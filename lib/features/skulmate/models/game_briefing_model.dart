import '../models/game_model.dart';

/// Pre-game briefing data derived from a [GameModel].
class GameBriefingModel {
  final String title;
  final String? topic;
  final String gameTypeLabel;
  final int itemCount;
  final String itemCountLabel;
  final int estimatedMinutes;
  final int estimatedXp;
  final GameType gameType;

  const GameBriefingModel({
    required this.title,
    required this.topic,
    required this.gameTypeLabel,
    required this.itemCount,
    required this.itemCountLabel,
    required this.estimatedMinutes,
    required this.estimatedXp,
    required this.gameType,
  });

  factory GameBriefingModel.fromGame(GameModel game) {
    final itemCount = _countPlayableItems(game);
    final minutes = _estimateMinutes(game.gameType, itemCount);
    final xp = _estimateXp(game.gameType, itemCount);

    return GameBriefingModel(
      title: game.title,
      topic: game.metadata.topic?.trim().isNotEmpty == true
          ? game.metadata.topic!.trim()
          : null,
      gameTypeLabel: _typeLabel(game.gameType),
      itemCount: itemCount,
      itemCountLabel: _itemCountLabel(game.gameType, itemCount),
      estimatedMinutes: minutes,
      estimatedXp: xp,
      gameType: game.gameType,
    );
  }

  static int _countPlayableItems(GameModel game) {
    switch (game.gameType) {
      case GameType.puzzlePieces:
        if (game.items.isNotEmpty) {
          final item = game.items.first;
          final steps = item.puzzleSteps ??
              (item.gameData?['puzzleSteps'] as List?);
          if (steps != null && steps.isNotEmpty) return steps.length;
          final pieces = item.puzzlePieces;
          if (pieces != null && pieces.isNotEmpty) return pieces.length;
        }
        return game.items.length.clamp(1, 99);
      case GameType.matching:
        return game.items
            .where(
              (i) =>
                  (i.leftItem ?? '').trim().isNotEmpty &&
                  (i.rightItem ?? '').trim().isNotEmpty,
            )
            .length
            .clamp(1, 99);
      case GameType.flashcards:
        return game.items
            .where(
              (i) =>
                  (i.term ?? '').trim().isNotEmpty &&
                  (i.definition ?? '').trim().isNotEmpty,
            )
            .length
            .clamp(1, 99);
      default:
        return game.items.length.clamp(1, 99);
    }
  }

  static int _estimateMinutes(GameType type, int count) {
    final perItem = switch (type) {
      GameType.puzzlePieces => 0.35,
      GameType.matching => 0.45,
      GameType.quiz => 0.5,
      GameType.flashcards => 0.25,
      GameType.dragDrop => 0.55,
      GameType.fillBlank => 0.4,
      _ => 0.4,
    };
    return (count * perItem).ceil().clamp(1, 12);
  }

  static int _estimateXp(GameType type, int count) {
    final base = switch (type) {
      GameType.puzzlePieces => count * 5 + 50,
      GameType.matching => count * 15 + 40,
      GameType.quiz => count * 10 + 30,
      GameType.flashcards => count * 8 + 20,
      GameType.dragDrop => count * 12 + 35,
      GameType.fillBlank => count * 10 + 30,
      _ => count * 10 + 25,
    };
    return base + (count > 4 ? 25 : 0);
  }

  static String _typeLabel(GameType type) {
    switch (type) {
      case GameType.quiz:
        return 'Quiz';
      case GameType.flashcards:
        return 'Flashcards';
      case GameType.matching:
        return 'Matching';
      case GameType.fillBlank:
        return 'Fill in the blank';
      case GameType.dragDrop:
        return 'Drag & drop';
      case GameType.puzzlePieces:
        return 'Sequence puzzle';
      default:
        return 'Game';
    }
  }

  static String _itemCountLabel(GameType type, int count) {
    switch (type) {
      case GameType.puzzlePieces:
        return '$count steps';
      case GameType.matching:
        return '$count pairs';
      case GameType.quiz:
        return '$count questions';
      case GameType.flashcards:
        return '$count cards';
      case GameType.fillBlank:
        return '$count sentences';
      case GameType.dragDrop:
        return '$count challenges';
      default:
        return '$count items';
    }
  }
}
