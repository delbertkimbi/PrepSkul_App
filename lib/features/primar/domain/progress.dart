/// What to show a child and a parent about how it is going.
///
/// ## All of this was already in the evidence log
///
/// Every number here — days in a row, skills cleared, minutes spent, how today
/// went — is derived from attempts that were already being recorded. Nothing
/// new is stored. The progress screen was missing, not the data.
///
/// That is worth saying because the obvious way to build a streak counter is to
/// add a `streak` field and increment it, which then has to be kept correct
/// across time zones, clock changes, reinstalls and a child who plays at
/// midnight. Deriving it from timestamps that already exist cannot drift.
///
/// ## What a streak is for, and what it must not become
///
/// A streak is a reason to come back tomorrow, which for a child who has
/// nobody making them practise is worth a great deal. It is also the mechanic
/// most easily turned into a punishment: a child who misses a day because
/// their mother needed the phone should not be told they have lost something.
///
/// So the streak here counts up and never scolds. [ProgressSummary.broken]
/// exists so the UI can say "let us start a new one" rather than "you lost
/// your streak", and nothing in the learning engine reads it at all — a
/// child's placement must never depend on how often they show up.
library;

import 'learner.dart';
import 'skill.dart';
import 'subjects.dart';

class ProgressSummary {
  const ProgressSummary({
    required this.streakDays,
    required this.broken,
    required this.playedToday,
    required this.answeredToday,
    required this.correctToday,
    required this.skillsCleared,
    required this.skillsTotal,
    required this.minutesToday,
    required this.secondsToday,
  });

  /// Consecutive days ending today or yesterday.
  final int streakDays;

  /// True when a run of two or more days ended before yesterday. Only ever used
  /// to soften the wording.
  final bool broken;

  final bool playedToday;
  final int answeredToday;
  final int correctToday;

  /// Skills at probable or better, out of the ones the app can teach.
  final int skillsCleared;
  final int skillsTotal;

  final int minutesToday;

  /// Time today, in a unit that is honest at the size it actually is.
  ///
  /// A five-question session is about twenty seconds of thinking, which rounds
  /// to "0 minutes" — true, and useless. Under a minute it reports seconds.
  final int secondsToday;

  String get timeToday =>
      minutesToday >= 1 ? '${minutesToday}m' : '${secondsToday}s';

  /// How today went, 0–1. Null before anything has been answered today, because
  /// a ring at zero reads as failure rather than as "not started".
  double? get accuracyToday =>
      answeredToday == 0 ? null : correctToday / answeredToday;
}

/// Calendar day, ignoring the time.
DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

ProgressSummary summariseProgress(List<Evidence> log, Learner learner,
    {DateTime? now, Subject subject = Subject.reading}) {
  final today = _day(now ?? DateTime.now());

  final days = log.map((e) => _day(e.at)).toSet().toList()..sort();
  final todays = log.where((e) => _day(e.at) == today).toList();

  // Counted backwards from today, and from yesterday if today has not started.
  //
  // Anchoring only on today would show a zero streak every morning until the
  // child opened the app, which is exactly when the number is meant to be
  // encouraging them to.
  var streak = 0;
  var broken = false;
  if (days.isNotEmpty) {
    final last = days.last;
    final gap = today.difference(last).inDays;
    if (gap <= 1) {
      var cursor = last;
      streak = 1;
      for (var i = days.length - 2; i >= 0; i--) {
        if (cursor.difference(days[i]).inDays == 1) {
          streak++;
          cursor = days[i];
        } else {
          break;
        }
      }
    } else {
      // A run that ended more than a day ago. Worth knowing so the wording can
      // invite rather than mourn.
      broken = days.length > 1;
    }
  }

  // This subject's skills only. One log holds every subject a child has
  // touched, so counting all of them would tell a child who finished reading
  // that they had nearly finished numeracy too.
  final mySkills = teachableSkillsFor(subject);
  final cleared = mySkills.where((s) => learner.isCleared(s.id)).length;

  // Time spent is summed from the thinking time already on each attempt rather
  // than from a wall clock, so a phone left on the counter does not become an
  // hour of learning.
  final ms = todays.fold<int>(0, (sum, e) => sum + e.elapsedMs);

  return ProgressSummary(
    streakDays: streak,
    broken: broken,
    playedToday: todays.isNotEmpty,
    answeredToday: todays.length,
    correctToday: todays.where((e) => e.correct).length,
    skillsCleared: cleared,
    skillsTotal: mySkills.length,
    minutesToday: ms ~/ 60000,
    secondsToday: (ms / 1000).round(),
  );
}

/// One line for the child, at the top of the screen.
///
/// Never a score, and never a comparison. A child who answered three questions
/// badly has still shown up, and showing up is the thing this screen exists to
/// reward.
String progressGreeting(ProgressSummary p, String name) {
  final who = name.trim().isEmpty ? 'You' : name.trim();
  if (!p.playedToday) {
    return p.streakDays > 0
        ? '$who, ready to keep it going?'
        : '$who, ready to start?';
  }
  if (p.streakDays >= 2) return '$who, ${p.streakDays} days in a row!';
  return 'Nice work today, $who!';
}

/// The streak line, worded so a missed day is an invitation.
String streakLine(ProgressSummary p) {
  if (p.streakDays >= 2) return '${p.streakDays} days in a row';
  if (p.streakDays == 1) return 'Day one';
  if (p.broken) return 'Let us start a new run';
  return 'Play today to start a run';
}
