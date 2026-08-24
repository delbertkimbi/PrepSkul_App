import 'package:flutter_test/flutter_test.dart';

import 'package:prepskul/features/primar/domain/home_copy.dart';
import 'package:prepskul/features/primar/domain/learner.dart';
import 'package:prepskul/features/primar/domain/policy.dart';
import 'package:prepskul/features/primar/domain/skill.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';
import 'package:prepskul/features/primar/domain/tutor_advice.dart';

void main() {
  test('practice advice lists every subject with a graph', () {
    final learner = Learner(locale: 'en', skills: const {});
    final advice = practiceAdviceFor(learner);
    expect(advice.length, 3);
    expect(advice.map((a) => a.subject).toList(), subjectOrder);
    expect(advice.every((a) => a.skillLabel.isNotEmpty), isTrue);
    expect(advice.every((a) => a.headline == 'UP NEXT'), isTrue);
  });

  test('Ask tab copy matches homeMateBody, never Decision.explain', () {
    final learner = Learner(locale: 'en', skills: const {});
    final advice = practiceAdviceFor(learner);
    for (final a in advice) {
      expect(isSessionIntroCopy(a.explain), isFalse, reason: a.explain);
      // Parent-facing engine lines must not leak onto Ask.
      expect(a.explain.toLowerCase(), isNot(contains('coming back to')));
      expect(a.explain.toLowerCase(), isNot(contains('keeps going')));
      expect(a.explain.toLowerCase(), isNot(contains('working on')));
      if (!a.exhausted) {
        final expected = homeMateBody(
          locale: 'en',
          skillLabel: a.skillLabel,
          reason: a.reason,
        );
        expect(a.explain, expected);
      }
    }
  });

  test('tips are locale-specific and honest', () {
    expect(tutorTips('en').length, 4);
    expect(tutorTips('fr').length, 4);
    expect(tutorTips('en').last, contains('PrepSkul'));
    expect(tutorTips('fr').last, contains('PrepSkul'));
  });

  test('next skill per subject powers profile advice', () {
    final learner = Learner(locale: 'en', skills: const {});
    for (final subject in subjectOrder) {
      if (teachableSkillsFor(subject).isEmpty) continue;
      final decision = nextSkill(learner, subject: subject);
      expect(decision.skillId, isNotNull,
          reason: '${subject.name} should have a first skill');
      expect(sessionHeadline(decision.reason), isNotEmpty);
    }
  });
}
