/// What the child does next, and why.
///
/// ## The one rule
///
/// **The engine decides what to teach. Nothing else does.**
///
/// Not the calendar, not the child's age, not a model asked to be creative. A
/// language model is downstream of this file: it can write a second explanation
/// for a skill this file selected, in words this file asked for. It does not
/// get to decide that today is a good day for fractions.
///
/// That separation is the difference between a learning system and a chatbot
/// with a syllabus in its prompt. It is also what makes the thing testable —
/// every decision here is a pure function of the learner's evidence, so it can
/// be checked against a child who does not exist yet.
///
/// ## The order of business
///
/// 1. **Anything due for review.** Retrieval beats new material. A skill that
///    was mastered and is now due is the highest-value minute in the session,
///    because that is the minute that decides whether it is still there next
///    month.
/// 2. **An unresolved misconception.** If the same mistake has come back three
///    times, more of the same question is not the answer. Drop to the
///    prerequisite that explains it.
/// 3. **The frontier.** Skills whose groundwork is done and which are not
///    finished, nearest the foundations first.
/// 4. **Transfer.** A skill sitting at *probable* has strong recent evidence
///    and has never been tested away from where it was taught. Test it.
///
/// Nothing here ever selects a skill whose prerequisites are unmet. A child
/// failing something unreachable has not learned that it is hard; they have
/// learned that they are stupid, and those are very different lessons.
library;

import 'learner.dart';
import 'intervention.dart';
import 'misconception.dart';
import 'skill.dart';
import 'subjects.dart';

/// Why the engine chose this.
///
/// Surfaced so a session can be explained to a parent, and so a wrong decision
/// leaves a trail. "It kept giving him letter sounds" is unanswerable; "it went
/// back to letter sounds because b/d came back three times" is a claim someone
/// can argue with.
enum Reason {
  /// Due for spaced retrieval.
  review,

  /// A misconception recurred; this is the rung underneath it.
  repair,

  /// A misconception recurred and there is a different way to show it. Unlike
  /// [repair], which changes *what* is worked on, this changes *how* — and it
  /// is the only branch that gives a child something they have not already
  /// seen and failed.
  reteach,

  /// Next thing they are ready for.
  advance,

  /// Known here, but never tested anywhere else.
  transfer,

  /// Nothing is reachable. See [Decision.exhausted].
  nothingLeft,
}

/// The engine's answer.
class Decision {
  const Decision({
    required this.skillId,
    required this.reason,
    this.explain = '',
  });

  /// Null only when [reason] is [Reason.nothingLeft].
  final String? skillId;
  final Reason reason;

  /// One sentence a parent could read.
  final String explain;

  /// True when every teachable skill is mastered, or when the only skills left
  /// are ones this app cannot yet present.
  ///
  /// Not an error. It is the graph telling us where the product stops, and it
  /// should be visible rather than papered over with a repeat of something the
  /// child already finished.
  bool get exhausted => skillId == null;
}

/// What the home screen calls the next session.
///
/// Brilliant separates "continue the course" from "review" and from "practice
/// this weak spot". The engine already knows [Reason]; this is the label a
/// child sees before they press Start.
String sessionHeadline(Reason reason) => switch (reason) {
      Reason.review => 'REVIEW',
      Reason.repair || Reason.reteach => 'PRACTICE',
      _ => 'UP NEXT',
    };

/// How long a skill has to have been quiet before review outranks new work.
///
/// Without this a session that begins the moment a review falls due spends
/// itself entirely on revision, and a child who came to learn something learns
/// nothing new.
const int maxReviewsPerSession = 2;

/// Picks the next skill.
///
/// [reviewsSoFar] is how many review items this session has already spent, so
/// the caller can keep a session from collapsing into revision.
Decision nextSkill(Learner learner,
    {int reviewsSoFar = 0, Subject subject = Subject.reading}) {
  /// Whether a skill belongs to the subject this session is about.
  ///
  /// One evidence log holds every subject a child has touched, so a review or
  /// a repair drawn from it could otherwise be for a different subject
  /// entirely — a letter sound surfacing halfway through counting.
  bool mine(String skillId) => skillsById[skillId]?.subject == subject;

  // 1. Due reviews, oldest first.
  if (reviewsSoFar < maxReviewsPerSession) {
    final due = learner.skills.values
        .where((s) => s.state == MasteryState.mastered && s.isDue && mine(s.skillId))
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    if (due.isNotEmpty) {
      final s = due.first;
      return Decision(
        skillId: s.skillId,
        reason: Reason.review,
        explain: 'Coming back to ${_label(s.skillId)} to check it has stuck.',
      );
    }
  }

  // 2. A misconception that keeps returning. The answer is a rung down, not
  //    another go at the same rung.
  final stuck = learner.skills.values
      .where((s) =>
          s.state == MasteryState.learning &&
          s.dominantMisconception != Misconception.unclear &&
          mine(s.skillId))
      .toList()
    ..sort((a, b) => a.recentAccuracy.compareTo(b.recentAccuracy));

  // A different way in beats a rung down.
  //
  // Dropping to the prerequisite is the right move when the groundwork is
  // missing. It is the wrong move when the child has the groundwork and a
  // stuck idea — then they need the same thing shown differently, which is
  // what the intervention registry is for.
  for (final s in stuck) {
    final plan = interventionFor(s.dominantMisconception);
    if (plan.isBuilt) {
      return Decision(
        skillId: s.skillId,
        reason: Reason.reteach,
        explain: plan.what,
      );
    }
  }

  for (final s in stuck) {
    final repair = _repairFor(s, learner);
    if (repair != null) {
      return Decision(
        skillId: repair,
        reason: Reason.repair,
        explain: '${_label(s.skillId)} keeps going the same way wrong, '
            'so we are going back to ${_label(repair)} first.',
      );
    }
  }

  // 3. The frontier, foundations first. Sorting by how much a skill rests on
  //    keeps the engine from wandering off into a distant strand while
  //    something closer to the ground is still open.
  final frontier = learner.frontier(subject: subject)
    ..sort((a, b) =>
        prerequisitesOf(a.id).length.compareTo(prerequisitesOf(b.id).length));

  final unstarted = frontier
      .where((s) => learner.stateOf(s.id).state == MasteryState.notStarted)
      .toList();
  final learning = frontier
      .where((s) => learner.stateOf(s.id).state == MasteryState.learning)
      .toList();

  // Something already begun beats something new. Finishing beats starting.
  final pick = learning.isNotEmpty ? learning.first : (unstarted.isNotEmpty ? unstarted.first : null);
  if (pick != null) {
    return Decision(
      skillId: pick.id,
      reason: Reason.advance,
      explain: 'Working on ${_label(pick.id)}.',
    );
  }

  // 4. Everything reachable is at least probable. Test the oldest of those
  //    somewhere it was not taught.
  final probable = frontier
      .where((s) => learner.stateOf(s.id).state == MasteryState.probable)
      .toList();
  if (probable.isNotEmpty) {
    final s = probable.first;
    return Decision(
      skillId: s.id,
      reason: Reason.transfer,
      explain: '${_label(s.id)} looks solid. Trying it somewhere new.',
    );
  }

  return const Decision(
    skillId: null,
    reason: Reason.nothingLeft,
    explain: 'Everything this app can teach here is done.',
  );
}

/// The prerequisite worth revisiting when [s] keeps failing the same way.
///
/// Returns null when there is nothing below it to go back to — a child stuck on
/// a foundation skill needs a person, not a lower number, and pretending
/// otherwise sends them round a loop.
String? _repairFor(SkillState s, Learner learner) {
  final skill = skillsById[s.skillId];
  if (skill == null) return null;

  // A reversal is a *shape* problem wearing a sound problem's clothes. A child
  // who picks d for /b/ has usually not misheard anything, and drilling the
  // sound will not touch it.
  if (s.dominantMisconception == Misconception.letterReversal &&
      s.skillId != 'letter.shape.reversal' &&
      skillsById.containsKey('letter.shape.reversal')) {
    return 'letter.shape.reversal';
  }

  for (final p in prerequisitesOf(s.skillId)) {
    final prereq = skillsById[p];
    if (prereq == null || !prereq.teachable) continue;
    // Only worth going back to if it is not already solid. Re-teaching
    // something they demonstrably have is a way to waste a child's afternoon.
    if (learner.stateOf(p).state != MasteryState.mastered) return p;
  }
  return null;
}

String _label(String skillId) => skillsById[skillId]?.label ?? skillId;

/// A short, honest account of where a child is, for the parent.
///
/// Names abilities, never deficits, and never a grade. The rule the rest of
/// this codebase already follows: describe what the child can do and what comes
/// next, because a label is the thing these families have had enough of.
String summarise(Learner learner, String name) {
  final who = name.trim().isEmpty ? 'Your child' : name.trim();

  final done = learner.skills.values
      .where((s) => s.state == MasteryState.mastered)
      .map((s) => _label(s.skillId))
      .toList();
  final working = learner.skills.values
      .where((s) => s.state == MasteryState.learning)
      .map((s) => _label(s.skillId))
      .toList();

  if (done.isEmpty && working.isEmpty) {
    return '$who is just getting started.';
  }
  if (done.isEmpty) {
    return '$who is working on ${working.first.toLowerCase()}.';
  }
  final headline = '$who can now ${done.last.toLowerCase()}';
  if (working.isEmpty) return '$headline.';
  return '$headline, and is working on ${working.first.toLowerCase()}.';
}
