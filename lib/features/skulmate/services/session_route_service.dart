import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'skulmate_session_intake_service.dart';

/// Maps M4 — latest tutor session summary → home revision focus.
class SessionRouteSuggestion {
  final String sessionId;
  final String tutorName;
  final String subject;
  final String focusPhrase;
  final String summary;

  const SessionRouteSuggestion({
    required this.sessionId,
    required this.tutorName,
    required this.subject,
    required this.focusPhrase,
    required this.summary,
  });
}

class SessionRouteService {
  SessionRouteService._();

  static const _dismissPrefix = 'skulmate_session_route_dismiss_';
  static const dismissDays = 7;

  static Future<SessionRouteSuggestion?> evaluate({String? childId}) async {
    final rows = await SkulMateSessionIntakeService.loadRecordedSessions(
      childId: childId,
      limit: 3,
    );
    if (rows.isEmpty) return null;

    for (final row in rows) {
      final sessionId = row['id']?.toString() ?? '';
      if (sessionId.isEmpty) continue;
      if (await _isDismissed(sessionId)) continue;

      final summary = row['session_summary']?.toString().trim() ?? '';
      if (summary.isEmpty) continue;

      final recurring = row['recurring_sessions'] as Map<String, dynamic>?;
      final tutorName =
          recurring?['tutor_name']?.toString().trim() ?? 'your tutor';
      final subject = recurring?['subject']?.toString().trim() ?? '';
      final focus = _extractFocusPhrase(summary);
      if (focus.isEmpty) continue;

      return SessionRouteSuggestion(
        sessionId: sessionId,
        tutorName: tutorName,
        subject: subject,
        focusPhrase: focus,
        summary: summary,
      );
    }
    return null;
  }

  static Future<void> dismiss(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_dismissPrefix$sessionId',
      DateTime.now().add(const Duration(days: dismissDays)).toIso8601String(),
    );
  }

  static Future<bool> _isDismissed(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_dismissPrefix$sessionId');
    if (raw == null) return false;
    final until = DateTime.tryParse(raw);
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  /// Pull 1–2 short focus phrases from a session summary (no LLM).
  @visibleForTesting
  static String extractFocusPhrase(String summary) => _extractFocusPhrase(summary);

  static String _extractFocusPhrase(String summary) {
    for (final line in summary.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      final bullet = RegExp(r'^[-•*]\s*(.+)$').firstMatch(trimmed);
      if (bullet != null) {
        final phrase = bullet.group(1)?.trim() ?? '';
        if (phrase.length >= 8) return _clip(phrase);
      }
    }

    final normalized = summary.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '';

    final sentences = normalized.split(RegExp(r'(?<=[.!?])\s+'));
    for (final sentence in sentences) {
      final s = sentence.trim();
      if (s.length >= 12) return _clip(s);
    }

    return _clip(normalized);
  }

  static String _clip(String text, {int max = 96}) {
    if (text.length <= max) return text;
    return '${text.substring(0, max - 1).trim()}…';
  }
}
