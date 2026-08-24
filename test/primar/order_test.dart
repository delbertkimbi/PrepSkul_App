import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/numeracy.dart';
import 'package:prepskul/features/primar/presentation/figure_view.dart';
import 'package:prepskul/features/primar/presentation/order_row.dart';

/// Drag-to-order has the same trap the match board shipped with: reaching the
/// answer is the only way out, so unless *how* a child got there is scored,
/// every board counts as a success and the staircase climbs on nothing.
void main() {
  int? valueOf(Figure f) => switch (f) {
        NumeralFigure(:final value) => value,
        QuantityFigure(:final count) => count,
        _ => null,
      };

  group('the par is the scoring rule, so it has to be exact', () {
    test('an already-sorted row needs no moves', () {
      expect(minimumOrderMoves([0, 1, 2, 3], [0, 1, 2, 3]), 0);
    });

    test('one tile out of place costs one move', () {
      // 3 belongs first; everything else is already in order.
      expect(minimumOrderMoves([3, 0, 1, 2], [0, 1, 2, 3]), 1);
      expect(minimumOrderMoves([1, 2, 3, 0], [0, 1, 2, 3]), 1);
    });

    test('a swapped pair costs one move, not two', () {
      // Lifting one of the two and dropping it on the other side is enough.
      expect(minimumOrderMoves([1, 0, 2, 3], [0, 1, 2, 3]), 1);
    });

    test('a fully reversed row costs everything but one tile', () {
      expect(minimumOrderMoves([3, 2, 1, 0], [0, 1, 2, 3]), 3);
    });

    test('the target does not have to be the identity', () {
      // orderSolution is indices into the shuffled row, so the target is
      // usually some other permutation entirely.
      expect(minimumOrderMoves([0, 1, 2], [2, 0, 1]), 1);
      expect(minimumOrderMoves([2, 0, 1], [2, 0, 1]), 0);
    });

    test('an empty row does not divide by anything', () {
      expect(minimumOrderMoves(const [], const []), 0);
    });

    test('par never exceeds the number of tiles', () {
      final rng = Random(7);
      for (var trial = 0; trial < 400; trial++) {
        final n = 2 + rng.nextInt(4);
        final target = List<int>.generate(n, (i) => i)..shuffle(rng);
        final from = List<int>.generate(n, (i) => i)..shuffle(rng);
        final par = minimumOrderMoves(from, target);
        expect(par, inInclusiveRange(0, n - 1));
      }
    });
  });

  group('what the generator hands over', () {
    List<PrimarItem> orderItemsAt(int level) => [
          for (var i = 0; i < 400; i++)
            generateNumeracyItem(level, Random(level * 53 + i), i),
        ].where((it) => it.interaction == Interaction.order).toList();

    test('ordering actually appears where the curriculum says it does', () {
      expect(orderItemsAt(5), isNotEmpty, reason: 'level 5 promises ordering');
      expect(orderItemsAt(6), isNotEmpty, reason: 'level 6 promises ordering');
    });

    test('no row is ever handed over already solved', () {
      // A question that opens on its own answer teaches nothing and scores as
      // a success — the worst combination available.
      for (final level in [5, 6]) {
        for (final item in orderItemsAt(level)) {
          final par = minimumOrderMoves(
            List<int>.generate(item.orderItems.length, (i) => i),
            item.orderSolution,
          );
          expect(par, greaterThan(0),
              reason: 'L$level ${item.id} starts sorted');
        }
      }
    });

    test('the solution really is smallest to largest', () {
      for (final level in [5, 6]) {
        for (final item in orderItemsAt(level)) {
          final ordered = [
            for (final k in item.orderSolution) valueOf(item.orderItems[k])!,
          ];
          for (var i = 1; i < ordered.length; i++) {
            expect(ordered[i], greaterThan(ordered[i - 1]),
                reason: 'L$level ${item.id}: $ordered');
          }
        }
      }
    });

    test('no two tiles hold the same amount', () {
      // Two identical tiles make more than one arrangement correct, and the
      // one the solution names would be the only accepted answer.
      for (final level in [5, 6]) {
        for (final item in orderItemsAt(level)) {
          final values = item.orderItems.map(valueOf).toList();
          expect(values.toSet().length, values.length, reason: '${item.id}: $values');
        }
      }
    });
  });

  group('the board itself', () {
    PrimarItem firstOrderItem() {
      for (var i = 0; i < 400; i++) {
        final item = generateNumeracyItem(5, Random(53 * 5 + i), i);
        if (item.interaction == Interaction.order) return item;
      }
      throw StateError('level 5 generated no ordering item');
    }

    testWidgets('shows every tile and reports nothing until a move is made',
        (tester) async {
      final item = firstOrderItem();
      var solvedWith = -99;
      var misses = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OrderRow(
            item: item,
            onSolved: (over) => solvedWith = over,
            onMiss: () => misses++,
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(FigureView), findsNWidgets(item.orderItems.length));
      // The board must not fire on first build. An order item that opened
      // already sorted would do exactly that, and score as a clean success.
      expect(solvedWith, -99, reason: 'reported a result before any move');
      expect(misses, 0);
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 360.0, 390.0]) {
      testWidgets('every tile is fully on screen at ${width.toInt()}pt', (tester) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final item = firstOrderItem();
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OrderRow(item: item, onSolved: (_) {}, onMiss: () {}),
            ),
          ),
        ));
        await tester.pump();

        // The row deliberately does not scroll, so a tile past the right edge
        // is a tile a child can neither see nor compare — and nothing throws
        // when that happens, which is why this measures rather than catching.
        final tiles = find.byType(FigureView);
        expect(tiles, findsNWidgets(item.orderItems.length));
        for (var i = 0; i < item.orderItems.length; i++) {
          final box = tester.getRect(tiles.at(i));
          expect(box.left, greaterThanOrEqualTo(-0.5), reason: 'tile $i off the left edge');
          expect(box.right, lessThanOrEqualTo(width + 0.5),
              reason: 'tile $i runs to ${box.right} on a ${width}pt screen');
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
