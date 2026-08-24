import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/learner.dart';
import 'package:prepskul/features/primar/domain/literacy.dart';
import 'package:prepskul/features/primar/domain/misconception.dart';
import 'package:prepskul/features/primar/domain/policy.dart';
import 'package:prepskul/features/primar/services/learner_traits.dart';
import 'package:prepskul/features/primar/services/tutor_brain.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

  final rhymeItem = PrimarItem(
    id: 'R6-0-rhyme',
    level: 6,
    topicId: literacyTopicIdEn,
    prompt: const [PictureFigure('cat')],
    options: const [
      PictureFigure('hat'),
      PictureFigure('dog'),
    ],
    answerIndex: 0,
    spoken: 'word:cat',
  );

  test('falls back to local TutorFeedback when offline', () async {
    final result = await TutorBrain.instance.lineFor(
      TutorContext(
        moment: TutorMoment.correct,
        locale: 'en',
        skillId: 'pa.rhyme',
        item: rhymeItem,
        streak: 2,
      ),
    );
    expect(result.source, 'local');
    expect(result.feedback.text.toLowerCase(), contains('hat'));
  });

  test('home_next moment never returns session-intro phrasing', () async {
    final result = await TutorBrain.instance.lineFor(
      const TutorContext(
        moment: TutorMoment.homeNext,
        locale: 'en',
        childName: 'Kofi',
        skillId: 'pa.rhyme',
        reason: Reason.advance,
      ),
    );
    expect(result.source, 'local');
    expect(result.feedback.text.toLowerCase(), isNot(contains('four short')));
    expect(result.feedback.text.toLowerCase(), contains('start'));
  });

  test('miss moment names chosen and answer locally', () async {
    final result = await TutorBrain.instance.lineFor(
      TutorContext(
        moment: TutorMoment.miss,
        locale: 'en',
        skillId: 'pa.rhyme',
        item: rhymeItem,
        chosenIndex: 1,
        misconception: Misconception.unclear,
      ),
    );
    expect(result.source, 'local');
    expect(result.feedback.text.toLowerCase(), contains('dog'));
  });

  test('cached AI line is reused offline', () async {
    await TutorBrain.instance.clearCache();
    const ctx = TutorContext(
      moment: TutorMoment.homeNext,
      locale: 'en',
      childName: 'Kofi',
      skillId: 'pa.rhyme',
      reason: Reason.advance,
    );
    final fp = ctx.cacheFingerprint();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'primar_tutor_lines_v1',
      '{"$fp":"Next up: rhyming. Tap Start when you are ready."}',
    );

    final result = await TutorBrain.instance.lineFor(ctx);
    expect(result.source, 'cache');
    expect(result.feedback.text, contains('rhyming'));
  });

  test('learner traits persist struggling skills', () async {
    await LearnerTraitsStore.instance.clear();
    final now = DateTime.now();
    await LearnerTraitsStore.instance.recomputeFrom(
      [
        Evidence(
          skillId: 'pa.rhyme',
          correct: false,
          elapsedMs: 4000,
          at: now,
          misconception: Misconception.unclear,
        ),
        Evidence(
          skillId: 'pa.rhyme',
          correct: false,
          elapsedMs: 3500,
          at: now.add(const Duration(minutes: 1)),
          misconception: Misconception.unclear,
        ),
      ],
      locale: 'en',
    );
    final loaded = await LearnerTraitsStore.instance.load();
    expect(loaded.strugglingSkillIds, contains('pa.rhyme'));
  });

  test('offline miss names recurring misconception from traits', () async {
    final result = await TutorBrain.instance.lineFor(
      TutorContext(
        moment: TutorMoment.miss,
        locale: 'en',
        skillId: 'letter.sound',
        item: PrimarItem(
          id: 'R4-bd',
          level: 4,
          topicId: literacyTopicIdEn,
          prompt: const [SoundFigure('sound:bbb')],
          options: const [
            LetterFigure('b'),
            LetterFigure('d'),
            LetterFigure('p'),
            LetterFigure('q'),
          ],
          answerIndex: 0,
          spoken: 'sound:bbb',
        ),
        chosenIndex: 1,
        misconception: Misconception.letterReversal,
        traits: const LearnerTraits(
          strugglingSkillIds: ['letter.sound'],
          recentMissTags: ['letterReversal'],
        ),
      ),
    );
    expect(result.source, 'local');
    final lower = result.feedback.text.toLowerCase();
    expect(lower, anyOf(contains('mirror'), contains('faces'), contains('d')));
    expect(lower, contains('b'));
  });

  test('offline speak corrective names heard then target', () async {
    final result = await TutorBrain.instance.lineFor(
      const TutorContext(
        moment: TutorMoment.speak,
        locale: 'en',
        speakTarget: 'cat',
        speakMatched: false,
        heard: 'dog',
      ),
    );
    expect(result.source, 'local');
    final lower = result.feedback.text.toLowerCase();
    expect(lower, contains('dog'));
    expect(lower, contains('cat'));
    expect(lower, isNot(contains('wrong')));
  });
}
