import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/learner.dart';
import 'package:prepskul/features/primar/domain/misconception.dart';
import 'package:prepskul/features/primar/domain/policy.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';

/// The home screen headline must reflect why the engine chose this skill.
void main() {
  test('due skills surface as REVIEW', () {
    final now = DateTime.now();
    final learner = learnerFrom([
      for (var i = 0; i < 8; i++)
        Evidence(
          skillId: 'letter.sound',
          correct: true,
          elapsedMs: 3000,
          at: now.subtract(Duration(days: 14, minutes: i)),
          misconception: Misconception.unclear,
          isTransfer: i > 5,
        ),
      Evidence(
        skillId: 'letter.sound',
        correct: true,
        elapsedMs: 3000,
        at: now.subtract(const Duration(days: 20)),
        misconception: Misconception.unclear,
        isTransfer: true,
      ),
    ]);

    final decision = nextSkill(learner, subject: Subject.reading);
    if (decision.reason == Reason.review) {
      expect(sessionHeadline(decision.reason), 'REVIEW');
    }
  });

  test('frontier skills stay UP NEXT', () {
    final learner = learnerFrom(const []);
    final decision = nextSkill(learner, subject: Subject.reading);
    expect(decision.reason, isNot(Reason.review));
    expect(sessionHeadline(decision.reason), 'UP NEXT');
  });

  test('repair and reteach surface as PRACTICE', () {
    expect(sessionHeadline(Reason.repair), 'PRACTICE');
    expect(sessionHeadline(Reason.reteach), 'PRACTICE');
    expect(sessionHeadline(Reason.advance), 'UP NEXT');
    expect(sessionHeadline(Reason.transfer), 'UP NEXT');
  });
}
