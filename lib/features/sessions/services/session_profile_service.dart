import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Service to fetch session participant profiles (tutor and learner)
/// Handles both individual_sessions and trial_sessions
class SessionProfileService {
  static final SessionProfileService _instance = SessionProfileService._internal();
  factory SessionProfileService() => _instance;
  SessionProfileService._internal();

  // Cache for profile data
  final Map<String, Map<String, dynamic>> _profileCache = {};

  /// Get both tutor and learner profiles for a session
  /// Returns: {'tutor': {...}, 'learner': {...}}
  Future<Map<String, Map<String, dynamic>?>> getSessionParticipants(String sessionId) async {
    try {
      // First, try individual_sessions
      var session = await SupabaseService.client
          .from('individual_sessions')
          .select('tutor_id, learner_id, parent_id')
          .eq('id', sessionId)
          .maybeSingle();

      String? tutorId;
      String? learnerId;

      if (session != null) {
        tutorId = session['tutor_id'] as String?;
        learnerId = session['learner_id'] as String? ?? session['parent_id'] as String?;
      } else {
        // Try trial_sessions
        var trialSession = await SupabaseService.client
            .from('trial_sessions')
            .select('tutor_id, learner_id, parent_id')
            .eq('id', sessionId)
            .maybeSingle();

        if (trialSession != null) {
          tutorId = trialSession['tutor_id'] as String?;
          learnerId = trialSession['learner_id'] as String? ?? trialSession['parent_id'] as String?;
        }
      }

      if (tutorId == null && learnerId == null) {
        LogService.warning('Session not found: $sessionId');
        return {'tutor': null, 'learner': null};
      }

      // Fetch profiles
      Map<String, dynamic>? tutorProfile;
      Map<String, dynamic>? learnerProfile;

      if (tutorId != null) {
        tutorProfile = await getUserProfile(tutorId);
      }

      if (learnerId != null) {
        learnerProfile = await getUserProfile(learnerId);
      }

      return {
        'tutor': tutorProfile,
        'learner': learnerProfile,
      };
    } catch (e) {
      LogService.error('Error fetching session participants: $e');
      return {'tutor': null, 'learner': null};
    }
  }

  /// Get user profile by ID
  /// Returns profile with: full_name, avatar_url, email, user_type
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    // Check cache first
    if (_profileCache.containsKey(userId)) {
      return _profileCache[userId];
    }

    try {
      // Try to get from profiles table
      var profile = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, avatar_url, email, user_type')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null) {
        // For tutors, also check tutor_profiles for profile_photo_url
        if (profile['user_type'] == 'tutor') {
          var tutorProfile = await SupabaseService.client
              .from('tutor_profiles')
              .select('profile_photo_url')
              .eq('id', userId)
              .maybeSingle();

          if (tutorProfile != null && tutorProfile['profile_photo_url'] != null) {
            profile['avatar_url'] = tutorProfile['profile_photo_url'];
          }
        }

        // Cache the profile
        _profileCache[userId] = profile;
        return profile;
      }

      return null;
    } catch (e) {
      LogService.error('Error fetching user profile: $e');
      return null;
    }
  }

  /// Get avatar URL with fallback
  /// Returns avatar URL or null if not available
  Future<String?> getAvatarUrl(String userId) async {
    final profile = await getUserProfile(userId);
    return profile?['avatar_url'] as String?;
  }

  /// Clear profile cache
  void clearCache() {
    _profileCache.clear();
  }

  /// Clear specific user from cache
  void clearUserCache(String userId) {
    _profileCache.remove(userId);
  }
}

