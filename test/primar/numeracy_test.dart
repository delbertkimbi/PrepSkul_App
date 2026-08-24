import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/numeracy.dart';

/// The arithmetic has to be right before anything else matters. An item that
/// marks a correct child wrong is worse than no item at all.
void main() {
  int? valueOf(Figure f) => switch (f) {
        NumeralFigure(:final value) => value,
        QuantityFigure(:final count) => count,
        _ => null,
      };

  group('item validity', () {
    test('every level produces well-formed items', () {
      for (var level = 1; level <= 10; level++) {
        for (var i = 0; i < 300; i++) {
          final item = generateNumeracyItem(level, Random(level * 977 + i), i);

          if (item.interaction == Interaction.match) {
            expect(item.matchLeft, isNotEmpty);
            expect(item.matchPairing.toSet(), hasLength(item.matchLeft.length),
                reason: 'two left items point at the same partner');
            continue;
          }
          if (item.interaction == Interaction.order) {
            expect(item.orderItems, isNotEmpty);
            expect(item.orderSolution, hasLength(item.orderItems.length),
                reason: 'L$level item $i solution does not cover the row');
            expect(item.orderSolution.toSet(), hasLength(item.orderItems.length),
                reason: 'L$level item $i sends two tiles to the same place');

            // Ordered, and never handed over already solved.
            final ordered = [for (final k in item.orderSolution) valueOf(item.orderItems[k])!];
            for (var k = 1; k < ordered.length; k++) {
              expect(ordered[k], greaterThan(ordered[k - 1]),
                  reason: 'L$level item $i solution is not smallest-first');
            }
            expect(item.orderSolution, isNot(List.generate(item.orderItems.length, (k) => k)),
                reason: 'L$level item $i opens on its own answer');
            continue;
          }
          expect(item.options.length, 4, reason: 'L$level item $i option count');
          expect(item.answerIndex, inInclusiveRange(0, 3), reason: 'L$level item $i answer index');
          expect(item.prompt, isNotEmpty, reason: 'L$level item $i empty prompt');
          expect(item.topicId, numeracyTopicId);

          // No duplicate options — two identical tiles means a child can be
          // right and still be marked wrong.
          final values = item.options.map(valueOf).toList();
          expect(values.whereType<int>().length, 4, reason: 'L$level item $i non-numeric option');
          expect(values.toSet().length, 4, reason: 'L$level item $i duplicate options: $values');

          // Nothing negative, nothing absurd on screen.
          for (final v in values.whereType<int>()) {
            expect(v, greaterThanOrEqualTo(0), reason: 'L$level item $i negative option');
            expect(v, lessThanOrEqualTo(25), reason: 'L$level item $i option too large to draw');
          }
        }
      }
    });
  });

  group('the arithmetic is actually correct', () {
    test('addition prompts resolve to the marked answer', () {
      var checked = 0;
      for (var level = 5; level <= 10; level++) {
        for (var i = 0; i < 400; i++) {
          final item = generateNumeracyItem(level, Random(level * 13 + i), i);
          final symbols = item.prompt.whereType<SymbolFigure>().map((s) => s.symbol).toList();
          if (!symbols.contains(MathSymbol.plus) || symbols.contains(MathSymbol.unknown)) continue;

          final operands = item.prompt.map(valueOf).whereType<int>().toList();
          expect(operands.length, 2, reason: 'addition should show two operands');
          expect(valueOf(item.answer), operands[0] + operands[1],
              reason: 'L$level item $i: ${operands[0]} + ${operands[1]}');
          checked++;
        }
      }
      expect(checked, greaterThan(50), reason: 'addition never generated');
    });

    test('subtraction prompts resolve to the marked answer and never go negative', () {
      var checked = 0;
      for (var level = 7; level <= 10; level++) {
        for (var i = 0; i < 400; i++) {
          final item = generateNumeracyItem(level, Random(level * 29 + i), i);
          final symbols = item.prompt.whereType<SymbolFigure>().map((s) => s.symbol).toList();
          if (!symbols.contains(MathSymbol.minus)) continue;

          final operands = item.prompt.map(valueOf).whereType<int>().toList();
          expect(operands.length, 2);
          final result = operands[0] - operands[1];
          expect(result, greaterThanOrEqualTo(0), reason: 'L$level item $i went negative');
          expect(valueOf(item.answer), result,
              reason: 'L$level item $i: ${operands[0]} - ${operands[1]}');
          checked++;
        }
      }
      expect(checked, greaterThan(50), reason: 'subtraction never generated');
    });

    test('missing addend resolves correctly', () {
      var checked = 0;
      for (var level = 9; level <= 10; level++) {
        for (var i = 0; i < 400; i++) {
          final item = generateNumeracyItem(level, Random(level * 47 + i), i);
          final symbols = item.prompt.whereType<SymbolFigure>().map((s) => s.symbol).toList();
          if (!symbols.contains(MathSymbol.unknown)) continue;

          final shown = item.prompt.map(valueOf).whereType<int>().toList();
          expect(shown.length, 2, reason: 'missing addend shows one operand and the sum');
          final a = shown[0];
          final sum = shown[1];
          expect(valueOf(item.answer), sum - a, reason: 'L$level item $i: $a + ? = $sum');
          checked++;
        }
      }
      expect(checked, greaterThan(20), reason: 'missing addend never generated');
    });

    test('comparison marks the larger group', () {
      var checked = 0;
      for (var level = 3; level <= 5; level++) {
        for (var i = 0; i < 400; i++) {
          final item = generateNumeracyItem(level, Random(level * 71 + i), i);
          final symbols = item.prompt.whereType<SymbolFigure>().map((s) => s.symbol).toList();
          if (!symbols.contains(MathSymbol.greater)) continue;

          final counts = item.options.map(valueOf).whereType<int>().toList();
          expect(valueOf(item.answer), counts.reduce(max),
              reason: 'L$level item $i did not mark the largest group');
          checked++;
        }
      }
      expect(checked, greaterThan(20), reason: 'comparison never generated');
    });
  });

  group('difficulty progression', () {
    test('numbers grow with level', () {
      double meanMax(int level) {
        var total = 0;
        const n = 300;
        for (var i = 0; i < n; i++) {
          final item = generateNumeracyItem(level, Random(level * 7 + i), i);
          final values = [...item.prompt, ...item.options].map(valueOf).whereType<int>();
          total += values.isEmpty ? 0 : values.reduce(max);
        }
        return total / n;
      }

      final low = meanMax(2);
      final high = meanMax(9);
      expect(high, greaterThan(low * 1.5), reason: 'L2 $low vs L9 $high — not enough progression');
    });
  });
}
