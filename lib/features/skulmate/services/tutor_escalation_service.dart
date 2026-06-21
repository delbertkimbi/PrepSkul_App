import 'package:shared_preferences/shared_preferences.dart';

import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'concept_mastery_service.dart';
import 'active_tutor_service.dart';

/// Phase C5 — optional tutor help after real struggle (never pushy).
class TutorEscalationService {
  TutorEscalationService._();

  static const _dismissPrefix = 'skulmate_tutor_escalation_dismiss_';
  static const _weeklyKey = 'skulmate_tutor_escalation_week';
  static const dismissDays = 14;
  static const maxOffersPerWeek = 1;
  static const minAttempts = 3;
  static const roughSessionThreshold = 0.55;

  /// Offer tutor help only after a rough round + sustained topic struggle.
  static Future<bool> shouldOfferForSession({
    required String gameId,
    required int correctAnswers,
    required int totalQuestions,
    String? childId,
  }) async {
    if (gameId.isEmpty || totalQuestions <= 0) return false;

    final sessionAccuracy = correctAnswers / totalQuestions;
    if (sessionAccuracy >= roughSessionThreshold) return false;

    final tutorStatus = await ActiveTutorService.check();
    if (tutorStatus.hasActiveTutor) return false;

    if (!await _hasWeeklyBudget()) return false;

    final topicIds = await _topicIdsForGame(gameId);
    if (topicIds.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    for (final topicId in topicIds) {
      if (topicId == 'open:general') continue;
      if (_isDismissed(prefs, topicId, now)) continue;

      final row = await _masteryRow(
        topicId: topicId,
        childId: childId,
      );
      if (_isSustainedStruggleAfterSession(
        row: row,
        sessionAccuracy: sessionAccuracy,
      )) {
        return true;
      }
    }

    return false;
  }

  /// Project post-session mastery so we don't race [saveGameSession].
  static bool _isSustainedStruggleAfterSession({
    required Map<String, dynamic>? row,
    required double sessionAccuracy,
  }) {
    const emaAlpha = 0.3;
    const weakSessionThreshold = 0.6;

    final previousAttempts = (row?['attempts'] as num?)?.toInt() ?? 0;
    final attempts = previousAttempts + 1;
    if (attempts < minAttempts) return false;

    final previousScore = (row?['mastery_score'] as num?)?.toDouble() ?? 0;
    final previousWeakStreak = (row?['weak_streak'] as num?)?.toInt() ?? 0;

    final masteryScore = previousAttempts <= 0
        ? sessionAccuracy
        : (1 - emaAlpha) * previousScore + emaAlpha * sessionAccuracy;

    final weakStreak = sessionAccuracy < weakSessionThreshold
        ? previousWeakStreak + 1
        : 0;

    return weakStreak >= 2 || (attempts >= 4 && masteryScore < 0.42);
  }

  static Future<void> dismissForGame(String gameId) async {
    final topicIds = await _topicIdsForGame(gameId);
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(const Duration(days: dismissDays));
    for (final topicId in topicIds) {
      await prefs.setString(
        '$_dismissPrefix$topicId',
        until.toIso8601String(),
      );
    }
  }

  static Future<void> markOffered(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final week = _isoWeekKey(DateTime.now());
      final topicIds = await _topicIdsForGame(gameId);
      final primary = topicIds.isNotEmpty ? topicIds.first : gameId;
      final topicKey = 'skulmate_tutor_escalation_seen_${week}_$primary';
      if (prefs.getBool(topicKey) == true) return;

      await prefs.setBool(topicKey, true);
      final storedWeek = prefs.getString(_weeklyKey);
      if (storedWeek == week) {
        await prefs.setInt('${_weeklyKey}_count', _weeklyCount(prefs) + 1);
      } else {
        await prefs.setString(_weeklyKey, week);
        await prefs.setInt('${_weeklyKey}_count', 1);
      }
    } catch (e) {
      LogService.debug('TutorEscalationService.markOffered: $e');
    }
  }

  static Future<List<String>> _topicIdsForGame(String gameId) async {
    try {
      final row = await SupabaseService.client
          .from('skulmate_games')
          .select('generation_context')
          .eq('id', gameId)
          .maybeSingle();
      if (row == null) return const [];
      final ctx = row['generation_context'];
      if (ctx is Map) {
        return ConceptMasteryService.resolveTopicIds(
          ctx.cast<String, dynamic>(),
        );
      }
    } catch (e) {
      LogService.debug('TutorEscalationService._topicIdsForGame: $e');
    }
    return const [];
  }

  static Future<Map<String, dynamic>?> _masteryRow({
    required String topicId,
    String? childId,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      var query = SupabaseService.client
          .from('skulmate_concept_mastery')
          .select(
            'topic_id, attempts, weak_streak, mastery_score',
          )
          .eq('user_id', userId)
          .eq('topic_id', topicId);

      if (childId != null) {
        query = query.eq('child_id', childId);
      } else {
        query = query.filter('child_id', 'is', null);
      }

      return await query.maybeSingle();
    } catch (e) {
      return null;
    }
  }

  static bool _isDismissed(
    SharedPreferences prefs,
    String topicId,
    DateTime now,
  ) {
    final raw = prefs.getString('$_dismissPrefix$topicId');
    if (raw == null) return false;
    final until = DateTime.tryParse(raw);
    if (until == null) return false;
    return now.isBefore(until);
  }

  static Future<bool> _hasWeeklyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final week = _isoWeekKey(DateTime.now());
    final storedWeek = prefs.getString(_weeklyKey);
    if (storedWeek != week) return true;
    return _weeklyCount(prefs) < maxOffersPerWeek;
  }

  static int _weeklyCount(SharedPreferences prefs) =>
      prefs.getInt('${_weeklyKey}_count') ?? 0;

  static String _isoWeekKey(DateTime dt) {
    final thursday = dt.add(Duration(days: 3 - ((dt.weekday + 6) % 7)));
    final yearStart = DateTime(thursday.year);
    final week =
        ((thursday.difference(yearStart).inDays) / 7).floor() + 1;
    return '${thursday.year}-W$week';
  }
}
