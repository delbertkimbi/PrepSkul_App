import 'dart:math';

import 'package:flutter/material.dart';

import 'primar_theme.dart';

/// The paper-craft vocabulary, read off the Summer Build Camp posters.
///
/// Torn edges, tape at an angle, a paperclip, marker doodles, a highlighter
/// swipe. What makes the look work is that nothing sits perfectly straight and
/// every layer casts a hard, opaque shadow — it reads as physical objects on a
/// desk rather than boxes on a screen.
///
/// These belong on the surfaces a parent reads. The child's working screen
/// stays deliberately quiet: a doodle beside a question competes with the
/// question, and the child is the one being measured.

/// A torn paper edge. Jagged along one side, flat along the rest.
class TornEdge extends StatelessWidget {
  const TornEdge({
    super.key,
    this.height = 18,
    this.color = PrimarTheme.sheet,
    this.flip = false,
    this.seed = 7,
  });

  final double height;
  final Color color;
  final bool flip;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _TornPainter(color: color, flip: flip, seed: seed)),
    );
  }
}

class _TornPainter extends CustomPainter {
  _TornPainter({required this.color, required this.flip, required this.seed});

  final Color color;
  final bool flip;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final path = Path();
    const steps = 22;
    final step = size.width / steps;

    if (flip) {
      path.moveTo(0, size.height);
      for (var i = 0; i <= steps; i++) {
        final y = size.height - (0.15 + rng.nextDouble() * 0.85) * size.height;
        path.lineTo(i * step, y);
      }
      path.lineTo(size.width, 0);
      path.lineTo(0, 0);
    } else {
      path.moveTo(0, 0);
      for (var i = 0; i <= steps; i++) {
        final y = (0.15 + rng.nextDouble() * 0.85) * size.height;
        path.lineTo(i * step, y);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TornPainter old) => old.color != color || old.flip != flip;
}

/// A strip of washi tape. Kraft, blue or purple, always slightly off-square.
class TapeStrip extends StatelessWidget {
  const TapeStrip({
    super.key,
    this.width = 84,
    this.height = 24,
    this.tone = TapeTone.blue,
    this.angle = -0.035,
  });

  final double width;
  final double height;
  final TapeTone tone;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      TapeTone.blue => const Color(0xFF638BE0).withValues(alpha: 0.7),
      TapeTone.kraft => const Color(0xFFE8D6AE).withValues(alpha: 0.85),
      TapeTone.purple => PrimarTheme.purple.withValues(alpha: 0.62),
      TapeTone.yellow => const Color(0xFFF4C742).withValues(alpha: 0.78),
    };

    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          boxShadow: const [BoxShadow(color: Color(0x1A132D63), blurRadius: 3, offset: Offset(0, 2))],
        ),
      ),
    );
  }
}

enum TapeTone { blue, kraft, purple, yellow }

/// A highlighter swipe behind a word. Drawn slightly taller and wider than the
/// text, and slightly crooked, the way a real marker lands.
class Highlighted extends StatelessWidget {
  const Highlighted({
    super.key,
    required this.child,
    this.color = PrimarTheme.yellow,
    this.angle = -0.014,
  });

  final Widget child;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Transform.rotate(
            angle: angle,
            child: FractionallySizedBox(
              widthFactor: 1.06,
              heightFactor: 0.62,
              alignment: Alignment.bottomCenter,
              child: Container(color: color.withValues(alpha: 0.75)),
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child),
      ],
    );
  }
}

/// Small marker doodles. Deliberately loose — a perfect star reads as clip art.
enum DoodleKind { sparkle, star, arrow, swirl, burst }

class Doodle extends StatelessWidget {
  const Doodle({
    super.key,
    required this.kind,
    this.size = 26,
    this.color = PrimarTheme.blue,
    this.angle = 0,
  });

  final DoodleKind kind;
  final double size;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _DoodlePainter(kind: kind, color: color)),
        ),
      );
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter({required this.kind, required this.color});

  final DoodleKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 40;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (kind) {
      case DoodleKind.sparkle:
        canvas.drawLine(Offset(20 * s, 6 * s), Offset(20 * s, 34 * s), paint);
        canvas.drawLine(Offset(6 * s, 20 * s), Offset(34 * s, 20 * s), paint);
        canvas.drawLine(Offset(11 * s, 11 * s), Offset(29 * s, 29 * s), paint..strokeWidth = 2.4 * s);
        canvas.drawLine(Offset(29 * s, 11 * s), Offset(11 * s, 29 * s), paint);

      case DoodleKind.star:
        final path = Path();
        for (var i = 0; i < 5; i++) {
          final outer = -pi / 2 + i * 2 * pi / 5;
          final inner = outer + pi / 5;
          final po = Offset(20 * s + 15 * s * cos(outer), 20 * s + 15 * s * sin(outer));
          final pi2 = Offset(20 * s + 6.5 * s * cos(inner), 20 * s + 6.5 * s * sin(inner));
          if (i == 0) {
            path.moveTo(po.dx, po.dy);
          } else {
            path.lineTo(po.dx, po.dy);
          }
          path.lineTo(pi2.dx, pi2.dy);
        }
        path.close();
        canvas.drawPath(path, paint);

      case DoodleKind.arrow:
        final path = Path()
          ..moveTo(6 * s, 28 * s)
          ..cubicTo(14 * s, 8 * s, 26 * s, 8 * s, 33 * s, 20 * s);
        canvas.drawPath(path, paint);
        canvas.drawLine(Offset(33 * s, 20 * s), Offset(26 * s, 17 * s), paint);
        canvas.drawLine(Offset(33 * s, 20 * s), Offset(31 * s, 12 * s), paint);

      case DoodleKind.swirl:
        final path = Path()..moveTo(8 * s, 30 * s);
        path.cubicTo(4 * s, 18 * s, 18 * s, 8 * s, 26 * s, 16 * s);
        path.cubicTo(31 * s, 21 * s, 24 * s, 28 * s, 20 * s, 23 * s);
        canvas.drawPath(path, paint);

      case DoodleKind.burst:
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3 - pi / 2;
          canvas.drawLine(
            Offset(20 * s + 8 * s * cos(a), 20 * s + 8 * s * sin(a)),
            Offset(20 * s + 16 * s * cos(a), 20 * s + 16 * s * sin(a)),
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) => old.kind != kind || old.color != color;
}

/// A paperclip hooked over the top edge of a sheet.
class Paperclip extends StatelessWidget {
  const Paperclip({super.key, this.size = 40, this.color = const Color(0xFF7B8AA8)});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size * 0.55,
        height: size,
        child: CustomPaint(painter: _ClipPainter(color: color)),
      );
}

class _ClipPainter extends CustomPainter {
  _ClipPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.16
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final path = Path()
      ..moveTo(w * 0.28, h * 0.86)
      ..lineTo(w * 0.28, h * 0.22)
      ..arcToPoint(Offset(w * 0.76, h * 0.22), radius: Radius.circular(w * 0.24))
      ..lineTo(w * 0.76, h * 0.7)
      ..arcToPoint(Offset(w * 0.5, h * 0.7), radius: Radius.circular(w * 0.14), clockwise: false)
      ..lineTo(w * 0.5, h * 0.34);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ClipPainter old) => old.color != color;
}

/// A wordmark where each word carries its own colour, as on the posters.
class ColorWordmark extends StatelessWidget {
  const ColorWordmark({super.key, required this.words, required this.size, this.angle = -0.012});

  final List<(String, Color)> words;
  final double size;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: size * 0.28,
        children: [
          for (final (word, color) in words)
            Text(word, style: PrimarTheme.display(size, color: color, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
