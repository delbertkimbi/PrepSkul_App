import 'package:flutter/material.dart';

import '../domain/figure.dart';
import '../services/primar_voice.dart';
import 'mascot.dart';
import 'primar_strings.dart';
import 'primar_theme.dart';

/// Shown once, the first time a question asks to be answered a new way.
///
/// ## The hole this closes
///
/// The demonstration reel at the start of a session shows one mechanic: tap
/// one of these. Every other way of answering — join these pairs, drag these
/// into order, build this word out of letters — arrives later, mid-session,
/// with no warning and no explanation, in front of a child who by definition
/// cannot read an instruction.
///
/// What that looks like from the child's side is not "a harder question". It
/// is the game breaking. They tap the way they have been tapping, nothing
/// happens, the ring drains, and the app records that they needed help on a
/// skill they may well have.
///
/// So: one card, once per mechanic per session, before the first question that
/// uses it. It says the instruction aloud, shows the gesture as a picture, and
/// waits for a tap. It is the same shape as [ReteachCard] on purpose — a child
/// who has met one already knows what a card that waits for a tap is.
///
/// ## Which mechanics get one
///
/// Only the ones that are genuinely new. Tapping an option is what the
/// demonstration already taught and what the warm-up already drilled, so
/// [Interaction.choose] returns null and no card is ever built for it. Adding
/// one there would put a screen between a child and every single question.
class MechanicCard extends StatelessWidget {
  const MechanicCard({
    super.key,
    required this.interaction,
    required this.locale,
    required this.onReady,
  });

  final Interaction interaction;
  final String locale;
  final VoidCallback onReady;

  /// Whether this way of answering needs introducing at all.
  static bool needsIntroduction(Interaction interaction) => switch (interaction) {
        Interaction.choose => false,
        // Speaking is always optional and never scored, and the say-it button
        // explains itself by being a button with a microphone on it.
        Interaction.speak => false,
        Interaction.spell || Interaction.match || Interaction.order => true,
      };

  static VoiceLine? _lineFor(Interaction interaction) => switch (interaction) {
        Interaction.spell => VoiceLines.buildTheWord,
        Interaction.match => VoiceLines.matchThem,
        Interaction.order => VoiceLines.putInOrder,
        _ => null,
      };

  String _what(S s) => switch (interaction) {
        Interaction.spell => s.spellHow,
        Interaction.match => s.matchHow,
        Interaction.order => s.orderHow,
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final s = S(locale);

    return GestureDetector(
      onTap: onReady,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          const Mate(mood: Mood.happy, size: 96),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: PrimarTheme.tile(border: PrimarTheme.blue, lift: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.newWayKicker,
                    style: PrimarTheme.label(11, color: PrimarTheme.blue)),
                const SizedBox(height: 10),
                Text(_what(s), style: PrimarTheme.display(21)),
                const SizedBox(height: 22),
                Center(child: _GestureHint(interaction: interaction)),
                const SizedBox(height: 22),
                Center(
                  child: Text(s.newWayGo,
                      style: PrimarTheme.body(15, color: PrimarTheme.blue)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Says the line aloud. Called by the session when the card appears rather
  /// than from `initState`, so a rebuild cannot make it speak twice.
  static void speak(Interaction interaction) {
    final line = _lineFor(interaction);
    if (line != null) PrimarVoice.instance.say(line);
  }
}

/// The gesture, drawn. A sentence a child cannot read is not an instruction,
/// so the picture is the part that has to carry it.
class _GestureHint extends StatelessWidget {
  const _GestureHint({required this.interaction});

  final Interaction interaction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: CustomPaint(
        size: const Size(240, 78),
        painter: _GesturePainter(interaction),
      ),
    );
  }
}

class _GesturePainter extends CustomPainter {
  _GesturePainter(this.interaction);

  final Interaction interaction;

  @override
  void paint(Canvas canvas, Size size) {
    final tile = Paint()
      ..color = PrimarTheme.blue.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final edge = Paint()
      ..color = PrimarTheme.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final slot = Paint()
      ..color = PrimarTheme.navy.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    void box(double x, double y, double w, double h, Paint fill) {
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h), const Radius.circular(7));
      canvas.drawRRect(r, fill);
      canvas.drawRRect(r, edge);
    }

    /// An arrow from one point to another, which is the whole vocabulary here:
    /// spelling moves a letter up into a slot, ordering moves one sideways,
    /// matching joins a left thing to a right thing.
    void arrow(Offset from, Offset to) {
      canvas.drawLine(from, to, edge);
      final d = (to - from);
      final len = d.distance == 0 ? 1 : d.distance;
      final u = Offset(d.dx / len, d.dy / len);
      final n = Offset(-u.dy, u.dx);
      canvas.drawLine(to, to - u * 9 + n * 6, edge);
      canvas.drawLine(to, to - u * 9 - n * 6, edge);
    }

    final cx = size.width / 2;

    switch (interaction) {
      case Interaction.spell:
        // Three empty slots on top, a letter below, an arrow lifting it in.
        for (var i = 0; i < 3; i++) {
          box(cx - 57 + i * 38, 2, 30, 24, slot);
        }
        box(cx - 15, 36, 30, 24, tile);
        arrow(Offset(cx, 34), Offset(cx - 42, 30));

      case Interaction.match:
        // Two on the left, two on the right, one line already joined.
        box(cx - 78, 2, 30, 24, tile);
        box(cx - 78, 34, 30, 24, tile);
        box(cx + 48, 2, 30, 24, tile);
        box(cx + 48, 34, 30, 24, tile);
        arrow(Offset(cx - 46, 14), Offset(cx + 46, 46));

      case Interaction.order:
        // A row, with one tile sliding left into place.
        for (var i = 0; i < 4; i++) {
          box(cx - 76 + i * 39, 18, 31, 26, i == 2 ? tile : slot);
        }
        arrow(Offset(cx + 2, 10), Offset(cx - 60, 10));

      case Interaction.choose:
      case Interaction.speak:
        break;
    }
  }

  @override
  bool shouldRepaint(_GesturePainter old) => old.interaction != interaction;
}
