import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The paper-craft design language, carried over from Summer Build Camp.
///
/// Depth comes from hard, fully opaque shadows rather than soft blurred ones.
/// That is a legibility decision before it is an aesthetic one: a raised, tappable
/// object has to read instantly on a scratched screen in daylight, and it has to
/// cost almost nothing to draw on a low-end phone.
class PrimarTheme {
  PrimarTheme._();

  // The brand palette, taken from the design sheet rather than approximated.
  //
  // Two changes worth naming. The old "brick" red was doing double duty as the
  // question colour, and red is the one colour a child already reads as *you
  // got it wrong* — so questions now use orange, which carries the same
  // "look here" weight with none of the verdict. And every accent has a pale
  // partner, because a tile that has to look selected needs a fill that does
  // not fight the ink sitting on it.
  static const Color navy = Color(0xFF1E3A8A);
  static const Color blue = Color(0xFF2563EB);
  static const Color teal = Color(0xFF14B8A6);
  static const Color yellow = Color(0xFFFACC15);
  static const Color orange = Color(0xFFFB923C);

  /// Kept as an alias so nothing that referred to the old accent breaks. It is
  /// the same hue role, not the same colour.
  static const Color brick = orange;

  static const Color tintBlue = Color(0xFFE0F2FE);
  static const Color tintGreen = Color(0xFFF0FDF4);
  static const Color tintYellow = Color(0xFFFEF3C7);
  static const Color tintGrey = Color(0xFFCBD5E1);

  /// The fill behind a selected tile, and the purple the celebration uses.
  ///
  /// Both were living as raw hex in five and six places respectively, which is
  /// how a palette change leaves half an app behind: the brand yellow and red
  /// were updated here and the old values kept rendering everywhere else.
  static const Color tintTeal = Color(0xFFE6F6F2);
  static const Color purple = Color(0xFF8B5CF6);

  static const Color paper = Color(0xFFF8FAFC);
  static const Color sheet = Color(0xFFFFFFFF);
  static const Color inkSoft = Color(0xFF334155);
  static const Color muted = Color(0xFF64748B);

  /// Question figures are brick, answers are blue. Two roles, two colours, so a
  /// child never has to be told which side of the puzzle they are looking at.
  static const Color questionInk = orange;
  static const Color answerInk = blue;
  static const Color ghostInk = Color(0xFF94A3B8);

  static TextStyle display(double size, {Color color = navy, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color, height: 1.14, letterSpacing: -0.2);

  static TextStyle body(double size, {Color color = inkSoft, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color, height: 1.5);

  static TextStyle label(double size, {Color color = muted}) => GoogleFonts.nunito(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 1.6,
      );

  static BoxDecoration paperSheet({double radius = 26}) => BoxDecoration(
        color: sheet,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x1F252F45), blurRadius: 32, offset: Offset(0, 16)),
          BoxShadow(color: Color(0x14252F45), blurRadius: 4, offset: Offset(0, 2)),
        ],
      );

  /// Answer tiles: an opaque, zero-blur shadow so the tile reads as a physical
  /// thing sitting above the page.
  static BoxDecoration tile({Color? border, Color? fill, double lift = 6}) => BoxDecoration(
        color: fill ?? sheet,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border ?? navy.withValues(alpha: 0.16), width: 2),
        boxShadow: [
          BoxShadow(color: (border ?? navy).withValues(alpha: 0.22), blurRadius: 0, offset: Offset(0, lift)),
        ],
      );
}

/// The halftone dot ground. Painted rather than tiled from an asset so it stays
/// crisp at any density and adds nothing to the bundle.
class PaperGround extends StatefulWidget {
  const PaperGround({super.key, required this.child});

  final Widget child;

  @override
  State<PaperGround> createState() => _PaperGroundState();
}

class _PaperGroundState extends State<PaperGround> {
  /// Compiled once for the whole app, not once per screen.
  ///
  /// Every stage in the flow wraps itself in a PaperGround, so loading the
  /// program per widget would recompile it on every navigation.
  static ui.FragmentProgram? _program;
  static bool _tried = false;

  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_tried) {
      if (mounted && _program != null) {
        setState(() => _shader = _program!.fragmentShader());
      }
      return;
    }
    _tried = true;
    try {
      _program = await ui.FragmentProgram.fromAsset('assets/shaders/paper.frag');
      if (mounted) setState(() => _shader = _program!.fragmentShader());
    } catch (e) {
      // Impeller off, an old driver, a stripped build — any of these and the
      // app still has to open. The flat fill below is the fallback, and it is
      // a fallback rather than an error because a background is not worth a
      // crash.
      debugPrint('[PaperGround] shader unavailable, using flat paper: $e');
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    return Container(
      color: PrimarTheme.paper,
      child: shader == null
          ? widget.child
          : CustomPaint(
              painter: _PaperPainter(shader),
              child: widget.child,
            ),
    );
  }
}

/// Hands the shader its size and the theme's colours, then fills.
class _PaperPainter extends CustomPainter {
  _PaperPainter(this.shader);

  final ui.FragmentShader shader;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      // The paper and tint colours come from the theme rather than being
      // written into the GLSL, so there is one place a palette change lands.
      ..setFloat(2, PrimarTheme.paper.r)
      ..setFloat(3, PrimarTheme.paper.g)
      ..setFloat(4, PrimarTheme.paper.b)
      ..setFloat(5, PrimarTheme.tintBlue.r)
      ..setFloat(6, PrimarTheme.tintBlue.g)
      ..setFloat(7, PrimarTheme.tintBlue.b);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  // Static by design — see the note at the top of paper.frag. Repainting only
  // happens when the shader instance itself changes.
  @override
  bool shouldRepaint(covariant _PaperPainter old) => old.shader != shader;
}

/// A strip of tape. Small, deliberate imperfection — it is what makes the
/// surface read as paper rather than as a card component.
class Tape extends StatelessWidget {
  const Tape({super.key, this.width = 84});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.035,
      child: Container(
        width: width,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFF638BE0).withValues(alpha: 0.7),
          boxShadow: const [BoxShadow(color: Color(0x1F132D63), blurRadius: 2, offset: Offset(0, 1))],
        ),
      ),
    );
  }
}

/// A button that lifts and presses like a paper cut-out.
class PaperButton extends StatefulWidget {
  const PaperButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.expand = true,
    this.circular = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool expand;
  final bool circular;

  @override
  State<PaperButton> createState() => _PaperButtonState();
}

class _PaperButtonState extends State<PaperButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final radius = widget.circular ? BorderRadius.circular(999) : BorderRadius.circular(18);

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: widget.expand ? double.infinity : null,
          transform: Matrix4.translationValues(0, _down ? 5 : 0, 0),
          padding: widget.circular
              ? const EdgeInsets.all(22)
              : const EdgeInsets.symmetric(horizontal: 26, vertical: 17),
          decoration: BoxDecoration(
            // Teal, not navy.
            //
            // The button was the same deep navy as the headings, which made
            // the one thing on the screen a child is meant to press look like
            // part of the page. Every product a child already knows uses a
            // bright, saturated "go" colour for the primary action and reserves
            // dark ink for text — and the reason is not fashion: a low-contrast
            // CTA on a cheap screen in daylight is simply hard to find.
            //
            // Teal is already the palette's "this went well" colour — the
            // cleared nodes, the progress fill — so pressing it means the same
            // thing everywhere.
            color: enabled ? const Color(0xFF14B8A6) : const Color(0xFFCBD5E1),
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: enabled ? const Color(0xFF0E9384) : const Color(0xFFA8B3C4),
                blurRadius: 0,
                offset: Offset(0, _down ? 2 : 7),
              ),
            ],
          ),
          child: Center(widthFactor: widget.expand ? null : 1, child: widget.child),
        ),
      ),
    );
  }
}
