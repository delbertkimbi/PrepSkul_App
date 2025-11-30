import 'package:geolocator/geolocator.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Location Check-In Service
///
/// Handles GPS tracking and verification for onsite sessions
/// - Gets current location
/// - Verifies proximity to session address
/// - Records check-in location in attendance
class LocationCheckInService {
  static final _supabase = SupabaseService.client;

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

      // If not coordinates, try geocoding (would need geocoding service)
      // For now, if we can't parse coordinates, we'll allow check-in but mark as unverified
      if (sessionPosition == null) {
        // TODO: Implement geocoding to convert address to coordinates
        // For now, return true but we'll mark check_in_verified as false
        return false; // Can't verify without coordinates
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
      print('❌ Error verifying location proximity: $e');
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
  ///
  /// Returns:
  /// - Map with 'success', 'verified', 'distance', 'message'
  static Future<Map<String, dynamic>> checkInToSession({
    required String sessionId,
    required String userId,
    required String userType,
    required String sessionAddress,
    bool verifyProximity = true,
    double allowedRadiusMeters = 100.0,
  }) async {
    try {
      // Get current location
      final currentPosition = await getCurrentLocation();
      final locationString = '${currentPosition.latitude},${currentPosition.longitude}';

      bool isVerified = false;
      double? distance;

      // Verify proximity if requested
      if (verifyProximity) {
        final isAtLocation = await verifyLocationProximity(
          sessionAddress: sessionAddress,
          allowedRadiusMeters: allowedRadiusMeters,
        );
        isVerified = isAtLocation;

        if (isAtLocation && sessionAddress.contains(',')) {
          // Calculate actual distance
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
      } else {
        // If not verifying, mark as verified (manual check-in)
        isVerified = true;
      }

      // Find or create attendance record
      final attendanceRecords = await _supabase
          .from('session_attendance')
          .select()
          .eq('session_id', sessionId)
          .eq('user_id', userId)
          .eq('user_type', userType);

      String attendanceId;
      if (attendanceRecords.isEmpty) {
        // Create new attendance record
        final newRecord = await _supabase
            .from('session_attendance')
            .insert({
              'session_id': sessionId,
              'user_id': userId,
              'user_type': userType,
              'joined_at': DateTime.now().toIso8601String(),
              'attendance_status': 'present',
              'check_in_location': locationString,
              'check_in_verified': isVerified,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        attendanceId = newRecord['id'] as String;
      } else {
        // Update existing attendance record
        attendanceId = attendanceRecords[0]['id'] as String;
        await _supabase
            .from('session_attendance')
            .update({
              'check_in_location': locationString,
              'check_in_verified': isVerified,
              'attendance_status': 'present',
              'joined_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', attendanceId);
      }

      return {
        'success': true,
        'verified': isVerified,
        'distance': distance,
        'location': locationString,
        'attendance_id': attendanceId,
        'message': isVerified
            ? 'Check-in successful! You are at the session location.'
            : 'Check-in recorded, but location could not be verified. Please ensure you are at the correct address.',
      };
    } catch (e) {
      print('❌ Error checking in to session: $e');
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
      print('❌ Error getting check-in status: $e');
      return null;
    }
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
}

