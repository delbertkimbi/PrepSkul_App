import 'package:flutter/material.dart';

import '../models/game_model.dart';

/// Shared icon, color, and label for each SkulMate game type.
class GameTypeVisuals {
  GameTypeVisuals._();

  static IconData iconFor(GameType type) {
    switch (type) {
      case GameType.quiz:
        return Icons.quiz;
      case GameType.flashcards:
        return Icons.style;
      case GameType.matching:
        return Icons.compare_arrows;
      case GameType.fillBlank:
        return Icons.edit;
      case GameType.match3:
        return Icons.grid_view;
      case GameType.bubblePop:
        return Icons.bubble_chart;
      case GameType.wordSearch:
        return Icons.search;
      case GameType.crossword:
        return Icons.grid_4x4;
      case GameType.diagramLabel:
        return Icons.label;
      case GameType.dragDrop:
        return Icons.drag_handle;
      case GameType.puzzlePieces:
        return Icons.extension;
      case GameType.simulation:
        return Icons.sim_card;
      case GameType.mystery:
        return Icons.search;
      case GameType.escapeRoom:
        return Icons.lock;
    }
  }

  static Color accentColorFor(GameType type) {
    switch (type) {
      case GameType.quiz:
        return const Color(0xFF7E57C2);
      case GameType.flashcards:
        return const Color(0xFF1E88E5);
      case GameType.matching:
        return const Color(0xFF00897B);
      case GameType.fillBlank:
        return const Color(0xFF43A047);
      case GameType.match3:
        return const Color(0xFFFB8C00);
      case GameType.bubblePop:
        return const Color(0xFFE91E63);
      case GameType.wordSearch:
        return const Color(0xFF00ACC1);
      case GameType.crossword:
        return const Color(0xFFF9A825);
      case GameType.diagramLabel:
        return const Color(0xFF6D4C41);
      case GameType.dragDrop:
        return const Color(0xFF3949AB);
      case GameType.puzzlePieces:
        return const Color(0xFF8D6E63);
      case GameType.simulation:
        return const Color(0xFF5E35B1);
      case GameType.mystery:
        return const Color(0xFF8E24AA);
      case GameType.escapeRoom:
        return const Color(0xFFE53935);
    }
  }

  static String labelFor(GameType type) {
    switch (type) {
      case GameType.quiz:
        return 'Quiz';
      case GameType.flashcards:
        return 'Flashcards';
      case GameType.matching:
        return 'Matching';
      case GameType.fillBlank:
        return 'Fill in Blank';
      case GameType.match3:
        return 'Match-3';
      case GameType.bubblePop:
        return 'Bubble Pop';
      case GameType.wordSearch:
        return 'Word Search';
      case GameType.crossword:
        return 'Crossword';
      case GameType.diagramLabel:
        return 'Diagram Label';
      case GameType.dragDrop:
        return 'Drag & Drop';
      case GameType.puzzlePieces:
        return 'Puzzle Pieces';
      case GameType.simulation:
        return 'Simulation';
      case GameType.mystery:
        return 'Mystery';
      case GameType.escapeRoom:
        return 'Escape Room';
    }
  }
}
