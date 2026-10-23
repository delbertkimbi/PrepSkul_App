import 'package:flutter/material.dart';
import 'learner_design.dart';

enum PrepSkulGlyph {
  rating,
  message,
  price,
  home,
  tutors,
  mate,
  sessions,
  learn,
  practice,
  voice,
  offline,
  streak,
  tutorRequest,
  requests,
}

/// Original paper-cut glyphs. Vector geometry stays crisp at every size.
/// Labels belong to the surrounding control, rather than the decorative art.
class PrepSkulIcon extends StatelessWidget {
  const PrepSkulIcon(
    this.glyph, {
    super.key,
    this.size = 28,
    this.active = true,
  });
  final PrepSkulGlyph glyph;
  final double size;
  final bool active;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _PaperGlyph(glyph, active)),
      ),
    ),
  );
}

class _PaperGlyph extends CustomPainter {
  const _PaperGlyph(this.glyph, this.active);
  final PrepSkulGlyph glyph;
  final bool active;
  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 32, size.height / 32);
    final ink = active ? LearnerDesign.ink : LearnerDesign.muted;
    final blue = active ? const Color(0xFF72C8F4) : const Color(0xFFDDE5EE);
    final yellow = active ? const Color(0xFFFFD335) : const Color(0xFFE5E9EF);
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void sheet(Path p, Color color) {
      c.save();
      c.translate(0, 1.6);
      c.drawPath(p, Paint()..color = ink.withValues(alpha: .15));
      c.restore();
      c.drawPath(p, Paint()..color = color);
      c.drawPath(p, stroke);
    }

    Path box(double x, double y, double w, double h, double r) => Path()
      ..addRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
      );
    void line(double x, double y, double a, double b) =>
        c.drawLine(Offset(x, y), Offset(a, b), stroke);
    switch (glyph) {
      case PrepSkulGlyph.rating:
        sheet(
          Path()
            ..moveTo(16, 3)
            ..lineTo(20, 11)
            ..lineTo(29, 12)
            ..lineTo(23, 19)
            ..lineTo(25, 28)
            ..lineTo(16, 24)
            ..lineTo(7, 28)
            ..lineTo(9, 19)
            ..lineTo(3, 12)
            ..lineTo(12, 11)
            ..close(),
          yellow,
        );
        break;
      case PrepSkulGlyph.message:
        sheet(
          Path()
            ..moveTo(4, 5)
            ..lineTo(28, 5)
            ..lineTo(28, 23)
            ..lineTo(13, 23)
            ..lineTo(5, 29)
            ..lineTo(5, 23)
            ..lineTo(4, 23)
            ..close(),
          blue,
        );
        line(10, 12, 23, 12);
        line(10, 17, 19, 17);
        c.drawCircle(const Offset(27, 5), 4, Paint()..color = yellow);
        break;
      case PrepSkulGlyph.price:
        sheet(box(3, 7, 26, 19, 4), Colors.white);
        sheet(Path()..addOval(const Rect.fromLTWH(10, 8, 13, 17)), yellow);
        line(6, 14, 8, 14);
        line(25, 19, 27, 19);
        line(16, 12, 16, 22);
        line(13, 15, 19, 15);
        break;
      case PrepSkulGlyph.tutorRequest:
        sheet(box(4, 6, 21, 20, 4), Colors.white);
        sheet(box(9, 3, 11, 6, 2), blue);
        line(9, 14, 17, 14);
        line(9, 19, 14, 19);
        sheet(Path()..addOval(const Rect.fromLTWH(18, 18, 12, 12)), yellow);
        line(21, 24, 27, 24);
        line(24, 21, 24, 27);
        break;
      case PrepSkulGlyph.requests:
        sheet(box(5, 4, 22, 25, 3), Colors.white);
        sheet(box(9, 2, 14, 6, 2), blue);
        line(10, 13, 22, 13);
        line(10, 18, 17, 18);
        line(12, 23, 15, 26);
        line(15, 26, 22, 20);
        break;
      case PrepSkulGlyph.home:
        sheet(
          Path()
            ..moveTo(6, 14)
            ..lineTo(16, 6)
            ..lineTo(26, 14)
            ..lineTo(26, 27)
            ..lineTo(6, 27)
            ..close(),
          Colors.white,
        );
        sheet(
          Path()
            ..moveTo(3, 14)
            ..lineTo(16, 3)
            ..lineTo(29, 14)
            ..lineTo(26, 17)
            ..lineTo(16, 9)
            ..lineTo(6, 17)
            ..close(),
          blue,
        );
        sheet(box(13, 19, 6, 8, 1), yellow);
        break;
      case PrepSkulGlyph.tutors:
        sheet(box(13, 4, 16, 15, 4), blue);
        line(18, 9, 24, 9);
        line(18, 13, 22, 13);
        sheet(Path()..addOval(const Rect.fromLTWH(4, 8, 10, 10)), yellow);
        sheet(
          Path()
            ..moveTo(2, 28)
            ..lineTo(2, 25)
            ..cubicTo(2, 17, 18, 17, 18, 25)
            ..lineTo(18, 28)
            ..close(),
          Colors.white,
        );
        line(21, 22, 27, 22);
        line(24, 19, 24, 25);
        break;
      case PrepSkulGlyph.mate:
        line(16, 7, 17, 3);
        c.drawCircle(const Offset(17, 3), 2.4, Paint()..color = yellow);
        sheet(box(4, 7, 24, 21, 10), blue);
        for (final x in [11.0, 21.0]) {
          c.drawOval(
            Rect.fromCenter(center: Offset(x, 16), width: 7, height: 9),
            Paint()..color = Colors.white,
          );
          c.drawCircle(Offset(x + .5, 16), 1.8, Paint()..color = ink);
        }
        c.drawPath(
          Path()
            ..moveTo(12, 23)
            ..quadraticBezierTo(16, 26, 20, 23),
          stroke,
        );
        break;
      case PrepSkulGlyph.sessions:
        sheet(box(4, 6, 24, 23, 4), Colors.white);
        sheet(box(4, 6, 24, 8, 3), blue);
        line(10, 3, 10, 9);
        line(22, 3, 22, 9);
        sheet(Path()..addOval(const Rect.fromLTWH(12, 17, 12, 12)), yellow);
        line(15, 23, 18, 25);
        line(18, 25, 22, 20);
        break;
      case PrepSkulGlyph.learn:
        sheet(
          Path()
            ..moveTo(3, 6)
            ..quadraticBezierTo(9, 4, 16, 8)
            ..lineTo(16, 28)
            ..quadraticBezierTo(9, 24, 3, 26)
            ..close(),
          Colors.white,
        );
        sheet(
          Path()
            ..moveTo(16, 8)
            ..quadraticBezierTo(23, 4, 29, 6)
            ..lineTo(29, 26)
            ..quadraticBezierTo(23, 24, 16, 28)
            ..close(),
          blue,
        );
        line(7, 12, 12, 13);
        line(7, 17, 12, 18);
        line(21, 12, 25, 11);
        break;
      case PrepSkulGlyph.practice:
        sheet(box(5, 4, 21, 25, 3), Colors.white);
        sheet(box(10, 2, 11, 5, 2), blue);
        line(9, 13, 11, 15);
        line(11, 15, 15, 11);
        line(18, 13, 22, 13);
        line(9, 22, 11, 24);
        line(11, 24, 15, 20);
        line(18, 22, 22, 22);
        break;
      case PrepSkulGlyph.voice:
        sheet(box(11, 3, 10, 18, 5), blue);
        c.drawPath(
          Path()
            ..moveTo(6, 15)
            ..cubicTo(6, 29, 26, 29, 26, 15),
          stroke,
        );
        line(16, 26, 16, 30);
        line(12, 30, 20, 30);
        break;
      case PrepSkulGlyph.streak:
        sheet(
          Path()
            ..moveTo(17, 2)
            ..cubicTo(19, 10, 28, 12, 27, 21)
            ..cubicTo(26, 33, 5, 33, 5, 21)
            ..cubicTo(4, 15, 11, 11, 11, 7)
            ..lineTo(14, 13)
            ..quadraticBezierTo(18, 8, 17, 2)
            ..close(),
          yellow,
        );
        sheet(
          Path()
            ..moveTo(16, 16)
            ..quadraticBezierTo(24, 25, 16, 28)
            ..quadraticBezierTo(8, 25, 16, 16)
            ..close(),
          blue,
        );
        break;
      case PrepSkulGlyph.offline:
        sheet(box(5, 3, 22, 26, 4), Colors.white);
        line(10, 8, 22, 8);
        line(16, 12, 16, 22);
        line(11, 18, 16, 23);
        line(16, 23, 21, 18);
        c.drawCircle(const Offset(26, 26), 5, Paint()..color = yellow);
        line(23, 26, 25, 28);
        line(25, 28, 29, 23);
        break;
    }
  }

  @override
  bool shouldRepaint(_PaperGlyph old) =>
      old.glyph != glyph || old.active != active;
}
