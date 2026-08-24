/// How much help the question itself gives.
///
/// ## The problem this solves
///
/// A picture beside a word is the difference between reading and shape-matching
/// — which is why every word in this app is picturable. But that is only true
/// while the child is *learning* the word. Leave the picture there forever and
/// the child never has to read anything: they look at the bed, they pick the
/// word next to the bed, and they can do that without knowing a single letter.
///
/// The same trap sits under every support in the product. A sound button that
/// never goes away means a child can wait to be told. A letter shown beside its
/// own sound means the mapping is never recalled, only recognised.
///
/// So support is not a property of a level. It is a property of *how well this
/// particular child currently knows this particular skill*, and it has to come
/// away as they get stronger — otherwise the app teaches a child to lean on it.
///
/// ## Why this is what makes the content scale
///
/// Without it, every new level needs new item types, and "how does the app work
/// at level 9" is a content question with no answer until someone writes level
/// 9. With it, one generator serves a skill for the whole of a child's journey
/// through it: the question stays the same and the scaffolding falls away.
///
/// That is also where the *transfer* evidence comes from for free. An item with
/// its support withdrawn is, by definition, the skill asked somewhere it was
/// not taught.
///
/// ## Fading, not removing
///
/// Support comes back when a child slips. The point is not to make things hard
/// as a reward for being good at them; it is to keep the question honest about
/// what the child is actually doing. A child who starts missing gets the
/// picture back, immediately and without ceremony.
library;

import 'learner.dart';

enum Support {
  /// Everything: the picture, the sound, and a replay. For a skill being met
  /// for the first time, or one a child is currently struggling with.
  full,

  /// The picture goes. The sound and its replay stay, so a child who did not
  /// catch it can still hear it again — that is access, not help.
  partial,

  /// Nothing but the question. This is where reading actually gets tested,
  /// and where transfer evidence comes from.
  none,
}

/// How much help this child should get on this skill right now.
///
/// Deliberately derived from the learner model rather than from the level, the
/// session number, or a setting. Two children on the same skill get different
/// scaffolding on the same day, and the same child gets different scaffolding
/// on the same skill a week apart.
Support supportFor(SkillState state) {
  // A skill that keeps needing the answer shown gets everything, regardless of
  // what the accuracy says. Help-dependence is the one signal that should
  // never be overruled by a good run.
  if (state.helpRate > 0.34) return Support.full;

  return switch (state.state) {
    // Never met it, or currently losing it.
    MasteryState.notStarted => Support.full,
    MasteryState.learning => Support.full,

    // Strong recently, but never tested without the props. Taking the picture
    // away here is exactly how we find out whether they were reading.
    MasteryState.probable => Support.partial,

    // Held up on its own. Reviews of a mastered skill are unsupported, because
    // a supported review tests nothing.
    MasteryState.mastered => Support.none,
  };
}

/// Whether an item built at this support level counts as transfer evidence.
///
/// Only the unsupported form does. A correct answer with the picture in front
/// of the child is evidence about the picture as much as about the word.
bool isTransferEvidence(Support support) => support == Support.none;

/// What the parent is told about why a question looked different today.
///
/// Worth surfacing, because a parent watching over a shoulder will see the
/// pictures disappear and reasonably wonder whether something broke.
String supportExplain(Support support, String name) => switch (support) {
      Support.full => '$name is learning this, so the picture and the sound are both there.',
      Support.partial => '$name is getting this, so we took the picture away and left the sound.',
      Support.none => '$name knows this, so we are asking without any help at all.',
    };
