/// Phase D4 — SM-2 lite (mirrors PrepSkul_Web/lib/skulmate/spaced-repetition.ts).
library;

class ReviewState {
  final double easeFactor;
  final int intervalDays;
  final int repetitions;

  const ReviewState({
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
  });
}

class Sm2UpdateResult {
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime nextReviewAt;
  final int lastQuality;

  const Sm2UpdateResult({
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
    required this.nextReviewAt,
    required this.lastQuality,
  });
}

const double _minEase = 1.3;
const double _defaultEase = 2.5;
const int _failedRetryMinutes = 10;

double _roundEase(double n) => (n * 100).round() / 100;

Sm2UpdateResult computeSm2Update(
  ReviewState? previous,
  int quality, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now().toUtc();
  final q = quality.clamp(0, 5);

  var ease = previous?.easeFactor ?? _defaultEase;
  var reps = previous?.repetitions ?? 0;
  var interval = previous?.intervalDays ?? 0;

  if (q < 3) {
    reps = 0;
    interval = 0;
    ease = (ease - 0.2).clamp(_minEase, 3.5);
  } else {
    if (reps == 0) {
      interval = 1;
    } else if (reps == 1) {
      interval = 3;
    } else {
      interval = (interval * ease).round().clamp(1, 365);
    }
    reps += 1;
    ease = ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    ease = ease.clamp(_minEase, 3.5);
  }

  final nextReviewAt = interval == 0
      ? clock.add(const Duration(minutes: _failedRetryMinutes))
      : clock.add(Duration(days: interval));

  return Sm2UpdateResult(
    easeFactor: _roundEase(ease),
    intervalDays: interval,
    repetitions: reps,
    nextReviewAt: nextReviewAt,
    lastQuality: q,
  );
}

int qualityFromFlashcardKnown(bool known) => known ? 4 : 1;

int qualityFromQuizAnswer({required bool isCorrect, bool usedHint = false}) {
  if (isCorrect && !usedHint) return 4;
  if (isCorrect && usedHint) return 3;
  return 1;
}

bool isReviewDue(DateTime nextReviewAt, {DateTime? now}) {
  final clock = now ?? DateTime.now().toUtc();
  return !nextReviewAt.isAfter(clock);
}

String conceptKeyFromTerm(String? term) {
  if (term == null || term.trim().isEmpty) return 'item';
  final slug = term
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final clipped = slug.length > 48 ? slug.substring(0, 48) : slug;
  return clipped.isEmpty ? 'item' : clipped;
}
