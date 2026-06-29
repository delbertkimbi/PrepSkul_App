import 'dart:math';

import '../models/revision_deck_model.dart';
import '../models/scroll_feed_item.dart';
import '../models/scroll_slide.dart';

/// Builds a mixed TikTok-style scroll queue from deck cards and due reviews.
class ScrollFeedComposer {
  ScrollFeedComposer._();

  static final Random _random = Random();

  static const _hooks = [
    'POV: you finally understand this',
    'Wait for it… 👀',
    'Nobody told you this part',
    'Study hack unlocked 🔓',
    'This shows up on every test',
    'Plot twist incoming',
    'Save this before you forget',
  ];

  /// Compose slides from legacy [ScrollFeedItem]s plus optional enriched deck.
  static List<ScrollSlide> compose({
    required List<ScrollFeedItem> items,
    RevisionDeckModel? deck,
    int celebrateEvery = 4,
  }) {
    if (items.isEmpty) return [];

    final cardByIndex = <int, RevisionDeckCard>{};
    if (deck != null) {
      for (final card in deck.cards) {
        final idx = card.gameItemIndex;
        if (idx != null) cardByIndex[idx] = card;
      }
    }

    final slides = <ScrollSlide>[];
    var cardCount = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final deckCard = cardByIndex[item.itemIndex];

      if (cardCount > 0 && cardCount % celebrateEvery == 0) {
        slides.add(
          ScrollSlide(
            kind: ScrollSlideKind.celebrate,
            gameId: item.gameId,
            itemIndex: item.itemIndex,
            prompt: '',
            answer: '',
            celebrateTitle: 'Nice streak! 🎉',
            celebrateBody:
                'You\'ve reviewed $cardCount cards. Keep the momentum going.',
            milestoneIndex: cardCount,
          ),
        );
      }

      if (cardCount % 3 == 0) {
        slides.add(
          ScrollSlide(
            kind: ScrollSlideKind.hook,
            gameId: item.gameId,
            itemIndex: item.itemIndex,
            reviewRowId: item.reviewRowId,
            gameTitle: item.gameTitle,
            cardId: deckCard?.id,
            hookLine: _hooks[_random.nextInt(_hooks.length)],
            prompt: item.term,
            answer: item.definition,
            explanation: deckCard?.explanation,
            emoji: deckCard != null
                ? ScrollSlide.fromDeckCard(
                    card: deckCard,
                    gameId: item.gameId,
                    itemIndex: item.itemIndex,
                  ).emoji
                : '💡',
          ),
        );
      }

      if (deckCard != null) {
        final base = ScrollSlide.fromDeckCard(
          card: deckCard,
          gameId: item.gameId,
          itemIndex: item.itemIndex,
          reviewRowId: item.reviewRowId,
          gameTitle: item.gameTitle,
        );

        if (base.kind == ScrollSlideKind.reveal && cardCount % 2 == 1) {
          slides.add(
            ScrollSlide(
              kind: ScrollSlideKind.listen,
              gameId: item.gameId,
              itemIndex: item.itemIndex,
              reviewRowId: item.reviewRowId,
              gameTitle: item.gameTitle,
              cardId: deckCard.id,
              prompt: item.term,
              answer: item.definition,
              explanation: deckCard.explanation,
              emoji: base.emoji,
            ),
          );
        } else {
          slides.add(base);
        }
      } else {
        slides.add(
          ScrollSlide.reveal(
            gameId: item.gameId,
            itemIndex: item.itemIndex,
            term: item.term,
            definition: item.definition,
            reviewRowId: item.reviewRowId,
            gameTitle: item.gameTitle,
          ),
        );
      }

      cardCount++;
    }

    return slides;
  }
}
