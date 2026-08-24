import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/mastery.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';

void main() {
  test('probe: accuracy and item spread by true ability', () {
    for (final trueLevel in [1, 2, 3, 5, 8]) {
      var acc = 0.0;
      final seen = <int, int>{};
      const runs = 60;
      for (var r = 0; r < runs; r++) {
        var state = startSession(subject: Subject.numeracy, seed: r * 61 + trueLevel);
        final rng = Random(r + 3);
        while (!state.finished) {
          final item = nextItem(state);
          seen[item.level] = (seen[item.level] ?? 0) + 1;
          // Knowledge, plus a guess across whatever choices are on offer.
          final know = 1 / (1 + exp((item.level - trueLevel) * 1.6));
          final guess = 1 / item.options.length;
          final p = know + (1 - know) * guess;
          state = recordAttempt(state, Attempt(
            itemId: item.id, level: item.level,
            correct: rng.nextDouble() < p, elapsedMs: 100));
        }
        acc += computePlacement(state).accuracy;
      }
      final dist = (seen.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
          .map((e) => 'L${e.key}:${e.value}').join(' ');
      // ignore: avoid_print
      print('true $trueLevel -> ${((acc / runs) * 100).round()}%   $dist');
    }
  });
}
