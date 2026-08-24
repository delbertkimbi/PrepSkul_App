import 'dart:math';

import 'package:flutter/material.dart';

import 'primar_theme.dart';

/// Pictures for the onboarding answers.
///
/// Every option a parent picks from is drawn, not written. Two reasons, and
/// the second is the important one:
///
/// 1. A parent who cannot read cannot answer a written questionnaire, and this
///    product is aimed squarely at families where that is true. The voice reads
///    the question; the picture has to carry the answers.
/// 2. A drawn option is answered faster and more honestly than a written one.
///    "They know most letters" invites a parent to round up. Three letters next
///    to a whole word is a comparison, and a comparison is harder to flatter.
///
/// ## The rule these are drawn to
///
/// **The thing that tells two options apart has to be the biggest thing in the
/// picture.** The first cut of these got that backwards: the school options
/// differed only by how many 5px dots were filled in under a roof that was
/// identical in all three, and at the size they actually render, all three read
/// as the same icon. Whatever distinguishes an option is now the composition,
/// not a detail inside it.
///
/// Numerals and `+ = ?` do a lot of the work here on purpose. They are the one
/// written language that reaches a parent who does not read words.
///
/// Drawn rather than generated, for the same reason as `WordPicture`: a model
/// asked for "a child reading" returns something different every time, weighs
/// hundreds of kilobytes, and needs a network. These are a few hundred bytes
/// and identical on every device from first launch.
enum ArtKind {
  // How much school this year.
  schoolNone,
  schoolPatchy,
  schoolDaily,

  // Letters, in the order a child actually acquires them.
  readingNone,
  readingFew,
  readingMost,
  readingWords,

  // Numbers.
  numbersNone,
  numbersTen,
  numbersTwenty,
  numbersAdd,

  // Shapes.
  shapesNone,
  shapesSame,
  shapesFit,
  shapesMissing,
}

class ChoiceArt extends StatelessWidget {
  const ChoiceArt({super.key, required this.kind, this.size = 56});

  final ArtKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ArtPainter(kind)),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.kind);

  final ArtKind kind;

  static const _navy = PrimarTheme.navy;
  static const _blue = PrimarTheme.blue;
  static const _teal = PrimarTheme.teal;
  static const _yellow = PrimarTheme.yellow;
  static const _brick = PrimarTheme.brick;
  static const _mango = Color(0xFFE79A2B);
  static const _empty = Color(0xFFDCE1EA);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100);

    // Unselected options are *not* dimmed. Selection is already signalled four
    // ways by the card around this — border, fill, lift and a tick — and
    // draining the colour out of the picture on top of that made every
    // unselected option hard to tell apart, which is the one thing a parent
    // scanning a list of four must be able to do.
    final line = Paint()
      ..color = _navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      // ---- School. The days are the picture; the roof is the label. -------
      case ArtKind.schoolNone:
        _school(canvas, line, 0);
      case ArtKind.schoolPatchy:
        _school(canvas, line, 2);
      case ArtKind.schoolDaily:
        _school(canvas, line, 5);

      // ---- Letters. Each rung is visibly more writing than the last. ------
      case ArtKind.readingNone:
        // Not a blank page — marks that are not yet letters. A blank rectangle
        // says "nothing here"; a scribble says "they see marks, not letters",
        // which is the actual answer being offered.
        _page(canvas, line);
        final scribble = Paint()
          ..color = const Color(0xFFB4BCCB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 3; i++) {
          final y = 42.0 + i * 13;
          canvas.drawPath(
            Path()
              ..moveTo(30, y)
              ..quadraticBezierTo(42, y - 5, 52, y)
              ..quadraticBezierTo(62, y + 5, 70, y),
            scribble,
          );
        }
      case ArtKind.readingFew:
        _page(canvas, line);
        _glyph(canvas, 'a', const Offset(50, 55), 42, _brick);
      case ArtKind.readingMost:
        _page(canvas, line);
        _glyph(canvas, 'a', const Offset(32, 55), 30, _brick);
        _glyph(canvas, 'b', const Offset(50, 55), 30, _blue);
        _glyph(canvas, 'c', const Offset(68, 55), 30, _teal);
      case ArtKind.readingWords:
        _page(canvas, line);
        _glyph(canvas, 'bus', const Offset(50, 51), 30, _navy);
        // The sweep of a finger along a word being decoded. The gesture is the
        // point, not the decoration.
        canvas.drawLine(
          const Offset(28, 70),
          const Offset(72, 70),
          Paint()
            ..color = _yellow
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round,
        );

      // ---- Numbers. The numeral is the hero, because a numeral is the one
      // ---- piece of writing that reaches a parent who does not read words.
      case ArtKind.numbersNone:
        // Loose things, uncounted, and nothing naming how many.
        for (final at in const [Offset(30, 40), Offset(58, 32), Offset(44, 62), Offset(70, 58)]) {
          canvas.drawCircle(at, 11, Paint()..color = _mango);
          canvas.drawCircle(at, 11, line);
        }
      case ArtKind.numbersTen:
        _glyph(canvas, '10', const Offset(50, 38), 46, _blue);
        _dotRow(canvas, 5, 78);
      case ArtKind.numbersTwenty:
        _glyph(canvas, '20', const Offset(50, 34), 46, _teal);
        _dotRow(canvas, 5, 70);
        _dotRow(canvas, 5, 86);
      case ArtKind.numbersAdd:
        _glyph(canvas, '2+1', const Offset(50, 50), 44, _navy);

      // ---- Shapes. A symbol between the two shapes names the relationship. -
      case ArtKind.shapesNone:
        // Two unrelated shapes, sitting apart.
        _tri(canvas, const Offset(30, 50), 22, _teal, line);
        _square(canvas, const Offset(70, 52), 32, _blue, line);
      case ArtKind.shapesSame:
        _tri(canvas, const Offset(26, 50), 21, _teal, line);
        _glyph(canvas, '=', const Offset(50, 50), 34, _brick);
        _tri(canvas, const Offset(74, 50), 21, _teal, line);
      case ArtKind.shapesFit:
        // Two halves already met. Drawn as one square with a seam rather than
        // as an equation: an equation needs a result after the equals sign,
        // and there is no room for one at this size.
        final joined = Rect.fromCenter(center: const Offset(50, 50), width: 52, height: 46);
        canvas.drawRect(
          Rect.fromLTWH(joined.left, joined.top, joined.width / 2, joined.height),
          Paint()..color = _teal.withValues(alpha: 0.9),
        );
        canvas.drawRect(
          Rect.fromLTWH(joined.center.dx, joined.top, joined.width / 2, joined.height),
          Paint()..color = _blue.withValues(alpha: 0.9),
        );
        canvas.drawRect(joined, line);
        canvas.drawLine(
          Offset(joined.center.dx, joined.top),
          Offset(joined.center.dx, joined.bottom),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 3.4,
        );
      case ArtKind.shapesMissing:
        final whole = Rect.fromCenter(center: const Offset(48, 50), width: 52, height: 46);
        canvas.drawRect(whole, Paint()..color = _teal.withValues(alpha: 0.32));
        canvas.drawRect(whole, line);
        final hole = Rect.fromLTWH(whole.center.dx, whole.top, whole.width / 2, whole.height);
        canvas.drawRect(hole, Paint()..color = PrimarTheme.sheet);
        _dashedRect(canvas, hole, _brick);
        _glyph(canvas, '?', hole.center, 32, _brick);
    }

    canvas.restore();
  }

  /// A roof, and a row of large day marks under it.
  ///
  /// The marks carry the whole answer, so they are drawn at the size of the
  /// building rather than as a footnote beneath it. Filled marks are days
  /// attended — not enrolment, which in this population is a different number.
  void _school(Canvas canvas, Paint line, int days) {
    final warm = days > 0;
    final roof = Path()
      ..moveTo(28, 36)
      ..lineTo(50, 18)
      ..lineTo(72, 36)
      ..close();
    canvas.drawPath(roof, Paint()..color = warm ? _brick : const Color(0xFFB6BECD));
    canvas.drawPath(roof, line);
    canvas.drawRect(const Rect.fromLTWH(34, 36, 32, 14),
        Paint()..color = warm ? _yellow : _empty);
    canvas.drawRect(const Rect.fromLTWH(34, 36, 32, 14), line);

    for (var i = 0; i < 5; i++) {
      // Radius and spacing are tied: at radius 10 and 15 apart the five days
      // overlapped into a single chain and stopped being countable, which is
      // the only thing they are there to be.
      final at = Offset(22 + i * 15.5, 76);
      final on = i < days;
      canvas.drawCircle(at, 7, Paint()..color = on ? _teal : _empty);
      canvas.drawCircle(at, 7, line..strokeWidth = 2.6);
      if (on) {
        // A tick inside, so "went" is legible even in one colour or in
        // bright sun where teal and grey stop being far apart.
        canvas.drawPath(
          Path()
            ..moveTo(at.dx - 3.2, at.dy)
            ..lineTo(at.dx - 0.7, at.dy + 2.8)
            ..lineTo(at.dx + 3.5, at.dy - 3.2),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
    line.strokeWidth = 3.4;
  }

  void _dotRow(Canvas canvas, int n, double y) {
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(24 + i * 13.0, y), 5, Paint()..color = _mango);
    }
  }

  void _page(Canvas canvas, Paint line) {
    final r = RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 22, 64, 62), const Radius.circular(6));
    canvas.drawRRect(r, Paint()..color = Colors.white);
    canvas.drawRRect(r, line);
  }

  void _tri(Canvas canvas, Offset at, double r, Color fill, Paint line) {
    final p = Path()
      ..moveTo(at.dx, at.dy - r)
      ..lineTo(at.dx + r * 0.95, at.dy + r * 0.72)
      ..lineTo(at.dx - r * 0.95, at.dy + r * 0.72)
      ..close();
    canvas.drawPath(p, Paint()..color = fill.withValues(alpha: 0.9));
    canvas.drawPath(p, line);
  }

  void _square(Canvas canvas, Offset at, double s, Color fill, Paint line) {
    final r = Rect.fromCenter(center: at, width: s, height: s);
    canvas.drawRect(r, Paint()..color = fill.withValues(alpha: 0.9));
    canvas.drawRect(r, line);
  }

  void _dashedRect(Canvas canvas, Rect r, Color colour) {
    final p = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;
    const dash = 5.0;
    for (var x = r.left; x < r.right; x += dash * 2) {
      canvas.drawLine(Offset(x, r.top), Offset(min(x + dash, r.right), r.top), p);
      canvas.drawLine(Offset(x, r.bottom), Offset(min(x + dash, r.right), r.bottom), p);
    }
    for (var y = r.top; y < r.bottom; y += dash * 2) {
      canvas.drawLine(Offset(r.left, y), Offset(r.left, min(y + dash, r.bottom)), p);
      canvas.drawLine(Offset(r.right, y), Offset(r.right, min(y + dash, r.bottom)), p);
    }
  }

  void _glyph(Canvas canvas, String text, Offset centre, double size, Color colour) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: PrimarTheme.display(size, color: colour, weight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, centre - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.kind != kind;
}
