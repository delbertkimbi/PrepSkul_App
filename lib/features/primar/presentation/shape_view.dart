import 'package:flutter/material.dart';

import '../domain/strokes.dart';
import 'primar_theme.dart';

/// Renders a shape as hand-drawn strokes on the shared 100x100 grid.
///
/// Round caps and joins plus a heavy weight keep figures readable on a cheap
/// screen in daylight — the same reason the paper look uses hard shadows.
class ShapeView extends StatelessWidget {
  const ShapeView({
    super.key,
    required this.shape,
    this.color = PrimarTheme.questionInk,
    this.size = 68,
    this.strokeWidth,
  });

  final Shape shape;
  final Color color;
  final double size;

  /// Screen-pixel stroke weight. Left null it scales with [size], because a
  /// fixed weight that reads well at 80px merges into a solid blob at 32px.
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShapePainter(
          shape: shape,
          color: color,
          strokeWidth: strokeWidth ?? size * 0.075,
        ),
        isComplex: false,
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter({required this.shape, required this.color, required this.strokeWidth});

  final Shape shape;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (final id in shape) {
      canvas.drawPath(strokes[id]!.build(), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShapePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || !shapesEqual(old.shape, shape);
}

/// The + and − signs, drawn as strokes so nothing on a child's screen is type.
class OperatorGlyph extends StatelessWidget {
  const OperatorGlyph({super.key, required this.isAdd, this.size = 22});

  final bool isAdd;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GlyphPainter(isAdd ? _Glyph.plus : _Glyph.minus)),
      );
}

/// The equals sign, same reasoning.
class EqualsGlyph extends StatelessWidget {
  const EqualsGlyph({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GlyphPainter(_Glyph.equals)),
      );
}

enum _Glyph { plus, minus, equals }

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph);

  final _Glyph glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 40;
    final paint = Paint()
      ..color = PrimarTheme.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    switch (glyph) {
      case _Glyph.plus:
        canvas.drawLine(Offset(8 * s, 20 * s), Offset(32 * s, 20 * s), paint);
        canvas.drawLine(Offset(20 * s, 8 * s), Offset(20 * s, 32 * s), paint);
      case _Glyph.minus:
        canvas.drawLine(Offset(8 * s, 20 * s), Offset(32 * s, 20 * s), paint);
      case _Glyph.equals:
        canvas.drawLine(Offset(9 * s, 14 * s), Offset(31 * s, 14 * s), paint);
        canvas.drawLine(Offset(9 * s, 26 * s), Offset(31 * s, 26 * s), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) => old.glyph != glyph;
}

/// An empty slot where the answer belongs.
class MysterySlot extends StatelessWidget {
  const MysterySlot({super.key, this.size = 68});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _SlotPainter()),
      );
}

class _SlotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final paint = Paint()
      ..color = PrimarTheme.navy.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * s
      ..strokeCap = StrokeCap.round;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(14 * s, 14 * s, 72 * s, 72 * s),
      Radius.circular(14 * s),
    );

    // Dashed outline, walked manually so it stays crisp at any size.
    final path = Path()..addRRect(rect);
    const dash = 9.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash * s).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dash * s;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SlotPainter oldDelegate) => false;
}
