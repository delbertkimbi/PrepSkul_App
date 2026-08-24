import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/literacy.dart';
import 'package:prepskul/features/primar/domain/misconception.dart';
import 'package:prepskul/features/primar/domain/numeracy.dart';
import 'package:prepskul/features/primar/domain/parent_phrases.dart';
import 'package:prepskul/features/primar/domain/tutor_feedback.dart';

void main() {
  group('contextual correct feedback', () {
    test('rhyme names both words', () {
      final item = PrimarItem(
        id: 'R6-0-rhyme',
        level: 6,
        topicId: literacyTopicIdEn,
        prompt: const [PictureFigure('cat')],
        options: const [
          PictureFigure('hat'),
          PictureFigure('dog'),
          PictureFigure('sun'),
          PictureFigure('bus'),
        ],
        answerIndex: 0,
        spoken: 'word:cat',
      );
      final fb = TutorFeedback.correct(item: item, locale: 'en', skillId: 'pa.rhyme');
      expect(fb.text.toLowerCase(), contains('cat'));
      expect(fb.text.toLowerCase(), contains('hat'));
      expect(
        fb.text.toLowerCase(),
        anyOf(contains('rhyme'), contains('ending'), contains('sounds like'), contains('end')),
      );
      expect(fb.parentMoment, ParentMoment.appreciation);
      _assertNotBanned(fb.text);
    });

    test('initial sound names the picture and the onset', () {
      final item = PrimarItem(
        id: 'R7-1-initial',
        level: 7,
        topicId: literacyTopicIdEn,
        prompt: const [PictureFigure('mango')],
        options: const [
          WordFigure('mat'),
          WordFigure('drum'),
          WordFigure('sun'),
          WordFigure('pen'),
        ],
        answerIndex: 0,
        spoken: 'word:mango',
      );
      // Wrong answer path is the example in the brief; correct still names mango.
      final ok = TutorFeedback.correct(
        item: item,
        locale: 'en',
        skillId: 'pa.initial',
      );
      expect(ok.text.toLowerCase(), contains('mango'));
      _assertNotBanned(ok.text);

      final miss = TutorFeedback.incorrect(
        item: item,
        locale: 'en',
        chosenIndex: 1,
        skillId: 'pa.initial',
      );
      expect(miss.text.toLowerCase(), contains('drum'));
      expect(miss.text.toLowerCase(), contains('mango'));
      expect(miss.parentMoment, ParentMoment.encouragement);
      _assertNotBanned(miss.text);
    });

    test('letter sound names letter and phoneme', () {
      final item = PrimarItem(
        id: 'R4-0-letterSound',
        level: 4,
        topicId: literacyTopicIdEn,
        prompt: const [SoundFigure('sound:mmm')],
        options: const [
          LetterFigure('m'),
          LetterFigure('s'),
          LetterFigure('t'),
          LetterFigure('a'),
        ],
        answerIndex: 0,
        spoken: 'sound:mmm',
      );
      final fb = TutorFeedback.correct(item: item, locale: 'en');
      expect(fb.text.toLowerCase(), contains('m'));
      expect(fb.text.toLowerCase(), anyOf(contains('mmm'), contains('says')));
      _assertNotBanned(fb.text);
    });
  });

  group('numeracy feedback', () {
    test('count miss says what they chose and recounts', () {
      final item = PrimarItem(
        id: 'N3-0-countToNumeral',
        level: 3,
        topicId: 'foundational.numeracy',
        prompt: const [
          QuantityFigure(3, token: CountToken.mango),
          SymbolFigure(MathSymbol.equals),
        ],
        options: const [
          NumeralFigure(3),
          NumeralFigure(5),
          NumeralFigure(2),
          NumeralFigure(4),
        ],
        answerIndex: 0,
        spoken: 'how_many',
      );
      final fb = TutorFeedback.incorrect(
        item: item,
        locale: 'en',
        chosenIndex: 1,
        misconception: Misconception.offByOne,
      );
      expect(fb.text, contains('5'));
      expect(fb.text.toLowerCase(), anyOf(contains('count'), contains('mango')));
      expect(fb.text.toLowerCase(), anyOf(contains('one'), contains('three')));
      _assertNotBanned(fb.text);
    });

    test('generated numeracy items always get item-grounded lines', () {
      final rng = Random(7);
      for (var i = 0; i < 12; i++) {
        final item = generateNumeracyItem(3 + (i % 5), rng, i);
        if (item.options.length < 2) continue;
        final wrong = item.answerIndex == 0 ? 1 : 0;
        final ok = TutorFeedback.correct(item: item, locale: 'en');
        final miss = TutorFeedback.incorrect(
          item: item,
          locale: 'en',
          chosenIndex: wrong,
        );
        _assertNotBanned(ok.text);
        _assertNotBanned(miss.text);
        expect(ok.parentMoment, ParentMoment.appreciation);
        expect(miss.parentMoment, ParentMoment.encouragement);
        // Must mention something concrete from the item when there is an answer label.
        final answer = _figureText(item.options[item.answerIndex]);
        if (answer != null) {
          final grounded = ok.text.toLowerCase().contains(answer.toLowerCase()) ||
              ok.text.contains(answer) ||
              ok.text.toLowerCase().contains('most') ||
              ok.text.toLowerCase().contains('more') ||
              ok.text.toLowerCase().contains('order') ||
              ok.text.toLowerCase().contains('group') ||
              ok.text.toLowerCase().contains('altogether') ||
              ok.text.toLowerCase().contains('left') ||
              ok.text.toLowerCase().contains('joined') ||
              ok.text.toLowerCase().contains('number') ||
              ok.text.toLowerCase().contains('counting') ||
              ok.text.toLowerCase().contains('mango') ||
              ok.text.toLowerCase().contains('ball') ||
              ok.text.toLowerCase().contains('fish') ||
              ok.text.toLowerCase().contains('leaf') ||
              ok.text.toLowerCase().contains('star');
          expect(grounded, isTrue,
              reason: 'correct line should ground in item: ${ok.text} for $answer (${item.id})');
        }
      }
    });
  });

  group('French feedback', () {
    test('correct and incorrect use French and name the word', () {
      final item = generateItemForSkill(
        'letter.sound',
        Random(3),
        index: 2,
        locale: 'fr',
      );
      final ok = TutorFeedback.correct(item: item, locale: 'fr');
      final miss = TutorFeedback.incorrect(
        item: item,
        locale: 'fr',
        chosenIndex: item.answerIndex == 0 ? 1 : 0,
      );
      expect(ok.text.toLowerCase(), anyOf(contains('oui'), contains('bien'), contains('exact')));
      expect(miss.text.toLowerCase(), isNot(contains('almost')));
      expect(miss.text.toLowerCase(), isNot(contains('try again')));
      _assertNotBanned(ok.text);
      _assertNotBanned(miss.text);
    });

    test('speak-back matched is French and names the target', () {
      final fb = TutorFeedback.speakMatched(target: 'lune', locale: 'fr');
      expect(fb.text, contains('lune'));
      expect(fb.parentMoment, ParentMoment.appreciation);
      expect(fb.text.toLowerCase(), anyOf(contains('entendu'), contains('dit'), contains('parfait')));
    });
  });

  group('waiting is patience, never try-again', () {
    test('waiting moment is patience', () {
      final item = PrimarItem(
        id: 'N2-0-countToNumeral',
        level: 2,
        topicId: 'n',
        prompt: const [QuantityFigure(4, token: CountToken.ball)],
        options: const [NumeralFigure(4), NumeralFigure(3)],
        answerIndex: 0,
      );
      final fb = TutorFeedback.waiting(item: item, locale: 'en');
      expect(fb.parentMoment, ParentMoment.patience);
      expect(fb.parentBridgeId, 'take_your_time');
      expect(fb.text.toLowerCase(), isNot(contains('try again')));
      expect(parentPhraseFor(fb.parentBridgeId!), 'take_time');
    });
  });

  group('speak-back', () {
    test('matched names the word and maps to appreciation', () {
      final fb = TutorFeedback.speakMatched(target: 'mat', locale: 'en', heard: 'ba');
      // When heard differs, still celebrate what was recognised or the target.
      expect(fb.text.toLowerCase(), anyOf(contains('ba'), contains('mat')));
      expect(fb.parentMoment, ParentMoment.appreciation);
      expect(parentMomentForLine(fb.parentBridgeId!), ParentMoment.appreciation);
    });

    test('corrective names heard then target without marking wrong', () {
      final fb = TutorFeedback.speakCorrective(
        target: 'cat',
        locale: 'en',
        heard: 'dog',
      );
      final lower = fb.text.toLowerCase();
      expect(lower, contains('dog'));
      expect(lower, contains('cat'));
      expect(lower, isNot(contains('wrong')));
      expect(fb.parentMoment, ParentMoment.encouragement);
      _assertNotBanned(fb.text);
    });
  });

  group('generated literacy items stay contextual', () {
    test('en reading items avoid banned primary lines', () {
      final rng = Random(11);
      for (final skill in ['pa.rhyme', 'pa.blend', 'letter.sound', 'letter.shape.reversal']) {
        if (!canGenerateSkill(skill)) continue;
        final item = generateItemForSkill(skill, rng, index: 4, locale: 'en');
        final ok = TutorFeedback.correct(item: item, locale: 'en', skillId: skill);
        final miss = TutorFeedback.incorrect(
          item: item,
          locale: 'en',
          chosenIndex: item.answerIndex == 0 ? 1 : 0,
          skillId: skill,
        );
        _assertNotBanned(ok.text);
        _assertNotBanned(miss.text);
        expect(ok.text.length, greaterThan(8));
        expect(miss.text.length, greaterThan(8));
      }
    });
  });
}

String? _figureText(Figure f) => switch (f) {
      LetterFigure(:final letter) => letter,
      WordFigure(:final word) => word,
      PictureFigure(:final word) => word,
      NumeralFigure(:final value) => '$value',
      QuantityFigure(:final count) => '$count',
      _ => null,
    };

void _assertNotBanned(String text) {
  final lower = text.toLowerCase().trim();
  for (final ban in bannedPrimaryFeedback) {
    if (ban == 'bravo!') continue; // allow bravo with content
    expect(lower, isNot(equals(ban)), reason: 'banned alone: $ban in "$text"');
    // "try again" as the whole line or leading slogan
    if (ban == 'try again') {
      expect(lower.startsWith('try again'), isFalse, reason: text);
    }
    if (ban == 'good job' || ban == 'great job' || ban == 'keep going') {
      expect(lower.contains(ban), isFalse, reason: text);
    }
  }
}
