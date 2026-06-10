import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/utils/tutor_display_name_utils.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';

/// Lightweight upcoming session for home hero and timeline.
class UpcomingSessionItem {
  final String id;
  final String tutorName;
  final String? tutorAvatarUrl;
  final String subject;
  final DateTime scheduledStart;
  final String scheduledDate;
  final String scheduledTime;
  final String location;
  final String status;
  final bool isTrial;
  final Map<String, dynamic> sessionMap;

  const UpcomingSessionItem({
    required this.id,
    required this.tutorName,
    this.tutorAvatarUrl,
    required this.subject,
    required this.scheduledStart,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.location,
    required this.status,
    required this.isTrial,
    required this.sessionMap,
  });

  static UpcomingSessionItem? fromIndividualMap(Map<String, dynamic> session) {
    final date = session['scheduled_date'] as String?;
    if (date == null || date.isEmpty) return null;
    var time = session['scheduled_time'] as String?;
    if (time == null || time.trim().isEmpty) {
      time = '00:00:00';
    }

    final recurring = session['recurring_sessions'] as Map<String, dynamic>?;
    final subject = recurring?['subject'] as String? ?? 'Session';
    final tutorName = _resolveTutorName(recurring);
    final avatar = recurring?['tutor_avatar_url'] as String?;

    late final DateTime start;
    try {
      final dateTime = DateTime.parse(date);
      final parts = time.split(':');
      if (parts.length >= 2) {
        start = DateTime(
          dateTime.year,
          dateTime.month,
          dateTime.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      } else {
        start = dateTime;
      }
    } catch (_) {
      return null;
    }
    return UpcomingSessionItem(
      id: session['id'] as String,
      tutorName: tutorName,
      tutorAvatarUrl: avatar,
      subject: subject,
      scheduledStart: start,
      scheduledDate: date,
      scheduledTime: time,
      location: session['location'] as String? ?? 'online',
      status: session['status'] as String? ?? 'scheduled',
      isTrial: false,
      sessionMap: Map<String, dynamic>.from(session),
    );
  }

  static UpcomingSessionItem? fromTrial(TrialSession trial, {String? tutorName}) {
    DateTime start;
    try {
      final parts = trial.scheduledTime.split(':');
      start = DateTime(
        trial.scheduledDate.year,
        trial.scheduledDate.month,
        trial.scheduledDate.day,
        parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
        parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      );
    } catch (_) {
      start = trial.scheduledDate;
    }

    final dateStr = trial.scheduledDate.toIso8601String().split('T').first;
    final recurring = {
      'tutor_name': tutorName,
      'tutor_id': trial.tutorId,
      'subject': trial.subject,
    };
    final name = _resolveTutorName(recurring);

    return UpcomingSessionItem(
      id: trial.id,
      tutorName: name,
      tutorAvatarUrl: null,
      subject: trial.subject,
      scheduledStart: start,
      scheduledDate: dateStr,
      scheduledTime: trial.scheduledTime,
      location: trial.location,
      status: trial.status,
      isTrial: true,
      sessionMap: {
        'id': trial.id,
        'type': 'trial',
        'scheduled_date': dateStr,
        'scheduled_time': trial.scheduledTime,
        'duration_minutes': trial.durationMinutes,
        'location': trial.location,
        'status': trial.status,
        'recurring_sessions': {
          'subject': trial.subject,
          'tutor_name': name,
          'tutor_id': trial.tutorId,
        },
        'trial_sessions': {
          'tutor_id': trial.tutorId,
          'learner_id': trial.learnerId,
        },
      },
    );
  }

  /// Build from a session detail map shown on SessionDetailScreen.
  static UpcomingSessionItem? fromSessionDetailMap(Map<String, dynamic> session) {
    final recurring = session['recurring_sessions'] as Map<String, dynamic>?;
    final date = session['scheduled_date'] as String?;
    final time = session['scheduled_time'] as String?;
    if (date == null || time == null) return null;

    DateTime? start;
    try {
      final dateTime = DateTime.parse(date);
      final parts = time.split(':');
      start = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
        parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
        parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      );
    } catch (_) {
      return null;
    }

    final isTrial = session['type'] == 'trial';
    final subject = recurring?['subject'] as String? ?? 'Session';
    final tutorName = _resolveTutorName(recurring);

    return UpcomingSessionItem(
      id: session['id'] as String,
      tutorName: tutorName,
      tutorAvatarUrl: recurring?['tutor_avatar_url'] as String?,
      subject: subject,
      scheduledStart: start,
      scheduledDate: date,
      scheduledTime: time,
      location: session['location'] as String? ?? 'online',
      status: session['status'] as String? ?? 'scheduled',
      isTrial: isTrial,
      sessionMap: Map<String, dynamic>.from(session),
    );
  }

  static String _resolveTutorName(
    Map<String, dynamic>? recurring, {
    Map<String, dynamic>? profile,
    Map<String, dynamic>? tutorProfile,
  }) {
    if (recurring == null) return 'PrepSkul Tutor';
    final subject = recurring['subject']?.toString().trim();
    final stored = recurring['tutor_name']?.toString().trim();
    if (!TutorDisplayNameUtils.isInvalidStoredName(stored, subject: subject)) {
      return stored!;
    }

    final tutorId = recurring['tutor_id']?.toString() ?? '';
    if (profile != null || tutorProfile != null) {
      final tutorMap = <String, dynamic>{
        'user_id': tutorId,
        if (tutorProfile != null) ...tutorProfile,
      };
      final resolved = TutorDisplayNameUtils.resolve(tutorMap, profile);
      if (!TutorDisplayNameUtils.isInvalidStoredName(resolved, subject: subject)) {
        return TutorDisplayNameUtils.cardLabel(tutorMap, profile);
      }
    }

    return 'PrepSkul Tutor';
  }

  /// Replace bad stored tutor_name values with profile-backed names.
  static Future<List<UpcomingSessionItem>> enrichWithTutorProfiles(
    List<UpcomingSessionItem> items,
  ) async {
    if (items.isEmpty) return items;

    final tutorIds = <String>{};
    for (final item in items) {
      final recurring = item.sessionMap['recurring_sessions'] as Map<String, dynamic>?;
      final tid = recurring?['tutor_id']?.toString() ??
          item.sessionMap['tutor_id']?.toString();
      if (tid != null && tid.isNotEmpty) tutorIds.add(tid);
    }
    if (tutorIds.isEmpty) return items;

    try {
      final profilesResponse = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, avatar_url, email')
          .inFilter('id', tutorIds.toList());

      final profilesById = <String, Map<String, dynamic>>{};
      for (final row in (profilesResponse as List).cast<Map<String, dynamic>>()) {
        final id = row['id']?.toString();
        if (id != null) profilesById[id] = row;
      }

      Map<String, Map<String, dynamic>> tutorProfilesById = {};
      try {
        final tutorRows = await SupabaseService.client
            .from('tutor_profiles')
            .select('user_id, personal_statement, bio, motivation')
            .inFilter('user_id', tutorIds.toList());
        for (final row in (tutorRows as List).cast<Map<String, dynamic>>()) {
          final id = row['user_id']?.toString();
          if (id != null) tutorProfilesById[id] = row;
        }
      } catch (_) {
        // tutor_profiles optional for name resolution
      }

      return items.map((item) {
        final sessionMap = Map<String, dynamic>.from(item.sessionMap);
        final recurring = Map<String, dynamic>.from(
          (sessionMap['recurring_sessions'] as Map<String, dynamic>?) ?? {},
        );
        final tutorId = recurring['tutor_id']?.toString() ??
            sessionMap['tutor_id']?.toString();
        if (tutorId == null || tutorId.isEmpty) return item;

        final profile = profilesById[tutorId];
        final tutorProfile = tutorProfilesById[tutorId];
        final resolved = _resolveTutorName(
          recurring,
          profile: profile,
          tutorProfile: tutorProfile,
        );
        final avatar =
            profile?['avatar_url'] as String? ?? item.tutorAvatarUrl;

        recurring['tutor_name'] = resolved;
        if (avatar != null && avatar.isNotEmpty) {
          recurring['tutor_avatar_url'] = avatar;
        }
        sessionMap['recurring_sessions'] = recurring;

        return UpcomingSessionItem(
          id: item.id,
          tutorName: resolved,
          tutorAvatarUrl: avatar,
          subject: item.subject,
          scheduledStart: item.scheduledStart,
          scheduledDate: item.scheduledDate,
          scheduledTime: item.scheduledTime,
          location: item.location,
          status: item.status,
          isTrial: item.isTrial,
          sessionMap: sessionMap,
        );
      }).toList();
    } catch (e) {
      LogService.debug('UpcomingSessionItem profile enrich failed: $e');
      return items;
    }
  }

  static List<UpcomingSessionItem> mergeAndSort({
    required List<Map<String, dynamic>> individual,
    required List<TrialSession> trials,
  }) {
    final items = <UpcomingSessionItem>[];
    for (final s in individual) {
      final item = fromIndividualMap(s);
      if (item != null) items.add(item);
    }
    for (final t in trials) {
      final status = t.status.toLowerCase();
      if (status != 'approved' && status != 'scheduled' && status != 'in_progress') {
        continue;
      }
      final item = fromTrial(t);
      if (item != null) items.add(item);
    }
    items.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    return items;
  }
}
