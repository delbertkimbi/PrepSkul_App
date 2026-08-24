/// The skill graph, flattened into something a child can look at.
///
/// ## Why this file exists
///
/// The graph has been the truth about what comes next since it was written,
/// and the only thing that ever read it was the policy — one skill at a time,
/// invisibly. A child using the app could not see where they were, what they
/// had finished, or what was coming. There was no map, so there was nothing to
/// want.
///
/// That is most of what "it feels boring" means. The questions were never the
/// problem; a session with no visible position in anything is just a quiz.
///
/// ## Why an order has to be chosen here
///
/// A graph has no single order — several skills are reachable at once. Drawing
/// it as a graph would be honest and useless: a child needs a line to walk.
/// So this does a topological sort with a stable tie-break by strand, which
/// gives the same line every time from the same graph, and puts hearing sounds
/// before letters before words, which is the order the evidence supports.
library;

import 'learner.dart';
import 'policy.dart';
import 'skill.dart';
import 'subjects.dart';

/// Where a child stands on one step of the path.
///
/// Named `PathState` rather than the more obvious `StepState` because Flutter's
/// Stepper exports that name, and a collision in a file that imports material
/// is resolved by prefixing every use — which reads far worse than picking a
/// different word once.
enum PathState {
  /// Prerequisites not met. Visible, so there is something to walk towards,
  /// but not startable.
  locked,

  /// What the engine will actually teach next. Exactly one step, always.
  ///
  /// Taken from [nextSkill] rather than worked out here — see the note on
  /// [pathFor]. Guessing it independently made the home screen name a
  /// different skill from the one the session then taught, in 87% of learner
  /// states a fuzz test could reach.
  current,

  /// Prerequisites met, nothing attempted yet. Startable, just not next.
  open,

  /// Started, not finished.
  started,

  /// Cleared.
  done,
}

class PathStep {
  const PathStep({
    required this.skill,
    required this.state,
    required this.strength,
  });

  final Skill skill;
  final PathState state;

  /// 0–1, how solid this skill is. Drives how full the ring around the node
  /// is drawn, so a child can see a skill firming up rather than only seeing
  /// it flip from unfinished to finished.
  final double strength;

  bool get isOpen => state != PathState.locked;
}

/// The order the steps are walked in.
///
/// Unteachable skills are kept in the graph on purpose — see the honesty rule
/// in `skill.dart` — but they are not put on the path. A step a child can see,
/// walk to, and then find nothing behind is worse than a path that ends.
List<Skill> pathOrder({Subject subject = Subject.reading}) {
  final open = teachableSkillsFor(subject).toList();
  final placed = <String>{};
  final out = <Skill>[];

  // Strand order is the tie-break, not the sort. Two skills that are both
  // reachable get resolved by which strand comes first, which is why the enum
  // is declared in teaching order.
  int strandRank(Skill s) => Strand.values.indexOf(s.strand);

  var guard = 0;
  while (open.isNotEmpty && guard++ < 200) {
    final ready = open.where((s) {
      return s.prerequisites.every((p) {
        // A prerequisite the app cannot teach never blocks — the same rule the
        // learner model uses, and it has to be the same rule or the path shows
        // a child as stuck on a skill the policy has already waved through.
        final pre = skillsById[p];
        if (pre != null && !pre.teachable) return true;
        return placed.contains(p);
      });
    }).toList()
      ..sort((a, b) => strandRank(a).compareTo(strandRank(b)));

    if (ready.isEmpty) break;
    final next = ready.first;
    out.add(next);
    placed.add(next.id);
    open.remove(next);
  }

  return out;
}

/// The path as the child stands on it right now.
///
/// ## The policy decides what is next, not this function
///
/// This used to work out `current` on its own: the first skill in graph order
/// that was not yet cleared. It reads as obviously right and it was wrong in
/// 350 of 400 random learner states — the home screen announced one skill under
/// "UP NEXT" and the session then taught a different one.
///
/// The reason is that "what next" is a real decision, not a position in a list.
/// [nextSkill] weighs due reviews, repairs after a repeated misconception, the
/// frontier, and transfer checks. None of that is visible from graph order, so
/// any second implementation of the question is a second answer to it.
///
/// So the states here describe the *graph* — done, locked, open, started — and
/// exactly one step is then overridden to [PathState.current] using the
/// engine's own decision. One source of truth, and a test asserts they agree.
List<PathStep> pathFor(Learner learner, {Subject subject = Subject.reading}) {
  final order = pathOrder(subject: subject);
  final steps = <PathStep>[];

  for (final skill in order) {
    final state = learner.stateOf(skill.id);
    final cleared = learner.isCleared(skill.id);
    final unlocked = skill.prerequisites.every((p) {
      final pre = skillsById[p];
      if (pre != null && !pre.teachable) return true;
      return learner.isCleared(p);
    });

    // `locked` means prerequisites unmet, and nothing else. It previously also
    // swallowed every unstarted skill that simply was not next, which drew a
    // padlock on work the engine was perfectly willing to set.
    final which = cleared
        ? PathState.done
        : !unlocked
            ? PathState.locked
            : state.state == MasteryState.notStarted
                ? PathState.open
                : PathState.started;

    steps.add(PathStep(
      skill: skill,
      state: which,
      strength: _strength(state),
    ));
  }

  final next = nextSkill(learner, subject: subject).skillId;
  final at = steps.indexWhere((s) => s.skill.id == next);
  if (at >= 0) {
    steps[at] = PathStep(
      skill: steps[at].skill,
      state: PathState.current,
      strength: steps[at].strength,
    );
  }

  return steps;
}

/// How solid a skill looks, on a scale a ring can be drawn from.
///
/// Deliberately coarse. This is a picture of progress, not the estimate the
/// engine acts on — inventing a precise-looking number here would imply the
/// app knows more than it does.
double _strength(SkillState state) => switch (state.state) {
      MasteryState.notStarted => 0,
      MasteryState.learning => 0.3,
      MasteryState.probable => 0.7,
      MasteryState.mastered => 1,
    };
