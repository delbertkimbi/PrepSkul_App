/// What to do when the same mistake keeps coming back.
///
/// ## Why this is a registry and not a screen
///
/// The b/d bed was one hand-built screen for one misconception. That is an
/// example, not a system: the tracker already classifies **eight** kinds of
/// mistake, the policy already routes a child to a repair when one of them
/// recurs, and seven of those routes arrived at more of the same question.
///
/// A child who keeps answering one-more-than the right number does not need
/// another counting question. They need someone to count it out with them,
/// slowly, once. A child who answers with one of the numbers they can see does
/// not have an arithmetic problem — they have not understood that the question
/// is asking for something new. Those are different problems with different
/// answers, and the app had one answer.
///
/// So: every misconception the tracker can name has an entry here, and every
/// entry says what a teacher would actually *do*. The ones without a built
/// screen say so rather than silently falling through, which is the same
/// honesty rule the skill graph follows — a missing rung is fine, a rung that
/// pretends to hold weight is not.
///
/// ## Why the engine owns this and not a model
///
/// A language model can write the *words* for an explanation. It must not
/// decide that a child who reverses letters needs spelling practice. The
/// mapping from "what went wrong" to "what to do about it" is pedagogy, and it
/// belongs in code where it can be read, argued with and tested.
library;

import 'misconception.dart';

/// How an intervention is delivered.
enum InterventionKind {
  /// A purpose-built screen. The strongest form, and the most expensive.
  demonstration,

  /// The same idea shown with a different representation — count it out, act
  /// it out, draw it — inside the ordinary question flow.
  reteach,

  /// Nothing built yet. The policy still drops to the prerequisite skill; the
  /// child simply does not get a new way in.
  none,
}

/// What the app does about one kind of recurring mistake.
class Intervention {
  const Intervention({
    required this.misconception,
    required this.kind,
    required this.what,
    required this.why,
    this.screenId,
  });

  final Misconception misconception;
  final InterventionKind kind;

  /// What a teacher would do, in plain words. Shown to a parent.
  final String what;

  /// Why this mistake calls for that, rather than more practice.
  final String why;

  /// Identifies a built screen, when there is one.
  final String? screenId;

  bool get isBuilt => kind != InterventionKind.none;
}

/// One entry per misconception the tracker can name. No gaps, by construction —
/// a test asserts it.
const List<Intervention> interventions = [
  Intervention(
    misconception: Misconception.letterReversal,
    kind: InterventionKind.reteach,
    what: 'Show the two letters together and say which way each one faces.',
    why: 'A reversal is a spatial mistake, not a sound one — the child usually '
        'knows both sounds perfectly well, so more listening practice cannot '
        'touch it. The difference only exists in the comparison, so the two '
        'letters have to be seen side by side.\n\n'
        'This was a "bed" mnemonic screen for a while: show the word bed, b is '
        'the head and d is the foot. It was deleted because it is circular — '
        'to use it a child must already recognise the word "bed", and a child '
        'who reverses b and d is usually nowhere near reading a word. The '
        'trick needed the skill it was meant to unlock.',
  ),
  Intervention(
    misconception: Misconception.letterShape,
    kind: InterventionKind.reteach,
    what: 'Put the two letters side by side and trace what is different.',
    why: 'm and n, u and n differ by one stroke. Showing them apart teaches '
        'nothing; the difference only exists in the comparison.',
  ),
  Intervention(
    misconception: Misconception.letterSound,
    kind: InterventionKind.reteach,
    what: 'Say the sound, then a word that starts with it, then the letter.',
    why: 'The child heard the sound and reached for the wrong letter, so the '
        'gap is in the mapping. Anchoring the sound to a word they know gives '
        'the mapping something to hold on to.',
  ),
  Intervention(
    misconception: Misconception.offByOne,
    kind: InterventionKind.reteach,
    what: 'Count it out loud together, one object at a time.',
    why: 'Off by one is almost always a counting slip rather than not knowing '
        '— the child counted and lost their place. Another question of the '
        'same kind gives them another chance to lose it.',
  ),
  Intervention(
    misconception: Misconception.countingUnstable,
    kind: InterventionKind.reteach,
    what: 'Drop to a smaller group and count it out together.',
    why: 'Being out by more than one means the quantity was guessed at, not '
        'counted. The number needs to be small enough to be counted before '
        'counting can be practised.',
  ),
  Intervention(
    misconception: Misconception.operandEcho,
    kind: InterventionKind.none,
    what: 'Show the two groups joining into one.',
    why: 'Answering with a number from the question means the operation has '
        'not landed at all — the child is returning what they can see. It '
        'needs the joining shown, not the sum repeated.',
  ),
  Intervention(
    misconception: Misconception.wrongOperation,
    kind: InterventionKind.none,
    what: 'Contrast joining and taking away, side by side.',
    why: 'The child can do both operations and read the wrong one. Like a '
        'letter reversal, the fix is a comparison, not more of either.',
  ),
  Intervention(
    misconception: Misconception.unclear,
    kind: InterventionKind.none,
    what: '',
    why: 'Nothing recognisable happened, so there is nothing to teach against. '
        'Guessing at an intervention here would be worse than none.',
  ),
];

/// What to do about [m].
Intervention interventionFor(Misconception m) =>
    interventions.firstWhere((i) => i.misconception == m);

/// Whether a built screen exists for this mistake.
bool hasBuiltIntervention(Misconception m) => interventionFor(m).isBuilt;

/// How much of the tracker's vocabulary the app can actually respond to.
///
/// Surfaced so the gap is a number someone can look at rather than a thing
/// discovered by a child hitting it.
double get interventionCoverage {
  final real = interventions.where((i) => i.misconception != Misconception.unclear);
  return real.where((i) => i.isBuilt).length / real.length;
}
