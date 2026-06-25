import 'package:genui/genui.dart';

import '../models/game_model.dart';
import '../models/scroll_feed_item.dart';
import 'skulmate_adaptive_factory.dart';
import 'skulmate_adaptive_types.dart';
import 'skulmate_genui_catalog.dart';

/// Deterministic [GameModel] / scroll feed → A2UI message adapter.
///
/// No extra LLM cost: the app builds genui messages locally from game content.
class GameModelA2uiAdapter {
  GameModelA2uiAdapter._();

  static String componentTypeFor(SkulMateCatalogKind kind) {
    return switch (kind) {
      SkulMateCatalogKind.scrollCard => 'SkulMateScrollCard',
      SkulMateCatalogKind.flashcard => 'SkulMateFlashcard',
      SkulMateCatalogKind.quizQuestion => 'SkulMateScrollCard',
      SkulMateCatalogKind.matchingPair => 'SkulMateScrollCard',
      SkulMateCatalogKind.puzzlePrompt => 'SkulMateScrollCard',
      SkulMateCatalogKind.notesBlock => 'SkulMateScrollCard',
    };
  }

  /// Build A2UI messages to mount [spec] on a genui surface.
  static List<A2uiMessage> messagesForSpec(SkulMateAdaptiveSurfaceSpec spec) {
    return [
      CreateSurface(
        surfaceId: spec.surfaceId,
        catalogId: skulMateCatalogId,
      ),
      UpdateComponents(
        surfaceId: spec.surfaceId,
        components: [
          Component(
            id: 'root',
            type: componentTypeFor(spec.kind),
            properties: const {},
          ),
        ],
      ),
      UpdateDataModel(
        surfaceId: spec.surfaceId,
        path: DataPath.root,
        value: spec.initialData,
      ),
    ];
  }

  static List<A2uiMessage> forScrollItem({
    required ScrollFeedItem item,
    required bool flipped,
    String? tapHint,
    String? revealHint,
  }) {
    final spec = SkulMateAdaptiveFactory.scrollCard(
      item: item,
      flipped: flipped,
      tapHint: tapHint,
      revealHint: revealHint,
    );
    return messagesForSpec(spec);
  }

  static List<A2uiMessage> forFlashcardItem({
    required GameModel game,
    required int index,
    required bool flipped,
  }) {
    final spec = SkulMateAdaptiveFactory.flashcard(
      item: game.items[index],
      index: index,
      flipped: flipped,
      gameTitle: game.title,
    );
    return messagesForSpec(spec);
  }

  static UpdateDataModel dataPatch(
    String surfaceId,
    Map<String, Object?> data,
  ) {
    return UpdateDataModel(
      surfaceId: surfaceId,
      path: DataPath.root,
      value: data,
    );
  }
}
