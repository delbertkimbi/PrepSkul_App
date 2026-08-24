import 'package:flutter/material.dart';

import '../domain/intervention.dart';
import '../services/primar_voice.dart';
import '../services/tutor_brain.dart';
import 'letter_card.dart';
import 'mascot.dart';
import 'primar_theme.dart';

/// A different way in, shown before the question comes back.
///
/// ## What was broken
///
/// The policy could already return [Reason.reteach] — it knew the child had
/// made the same mistake three times and knew what a teacher would do about it.
/// Nothing rendered it. The decision was computed, logged, and thrown away, and
/// the child got the next question exactly as if nothing had been noticed.
///
/// That is the gap between having a learning engine and having one that
/// reaches a child.
///
/// ## Why it is a card and not a screen
///
/// The first attempt at an intervention was a purpose-built screen for one
/// misconception. It cost two days of drawing, was never wired into the app,
/// and would have helped exactly one of the eight mistakes the tracker names.
///
/// A card that reads the plan out of the registry works for **all** of them the
/// day they are added, appears in the flow the child is already in, and costs
/// nothing per new intervention. Purpose-built screens can come later for the
/// ones that genuinely need a picture; they should not be the only way an
/// intervention can exist.
class ReteachCard extends StatefulWidget {
  const ReteachCard({
    super.key,
    required this.plan,
    required this.onReady,
    this.letter,
    this.sound,
    this.locale = 'en',
  });

  final Intervention plan;

  /// The letter the child just got wrong, when the mistake was a letter one.
  ///
  /// With it, the card can *show* the thing rather than describe it — the
  /// letter big in both cases with two pictures that start with it, which is
  /// the shape every printed phonics worksheet has used for decades. Without
  /// it, the card falls back to the plan in words.
  final String? letter;
  final String? sound;
  final String locale;

  /// The child taps on when they have looked at it.
  final VoidCallback onReady;

  @override
  State<ReteachCard> createState() => _ReteachCardState();
}

class _ReteachCardState extends State<ReteachCard> {
  @override
  void initState() {
    super.initState();
    // Named before it is shown, so a child who cannot read still knows
    // something changed rather than wondering why the game paused.
    //
    // Contextual opener when we know the letter; otherwise a short pattern cue.
    // The letter card that follows still says the sound and its words itself.
    PrimarVoice.instance.sayFromBrain(
      TutorContext(
        moment: TutorMoment.reteach,
        locale: widget.locale,
        letter: widget.letter,
        sound: widget.sound,
        misconception: widget.plan.misconception,
      ),
    );
    if (widget.letter == null) PrimarVoice.instance.say(VoiceLines.lookAtBoth);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onReady,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          const Mate(mood: Mood.encourage, size: 84),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: PrimarTheme.tile(border: PrimarTheme.orange, lift: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A DIFFERENT WAY',
                    style: PrimarTheme.label(10, color: PrimarTheme.orange)),
                const SizedBox(height: 8),
                // The plan, in the words the registry holds. A parent reading
                // over a shoulder gets the same sentence the engine acted on,
                // which is the only way "why is it doing that" has an answer.
                Text(widget.plan.what, style: PrimarTheme.display(19)),
                if (widget.letter != null && widget.sound != null) ...[
                  const SizedBox(height: 16),
                  LetterCard(
                    letter: widget.letter!,
                    sound: widget.sound!,
                    locale: widget.locale,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
