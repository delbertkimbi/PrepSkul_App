import 'package:flutter/material.dart';
import 'package:prepskul/features/skulmate/models/game_model.dart';
import 'package:prepskul/features/skulmate/screens/bubble_pop_game_screen.dart';
import 'package:prepskul/features/skulmate/screens/crossword_game_screen.dart';
import 'package:prepskul/features/skulmate/screens/drag_drop_game_screen.dart';
import 'package:prepskul/features/skulmate/screens/escape_room_game_screen.dart';
import 'package:prepskul/features/skulmate/screens/flashcard_game_screen.dart';
import 'package:prepskul/features/skulmate/screens/fill_blank_game_screen.dart';
import 'package:prepskul/features/skulmate/screens/match3_game_screen.dart';
import 'package:prepskul/features/skulmate/screens/matching_game_screen.dart';
import 'package:prepskul/features/skulmate/screens/mystery_game_screen.dart';
import 'package:prepskul/features/skulmate/screens/puzzle_pieces_game_screen.dart';
import 'package:prepskul/features/skulmate/screens/quiz_game_screen.dart';
import 'package:prepskul/features/skulmate/screens/simulation_game_screen.dart';
import 'package:prepskul/features/skulmate/screens/word_search_game_screen.dart';
import 'package:prepskul/features/skulmate/utils/skulmate_client_game_policy.dart';

/// Opens the correct SkulMate game screen from home teaser or shortcuts.
class SkulMateGameLauncher {
  SkulMateGameLauncher._();

  static void open(BuildContext context, GameModel game, {bool isDailyChallenge = false}) {
    if (SkulMateClientGamePolicy.comingSoonTypes.contains(game.gameType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This game type is coming soon.')),
      );
      return;
    }
    if (!game.isPlayable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This game has no playable content yet.')),
      );
      return;
    }

    final Widget screen;
    switch (game.gameType) {
      case GameType.quiz:
        screen = QuizGameScreen(game: game, isDailyChallenge: isDailyChallenge);
        break;
      case GameType.flashcards:
        screen = FlashcardGameScreen(game: game);
        break;
      case GameType.matching:
        screen = MatchingGameScreen(game: game);
        break;
      case GameType.fillBlank:
        screen = FillBlankGameScreen(game: game);
        break;
      case GameType.match3:
        screen = Match3GameScreen(game: game);
        break;
      case GameType.bubblePop:
        screen = BubblePopGameScreen(game: game);
        break;
      case GameType.wordSearch:
        screen = WordSearchGameScreen(game: game);
        break;
      case GameType.crossword:
        screen = CrosswordGameScreen(game: game);
        break;
      case GameType.diagramLabel:
        screen = MysteryGameScreen(game: game);
        break;
      case GameType.dragDrop:
        screen = DragDropGameScreen(game: game);
        break;
      case GameType.puzzlePieces:
        screen = PuzzlePiecesGameScreen(game: game);
        break;
      case GameType.simulation:
        screen = SimulationGameScreen(game: game);
        break;
      case GameType.mystery:
        screen = MysteryGameScreen(game: game);
        break;
      case GameType.escapeRoom:
        screen = EscapeRoomGameScreen(game: game);
        break;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
