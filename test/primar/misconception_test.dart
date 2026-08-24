import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/misconception.dart';

/// Knowing *what* a child got wrong is the difference between adapting and
/// merely getting harder. These assert the classifier reads the error a
/// teacher would read.
void main() {
  PrimarItem letterItem({
    required String answer,
    required List<String> options,
    bool bySound = false,
  }) =>
      PrimarItem(
        id: 'L',
        level: 3,
        topicId: 't',
        prompt: [if (!bySound) LetterFigure(answer), const SymbolFigure(MathSymbol.equals)],
        options: options.map<Figure>((l) => LetterFigure(l)).toList(),
        answerIndex: options.indexOf(answer),
        spoken: bySound ? 'sound:buh' : 'find_the_same',
      );

  PrimarItem sumItem({
    required int a,
    required int b,
    required MathSymbol op,
    required List<int> options,
    required int answer,
  }) =>
      PrimarItem(
        id: 'N',
        level: 6,
        topicId: 't',
        prompt: [
          QuantityFigure(a),
          SymbolFigure(op),
          QuantityFigure(b),
          const SymbolFigure(MathSymbol.equals),
        ],
        options: options.map<Figure>((v) => NumeralFigure(v)).toList(),
        answerIndex: options.indexOf(answer),
      );

  group('reading errors', () {
    test('b chosen for d is read as a reversal, not a shape mix-up', () {
      final item = letterItem(answer: 'd', options: ['b', 'd', 'm', 's']);
      expect(classifyMiss(item, 0), Misconception.letterReversal);
    });

    test('p and q are reversals too', () {
      final item = letterItem(answer: 'p', options: ['q', 'p', 'a', 'z']);
      expect(classifyMiss(item, 0), Misconception.letterReversal);
    });

    test('a similar-looking letter that is not a mirror is a shape confusion', () {
      final item = letterItem(answer: 'n', options: ['m', 'n', 'b', 's']);
      expect(classifyMiss(item, 0), Misconception.letterShape);
    });

    test('missing a letter asked for by sound is about the sound', () {
      // Same wrong letter, different question — and so different teaching.
      final item = letterItem(answer: 'b', options: ['m', 'b', 'n', 's'], bySound: true);
      expect(classifyMiss(item, 0), Misconception.letterSound);
    });
  });

  group('number errors', () {
    test('answering one away is a counting slip', () {
      final item = sumItem(a: 3, b: 2, op: MathSymbol.plus, options: [4, 5, 7, 9], answer: 5);
      expect(classifyMiss(item, 0), Misconception.offByOne);
    });

    test('answering with one of the operands is an echo, not a slip', () {
      // 3 is one away from 4 as well as being an operand — the echo reading is
      // the useful one, so it has to win.
      final item = sumItem(a: 3, b: 1, op: MathSymbol.plus, options: [3, 4, 6, 8], answer: 4);
      expect(classifyMiss(item, 0), Misconception.operandEcho);
    });

    test('subtracting when asked to add is the wrong operation', () {
      final item = sumItem(a: 5, b: 3, op: MathSymbol.plus, options: [2, 8, 9, 11], answer: 8);
      expect(classifyMiss(item, 0), Misconception.wrongOperation);
    });

    test('adding when asked to take away is the wrong operation', () {
      final item = sumItem(a: 7, b: 3, op: MathSymbol.minus, options: [10, 4, 5, 6], answer: 4);
      expect(classifyMiss(item, 0), Misconception.wrongOperation);
    });

    test('being far out means the quantity was never counted', () {
      final item = sumItem(a: 4, b: 3, op: MathSymbol.plus, options: [12, 7, 9, 10], answer: 7);
      expect(classifyMiss(item, 0), Misconception.countingUnstable);
    });
  });

  group('tracking a pattern rather than a slip', () {
    test('one mistake is never treated as a pattern', () {
      final tracker = MisconceptionTracker();
      tracker.record(letterItem(answer: 'd', options: ['b', 'd', 'm', 's']), 0);
      expect(tracker.dominant, isNull, reason: 'a single slip must not trigger teaching');
    });

    test('the same mistake three times becomes something to teach against', () {
      final tracker = MisconceptionTracker();
      for (var i = 0; i < 3; i++) {
        tracker.record(letterItem(answer: 'd', options: ['b', 'd', 'm', 's']), 0);
      }
      expect(tracker.dominant, Misconception.letterReversal);
      expect(tracker.summaryFor('Ayuk'), contains('mirror'));
    });

    test('the most frequent pattern wins when several recur', () {
      final tracker = MisconceptionTracker();
      for (var i = 0; i < 3; i++) {
        tracker.record(
            sumItem(a: 3, b: 2, op: MathSymbol.plus, options: [4, 5, 7, 9], answer: 5), 0);
      }
      for (var i = 0; i < 5; i++) {
        tracker.record(letterItem(answer: 'd', options: ['b', 'd', 'm', 's']), 0);
      }
      expect(tracker.dominant, Misconception.letterReversal);
    });

    test('the parent summary describes a habit, never a deficiency', () {
      final tracker = MisconceptionTracker();
      for (var i = 0; i < 3; i++) {
        tracker.record(
            sumItem(a: 3, b: 2, op: MathSymbol.plus, options: [4, 5, 7, 9], answer: 5), 0);
      }
      final summary = tracker.summaryFor('Bih')!;
      expect(summary, contains('Bih'));
      // A parent reads this about their own child.
      for (final word in ['fail', 'poor', 'weak', 'cannot', 'behind', 'struggl']) {
        expect(summary.toLowerCase(), isNot(contains(word)),
            reason: 'summary uses deficit language: "$summary"');
      }
    });
  });
}
