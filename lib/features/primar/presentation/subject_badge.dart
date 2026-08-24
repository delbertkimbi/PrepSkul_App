import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/subjects.dart';
import 'primar_theme.dart';

/// The picture on a subject card.
///
/// The first version drew a single grey figure — a thin outline of a shape, a
/// pale ten-frame, a typed letter — and all three read as the same monochrome
/// glyph. A parent scanning the screen could not tell them apart at a glance,
/// and a child could not tell them apart at all.
///
/// Each subject now gets its own colour, its own arrangement and its own
/// silhouette, so the three are distinguishable before any word is read. That
/// is not decoration: this screen is the only place the whole product is
/// chosen from, and the labels underneath are useless to a parent who does not
/// read either.
class SubjectBadge extends StatelessWidget {
  const SubjectBadge({
    super.key,
    required this.subject,
    required this.selected,
    this.size = 62,
  });

  final Subject subject;
  final bool selected;
  final double size;

  static const _tints = {
    Subject.shapes: PrimarTheme.purple,
    Subject.numeracy: PrimarTheme.teal,
    Subject.reading: PrimarTheme.brick,
  };

  Color get tint => _tints[subject]!;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BadgePainter(
          subject: subject,
          tint: tint,
          // Unselected cards drain toward grey rather than vanishing, so the
          // chosen one is obvious without the others becoming invisible.
          strength: selected ? 1.0 : 0.42,
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter({required this.subject, required this.tint, required this.strength});

  final Subject subject;
  final Color tint;
  final double strength;

  Color _c(Color base) =>
      Color.lerp(const Color(0xFFAEB6C8), base, strength)!;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);

    // A soft rounded ground so each badge reads as an object, not a floating
    // mark on paper.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 6, 92, 88),
        const Radius.circular(26),
      ),
      Paint()..color = _c(tint).withValues(alpha: 0.13),
    );

    switch (subject) {
      case Subject.shapes:
        _shapes(canvas);
      case Subject.numeracy:
        _numbers(canvas);
      case Subject.reading:
        _letters(canvas);
    }

    canvas.restore();
  }

  /// Three overlapping cut-outs — a circle, a square and a triangle, in three
  /// colours. Composition is the subject, so the badge shows parts combining.
  void _shapes(Canvas canvas) {
    canvas.drawCircle(const Offset(38, 44), 20, Paint()..color = _c(PrimarTheme.purple));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(44, 36, 34, 34),
        const Radius.circular(7),
      ),
      Paint()..color = _c(PrimarTheme.yellow).withValues(alpha: 0.92),
    );
    final tri = Path()
      ..moveTo(50, 20)
      ..lineTo(70, 54)
      ..lineTo(30, 54)
      ..close();
    canvas.drawPath(tri, Paint()..color = _c(PrimarTheme.teal).withValues(alpha: 0.85));

    canvas.drawCircle(
      const Offset(38, 44),
      20,
      Paint()
        ..color = _c(PrimarTheme.navy)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2,
    );
  }

  /// Counting beads on a string — five filled, two empty. Reads as quantity
  /// from across a room, which a pale grid never did.
  void _numbers(Canvas canvas) {
    final line = Paint()
      ..color = _c(PrimarTheme.navy).withValues(alpha: 0.45)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    for (var row = 0; row < 2; row++) {
      final y = 38.0 + row * 26;
      canvas.drawLine(Offset(18, y), const Offset(82, 0).translate(0, y), line);

      for (var i = 0; i < 4; i++) {
        final x = 24.0 + i * 17;
        final filled = row == 0 ? i < 4 : i < 1;
        final c = row == 0 ? PrimarTheme.teal : PrimarTheme.brick;
        canvas.drawCircle(
          Offset(x, y),
          7.5,
          Paint()..color = filled ? _c(c) : _c(c).withValues(alpha: 0.18),
        );
        if (filled) {
          canvas.drawCircle(
            Offset(x - 2, y - 2.4),
            2.2,
            Paint()..color = Colors.white.withValues(alpha: 0.55 * strength),
          );
        }
      }
    }
  }

  /// Three letter tiles, tilted like scattered blocks, each its own colour.
  void _letters(Canvas canvas) {
    const tiles = [
      ('a', -0.16, Offset(30, 44), PrimarTheme.brick),
      ('b', 0.10, Offset(52, 36), PrimarTheme.blue),
      ('c', -0.05, Offset(66, 56), PrimarTheme.teal),
    ];

    for (final (glyph, angle, at, colour) in tiles) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(angle);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-16, -16, 32, 32),
          const Radius.circular(8),
        ),
        Paint()..color = _c(colour),
      );

      final painter = TextPainter(
        text: TextSpan(
          text: glyph,
          style: PrimarTheme.display(21, color: Colors.white, weight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BadgePainter old) =>
      old.subject != subject || old.strength != strength;
}

/// A small confetti-free celebration that fires on every correct answer.
///
/// The tick was previously only a colour change on the tile, which is easy to
/// miss on a bright screen. A child needs to *see* that they were right, not
/// infer it.
class CorrectBurst extends StatelessWidget {
  const CorrectBurst({super.key, required this.progress, this.size = 96});

  /// 0 at the moment of answering, running to 1.
  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return const SizedBox.shrink();
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _BurstPainter(progress)),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final eased = Curves.easeOutCubic.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);

    // An expanding ring.
    canvas.drawCircle(
      c,
      size.width * 0.28 + size.width * 0.34 * eased,
      Paint()
        ..color = PrimarTheme.teal.withValues(alpha: 0.5 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * fade,
    );

    // Rays flying outward.
    final ray = Paint()
      ..color = PrimarTheme.yellow.withValues(alpha: fade)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + eased * 0.3;
      final r0 = size.width * (0.30 + 0.22 * eased);
      final r1 = r0 + size.width * 0.12 * (1 - eased * 0.4);
      canvas.drawLine(
        Offset(c.dx + r0 * cos(a), c.dy + r0 * sin(a)),
        Offset(c.dx + r1 * cos(a), c.dy + r1 * sin(a)),
        ray,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}
