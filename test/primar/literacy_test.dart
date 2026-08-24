import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/literacy.dart';
import 'package:prepskul/features/primar/presentation/word_picture.dart';

/// Same bar as the other two engines: an item that can mark a correct child
/// wrong is worse than no item at all.
void main() {
  String? textOf(Figure f) => switch (f) {
        LetterFigure(:final letter) => letter,
        WordFigure(:final word) => word,
        _ => null,
      };

  for (final locale in ['en', 'fr']) {
    group('[$locale] item validity', () {
      test('every level produces well-formed items', () {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 250; i++) {
            final item = generateLiteracyItem(level, Random(level * 613 + i),
                index: i, locale: locale);

            if (item.interaction == Interaction.spell) {
              expect(item.spellTarget, isNotEmpty);
              expect(item.spellPool.toSet(), containsAll(item.spellTarget.toSet()));
              continue;
            }
            expect(item.options.length, 4, reason: 'L$level item $i option count');
            expect(item.answerIndex, inInclusiveRange(0, 3));
            expect(item.prompt, isNotEmpty);

            final texts = item.options.map(textOf).toList();
            expect(texts.whereType<String>().length, 4,
                reason: 'L$level item $i has a non-text option');
            // Two identical options means a child can be right and still be
            // marked wrong — the bug this suite exists to prevent.
            expect(texts.toSet().length, 4,
                reason: 'L$level item $i duplicate options: $texts');
            for (final t in texts.whereType<String>()) {
              expect(t.trim(), isNotEmpty, reason: 'L$level item $i blank option');
            }
          }
        }
      });

      test('spoken prompts are always present when the item needs one', () {
        for (var level = 3; level <= 10; level++) {
          for (var i = 0; i < 200; i++) {
            final item = generateLiteracyItem(level, Random(level * 31 + i),
                index: i, locale: locale);
            // Anything above pure shape matching asks a question out loud. If
            // the line is missing the child is shown a blank and no
            // instruction, which is unusable for a non-reader.
            final visualOnly = item.prompt.whereType<LetterFigure>().isNotEmpty;
            if (!visualOnly) {
              expect(item.spoken, isNotNull,
                  reason: 'L$level item $i has no spoken prompt');
              expect(item.spoken, isNotEmpty);
            }
          }
        }
      });
    });

    group('[$locale] the answer is genuinely the answer', () {
      test('the marked option matches what is spoken', () {
        var checkedWords = 0;
        for (var level = 6; level <= 10; level++) {
          for (var i = 0; i < 300; i++) {
            final item = generateLiteracyItem(level, Random(level * 97 + i),
                index: i, locale: locale);
            final spoken = item.spoken ?? '';
            if (!spoken.startsWith('word:')) continue;
            // A spelling item is checked by its tiles, not by a marked option.
            if (item.interaction == Interaction.spell) {
              expect(item.spellTarget.join(), spoken.substring(5),
                  reason: 'L$level item $i spells something other than it says');
              continue;
            }

            final word = spoken.substring(5);
            final answer = textOf(item.options[item.answerIndex])!;

            if (item.options[item.answerIndex] is WordFigure) {
              expect(answer, word, reason: 'L$level item $i spoke "$word" but marked "$answer"');
            } else {
              // Initial-sound item: the marked letter must start the word.
              expect(answer, word[0],
                  reason: 'L$level item $i spoke "$word" but marked letter "$answer"');
            }
            checkedWords++;
          }
        }
        expect(checkedWords, greaterThan(50), reason: 'word items never generated');
      });
    });

    group('[$locale] speech catalogue', () {
      test('every spoken prompt an item can produce is in the catalogue', () {
        final catalogue = literacySpeechCatalogue(locale: locale).toSet();
        final missing = <String>{};

        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 400; i++) {
            final item = generateLiteracyItem(level, Random(level * 7 + i),
                index: i, locale: locale);
            final s = item.spoken;
            if (s == null) continue;
            // Fixed UI phrases live in the voice catalogue, not this one.
            if (!s.startsWith('sound:') && !s.startsWith('word:')) continue;
            if (!catalogue.contains(s)) missing.add(s);
          }
        }

        // A prompt with no recorded audio is silence, and silence on a reading
        // item is an unanswerable question.
        expect(missing, isEmpty, reason: 'these prompts have no audio: $missing');
      });
    });
  }

  group('a word shown to be read always has a picture', () {
    test('every WordFigure offered can be drawn', () {
      // The rule that separates reading from shape-matching. It is one list
      // edit away from being broken, so it is asserted rather than remembered.
      for (final locale in ['en', 'fr']) {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 200; i++) {
            final item = generateLiteracyItem(level, Random(level * 53 + i),
                index: i, locale: locale);
            for (final f in item.options) {
              if (f is! WordFigure) continue;
              expect(WordPicture.canDraw(f.word), isTrue,
                  reason: '[$locale] L$level shows "${f.word}" with no picture — '
                      'a child choosing it is matching shapes, not reading');
            }
          }
        }
      }
    });
  });

  group('difficulty progression', () {
    test('later levels lean on reading rather than shape matching', () {
      int wordItems(int level) {
        var n = 0;
        for (var i = 0; i < 300; i++) {
          final item = generateLiteracyItem(level, Random(level * 11 + i), index: i);
          if (item.options.isNotEmpty && item.options.first is WordFigure) n++;
          if (item.interaction == Interaction.spell) n++;
        }
        return n;
      }

      expect(wordItems(1), 0, reason: 'level 1 should never ask for whole words');
      expect(wordItems(10), greaterThan(200), reason: 'level 10 should be reading words');
    });
  });
}
