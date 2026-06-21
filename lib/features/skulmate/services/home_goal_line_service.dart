import 'dart:convert';

import 'package:prepskul/features/skulmate/services/learner_context_service.dart';

/// Learner context for revision push copy — soft goals only, no exam board labels.
class HomeGoalLineService {
  HomeGoalLineService._();

  /// Dynamic notification body (title is fixed hero question).
  static Future<String> notificationBody({
    required bool french,
    required int streakCount,
    String? childId,
  }) async {
    final focus = await _learnerFocusPhrase(childId: childId);
    if (focus != null && focus.isNotEmpty) {
      return french
          ? 'Reprends $focus — quelques minutes suffisent.'
          : 'Pick up $focus — a few minutes is enough.';
    }

    if (streakCount > 0) {
      return french
          ? 'Garde ta série de $streakCount jour${streakCount > 1 ? 's' : ''} — une courte révision aujourd\'hui.'
          : 'Keep your $streakCount-day streak — a quick revision today.';
    }

    return french
        ? 'Quelques minutes aujourd\'hui, et tu restes sur la bonne voie.'
        : 'A few minutes today keeps you on track.';
  }

  static Future<String?> _learnerFocusPhrase({String? childId}) async {
    final context = await LearnerContextService.build(childId: childId);
    if (context == null) return null;

    final goal = _firstGoalPhrase(context['learning_goals']);
    if (goal != null) {
      final sanitized = _sanitizeForLearner(goal);
      if (sanitized.isNotEmpty) return sanitized.toLowerCase();
    }

    final subject = _firstSubject(context['subjects']);
    if (subject != null) return subject.toLowerCase();

    final pathLabel = _softPathFocus(context['learning_goals'], french: false);
    if (pathLabel != null) return pathLabel;

    return null;
  }

  static String? _firstGoalPhrase(dynamic raw) {
    final items = _asStringList(raw);
    if (items.isEmpty) return null;
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static String? _firstSubject(dynamic raw) {
    final items = _asStringList(raw);
    if (items.isEmpty) return null;
    for (final item in items) {
      final trimmed = _titleCase(_sanitizeForLearner(item));
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static List<String> _asStringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return const [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    if (text.contains(',')) {
      return text.split(',').map((s) => s.trim()).toList();
    }
    return [text];
  }

  static String? _softPathFocus(dynamic raw, {required bool french}) {
    final blob = _asStringList(raw).join(' ').toLowerCase();
    if (blob.isEmpty) return null;

    if (blob.contains('skill') || blob.contains('coding') || blob.contains('tech')) {
      return french ? 'tes compétences' : 'your skills';
    }
    if (blob.contains('hobby') || blob.contains('fun')) {
      return french ? 'ton apprentissage' : 'your learning';
    }
    if (blob.contains('school') ||
        blob.contains('exam') ||
        blob.contains('revision') ||
        blob.contains('révision')) {
      return french ? 'tes révisions' : 'your revision';
    }
    return null;
  }

  static String _sanitizeForLearner(String input) {
    var text = input.trim();
    if (text.isEmpty) return '';

    final examStrip = RegExp(
      r'\b(gce|waec|bepc|probatoire|bac|sat|ielts|toefl|o[\s.-]?level|a[\s.-]?level|jamb|neco|niveau\s*o|niveau\s*a)\b',
      caseSensitive: false,
    );
    text = text.replaceAll(examStrip, '').trim();
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    text = text.replaceAll(RegExp(r'^[\s,.-]+|[\s,.-]+$'), '');
    return text;
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
