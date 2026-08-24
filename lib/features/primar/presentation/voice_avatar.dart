import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/teaching_voice.dart';
import 'mascot.dart';
import 'primar_theme.dart';

/// A face for each voice.
///
/// The first version used a mortarboard for every teacher and a heart for the
/// parent — icons *about* the idea rather than pictures of the person. Three
/// teachers who differ only in a name underneath are three identical rows, and
/// a parent choosing between them is choosing between labels.
///
/// These are people. Different faces, different skin, different hair, so the
/// list reads as a row of humans a child might learn from — which is what it
/// is. The teacher voices are real Nigerian and Kenyan neural voices, and
/// drawing them as generic academia icons quietly threw that away.
///
/// Deliberately drawn rather than photographed: a photo implies a specific real
/// person who has consented to represent this, and none has.
class VoiceAvatar extends StatelessWidget {
  const VoiceAvatar({super.key, required this.voice, this.size = 46});

  final TeachingVoice voice;
  final double size;

  @override
  Widget build(BuildContext context) {
    // The guide is the mascot, not a person.
    if (voice.kind == VoiceKind.guide) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: Mate(mood: Mood.happy, size: size * 0.9)),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FacePainter(_lookFor(voice))),
    );
  }

  /// A stable look per voice id, so a family always sees the same face beside
  /// the same name.
  static _Look _lookFor(TeachingVoice v) => switch (v.id) {
        'teacher.ezinne' => const _Look(
            skin: Color(0xFF8D5524),
            hair: Color(0xFF2B2118),
            style: _Hair.wrap,
            top: Color(0xFFE07A5F),
          ),
        'teacher.abeo' => const _Look(
            skin: Color(0xFF6B4226),
            hair: Color(0xFF1F1A15),
            style: _Hair.short,
            top: Color(0xFF3D5A80),
          ),
        'teacher.asilia' => const _Look(
            skin: Color(0xFFA9714B),
            hair: Color(0xFF241C16),
            style: _Hair.braids,
            top: Color(0xFF2A9D8F),
          ),
        'teacher.denise' => const _Look(
            skin: Color(0xFFC68642),
            hair: Color(0xFF3B2C22),
            style: _Hair.short,
            top: Color(0xFF8B5CF6),
          ),
        // A parent. Deliberately the warmest of the set.
        _ => const _Look(
            skin: Color(0xFF7A4B28),
            hair: Color(0xFF241A12),
            style: _Hair.wrap,
            top: Color(0xFFF4A261),
          ),
      };
}

enum _Hair { short, wrap, braids }

class _Look {
  const _Look({
    required this.skin,
    required this.hair,
    required this.style,
    required this.top,
  });

  final Color skin;
  final Color hair;
  final _Hair style;

  /// Shoulders, so each face reads as a different person at a glance even
  /// before you look at the features.
  final Color top;
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.look);

  final _Look look;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);

    canvas.clipRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100), const Radius.circular(50)));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100),
        Paint()..color = PrimarTheme.tintBlue);

    // Shoulders.
    final shoulders = Path()
      ..moveTo(10, 100)
      ..quadraticBezierTo(20, 74, 50, 74)
      ..quadraticBezierTo(80, 74, 90, 100)
      ..close();
    canvas.drawPath(shoulders, Paint()..color = look.top);

    // Neck.
    canvas.drawRect(const Rect.fromLTWH(42, 62, 16, 16), Paint()..color = look.skin);

    // Head.
    final head = Rect.fromCenter(center: const Offset(50, 46), width: 46, height: 54);
    canvas.drawOval(head, Paint()..color = look.skin);

    // Hair, which is most of what distinguishes one person from another here.
    final hair = Paint()..color = look.hair;
    switch (look.style) {
      case _Hair.short:
        canvas.drawArc(
            Rect.fromCenter(center: const Offset(50, 44), width: 50, height: 52),
            pi, pi, true, hair);

      case _Hair.wrap:
        // A headwrap, which is both common and instantly readable at 46px.
        final wrap = Path()
          ..moveTo(26, 34)
          ..quadraticBezierTo(50, 8, 74, 34)
          ..quadraticBezierTo(62, 24, 50, 26)
          ..quadraticBezierTo(38, 24, 26, 34)
          ..close();
        canvas.drawPath(wrap, Paint()..color = look.top);
        canvas.drawArc(
            Rect.fromCenter(center: const Offset(50, 40), width: 50, height: 44),
            pi, pi, true, Paint()..color = look.top);
        // A knot at the side.
        canvas.drawCircle(const Offset(74, 30), 7, Paint()..color = look.top);

      case _Hair.braids:
        canvas.drawArc(
            Rect.fromCenter(center: const Offset(50, 42), width: 50, height: 48),
            pi, pi, true, hair);
        for (final dx in [-1.0, 1.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(50 + dx * 26 - 5, 38, 10, 34),
              const Radius.circular(5),
            ),
            hair,
          );
        }
    }

    // Face. Two dots and a curve is all that survives at this size, and it is
    // enough — a smile is what makes a face look like it wants to help.
    canvas.drawCircle(const Offset(42, 46), 2.8, Paint()..color = PrimarTheme.navy);
    canvas.drawCircle(const Offset(58, 46), 2.8, Paint()..color = PrimarTheme.navy);
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(50, 52), width: 18, height: 14),
      0.35,
      2.44,
      false,
      Paint()
        ..color = PrimarTheme.navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) => old.look != look;
}
