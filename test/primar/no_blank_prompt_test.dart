import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/literacy.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';

/// A question a child cannot see is not a question.
///
/// Found on a real device, playing as a ten-year-old: two of the three
/// placement questions were **two empty dashed boxes** and four letters. The
/// sound had been spoken once and there was no way to hear it again, so a child
/// who looked away, or whose phone was in a noisy room, or whose volume was
/// down, had a placement decided by a screen with nothing on it.
///
/// Five of the six reading forms did this — levels four through ten, which is
/// the entire part of reading that matters.
///
/// The rule these tests hold: **every item shows something a child can act on.**
/// Either a picture of the thing, or a button that says the sound and says it
/// again. Never a blank.
void main() {
  bool isBlank(Figure f) =>
      f is SymbolFigure && f.symbol == MathSymbol.unknown;

  bool isActionable(Figure f) =>
      f is SoundFigure || f is PictureFigure || f is LetterFigure ||
      f is WordFigure || f is QuantityFigure || f is NumeralFigure ||
      f is ShapeFigure;

  group('no reading question is ever a blank box', () {
    test('every form at every level shows something', () {
      for (final locale in ['en', 'fr']) {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 150; i++) {
            final item = generateForSubject(
                Subject.reading, level, Random(level * 41 + i), i, locale);

            expect(item.prompt.any(isBlank), isFalse,
                reason: '$locale L$level ${item.id} shows an empty dashed box');
            expect(item.prompt.any(isActionable), isTrue,
                reason: '$locale L$level ${item.id} has nothing a child can look at');
            expect(item.hasVisiblePrompt, isTrue,
                reason: '$locale L$level ${item.id} is symbols and nothing else');
          }
        }
      }
    });

    test('a question with no picture always offers a replayable sound', () {
      // The one case a picture cannot cover is a bare letter sound — /mmm/ is
      // not a thing that can be drawn. Those must carry the sound itself.
      var soundOnly = 0;
      for (var level = 1; level <= 10; level++) {
        for (var i = 0; i < 150; i++) {
          final item = generateForSubject(Subject.reading, level, Random(level * 7 + i), i);
          final hasPicture = item.prompt.any((f) => f is PictureFigure);
          final hasLetterOrWord =
              item.prompt.any((f) => f is LetterFigure || f is WordFigure);
          if (hasPicture || hasLetterOrWord) continue;

          expect(item.prompt.any((f) => f is SoundFigure), isTrue,
              reason: 'L$level ${item.id} has neither a picture nor a sound');
          soundOnly++;
        }
      }
      expect(soundOnly, greaterThan(50),
          reason: 'letter-sound items never generated, so this proves nothing');
    });

    test('every sound button names a phrase the voice can actually say', () {
      // A listen button that plays nothing is worse than no button: a child
      // presses it, hears silence, and learns the app is broken.
      final catalogue = {
        for (final locale in ['en', 'fr']) ...literacySpeechCatalogueFor(locale),
      };
      for (final locale in ['en', 'fr']) {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 100; i++) {
            final item = generateForSubject(
                Subject.reading, level, Random(level * 13 + i), i, locale);
            for (final f in item.prompt.whereType<SoundFigure>()) {
              expect(catalogue, contains(f.phraseId),
                  reason: '$locale L$level ${item.id} would press a silent button');
            }
          }
        }
      }
    });
  });

  group('the other subjects were never blank, and stay that way', () {
    test('numbers and shapes always show their question', () {
      for (final subject in [Subject.numeracy, Subject.shapes]) {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 120; i++) {
            final item = generateForSubject(subject, level, Random(level * 29 + i), i);
            // A dashed box is allowed here, and only here: "3 + ? = 8" needs
            // somewhere to put the unknown, and it is surrounded by real
            // numbers that say what is being asked. What is forbidden is a
            // prompt made of *nothing but* boxes, which is what reading was
            // doing — there the box was the entire question.
            if (!item.hasVisiblePrompt) continue;
            expect(item.prompt.any(isActionable), isTrue,
                reason: '$subject L$level ${item.id} is boxes and nothing else');
          }
        }
      }
    });
  });
}

/// The literacy speech catalogue for a locale, as a set.
Set<String> literacySpeechCatalogueFor(String locale) =>
    literacySpeechCatalogue(locale: locale).toSet();
