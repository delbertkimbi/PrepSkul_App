import 'package:flutter/material.dart';

import '../models/deck_library_entry.dart';
import '../models/deck_study_intent_mode.dart';
import '../models/game_model.dart';
import '../models/revision_deck_model.dart';
import '../models/skulmate_intake_models.dart';
import '../screens/deck_concept_check_screen.dart';
import '../screens/deck_hub_screen.dart';
import '../screens/deck_tutor_session_screen.dart';
import '../screens/skulmate_path_overview_screen.dart';
import '../services/deck_concept_check_service.dart';
import '../services/deck_game_projector.dart';
import '../services/deck_study_progress_service.dart';
import '../services/game_progress_service.dart';
import '../services/learner_intelligence_service.dart';
import '../services/revision_deck_service.dart';
import '../services/skulmate_service.dart';
import '../services/deck_library_service.dart';
import '../services/scroll_play_mode_prefs.dart';
import '../utils/skulmate_game_router.dart';
import '../widgets/deck_add_sheet.dart';
import '../widgets/deck_select_sheet.dart';
import '../widgets/deck_study_launcher_sheet.dart'; // DeckStudyMode

/// Deck navigation — picker → study chat → tutor / drill / play / path.
class DeckNavigation {
  /// Opens deck picker → Gizmo-style study chat → chosen mode.
  static Future<void> openDeckPicker({
    required BuildContext context,
    String? childId,
  }) async {
    final decks = await DeckLibraryService.listDecks(childId: childId);
    if (!context.mounted) return;

    if (decks.isEmpty) {
      await DeckAddSheet.show(context, childId: childId);
      return;
    }

    final selected = await showDeckSelectSheet(
      context: context,
      childId: childId,
      initialDecks: decks,
    );
    if (!context.mounted || selected == null) return;

    await openDeckHub(
      context: context,
      entry: selected,
      childId: childId,
    );
  }

  static Future<void> routeStudyIntent({
    required BuildContext context,
    required DeckLibraryEntry entry,
    required DeckStudyIntentMode mode,
    String? refinement,
    String? childId,
  }) async {
    await LearnerIntelligenceService.build(
      childId: childId,
      activeDeckTitle: entry.title,
      deckStudyMode: mode.name,
      refinement: refinement,
    );

    final game = await _resolveGame(entry.gameId, childId: childId);
    if (!context.mounted) return;
    if (game == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load this deck. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    var deck = entry.deck;
    if (refinement != null && refinement.isNotEmpty) {
      deck = RevisionDeckModel(
        id: deck.id,
        title: deck.title,
        topicLabel: refinement,
        sourceType: deck.sourceType,
        notes: deck.notes,
        knowledgeUnits: deck.knowledgeUnits,
        cards: deck.cards,
        conceptCheckCardIds: deck.conceptCheckCardIds,
        linkedGameId: deck.linkedGameId,
        gameType: deck.gameType,
      );
    }
    RevisionDeckService.cacheDeck(deck);

    switch (mode) {
      case DeckStudyIntentMode.tutor:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeckTutorSessionScreen(
              deck: deck,
              gameId: entry.gameId,
              childId: childId,
            ),
          ),
        );
      case DeckStudyIntentMode.play:
        if (!game.isPlayable) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This game is not ready to play yet. Try regenerating it.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        await SkulMateGameRouter.open(
          context,
          game,
          skipBriefing: true,
          childId: childId,
        );
      case DeckStudyIntentMode.path:
        final payload = SkulMateIntakePayload(
          source: SkulMateIntakeSource.typedTopic,
          topicHint: refinement ?? deck.topicLabel,
          title: deck.title,
          text: deck.notes.isNotEmpty ? deck.notes : null,
          childId: childId,
        );
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SkulMatePathOverviewScreen(payload: payload),
          ),
        );
      case DeckStudyIntentMode.drill:
        await playStudyModeFromHub(
          context: context,
          game: game,
          deck: deck,
          studyMode: DeckStudyMode.memorise,
          childId: childId,
        );
      case DeckStudyIntentMode.scroll:
        await playStudyModeFromHub(
          context: context,
          game: game,
          deck: deck,
          studyMode: DeckStudyMode.scroll,
          childId: childId,
          openAsScrollFeed: true,
        );
    }
  }

  /// Opens the deck hub (cards, notes, lessons…) from home or library.
  static Future<void> openDeckHub({
    required BuildContext context,
    required DeckLibraryEntry entry,
    String? childId,
  }) async {
    final game = await _resolveGame(entry.gameId, childId: childId);
    if (!context.mounted) return;
    if (game == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load this deck. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeckHubScreen(
          deck: entry.deck,
          game: game,
          childId: childId,
          libraryMode: true,
        ),
      ),
    );
  }

  /// Opens study chat for one deck — routes to deck hub (review cards, then Study deck).
  static Future<void> openDeckStudyChat({
    required BuildContext context,
    required DeckLibraryEntry entry,
    String? childId,
  }) {
    return openDeckHub(
      context: context,
      entry: entry,
      childId: childId,
    );
  }

  static Future<void> _playProjectedMode(
    BuildContext context, {
    required GameModel game,
    required RevisionDeckModel deck,
    required DeckStudyMode studyMode,
    String? childId,
    bool openAsScrollFeed = false,
  }) async {
    final playGame = DeckGameProjector.project(
      game: game,
      deck: deck,
      studyMode: studyMode,
    );

    final scrollReady = studyMode == DeckStudyMode.scroll &&
        (deck.cards.isNotEmpty || playGame.items.isNotEmpty);

    if (!scrollReady && !playGame.isPlayable) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Not enough cards to play ${studyMode.label} yet. '
            'Try another mode or add more cards.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final modeKey = studyMode.apiGameType ?? studyMode.name;
    await DeckStudyProgressService.recordModeCompleted(deck.deckKey, modeKey);

    if (!context.mounted) return;
    if (openAsScrollFeed || studyMode == DeckStudyMode.scroll) {
      await ScrollPlayModePrefs.markScroll(game.id);
    }

    final played = await SkulMateGameRouter.open(
      context,
      playGame,
      openAsScrollFeed: openAsScrollFeed || studyMode == DeckStudyMode.scroll,
      skipBriefing: true,
      childId: childId,
    );
    if (played) {
      await DeckStudyProgressService.markSessionCompleted(deck.deckKey);
    }
  }

  static Future<GameModel?> _resolveGame(
    String gameId, {
    String? childId,
  }) async {
    final cached = await SkulMateService.getCachedGames(childId: childId);
    for (final game in cached) {
      if (game.id == gameId) return game;
    }
    final games = await SkulMateService.getGames(childId: childId);
    for (final game in games) {
      if (game.id == gameId) return game;
    }
    return null;
  }

  /// Opens a saved deck from home/library — review cards before playing.
  static Future<void> openFromLibrary({
    required BuildContext context,
    required GameModel game,
    required RevisionDeckModel deck,
    String? childId,
    bool openAsScrollFeed = false,
  }) {
    return openAfterGeneration(
      context: context,
      game: game,
      deck: deck,
      childId: childId,
      openAsScrollFeed: openAsScrollFeed,
    );
  }

  static Future<void> playStudyModeFromHub({
    required BuildContext context,
    required GameModel game,
    required RevisionDeckModel deck,
    required DeckStudyMode studyMode,
    String? childId,
    bool openAsScrollFeed = false,
  }) async {
    final needsConceptCheck =
        studyMode == DeckStudyMode.quiz ||
        studyMode == DeckStudyMode.matching ||
        studyMode == DeckStudyMode.fillBlank;

    if (needsConceptCheck) {
      final freshDeck = RevisionDeckService.cachedDeckForGame(game.id) ?? deck;
      final resumeFrom = await GameProgressService.loadProgress(game.id);
      final alreadyPassed = resumeFrom != null ||
          await DeckConceptCheckService.hasPassed(freshDeck.deckKey);
      if (!alreadyPassed && context.mounted) {
        final passed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => DeckConceptCheckScreen(
              deck: freshDeck,
              studyMode: studyMode,
              onComplete: (_) {},
            ),
          ),
        );
        if (!context.mounted) return;
        if (passed != true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Review the cards and notes, then try the concept check again.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        await DeckStudyProgressService.markConceptPassed(freshDeck.deckKey);
      } else if (alreadyPassed) {
        await DeckStudyProgressService.markConceptPassed(freshDeck.deckKey);
      }
    }

    if (!context.mounted) return;

    final freshDeck = RevisionDeckService.cachedDeckForGame(game.id) ?? deck;
    await _playProjectedMode(
      context,
      game: game,
      deck: freshDeck,
      studyMode: studyMode,
      childId: childId,
      openAsScrollFeed: openAsScrollFeed || studyMode == DeckStudyMode.scroll,
    );
  }

  static Future<void> openAfterGeneration({
    required BuildContext context,
    required GameModel game,
    RevisionDeckModel? deck,
    String? childId,
    bool openAsScrollFeed = false,
    SkulMateIntentMode? intakeMode,
  }) async {
    if (deck != null && deck.cards.isNotEmpty) {
      if (!context.mounted) return;

      // Scroll / drill intents: play immediately (no hub detour).
      if (openAsScrollFeed || intakeMode == SkulMateIntentMode.scroll) {
        await playStudyModeFromHub(
          context: context,
          game: game,
          deck: deck,
          studyMode: DeckStudyMode.scroll,
          childId: childId,
          openAsScrollFeed: true,
        );
        return;
      }
      if (intakeMode == SkulMateIntentMode.drill) {
        await playStudyModeFromHub(
          context: context,
          game: game,
          deck: deck,
          studyMode: DeckStudyMode.memorise,
          childId: childId,
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeckHubScreen(
            deck: deck,
            game: game,
            childId: childId,
            openAsScrollFeed: openAsScrollFeed,
            libraryMode: true,
          ),
        ),
      );
      return;
    }

    if (!game.isPlayable) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This game is not ready to play yet. Try regenerating it.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await SkulMateGameRouter.open(
      context,
      game,
      fromGenerationFlow: true,
      openAsScrollFeed: openAsScrollFeed,
      skipBriefing: true,
      childId: childId,
    );
  }
}
