import 'dart:math';

import 'figure.dart';
import 'items.dart';
import 'subjects.dart';

/// Adaptive placement.
///
/// A 2-up/1-down staircase: two correct answers in a row move the child up a
/// level, a single wrong answer moves them down. This targets roughly 70%
/// accuracy, which matters for two reasons — it converges on the level a child
/// can *reliably* work at rather than the level they fail at, and it means most
/// of what a child sees, they get right. A child who already associates school
/// with failure should not meet a wall on their first session.
///
/// The converged level is read from reversals (the points where direction
/// changes), which is standard practice and far more stable than reading the
/// final level alone.

const int startLevel = 3;
const int sessionLength = 14;

/// Reversals to discard before averaging — the early ones are just approach.
const int _warmupReversals = 1;

/// Before the first reversal the staircase moves in big steps, so it reaches the
/// right neighbourhood in a few items instead of walking there all session.
/// After the first reversal it switches to fine steps for precision.
///
/// The steps are not symmetrical. Climbing always costs two correct answers in
/// a row; falling costs one wrong answer, and accelerates while the staircase
/// is still searching. That asymmetry is deliberate — being a rung too low
/// costs a child an easy question, being several rungs too high costs them the
/// session.
const int _approachStep = 2;
const int _refineStep = 1;

class Attempt {
  const Attempt({
    required this.itemId,
    required this.level,
    required this.correct,
    required this.elapsedMs,
  });

  final String itemId;
  final int level;
  final bool correct;
  final int elapsedMs;
}

enum StaircaseDirection { up, down }

class SessionState {
  const SessionState({
    required this.seed,
    required this.subject,
    required this.locale,
    required this.attempts,
    required this.length,
    required this.currentLevel,
    required this.consecutiveCorrect,
    required this.reversals,
    required this.lastDirection,
    required this.finished,
  });

  final int seed;

  /// How many items this session runs for. Shorter once a child has a history,
  /// because the staircase starts near the answer instead of hunting for it.
  final int length;

  /// What is being measured. Decides which generator supplies the next item and
  /// which curriculum topic the mastery row lands on.
  final Subject subject;

  /// Which language this session is being taught in. Reading items are built
  /// from a different alphabet and a different word list per language, so the
  /// session has to carry it — the generator cannot guess.
  final String locale;

  final List<Attempt> attempts;
  final int currentLevel;
  final int consecutiveCorrect;

  /// Levels at which the staircase changed direction.
  final List<int> reversals;
  final StaircaseDirection? lastDirection;
  final bool finished;
}

/// Sessions after the first are shorter.
///
/// A warm-started staircase is already near the child's level, so it needs
/// fewer steps to settle. Spending fourteen items to re-derive something we
/// already know is fatigue with no information in it, and fatigue is how a
/// child stops coming back.
const int returningSessionLength = 10;

/// Where a returning child should begin.
///
/// Deliberately one rung *below* the last placement. Opening on the exact
/// converged level means a coin-flip first question; opening a step under it
/// means the session starts with something they can do, and climbs from there
/// within two or three items. For a child who associates school with failing,
/// the first question is the one that decides whether there is a second
/// session.
int warmStartFrom(double? lastLevel) {
  if (lastLevel == null) return startLevel;
  return clampLevel(lastLevel - 1);
}

SessionState startSession({
  Subject subject = Subject.shapes,
  String locale = 'en',
  int? seed,
  int? beginAt,
  int? length,
}) =>
    SessionState(
      seed: seed ?? DateTime.now().millisecondsSinceEpoch,
      subject: subject,
      locale: locale,
      attempts: const [],
      length: length ?? sessionLength,
      currentLevel: beginAt ?? startLevel,
      consecutiveCorrect: 0,
      reversals: const [],
      lastDirection: null,
      finished: false,
    );

PrimarItem nextItem(SessionState state) {
  final rng = Random(state.seed + state.attempts.length * 7919);
  return generateForSubject(
      state.subject, state.currentLevel, rng, state.attempts.length, state.locale);
}

/// How many misses in a row the session is currently on, including this one.
int _trailingMisses(List<Attempt> attempts) {
  var n = 0;
  for (var i = attempts.length - 1; i >= 0 && !attempts[i].correct; i--) {
    n++;
  }
  return n;
}

SessionState recordAttempt(SessionState state, Attempt attempt) {
  final attempts = [...state.attempts, attempt];

  var level = state.currentLevel;
  var consecutiveCorrect = state.consecutiveCorrect;
  var direction = state.lastDirection;
  final reversals = [...state.reversals];

  final approaching = reversals.isEmpty;
  final step = approaching ? _approachStep : _refineStep;

  // Two in a row to climb, at every phase.
  //
  // The approach used to climb on a single correct answer, which made a lucky
  // guess indistinguishable from knowing something. At high levels a child has
  // a one-in-four chance of tapping the right tile, so a level-1 child placed
  // at 10 would fall 10, 8, then guess one right and bounce straight back to
  // 10 — traced runs did exactly that and never recovered inside the session.
  //
  // Requiring two consecutive correct answers costs a genuinely able child
  // about three extra questions on the way up. It costs a child who was
  // started far too high nothing at all, and saves them a whole session.
  const correctNeeded = 2;

  if (attempt.correct) {
    consecutiveCorrect += 1;
    if (consecutiveCorrect >= correctNeeded) {
      consecutiveCorrect = 0;
      final next = clampLevel(level + step);
      if (next != level) {
        if (direction == StaircaseDirection.down) reversals.add(level);
        direction = StaircaseDirection.up;
        level = next;
      }
    }
  } else {
    consecutiveCorrect = 0;

    // Falling accelerates while it is still searching.
    //
    // A fixed two-rung drop is fine when the start was roughly right. It is not
    // fine when it was badly wrong: a child placed at 10 who belongs at 1 needs
    // five straight failures to reach the floor, and a fourteen-question
    // session cannot recover from that — measured, it settled them near 4.
    // Every one of those questions is one they cannot do.
    //
    // So each consecutive miss during the approach widens the next drop. It
    // only applies before the first reversal, so a converged staircase still
    // moves one rung at a time and the psychophysics are untouched. Nothing
    // symmetrical is done on the way up on purpose: overshooting downward
    // costs a child one easy question, overshooting upward costs them the
    // belief that they can do this.
    final missStreak = _trailingMisses(attempts);
    final fall = approaching ? step * missStreak.clamp(1, 3) : step;

    final next = clampLevel(level - fall);
    if (next != level) {
      if (direction == StaircaseDirection.up) reversals.add(level);
      direction = StaircaseDirection.down;
      level = next;
    }
  }

  return SessionState(
    seed: state.seed,
    subject: state.subject,
    locale: state.locale,
    length: state.length,
    attempts: attempts,
    currentLevel: level,
    consecutiveCorrect: consecutiveCorrect,
    reversals: reversals,
    lastDirection: direction,
    finished: attempts.length >= state.length,
  );
}

class Placement {
  const Placement({
    required this.level,
    required this.masteryScore,
    required this.accuracy,
    required this.correct,
    required this.total,
    required this.medianMs,
    required this.provisional,
  });

  /// Converged working level, 1–10.
  final double level;

  /// Normalised 0–1, written straight into skulmate_concept_mastery.
  final double masteryScore;
  final double accuracy;
  final int correct;
  final int total;
  final int medianMs;

  /// True when the staircase never settled — placement is a guess, say so.
  final bool provisional;
}

Placement computePlacement(SessionState state) {
  final total = state.attempts.length;
  final correct = state.attempts.where((a) => a.correct).length;
  final accuracy = total > 0 ? correct / total : 0.0;

  final usable = state.reversals.length > _warmupReversals
      ? state.reversals.sublist(_warmupReversals)
      : <int>[];

  double level;
  var provisional = false;

  if (usable.length >= 2) {
    level = usable.reduce((a, b) => a + b) / usable.length;
  } else if (state.attempts.isNotEmpty) {
    // Never settled.
    //
    // The fallback used to average every level the child was shown, which
    // quietly counts the search itself as evidence: a child who started at 10
    // and fell 10, 8, 6, 4, 2, 1, 1, 1 was scored near 4, when every level
    // above 1 had *already been established as too hard*. The descent is the
    // path, not the destination.
    //
    // A single reversal is not enough to average, but it is still the best
    // thing in the session — it is the one point where the staircase actually
    // changed its mind. Failing that, the last few questions are where it had
    // got to when it ran out. Either way this stays provisional, because
    // running out of questions means nothing was confirmed.
    if (state.reversals.isNotEmpty) {
      level = state.reversals.last.toDouble();
    } else {
      const tail = 3;
      final recent = state.attempts.length > tail
          ? state.attempts.sublist(state.attempts.length - tail)
          : state.attempts;
      level = recent.map((a) => a.level).reduce((a, b) => a + b) / recent.length;
    }
    provisional = true;
  } else {
    level = startLevel.toDouble();
    provisional = true;
  }

  final times = state.attempts.map((a) => a.elapsedMs).toList()..sort();
  final medianMs = times.isNotEmpty ? times[times.length ~/ 2] : 0;

  return Placement(
    level: (level * 10).round() / 10,
    masteryScore: (level / 10).clamp(0.0, 1.0),
    accuracy: accuracy,
    correct: correct,
    total: total,
    medianMs: medianMs,
    provisional: provisional,
  );
}

/// Shaped for the existing `skulmate_concept_mastery` row so a session writes
/// into the schema that is already there rather than inventing a parallel one.
class MasteryUpsert {
  const MasteryUpsert({
    required this.topicId,
    required this.masteryScore,
    required this.attempts,
    required this.correctTotal,
    required this.questionTotal,
    required this.weakStreak,
    required this.lastSessionAccuracy,
  });

  final String topicId;
  final double masteryScore;
  final int attempts;
  final int correctTotal;
  final int questionTotal;
  final int weakStreak;
  final double lastSessionAccuracy;

  Map<String, dynamic> toJson() => {
        'topic_id': topicId,
        'mastery_score': double.parse(masteryScore.toStringAsFixed(4)),
        'attempts': attempts,
        'correct_total': correctTotal,
        'question_total': questionTotal,
        'weak_streak': weakStreak,
        'last_session_accuracy': double.parse(lastSessionAccuracy.toStringAsFixed(4)),
      };
}

const double weakThreshold = 0.4;

MasteryUpsert toMasteryUpsert(
  Placement placement,
  String topicId, {
  MasteryUpsert? previous,
}) {
  final weak = placement.masteryScore < weakThreshold;
  return MasteryUpsert(
    topicId: topicId,
    masteryScore: placement.masteryScore,
    attempts: (previous?.attempts ?? 0) + 1,
    correctTotal: (previous?.correctTotal ?? 0) + placement.correct,
    questionTotal: (previous?.questionTotal ?? 0) + placement.total,
    weakStreak: weak ? (previous?.weakStreak ?? 0) + 1 : 0,
    lastSessionAccuracy: placement.accuracy,
  );
}

/// The topic this item type reports against, matching curriculum_nodes.topic_id.
const String primarTopicId = 'foundational.visual-reasoning.shape-composition';
