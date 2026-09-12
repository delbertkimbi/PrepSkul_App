import 'session_live_utils.dart';

/// Dual-column participant lookup + upcoming list classification.
class UpcomingSessionMerge {
  static bool isMissingParticipantColumnError(Object error) {
    final text = error.toString();
    final mentionsColumn = text.contains('individual_session_id') ||
        text.contains('session_id');
    if (!mentionsColumn) return false;
    return text.contains('42703') ||
        text.contains('PGRST204') ||
        text.contains('schema cache') ||
        text.contains('does not exist') ||
        text.contains('Could not find');
  }

  static String? sessionIdFromParticipantRow(Map<String, dynamic> row) {
    for (final key in const ['session_id', 'individual_session_id']) {
      final value = row[key]?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    final nested = row['individual_sessions'];
    if (nested is Map<String, dynamic>) {
      final id = nested['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  /// Keep paid/live rows My Sessions should show, including in-progress
  /// sessions that have not actually ended yet.
  static bool includeInUpcomingList(
    Map<String, dynamic> session, {
    required DateTime now,
    DateTime? Function(Map<String, dynamic>)? parseStart,
  }) {
    final status = (session['status'] as String? ?? '').toLowerCase();
    if (status == 'in_progress') {
      if (SessionLiveUtils.isSessionGenuinelyLive(session)) return true;
      return SessionLiveUtils.effectiveStatus(session) == 'scheduled';
    }
    final start = parseStart?.call(session) ??
        SessionLiveUtils.parseScheduledStart(session);
    if (start == null) return true;
    return !start.isBefore(now);
  }
}
