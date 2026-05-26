
This is how things should flow
I click on pay
if it's onsite or hybrid and i hVE NEVER COMPLETED VERIFICATION, I AM TAKEN TO A MINIMALIST SCREEN THAT SAYS FOR ONSITE SESSIONS, I NEED TO COMPLETE VERIFICATION FOR SECURITY PURPOSESS, LISTING WHAT I WILL NEED TO PROVIDELIKE ID FRONT ANDBACK, MY PICTURE, import 'package:intl/intl.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Roster-derived scheduling fields for **Lesson info** in call (trial vs individual).
class SessionBookingSummary {
  const SessionBookingSummary({
    this.subject,
    this.scheduledDisplay,
    this.durationMinutes,
    this.status,
    this.isTrial = false,
  });

  final String? subject;
  final String? scheduledDisplay;
  final int? durationMinutes;
  final String? status;
  final bool isTrial;
}

/// Tutor/learner profiles plus auth user ids for a session (individual or trial).
///
/// Used to map deterministic Agora UIDs (see [agoraNumericUidForSessionRole]) to names/avatars.
class SessionParticipantBundle {
  const SessionParticipantBundle({
    this.tutorProfile,
    this.learnerProfile,
    this.tutorUserId,
    this.learnerUserId,
  });

  final Map<String, dynamic>? tutorProfile;
  final Map<String, dynamic>? learnerProfile;
  final String? tutorUserId;
  final String? learnerUserId;

  /// Back-compat map shape for callers that only need profiles.
  Map<String, Map<String, dynamic>?> get asProfileMap => {
        'tutor': tutorProfile,
        'learner': learnerProfile,
      };
}

/// Service to fetch session participant profiles (tutor and learner)
/// Handles both individual_sessions and trial_sessions
class SessionProfileService {
  static final SessionProfileService _instance = SessionProfileService._internal();
  factory SessionProfileService() => _instance;
  SessionProfileService._internal();

  // Cache for profile data
  final Map<String, Map<String, dynamic>> _profileCache = {};

  /// Resolve tutor auth user id for a session (individual or trial row).
  Future<String?> getTutorUserIdForSession(String sessionId) async {
    try {
      final session = await SupabaseService.client
          .from('individual_sessions')
          .select('tutor_id')
          .eq('id', sessionId)
          .maybeSingle();

      if (session != null) {
        return session['tutor_id'] as String?;
      }

      final trialSession = await SupabaseService.client
          .from('trial_sessions')
          .select('tutor_id')
          .eq('id', sessionId)
          .maybeSingle();

      return trialSession?['tutor_id'] as String?;
    } catch (e) {
      LogService.warning('[SESSION] getTutorUserIdForSession failed: $e');
      return null;
    }
  }

  /// Profiles and user ids for tutor + learner on this session row.
  Future<SessionParticipantBundle> getSessionParticipants(String sessionId) async {
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
        return const SessionParticipantBundle(
          tutorProfile: null,
          learnerProfile: null,
          tutorUserId: null,
          learnerUserId: null,
        );
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

      return SessionParticipantBundle(
        tutorProfile: tutorProfile,
        learnerProfile: learnerProfile,
        tutorUserId: tutorId,
        learnerUserId: learnerId,
      );
    } catch (e) {
      LogService.error('Error fetching session participants: $e');
      return const SessionParticipantBundle(
        tutorProfile: null,
        learnerProfile: null,
        tutorUserId: null,
        learnerUserId: null,
      );
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

  /// Lightweight booking snapshot for individual or trial lesson rows (no joins).
  Future<SessionBookingSummary?> getSessionBookingSummary(String sessionId) async {
    try {
      final individual = await SupabaseService.client
          .from('individual_sessions')
          .select('subject, scheduled_date, scheduled_time, duration_minutes, status')
          .eq('id', sessionId)
          .maybeSingle();

      if (individual != null) {
        final duration = individual['duration_minutes'] as int?;
        return SessionBookingSummary(
          subject: individual['subject'] as String?,
          scheduledDisplay:
              sessionScheduledDisplayFromParts(individual['scheduled_date'], individual['scheduled_time']),
          durationMinutes: duration,
          status: individual['status'] as String?,
          isTrial: false,
        );
      }

      final trial = await SupabaseService.client
          .from('trial_sessions')
          .select('subject, scheduled_date, scheduled_time, status')
          .eq('id', sessionId)
          .maybeSingle();

      if (trial != null) {
        return SessionBookingSummary(
          subject: trial['subject'] as String?,
          scheduledDisplay:
              sessionScheduledDisplayFromParts(trial['scheduled_date'], trial['scheduled_time']),
          durationMinutes: 30,
          status: trial['status'] as String?,
          isTrial: true,
        );
      }

      return null;
    } catch (e) {
      LogService.warning('[SESSION] getSessionBookingSummary failed: $e');
      return null;
    }
  }
}

/// Shared formatting for roster `scheduled_date` + `scheduled_time` columns.
String? sessionScheduledDisplayFromParts(dynamic dateRaw, dynamic timeRaw) {
  if (dateRaw == null || timeRaw == null) return null;
  final datePart = dateRaw.toString().split('T').first.trim();
  final timePart = timeRaw.toString().trim();
  if (datePart.isEmpty || timePart.isEmpty) return null;
  final merged = DateTime.tryParse(
    '${datePart}T$timePart',
  );
  if (merged != null) {
    return DateFormat('EEE, MMM d · h:mm a').format(merged.toLocal());
  }
  return '$datePart · $timePart';
}

