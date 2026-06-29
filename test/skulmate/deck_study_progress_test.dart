import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/services/deck_study_progress_service.dart';

void main() {
  group('DeckStudyProgressService.percentForDeck', () {
    test('returns 0 for fresh deck', () {
      expect(
        DeckStudyProgressService.percentForDeck(
          progress: const DeckStudyProgress(),
          totalCards: 10,
        ),
        0,
      );
    });

    test('returns 100 when all journey steps done', () {
      expect(
        DeckStudyProgressService.percentForDeck(
          progress: const DeckStudyProgress(
            cardsRevealed: 5,
            notesViewed: true,
            conceptPassed: true,
            modesCompleted: ['quiz', 'flashcards'],
            sessionCompleted: true,
          ),
          totalCards: 10,
        ),
        100,
      );
    });
  });
}
