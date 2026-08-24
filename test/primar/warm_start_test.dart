import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/mastery.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';

/// Does a returning child actually get a better session?
///
/// "Grows with them" has to be measurable or it is a slogan. These tests assert
/// three things a child would feel: they are not re-tested on what they already
/// proved, their first question is one they can do, and the session is shorter.
void main() {
  /// A child of a fixed true ability answering probabilistically.
  ({Placement placement, List<int> levels, bool firstCorrect}) simulate({
    required int trueLevel,
    required int seed,
    int? beginAt,
    int? length,
  }) {
    var state = startSession(
      subject: Subject.numeracy,
      seed: seed,
      beginAt: beginAt,
      length: length,
    );
    final rng = Random(seed + 5);
    final levels = <int>[];
    bool? firstCorrect;

    while (!state.finished) {
      final item = nextItem(state);
      levels.add(item.level);
      // Knowledge plus a guess across the options actually offered. Modelling a
            // child who never guesses made every accuracy figure pessimistic, and
            // produced a false alarm about the weakest learners.
            final know = 1 / (1 + exp((item.level - trueLevel) * 1.6));
            // A match board has no options, so there is nothing to guess from — and
            // 1/0 would make the simulated child answer everything correctly.
            // Joining three pairs by luck is close enough to impossible.
            final guess = item.options.isEmpty ? 0.02 : 1 / item.options.length;
            final p = know + (1 - know) * guess;
      final correct = rng.nextDouble() < p;
      firstCorrect ??= correct;
      state = recordAttempt(
        state,
        Attempt(
          itemId: item.id,
          level: item.level,
          correct: correct,
          elapsedMs: 3000,
        ),
      );
    }
    return (
      placement: computePlacement(state),
      levels: levels,
      firstCorrect: firstCorrect ?? false
    );
  }

  group('warm start', () {
    test('opens one rung below the last placement, never above it', () {
      // Opening on the exact converged level is a coin-flip first question.
      expect(warmStartFrom(8), 7);
      expect(warmStartFrom(5.4), 4);
      expect(warmStartFrom(1), 1, reason: 'must not fall below the floor');
      expect(warmStartFrom(10), 9);
      expect(warmStartFrom(null), startLevel, reason: 'a new child starts at the default');
    });

    test('a struggling child no longer opens on a question above them', () {
      // This test began as "warm start gives everyone an easier first
      // question", and the simulation falsified it: a cold start opens a
      // level-8 child on a level-3 item and they win 60/60. The cost of a cold
      // start for a strong child is boredom, not failure — covered separately.
      //
      // The child a cold start genuinely hurts is the weak one, who is opened
      // at level 3 when they work at level 2.
      var warmWins = 0;
      var coldWins = 0;
      const runs = 80;
      const trueLevel = 2;

      for (var r = 0; r < runs; r++) {
        if (simulate(
          trueLevel: trueLevel,
          seed: r * 17,
          beginAt: warmStartFrom(trueLevel.toDouble()),
          length: returningSessionLength,
        ).firstCorrect) {
          warmWins++;
        }
        if (simulate(trueLevel: trueLevel, seed: r * 17).firstCorrect) coldWins++;
      }

      expect(warmWins, greaterThan(coldWins),
          reason: 'warm $warmWins vs cold $coldWins — a struggling child should '
              'not meet a wall on their first question back');
    });

    test('a warm session is challenging, not merely easy', () {
      // A session a child wins outright teaches nothing and measures nothing.
      // The staircase targets roughly 70%; this asserts warm starts land in a
      // band that is winnable but real.
      for (final trueLevel in [3, 6, 9]) {
        var accuracy = 0.0;
        const runs = 40;
        for (var r = 0; r < runs; r++) {
          accuracy += simulate(
            trueLevel: trueLevel,
            seed: r * 71 + trueLevel,
            beginAt: warmStartFrom(trueLevel.toDouble()),
            length: returningSessionLength,
          ).placement.accuracy;
        }
        final mean = accuracy / runs;
        expect(mean, greaterThan(0.5),
            reason: 'true $trueLevel: ${(mean * 100).round()}% is a wall');
        expect(mean, lessThan(0.95),
            reason: 'true $trueLevel: ${(mean * 100).round()}% is a walkover');
      }
    });

    test('a strong child is not dragged back through easy items', () {
      const trueLevel = 8;
      final cold = simulate(trueLevel: trueLevel, seed: 99);
      final warm = simulate(
        trueLevel: trueLevel,
        seed: 99,
        beginAt: warmStartFrom(trueLevel.toDouble()),
        length: returningSessionLength,
      );

      final coldEasy = cold.levels.where((l) => l <= 4).length;
      final warmEasy = warm.levels.where((l) => l <= 4).length;

      // Boredom is a drop-off mechanism just as much as failure is.
      expect(warmEasy, lessThan(coldEasy),
          reason: 'warm saw $warmEasy easy items, cold saw $coldEasy');
    });

    test('a shorter warm session still places the child accurately', () {
      for (final trueLevel in [2, 5, 8]) {
        const runs = 40;
        var sum = 0.0;
        var provisional = 0;

        for (var r = 0; r < runs; r++) {
          final result = simulate(
            trueLevel: trueLevel,
            seed: r * 131 + trueLevel,
            beginAt: warmStartFrom(trueLevel.toDouble()),
            length: returningSessionLength,
          );
          sum += result.placement.level;
          if (result.placement.provisional) provisional++;
        }

        final estimate = sum / runs;
        // Four fewer items must not cost accuracy, or the shorter session is
        // just a worse session.
        expect((estimate - trueLevel).abs(), lessThan(1.5),
            reason: 'true $trueLevel estimated ${estimate.toStringAsFixed(2)} '
                'in $returningSessionLength items');
        expect(provisional, lessThan(runs ~/ 2),
            reason: 'true $trueLevel: $provisional/$runs never settled');
      }
    });

    test('session length is honoured exactly', () {
      var state = startSession(
        subject: Subject.numeracy,
        seed: 3,
        beginAt: 6,
        length: returningSessionLength,
      );
      var guard = 0;
      while (!state.finished && guard < 100) {
        final item = nextItem(state);
        state = recordAttempt(
          state,
          Attempt(itemId: item.id, level: item.level, correct: guard.isEven, elapsedMs: 1000),
        );
        guard++;
      }
      expect(state.attempts.length, returningSessionLength);
    });
  });
}
