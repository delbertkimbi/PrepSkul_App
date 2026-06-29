import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/services/concept_mastery_service.dart';
import 'package:prepskul/features/skulmate/utils/sm2_lite.dart';

void main() {
  group('Path A — mastery & spaced repetition', () {
    test('resolveTopicIds uses curriculum alignment when present', () {
      final ids = ConceptMasteryService.resolveTopicIds({
        'curriculumAlignment': {
          'frameworkId': 'cm_gce_ol',
          'matchedTopicIds': ['gce_ol_chem_electrolysis'],
        },
      });
      expect(ids, ['gce_ol_chem_electrolysis']);
    });

    test('resolveTopicIds falls back to open topic slug', () {
      final ids = ConceptMasteryService.resolveTopicIds({
        'topic': 'Machine Learning Basics',
      });
      expect(ids.single, 'open:machine-learning-basics');
    });

    test('resolveTopicIds defaults to open:general', () {
      expect(
        ConceptMasteryService.resolveTopicIds(null),
        ['open:general'],
      );
      expect(
        ConceptMasteryService.resolveTopicIds({}),
        ['open:general'],
      );
    });

    test('resolveFrameworkId reads alignment or defaults', () {
      expect(
        ConceptMasteryService.resolveFrameworkId({
          'curriculumAlignment': {'frameworkId': 'cm_gce_ol'},
        }),
        'cm_gce_ol',
      );
      expect(
        ConceptMasteryService.resolveFrameworkId(null),
        'open_learning',
      );
    });

    test('SM-2 schedules longer interval after successful recall', () {
      final first = computeSm2Update(null, 4);
      expect(first.intervalDays, 1);
      expect(first.repetitions, 1);

      final second = computeSm2Update(
        ReviewState(
          easeFactor: first.easeFactor,
          intervalDays: first.intervalDays,
          repetitions: first.repetitions,
        ),
        4,
      );
      expect(second.intervalDays, greaterThanOrEqualTo(3));
      expect(second.repetitions, 2);
    });

    test('SM-2 resets interval after failed recall', () {
      final established = computeSm2Update(
        ReviewState(
          easeFactor: 2.5,
          intervalDays: 6,
          repetitions: 3,
        ),
        1,
      );
      expect(established.repetitions, 0);
      expect(established.intervalDays, 0);
    });
  });
}
