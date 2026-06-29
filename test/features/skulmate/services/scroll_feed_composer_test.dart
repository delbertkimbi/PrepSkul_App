import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/models/revision_deck_model.dart';
import 'package:prepskul/features/skulmate/models/scroll_feed_item.dart';
import 'package:prepskul/features/skulmate/models/scroll_slide.dart';
import 'package:prepskul/features/skulmate/services/scroll_feed_composer.dart';

void main() {
  group('ScrollFeedComposer', () {
    test('interleaves hooks, celebrate, and mcq from enriched deck', () {
      final items = [
        const ScrollFeedItem(
          gameId: 'g1',
          itemIndex: 0,
          term: 'Photosynthesis',
          definition: 'Plants make food from light',
        ),
        const ScrollFeedItem(
          gameId: 'g1',
          itemIndex: 1,
          term: 'Mitochondria',
          definition: 'Powerhouse of the cell',
        ),
        const ScrollFeedItem(
          gameId: 'g1',
          itemIndex: 2,
          term: 'Nucleus',
          definition: 'Controls the cell',
        ),
        const ScrollFeedItem(
          gameId: 'g1',
          itemIndex: 3,
          term: 'Ribosome',
          definition: 'Makes proteins',
        ),
      ];

      final deck = RevisionDeckModel(
        title: 'Bio',
        topicLabel: 'Bio',
        sourceType: 'text',
        notes: '',
        knowledgeUnits: const [],
        cards: [
          RevisionDeckCard(
            id: 'c0',
            knowledgeUnitId: 'core',
            cardType: RevisionDeckCardType.termDef,
            prompt: 'Photosynthesis',
            answer: 'Plants make food from light',
            gameItemIndex: 0,
          ),
          RevisionDeckCard(
            id: 'c1',
            knowledgeUnitId: 'core',
            cardType: RevisionDeckCardType.mcq,
            prompt: 'What is the powerhouse?',
            answer: 'Mitochondria',
            distractors: const ['Nucleus', 'Ribosome'],
            gameItemIndex: 1,
          ),
          RevisionDeckCard(
            id: 'c2',
            knowledgeUnitId: 'core',
            cardType: RevisionDeckCardType.pair,
            prompt: 'Nucleus',
            answer: 'Controls the cell',
            gameItemIndex: 2,
          ),
          RevisionDeckCard(
            id: 'c3',
            knowledgeUnitId: 'core',
            cardType: RevisionDeckCardType.termDef,
            prompt: 'Ribosome',
            answer: 'Makes proteins',
            gameItemIndex: 3,
          ),
        ],
        conceptCheckCardIds: const [],
        gameType: 'flashcards',
      );

      final slides = ScrollFeedComposer.compose(
        items: items,
        deck: deck,
        celebrateEvery: 4,
      );

      expect(slides.length, greaterThan(items.length));
      expect(slides.first.kind, ScrollSlideKind.hook);
      expect(
        slides.any((s) => s.kind == ScrollSlideKind.mcq),
        isTrue,
      );
      expect(
        slides.any((s) => s.kind == ScrollSlideKind.match),
        isTrue,
      );
      // Celebrate inserts before card 4 when celebrateEvery is 4.
      expect(slides.where((s) => s.kind == ScrollSlideKind.hook).length, 2);
    });
  });
}
