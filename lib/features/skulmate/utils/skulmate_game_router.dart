import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_model.dart';
import '../services/game_progress_service.dart';
import '../services/scroll_play_mode_prefs.dart';
import '../widgets/game_briefing_screen.dart';
import '../widgets/skulmate_surface_styles.dart';
import '../screens/bubble_pop_game_screen.dart';
import '../screens/crossword_game_screen.dart';
import '../screens/drag_drop_game_screen.dart';
import '../screens/escape_room_game_screen.dart';
import '../screens/fill_blank_game_screen.dart';
import '../screens/flashcard_game_screen.dart';
import '../screens/match3_game_screen.dart';
import '../screens/matching_game_screen.dart';
import '../screens/mystery_game_screen.dart';
import '../screens/puzzle_pieces_game_screen.dart';
import '../screens/quiz_game_screen.dart';
import '../screens/simulation_game_screen.dart';
import '../screens/skulmate_scroll_feed_screen.dart';
import '../screens/word_search_game_screen.dart';
import 'skulmate_client_game_policy.dart';

/// Routes a [GameModel] to the correct playable screen.
class SkulMateGameRouter {
  static Set<GameType> get comingSoonTypes =>
      SkulMateClientGamePolicy.comingSoonTypes;

  static Future<bool> open(
    BuildContext context,
    GameModel game, {
    bool isDailyChallenge = false,
    bool fromGenerationFlow = false,
    bool openAsScrollFeed = false,
    bool skipBriefing = false,
    String? childId,
  }) async {
    if (comingSoonTypes.contains(game.gameType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_label(game.gameType)} is coming soon. Choose another game for now.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    if (!game.isPlayable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This game does not have playable content yet. Try regenerating it.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    final resumeFrom = await GameProgressService.loadProgress(game.id);

    var asScroll = openAsScrollFeed;
    if (!asScroll && game.gameType == GameType.flashcards) {
      final preferred = await ScrollPlayModePrefs.preferredModeFor(game.id);
      asScroll = preferred == ScrollPlayModePrefs.scroll;
    }

    if (!skipBriefing && resumeFrom == null && context.mounted && !asScroll) {
      final ready = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => GameBriefingScreen(game: game),
        ),
      );
      if (!context.mounted || ready != true) return false;
    }

    final screen = _screenFor(
      game,
      isDailyChallenge: isDailyChallenge,
      fromGenerationFlow: fromGenerationFlow,
      resumeFrom: resumeFrom,
      openAsScrollFeed: asScroll,
      childId: childId,
    );

    if (asScroll) {
      await ScrollPlayModePrefs.markScroll(game.id);
    } else if (game.gameType == GameType.flashcards) {
      await ScrollPlayModePrefs.markFlashcards(game.id);
    }

    if (resumeFrom != null && context.mounted && !asScroll) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resuming where you left off'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }

    if (!context.mounted) return false;

    final route = MaterialPageRoute(builder: (_) => screen);

    if (fromGenerationFlow) {
      await Navigator.pushAndRemoveUntil(
        context,
        route,
        (r) => r.isFirst,
      );
    } else {
      await Navigator.push(context, route);
    }

    SystemChrome.setSystemUIOverlayStyle(
      SkulMateSurfaceStyles.lightStatusBarOverlay,
    );
    return true;
  }

  static Widget _screenFor(
    GameModel game, {
    required bool isDailyChallenge,
    required bool fromGenerationFlow,
    GameProgress? resumeFrom,
    bool openAsScrollFeed = false,
    String? childId,
  }) {
    switch (game.gameType) {
      case GameType.quiz:
        return QuizGameScreen(
          game: game,
          isDailyChallenge: isDailyChallenge,
          fromGenerationFlow: fromGenerationFlow,
          resumeFrom: resumeFrom,
        );
      case GameType.flashcards:
        if (openAsScrollFeed) {
          return SkulMateScrollFeedScreen(
            seedGame: game,
            childId: childId,
          );
        }
        return FlashcardGameScreen(game: game, resumeFrom: resumeFrom);
      case GameType.matching:
        return MatchingGameScreen(game: game, resumeFrom: resumeFrom);
      case GameType.fillBlank:
        return FillBlankGameScreen(game: game, resumeFrom: resumeFrom);
      case GameType.match3:
        return Match3GameScreen(game: game);
      case GameType.bubblePop:
        return BubblePopGameScreen(game: game);
      case GameType.wordSearch:
        return WordSearchGameScreen(game: game);
      case GameType.crossword:
        return CrosswordGameScreen(game: game);
      case GameType.diagramLabel:
        return MysteryGameScreen(game: game);
      case GameType.dragDrop:
        return DragDropGameScreen(game: game, resumeFrom: resumeFrom);
      case GameType.puzzlePieces:
        return PuzzlePiecesGameScreen(game: game, resumeFrom: resumeFrom);
      case GameType.simulation:
        return SimulationGameScreen(game: game);
      case GameType.mystery:
        return MysteryGameScreen(game: game);
      case GameType.escapeRoom:
        return EscapeRoomGameScreen(game: game);
    }
  }

  static String _label(GameType type) {
    switch (type) {
      case GameType.quiz:
        return 'Quiz';
      case GameType.flashcards:
        return 'Flashcards'; // briefing only; scroll uses its own chrome
      case GameType.matching:
        return 'Matching';
      default:
        return 'This game type';
    }
  }
}
