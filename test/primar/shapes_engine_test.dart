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

/// Shapes on the learning engine — the third subject off the staircase.
void main() {
  group('the graph', () {
    test('shapes has a walkable path', () {
      final order = pathOrder(subject: Subject.shapes);
      expect(order, hasLength(6));
      for (final s in order) {
        expect(s.subject, Subject.shapes);
        expect(canGenerateSkill(s.id), isTrue);
      }
    });

    test('compose comes before decompose', () {
      final order = pathOrder(subject: Subject.shapes).map((s) => s.id).toList();
      expect(order.indexOf('shape.compose.basic'),
          lessThan(order.indexOf('shape.decompose')));
      expect(order.indexOf('shape.decompose'), lessThan(order.indexOf('shape.flex')));
    });
  });

  group('the engine keeps subjects apart', () {
    test('a shapes decision is always a shape skill', () {
      final rng = Random(12);
      for (var trial = 0; trial < 200; trial++) {
        final log = <Evidence>[];
        for (var i = 0; i < rng.nextInt(30); i++) {
          log.add(Evidence(
            skillId: shapesSkills[rng.nextInt(shapesSkills.length)].id,
            correct: rng.nextInt(10) > 2,
            elapsedMs: 3000,
            at: DateTime.now().subtract(Duration(minutes: 30 - i)),
            misconception: Misconception.unclear,
          ));
        }
        final learner = learnerFrom(log);
        final decision = nextSkill(learner, subject: Subject.shapes);
        if (decision.skillId != null) {
          expect(skillsById[decision.skillId]!.subject, Subject.shapes);
        }
      }
    });
  });

  group('the questions', () {
    test('every shape skill produces shape figures', () {
      for (final skill in shapesSkills) {
        for (var i = 0; i < 30; i++) {
          final item = generateItemForSkill(skill.id, Random(i * 19), index: i);
          expect(item.prompt.any((f) => f is ShapeFigure), isTrue);
          expect(item.options.every((f) => f is ShapeFigure), isTrue);
        }
      }
    });

    test('path agrees with the engine for shapes', () {
      final rng = Random(55);
      for (var trial = 0; trial < 150; trial++) {
        final log = <Evidence>[];
        for (var i = 0; i < rng.nextInt(20); i++) {
          log.add(Evidence(
            skillId: shapesSkills[rng.nextInt(shapesSkills.length)].id,
            correct: rng.nextInt(10) > 3,
            elapsedMs: 3000,
            at: DateTime.now().subtract(Duration(minutes: 20 - i)),
            misconception: Misconception.unclear,
          ));
        }
        final learner = learnerFrom(log);
        final steps = pathFor(learner, subject: Subject.shapes);
        final decision = nextSkill(learner, subject: Subject.shapes);
        final current = steps.where((s) => s.state == PathState.current).toList();
        if (decision.skillId == null) {
          expect(current, isEmpty);
          continue;
        }
        expect(current.length, 1);
        expect(current.single.skill.id, decision.skillId);
      }
    });
  });
}
