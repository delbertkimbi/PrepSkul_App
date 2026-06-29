import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/models/game_model.dart';
import 'package:prepskul/features/skulmate/models/revision_deck_model.dart';
import 'package:prepskul/features/skulmate/services/deck_game_projector.dart';
import 'package:prepskul/features/skulmate/services/deck_study_progress_service.dart';
import 'package:prepskul/features/skulmate/services/revision_deck_builder.dart';
import 'package:prepskul/features/skulmate/widgets/deck_study_launcher_sheet.dart';

GameModel _quizGame() {
  return GameModel(
    id: 'g1',
    userId: 'u1',
    title: 'Biology',
    gameType: GameType.quiz,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    items: [
      GameItem(
        question: 'What absorbs light?',
        options: ['Chlorophyll', 'Oxygen', 'Water', 'CO2'],
        correctAnswer: 0,
      ),
      GameItem(
        question: 'Where does photosynthesis occur?',
        options: ['Chloroplast', 'Mitochondria', 'Nucleus', 'Ribosome'],
        correctAnswer: 0,
      ),
    ],
    metadata: GameMetadata(
      source: 'text',
      generatedAt: DateTime.now().toIso8601String(),
      difficulty: 'medium',
      totalItems: 2,
      topic: 'Photosynthesis',
    ),
  );
}

RevisionDeckModel _twoCardDeck() {
  return RevisionDeckModel(
    title: 'Bio',
    topicLabel: 'Bio',
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
        prompt: 'Chlorophyll',
        answer: 'Light-absorbing pigment',
      ),
      RevisionDeckCard(
        id: 'c2',
        knowledgeUnitId: 'core-1',
        cardType: RevisionDeckCardType.mcq,
        prompt: 'Photosynthesis occurs in the ___',
        answer: 'chloroplast',
      ),
    ],
    conceptCheckCardIds: const ['c1', 'c2'],
    gameType: 'quiz',
  );
}

void main() {
  group('Path B — deck-first flow', () {
    test('builder produces deck from generated quiz game', () {
      final deck = RevisionDeckBuilder.fromGame(_quizGame());
      expect(deck.cards.length, greaterThanOrEqualTo(2));
      expect(deck.conceptCheckCardIds, isNotEmpty);
    });

    test('study modes include all core modes when deck has 2+ cards', () {
      final modes = availableStudyModesForDeck(_twoCardDeck());
      expect(modes, contains(DeckStudyMode.quiz));
      expect(modes, contains(DeckStudyMode.memorise));
      expect(modes, contains(DeckStudyMode.matching));
      expect(modes, contains(DeckStudyMode.fillBlank));
      expect(modes, contains(DeckStudyMode.scroll));
    });

    test('small deck only offers memorise and scroll', () {
      final tiny = RevisionDeckModel(
        title: 'Tiny',
        topicLabel: 'Tiny',
        sourceType: 'text',
        notes: '',
        knowledgeUnits: const [],
        cards: const [
          RevisionDeckCard(
            id: 'only',
            knowledgeUnitId: 'core',
            cardType: RevisionDeckCardType.termDef,
            prompt: 'A',
            answer: 'B',
          ),
        ],
        conceptCheckCardIds: const [],
        gameType: 'flashcards',
      );
      final modes = availableStudyModesForDeck(tiny);
      expect(modes, [DeckStudyMode.memorise, DeckStudyMode.scroll]);
    });

    test('projector produces playable games for every study mode', () {
      final game = _quizGame();
      final deck = _twoCardDeck();

      for (final mode in [
        DeckStudyMode.quiz,
        DeckStudyMode.memorise,
        DeckStudyMode.matching,
        DeckStudyMode.fillBlank,
      ]) {
        final projected = DeckGameProjector.project(
          game: game,
          deck: deck,
          studyMode: mode,
        );
        expect(projected.isPlayable, isTrue, reason: mode.name);
        expect(projected.items.length, greaterThanOrEqualTo(2));
      }
    });

    test('journey advances Review → Ready → Practice → Master', () {
      var progress = const DeckStudyProgress();
      var steps = DeckStudyProgressService.completedSteps(
        progress: progress,
        totalCards: 6,
      );
      expect(steps, isEmpty);

      progress = progress.copyWith(cardsRevealed: 3);
      steps = DeckStudyProgressService.completedSteps(
        progress: progress,
        totalCards: 6,
      );
      expect(steps, contains(DeckJourneyStep.review));

      progress = progress.copyWith(conceptPassed: true);
      steps = DeckStudyProgressService.completedSteps(
        progress: progress,
        totalCards: 6,
      );
      expect(steps, containsAll([DeckJourneyStep.review, DeckJourneyStep.ready]));

      progress = progress.copyWith(modesCompleted: ['quiz']);
      steps = DeckStudyProgressService.completedSteps(
        progress: progress,
        totalCards: 6,
      );
      expect(steps, contains(DeckJourneyStep.practice));

      progress = progress.copyWith(
        modesCompleted: ['quiz', 'matching'],
      );
      steps = DeckStudyProgressService.completedSteps(
        progress: progress,
        totalCards: 6,
      );
      expect(steps, contains(DeckJourneyStep.master));
    });
  });
}
