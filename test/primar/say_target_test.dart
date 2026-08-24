import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';
import 'package:prepskul/features/primar/presentation/say_it_button.dart';

/// What a child is invited to say has to be the thing they would actually say.
///
/// The failure this guards against is silent and total: a target of "5" can
/// never match a child saying "five", so speaking practice would appear to
/// work, ask for a number, and refuse every correct answer — in the one subject
/// where saying the answer is easiest.
void main() {
  const spokenNumbers = {
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
    'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
    'sixteen', 'seventeen', 'eighteen', 'nineteen', 'twenty',
  };

  group('numbers are offered as words, never as digits', () {
    test('every numeracy target is a word a child could say', () {
      var checked = 0;
      for (var level = 1; level <= 10; level++) {
        for (var i = 0; i < 200; i++) {
          final item = generateForSubject(Subject.numeracy, level, Random(level * 31 + i), i);
          final target = SayItButton.targetFor(item);
          if (target == null) continue;

          expect(int.tryParse(target), isNull,
              reason: 'L$level ${item.id} would ask a child to say "$target"');
          expect(spokenNumbers, contains(target),
              reason: 'L$level ${item.id} target "$target" is not a number word');
          checked++;
        }
      }
      expect(checked, greaterThan(100), reason: 'no numeracy targets were produced at all');
    });
  });

  group('what has nothing worth saying offers nothing', () {
    test('shape compositions never invite speech', () {
      // A shape made of an arc and two strokes has no name. Inviting a child to
      // say it is a question with no answer, and the recogniser would fail
      // every time through no fault of theirs.
      for (var level = 1; level <= 10; level++) {
        for (var i = 0; i < 60; i++) {
          final item = generateForSubject(Subject.shapes, level, Random(level * 17 + i), i);
          expect(SayItButton.targetFor(item), isNull,
              reason: 'L$level ${item.id} invited speech for a nameless shape');
        }
      }
    });

    test('match boards and ordering rows offer nothing', () {
      // Neither has a single answer, so there is no one thing to say back.
      var seen = 0;
      for (var level = 1; level <= 10; level++) {
        for (var i = 0; i < 200; i++) {
          final item = generateForSubject(Subject.numeracy, level, Random(level * 7 + i), i);
          if (item.interaction == Interaction.choose) continue;
          seen++;
          expect(SayItButton.targetFor(item), isNull,
              reason: '${item.id} (${item.interaction.name}) invited speech');
        }
      }
      expect(seen, greaterThan(20), reason: 'no match or ordering items were generated');
    });
  });

  group('reading offers the letter or the word itself', () {
    test('every reading target is something in the item', () {
      var checked = 0;
      for (final locale in ['en', 'fr']) {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 120; i++) {
            final item = generateForSubject(
                Subject.reading, level, Random(level * 53 + i), i, locale);
            final target = SayItButton.targetFor(item);
            if (target == null) continue;

            final answer = item.options[item.answerIndex];
            final expected = switch (answer) {
              LetterFigure(:final letter) => letter,
              WordFigure(:final word) => word,
              _ => null,
            };
            expect(target, expected,
                reason: '$locale L$level ${item.id} offers "$target" '
                    'but the answer is "$expected"');
            checked++;
          }
        }
      }
      expect(checked, greaterThan(100), reason: 'no reading targets were produced');
    });
  });

  group('the option trimmer carries it through', () {
    test('low levels keep their target', () {
      // Levels 1 to 3 are rebuilt to offer fewer choices, and that rebuild has
      // dropped fields before — it silently stripped every explanation from
      // exactly the levels the weakest children live at. Speaking would have
      // been the next thing to vanish there and nowhere else.
      var found = 0;
      for (var level = 1; level <= 3; level++) {
        for (var i = 0; i < 200; i++) {
          final item = generateForSubject(Subject.numeracy, level, Random(level * 91 + i), i);
          if (item.interaction != Interaction.choose) continue;
          if (SayItButton.targetFor(item) != null) found++;
        }
      }
      expect(found, greaterThan(50),
          reason: 'speaking is offered at level 4 and above but almost never below it');
    });
  });
}
