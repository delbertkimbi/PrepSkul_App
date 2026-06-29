import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

import 'concept_mastery_service.dart';
import 'deck_library_service.dart';
import 'learner_context_service.dart';
import 'skulmate_session_history_service.dart';
import 'skulmate_service.dart';
import 'tutor_escalation_service.dart';

/// Unified learner intelligence — profile + mastery + deck history for all AI calls.
class LearnerIntelligenceService {
  LearnerIntelligenceService._();

  static Future<Map<String, dynamic>?> build({
    String? childId,
    String? gameId,
    String? activeDeckTitle,
    String? deckStudyMode,
    String? refinement,
    int tutorFollowUpCount = 0,
  }) async {
    try {
      final base = await LearnerContextService.build(childId: childId) ?? {};
      final signals = <String, dynamic>{};

      var followUps = tutorFollowUpCount;
      if (followUps <= 0 && gameId != null && gameId.isNotEmpty) {
        followUps = await SkulMateSessionHistoryService.tutorFollowUpCount(
          gameId,
        );
      }

      final weakRows = await ConceptMasteryService.fetchWeakTopics(
        limit: 4,
        childId: childId,
      );
      if (weakRows.isNotEmpty) {
        signals['weakTopics'] = weakRows
            .map(
              (row) => {
                'topicId': row['topic_id']?.toString(),
                'masteryScore': (row['mastery_score'] as num?)?.toDouble(),
                'weakStreak': (row['weak_streak'] as num?)?.toInt(),
              },
            )
            .toList();
      }

      try {
        final games = await SkulMateService.getCachedGames(childId: childId);
        if (games.isNotEmpty) {
          final decks = await DeckLibraryService.listDecks(
            childId: childId,
            games: games,
          );
          if (decks.isNotEmpty) {
            signals['recentDeckTitles'] =
                decks.take(6).map((d) => d.title).toList();
          }
        }
      } catch (_) {}

      if (activeDeckTitle != null && activeDeckTitle.trim().isNotEmpty) {
        signals['studyingDeckTitle'] = activeDeckTitle.trim();
      }
      if (deckStudyMode != null && deckStudyMode.isNotEmpty) {
        signals['deckStudyMode'] = deckStudyMode;
      }
      if (refinement != null && refinement.trim().isNotEmpty) {
        signals['studyRefinement'] = refinement.trim();
      }
      if (followUps > 0) {
        signals['tutorFollowUpCount'] = followUps;
        signals['needsHumanTutorHint'] =
            followUps >= TutorEscalationService.tutorFollowUpThreshold;
      }

      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        signals['learnerId'] = userId;
      }

      if (signals.isNotEmpty) {
        base['intelligenceSignals'] = signals;
      }

      return base;
    } catch (e) {
      LogService.warning('LearnerIntelligenceService.build: $e');
      return LearnerContextService.build(childId: childId);
    }
  }
}
