import 'package:flutter/material.dart';

/// Shared motion tokens — one place for the feel of the app.
///
/// Brilliant's polish is not one animation; it is the same easing everywhere,
/// stagger on lists, and nothing that jumps. These constants are the contract.
abstract final class PrimarMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);
  static const Duration pulse = Duration(milliseconds: 1600);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve bounce = Curves.easeOutBack;

  /// Stagger delay for the nth item in a list (Brilliant-style cascade).
  static Duration stagger(int index, {int baseMs = 45}) =>
      Duration(milliseconds: index * baseMs);
}

/// Fades and slides a child in once, on first build.
class PrimarReveal extends StatefulWidget {
  const PrimarReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 14,
  });

  final Widget child;
  final Duration delay;
  final double offsetY;

  @override
  State<PrimarReveal> createState() => _PrimarRevealState();
}

class _PrimarRevealState extends State<PrimarReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    // Delay is baked into the controller so widget tests never inherit a
    // dangling Timer from a staggered home-screen reveal.
    final total = widget.delay + PrimarMotion.medium;
    _c = AnimationController(vsync: this, duration: total);
    final start = widget.delay == Duration.zero
        ? 0.0
        : widget.delay.inMilliseconds / total.inMilliseconds;
    _fade = CurvedAnimation(
      parent: _c,
      curve: Interval(start, 1.0, curve: PrimarMotion.enter),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, widget.offsetY * (1 - _fade.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// A ring that fills to [progress] — the dashboard "where am I" at a glance.
class PrimarProgressRing extends StatelessWidget {
  const PrimarProgressRing({
    super.key,
    required this.progress,
    this.size = 54,
    this.colour,
  });

  final double progress;
  final double size;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final c = colour ?? const Color(0xFF2A9D8F);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0, 1)),
        duration: PrimarMotion.slow,
        curve: PrimarMotion.enter,
        builder: (context, value, _) => CustomPaint(
          painter: _RingPainter(value: value, colour: c),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.colour});

  final double value;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    final track = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(centre, r, track);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: r),
      -3.14159 / 2,
      6.28318 * value,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.colour != colour;
}
