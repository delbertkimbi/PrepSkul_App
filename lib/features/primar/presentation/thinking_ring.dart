import 'dart:math';

import 'package:flutter/material.dart';

import 'primar_theme.dart';

/// The thinking ring.
///
/// A coloured arc that drains while a child decides, from teal through amber.
/// It gives a question shape and momentum — there is a beginning and a middle,
/// and something is happening.
///
/// What it deliberately does NOT do is run out and mark them wrong.
///
/// A countdown that punishes is the wrong instrument for this child. They
/// already associate school with failing, and a timer that snatches the
/// question away teaches that thinking is dangerous. So the ring drains, and
/// when it empties Mate offers help — the pressure is a heartbeat, not a
/// guillotine. It never turns red, and it never ends a question.
class ThinkingRing extends StatelessWidget {
  const ThinkingRing({
    super.key,
    required this.progress,
    this.size = 34,
    this.stroke = 5,
  });

  /// 1.0 at the start of a question, falling toward 0.
  final double progress;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress: progress.clamp(0.0, 1.0), stroke: stroke),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.stroke});

  final double progress;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);

    canvas.drawArc(
      rect,
      0,
      2 * pi,
      false,
      Paint()
        ..color = PrimarTheme.navy.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (progress <= 0) return;

    // Teal while there is plenty of time, warming to amber as it drains.
    // Never red: red says failure, and nothing here has failed.
    final colour = Color.lerp(
      PrimarTheme.yellow,
      PrimarTheme.teal,
      Curves.easeOut.transform(progress),
    )!;

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.stroke != stroke;
}
