import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/sessions/models/location_share_result.dart';
import 'package:prepskul/features/sessions/utils/onsite_presence_utils.dart';

/// Location Sharing Service
///
/// Handles real-time location sharing for parents during onsite sessions
/// - Tracks learner/tutor location during active sessions
/// - Stores location updates in database
/// - Provides real-time location data for parents
class LocationSharingService {
  static final _supabase = SupabaseService.client;
  static final Map<String, StreamSubscription<Position>> _activeTrackers = {};
  static final Map<String, Timer> _updateTimers = {};

  /// Start sharing location for a session
  ///
  /// Parameters:
  /// - [sessionId]: The session ID
  /// - [userId]: The user ID (learner or tutor)
  /// - [userType]: 'learner' or 'tutor'
  /// - [updateInterval]: How often to update location (default: 30 seconds)
  ///
  /// Returns result with user-facing message on failure.
  static Future<LocationShareResult> startLocationSharing({
    required String sessionId,
    required String userId,
    required String userType,
    Duration updateInterval = const Duration(seconds: 30),
  }) async {
    try {
      if (_activeTrackers.containsKey(sessionId)) {
        return const LocationShareResult(
          success: true,
          message: 'Location sharing is already active for this session.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationShareResult(
            success: false,
            message: 'Location permission is required to share your live location.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationShareResult(
          success: false,
          message: 'Location permission is blocked. Enable it in your device settings.',
        );
      }

      final session = await _supabase
          .from('individual_sessions')
          .select('location, status, parent_id, learner_id, tutor_id, scheduled_date, scheduled_time')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        return const LocationShareResult(
          success: false,
          message: 'Session not found.',
        );
      }

      final sessionLocation = session['location'] as String?;
      if (sessionLocation != 'onsite' && sessionLocation != 'hybrid') {
        return const LocationShareResult(
          success: false,
          message: 'Location sharing is only available for on-site sessions.',
        );
      }

      final status = session['status'] as String?;
      var canShare = status == 'in_progress';

      DateTime? scheduledStart;
      final dateStr = session['scheduled_date'] as String?;
      final timeStr = session['scheduled_time'] as String?;
      if (dateStr != null && timeStr != null) {
        final parts = timeStr.split(':');
        final hour = parts.isNotEmpty ? (int.tryParse(parts[0].trim()) ?? 0) : 0;
        final minute = parts.length > 1
            ? (int.tryParse(parts[1].trim().split(' ').first) ?? 0)
            : 0;
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          scheduledStart = DateTime(date.year, date.month, date.day, hour, minute);
        }
      }

      if (!canShare && userType == 'tutor') {
        final attendance = await _supabase
            .from('session_attendance')
            .select('check_in_verified')
            .eq('session_id', sessionId)
            .eq('user_id', userId)
            .eq('user_type', 'tutor')
            .maybeSingle();
        canShare = attendance?['check_in_verified'] == true;
      }

      if (!canShare &&
          userType == 'tutor' &&
          OnsitePresenceUtils.isWithinPresenceWindow(scheduledStart)) {
        canShare = true;
      }

      if (!canShare) {
        final windowHint = OnsitePresenceUtils.checkInBlockedMessage(scheduledStart) ??
            OnsitePresenceUtils.windowLabel(scheduledStart);
        return LocationShareResult(
          success: false,
          message:
              'Live location sharing opens during the check-in window (1 hour before until 2 hours after session start). $windowHint',
        );
      }

      // Verify user is authorized (learner or tutor for this session)
      final learnerId = session['learner_id'] as String?;
      
      if (userType == 'learner' && userId != learnerId) {
        return const LocationShareResult(
          success: false,
          message: 'Only the learner assigned to this session can share location.',
        );
      }
      
      if (userType == 'tutor') {
        final tutorId = session['tutor_id'] as String?;
        if (tutorId == null || userId != tutorId) {
          return const LocationShareResult(
            success: false,
            message: 'Only the tutor assigned to this session can share location.',
          );
        }
      }

      // Start location tracking
      final positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update if moved 10 meters
        ),
      );

      // Subscribe to position updates
      final subscription = positionStream.listen(
        (Position position) async {
          await _updateLocation(
            sessionId: sessionId,
            userId: userId,
            userType: userType,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            timestamp: position.timestamp,
          );
        },
        onError: (error) {
          LogService.error('Error tracking location: $error');
        },
      );

      _activeTrackers[sessionId] = subscription;

      // Also set up periodic updates (as backup)
      final timer = Timer.periodic(updateInterval, (timer) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          await _updateLocation(
            sessionId: sessionId,
            userId: userId,
            userType: userType,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            timestamp: position.timestamp,
          );
        } catch (e) {
          LogService.warning('Error in periodic location update: $e');
        }
      });

      _updateTimers[sessionId] = timer;

      // Create initial location record
      try {
        final initialPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await _updateLocation(
          sessionId: sessionId,
          userId: userId,
          userType: userType,
          latitude: initialPosition.latitude,
          longitude: initialPosition.longitude,
          accuracy: initialPosition.accuracy,
          timestamp: initialPosition.timestamp,
        );
      } catch (e) {
        LogService.warning('Error getting initial position: $e');
      }

      LogService.success('Location sharing started for session: $sessionId');
      return const LocationShareResult(
        success: true,
        message: 'Location sharing started.',
      );
    } catch (e) {
      LogService.error('Error starting location sharing: $e');
      return LocationShareResult(
        success: false,
        message: 'Could not start location sharing: $e',
      );
    }
  }

  /// Stop sharing location for a session
  static Future<void> stopLocationSharing(String sessionId) async {
    try {
      // Cancel subscription
      final subscription = _activeTrackers.remove(sessionId);
      if (subscription != null) {
        await subscription.cancel();
      }

      // Cancel timer
      final timer = _updateTimers.remove(sessionId);
      if (timer != null) {
        timer.cancel();
      }

      LogService.success('Location sharing stopped for session: $sessionId');
    } catch (e) {
      LogService.error('Error stopping location sharing: $e');
    }
  }

  /// Update location in database
  /// Also stores location history for safety records
  static Future<void> _updateLocation({
    required String sessionId,
    required String userId,
    required String userType,
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
  }) async {
    try {
      // Check if location tracking record exists
      final existing = await _supabase
          .from('session_location_tracking')
          .select('id')
          .eq('session_id', sessionId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Update existing record
        await _supabase
            .from('session_location_tracking')
            .update({
              'latitude': latitude,
              'longitude': longitude,
              'accuracy': accuracy,
              'last_updated_at': timestamp.toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);
      } else {
        // Create new record
        await _supabase.from('session_location_tracking').insert({
          'session_id': sessionId,
          'user_id': userId,
          'user_type': userType,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'last_updated_at': timestamp.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // Store location history for safety records (append-only)
      // This creates a permanent record of all location updates
      try {
        await _supabase.from('session_location_history').insert({
          'session_id': sessionId,
          'user_id': userId,
          'user_type': userType,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'recorded_at': timestamp.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // If history table doesn't exist, log warning but don't fail
        LogService.debug('Location history table may not exist: $e');
      }
    } catch (e) {
      LogService.warning('Error updating location: $e');
      // Don't throw - location updates are best effort
    }
  }

  /// Get current location for a session
  ///
  /// Returns the latest location update for the session
  /// If multiple users are tracking (tutor and learner), returns the most recent
  static Future<Map<String, dynamic>?> getSessionLocation(String sessionId) async {
    try {
      final response = await _supabase
          .from('session_location_tracking')
          .select('''
            id,
            user_id,
            user_type,
            latitude,
            longitude,
            accuracy,
            last_updated_at,
            created_at
          ''')
          .eq('session_id', sessionId)
          .order('last_updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return {
        'latitude': response['latitude'] as double,
        'longitude': response['longitude'] as double,
        'accuracy': response['accuracy'] as double?,
        'user_type': response['user_type'] as String,
        'user_id': response['user_id'] as String,
        'last_updated_at': response['last_updated_at'] as String,
        'timestamp': DateTime.parse(response['last_updated_at'] as String),
      };
    } catch (e) {
      LogService.error('Error getting session location: $e');
      return null;
    }
  }

  /// Get all active location trackers for a session
  ///
  /// Returns locations for both tutor and learner if both are tracking
  static Future<List<Map<String, dynamic>>> getAllSessionLocations(String sessionId) async {
    try {
      final response = await _supabase
          .from('session_location_tracking')
          .select('''
            id,
            user_id,
            user_type,
            latitude,
            longitude,
            accuracy,
            last_updated_at
          ''')
          .eq('session_id', sessionId)
          .order('last_updated_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>().map((location) {
        return {
          'latitude': location['latitude'] as double,
          'longitude': location['longitude'] as double,
          'accuracy': location['accuracy'] as double?,
          'user_type': location['user_type'] as String,
          'user_id': location['user_id'] as String,
          'last_updated_at': location['last_updated_at'] as String,
          'timestamp': DateTime.parse(location['last_updated_at'] as String),
        };
      }).toList();
    } catch (e) {
      LogService.error('Error getting all session locations: $e');
      return [];
    }
  }

  /// Get location history for a session
  ///
  /// Returns all location updates for the session
  static Future<List<Map<String, dynamic>>> getLocationHistory(
    String sessionId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('session_location_tracking')
          .select('''
            id,
            user_id,
            user_type,
            latitude,
            longitude,
            accuracy,
            last_updated_at
          ''')
          .eq('session_id', sessionId)
          .order('last_updated_at', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.error('Error getting location history: $e');
      return [];
    }
  }

  /// Check if location sharing is active for a session
  static bool isLocationSharingActive(String sessionId) {
    return _activeTrackers.containsKey(sessionId);
  }

  /// Stop all active location sharing
  static Future<void> stopAllLocationSharing() async {
    final sessionIds = _activeTrackers.keys.toList();
    for (final sessionId in sessionIds) {
      await stopLocationSharing(sessionId);
    }
  }

  /// Share location with emergency contact
  ///
  /// Starts location sharing for a session to enable emergency contact monitoring
  /// This is called by SessionSafetyService when user requests to share location
  static Future<LocationShareResult> shareWithEmergencyContact({
    required String sessionId,
    required String userId,
    required String userType,
  }) async {
    return startLocationSharing(
      sessionId: sessionId,
      userId: userId,
      userType: userType,
      updateInterval: const Duration(seconds: 30),
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
}