import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/learner.dart';
import 'package:prepskul/features/primar/domain/literacy.dart';
import 'package:prepskul/features/primar/domain/misconception.dart';
import 'package:prepskul/features/primar/domain/path.dart';
import 'package:prepskul/features/primar/domain/policy.dart';
import 'package:prepskul/features/primar/domain/skill.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';

/// Numeracy on the learning engine.
///
/// ## What this closes
///
/// The product's claim is a system that knows *you are here, you need this
/// next*. That held for reading and for nothing else: the skill graph, the
/// mastery estimate, the spaced review and the misconception repairs were all
/// reading-only, and numeracy ran on the level ladder it started with — a
/// number that went up when a child was right and down when they were wrong.
///
/// ## The hazard this introduces
///
/// One evidence log holds every subject a child has touched. So the risk is
/// not that numeracy fails to work; it is that the two graphs leak into each
/// other — a letter sound surfacing as a due review halfway through counting,
/// or a child being told they have cleared most of numeracy because they
/// cleared most of reading. Most of what follows is about that.
void main() {
  Learner learnerWith(List<String> skillIds, {bool correct = true}) {
    final now = DateTime.now();
    return learnerFrom([
      for (var i = 0; i < skillIds.length; i++)
        for (var n = 0; n < 8; n++)
          Evidence(
            skillId: skillIds[i],
            correct: correct,
            elapsedMs: 3000,
            at: now.subtract(Duration(minutes: skillIds.length * 8 - i * 8 - n)),
            misconception: Misconception.unclear,
            isTransfer: n > 5,
          ),
    ]);
  }

  group('the graph', () {
    test('numeracy has a walkable path', () {
      final order = pathOrder(subject: Subject.numeracy);
      expect(order, isNotEmpty);
      for (final s in order) {
        expect(s.subject, Subject.numeracy);
        expect(canGenerateSkill(s.id), isTrue,
            reason: '${s.id} is on the path with no generator behind it');
      }
    });

    test('counting comes before arithmetic', () {
      final order = pathOrder(subject: Subject.numeracy).map((s) => s.id).toList();
      expect(order.indexOf('num.count'), lessThan(order.indexOf('num.add')));
      expect(order.indexOf('num.add'), lessThan(order.indexOf('num.subtract')));
      expect(order.indexOf('num.subtract'), lessThan(order.indexOf('num.missing')));
    });

    test('the two subjects share no skill ids', () {
      final reading = readingSkills.map((s) => s.id).toSet();
      final numeracy = numeracySkills.map((s) => s.id).toSet();
      expect(reading.intersection(numeracy), isEmpty,
          reason: 'one id in two graphs would make the shared lookup wrong');
    });

    test('a numeracy path never contains a reading skill, or the reverse', () {
      expect(
        pathOrder(subject: Subject.numeracy).every((s) => s.subject == Subject.numeracy),
        isTrue,
      );
      expect(
        pathOrder(subject: Subject.reading).every((s) => s.subject == Subject.reading),
        isTrue,
      );
    });
  });

  group('the engine keeps the subjects apart', () {
    test('a numeracy decision is always a numeracy skill', () {
      final rng = Random(4);
      final everySkill = [
        ...readingSkills.where((s) => s.teachable).map((s) => s.id),
        ...numeracySkills.map((s) => s.id),
      ];

      for (var trial = 0; trial < 300; trial++) {
        final log = <Evidence>[];
        for (var i = 0; i < rng.nextInt(40); i++) {
          log.add(Evidence(
            skillId: everySkill[rng.nextInt(everySkill.length)],
            correct: rng.nextInt(10) > 2,
            elapsedMs: 3000,
            at: DateTime.now().subtract(Duration(minutes: 40 - i)),
            misconception: Misconception.unclear,
          ));
        }
        final learner = learnerFrom(log);

        final maths = nextSkill(learner, subject: Subject.numeracy);
        if (maths.skillId != null) {
          expect(skillsById[maths.skillId]!.subject, Subject.numeracy,
              reason: 'a numeracy session was handed ${maths.skillId}');
        }

        final reading = nextSkill(learner, subject: Subject.reading);
        if (reading.skillId != null) {
          expect(skillsById[reading.skillId]!.subject, Subject.reading,
              reason: 'a reading session was handed ${reading.skillId}');
        }
      }
    });

    test('clearing reading does not clear numeracy', () {
      // The failure this guards: one log, one `teachableSkills` default, and a
      // child who had finished reading being shown numeracy as already done.
      final learner = learnerWith(
        readingSkills.where((s) => s.teachable).map((s) => s.id).toList(),
      );

      final mathsPath = pathFor(learner, subject: Subject.numeracy);
      final cleared = mathsPath.where((s) => s.state == PathState.done).length;
      expect(cleared, 0,
          reason: '$cleared numeracy skills counted as done on reading '
              'evidence alone');

      expect(nextSkill(learner, subject: Subject.numeracy).skillId, isNotNull,
          reason: 'numeracy reported nothing left to teach');
    });

    test('a due reading review does not interrupt a numeracy session', () {
      final learner = learnerWith(['letter.shape', 'letter.shape.reversal']);
      final decision = nextSkill(learner, subject: Subject.numeracy);
      if (decision.skillId != null) {
        expect(skillsById[decision.skillId]!.subject, Subject.numeracy);
      }
    });
  });

  group('the questions', () {
    test('every numeracy skill produces a well formed item', () {
      for (final skill in numeracySkills) {
        for (var i = 0; i < 40; i++) {
          final item = generateItemForSkill(skill.id, Random(i * 17), index: i);
          final hasSomething = item.prompt.any((f) => f is! SymbolFigure) ||
              item.orderItems.isNotEmpty ||
              item.matchLeft.isNotEmpty ||
              item.options.isNotEmpty;
          expect(hasSomething, isTrue,
              reason: '${skill.id} produced a question with nothing in it');

          if (item.interaction == Interaction.choose) {
            expect(item.options, isNotEmpty);
            expect(item.answerIndex,
                inInclusiveRange(0, item.options.length - 1));
          }
        }
      }
    });

    test('a skill always asks its own kind of question', () {
      // The point of putting numeracy on a graph. The old ladder mixed forms
      // at every level, so a child's performance on "which pile is bigger" and
      // on "what is 3 and 2" landed on one number and neither was measurable.
      for (final skill in numeracySkills) {
        final kinds = <String>{};
        for (var i = 0; i < 40; i++) {
          final item = generateItemForSkill(skill.id, Random(i * 23), index: i);
          // The generator stamps the form into the id.
          kinds.add(item.id.split('-').last);
        }
        expect(kinds.length, 1,
            reason: '${skill.id} produced $kinds — one skill must be one kind '
                'of question or the evidence means nothing');
      }
    });

    test('the path agrees with the engine for numeracy too', () {
      final rng = Random(88);
      final ids = numeracySkills.map((s) => s.id).toList();

      for (var trial = 0; trial < 200; trial++) {
        final log = <Evidence>[];
        for (var i = 0; i < rng.nextInt(30); i++) {
          log.add(Evidence(
            skillId: ids[rng.nextInt(ids.length)],
            correct: rng.nextInt(10) > 3,
            elapsedMs: 3000,
            at: DateTime.now().subtract(Duration(minutes: 30 - i)),
            misconception: Misconception.unclear,
          ));
        }
        final learner = learnerFrom(log);
        final steps = pathFor(learner, subject: Subject.numeracy);
        final decision = nextSkill(learner, subject: Subject.numeracy);
        final current = steps.where((s) => s.state == PathState.current).toList();

        if (decision.skillId == null) {
          expect(current, isEmpty);
          continue;
        }
        expect(current.length, 1);
        expect(current.single.skill.id, decision.skillId,
            reason: 'home would say "${current.single.skill.label}" and the '
                'session would teach ${decision.skillId}');
      }
    });
  });
}
