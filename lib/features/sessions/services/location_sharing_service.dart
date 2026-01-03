import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

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
  /// Returns: true if started successfully
  static Future<bool> startLocationSharing({
    required String sessionId,
    required String userId,
    required String userType,
    Duration updateInterval = const Duration(seconds: 30),
  }) async {
    try {
      // Check if already tracking
      if (_activeTrackers.containsKey(sessionId)) {
        LogService.warning('Location sharing already active for session: $sessionId');
        return true;
      }

      // Check location permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      // Verify session is onsite and in progress
      final session = await _supabase
          .from('individual_sessions')
          .select('location, status, parent_id, learner_id')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      // Allow location sharing for onsite sessions only
      final sessionLocation = session['location'] as String?;
      // If location is 'hybrid' (legacy data), default to allowing it (treat as onsite)
      if (sessionLocation != 'onsite' && sessionLocation != 'hybrid') {
        throw Exception('Location sharing only available for onsite sessions');
      }

      if (session['status'] != 'in_progress') {
        throw Exception('Location sharing only available during active sessions');
      }

      // Verify user is authorized (learner or tutor for this session)
      final learnerId = session['learner_id'] as String?;
      final parentId = session['parent_id'] as String?;
      
      if (userType == 'learner' && userId != learnerId) {
        throw Exception('Unauthorized: Only the learner can share their location');
      }
      
      if (userType == 'tutor') {
        // Tutor can also share location
        final tutorCheck = await _supabase
            .from('individual_sessions')
            .select('tutor_id')
            .eq('id', sessionId)
            .maybeSingle();
        if (tutorCheck == null || userId != tutorCheck['tutor_id']) {
          throw Exception('Unauthorized: Only the tutor can share their location');
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
      return true;
    } catch (e) {
      LogService.error('Error starting location sharing: $e');
      return false;
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
  static Future<bool> shareWithEmergencyContact({
    required String sessionId,
    required String userId,
    required String userType,
  }) async {
    try {
      // Start location sharing for the session
      // This will begin real-time location tracking that emergency contacts can monitor
      final success = await startLocationSharing(
        sessionId: sessionId,
        userId: userId,
        userType: userType,
        updateInterval: const Duration(seconds: 30),
      );

      if (success) {
        LogService.success('Location sharing started for emergency contact monitoring: $sessionId');
      }

      return success;
    } catch (e) {
      LogService.error('Error sharing location with emergency contact: $e');
      return false;
    }
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