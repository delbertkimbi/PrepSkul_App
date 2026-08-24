/// What we believe about one child, skill by skill.
///
/// ## Why a number was not enough
///
/// The stored model until now was a single float per subject. It could say a
/// child was "at 6.2". It could not say they had been confusing b and d for
/// three sessions, or that they answered correctly but took nine seconds every
/// time, or that they had only ever seen /b/ in the word *ball*.
///
/// Every one of those changes what a teacher does next, and none of them
/// survives being averaged into one number.
///
/// ## Mastery is a decision, not a threshold
///
/// "8 out of 10" is not mastery. It is a number that a child can reach by
/// guessing well on a four-option question, or by having seen the same item
/// eleven times, or on a good day.
///
/// What we actually want to know is whether the child can do this
/// *independently*, *now*, and *somewhere it was not taught*. So the estimate
/// weighs recent evidence over old, refuses to promote a skill that has never
/// been tested outside its teaching context, and treats needing the answer
/// shown as a real cost even when the retry succeeds.
///
/// Erring toward "not yet" is deliberate. Calling mastery too early moves a
/// child on with a hole under them, and the hole shows up three skills later
/// where nobody thinks to look for it.
library;

import 'misconception.dart';
import 'skill.dart';
import 'subjects.dart';

/// One answered item, as evidence rather than as a score.
class Evidence {
  const Evidence({
    required this.skillId,
    required this.correct,
    required this.elapsedMs,
    required this.at,
    this.neededTeaching = false,
    this.misconception = Misconception.unclear,
    this.isTransfer = false,
  });

  final String skillId;
  final bool correct;
  final int elapsedMs;
  final DateTime at;

  /// True when the child got there only after being shown and re-asked.
  ///
  /// The retry is unscored for placement — a child should not be punished twice
  /// for one gap — but it is not free evidence either. Reaching the answer with
  /// help is a different thing from reaching it alone, and a skill held up
  /// entirely by help is not mastered.
  final bool neededTeaching;

  /// What went wrong, when it is recognisable.
  final Misconception misconception;

  /// True when this item came from a context the skill was not taught in.
  ///
  /// This is the flag that stops eleven correct answers to the same question
  /// counting as knowing something.
  final bool isTransfer;
}

/// Where a skill stands.
enum MasteryState {
  /// Never attempted.
  notStarted,

  /// Being worked on. Everything that is not one of the others.
  learning,

  /// Recent evidence is strong, but it has never been tested away from where
  /// it was taught. Good enough to move on from; not good enough to stop
  /// revisiting.
  probable,

  /// Strong recent evidence, unaided, and it survived a change of context.
  mastered,
}

/// The estimate for one skill, and the evidence behind it.
class SkillState {
  const SkillState({
    required this.skillId,
    required this.state,
    required this.attempts,
    required this.accuracy,
    required this.recentAccuracy,
    required this.medianMs,
    required this.helpRate,
    required this.transferTested,
    required this.dominantMisconception,
    this.lastSeen,
    this.dueAt,
  });

  final String skillId;
  final MasteryState state;
  final int attempts;

  /// All of it, and only the recent part. They separate a child who was lost
  /// and has since got it from a child who had it and is losing it — opposite
  /// situations that share an average.
  final double accuracy;
  final double recentAccuracy;

  final int medianMs;

  /// How often reaching the answer needed the answer shown first.
  final double helpRate;

  /// Whether this has ever been answered in a context it was not taught in.
  final bool transferTested;

  /// The mistake that keeps coming back, if there is one. This is what an
  /// intervention is chosen against.
  final Misconception dominantMisconception;

  final DateTime? lastSeen;

  /// When this should come back for a retrieval check. Null while it is still
  /// being learned — spacing is for things that have been got, not for things
  /// still being got.
  final DateTime? dueAt;

  bool get isDue => dueAt != null && !DateTime.now().isBefore(dueAt!);
}

/// Everything known about one child.
class Learner {
  const Learner({required this.skills, this.locale = 'en'});

  final Map<String, SkillState> skills;
  final String locale;

  SkillState stateOf(String skillId) =>
      skills[skillId] ??
      SkillState(
        skillId: skillId,
        state: MasteryState.notStarted,
        attempts: 0,
        accuracy: 0,
        recentAccuracy: 0,
        medianMs: 0,
        helpRate: 0,
        transferTested: false,
        dominantMisconception: Misconception.unclear,
      );

  /// Whether [skillId] is far enough along to stop blocking what sits on it.
  ///
  /// A prerequisite the app cannot present never blocks.
  ///
  /// This is not a shortcut, it is the only defensible rule: we cannot gate on
  /// a skill we cannot measure. Hearing the beats in a word is a genuine
  /// prerequisite for hearing the sound a word starts with, and this app has no
  /// way to ask a child to clap syllables. Treating that as unmet would leave
  /// every child stuck on letter shapes forever, with the rest of reading
  /// sealed behind a door with no handle — which is exactly what happened the
  /// first time this graph was wired up.
  ///
  /// So an unteachable prerequisite stays in the graph as a statement of what
  /// this app does not cover, and is stepped over rather than waited on.
  bool isCleared(String skillId) {
    final skill = skillsById[skillId];
    if (skill != null && !skill.teachable) return true;

    final s = stateOf(skillId).state;
    return s == MasteryState.mastered || s == MasteryState.probable;
  }

  /// Skills whose groundwork is done and which are not finished.
  ///
  /// This is where a child actually is — a set, not a rung. Two children on the
  /// same frontier can have arrived from different directions and need
  /// different things next, which is the whole reason for the graph.
  /// Everything this subject can teach right now.
  ///
  /// Subject-scoped, because one evidence log holds every subject a child has
  /// touched. Without the filter a numeracy session's frontier would include
  /// letter sounds, and the engine would cheerfully hand a child a phonics
  /// question in the middle of counting.
  List<Skill> frontier({Subject subject = Subject.reading}) {
    return teachableSkillsFor(subject).where((s) {
      if (stateOf(s.id).state == MasteryState.mastered) return false;
      return s.prerequisites.every(isCleared);
    }).toList();
  }
}

/// How many recent items "recent" means.
///
/// Small on purpose. A child who has turned a corner should be believed within
/// a session, not after twenty more items — and a child who is losing something
/// should be caught in the same window.
const int recentWindow = 6;

/// The fewest attempts before mastery is even considered.
///
/// Below this the accuracy figure is mostly noise: three out of three on a
/// four-option question happens by luck roughly once in every sixty children.
const int minAttemptsForMastery = 6;

/// Recomputes a skill's state from its evidence, newest last.
SkillState estimate(String skillId, List<Evidence> history) {
  if (history.isEmpty) return const Learner(skills: {}).stateOf(skillId);

  final mine = history.where((e) => e.skillId == skillId).toList();
  if (mine.isEmpty) return const Learner(skills: {}).stateOf(skillId);

  final recent =
      mine.length > recentWindow ? mine.sublist(mine.length - recentWindow) : mine;

  final accuracy = mine.where((e) => e.correct).length / mine.length;
  final recentAccuracy = recent.where((e) => e.correct).length / recent.length;
  final helpRate = mine.where((e) => e.neededTeaching).length / mine.length;

  final times = mine.map((e) => e.elapsedMs).toList()..sort();
  final medianMs = times[times.length ~/ 2];

  // Transfer only counts when it was *correct*. Meeting a skill in a new
  // context and failing is information, but it is not evidence of transfer.
  final transferTested = mine.any((e) => e.isTransfer && e.correct);

  final counts = <Misconception, int>{};
  for (final e in mine) {
    if (e.misconception == Misconception.unclear) continue;
    counts[e.misconception] = (counts[e.misconception] ?? 0) + 1;
  }
  var dominant = Misconception.unclear;
  var best = 0;
  counts.forEach((m, n) {
    // Three is where a pattern starts, matching MisconceptionTracker: one
    // mistake is noise, the same mistake three times is something to teach
    // against.
    if (n >= 3 && n > best) {
      dominant = m;
      best = n;
    }
  });
  final state = _decide(
    attempts: mine.length,
    recentAccuracy: recentAccuracy,
    helpRate: helpRate,
    transferTested: transferTested,
    recent: recent,
  );

  return SkillState(
    skillId: skillId,
    state: state,
    attempts: mine.length,
    accuracy: accuracy,
    recentAccuracy: recentAccuracy,
    medianMs: medianMs,
    helpRate: helpRate,
    transferTested: transferTested,
    dominantMisconception: dominant,
    lastSeen: mine.last.at,
    dueAt: state == MasteryState.mastered ? _nextReview(mine) : null,
  );
}

MasteryState _decide({
  required int attempts,
  required double recentAccuracy,
  required double helpRate,
  required bool transferTested,
  required List<Evidence> recent,
}) {
  if (attempts == 0) return MasteryState.notStarted;
  if (attempts < minAttemptsForMastery) return MasteryState.learning;

  // Still leaning on being shown the answer. A skill propped up by help is not
  // a skill the child has, however good the recent numbers look.
  if (helpRate > 0.34) return MasteryState.learning;

  // The last few have to be clean. This is the "independently, now" half.
  final lastThree = recent.length >= 3 ? recent.sublist(recent.length - 3) : recent;
  final cleanRun = lastThree.every((e) => e.correct && !e.neededTeaching);

  if (recentAccuracy >= 0.85 && cleanRun) {
    // Never tested away from where it was taught. Strong, but not finished —
    // and the honest label for that is not "mastered".
    return transferTested ? MasteryState.mastered : MasteryState.probable;
  }
  if (recentAccuracy >= 0.7) return MasteryState.probable;
  return MasteryState.learning;
}

/// Expanding intervals for retrieval practice.
///
/// The gaps widen because that is the point: recalling something after a week
/// is worth far more than recalling it after a minute, and a schedule that
/// never widens is just repetition.
const List<Duration> reviewSchedule = [
  Duration(days: 1),
  Duration(days: 3),
  Duration(days: 7),
  Duration(days: 21),
];

DateTime _nextReview(List<Evidence> mine) {
  // How many separate days this skill has been seen on, which is a better
  // proxy for how well it has bedded in than a raw attempt count — twenty
  // items in one sitting is one exposure, not twenty.
  final days = mine
      .map((e) => DateTime(e.at.year, e.at.month, e.at.day))
      .toSet()
      .length;
  final step = reviewSchedule[(days - 1).clamp(0, reviewSchedule.length - 1)];
  return mine.last.at.add(step);
}

/// Rebuilds the whole learner from an evidence log.
///
/// Deliberately a pure fold rather than incremental updates. The log is the
/// truth; the model is a view of it. That means a change to how mastery is
/// judged applies to every child's history at once, instead of leaving old
/// learners frozen under the old rule.
Learner learnerFrom(List<Evidence> log, {String locale = 'en'}) {
  final byId = <String, List<Evidence>>{};
  for (final e in log) {
    byId.putIfAbsent(e.skillId, () => []).add(e);
  }
  return Learner(
    locale: locale,
    skills: {
      for (final entry in byId.entries) entry.key: estimate(entry.key, entry.value),
    },
  );
}
