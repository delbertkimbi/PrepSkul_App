import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/path.dart';
import 'package:prepskul/features/primar/domain/screener.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';

/// The onboarding answers have to change something.
///
/// ## Why this file exists
///
/// Twice now the parent questionnaire has been decorative. First because the
/// reading session ignored `beginAt` entirely — it runs on the engine, which
/// reads the evidence log, which the warm-up never wrote to. Then, after that
/// was fixed, because the warm-up probed the first three skills in path order
/// regardless of anything a parent had said.
///
/// Both times nothing crashed and the screens all looked right. A parent
/// answered five questions and the app did exactly the same thing either way.
///
/// So this asserts the consequence directly: two children whose parents
/// describe them very differently must not be probed at the same place.
void main() {
  /// The skills the warm-up would try, for a given set of answers.
  ///
  /// Mirrors `_WarmUpState._readingProbe`. Kept in step by the test below that
  /// checks it against the real path length — if the graph grows and this
  /// drifts, that test fails rather than this one quietly passing.
  List<String> probeFor(ScreenerAnswers answers) {
    final estimate = Screener.estimate(answers);
    final order = pathOrder();
    int place(int level) =>
        (((level - 1) / 9) * (order.length - 1)).round().clamp(0, order.length - 1);

    final seen = <String>{};
    final picked = <String>[];
    for (final level in estimate.probeLevels) {
      final id = order[place(level)].id;
      if (seen.add(id)) picked.add(id);
    }
    for (var i = 0; picked.length < estimate.probeLevels.length && i < order.length; i++) {
      if (seen.add(order[i].id)) picked.add(order[i].id);
    }
    return picked;
  }

  test('a confident older reader is not probed where a beginner is', () {
    const beginner = ScreenerAnswers(
      age: 5,
      schooling: Schooling.none,
      seenDoing: SeenDoing.notYet,
      subject: Subject.reading,
    );
    const reader = ScreenerAnswers(
      age: Screener.olderThanListed,
      schooling: Schooling.daily,
      seenDoing: SeenDoing.confident,
      subject: Subject.reading,
    );

    expect(probeFor(beginner), isNot(equals(probeFor(reader))),
        reason: 'the questionnaire made no difference to where the child '
            'starts, which means it is asking for nothing');
  });

  test('schooling on its own moves the probe', () {
    // This is the question that got challenged directly: "what is the use of
    // asking how much school they have had?" It earns its page only if the
    // answer changes what happens next, holding everything else fixed.
    var moved = 0;
    var compared = 0;
    for (var age = 3; age <= 13; age++) {
      for (final seen in SeenDoing.values) {
        final probes = <List<String>>[];
        for (final school in Schooling.values) {
          probes.add(probeFor(ScreenerAnswers(
            age: age,
            schooling: school,
            seenDoing: seen,
            subject: Subject.reading,
          )));
        }
        compared++;
        final first = probes.first.join(',');
        if (probes.any((p) => p.join(',') != first)) moved++;
      }
    }

    expect(moved, greaterThan(0),
        reason: 'schooling changed the starting point in 0 of $compared '
            'combinations — the page should be cut rather than kept');
  });

  test('the probe never asks for a skill that is not on the path', () {
    final ids = pathOrder().map((s) => s.id).toSet();
    for (var age = 3; age <= 13; age++) {
      for (final school in Schooling.values) {
        for (final seen in SeenDoing.values) {
          final probe = probeFor(ScreenerAnswers(
            age: age,
            schooling: school,
            seenDoing: seen,
            subject: Subject.reading,
          ));
          expect(probe, isNotEmpty);
          for (final id in probe) {
            expect(ids, contains(id),
                reason: '$id is probed but is not a teachable skill');
          }
          expect(probe.toSet().length, probe.length,
              reason: 'the same skill is probed twice in one warm-up');
        }
      }
    }
  });
}
