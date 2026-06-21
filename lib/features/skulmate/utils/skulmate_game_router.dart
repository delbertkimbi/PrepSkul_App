import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_model.dart';
import '../services/game_progress_service.dart';
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

    final screen = _screenFor(
      game,
      isDailyChallenge: isDailyChallenge,
      fromGenerationFlow: fromGenerationFlow,
      resumeFrom: resumeFrom,
    );

    if (resumeFrom != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resuming where you left off'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }

    if (!context.mounted) return false;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      SystemChrome.setSystemUIOverlayStyle(
        SkulMateSurfaceStyles.lightStatusBarOverlay,
      );
    });
    return true;
  }

  static Widget _screenFor(
    GameModel game, {
    required bool isDailyChallenge,
    required bool fromGenerationFlow,
    GameProgress? resumeFrom,
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
      default:
        return QuizGameScreen(
          game: game,
          isDailyChallenge: isDailyChallenge,
          fromGenerationFlow: fromGenerationFlow,
        );
    }
  }

  static String _label(GameType type) {
    switch (type) {
      case GameType.quiz:
        return 'Quiz';
      case GameType.flashcards:
        return 'Flashcards';
      case GameType.matching:
        return 'Matching';
      default:
        return 'This game type';
    }
  }
}
