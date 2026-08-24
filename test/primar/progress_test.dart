import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/learner.dart';
import 'package:prepskul/features/primar/domain/progress.dart';

/// A streak is the mechanic most easily turned into a punishment. These hold it
/// to counting up and never scolding — and hold the numbers to being derived
/// rather than stored, because a stored counter drifts and a derived one cannot.
void main() {
  final today = DateTime(2026, 8, 15, 18);

  Evidence on(int daysAgo, {bool correct = true, int ms = 3000}) => Evidence(
        skillId: 'letter.shape',
        correct: correct,
        elapsedMs: ms,
        at: today.subtract(Duration(days: daysAgo)),
      );

  ProgressSummary summarise(List<Evidence> log) =>
      summariseProgress(log, learnerFrom(log), now: today);

  group('the streak counts days, not sessions', () {
    test('twenty answers in one sitting is one day', () {
      final p = summarise([for (var i = 0; i < 20; i++) on(0)]);
      expect(p.streakDays, 1);
      expect(p.answeredToday, 20);
    });

    test('consecutive days add up', () {
      expect(summarise([on(0), on(1), on(2), on(3)]).streakDays, 4);
    });

    test('a gap ends the run', () {
      // Played today, and before that only a week ago.
      expect(summarise([on(0), on(7), on(8)]).streakDays, 1);
    });

    test('yesterday still counts before today has started', () {
      // Anchoring only on today would show zero every morning until the child
      // opened the app — exactly when the number is meant to be pulling them
      // back.
      final p = summarise([on(1), on(2), on(3)]);
      expect(p.streakDays, 3);
      expect(p.playedToday, isFalse);
    });

    test('a run that ended days ago is not a streak', () {
      final p = summarise([on(5), on(6), on(7)]);
      expect(p.streakDays, 0);
      expect(p.broken, isTrue);
    });
  });

  group('nothing here scolds', () {
    const harsh = ['lost', 'failed', 'broke', 'missed', 'gone', 'wrong', 'behind'];

    test('a broken run reads as an invitation', () {
      final p = summarise([on(5), on(6)]);
      final line = streakLine(p);
      expect(line, 'Let us start a new run');
      for (final w in harsh) {
        expect(line.toLowerCase(), isNot(contains(w)), reason: line);
      }
    });

    test('a bad day is still a good greeting', () {
      // Three answers, all wrong. The child still showed up, and showing up is
      // what this screen exists to reward.
      final p = summarise([on(0, correct: false), on(0, correct: false), on(0, correct: false)]);
      final greeting = progressGreeting(p, 'Ayuk');
      for (final w in harsh) {
        expect(greeting.toLowerCase(), isNot(contains(w)), reason: greeting);
      }
      expect(greeting, contains('Ayuk'));
    });

    test('every wording path stays kind', () {
      final cases = <List<Evidence>>[
        [],
        [on(0)],
        [on(1)],
        [on(0), on(1), on(2)],
        [on(6), on(7)],
        [on(0, correct: false)],
      ];
      for (final log in cases) {
        final p = summarise(log);
        for (final text in [progressGreeting(p, 'Bih'), streakLine(p)]) {
          for (final w in harsh) {
            expect(text.toLowerCase(), isNot(contains(w)), reason: text);
          }
        }
      }
    });
  });

  group('today, honestly', () {
    test('accuracy is null before anything is answered', () {
      // A ring at zero reads as failure rather than as "not started".
      expect(summarise([on(2)]).accuracyToday, isNull);
    });

    test('accuracy counts only today', () {
      final p = summarise([
        on(1, correct: false),
        on(1, correct: false),
        on(0, correct: true),
        on(0, correct: false),
      ]);
      expect(p.answeredToday, 2);
      expect(p.accuracyToday, 0.5);
    });

    test('time comes from thinking time, not a wall clock', () {
      // A phone left face-up on the counter must not become an hour of
      // learning.
      final p = summarise([for (var i = 0; i < 20; i++) on(0, ms: 6000)]);
      expect(p.minutesToday, 2);
    });
  });

  group('skills cleared is a real position, not a percentage of nothing', () {
    test('a new learner has cleared none', () {
      final p = summarise([]);
      expect(p.skillsCleared, 0);
      expect(p.skillsTotal, greaterThan(0));
    });

    test('clearing a skill moves the count', () {
      final log = [
        for (var i = 0; i < 8; i++)
          Evidence(
              skillId: 'letter.shape',
              correct: true,
              elapsedMs: 2000,
              at: today.subtract(Duration(minutes: i))),
      ];
      expect(summariseProgress(log, learnerFrom(log), now: today).skillsCleared,
          greaterThan(0));
    });
  });
}
