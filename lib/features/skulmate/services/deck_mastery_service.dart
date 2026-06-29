import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import 'concept_mastery_service.dart';
import 'spaced_repetition_service.dart';

/// Path A — mastery + due-review snapshot for a single deck/game.
class DeckMasterySnapshot {
  final int? masteryPercent;
  final String bandLabel;
  final Color bandColor;
  final int dueReviewCount;

  const DeckMasterySnapshot({
    required this.masteryPercent,
    required this.bandLabel,
    required this.bandColor,
    required this.dueReviewCount,
  });

  static const empty = DeckMasterySnapshot(
    masteryPercent: null,
    bandLabel: 'New',
    bandColor: AppTheme.textMedium,
    dueReviewCount: 0,
  );

  bool get hasMastery => masteryPercent != null;
  bool get hasDueReviews => dueReviewCount > 0;
}

class DeckMasteryService {
  DeckMasteryService._();

  static String bandLabelForScore(double? score) {
    if (score == null) return 'New';
    if (score >= 0.75) return 'Solid';
    if (score >= 0.5) return 'Building';
    return 'Needs work';
  }

  static Color bandColorForScore(double? score) {
    if (score == null) return AppTheme.textMedium;
    if (score >= 0.75) return AppTheme.accentGreen;
    if (score >= 0.5) return AppTheme.skyBlue;
    return AppTheme.accentOrange;
  }

  static int? percentForScore(double? score) {
    if (score == null) return null;
    return (score.clamp(0.0, 1.0) * 100).round();
  }

  static DeckMasterySnapshot snapshotFromScore({
    required double? score,
    required int dueReviewCount,
  }) {
    return DeckMasterySnapshot(
      masteryPercent: percentForScore(score),
      bandLabel: bandLabelForScore(score),
      bandColor: bandColorForScore(score),
      dueReviewCount: dueReviewCount,
    );
  }

  static Future<DeckMasterySnapshot> forGame({
    required String gameId,
    String? childId,
    Map<String, dynamic>? generationContext,
  }) async {
    if (gameId.isEmpty) return DeckMasterySnapshot.empty;

    try {
      final dueQueue = await SpacedRepetitionService.fetchDueQueue(
        limit: 50,
        childId: childId,
      );
      final dueCount =
          dueQueue.where((item) => item.gameId == gameId).length;

      final score = await _masteryScoreForGame(
        gameId: gameId,
        childId: childId,
        generationContext: generationContext,
      );

      return snapshotFromScore(score: score, dueReviewCount: dueCount);
    } catch (e) {
      LogService.debug('DeckMasteryService.forGame: $e');
      return DeckMasterySnapshot.empty;
    }
  }

  static Future<double?> _masteryScoreForGame({
    required String gameId,
    required String? childId,
    Map<String, dynamic>? generationContext,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;

    var byGameQuery = SupabaseService.client
        .from('skulmate_concept_mastery')
        .select('mastery_score, attempts')
        .eq('user_id', userId)
        .eq('last_game_id', gameId);

    if (childId != null) {
      byGameQuery = byGameQuery.eq('child_id', childId);
    } else {
      byGameQuery = byGameQuery.filter('child_id', 'is', null);
    }

    final byGame = await byGameQuery.limit(5);
    if (byGame.isNotEmpty) {
      return _averageMasteryScore(byGame);
    }

    final topicIds = ConceptMasteryService.resolveTopicIds(generationContext);
    if (topicIds.isEmpty) return null;

    var byTopicQuery = SupabaseService.client
        .from('skulmate_concept_mastery')
        .select('mastery_score, attempts')
        .eq('user_id', userId)
        .inFilter('topic_id', topicIds);

    if (childId != null) {
      byTopicQuery = byTopicQuery.eq('child_id', childId);
    } else {
      byTopicQuery = byTopicQuery.filter('child_id', 'is', null);
    }

    final byTopic = await byTopicQuery.limit(5);
    if (byTopic.isEmpty) return null;
    return _averageMasteryScore(byTopic);
  }

  static double? _averageMasteryScore(List<dynamic> rows) {
    final scores = rows
        .map((row) => (row['mastery_score'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }
}
