import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/items.dart';
import 'package:prepskul/features/primar/domain/mastery.dart';
import 'package:prepskul/features/primar/domain/strokes.dart';

/// Parity checks for the Dart port.
///
/// These mirror the checks the TypeScript reference had to pass, so a bug that
/// was already found and fixed once cannot quietly reappear in this language.
void main() {
  group('item validity', () {
    test('every level produces well-formed items', () {
      for (var level = 1; level <= 10; level++) {
        for (var i = 0; i < 200; i++) {
          final item = generateItem(level, Random(level * 1000 + i), i);

          expect(item.options.length, 4, reason: 'L$level item $i option count');
          expect(item.answerIndex, greaterThanOrEqualTo(0), reason: 'L$level item $i answer present');
          expect(item.answer, isNotEmpty, reason: 'L$level item $i empty answer');
          expect(item.operandA, isNotEmpty, reason: 'L$level item $i empty operand A');
          expect(item.operandB, isNotEmpty, reason: 'L$level item $i empty operand B');
          expect(
            shapesEqual(item.options[item.answerIndex], item.answer),
            isTrue,
            reason: 'L$level item $i answerIndex mismatch',
          );

          final keys = item.options.map(shapeKey).toSet();
          expect(keys.length, 4, reason: 'L$level item $i has duplicate options');
          for (final option in item.options) {
            expect(option, isNotEmpty, reason: 'L$level item $i has an empty option');
          }
        }
      }
    });

    test('answer is always reachable by applying the stated operation', () {
      for (var level = 1; level <= 10; level++) {
        for (var i = 0; i < 120; i++) {
          final item = generateItem(level, Random(level * 31 + i), i);
          final expected = item.op == Operation.add
              ? shapeUnion(item.operandA, item.operandB)
              : shapeDifference(item.operandA, item.operandB);
          expect(shapesEqual(item.answer, expected), isTrue,
              reason: 'L$level item $i answer does not follow from operands');
        }
      }
    });
  });

  group('stroke vocabulary', () {
    test('horizontal arcs are not the same circle as the vertical pair', () {
      // Regression: at radius 28 arcT/arcB traced the identical circle drawn by
      // arcL + arcR, so adding one painted nothing and two different shapes
      // rendered pixel-identical. A child could be marked wrong for an answer
      // that looked correct.
      final lens = strokes[StrokeId.arcT]!.build().getBounds();
      final circleHalf = strokes[StrokeId.arcL]!.build().getBounds();
      expect(
        lens.height,
        isNot(closeTo(circleHalf.width, 0.5)),
        reason: 'arcT bulge must differ from the circle radius',
      );
    });

    test('every stroke paints a path with real extent', () {
      for (final id in allStrokeIds) {
        final bounds = strokes[id]!.build().getBounds();
        // Not Rect.isEmpty — a straight horizontal line has zero height and is
        // still perfectly visible.
        expect(bounds.width > 0 || bounds.height > 0, isTrue, reason: '$id paints nothing');
        expect(bounds.longestSide, greaterThan(10), reason: '$id is suspiciously small');
      }
    });
  });

  group('adaptive staircase', () {
    /// A child whose true ability is [trueLevel] answers correctly with a
    /// probability that falls off as items climb past that level.
    Placement simulate(int trueLevel, int seed) {
      var state = startSession(seed: seed);
      final rng = Random(seed + 5);
      while (!state.finished) {
        final item = nextItem(state);
        final gap = item.level - trueLevel;
        final know = 1 / (1 + exp(gap * 1.6));
        // A match board has no options, so there is nothing to guess from — and
            // 1/0 would make the simulated child answer everything correctly.
            // Joining three pairs by luck is close enough to impossible.
            final guess = item.options.isEmpty ? 0.02 : 1 / item.options.length;
            final p = know + (1 - know) * guess;
        state = recordAttempt(
          state,
          Attempt(
            itemId: item.id,
            level: item.level,
            correct: rng.nextDouble() < p,
            elapsedMs: 3000 + rng.nextInt(4000),
          ),
        );
      }
      return computePlacement(state);
    }

    test('converges within 1.5 levels across the ability range', () {
      for (final trueLevel in [2, 4, 6, 8]) {
        const runs = 40;
        var sum = 0.0;
        var accuracy = 0.0;
        for (var r = 0; r < runs; r++) {
          final p = simulate(trueLevel, r * 131 + trueLevel);
          sum += p.level;
          accuracy += p.accuracy;
        }
        final estimated = sum / runs;
        final meanAccuracy = accuracy / runs;

        expect(
          (estimated - trueLevel).abs(),
          lessThan(1.5),
          reason: 'true $trueLevel estimated ${estimated.toStringAsFixed(2)}',
        );
        // The whole point of 2-up/1-down: most of what a child sees, they get
        // right. If this drifts low the experience becomes a wall of failure.
        expect(meanAccuracy, greaterThan(0.5),
            reason: 'true $trueLevel accuracy ${meanAccuracy.toStringAsFixed(2)} too punishing');
      }
    });

    test('a session always ends after the fixed number of items', () {
      var state = startSession(seed: 7);
      var guard = 0;
      while (!state.finished && guard < 100) {
        final item = nextItem(state);
        state = recordAttempt(
          state,
          Attempt(itemId: item.id, level: item.level, correct: guard.isEven, elapsedMs: 2000),
        );
        guard++;
      }
      expect(state.finished, isTrue);
      expect(state.attempts.length, sessionLength);
    });
  });

  group('mastery row', () {
    test('maps into the skulmate_concept_mastery shape', () {
      var state = startSession(seed: 99);
      while (!state.finished) {
        final item = nextItem(state);
        state = recordAttempt(
          state,
          Attempt(itemId: item.id, level: item.level, correct: true, elapsedMs: 1500),
        );
      }
      final row = toMasteryUpsert(computePlacement(state), primarTopicId).toJson();

      expect(row['topic_id'], primarTopicId);
      expect(row['mastery_score'], inInclusiveRange(0, 1));
      expect(row['question_total'], sessionLength);
      expect(row['correct_total'], sessionLength);
      expect(row['weak_streak'], 0);
      expect(row['last_session_accuracy'], closeTo(1.0, 0.0001));
    });
  });
}
