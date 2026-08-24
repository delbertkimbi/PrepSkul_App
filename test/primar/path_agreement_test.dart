import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/learner.dart';
import 'package:prepskul/features/primar/domain/misconception.dart';
import 'package:prepskul/features/primar/domain/path.dart';
import 'package:prepskul/features/primar/domain/policy.dart';
import 'package:prepskul/features/primar/domain/skill.dart';

/// The home screen and the session must name the same next skill.
///
/// ## The bug this exists to prevent
///
/// `pathFor` used to work out "what is next" itself — first skill in graph
/// order that was not yet cleared. It reads as obviously correct. Fuzzed over
/// random learner states it disagreed with the engine **350 times out of 400**:
/// home announced "UP NEXT: hears the sound a word starts with" and the session
/// then taught telling letters apart.
///
/// That is the worst kind of defect in a product for children. It is on the
/// first screen, it is about the one thing the screen exists to say, and
/// nothing crashes — so it survives every test that checks the app *works*.
///
/// The fix was structural: the states here describe the graph, and `current` is
/// taken from [nextSkill]. This test is what stops a future edit from
/// reintroducing a second opinion.
void main() {
  /// Random histories, including incoherent ones.
  ///
  /// Deliberately not "realistic" logs. A learner model is a fold over whatever
  /// actually happened, and what actually happens includes a child answering
  /// four questions and handing the phone back — the ragged states are the ones
  /// where two implementations drift apart.
  List<Evidence> randomLog(Random rng) {
    final ids = teachableSkills.map((s) => s.id).toList();
    final n = rng.nextInt(45);
    return [
      for (var i = 0; i < n; i++)
        Evidence(
          skillId: ids[rng.nextInt(ids.length)],
          correct: rng.nextInt(10) > 2,
          elapsedMs: 2000 + rng.nextInt(6000),
          at: DateTime.now().subtract(Duration(minutes: n - i)),
          neededTeaching: rng.nextInt(6) == 0,
          misconception: Misconception.unclear,
          isTransfer: rng.nextInt(5) == 0,
        ),
    ];
  }

  test('the step marked current is the skill the engine will teach', () {
    final rng = Random(20260817);

    for (var trial = 0; trial < 500; trial++) {
      final learner = learnerFrom(randomLog(rng));
      final steps = pathFor(learner);
      final decision = nextSkill(learner);

      final current =
          steps.where((s) => s.state == PathState.current).toList();

      if (decision.skillId == null) {
        // Nothing left to teach. Nothing may claim to be next either.
        expect(current, isEmpty,
            reason: 'trial $trial: the path names a next skill but the engine '
                'has none');
        continue;
      }

      expect(current.length, 1,
          reason: 'trial $trial: expected exactly one current step, '
              'got ${current.length}');
      expect(current.single.skill.id, decision.skillId,
          reason: 'trial $trial: home would say "${current.single.skill.label}" '
              'and the session would teach ${decision.skillId}');
    }
  });

  test('locked means prerequisites unmet, and nothing else', () {
    final rng = Random(99);

    for (var trial = 0; trial < 200; trial++) {
      final learner = learnerFrom(randomLog(rng));

      for (final step in pathFor(learner)) {
        if (step.state != PathState.locked) continue;

        // A padlock is a promise that this cannot be attempted. It used to be
        // drawn on any unstarted skill that simply was not next, which told a
        // child a wall was there when the engine would have set the work.
        final reachable = step.skill.prerequisites.every((p) {
          final pre = skillsById[p];
          if (pre != null && !pre.teachable) return true;
          return learner.isCleared(p);
        });

        expect(reachable, isFalse,
            reason: 'trial $trial: ${step.skill.id} is drawn locked but every '
                'prerequisite is cleared');
      }
    }
  });

  test('every teachable skill appears exactly once', () {
    final steps = pathFor(learnerFrom(const []));
    final ids = steps.map((s) => s.skill.id).toList();

    expect(ids.toSet().length, ids.length, reason: 'a skill is on the path twice');
    expect(ids.toSet(), teachableSkills.map((s) => s.id).toSet(),
        reason: 'the path and the teachable graph have drifted apart');
  });
}
