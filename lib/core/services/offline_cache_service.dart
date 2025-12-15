import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Offline Cache Service
/// 
/// Caches app data locally for offline access
/// Uses SharedPreferences for simple key-value storage
/// 
/// Cached Data:
/// - Tutor lists (discovery)
/// - Booking requests (student & tutor)
/// - Recurring sessions
/// - Individual sessions
/// - User profile data
/// 
/// Cache Strategy:
/// - Cache on successful fetch
/// - Serve from cache when offline
/// - Show cache timestamp to user
/// - Auto-expire old cache (7 days)

class OfflineCacheService {
  // Cache keys
  static const String _keyTutors = 'cached_tutors';
  static const String _keyTutorDetails = 'cached_tutor_details_';
  static const String _keyBookingRequests = 'cached_booking_requests_';
  static const String _keyTrialSessions = 'cached_trial_sessions_';
  static const String _keyRecurringSessions = 'cached_recurring_sessions_';
  static const String _keyIndividualSessions = 'cached_individual_sessions_';
  static const String _keyUserProfile = 'cached_user_profile_';
  static const String _keyCacheTimestamp = '_cache_timestamp';
  
  // Cache expiration (7 days)
  static const Duration _cacheExpiration = Duration(days: 7);

  /// Cache tutor list
  static Future<void> cacheTutors(List<Map<String, dynamic>> tutors) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(tutors);
      await prefs.setString(_keyTutors, json);
      await prefs.setInt('${_keyTutors}_timestamp', DateTime.now().millisecondsSinceEpoch);
      LogService.success('Cached ${tutors.length} tutors');
    } catch (e) {
      LogService.error('Error caching tutors: $e');
    }
  }

  /// Get cached tutor list
  static Future<List<Map<String, dynamic>>?> getCachedTutors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyTutors);
      final timestamp = prefs.getInt('${_keyTutors}_timestamp') ?? 0;
      
      if (json == null) return null;
      
      // Check if cache is expired
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheExpiration) {
        LogService.warning('Tutor cache expired');
        return null;
      }

      final List<dynamic> decoded = jsonDecode(json);
      final tutors = List<Map<String, dynamic>>.from(
        decoded.map((t) => Map<String, dynamic>.from(t)),
      );
      LogService.success('Retrieved ${tutors.length} tutors from cache');
      return tutors;
    } catch (e) {
      LogService.error('Error getting cached tutors: $e');
      return null;
    }
  }

  /// Cache tutor details
  static Future<void> cacheTutorDetails(String tutorId, Map<String, dynamic> tutor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(tutor);
      await prefs.setString('$_keyTutorDetails$tutorId', json);
      await prefs.setInt('$_keyTutorDetails$tutorId$_keyCacheTimestamp', 
          DateTime.now().millisecondsSinceEpoch);
      LogService.success('Cached tutor details: $tutorId');
    } catch (e) {
      LogService.error('Error caching tutor details: $e');
    }
  }

  /// Get cached tutor details
  static Future<Map<String, dynamic>?> getCachedTutorDetails(String tutorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('$_keyTutorDetails$tutorId');
      final timestamp = prefs.getInt('$_keyTutorDetails$tutorId$_keyCacheTimestamp') ?? 0;
      
      if (json == null) return null;
      
      // Check if cache is expired
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheExpiration) {
        return null;
      }

      return Map<String, dynamic>.from(jsonDecode(json));
    } catch (e) {
      LogService.error('Error getting cached tutor details: $e');
      return null;
    }
  }

  /// Cache booking requests
  static Future<void> cacheBookingRequests(
    String userId,
    List<Map<String, dynamic>> requests,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(requests);
      await prefs.setString('$_keyBookingRequests$userId', json);
      await prefs.setInt('$_keyBookingRequests$userId$_keyCacheTimestamp',
          DateTime.now().millisecondsSinceEpoch);
      LogService.success('Cached ${requests.length} booking requests for user: $userId');
    } catch (e) {
      LogService.error('Error caching booking requests: $e');
    }
  }

  /// Get cached booking requests
  static Future<List<Map<String, dynamic>>?> getCachedBookingRequests(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('$_keyBookingRequests$userId');
      final timestamp = prefs.getInt('$_keyBookingRequests$userId$_keyCacheTimestamp') ?? 0;
      
      if (json == null) return null;
      
      // Check if cache is expired
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheExpiration) {
        return null;
      }

      final List<dynamic> decoded = jsonDecode(json);
      return List<Map<String, dynamic>>.from(
        decoded.map((r) => Map<String, dynamic>.from(r)),
      );
    } catch (e) {
      LogService.error('Error getting cached booking requests: $e');
      return null;
    }
  }

  /// Cache recurring sessions
  static Future<void> cacheRecurringSessions(
    String userId,
    List<Map<String, dynamic>> sessions,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(sessions);
      await prefs.setString('$_keyRecurringSessions$userId', json);
      await prefs.setInt('$_keyRecurringSessions$userId$_keyCacheTimestamp',
          DateTime.now().millisecondsSinceEpoch);
      LogService.success('Cached ${sessions.length} recurring sessions for user: $userId');
    } catch (e) {
      LogService.error('Error caching recurring sessions: $e');
    }
  }

  /// Get cached recurring sessions
  static Future<List<Map<String, dynamic>>?> getCachedRecurringSessions(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('$_keyRecurringSessions$userId');
      final timestamp = prefs.getInt('$_keyRecurringSessions$userId$_keyCacheTimestamp') ?? 0;
      
      if (json == null) return null;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheExpiration) {
        return null;
      }

      final List<dynamic> decoded = jsonDecode(json);
      return List<Map<String, dynamic>>.from(
        decoded.map((s) => Map<String, dynamic>.from(s)),
      );
    } catch (e) {
      LogService.error('Error getting cached recurring sessions: $e');
      return null;
    }
  }

  /// Cache individual sessions
  static Future<void> cacheIndividualSessions(
    String userId,
    List<Map<String, dynamic>> sessions,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(sessions);
      await prefs.setString('$_keyIndividualSessions$userId', json);
      await prefs.setInt('$_keyIndividualSessions$userId$_keyCacheTimestamp',
          DateTime.now().millisecondsSinceEpoch);
      LogService.success('Cached ${sessions.length} individual sessions for user: $userId');
    } catch (e) {
      LogService.error('Error caching individual sessions: $e');
    }
  }

  /// Get cached individual sessions
  static Future<List<Map<String, dynamic>>?> getCachedIndividualSessions(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('$_keyIndividualSessions$userId');
      final timestamp = prefs.getInt('$_keyIndividualSessions$userId$_keyCacheTimestamp') ?? 0;
      
      if (json == null) return null;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheExpiration) {
        return null;
      }

      final List<dynamic> decoded = jsonDecode(json);
      return List<Map<String, dynamic>>.from(
        decoded.map((s) => Map<String, dynamic>.from(s)),
      );
    } catch (e) {
      LogService.error('Error getting cached individual sessions: $e');
      return null;
    }
  }

  /// Cache trial sessions
  static Future<void> cacheTrialSessions(
    String userId,
    List<Map<String, dynamic>> sessions,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(sessions);
      await prefs.setString('$_keyTrialSessions$userId', json);
      await prefs.setInt('$_keyTrialSessions$userId$_keyCacheTimestamp',
          DateTime.now().millisecondsSinceEpoch);
      LogService.success('Cached ${sessions.length} trial sessions for user: $userId');
    } catch (e) {
      LogService.error('Error caching trial sessions: $e');
    }
  }

  /// Get cached trial sessions
  static Future<List<Map<String, dynamic>>?> getCachedTrialSessions(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('$_keyTrialSessions$userId');
      final timestamp = prefs.getInt('$_keyTrialSessions$userId$_keyCacheTimestamp') ?? 0;
      
      if (json == null) return null;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheExpiration) {
        return null;
      }

      final List<dynamic> decoded = jsonDecode(json);
      return List<Map<String, dynamic>>.from(
        decoded.map((s) => Map<String, dynamic>.from(s)),
      );
    } catch (e) {
      LogService.error('Error getting cached trial sessions: $e');
      return null;
    }
  }

  /// Cache user profile
  static Future<void> cacheUserProfile(String userId, Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(profile);
      await prefs.setString('$_keyUserProfile$userId', json);
      await prefs.setInt('$_keyUserProfile$userId$_keyCacheTimestamp',
          DateTime.now().millisecondsSinceEpoch);
      LogService.success('Cached user profile: $userId');
    } catch (e) {
      LogService.error('Error caching user profile: $e');
    }
  }

  /// Get cached user profile
  static Future<Map<String, dynamic>?> getCachedUserProfile(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('$_keyUserProfile$userId');
      final timestamp = prefs.getInt('$_keyUserProfile$userId$_keyCacheTimestamp') ?? 0;
      
      if (json == null) return null;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheExpiration) {
        return null;
      }

      return Map<String, dynamic>.from(jsonDecode(json));
    } catch (e) {
      LogService.error('Error getting cached user profile: $e');
      return null;
    }
  }

  /// Get cache timestamp for a key
  static Future<DateTime?> getCacheTimestamp(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('${key}_timestamp') ?? 
                        prefs.getInt('${key}$_keyCacheTimestamp');
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      return null;
    }
  }

  /// Clear all cache
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('cached_') || key.contains('_cache_timestamp')) {
          await prefs.remove(key);
        }
      }
      LogService.success('Cleared all cache');
    } catch (e) {
      LogService.error('Error clearing cache: $e');
    }
  }

  /// Clear cache for a specific user
  static Future<void> clearUserCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.contains(userId) && (key.startsWith('cached_') || key.contains('_cache_timestamp'))) {
          await prefs.remove(key);
        }
      }
      LogService.success('Cleared cache for user: $userId');
    } catch (e) {
      LogService.error('Error clearing user cache: $e');
    }
  }
}





