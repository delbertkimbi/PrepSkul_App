import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/utils/sm2_lite.dart';

void main() {
  final now = DateTime.utc(2026, 6, 10, 12);

  group('sm2_lite D4', () {
    test('flashcard quality mapping', () {
      expect(qualityFromFlashcardKnown(true), 4);
      expect(qualityFromFlashcardKnown(false), 1);
    });

    test('quiz quality mapping', () {
      expect(qualityFromQuizAnswer(isCorrect: true), 4);
      expect(qualityFromQuizAnswer(isCorrect: true, usedHint: true), 3);
      expect(qualityFromQuizAnswer(isCorrect: false), 1);
    });

    test('first success schedules 1 day', () {
      final result = computeSm2Update(null, 4, now: now);
      expect(result.repetitions, 1);
      expect(result.intervalDays, 1);
      expect(result.nextReviewAt, DateTime.utc(2026, 6, 11, 12));
    });

    test('failure resets and retries in 10 minutes', () {
      final result = computeSm2Update(
        const ReviewState(easeFactor: 2.5, intervalDays: 3, repetitions: 2),
        1,
        now: now,
      );
      expect(result.repetitions, 0);
      expect(result.intervalDays, 0);
      expect(
        result.nextReviewAt.difference(now).inMinutes,
        10,
      );
    });

    test('isReviewDue respects clock', () {
      expect(
        isReviewDue(DateTime.utc(2026, 6, 9), now: now),
        isTrue,
      );
      expect(
        isReviewDue(DateTime.utc(2026, 6, 11), now: now),
        isFalse,
      );
    });

    test('conceptKeyFromTerm slugifies', () {
      expect(conceptKeyFromTerm('Photosynthesis'), 'photosynthesis');
      expect(conceptKeyFromTerm(''), 'item');
    });
  });
}
