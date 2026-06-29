import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/models/game_model.dart';
import 'package:prepskul/features/skulmate/models/revision_deck_model.dart';
import 'package:prepskul/features/skulmate/services/deck_game_projector.dart';
import 'package:prepskul/features/skulmate/widgets/deck_study_launcher_sheet.dart';

GameModel _sampleGame() {
  return GameModel(
    id: 'g1',
    userId: 'u1',
    title: 'Biology',
    gameType: GameType.flashcards,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    items: [
      GameItem(term: 'Old', definition: 'Card'),
    ],
    metadata: GameMetadata(
      source: 'text',
      generatedAt: DateTime.now().toIso8601String(),
      difficulty: 'medium',
      totalItems: 1,
      topic: 'Biology',
    ),
  );
}

RevisionDeckModel _sampleDeck() {
  return RevisionDeckModel(
    id: 'g1',
    title: 'Biology',
    topicLabel: 'Biology',
    sourceType: 'text',
    notes: 'Notes',
    knowledgeUnits: const [
      RevisionKnowledgeUnit(id: 'core-1', name: 'Core', priority: 'high'),
    ],
    cards: const [
      RevisionDeckCard(
        id: 'c1',
        knowledgeUnitId: 'core-1',
        cardType: RevisionDeckCardType.termDef,
        prompt: 'Mitochondria',
        answer: 'Powerhouse of the cell',
      ),
      RevisionDeckCard(
        id: 'c2',
        knowledgeUnitId: 'core-1',
        cardType: RevisionDeckCardType.mcq,
        prompt: 'What gas do plants absorb?',
        answer: 'Carbon dioxide',
        distractors: ['Oxygen', 'Nitrogen'],
      ),
      RevisionDeckCard(
        id: 'c3',
        knowledgeUnitId: 'core-1',
        cardType: RevisionDeckCardType.pair,
        prompt: 'H2O',
        answer: 'Water',
      ),
    ],
    conceptCheckCardIds: const ['c1', 'c2', 'c3'],
    linkedGameId: 'g1',
    gameType: 'flashcards',
  );
}

void main() {
  test('projects quiz items with indexed correctAnswer', () {
    final projected = DeckGameProjector.project(
      game: _sampleGame(),
      deck: _sampleDeck(),
      studyMode: DeckStudyMode.quiz,
    );

    expect(projected.gameType, GameType.quiz);
    expect(projected.items.length, greaterThanOrEqualTo(2));
    final mcq = projected.items.firstWhere(
      (item) => (item.question ?? '').contains('gas do plants absorb'),
    );
    expect(mcq.options, isNotNull);
    expect(mcq.correctAnswer, isA<int>());
  });

  test('projects flashcards from mixed deck', () {
    final projected = DeckGameProjector.project(
      game: _sampleGame(),
      deck: _sampleDeck(),
      studyMode: DeckStudyMode.memorise,
    );

    expect(projected.gameType, GameType.flashcards);
    expect(
      projected.items.any(
        (item) =>
            item.term == 'Mitochondria' &&
            item.definition == 'Powerhouse of the cell',
      ),
      isTrue,
    );
  });

  test('projects matching pairs', () {
    final projected = DeckGameProjector.project(
      game: _sampleGame(),
      deck: _sampleDeck(),
      studyMode: DeckStudyMode.matching,
    );

    expect(projected.gameType, GameType.matching);
    expect(
      projected.items.any(
        (item) => item.leftItem == 'H2O' && item.rightItem == 'Water',
      ),
      isTrue,
    );
  });
}
