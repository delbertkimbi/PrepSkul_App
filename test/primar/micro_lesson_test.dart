import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/literacy.dart';
import 'package:prepskul/features/primar/domain/micro_lesson.dart';
import 'package:prepskul/features/primar/domain/misconception.dart';
import 'package:prepskul/features/primar/domain/tutor_feedback.dart';
import 'package:prepskul/features/primar/services/tutor_brain.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

void main() {
  final rhyme = PrimarItem(
    id: 'R6-0-rhyme',
    level: 6,
    topicId: literacyTopicIdEn,
    prompt: const [PictureFigure('cat')],
    options: const [
      PictureFigure('hat'),
      PictureFigure('dog'),
      PictureFigure('sun'),
    ],
    answerIndex: 0,
    spoken: 'word:cat',
  );

  final count = PrimarItem(
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
    ],
    answerIndex: 0,
    spoken: 'how_many',
  );

  final letters = PrimarItem(
    id: 'R2-0-letterShape',
    level: 2,
    topicId: literacyTopicIdEn,
    prompt: const [LetterFigure('d')],
    options: const [
      LetterFigure('b'),
      LetterFigure('d'),
      LetterFigure('m'),
    ],
    answerIndex: 1,
    spoken: 'find_the_same',
  );

  group('SessionMissWatch', () {
    test('does not trigger on the first miss', () {
      final w = SessionMissWatch();
      expect(w.onMiss('pa.rhyme'), isFalse);
      expect(w.countFor('pa.rhyme'), 1);
    });

    test('triggers on the second miss of the same skill', () {
      final w = SessionMissWatch();
      expect(w.onMiss('pa.rhyme'), isFalse);
      expect(w.onMiss('pa.rhyme'), isTrue);
    });

    test('does not trigger again on a third miss', () {
      final w = SessionMissWatch();
      w.onMiss('pa.rhyme');
      w.onMiss('pa.rhyme');
      expect(w.onMiss('pa.rhyme'), isFalse);
    });

    test('tracks skills independently', () {
      final w = SessionMissWatch();
      expect(w.onMiss('pa.rhyme'), isFalse);
      expect(w.onMiss('letter.sound'), isFalse);
      expect(w.onMiss('letter.sound'), isTrue);
      expect(w.onMiss('pa.rhyme'), isTrue);
    });
  });

  group('MicroLesson copy names the item', () {
    test('rhyme miss names the words', () {
      final lesson = MicroLesson.build(
        item: rhyme,
        locale: 'en',
        chosenIndex: 1,
        skillId: 'pa.rhyme',
      );
      final blob = '${lesson.title} ${lesson.coachLine}'.toLowerCase();
      expect(blob, contains('cat'));
      expect(blob, anyOf(contains('dog'), contains('hat')));
      expect(lesson.cta, 'Try again');
      expect(lesson.spoken.toLowerCase(), isNot(startsWith('try again')));
    });

    test('counting miss names the number and the slip', () {
      final lesson = MicroLesson.build(
        item: count,
        locale: 'en',
        chosenIndex: 1,
        skillId: 'num.count',
        misconception: Misconception.offByOne,
      );
      expect(lesson.coachLine, contains('5'));
      expect(lesson.coachLine, contains('3'));
      expect(lesson.coachLine.toLowerCase(), contains('touch'));
      expect(lesson.title.toLowerCase(), anyOf(contains('3'), contains('count')));
    });

    test('letter reversal names both letters and the mirror', () {
      final lesson = MicroLesson.build(
        item: letters,
        locale: 'en',
        chosenIndex: 0,
        skillId: 'letter.shape.reversal',
      );
      expect(lesson.misconception, Misconception.letterReversal);
      expect(lesson.coachLine.toLowerCase(), contains('b'));
      expect(lesson.coachLine.toLowerCase(), contains('d'));
      expect(lesson.coachLine.toLowerCase(), contains('mirror'));
      expect(lesson.gestureHint, isNotEmpty);
      expect(lesson.letter, 'd');
    });
  });

  group('French micro-lesson', () {
    test('coach line and CTA are French and still name the item', () {
      final lesson = MicroLesson.build(
        item: rhyme,
        locale: 'fr',
        chosenIndex: 1,
        skillId: 'pa.rhyme',
      );
      expect(lesson.cta, 'Réessaie');
      expect(lesson.coachLine.toLowerCase(), isNot(contains('almost')));
      expect(lesson.coachLine.toLowerCase(), isNot(contains('try again')));
      final blob = '${lesson.title} ${lesson.coachLine}'.toLowerCase();
      expect(blob, anyOf(contains('cat'), contains('dog'), contains('hat')));
    });

    test('counting in French names the number', () {
      final lesson = MicroLesson.build(
        item: count,
        locale: 'fr',
        chosenIndex: 1,
        misconception: Misconception.offByOne,
      );
      expect(lesson.cta, 'Réessaie');
      expect(lesson.coachLine, contains('3'));
      expect(lesson.coachLine.toLowerCase(), anyOf(contains('touch'), contains('compte'), contains('dit')));
    });
  });

  group('TutorBrain speaks the micro-lesson locally', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TutorBrain.instance.clearCache();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (call) async => ['none'],
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        null,
      );
    });

    test('microLesson moment names the item and skips the network', () async {
      final result = await TutorBrain.instance.lineFor(
        TutorContext(
          moment: TutorMoment.microLesson,
          locale: 'en',
          skillId: 'pa.rhyme',
          item: rhyme,
          chosenIndex: 1,
        ),
      );
      expect(result.source, 'local');
      expect(result.feedback.text.toLowerCase(), contains('cat'));
      expect(result.feedback.parentBridgeId, 'have_a_look');
      for (final ban in bannedPrimaryFeedback) {
        if (ban == 'bravo!') continue;
        expect(result.feedback.text.toLowerCase().trim(), isNot(equals(ban)));
      }
    });
  });
}
