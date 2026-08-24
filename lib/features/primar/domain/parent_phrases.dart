/// The lines a parent records in their own voice.
///
/// ## Why recorded and not cloned
///
/// Cloning a parent's voice needs a provider that supports it (the current one
/// reports `supports_voice_cloning = false`), an API key, a consent flow and a
/// verification step — and produces a synthetic approximation of them.
///
/// Recording produces *them*. It needs no provider, no key and no consent
/// minefield, because a parent recording their own voice on their own phone has
/// already given the only consent that matters and can delete it at any time.
/// It is also warmer: a real mother saying "I know you can do this" beats any
/// synthesis of her saying it.
///
/// The trade is coverage. A clone can say anything; a recording says only what
/// was recorded. That turns out to matter far less than expected, because the
/// moments where a parent's voice is worth anything are **emotional**, not
/// instructional. Nobody needs their mother to read out "which one has the
/// most". They need her when they get something right, and when they get it
/// wrong and want to stop.
///
/// So this is a short, fixed set: praise, encouragement, a nudge to try again,
/// and a hello. Everything else stays in the teaching voice.
///
/// ## Why so few
///
/// A parent asked to record forty lines records none. Six is a two-minute job
/// standing in a kitchen, and it covers every moment that carries feeling.
library;

/// Emotional bucket a parent recording belongs in.
///
/// Appreciation must never play on a miss. Encouragement must never play on a
/// success. Patience is for thinking time — the child has not failed yet.
enum ParentMoment {
  /// Got it right / spoke correctly.
  appreciation,

  /// Missed, or being handed the same question back after teaching.
  encouragement,

  /// Still thinking — not wrong yet.
  patience,

  /// Session finished.
  proud,

  /// No parent line for this moment.
  none,
}

/// One line to record, and the moment it fills.
class ParentPhrase {
  const ParentPhrase({
    required this.id,
    required this.prompt,
    required this.when,
    required this.moment,
  });

  /// Stable — it is the filename on disk.
  final String id;

  /// What the parent is asked to say. Written to be said naturally rather than
  /// read: short, spoken, no clause a person would not use out loud.
  final String prompt;

  /// When the child will hear it. Shown to the parent, because knowing the
  /// moment changes how you say the line.
  final String when;

  /// Which emotional bucket this recording fills.
  final ParentMoment moment;
}

const List<ParentPhrase> parentPhrases = [
  ParentPhrase(
    id: 'hello',
    prompt: 'Hello! Let us learn together today.',
    when: 'When they open the app',
    moment: ParentMoment.none,
  ),
  ParentPhrase(
    id: 'proud',
    prompt: 'I am proud of you.',
    when: 'When they finish a session',
    moment: ParentMoment.proud,
  ),
  ParentPhrase(
    id: 'well_done',
    prompt: 'Well done!',
    when: 'When they get something right',
    moment: ParentMoment.appreciation,
  ),
  ParentPhrase(
    id: 'take_time',
    prompt: 'Take your time. Look again.',
    when: 'When they are thinking',
    moment: ParentMoment.patience,
  ),
  ParentPhrase(
    id: 'try_again',
    prompt: 'Try again. You can do this.',
    when: 'After a mistake',
    moment: ParentMoment.encouragement,
  ),
  ParentPhrase(
    id: 'come_back',
    prompt: 'See you tomorrow.',
    when: 'When they stop for the day',
    moment: ParentMoment.none,
  ),
];

/// Recording id for a [ParentMoment], or null when none belongs.
String? parentPhraseForMoment(ParentMoment moment) => switch (moment) {
      ParentMoment.appreciation => 'well_done',
      ParentMoment.encouragement => 'try_again',
      ParentMoment.patience => 'take_time',
      ParentMoment.proud => 'proud',
      ParentMoment.none => null,
    };

/// Which emotional moment a teaching-line id belongs to, if any.
///
/// This is the source of truth for "can this line ever trigger a parent
/// recording". Tests lock the mapping so appreciation cannot attach to a miss
/// line and encouragement cannot attach to a success line.
ParentMoment? parentMomentForLine(String voiceLineId) => switch (voiceLineId) {
      // Success / celebration only.
      'yes' ||
      'nice_one' ||
      'that_is_it' ||
      'good' ||
      'i_heard_you' ||
      'well_matched' ||
      'well_ordered' =>
        ParentMoment.appreciation,

      // After a miss, or handing the question back.
      'now_you_try' || 'look_again' || 'good_try' || 'it_is_this_one' =>
        ParentMoment.encouragement,

      // Thinking — must NOT map to try_again.
      'take_your_time' || 'have_a_look' || 'you_can_do_it' =>
        ParentMoment.patience,

      'all_done' => ParentMoment.proud,

      _ => null,
    };

/// Which recorded phrase, if any, should replace a teaching line.
///
/// Only the emotional moments are mapped. Instructional lines — the questions
/// themselves, counting aloud, letter sounds — always stay in the teaching
/// voice, because a parent has not recorded them and never should have to.
///
/// Returns null when the moment is not one a parent's voice belongs in.
String? parentPhraseFor(String voiceLineId) {
  final moment = parentMomentForLine(voiceLineId);
  if (moment == null) return null;
  return parentPhraseForMoment(moment);
}
