import 'session_date_utils.dart';

/// Shared rules for when a session should be treated as genuinely live in the UI.
class SessionLiveUtils {
  static const int earlyJoinMinutes = 15;
  static const int graceMinutes = 20;
  static const int maxDurationMinutes = 180;

  static DateTime? parseStartedAt(Map<String, dynamic> session) {
    final raw = session['session_started_at'];
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  static DateTime? parseScheduledStart(Map<String, dynamic> session) {
    final date = session['scheduled_date'] as String?;
    final time = session['scheduled_time'] as String?;
    if (date == null || time == null) return null;
    return SessionDateUtils.parseScheduledStart(date, time);
  }

  static int durationMinutes(Map<String, dynamic> session) {
    final raw = session['duration_minutes'];
    final parsed = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (parsed == null || parsed <= 0) return 60;
    return parsed.clamp(1, maxDurationMinutes);
  }

  static DateTime? scheduledEnd(Map<String, dynamic> session) {
    final start = parseScheduledStart(session);
    if (start == null) return null;
    return start.add(Duration(minutes: durationMinutes(session)));
  }

  /// True only when status is in_progress, the tutor started the session, and
  /// the current time is inside the scheduled join window.
  static bool isSessionGenuinelyLive(Map<String, dynamic> session) {
    if (session['status']?.toString() != 'in_progress') return false;

    final startedAt = parseStartedAt(session);
    if (startedAt == null) return false;

    final now = DateTime.now();
    final scheduledStart = parseScheduledStart(session);
    final scheduledEndTime = scheduledEnd(session);
    final duration = durationMinutes(session);

    if (scheduledStart != null) {
      final earliestJoin = scheduledStart.subtract(
        const Duration(minutes: earlyJoinMinutes),
      );
      if (now.isBefore(earliestJoin)) return false;
    }

    if (scheduledEndTime != null) {
      final latestBySchedule = scheduledEndTime.add(
        const Duration(minutes: graceMinutes),
      );
      if (now.isAfter(latestBySchedule)) return false;
    }

    final latestByStartedAt = startedAt.add(
      Duration(minutes: duration + graceMinutes),
    );
    if (now.isAfter(latestByStartedAt)) return false;

    if (now.difference(startedAt).inHours > 12) return false;

    return true;
  }

  /// Effective status for UI — stale in_progress rows fall back to scheduled.
  static String effectiveStatus(Map<String, dynamic> session) {
    final status = session['status']?.toString() ?? 'scheduled';
    if (status == 'in_progress' && !isSessionGenuinelyLive(session)) {
      final end = scheduledEnd(session);
      if (end != null && DateTime.now().isAfter(end)) {
        return 'completed';
      }
      return 'scheduled';
    }
    return status;
  }

  static bool showsLiveUi(Map<String, dynamic> session) =>
      isSessionGenuinelyLive(session);

  /// Session-state chip label for home cards and heroes.
  static String displayStatusBadge(Map<String, dynamic> session) =>
      isSessionGenuinelyLive(session) ? 'LIVE' : 'Upcoming';
}
