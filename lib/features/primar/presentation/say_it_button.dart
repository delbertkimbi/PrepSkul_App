import 'package:flutter/material.dart';

import '../domain/figure.dart';
import '../services/primar_voice.dart';
import '../services/say_it_back.dart';
import '../services/tutor_brain.dart';
import 'primar_theme.dart';

/// The fourth step of the loop: say it back.
///
/// The other three — Mate demonstrating, the answer being named and explained
/// on a miss, and the same question coming straight back unscored — were all
/// running. This one was written, tested, and then never put on a screen, so
/// for every child who has used this, the loop has been three steps long.
///
/// ## The rule, which is the whole design
///
/// **Speech can earn a reward. It can never cost one.**
///
/// Recognisers run 30–45% word error on African-accented English and worse on
/// children. Grading a spoken answer at that rate would tell a child they were
/// wrong when they were right — precisely the experience this product exists
/// to undo. So there are only two outcomes: heard, which celebrates, and not
/// heard, which shrugs and moves on. A child who says it perfectly into a
/// broken microphone loses nothing.
///
/// It follows that this is never required, never blocks the next question, and
/// never appears before the answer is already known and correct. It is
/// practice, not assessment.
class SayItButton extends StatefulWidget {
  const SayItButton({
    super.key,
    required this.target,
    required this.locale,
  });

  /// What the child is invited to say — a letter, a word, or a number.
  final String target;

  final String locale;

  /// The thing worth saying in this item, or null if there isn't one.
  ///
  /// A shape composition has no name to say, and inviting a child to say a
  /// nameless thing is a question with no answer.
  static String? targetFor(PrimarItem item) {
    // The generator's own answer, when it set one. This matters most for
    // numbers: the target is matched against what a recogniser *heard*, and a
    // child saying "five" produces the word, never the digit. Returning '5'
    // here meant every spoken number failed to match, so the one subject where
    // saying the answer is easiest was the one where it never worked.
    if (item.sayTarget != null) return item.sayTarget;

    if (item.options.isEmpty || item.answerIndex >= item.options.length) return null;
    return switch (item.options[item.answerIndex]) {
      LetterFigure(:final letter) => letter,
      WordFigure(:final word) => word,
      _ => null,
    };
  }

  @override
  State<SayItButton> createState() => _SayItButtonState();
}

enum _Phase { idle, listening, heard }

class _SayItButtonState extends State<SayItButton> {
  _Phase _phase = _Phase.idle;

  @override
  void dispose() {
    SayItBack.instance.cancel();
    super.dispose();
  }

  Future<void> _listen() async {
    if (_phase != _Phase.idle) return;
    setState(() => _phase = _Phase.listening);

    final result = await SayItBack.instance.listenFor(
      widget.target,
      locale: widget.locale,
    );
    if (!mounted) return;

    if (result.matched) {
      setState(() => _phase = _Phase.heard);
      PrimarVoice.instance.chime(Sfx.streak);
      PrimarVoice.instance.sayFromBrain(
        TutorContext(
          moment: TutorMoment.speak,
          locale: widget.locale,
          speakTarget: widget.target,
          speakMatched: true,
          heard: result.heard,
        ),
      );
    } else if (result.hasHeard) {
      // Heard→correct coaching. Still not a miss: button stays available, no
      // score change — speech can never cost a reward.
      setState(() => _phase = _Phase.idle);
      PrimarVoice.instance.sayFromBrain(
        TutorContext(
          moment: TutorMoment.speak,
          locale: widget.locale,
          speakTarget: widget.target,
          speakMatched: false,
          heard: result.heard,
        ),
      );
    } else {
      // Silence / noise / no recogniser: shrug, no line that could feel like
      // "you said it wrong".
      setState(() => _phase = _Phase.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final heard = _phase == _Phase.heard;
    final listening = _phase == _Phase.listening;

    return Center(
      child: GestureDetector(
        onTap: heard ? null : _listen,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: PrimarTheme.tile(
            border: heard
                ? PrimarTheme.teal
                : listening
                    ? PrimarTheme.blue
                    : null,
            fill: heard
                ? PrimarTheme.tintTeal
                : listening
                    ? PrimarTheme.tintBlue
                    : null,
            lift: listening ? 2 : 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Mic(listening: listening, heard: heard),
              const SizedBox(width: 10),
              Text(
                // Never an instruction that has to be read to be understood —
                // the microphone carries it. The word is here for the adult
                // sitting alongside.
                heard
                    ? (widget.locale == 'fr' ? 'Bravo !' : 'Nice!')
                    : listening
                        ? (widget.locale == 'fr' ? 'Je t’écoute…' : 'Listening…')
                        : (widget.locale == 'fr' ? 'Dis-le' : 'Say it'),
                style: PrimarTheme.display(15,
                    color: heard ? PrimarTheme.teal : PrimarTheme.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mic extends StatefulWidget {
  const _Mic({required this.listening, required this.heard});

  final bool listening;
  final bool heard;

  @override
  State<_Mic> createState() => _MicState();
}

class _MicState extends State<_Mic> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        // A microphone that does not move while it is listening looks broken,
        // and a child who thinks it is broken stops talking.
        final grow = widget.listening ? 1 + _pulse.value * 0.16 : 1.0;
        return Transform.scale(
          scale: grow,
          child: Icon(
            widget.heard ? Icons.check_rounded : Icons.mic_rounded,
            size: 22,
            color: widget.heard
                ? PrimarTheme.teal
                : widget.listening
                    ? PrimarTheme.blue
                    : PrimarTheme.muted,
          ),
        );
      },
    );
  }
}
