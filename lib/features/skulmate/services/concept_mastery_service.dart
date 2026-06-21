import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Records per-topic mastery after game sessions (Phase C — background signal).
class ConceptMasteryService {
  static const _weakSessionThreshold = 0.6;
  static const _emaAlpha = 0.3;

  static List<String> resolveTopicIds(Map<String, dynamic>? generationContext) {
    if (generationContext == null || generationContext.isEmpty) {
      return const ['open:general'];
    }

    final alignment = generationContext['curriculumAlignment'];
    if (alignment is Map) {
      final matched = alignment['matchedTopicIds'];
      if (matched is List && matched.isNotEmpty) {
        return matched.map((e) => e.toString()).toList();
      }
    }

    final topic = generationContext['topic'];
    if (topic is String && topic.trim().isNotEmpty) {
      final slug = topic
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final clipped = slug.length > 48 ? slug.substring(0, 48) : slug;
      return ['open:${clipped.isEmpty ? 'topic' : clipped}'];
    }

    return const ['open:general'];
  }

  static String? resolveFrameworkId(Map<String, dynamic>? generationContext) {
    final alignment = generationContext?['curriculumAlignment'];
    if (alignment is Map) {
      final id = alignment['frameworkId'];
      if (id is String && id.isNotEmpty) return id;
    }
    return 'open_learning';
  }

  static Future<void> recordSessionForGame({
    required String gameId,
    required int correctAnswers,
    required int totalQuestions,
  }) async {
    if (gameId.isEmpty || totalQuestions <= 0) return;

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;

      final gameRow = await SupabaseService.client
          .from('skulmate_games')
          .select('child_id, generation_context')
          .eq('id', gameId)
          .maybeSingle();

      if (gameRow == null) return;

      final generationContext = gameRow['generation_context'];
      final contextMap = generationContext is Map
          ? generationContext.cast<String, dynamic>()
          : null;
      final topicIds = resolveTopicIds(contextMap);
      final frameworkId = resolveFrameworkId(contextMap);
      final childId = gameRow['child_id'] as String?;

      for (final topicId in topicIds) {
        await _upsertTopicMastery(
          userId: userId,
          childId: childId,
          topicId: topicId,
          frameworkId: frameworkId,
          gameId: gameId,
          correctAnswers: correctAnswers,
          totalQuestions: totalQuestions,
        );
      }
    } catch (e) {
      LogService.debug('ConceptMasteryService: skipped ($e)');
    }
  }

  /// Raw mastery rows for reroute evaluation (client applies strict policy).
  static Future<List<Map<String, dynamic>>> fetchMasteryCandidates({
    int limit = 8,
    String? childId,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      var query = SupabaseService.client
          .from('skulmate_concept_mastery')
          .select(
            'topic_id, framework_id, mastery_score, weak_streak, attempts, last_seen_at, last_game_id',
          )
          .eq('user_id', userId)
          .gte('attempts', 3);

      if (childId != null) {
        query = query.eq('child_id', childId);
      } else {
        query = query.filter('child_id', 'is', null);
      }

      final rows = await query
          .order('weak_streak', ascending: false)
          .order('mastery_score', ascending: true)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      LogService.debug('ConceptMasteryService.fetchMasteryCandidates: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchWeakTopics({
    int limit = 5,
    String? childId,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      var query = SupabaseService.client
          .from('skulmate_concept_mastery')
          .select(
            'topic_id, framework_id, mastery_score, weak_streak, last_seen_at',
          )
          .eq('user_id', userId)
          .or('weak_streak.gte.2,mastery_score.lt.0.55');

      if (childId != null) {
        query = query.eq('child_id', childId);
      } else {
        query = query.filter('child_id', 'is', null);
      }

      final rows = await query
          .order('weak_streak', ascending: false)
          .order('mastery_score', ascending: true)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      LogService.debug('ConceptMasteryService.fetchWeakTopics: $e');
      return [];
    }
  }

  static Future<void> _upsertTopicMastery({
    required String userId,
    required String? childId,
    required String topicId,
    required String? frameworkId,
    required String gameId,
    required int correctAnswers,
    required int totalQuestions,
  }) async {
    var existingQuery = SupabaseService.client
        .from('skulmate_concept_mastery')
        .select(
          'id, mastery_score, attempts, correct_total, question_total, weak_streak',
        )
        .eq('user_id', userId)
        .eq('topic_id', topicId);

    if (childId != null) {
      existingQuery = existingQuery.eq('child_id', childId);
    } else {
      existingQuery = existingQuery.filter('child_id', 'is', null);
    }

    final existing = await existingQuery.maybeSingle();
    final sessionAccuracy = (correctAnswers / totalQuestions).clamp(0.0, 1.0);

    final previousScore =
        (existing?['mastery_score'] as num?)?.toDouble() ?? 0;
    final previousAttempts = (existing?['attempts'] as num?)?.toInt() ?? 0;
    final previousWeakStreak =
        (existing?['weak_streak'] as num?)?.toInt() ?? 0;

    final masteryScore = previousAttempts <= 0
        ? sessionAccuracy
        : (1 - _emaAlpha) * previousScore + _emaAlpha * sessionAccuracy;

    final weakStreak = sessionAccuracy < _weakSessionThreshold
        ? previousWeakStreak + 1
        : 0;

    final payload = {
      'user_id': userId,
      'child_id': childId,
      'topic_id': topicId,
      'framework_id': frameworkId,
      'mastery_score': double.parse(masteryScore.toStringAsFixed(4)),
      'attempts': previousAttempts + 1,
      'correct_total':
          ((existing?['correct_total'] as num?)?.toInt() ?? 0) + correctAnswers,
      'question_total':
          ((existing?['question_total'] as num?)?.toInt() ?? 0) + totalQuestions,
      'weak_streak': weakStreak,
      'last_session_accuracy':
          double.parse(sessionAccuracy.toStringAsFixed(4)),
      'last_game_id': gameId,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (existing?['id'] != null) {
      await SupabaseService.client
          .from('skulmate_concept_mastery')
          .update(payload)
          .eq('id', existing!['id'] as String);
    } else {
      await SupabaseService.client
          .from('skulmate_concept_mastery')
          .insert(payload);
    }
  }
}
