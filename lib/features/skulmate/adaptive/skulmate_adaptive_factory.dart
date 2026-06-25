import '../models/game_model.dart';
import '../models/scroll_feed_item.dart';
import 'skulmate_adaptive_types.dart';

/// Builds adaptive surface specs from SkulMate game content.
///
/// Today these specs drive local catalog widgets. Later, the same shapes can be
/// emitted as A2UI messages from OpenRouter via [genui].
class SkulMateAdaptiveFactory {
  SkulMateAdaptiveFactory._();

  static SkulMateAdaptiveSurfaceSpec scrollCard({
    required ScrollFeedItem item,
    required bool flipped,
    String? tapHint,
    String? revealHint,
  }) {
    return SkulMateAdaptiveSurfaceSpec(
      surfaceId: 'scroll-${item.gameId}-${item.itemIndex}',
      kind: SkulMateCatalogKind.scrollCard,
      initialData: {
        'term': item.term,
        'definition': item.definition,
        'gameTitle': item.gameTitle ?? '',
        'flipped': flipped,
        if (tapHint != null) 'tapHint': tapHint,
        if (revealHint != null) 'revealHint': revealHint,
      },
    );
  }

  static SkulMateAdaptiveSurfaceSpec flashcard({
    required GameItem item,
    required int index,
    required bool flipped,
    String? gameTitle,
  }) {
    return SkulMateAdaptiveSurfaceSpec(
      surfaceId: 'flashcard-$index',
      kind: SkulMateCatalogKind.flashcard,
      initialData: {
        'term': item.term ?? '',
        'definition': item.definition ?? '',
        'gameTitle': gameTitle ?? '',
        'flipped': flipped,
      },
    );
  }

  static SkulMateAdaptiveSurfaceSpec quizQuestion({
    required GameItem item,
    required int index,
    int? selectedIndex,
    bool? showResult,
  }) {
    return SkulMateAdaptiveSurfaceSpec(
      surfaceId: 'quiz-$index',
      kind: SkulMateCatalogKind.quizQuestion,
      initialData: {
        'question': item.question ?? '',
        'options': item.options ?? const <String>[],
        'selectedIndex': selectedIndex ?? -1,
        'showResult': showResult ?? false,
        'correctIndex': item.correctAnswer is int ? item.correctAnswer as int : -1,
      },
    );
  }

  static SkulMateAdaptiveSurfaceSpec puzzlePrompt({
    required GameItem item,
    required int index,
  }) {
    return SkulMateAdaptiveSurfaceSpec(
      surfaceId: 'puzzle-$index',
      kind: SkulMateCatalogKind.puzzlePrompt,
      initialData: {
        'prompt': item.question ?? item.term ?? '',
        'hint': item.explanation ?? '',
        'imageUrl': item.imageUrl ?? '',
      },
    );
  }

  static SkulMateAdaptiveSurfaceSpec matchingPair({
    required GameItem item,
    required int index,
    bool revealed = false,
  }) {
    return SkulMateAdaptiveSurfaceSpec(
      surfaceId: 'match-$index',
      kind: SkulMateCatalogKind.matchingPair,
      initialData: {
        'leftItem': item.leftItem ?? '',
        'rightItem': item.rightItem ?? '',
        'revealed': revealed,
      },
    );
  }

  static SkulMateAdaptiveSurfaceSpec notesBlock({
    required String title,
    required String body,
  }) {
    return SkulMateAdaptiveSurfaceSpec(
      surfaceId: 'notes-${title.hashCode}',
      kind: SkulMateCatalogKind.notesBlock,
      initialData: {
        'title': title,
        'body': body,
      },
    );
  }

  /// Pick the best catalog kind for a generated game item.
  static SkulMateAdaptiveSurfaceSpec forGameItem({
    required GameModel game,
    required int index,
    Map<String, Object?> extra = const {},
  }) {
    final item = game.items[index];
    switch (game.gameType) {
      case GameType.flashcards:
        return flashcard(
          item: item,
          index: index,
          flipped: extra['flipped'] == true,
          gameTitle: game.title,
        );
      case GameType.quiz:
      case GameType.fillBlank:
        return quizQuestion(
          item: item,
          index: index,
          selectedIndex: extra['selectedIndex'] as int?,
          showResult: extra['showResult'] == true,
        );
      case GameType.puzzlePieces:
        return puzzlePrompt(item: item, index: index);
      case GameType.matching:
        return matchingPair(
          item: item,
          index: index,
          revealed: extra['revealed'] == true,
        );
      default:
        return notesBlock(
          title: game.title,
          body: item.question ?? item.term ?? item.definition ?? '',
        );
    }
  }
}
