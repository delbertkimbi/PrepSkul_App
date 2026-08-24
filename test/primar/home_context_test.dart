import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/home_copy.dart';
import 'package:prepskul/features/primar/domain/policy.dart';
import 'package:prepskul/features/primar/services/primar_voice.dart';
import 'package:prepskul/features/primar/services/tutor_brain.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home and profile must never use onboarding or session-walk-through phrasing.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('home copy is action-oriented', () {
    test('home voice lines name the skill and Start', () {
      for (final reason in Reason.values) {
        if (reason == Reason.nothingLeft) continue;
        final en = homeNextVoiceLine(
          locale: 'en',
          childName: 'Ayuk',
          skillLabel: 'Rhyming',
          reason: reason,
        );
        final fr = homeNextVoiceLine(
          locale: 'fr',
          childName: 'Ayuk',
          skillLabel: 'Rimes',
          reason: reason,
        );
        expect(isSessionIntroCopy(en), isFalse, reason: en);
        expect(isSessionIntroCopy(fr), isFalse, reason: fr);
        expect(en.toLowerCase(), contains('start'));
        expect(fr.toLowerCase(), contains('démarrer'));
      }
    });

    test('home sublines never use session-intro fragments', () {
      final sub = homeStartSubline(
        locale: 'en',
        skillLabel: 'Letter sounds',
        reason: Reason.advance,
      );
      expect(isSessionIntroCopy(sub), isFalse);
      expect(sub, contains('Letter sounds'));
    });

    test('home mate body rejects engine parent explain text', () {
      const parentExplain =
          'Coming back to Letter sounds to check it has stuck.';
      expect(isSessionIntroCopy(parentExplain), isFalse);
      final body = homeMateBody(
        locale: 'en',
        skillLabel: 'Letter sounds',
        reason: Reason.review,
      );
      expect(isSessionIntroCopy(body), isFalse);
      expect(body, contains('Letter sounds'));
    });
  });

  group('catalogue lines stay off home', () {
    test('onboarding voice lines are session-intro flagged', () {
      expect(isSessionIntroCopy(VoiceLines.welcomeParent.text), isTrue);
      expect(isSessionIntroCopy(VoiceLines.warmUpChild.text), isTrue);
      expect(isSessionIntroCopy(VoiceLines.handoffParent.text), isTrue);
      expect(isSessionIntroCopy(VoiceLines.voiceSample.text), isFalse);
    });

    test('home_next local line is never onboarding copy', () async {
      TutorBrain.instance.markAiUnavailable('force_local');
      final result = await TutorBrain.instance.lineFor(
        const TutorContext(
          moment: TutorMoment.homeNext,
          locale: 'en',
          childName: 'Ayuk',
          skillId: 'pa.rhyme',
          reason: Reason.advance,
        ),
      );
      expect(result.source, 'local');
      expect(isSessionIntroCopy(result.feedback.text), isFalse);
      expect(result.feedback.text.toLowerCase(), contains('rhym'));
    });
  });

  group('surfaces stay on their own copy', () {
    test('home and profile share homeMateBody family', () {
      for (final reason in Reason.values) {
        final body = homeMateBody(
          locale: 'en',
          skillLabel: 'Rhyming',
          reason: reason,
        );
        expect(isSessionIntroCopy(body), isFalse, reason: body);
        expect(body.toLowerCase(), isNot(contains('four short')));
        expect(body.toLowerCase(), isNot(contains('hand the phone')));
        expect(body.toLowerCase(), isNot(contains('coming back to')));
      }
    });
  });
}
