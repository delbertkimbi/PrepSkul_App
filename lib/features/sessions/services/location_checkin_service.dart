import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/storage_service.dart';
import 'package:prepskul/features/sessions/services/onsite_geocoding_service.dart';
import 'package:prepskul/features/sessions/utils/onsite_presence_utils.dart';

/// Location Check-In Service
///
/// Handles GPS tracking and verification for onsite sessions
/// - Gets current location
/// - Verifies proximity to session address
/// - Records check-in location in attendance
class LocationCheckInService {
  static final _supabase = SupabaseService.client;

  static const double defaultAllowedRadiusMeters =
      OnsiteGeocodingService.checkInRadiusMeters;

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permissions
  static Future<LocationPermission> checkLocationPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permissions
  static Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current location
  ///
  /// Returns current GPS coordinates
  /// Throws exception if permissions denied or location unavailable
  static Future<Position> getCurrentLocation() async {
    // Check if location services are enabled
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable location services.');
    }

    // Check permissions
    LocationPermission permission = await checkLocationPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestLocationPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied. Please grant location access.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please enable in settings.');
    }

    // Get current position with high accuracy
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  /// Calculate distance between two coordinates (in meters)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Verify if user is at session location
  ///
  /// Parameters:
  /// - [sessionAddress]: The session address (can be coordinates or address string)
  /// - [allowedRadiusMeters]: Maximum distance allowed (default: 100 meters)
  ///
  /// Returns:
  /// - true if within allowed radius
  /// - false if too far away
  static Future<bool> verifyLocationProximity({
    required String sessionAddress,
    double allowedRadiusMeters = 100.0,
  }) async {
    try {
      // Get current location
      final currentPosition = await getCurrentLocation();

      // Parse session address (could be coordinates or address)
      // Try to parse as coordinates first (format: "lat,lon" or "lat, lon")
      Position? sessionPosition;

      // Check if address is in coordinate format
      if (sessionAddress.contains(',') && 
          RegExp(r'^-?\d+\.?\d*,-?\d+\.?\d*$').hasMatch(sessionAddress.replaceAll(' ', ''))) {
        final parts = sessionAddress.split(',');
        final lat = double.tryParse(parts[0].trim());
        final lon = double.tryParse(parts[1].trim());
        
        if (lat != null && lon != null) {
          sessionPosition = Position(
            latitude: lat,
            longitude: lon,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        }
      }

      // If not coordinates, try geocoding to convert address to coordinates
      if (sessionPosition == null) {
        try {
          final locations = await locationFromAddress(sessionAddress);
          if (locations.isNotEmpty) {
            final location = locations.first;
            sessionPosition = Position(
              latitude: location.latitude,
              longitude: location.longitude,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );
          } else {
            LogService.warning('Geocoding returned no results for: $sessionAddress');
            return false; // Can't verify without coordinates
          }
        } catch (e) {
          LogService.warning('Geocoding failed for address: $sessionAddress, error: $e');
          return false; // Can't verify without coordinates
        }
      }

      // Calculate distance
      final distance = calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        sessionPosition.latitude,
        sessionPosition.longitude,
      );

      return distance <= allowedRadiusMeters;
    } catch (e) {
      LogService.error('Error verifying location proximity: $e');
      return false;
    }
  }

  /// Check in to an onsite session
  ///
  /// Parameters:
  /// - [sessionId]: The session ID
  /// - [userId]: The user ID (tutor or student)
  /// - [userType]: 'tutor' or 'student'
  /// - [sessionAddress]: The session address
  /// - [verifyProximity]: Whether to verify user is at location (default: true)
  /// - [scheduledDateTime]: Optional scheduled date/time for punctuality calculation
  ///
  /// Returns:
  /// - Map with 'success', 'verified', 'distance', 'punctuality', 'message'
  static Future<Map<String, dynamic>> checkInToSession({
    required String sessionId,
    required String userId,
    required String userType,
    required String sessionAddress,
    bool verifyProximity = true,
    double allowedRadiusMeters = defaultAllowedRadiusMeters,
    DateTime? scheduledDateTime,
  }) async {
    try {
      if (scheduledDateTime != null) {
        final windowMsg = OnsitePresenceUtils.checkInBlockedMessage(scheduledDateTime);
        if (windowMsg != null) {
          return {
            'success': false,
            'verified': false,
            'message': windowMsg,
            'blocked_reason': 'outside_presence_window',
          };
        }
      }

      final currentPosition = await getCurrentLocation();
      final locationString =
          '${currentPosition.latitude},${currentPosition.longitude}';

      double? distance;
      String addressLabel = sessionAddress;
      bool isVerified = !verifyProximity;

      if (verifyProximity) {
        final target = await OnsiteGeocodingService.resolveSessionCoordinates(
          sessionId: sessionId,
          fallbackAddress: sessionAddress,
        );
        if (target == null) {
          return {
            'success': false,
            'verified': false,
            'message':
                'We could not plot this session address on the map yet. '
                'Ask your coordinator to confirm the full street address for "$sessionAddress", '
                'or try again closer to session day when you are at the venue.',
            'blocked_reason': 'geocode_failed',
          };
        }

        final targetLat = target['latitude'] as double;
        final targetLon = target['longitude'] as double;
        addressLabel =
            (target['address_label'] as String?) ?? sessionAddress;

        distance = calculateDistance(
          currentPosition.latitude,
          currentPosition.longitude,
          targetLat,
          targetLon,
        );

        if (distance > allowedRadiusMeters) {
          final distRounded = distance.round();
          return {
            'success': false,
            'verified': false,
            'distance': distance,
            'message':
                'You are about $distRounded m from the session location ($addressLabel). '
                'Move within ${allowedRadiusMeters.round()} m to check in.',
          };
        }
        isVerified = true;
      }

      // Calculate punctuality if scheduled time provided
      String? punctualityStatus;
      int? minutesEarlyOrLate;
      if (scheduledDateTime != null) {
        final now = DateTime.now();
        final difference = now.difference(scheduledDateTime);
        minutesEarlyOrLate = difference.inMinutes;
        
        if (difference.isNegative) {
          // Arrived early
          punctualityStatus = 'early';
        } else if (difference.inMinutes <= 5) {
          // On time (within 5 minutes)
          punctualityStatus = 'on_time';
        } else {
          // Late
          punctualityStatus = 'late';
        }
      }

      // Find or create attendance record
      final attendanceRecords = await _supabase
          .from('session_attendance')
          .select()
          .eq('session_id', sessionId)
          .eq('user_id', userId)
          .eq('user_type', userType);

      final checkInTime = DateTime.now();
      String attendanceId;
      if (attendanceRecords.isEmpty) {
        // Create new attendance record
        final attendanceData = {
          'session_id': sessionId,
          'user_id': userId,
          'user_type': userType,
          'joined_at': checkInTime.toIso8601String(),
          'check_in_time': checkInTime.toIso8601String(),
          'attendance_status': 'present',
          'check_in_location': locationString,
          'check_in_verified': isVerified,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        // Add punctuality data if available
        if (punctualityStatus != null) {
          attendanceData['punctuality_status'] = punctualityStatus;
          if (minutesEarlyOrLate != null) {
            attendanceData['arrival_time_minutes'] = minutesEarlyOrLate;
          }
        }
        
        final newRecord = await _supabase
            .from('session_attendance')
            .insert(attendanceData)
            .select()
            .maybeSingle();
        if (newRecord == null) {
          throw Exception('Failed to create attendance record');
        }
        attendanceId = newRecord['id'] as String;
      } else {
        // Update existing attendance record (update check-in time)
        attendanceId = attendanceRecords[0]['id'] as String;
        final updateData = {
          'check_in_location': locationString,
          'check_in_verified': isVerified,
          'check_in_time': checkInTime.toIso8601String(),
          'attendance_status': 'present',
          'joined_at': checkInTime.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        // Add punctuality data if available
        if (punctualityStatus != null) {
          updateData['punctuality_status'] = punctualityStatus;
          if (minutesEarlyOrLate != null) {
            updateData['arrival_time_minutes'] = minutesEarlyOrLate;
          }
        }
        
        await _supabase
            .from('session_attendance')
            .update(updateData)
            .eq('id', attendanceId);
      }

      if (userType == 'tutor' && isVerified) {
        await _markOnsiteSessionInProgress(sessionId);
      }

      // Notify admins if tutor checked in late beyond grace (e.g. >15 min)
      if (punctualityStatus == 'late' && minutesEarlyOrLate != null && minutesEarlyOrLate >= 15) {
        NotificationHelperService.notifyAdminsAboutSessionSafetyAlert(
          sessionId: sessionId,
          title: 'Tutor checked in late',
          message: 'Tutor checked in $minutesEarlyOrLate minutes late (onsite session).',
          severity: 'warning',
          type: 'late_check_in',
          metadata: {'minutes_late': minutesEarlyOrLate},
          sendPush: true,
        );
      }

      String message;
      if (punctualityStatus == 'on_time') {
        message = 'Check-in successful. You arrived on time.';
      } else if (punctualityStatus == 'early') {
        message =
            'Check-in successful. You arrived ${minutesEarlyOrLate!.abs()} minutes early.';
      } else if (punctualityStatus == 'late') {
        message =
            'Check-in successful. You arrived $minutesEarlyOrLate minutes late.';
      } else {
        message = 'Check-in successful. You are at the session location.';
      }

      return {
        'success': true,
        'verified': isVerified,
        'distance': distance,
        'location': locationString,
        'attendance_id': attendanceId,
        'punctuality_status': punctualityStatus,
        'minutes_early_or_late': minutesEarlyOrLate,
        'check_in_time': checkInTime.toIso8601String(),
        'message': message,
      };
    } catch (e) {
      LogService.error('Error checking in to session: $e');
      final err = e.toString();
      if (err.contains('Location permissions')) {
        return {
          'success': false,
          'verified': false,
          'message':
              'Location access is required to check in. Please enable location permissions in your device settings.',
        };
      }
      if (err.contains('Location services are disabled')) {
        return {
          'success': false,
          'verified': false,
          'message':
              'Turn on location services (GPS) on your device, then try checking in again.',
        };
      }
      return {
        'success': false,
        'verified': false,
        'error': err,
        'message': 'We could not complete check-in. Please try again in a moment.',
      };
    }
  }

  static Future<void> _markOnsiteSessionInProgress(String sessionId) async {
    final now = DateTime.now().toIso8601String();
    try {
      final session = await _supabase
          .from('individual_sessions')
          .select('status, session_started_at, location')
          .eq('id', sessionId)
          .maybeSingle();
      if (session == null) return;

      final loc = (session['location'] as String? ?? '').toLowerCase();
      if (loc != 'onsite' && loc != 'hybrid') return;

      final updateData = <String, dynamic>{
        'status': 'in_progress',
        'tutor_joined_at': now,
        'attendance_admin_status': 'pending',
        'updated_at': now,
      };
      if (session['session_started_at'] == null) {
        updateData['session_started_at'] = now;
      }
      await _supabase.from('individual_sessions').update(updateData).eq('id', sessionId);
    } catch (e) {
      LogService.warning('Could not mark session in progress on check-in: $e');
    }
  }

  /// Get check-in status for a session
  ///
  /// Returns check-in information if available
  static Future<Map<String, dynamic>?> getCheckInStatus({
    required String sessionId,
    required String userId,
  }) async {
    try {
      final attendance = await _supabase
          .from('session_attendance')
          .select(
            'check_in_location, check_in_verified, check_in_time, joined_at, check_out_time, check_in_photo_url, check_out_photo_url',
          )
          .eq('session_id', sessionId)
          .eq('user_id', userId)
          .maybeSingle();

      if (attendance == null) {
        return null;
      }

      final verified = attendance['check_in_verified'] as bool? ?? false;
      final checkInTime = attendance['check_in_time'] as String?;
      final hasCheckedIn = verified && checkInTime != null;
      final checkOutTime = attendance['check_out_time'] as String?;

      return {
        'has_checked_in': hasCheckedIn,
        'has_checked_out': checkOutTime != null,
        'verified': verified,
        'location': attendance['check_in_location'] as String?,
        'checked_in_at': checkInTime ?? attendance['joined_at'] as String?,
        'checked_out_at': checkOutTime,
        'has_check_in_selfie':
            (attendance['check_in_photo_url'] as String?)?.trim().isNotEmpty == true,
        'has_check_out_selfie':
            (attendance['check_out_photo_url'] as String?)?.trim().isNotEmpty == true,
      };
    } catch (e) {
      LogService.error('Error getting check-in status: $e');
      return null;
    }
  }

  /// Check out from an onsite session
  ///
  /// Records check-out time and calculates session duration
  static Future<Map<String, dynamic>> checkOutFromSession({
    required String sessionId,
    required String userId,
    required String userType,
    bool requireCheckoutSelfie = true,
  }) async {
    try {
      final attendanceRecords = await _supabase
          .from('session_attendance')
          .select(
            'id, joined_at, check_in_time, check_in_verified, check_out_photo_url',
          )
          .eq('session_id', sessionId)
          .eq('user_id', userId)
          .eq('user_type', userType);

      if (attendanceRecords.isEmpty) {
        return {
          'success': false,
          'message': 'Please check in at the session location before checking out.',
        };
      }

      final attendance = attendanceRecords[0];
      if (attendance['check_in_verified'] != true) {
        return {
          'success': false,
          'message': 'A verified check-in is required before you can check out.',
        };
      }

      final checkoutPhoto = attendance['check_out_photo_url'] as String?;
      if (requireCheckoutSelfie &&
          (checkoutPhoto == null || checkoutPhoto.trim().isEmpty)) {
        return {
          'success': false,
          'message':
              'Please upload a checkout selfie before ending your on-site session.',
        };
      }

      final checkOutTime = DateTime.now();
      final checkInTimeStr = attendance['check_in_time'] as String? ??
          attendance['joined_at'] as String?;

      int? durationMinutes;
      if (checkInTimeStr != null) {
        final checkInTime = DateTime.parse(checkInTimeStr);
        durationMinutes = checkOutTime.difference(checkInTime).inMinutes;
      }

      await _supabase.from('session_attendance').update({
        'left_at': checkOutTime.toIso8601String(),
        'check_out_time': checkOutTime.toIso8601String(),
        'duration_minutes': durationMinutes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', attendance['id']);

      await _completeOnsiteSessionAfterCheckout(sessionId);

      NotificationHelperService.notifyAdminsAboutSessionSafetyAlert(
        sessionId: sessionId,
        title: 'On-site session ready for review',
        message:
            'Tutor checked out. Please review attendance and selfies in the admin queue.',
        severity: 'info',
        type: 'onsite_checkout_pending_review',
        sendPush: true,
      ).catchError((e) {
        LogService.warning('Admin notify after checkout failed: $e');
      });

      return {
        'success': true,
        'check_out_time': checkOutTime.toIso8601String(),
        'duration_minutes': durationMinutes,
        'message': 'Check-out recorded. Session ended and sent for admin review.',
      };
    } catch (e) {
      LogService.error('Error checking out from session: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'We could not complete check-out. Please try again.',
      };
    }
  }

  static Future<void> _completeOnsiteSessionAfterCheckout(String sessionId) async {
    final now = DateTime.now().toIso8601String();
    try {
      final session = await _supabase
          .from('individual_sessions')
          .select('status, session_started_at, duration_minutes, location')
          .eq('id', sessionId)
          .maybeSingle();
      if (session == null) return;

      int? actualDurationMinutes;
      if (session['session_started_at'] != null) {
        final start = DateTime.parse(session['session_started_at'] as String);
        actualDurationMinutes = DateTime.now().difference(start).inMinutes;
      } else {
        actualDurationMinutes = session['duration_minutes'] as int?;
      }

      await _supabase.from('individual_sessions').update({
        'status': 'completed',
        'session_ended_at': now,
        'actual_duration_minutes': actualDurationMinutes,
        'attendance_admin_status': 'pending',
        'updated_at': now,
      }).eq('id', sessionId);
    } catch (e) {
      LogService.warning('Could not complete session after checkout: $e');
    }
  }

  /// Upload checkout selfie (required before check-out).
  static Future<Map<String, dynamic>> uploadCheckoutSelfie({
    required String sessionId,
    required String userId,
    required String userType,
    required dynamic selfieFile,
  }) async {
    try {
      final photoUrl = await StorageService.uploadDocument(
        userId: userId,
        documentFile: selfieFile,
        documentType: 'session_checkout_selfie_$sessionId',
      );

      final attendance = await _supabase
          .from('session_attendance')
          .select('id')
          .eq('session_id', sessionId)
          .eq('user_id', userId)
          .eq('user_type', userType)
          .maybeSingle();

      if (attendance == null) {
        return {
          'success': false,
          'message': 'Check in first before uploading a checkout selfie.',
        };
      }

      await _supabase.from('session_attendance').update({
        'check_out_photo_url': photoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', attendance['id']);

      return {
        'success': true,
        'photo_url': photoUrl,
        'message': 'Checkout selfie uploaded. You can now check out.',
      };
    } catch (e) {
      LogService.error('Error uploading checkout selfie: $e');
      return {
        'success': false,
        'message': 'Failed to upload checkout selfie. Please try again.',
      };
    }
  }

  /// Get full attendance record with check-in/check-out times
  static Future<Map<String, dynamic>?> getAttendanceRecord({
    required String sessionId,
    required String userId,
  }) async {
    try {
      final attendance = await _supabase
          .from('session_attendance')
          .select('''
            id,
            joined_at,
            left_at,
            check_in_time,
            check_out_time,
            check_in_location,
            check_in_verified,
            check_in_photo_url,
            check_out_photo_url,
            punctuality_status,
            arrival_time_minutes,
            duration_minutes,
            attendance_status
          ''')
          .eq('session_id', sessionId)
          .eq('user_id', userId)
          .maybeSingle();

      if (attendance == null) {
        return null;
      }

      return attendance as Map<String, dynamic>;
    } catch (e) {
      LogService.error('Error getting attendance record: $e');
      return null;
    }
  }

  /// Upload selfie for presence validation
  ///
  /// Stores the image in Supabase Storage and attempts to attach it to
  /// the session_attendance record (if the column exists).
  static Future<Map<String, dynamic>> uploadPresenceSelfie({
    required String sessionId,
    required String userId,
    required String userType,
    required dynamic selfieFile,
  }) async {
    try {
      final photoUrl = await StorageService.uploadDocument(
        userId: userId,
        documentFile: selfieFile,
        documentType: 'session_selfie_$sessionId',
      );

      try {
        final attendance = await _supabase
            .from('session_attendance')
            .select('id')
            .eq('session_id', sessionId)
            .eq('user_id', userId)
            .eq('user_type', userType)
            .maybeSingle();

        if (attendance != null) {
          await _supabase.from('session_attendance').update({
            'check_in_photo_url': photoUrl,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', attendance['id']);
        }

        // Mark session for admin attendance review (onsite/hybrid)
        try {
          await _supabase.from('individual_sessions').update({
            'attendance_admin_status': 'pending',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', sessionId);
        } catch (e) {
          LogService.warning('Could not set attendance_admin_status: $e');
        }
      } catch (e) {
        LogService.warning('Selfie uploaded but not saved to attendance: $e');
      }

      return {
        'success': true,
        'photo_url': photoUrl,
        'message': 'Selfie uploaded successfully',
      };
    } catch (e) {
      LogService.error('Error uploading presence selfie: $e');
      return {
        'success': false,
        'message': 'Failed to upload selfie. Please try again.',
        'error': e.toString(),
      };
    }
  }

  /// Get attendance history for a user
  static Future<List<Map<String, dynamic>>> getAttendanceHistory({
    required String userId,
    String? userType,
    int limit = 50,
  }) async {
    try {
      var query = _supabase
          .from('session_attendance')
          .select('''
            id,
            session_id,
            user_type,
            joined_at,
            left_at,
            check_in_time,
            check_out_time,
            check_in_location,
            check_in_verified,
            punctuality_status,
            arrival_time_minutes,
            duration_minutes,
            attendance_status,
            created_at
          ''')
          .eq('user_id', userId);
      
      if (userType != null) {
        query = query.eq('user_type', userType);
      }
      
      final response = await query.order('created_at', ascending: false).limit(limit);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.error('Error getting attendance history: $e');
      return [];
    }
  }

  /// Calculate punctuality score (0-100)
  /// Higher score = more punctual
  static int calculatePunctualityScore(List<Map<String, dynamic>> attendanceHistory) {
    if (attendanceHistory.isEmpty) return 0;

    int onTimeCount = 0;
    int earlyCount = 0;
    int lateCount = 0;

    for (final record in attendanceHistory) {
      final status = record['punctuality_status'] as String?;
      if (status == 'on_time') {
        onTimeCount++;
      } else if (status == 'early') {
        earlyCount++;
      } else if (status == 'late') {
        lateCount++;
      }
    }

    final total = attendanceHistory.length;
    if (total == 0) return 0;

    // Score calculation:
    // - On time: 100 points
    // - Early: 90 points (still good)
    // - Late: 50 points
    final score = ((onTimeCount * 100) + (earlyCount * 90) + (lateCount * 50)) / total;
    return score.round();
  }

  /// Format location string for display
  static String formatLocationString(String? locationString) {
    if (locationString == null || locationString.isEmpty) {
      return 'Location not available';
    }

    // If it's coordinates, format nicely
    if (locationString.contains(',')) {
      final parts = locationString.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lon = double.tryParse(parts[1].trim());
        if (lat != null && lon != null) {
          return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
        }
      }
    }

    return locationString;
  }

  /// Format punctuality status for display
  static String formatPunctualityStatus(String? status, int? minutes) {
    if (status == null) return 'Not recorded';
    
    switch (status) {
      case 'on_time':
        return 'On time';
      case 'early':
        return minutes != null ? '${minutes.abs()} min early' : 'Early';
      case 'late':
        return minutes != null ? '$minutes min late' : 'Late';
      default:
        return 'Unknown';
    }
  }
}