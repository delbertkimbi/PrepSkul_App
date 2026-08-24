import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/mastery.dart';
import 'package:prepskul/features/primar/domain/screener.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';

/// The one thing this must never do is decide what a child is allowed to see
/// because of how old they are. Age and grade have already stopped predicting
/// ability for the children this exists for — that is the whole premise — so a
/// screener that leans on age has reproduced the failure it is meant to catch.
void main() {
  group('age is the weakest signal, and provably so', () {
    test('what a parent has seen moves the start further than age does', () {
      const middle = ScreenerAnswers(schooling: Schooling.patchy);

      final youngest = Screener.estimate(middle.copyWith(age: 5)).level;
      final oldest = Screener.estimate(middle.copyWith(age: 11)).level;
      final ageSwing = oldest - youngest;

      final cannot = Screener.estimate(middle.copyWith(seenDoing: SeenDoing.notYet)).level;
      final can = Screener.estimate(middle.copyWith(seenDoing: SeenDoing.confident)).level;
      final seenSwing = can - cannot;

      expect(seenSwing, greaterThan(ageSwing),
          reason: 'age (swing $ageSwing) is pulling harder than direct '
              'observation (swing $seenSwing) — that is backwards');
    });

    test('a nine year old who cannot count starts near the bottom', () {
      // The child this product exists for. If being nine drags them upward,
      // they get four questions they cannot answer in the first two minutes.
      final e = Screener.estimate(const ScreenerAnswers(
        age: 9,
        schooling: Schooling.none,
        seenDoing: SeenDoing.notYet,
      ));
      expect(e.level, lessThanOrEqualTo(2),
          reason: 'started a nine-year-old who cannot count at level ${e.level}');
    });

    test('a six year old who reads words is not held down by being six', () {
      final e = Screener.estimate(const ScreenerAnswers(
        age: 6,
        schooling: Schooling.daily,
        seenDoing: SeenDoing.confident,
      ));
      expect(e.level, greaterThanOrEqualTo(5),
          reason: 'a six-year-old reading words was started at ${e.level}');
    });

    test('two children the same age can start five rungs apart', () {
      final low = Screener.estimate(const ScreenerAnswers(
        age: 8,
        schooling: Schooling.none,
        seenDoing: SeenDoing.notYet,
      ));
      final high = Screener.estimate(const ScreenerAnswers(
        age: 8,
        schooling: Schooling.daily,
        seenDoing: SeenDoing.confident,
      ));
      expect(high.level - low.level, greaterThanOrEqualTo(5),
          reason: 'age is flattening two very different children together');
    });
  });

  group('the estimate stays inside the real world', () {
    test('every combination of answers lands on a level that exists', () {
      for (final age in [null, ...Screener.ages, 3, 15]) {
        for (final school in [null, ...Schooling.values]) {
          for (final seen in [null, ...SeenDoing.values]) {
            final e = Screener.estimate(
              ScreenerAnswers(age: age, schooling: school, seenDoing: seen),
            );
            expect(e.level, inInclusiveRange(1, 10),
                reason: 'age=$age school=$school seen=$seen → ${e.level}');
            for (final l in e.probeLevels) {
              expect(l, inInclusiveRange(1, 10));
            }
            expect(e.probeLevels, isNotEmpty);
            final sorted = [...e.probeLevels]..sort();
            expect(e.probeLevels, sorted, reason: 'probe levels out of order');
            expect(e.probeLevels.toSet().length, e.probeLevels.length,
                reason: 'the same level asked twice');
          }
        }
      }
    });

    test('knowing less makes the probe look further', () {
      final blind = Screener.estimate(const ScreenerAnswers());
      final informed = Screener.estimate(const ScreenerAnswers(
        age: 7,
        schooling: Schooling.daily,
        seenDoing: SeenDoing.someOfIt,
      ));
      expect(blind.spread, greaterThan(informed.spread));
    });

    test('an unanswered questionnaire still produces a usable start', () {
      final e = Screener.estimate(const ScreenerAnswers());
      expect(e.level, inInclusiveRange(1, 10));
      expect(e.probeLevels.length, greaterThanOrEqualTo(2));
    });
  });

  group('the probe overrules the questionnaire', () {
    test('a child who answers everything starts at the hardest one they got', () {
      const e = Estimate(level: 3, spread: 2, basis: '');
      final start = Screener.startFromProbe(const [
        ProbeResult(level: 1, correct: true),
        ProbeResult(level: 3, correct: true),
        ProbeResult(level: 5, correct: true),
      ], e);
      expect(start, 5);
    });

    test('a child who answers nothing drops below the easiest thing shown', () {
      const e = Estimate(level: 6, spread: 2, basis: '');
      final start = Screener.startFromProbe(const [
        ProbeResult(level: 4, correct: false),
        ProbeResult(level: 6, correct: false),
        ProbeResult(level: 8, correct: false),
      ], e);
      expect(start, 3);
      expect(start, lessThan(e.level),
          reason: 'the parent said six and the child answered nothing — '
              'the child has to win that argument');
    });

    test('never drops below the floor, because there is nothing below it', () {
      const e = Estimate(level: 1, spread: 2, basis: '');
      final start = Screener.startFromProbe(const [
        ProbeResult(level: 1, correct: false),
      ], e);
      expect(start, 1);
    });

    test('a high questionnaire and a low child yields a low start', () {
      const e = Estimate(level: 8, spread: 2, basis: '');
      final start = Screener.startFromProbe(const [
        ProbeResult(level: 6, correct: true),
        ProbeResult(level: 8, correct: false),
        ProbeResult(level: 10, correct: false),
      ], e);
      expect(start, 6);
    });

    test('with no probe at all the estimate is used unchanged', () {
      const e = Estimate(level: 5, spread: 2, basis: '');
      expect(Screener.startFromProbe(const [], e), 5);
    });
  });

  group('what the parent reads', () {
    const deficit = [
      'behind', 'below', 'slow', 'weak', 'poor', 'fail', 'cannot read',
      'struggl', 'should', 'grade', 'class', 'year group',
    ];

    test('the basis describes where we start, not what the child is', () {
      for (final a in [
        const ScreenerAnswers(name: 'Ayuk'),
        const ScreenerAnswers(
            name: 'Ayuk', age: 9, schooling: Schooling.none, seenDoing: SeenDoing.notYet),
        const ScreenerAnswers(
            name: 'Ayuk', age: 6, schooling: Schooling.daily, seenDoing: SeenDoing.confident),
      ]) {
        final text = Screener.estimate(a).basis.toLowerCase();
        for (final word in deficit) {
          expect(text, isNot(contains(word)), reason: 'reads as a verdict: "$text"');
        }
      }
    });

    test('answering nothing is described as a starting point, not a failure', () {
      final text = Screener.probeSummary(const [
        ProbeResult(level: 1, correct: false),
        ProbeResult(level: 3, correct: false),
      ], 'Bih');
      expect(text, contains('Bih'));
      for (final word in deficit) {
        expect(text.toLowerCase(), isNot(contains(word)), reason: 'reads as a verdict: "$text"');
      }
    });

    test('the summary always names the child', () {
      for (final got in [0, 1, 3]) {
        final results = [
          for (var i = 0; i < 3; i++) ProbeResult(level: i * 2 + 1, correct: i < got),
        ];
        expect(Screener.probeSummary(results, 'Ndip'), contains('Ndip'));
      }
    });
  });

  group('a wrong start is a start, never a cage', () {
    /// Plays a whole session as a simulated child of a known true level.
    ///
    /// Returns the reported placement and the levels of the last third of the
    /// session — the second of those matters more than the first. A number in
    /// a parent's summary being two rungs out is a cosmetic problem. A child
    /// still being asked questions four rungs above them on the twelfth
    /// question is the thing that makes them stop coming back.
    ({double reported, double endedNear}) play(int start, int trueLevel, int seed) {
      var state = startSession(subject: Subject.numeracy, seed: seed, beginAt: start);
      final rng = Random(seed + 11);
      while (!state.finished) {
        final item = nextItem(state);
        final know = 1 / (1 + exp((item.level - trueLevel) * 1.6));
        // A match board has no options, so there is nothing to guess from —
        // and 1/0 would make the simulated child answer everything correctly.
        // Joining three pairs by luck is close to impossible.
        final guess = item.options.isEmpty ? 0.02 : 1 / item.options.length;
        final p = know + (1 - know) * guess;
        state = recordAttempt(
          state,
          Attempt(
            itemId: item.id,
            level: item.level,
            correct: rng.nextDouble() < p,
            elapsedMs: 2000,
          ),
        );
      }
      final tail = state.attempts.sublist(state.attempts.length ~/ 3 * 2);
      return (
        reported: computePlacement(state).level,
        endedNear: tail.map((a) => a.level).reduce((a, b) => a + b) / tail.length,
      );
    }

    test('an ordinary wrong start is corrected inside one session', () {
      // The everyday case: the parent's answers pointed a few rungs off.
      for (final (start, trueLevel) in [(1, 8), (6, 2), (3, 9), (8, 3)]) {
        var sum = 0.0;
        const runs = 30;
        for (var r = 0; r < runs; r++) {
          sum += play(start, trueLevel, r * 91 + start).reported;
        }
        final estimate = sum / runs;
        expect((estimate - trueLevel).abs(), lessThan(2.0),
            reason: 'started at $start for a level-$trueLevel child and settled '
                'at ${estimate.toStringAsFixed(1)} — the start trapped them');
      }
    });

    test('even the worst possible start stops costing the child questions', () {
      // The extreme: a child who belongs at the very bottom, placed at the very
      // top by three lucky taps in the warm-up. Nine rungs is more than a
      // fourteen-question session can fully undo — options carry a 25% guessing
      // floor, so some of the descent is spent distinguishing luck from
      // knowledge, and the reported number stays loose. That is honest, and it
      // is why such a placement is reported as provisional.
      //
      // What must not happen is the child spending the whole session drowning.
      // By the last third they have to be somewhere they can work.
      var endedNear = 0.0;
      var reported = 0.0;
      const runs = 40;
      for (var r = 0; r < runs; r++) {
        final run = play(10, 1, r * 91 + 7);
        endedNear += run.endedNear;
        reported += run.reported;
      }
      endedNear /= runs;
      reported /= runs;

      expect(endedNear, lessThan(3.0),
          reason: 'a level-1 child started at 10 was still being asked '
              '${endedNear.toStringAsFixed(1)}-level questions at the end');
      expect(reported, lessThan(4.0),
          reason: 'reported ${reported.toStringAsFixed(1)} for a level-1 child');
    });
  });

  group('the questions read as things a parent has watched happen', () {
    test('nothing on the last page is left in English', () {
      // This is the page that decides where a child starts, and it was the one
      // page in the flow that never got translated: a parent who picked
      // Français answered five French questions and then met this in English.
      // An untranslated option is not a cosmetic gap — it is the parent
      // guessing on the answer that carries the most weight.
      for (final subject in Subject.values) {
        for (final seen in SeenDoing.values) {
          final en = seen.prompt(subject, 'en');
          final fr = seen.prompt(subject, 'fr');
          expect(fr, isNotEmpty);
          expect(fr, isNot(en),
              reason: '$subject/$seen is the same string in both languages');
        }
        final french = SeenDoing.values.map((s) => s.prompt(subject, 'fr'));
        expect(french.toSet().length, SeenDoing.values.length,
            reason: '$subject repeats a French option');
      }
    });

    test('every subject phrases every option in its own terms', () {
      for (final subject in Subject.values) {
        final prompts = SeenDoing.values.map((s) => s.prompt(subject)).toList();
        expect(prompts.toSet().length, SeenDoing.values.length,
            reason: '$subject repeats an option');
        for (final p in prompts) {
          expect(p, isNotEmpty);
          // A parent should be answering about what they saw, not rating their
          // child against anything.
          expect(p.toLowerCase(), isNot(contains('level')));
          expect(p.toLowerCase(), isNot(contains('good at')));
        }
      }
    });
  });
}
