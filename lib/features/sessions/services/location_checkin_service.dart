import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:prepskul/core/config/live_session_test_config.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/utils/geocoding_helper.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/storage_service.dart';

/// Location Check-In Service
///
/// Handles GPS tracking and verification for onsite sessions
/// - Gets current location
/// - Verifies proximity to session address
/// - Records check-in location in attendance
class LocationCheckInService {
  static final _supabase = SupabaseService.client;

  /// Debug/test accounts may record check-in when GPS is unavailable (e.g. Flutter web).
  static bool canBypassLocationVerify(String? userId) {
    return LiveSessionTestConfig.canBypassOnsiteLocationVerify(userId);
  }
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

      // If not coordinates, resolve via geocoder + Nominatim
      if (sessionPosition == null) {
        final resolved = await GeocodingHelper.resolve(sessionAddress);
        if (resolved != null) {
          sessionPosition = Position(
            latitude: resolved.lat,
            longitude: resolved.lng,
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
              return false;
            }
          } catch (e) {
            LogService.warning('Geocoding failed for address: $sessionAddress, error: $e');
            return false;
          }
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
    double allowedRadiusMeters = 100.0,
    DateTime? scheduledDateTime,
  }) async {
    try {
      Position? currentPosition;
      String locationString;
      try {
        currentPosition = await getCurrentLocation();
        locationString = '${currentPosition.latitude},${currentPosition.longitude}';
      } catch (e) {
        if (canBypassLocationVerify(userId)) {
          final resolved = await GeocodingHelper.resolve(sessionAddress);
          if (resolved == null) {
            return {
              'success': false,
              'message': 'Could not resolve session address. Add a fuller address at booking.',
            };
          }
          locationString = '${resolved.lat},${resolved.lng}';
          LogService.warning('GPS unavailable; test-mode check-in at session coordinates: $e');
        } else {
          rethrow;
        }
      }

      bool isVerified = false;
      double? distance;

      // Verify proximity if requested
      if (verifyProximity && currentPosition != null) {
        final isAtLocation = await verifyLocationProximity(
          sessionAddress: sessionAddress,
          allowedRadiusMeters: allowedRadiusMeters,
        );
        isVerified = isAtLocation;

        if (isAtLocation) {
          final resolved = await GeocodingHelper.resolve(sessionAddress);
          if (resolved != null) {
            distance = calculateDistance(
              currentPosition.latitude,
              currentPosition.longitude,
              resolved.lat,
              resolved.lng,
            );
          } else if (sessionAddress.contains(',')) {
            final parts = sessionAddress.split(',');
            final lat = double.tryParse(parts[0].trim());
            final lon = double.tryParse(parts[1].trim());
            if (lat != null && lon != null) {
              distance = calculateDistance(
                currentPosition.latitude,
                currentPosition.longitude,
                lat,
                lon,
              );
            }
          }
        }
      } else if (verifyProximity && currentPosition == null && canBypassLocationVerify(userId)) {
        isVerified = true;
      } else if (!verifyProximity) {
        // If not verifying, mark as verified (manual check-in)
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

      // Build message with punctuality info
      String message;
      if (isVerified) {
        if (punctualityStatus == 'on_time') {
          message = 'Check-in successful! You arrived on time.';
        } else if (punctualityStatus == 'early') {
          message = 'Check-in successful! You arrived ${minutesEarlyOrLate!.abs()} minutes early.';
        } else if (punctualityStatus == 'late') {
          message = 'Check-in successful! You arrived ${minutesEarlyOrLate} minutes late.';
        } else {
          message = 'Check-in successful! You are at the session location.';
        }
      } else {
        message = 'Check-in recorded, but location could not be verified. Please ensure you are at the correct address.';
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
      return {
        'success': false,
        'verified': false,
        'error': e.toString(),
        'message': 'Failed to check in. Please try again.',
      };
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
          .select('check_in_location, check_in_verified, joined_at')
          .eq('session_id', sessionId)
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (attendance == null) {
        return null;
      }

      return {
        'has_checked_in': attendance['check_in_location'] != null,
        'verified': attendance['check_in_verified'] as bool? ?? false,
        'location': attendance['check_in_location'] as String?,
        'checked_in_at': attendance['joined_at'] as String?,
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
  }) async {
    try {
      // Find attendance record
      final attendanceRecords = await _supabase
          .from('session_attendance')
          .select('id, joined_at, check_in_time')
          .eq('session_id', sessionId)
          .eq('user_id', userId)
          .eq('user_type', userType);

      if (attendanceRecords.isEmpty) {
        return {
          'success': false,
          'message': 'No check-in record found. Please check in first.',
        };
      }

      final attendance = attendanceRecords[0];
      final checkOutTime = DateTime.now();
      final checkInTimeStr = attendance['check_in_time'] as String? ?? attendance['joined_at'] as String?;
      
      int? durationMinutes;
      if (checkInTimeStr != null) {
        final checkInTime = DateTime.parse(checkInTimeStr);
        durationMinutes = checkOutTime.difference(checkInTime).inMinutes;
      }

      // Update attendance record with check-out
      await _supabase
          .from('session_attendance')
          .update({
            'left_at': checkOutTime.toIso8601String(),
            'check_out_time': checkOutTime.toIso8601String(),
            'duration_minutes': durationMinutes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', attendance['id']);

      return {
        'success': true,
        'check_out_time': checkOutTime.toIso8601String(),
        'duration_minutes': durationMinutes,
        'message': 'Check-out successful!',
      };
    } catch (e) {
      LogService.error('Error checking out from session: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to check out. Please try again.',
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
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (attendance == null) {
        return null;
      }

      return Map<String, dynamic>.from(attendance as Map);
    } catch (e) {
      LogService.error('Error getting attendance record: $e');
      return null;
    }
  }

  /// Upload selfie for presence validation
  ///
  /// Stores the image in Supabase Storage and attempts to attach it to
  /// the session_attendance record (if the column exists).
  static Future<String> _uploadDocumentWithRetry({
    required String userId,
    required dynamic documentFile,
    required String documentType,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await StorageService.uploadDocument(
          userId: userId,
          documentFile: documentFile,
          documentType: documentType,
        );
      } catch (e) {
        lastError = e;
        final msg = e.toString();
        final retryable = msg.contains('504') ||
            msg.contains('Timeout') ||
            msg.contains('timeout') ||
            msg.contains('Gateway');
        if (attempt < 2 && retryable) {
          LogService.warning(
            'Upload retry ${attempt + 1}/2 for $documentType: $e',
          );
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
          continue;
        }
        rethrow;
      }
    }
    throw lastError ?? Exception('Upload failed');
  }

  static Future<Map<String, dynamic>> uploadPresenceSelfie({
    required String sessionId,
    required String userId,
    required String userType,
    required dynamic selfieFile,
  }) async {
    try {
      final photoUrl = await _uploadDocumentWithRetry(
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

  /// Upload checkout selfie for presence validation at session end.
  static Future<Map<String, dynamic>> uploadCheckoutSelfie({
    required String sessionId,
    required String userId,
    required String userType,
    required dynamic selfieFile,
  }) async {
    try {
      final photoUrl = await _uploadDocumentWithRetry(
        userId: userId,
        documentFile: selfieFile,
        documentType: 'session_checkout_selfie_$sessionId',
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
            'check_out_photo_url': photoUrl,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', attendance['id']);
        }
      } catch (e) {
        LogService.warning('Checkout selfie uploaded but not saved to attendance: $e');
      }

      return {
        'success': true,
        'photo_url': photoUrl,
        'message': 'Checkout selfie uploaded successfully',
      };
    } catch (e) {
      LogService.error('Error uploading checkout selfie: $e');
      return {
        'success': false,
        'message': 'Failed to upload checkout selfie. Please try again.',
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