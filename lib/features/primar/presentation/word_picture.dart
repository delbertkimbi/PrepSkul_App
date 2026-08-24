import 'dart:math';

import 'package:flutter/material.dart';

import 'primar_theme.dart';

/// A picture for a word.
///
/// A child choosing between "leg", "log", "pen" and "bag" written bare is not
/// reading — they are matching shapes. Reading is decoding *and* meaning, and a
/// word with no picture beside it carries no meaning to a child who cannot yet
/// read it. So the rule is simple and absolute: **a word is only ever shown if
/// it can be pictured.**
///
/// These are drawn, not generated. A model asked for "a pot" returns something
/// different every time, and a child learning that these marks mean *this
/// thing* needs the thing to look the same on every encounter. Drawn icons are
/// also a few hundred bytes each, identical on every device, and present from
/// first launch with no network.
class WordPicture extends StatelessWidget {
  const WordPicture({super.key, required this.word, this.size = 72});

  final String word;
  final double size;

  /// Words this can draw. The reading item generator is restricted to these,
  /// so a word without a picture simply never reaches a child.
  static const Set<String> drawable = {
    'sun', 'cup', 'hat', 'bag', 'box', 'pot', 'bus', 'mat',
    'net', 'log', 'fan', 'bed', 'yam', 'pen', 'leg', 'van',
    // Added for initial-sound work, which needs a picture for as many starting
    // letters as possible: b, c, a, f, k, s.
    'ball', 'cat', 'apple', 'fish', 'key', 'star',
    // Cameroon. Things within arm's reach of the child using this.
    'mango', 'plantain', 'drum', 'hen', 'pan', 'tin',
    // The seven letters that had only one picture each, and so could not make
    // a letter card: a, d, k, n, t, v, y.
    'ant', 'dog', 'kite', 'nest', 'tap', 'vase', 'yoyo',
    // French-only pictures. The short decodable French list needs these and no
    // English word above happens to draw them.
    'lune', 'main',
    // Longer words, added so syllables can be taught at all.
    //
    // Counting beats needs words with more than one. The bank had about
    // thirty-two one-syllable words, four with two and none with three, so a
    // child answering "one" every time would have scored near ninety percent —
    // a rung that records mastery it never measured. These are three, three
    // and three, and all of them are within reach of a child in Buea.
    'banana', 'tomato', 'umbrella',
    // Cameroon / French — drawn here because no English word fits.
    'moto', 'arbre', 'gobelet', 'riz', 'eau', 'feu',
    // Short French decodable words that needed their own icon.
    'mot', 'roc', 'mer',
  };

  /// French words that reuse an English icon.
  ///
  /// A picture is language-neutral — a drawing of a bed is a drawing of a bed
  /// in any language — but the *key* is the English word, so a French item
  /// asking for "lit" would have found nothing and drawn the placeholder box.
  /// A word with a placeholder instead of a picture turns the reading rung
  /// back into shape-matching, which is the one thing that rung must not be.
  static const Map<String, String> _alias = {
    'lit': 'bed',
    'sac': 'bag',
    'tasse': 'cup',
    'natte': 'mat',
    'mangue': 'mango',
    // A drawing costs nothing to reuse, and the French bank was seven words
    // against thirty-five English — meaning every rung a Francophone child met
    // drew from a seventh of the material. These five needed no new artwork at
    // all; they were simply never pointed at the pictures already here.
    'chat': 'cat',
    'nid': 'nest',
    'tapis': 'mat',
    'poule': 'hen',
    'ballon': 'ball',
    'chien': 'dog',
    'poisson': 'fish',
    'soleil': 'sun',
    'chapeau': 'hat',
    'boite': 'box',
    'banane': 'banana',
    'tomate': 'tomato',
    'parapluie': 'umbrella',
    'tambour': 'drum',
    'stylo': 'pen',
    'etoile': 'star',
    'cle': 'key',
    'fourmi': 'ant',
    'pomme': 'apple',
    'jambe': 'leg',
    'ventilo': 'fan',
    'bol': 'cup',
    'fil': 'fish',
    'sol': 'sun',
    'rat': 'cat',
    'plat': 'mat',
    'pin': 'pen',
    'lot': 'box',
  };

  /// The drawing key for a word. Public because the word bank's tests hold the
  /// bank and the drawings to each other, and they have to agree on what
  /// "has a picture" means.
  static String keyFor(String w) {
    final lower = w.toLowerCase();
    return _alias[lower] ?? lower;
  }

  static bool canDraw(String w) => drawable.contains(keyFor(w));

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WordPainter(keyFor(word))),
    );
  }
}

class _WordPainter extends CustomPainter {
  _WordPainter(this.word);

  final String word;

  static const _brick = PrimarTheme.brick;
  static const _teal = PrimarTheme.teal;
  static const _blue = PrimarTheme.blue;
  static const _yellow = PrimarTheme.yellow;
  static const _navy = PrimarTheme.navy;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);

    // A soft shadow under everything, drawn first.
    //
    // The old icons were flat outlines on flat paper and read as clip art. One
    // blurred ellipse under each object is the whole difference between a
    // diagram of a thing and a picture of a thing sitting on a surface — and it
    // costs one draw call.
    canvas.drawOval(
      const Rect.fromLTWH(24, 78, 52, 14),
      Paint()
        ..color = _navy.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    final line = Paint()
      ..color = _navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (word) {
      case 'sun':
        canvas.drawCircle(const Offset(50, 50), 20, Paint()..color = _yellow);
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4;
          canvas.drawLine(
            Offset(50 + 27 * cos(a), 50 + 27 * sin(a)),
            Offset(50 + 36 * cos(a), 50 + 36 * sin(a)),
            Paint()
              ..color = _yellow
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round,
          );
        }
        canvas.drawCircle(const Offset(50, 50), 20, line);

      case 'cup':
        // The handle used to be an arc drawn beside the body, not joined to it
        // — it read as a cup next to a stray line. It now starts and ends on
        // the wall of the cup, which is the only thing that makes it a handle.
        final body = Path()
          ..moveTo(30, 34)
          ..lineTo(66, 34)
          ..lineTo(61, 76)
          ..lineTo(35, 76)
          ..close();
        final handle = Path()
          ..moveTo(66, 42)
          ..quadraticBezierTo(84, 44, 82, 56)
          ..quadraticBezierTo(80, 66, 63, 64);
        canvas.drawPath(handle, line..strokeWidth = 5);
        line.strokeWidth = 3.4;
        canvas.drawPath(body, Paint()..color = _blue);
        canvas.drawPath(body, line);
        // A little liquid, so it reads as a cup in use rather than an outline.
        canvas.drawOval(const Rect.fromLTWH(31, 30, 34, 9),
            Paint()..color = const Color(0xFF9AC2F5));
        canvas.drawOval(const Rect.fromLTWH(31, 30, 34, 9), line..strokeWidth = 2.4);
        line.strokeWidth = 3.4;

      case 'hat':
        canvas.drawArc(const Rect.fromLTWH(28, 26, 44, 48), pi, pi, false,
            Paint()..color = _brick);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(20, 48, 60, 10), const Radius.circular(5)),
          Paint()..color = _brick,
        );
        canvas.drawArc(const Rect.fromLTWH(28, 26, 44, 48), pi, pi, false, line);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(20, 48, 60, 10), const Radius.circular(5)),
          line,
        );

      case 'bag':
        final b = RRect.fromRectAndRadius(
            const Rect.fromLTWH(28, 42, 44, 40), const Radius.circular(6));
        canvas.drawRRect(b, Paint()..color = _teal);
        canvas.drawArc(const Rect.fromLTWH(38, 24, 24, 32), pi, pi, false, line);
        canvas.drawRRect(b, line);

      case 'box':
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(26, 40, 48, 40), const Radius.circular(4)),
          Paint()..color = const Color(0xFFC98A46),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(26, 40, 48, 40), const Radius.circular(4)),
          line,
        );
        canvas.drawLine(const Offset(50, 40), const Offset(50, 80), line);
        canvas.drawRect(const Rect.fromLTWH(26, 32, 48, 10), Paint()..color = _yellow);
        canvas.drawRect(const Rect.fromLTWH(26, 32, 48, 10), line);

      case 'pot':
        final p = RRect.fromRectAndRadius(
            const Rect.fromLTWH(30, 42, 40, 34), const Radius.circular(8));
        canvas.drawRRect(p, Paint()..color = _navy.withValues(alpha: 0.75));
        canvas.drawRRect(p, line);
        canvas.drawLine(const Offset(24, 42), const Offset(76, 42), line);
        canvas.drawCircle(const Offset(50, 34), 5, line);

      case 'bus':
        final b = RRect.fromRectAndRadius(
            const Rect.fromLTWH(18, 34, 64, 36), const Radius.circular(8));
        canvas.drawRRect(b, Paint()..color = _yellow);
        canvas.drawRRect(b, line);
        for (var i = 0; i < 3; i++) {
          canvas.drawRect(Rect.fromLTWH(24 + i * 18.0, 40, 12, 12),
              Paint()..color = Colors.white.withValues(alpha: 0.9));
        }
        canvas.drawCircle(const Offset(33, 72), 7, Paint()..color = _navy);
        canvas.drawCircle(const Offset(67, 72), 7, Paint()..color = _navy);

      case 'mat':
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(20, 40, 60, 34), const Radius.circular(4)),
          Paint()..color = const Color(0xFFD9A441),
        );
        for (var i = 1; i < 4; i++) {
          canvas.drawLine(Offset(20 + i * 15.0, 40), Offset(20 + i * 15.0, 74), line);
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(20, 40, 60, 34), const Radius.circular(4)),
          line,
        );

      case 'net':
        canvas.drawCircle(const Offset(50, 46), 22, Paint()..color = _teal.withValues(alpha: 0.25));
        for (var i = -2; i <= 2; i++) {
          canvas.drawLine(Offset(50 + i * 9.0, 26), Offset(50 + i * 9.0, 66), line..strokeWidth = 2);
          canvas.drawLine(Offset(30, 46 + i * 9.0), Offset(70, 46 + i * 9.0), line);
        }
        line.strokeWidth = 3.4;
        canvas.drawCircle(const Offset(50, 46), 22, line);
        canvas.drawLine(const Offset(50, 68), const Offset(50, 82), line);

      case 'log':
        // Was a thin rounded bar with one ring, which read as a battery. A log
        // is short, thick, and shows its cut end.
        final barrel = RRect.fromRectAndRadius(
            const Rect.fromLTWH(22, 34, 56, 40), const Radius.circular(14));
        canvas.drawRRect(barrel, Paint()..color = const Color(0xFF9A6B3F));
        canvas.drawRRect(barrel, line);
        // Bark, along the length.
        for (final y in [46.0, 56.0, 66.0]) {
          canvas.drawLine(Offset(46, y), Offset(72, y),
              Paint()
                ..color = const Color(0xFF6E4A28)
                ..strokeWidth = 2.2
                ..strokeCap = StrokeCap.round);
        }
        // The cut end, with rings — the thing that says "log" rather than "pipe".
        canvas.drawOval(const Rect.fromLTWH(22, 34, 26, 40),
            Paint()..color = const Color(0xFFC49060));
        canvas.drawOval(const Rect.fromLTWH(22, 34, 26, 40), line);
        canvas.drawOval(const Rect.fromLTWH(29, 45, 12, 18), line..strokeWidth = 2.2);
        canvas.drawOval(const Rect.fromLTWH(33, 51, 4, 6), line);
        line.strokeWidth = 3.4;

      case 'fan':
        // Was four rotated petals around a hub, which read as a flower — and a
        // child told that picture says "fan" learns the wrong word, which is
        // worse than being shown nothing. Now a guard cage on a stand, which is
        // what a standing fan looks like in any room that has one.
        canvas.drawCircle(const Offset(50, 42), 26, Paint()..color = const Color(0xFFDCE7F5));
        for (var i = 0; i < 3; i++) {
          canvas.save();
          canvas.translate(50, 42);
          canvas.rotate(i * 2 * pi / 3);
          final blade = Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(6, -20, 20, -14)
            ..quadraticBezierTo(14, -2, 0, 0)
            ..close();
          canvas.drawPath(blade, Paint()..color = _blue);
          canvas.drawPath(blade, line..strokeWidth = 2.2);
          canvas.restore();
        }
        line.strokeWidth = 3.4;
        canvas.drawCircle(const Offset(50, 42), 6, Paint()..color = _navy);
        canvas.drawCircle(const Offset(50, 42), 26, line);
        // Stand.
        canvas.drawLine(const Offset(50, 68), const Offset(50, 82), line);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(34, 80, 32, 7), const Radius.circular(3)),
          Paint()..color = _navy,
        );

      case 'bed':
        canvas.drawRect(const Rect.fromLTWH(22, 50, 56, 18), Paint()..color = _blue);
        canvas.drawRect(const Rect.fromLTWH(22, 50, 56, 18), line);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(26, 42, 20, 12), const Radius.circular(5)),
          Paint()..color = Colors.white,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(26, 42, 20, 12), const Radius.circular(5)),
          line,
        );
        canvas.drawLine(const Offset(22, 68), const Offset(22, 78), line);
        canvas.drawLine(const Offset(78, 68), const Offset(78, 78), line);

      case 'yam':
        final y = Path()
          ..moveTo(34, 74)
          ..quadraticBezierTo(24, 52, 42, 34)
          ..quadraticBezierTo(60, 18, 70, 34)
          ..quadraticBezierTo(78, 52, 58, 70)
          ..quadraticBezierTo(46, 80, 34, 74)
          ..close();
        canvas.drawPath(y, Paint()..color = const Color(0xFF9A6B3F));
        canvas.drawPath(y, line);

      case 'pen':
        canvas.save();
        canvas.translate(50, 50);
        canvas.rotate(-0.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -30, 12, 46), const Radius.circular(3)),
          Paint()..color = _blue,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -30, 12, 46), const Radius.circular(3)),
          line,
        );
        final nib = Path()
          ..moveTo(-6, 16)
          ..lineTo(0, 30)
          ..lineTo(6, 16)
          ..close();
        canvas.drawPath(nib, Paint()..color = _navy);
        canvas.restore();

      case 'leg':
        // Was a straight tapered shape that read as a sock or a boot. A leg is
        // legible only when it bends: thigh, knee, shin, then a foot turned to
        // the side.
        final limb = Path()
          ..moveTo(38, 20)
          ..lineTo(58, 20)
          ..quadraticBezierTo(62, 44, 56, 52)
          ..quadraticBezierTo(50, 62, 52, 74)
          ..lineTo(38, 74)
          ..quadraticBezierTo(36, 58, 42, 48)
          ..quadraticBezierTo(46, 40, 38, 20)
          ..close();
        canvas.drawPath(limb, Paint()..color = const Color(0xFFC98A5E));
        canvas.drawPath(limb, line);
        // The foot, pointing right, which is what settles it as a leg.
        final foot = Path()
          ..moveTo(36, 74)
          ..lineTo(70, 74)
          ..quadraticBezierTo(76, 76, 70, 82)
          ..lineTo(36, 82)
          ..close();
        canvas.drawPath(foot, Paint()..color = const Color(0xFFB2764C));
        canvas.drawPath(foot, line);
        // Knee.
        canvas.drawArc(const Rect.fromLTWH(40, 42, 16, 14), 3.6, 2.0, false,
            line..strokeWidth = 2.2);
        line.strokeWidth = 3.4;

      case 'van':
        final v = Path()
          ..moveTo(18, 68)
          ..lineTo(18, 46)
          ..lineTo(46, 46)
          ..lineTo(54, 32)
          ..lineTo(80, 32)
          ..lineTo(84, 68)
          ..close();
        canvas.drawPath(v, Paint()..color = _teal);
        canvas.drawPath(v, line);
        canvas.drawCircle(const Offset(34, 70), 7, Paint()..color = _navy);
        canvas.drawCircle(const Offset(70, 70), 7, Paint()..color = _navy);

      case 'mango':
        final body = Path()
          ..moveTo(46, 78)
          ..quadraticBezierTo(20, 62, 28, 40)
          ..quadraticBezierTo(38, 18, 62, 24)
          ..quadraticBezierTo(84, 32, 78, 56)
          ..quadraticBezierTo(72, 76, 46, 78)
          ..close();
        canvas.drawPath(body, Paint()..color = const Color(0xFFE79A2B));
        // The blush, which is what makes it a mango and not an egg.
        canvas.drawOval(const Rect.fromLTWH(30, 30, 30, 26),
            Paint()..color = const Color(0xFFD2582C).withValues(alpha: 0.75));
        canvas.drawPath(body, line);
        canvas.drawLine(const Offset(58, 25), const Offset(62, 12),
            Paint()
              ..color = const Color(0xFF6B4A2B)
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round);
        final leaf = Path()
          ..moveTo(62, 14)
          ..quadraticBezierTo(84, 6, 80, 22)
          ..quadraticBezierTo(70, 26, 62, 14)
          ..close();
        canvas.drawPath(leaf, Paint()..color = const Color(0xFF3E9B5F));
        canvas.drawPath(leaf, line..strokeWidth = 2.4);
        line.strokeWidth = 3.4;

      case 'plantain':
        // Three fingers on a hand, curved the way a bunch actually hangs.
        for (var i = 0; i < 3; i++) {
          final dx = i * 9.0;
          final f = Path()
            ..moveTo(20 + dx, 74)
            ..quadraticBezierTo(16 + dx, 44, 40 + dx, 26)
            ..quadraticBezierTo(50 + dx, 20, 54 + dx, 26)
            ..quadraticBezierTo(36 + dx, 42, 32 + dx, 76)
            ..close();
          canvas.drawPath(f, Paint()..color = const Color(0xFFD8C24A));
          canvas.drawPath(f, line);
        }
        canvas.drawLine(const Offset(58, 26), const Offset(70, 18),
            Paint()
              ..color = const Color(0xFF6B4A2B)
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round);

      case 'drum':
        final shell = Path()
          ..moveTo(28, 34)
          ..lineTo(72, 34)
          ..lineTo(64, 82)
          ..lineTo(36, 82)
          ..close();
        canvas.drawPath(shell, Paint()..color = const Color(0xFF9A6B3F));
        canvas.drawPath(shell, line);
        // Skin.
        canvas.drawOval(const Rect.fromLTWH(26, 26, 48, 16),
            Paint()..color = const Color(0xFFE8D6B8));
        canvas.drawOval(const Rect.fromLTWH(26, 26, 48, 16), line);
        // Lacing, which is what says djembe rather than bucket.
        for (var i = 0; i < 4; i++) {
          final x1 = 32 + i * 12.0;
          canvas.drawLine(Offset(x1, 40), Offset(x1 - 2, 74),
              Paint()
                ..color = const Color(0xFF6E4A28)
                ..strokeWidth = 2.2);
        }

      case 'hen':
        final body = Path()
          ..addOval(const Rect.fromLTWH(24, 40, 52, 38));
        canvas.drawPath(body, Paint()..color = PrimarTheme.brick);
        canvas.drawPath(body, line);
        // Head and neck.
        canvas.drawCircle(const Offset(68, 34), 13, Paint()..color = PrimarTheme.brick);
        canvas.drawCircle(const Offset(68, 34), 13, line);
        // Comb.
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(62 + i * 6.0, 20), 5, Paint()..color = _brick);
        }
        // Beak and eye.
        final beak = Path()
          ..moveTo(80, 32)
          ..lineTo(90, 36)
          ..lineTo(80, 40)
          ..close();
        canvas.drawPath(beak, Paint()..color = _yellow);
        canvas.drawPath(beak, line..strokeWidth = 2.2);
        canvas.drawCircle(const Offset(72, 31), 2.6, Paint()..color = _navy);
        line.strokeWidth = 3.4;
        // Legs.
        canvas.drawLine(const Offset(42, 76), const Offset(40, 88), line);
        canvas.drawLine(const Offset(58, 76), const Offset(60, 88), line);

      case 'pan':
        canvas.drawOval(const Rect.fromLTWH(20, 44, 56, 30),
            Paint()..color = const Color(0xFF6B7280));
        canvas.drawOval(const Rect.fromLTWH(20, 44, 56, 30), line);
        canvas.drawOval(const Rect.fromLTWH(27, 48, 42, 18),
            Paint()..color = const Color(0xFF9AA3AF));
        // Handle, joined to the rim.
        canvas.drawLine(const Offset(74, 54), const Offset(94, 46),
            line..strokeWidth = 6);
        line.strokeWidth = 3.4;

      case 'tin':
        final can = RRect.fromRectAndRadius(
            const Rect.fromLTWH(32, 30, 36, 48), const Radius.circular(5));
        canvas.drawRRect(can, Paint()..color = const Color(0xFF9AA3AF));
        canvas.drawRRect(can, line);
        canvas.drawRect(const Rect.fromLTWH(32, 44, 36, 20), Paint()..color = _brick);
        canvas.drawRect(const Rect.fromLTWH(32, 44, 36, 20), line..strokeWidth = 2.4);
        line.strokeWidth = 3.4;
        canvas.drawOval(const Rect.fromLTWH(32, 25, 36, 11),
            Paint()..color = const Color(0xFFCBD5E1));
        canvas.drawOval(const Rect.fromLTWH(32, 25, 36, 11), line);

      case 'ant':
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(34 + i * 17.0, 54), i == 1 ? 8 : 10,
              Paint()..color = const Color(0xFF6B4A2B));
        }
        // Legs and feelers, which are what make three circles an insect.
        for (var i = 0; i < 3; i++) {
          final x = 34 + i * 17.0;
          canvas.drawLine(Offset(x, 60), Offset(x - 6, 74), line..strokeWidth = 2.4);
          canvas.drawLine(Offset(x, 60), Offset(x + 6, 74), line);
        }
        canvas.drawLine(const Offset(30, 46), const Offset(20, 32), line);
        canvas.drawLine(const Offset(36, 45), const Offset(32, 30), line);
        line.strokeWidth = 3.4;
        canvas.drawCircle(const Offset(30, 51), 2.4, Paint()..color = Colors.white);

      case 'dog':
        canvas.drawOval(const Rect.fromLTWH(26, 40, 48, 40),
            Paint()..color = const Color(0xFFC98A46));
        canvas.drawOval(const Rect.fromLTWH(26, 40, 48, 40), line);
        // Ears, the fastest way to say dog rather than any other animal.
        for (final dx in [-1.0, 1.0]) {
          final ear = Path()
            ..moveTo(50 + dx * 20, 44)
            ..quadraticBezierTo(50 + dx * 34, 30, 50 + dx * 26, 22)
            ..quadraticBezierTo(50 + dx * 16, 30, 50 + dx * 20, 44)
            ..close();
          canvas.drawPath(ear, Paint()..color = const Color(0xFF9A6B3F));
          canvas.drawPath(ear, line);
        }
        canvas.drawCircle(const Offset(42, 54), 3, Paint()..color = _navy);
        canvas.drawCircle(const Offset(58, 54), 3, Paint()..color = _navy);
        canvas.drawOval(const Rect.fromLTWH(44, 62, 12, 9), Paint()..color = _navy);
        canvas.drawArc(const Rect.fromLTWH(40, 66, 20, 14), 0.3, 2.5, false,
            line..strokeWidth = 2.4);
        line.strokeWidth = 3.4;

      case 'kite':
        final k = Path()
          ..moveTo(50, 16)
          ..lineTo(76, 44)
          ..lineTo(50, 72)
          ..lineTo(24, 44)
          ..close();
        canvas.drawPath(k, Paint()..color = _brick);
        // Quartered, which is what a kite looks like from below.
        canvas.drawPath(
          Path()
            ..moveTo(50, 16)
            ..lineTo(76, 44)
            ..lineTo(50, 44)
            ..close(),
          Paint()..color = _yellow,
        );
        canvas.drawPath(
          Path()
            ..moveTo(50, 44)
            ..lineTo(76, 44)
            ..lineTo(50, 72)
            ..close(),
          Paint()..color = _teal,
        );
        canvas.drawPath(k, line);
        canvas.drawLine(const Offset(24, 44), const Offset(76, 44), line..strokeWidth = 2.2);
        canvas.drawLine(const Offset(50, 16), const Offset(50, 72), line);
        line.strokeWidth = 3.4;
        // Tail.
        final tail = Path()
          ..moveTo(50, 72)
          ..quadraticBezierTo(44, 80, 52, 86)
          ..quadraticBezierTo(60, 90, 54, 96);
        canvas.drawPath(tail, line..strokeWidth = 2.6);
        line.strokeWidth = 3.4;

      case 'nest':
        canvas.drawArc(const Rect.fromLTWH(18, 40, 64, 48), 0, pi, true,
            Paint()..color = const Color(0xFF9A6B3F));
        canvas.drawArc(const Rect.fromLTWH(18, 40, 64, 48), 0, pi, false, line);
        canvas.drawLine(const Offset(18, 64), const Offset(82, 64), line);
        // Twigs.
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(Offset(26 + i * 14.0, 68), Offset(34 + i * 14.0, 78),
              Paint()
                ..color = const Color(0xFF6E4A28)
                ..strokeWidth = 2.4
                ..strokeCap = StrokeCap.round);
        }
        // Eggs.
        for (var i = 0; i < 3; i++) {
          canvas.drawOval(Rect.fromLTWH(32 + i * 14.0, 44, 14, 18),
              Paint()..color = const Color(0xFFE8F1FA));
          canvas.drawOval(Rect.fromLTWH(32 + i * 14.0, 44, 14, 18), line..strokeWidth = 2.4);
        }
        line.strokeWidth = 3.4;

      case 'tap':
        // A standing tap, which in most of the houses this is built for is the
        // one in the yard rather than one over a sink.
        canvas.drawRect(const Rect.fromLTWH(44, 30, 12, 46), Paint()..color = const Color(0xFF9AA3AF));
        canvas.drawRect(const Rect.fromLTWH(44, 30, 12, 46), line);
        final spout = Path()
          ..moveTo(56, 40)
          ..lineTo(76, 40)
          ..lineTo(76, 52)
          ..lineTo(68, 52)
          ..lineTo(68, 48)
          ..lineTo(56, 48)
          ..close();
        canvas.drawPath(spout, Paint()..color = const Color(0xFF9AA3AF));
        canvas.drawPath(spout, line);
        // Handle.
        canvas.drawRect(const Rect.fromLTWH(38, 24, 24, 8), Paint()..color = _brick);
        canvas.drawRect(const Rect.fromLTWH(38, 24, 24, 8), line);
        // Water, because a tap with nothing coming out is a pipe.
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(72, 62 + i * 10.0), 3.5 - i * 0.5,
              Paint()..color = _blue);
        }

      case 'vase':
        final v = Path()
          ..moveTo(38, 32)
          ..quadraticBezierTo(28, 52, 38, 66)
          ..lineTo(38, 80)
          ..lineTo(62, 80)
          ..lineTo(62, 66)
          ..quadraticBezierTo(72, 52, 62, 32)
          ..close();
        canvas.drawPath(v, Paint()..color = _teal);
        canvas.drawPath(v, line);
        canvas.drawLine(const Offset(36, 32), const Offset(64, 32), line);
        // A flower, so the silhouette is unmistakable.
        canvas.drawLine(const Offset(50, 32), const Offset(50, 16), line..strokeWidth = 2.6);
        line.strokeWidth = 3.4;
        for (var i = 0; i < 5; i++) {
          final a = i * 2 * pi / 5 - pi / 2;
          canvas.drawCircle(Offset(50 + 8 * cos(a), 14 + 8 * sin(a)), 5,
              Paint()..color = _brick);
        }
        canvas.drawCircle(const Offset(50, 14), 4, Paint()..color = _yellow);

      case 'yoyo':
        canvas.drawLine(const Offset(50, 12), const Offset(50, 44), line..strokeWidth = 2.6);
        line.strokeWidth = 3.4;
        canvas.drawCircle(const Offset(50, 62), 24, Paint()..color = _brick);
        canvas.drawCircle(const Offset(50, 62), 24, line);
        canvas.drawCircle(const Offset(50, 62), 9, Paint()..color = _yellow);
        canvas.drawCircle(const Offset(50, 62), 9, line..strokeWidth = 2.4);
        line.strokeWidth = 3.4;

      case 'lune':
        // A crescent, cut from a circle by a second offset circle.
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: const Offset(52, 50), radius: 26)),
          Path()..addOval(Rect.fromCircle(center: const Offset(68, 42), radius: 24)),
        );
        canvas.drawPath(moon, Paint()..color = _yellow);
        canvas.drawPath(moon, line);

      case 'main':
        // A hand: palm, four fingers, thumb.
        final palm = RRect.fromRectAndRadius(
            const Rect.fromLTWH(32, 46, 38, 34), const Radius.circular(10));
        canvas.drawRRect(palm, Paint()..color = const Color(0xFFE0A87C));
        for (var i = 0; i < 4; i++) {
          final x = 34.0 + i * 9;
          final finger = RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 24 + (i == 0 || i == 3 ? 6 : 0), 7, 26),
              const Radius.circular(4));
          canvas.drawRRect(finger, Paint()..color = const Color(0xFFE0A87C));
          canvas.drawRRect(finger, line..strokeWidth = 2.4);
        }
        line.strokeWidth = 3.4;
        final thumb = RRect.fromRectAndRadius(
            const Rect.fromLTWH(22, 52, 16, 8), const Radius.circular(4));
        canvas.drawRRect(thumb, Paint()..color = const Color(0xFFE0A87C));
        canvas.drawRRect(thumb, line);
        canvas.drawRRect(palm, line);

      case 'ball':
        canvas.drawCircle(const Offset(50, 54), 26, Paint()..color = PrimarTheme.orange);
        // A curved seam and a highlight. Two marks are what turn a coloured
        // circle into a ball a child recognises.
        canvas.drawArc(const Rect.fromLTWH(28, 32, 44, 44), 0.5, 2.2, false,
            line..strokeWidth = 3.0);
        canvas.drawArc(const Rect.fromLTWH(28, 32, 44, 44), 3.7, 2.2, false, line);
        line.strokeWidth = 3.4;
        canvas.drawCircle(const Offset(42, 44), 6,
            Paint()..color = Colors.white.withValues(alpha: 0.45));
        canvas.drawCircle(const Offset(50, 54), 26, line);

      case 'cat':
        final head = Path()
          ..moveTo(30, 44)
          ..lineTo(34, 26)
          ..lineTo(46, 38)
          ..lineTo(58, 38)
          ..lineTo(70, 26)
          ..lineTo(74, 44)
          ..quadraticBezierTo(78, 72, 52, 76)
          ..quadraticBezierTo(26, 72, 30, 44)
          ..close();
        canvas.drawPath(head, Paint()..color = const Color(0xFFA8752F));
        canvas.drawPath(head, line);
        canvas.drawCircle(const Offset(43, 52), 3.6, Paint()..color = _navy);
        canvas.drawCircle(const Offset(61, 52), 3.6, Paint()..color = _navy);
        final nose = Path()
          ..moveTo(48, 60)
          ..lineTo(56, 60)
          ..lineTo(52, 65)
          ..close();
        canvas.drawPath(nose, Paint()..color = const Color(0xFFE0857C));
        for (final dx in [-1.0, 1.0]) {
          canvas.drawLine(Offset(52 + dx * 10, 61), Offset(52 + dx * 24, 58),
              line..strokeWidth = 2.2);
          canvas.drawLine(Offset(52 + dx * 10, 65), Offset(52 + dx * 24, 66), line);
        }
        line.strokeWidth = 3.4;

      case 'banana':
        // A crescent with a stem. Drawn as one thick stroke rather than an
        // outlined shape, because at 56 logical pixels a filled banana and an
        // outlined one are the same yellow blob.
        final curve = Path()
          ..moveTo(26, 30)
          ..quadraticBezierTo(30, 70, 72, 72)
          ..quadraticBezierTo(46, 62, 38, 28);
        canvas.drawPath(curve, Paint()..color = _yellow);
        canvas.drawPath(curve, line);
        canvas.drawLine(const Offset(31, 30), const Offset(29, 22),
            line..strokeWidth = 4.5);
        line.strokeWidth = 3.4;

      case 'tomato':
        canvas.drawCircle(const Offset(50, 58), 24, Paint()..color = _brick);
        canvas.drawCircle(const Offset(50, 58), 24, line);
        // Leaves — three short spokes at the top, which is what separates a
        // tomato from a plain red ball.
        for (final a in [-0.9, 0.0, 0.9]) {
          canvas.drawLine(
            const Offset(50, 36),
            Offset(50 + 14 * sin(a), 36 - 9 * cos(a)),
            Paint()
              ..color = _teal
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round,
          );
        }
        canvas.drawCircle(const Offset(50, 36), 4, Paint()..color = _teal);

      case 'umbrella':
        final dome = Path()
          ..moveTo(20, 56)
          ..arcToPoint(const Offset(80, 56), radius: const Radius.circular(30))
          ..close();
        canvas.drawPath(dome, Paint()..color = _blue);
        canvas.drawPath(dome, line);
        // Scallops along the hem, so the dome reads as fabric panels rather
        // than as half a circle.
        for (final x in [35.0, 50.0, 65.0]) {
          canvas.drawArc(Rect.fromLTWH(x - 8, 50, 16, 12), 0, pi, false, line);
        }
        canvas.drawLine(const Offset(50, 56), const Offset(50, 78),
            line..strokeWidth = 4.5);
        canvas.drawArc(const Rect.fromLTWH(42, 72, 16, 12), 0, pi, false, line);
        line.strokeWidth = 3.4;

      case 'apple':
        final body = Path()
          ..moveTo(50, 32)
          ..quadraticBezierTo(78, 28, 76, 54)
          ..quadraticBezierTo(74, 82, 50, 80)
          ..quadraticBezierTo(26, 82, 24, 54)
          ..quadraticBezierTo(22, 28, 50, 32)
          ..close();
        canvas.drawPath(body, Paint()..color = const Color(0xFFE03B3B));
        canvas.drawPath(body, line);
        canvas.drawLine(const Offset(50, 32), const Offset(52, 18),
            Paint()
              ..color = const Color(0xFF6B4A2B)
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round);
        final leaf = Path()
          ..moveTo(53, 22)
          ..quadraticBezierTo(70, 12, 68, 26)
          ..quadraticBezierTo(60, 30, 53, 22)
          ..close();
        canvas.drawPath(leaf, Paint()..color = const Color(0xFF3E9B5F));
        canvas.drawPath(leaf, line..strokeWidth = 2.4);
        line.strokeWidth = 3.4;

      case 'fish':
        final tail = Path()
          ..moveTo(24, 52)
          ..lineTo(12, 36)
          ..lineTo(12, 68)
          ..close();
        canvas.drawPath(tail, Paint()..color = const Color(0xFF1E88A8));
        canvas.drawPath(tail, line);
        final body = Path()
          ..addOval(const Rect.fromLTWH(22, 32, 62, 42));
        canvas.drawPath(body, Paint()..color = const Color(0xFF35A7C4));
        canvas.drawPath(body, line);
        canvas.drawCircle(const Offset(68, 46), 4, Paint()..color = _navy);
        canvas.drawArc(const Rect.fromLTWH(36, 42, 26, 22), 0.3, 2.0, false,
            line..strokeWidth = 2.4);
        line.strokeWidth = 3.4;

      case 'key':
        canvas.drawCircle(const Offset(34, 46), 16, Paint()..color = _yellow);
        canvas.drawCircle(const Offset(34, 46), 16, line);
        canvas.drawCircle(const Offset(34, 46), 6, Paint()..color = PrimarTheme.sheet);
        canvas.drawCircle(const Offset(34, 46), 6, line..strokeWidth = 2.4);
        line.strokeWidth = 3.4;
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(48, 41, 34, 10), const Radius.circular(4)),
          Paint()..color = _yellow,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(48, 41, 34, 10), const Radius.circular(4)),
          line,
        );
        canvas.drawLine(const Offset(70, 51), const Offset(70, 62), line);
        canvas.drawLine(const Offset(78, 51), const Offset(78, 59), line);

      case 'star':
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final rad = i.isEven ? 30.0 : 13.0;
          final a = -pi / 2 + i * pi / 5;
          final pt = Offset(50 + rad * cos(a), 52 + rad * sin(a));
          i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
        }
        star.close();
        canvas.drawPath(star, Paint()..color = _yellow);
        canvas.drawPath(star, line);

      case 'moto':
        // A moto-taxi — the vehicle most children here see every day.
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(18, 52, 64, 22), const Radius.circular(6)),
          Paint()..color = _brick,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(18, 52, 64, 22), const Radius.circular(6)),
          line,
        );
        canvas.drawCircle(const Offset(30, 74), 10, Paint()..color = _navy);
        canvas.drawCircle(const Offset(30, 74), 10, line..strokeWidth = 2.8);
        canvas.drawCircle(const Offset(70, 74), 10, Paint()..color = _navy);
        canvas.drawCircle(const Offset(70, 74), 10, line..strokeWidth = 2.8);
        line.strokeWidth = 3.4;
        // Handlebars and rider silhouette — enough to read as bike, not car.
        canvas.drawLine(const Offset(38, 52), const Offset(34, 36), line);
        canvas.drawLine(const Offset(58, 52), const Offset(62, 36), line);
        canvas.drawArc(const Rect.fromLTWH(40, 24, 24, 28), pi, pi, false, line);
        canvas.drawLine(const Offset(46, 38), const Offset(58, 38), line..strokeWidth = 2.6);
        line.strokeWidth = 3.4;

      case 'arbre':
        // Trunk and round crown — the simplest tree a child draws.
        canvas.drawRect(const Rect.fromLTWH(44, 48, 12, 34), Paint()..color = const Color(0xFF6B4A2B));
        canvas.drawRect(const Rect.fromLTWH(44, 48, 12, 34), line);
        canvas.drawCircle(const Offset(50, 36), 26, Paint()..color = const Color(0xFF3E9B5F));
        canvas.drawCircle(const Offset(50, 36), 26, line);

      case 'gobelet':
        // A plastic cup — taller and tapered, unlike the English teacup.
        final cup = Path()
          ..moveTo(34, 28)
          ..lineTo(30, 78)
          ..lineTo(70, 78)
          ..lineTo(66, 28)
          ..close();
        canvas.drawPath(cup, Paint()..color = _teal);
        canvas.drawPath(cup, line);
        canvas.drawLine(const Offset(34, 28), const Offset(66, 28), line);
        // A stripe so it reads as disposable plastic, not pottery.
        canvas.drawLine(const Offset(32, 52), const Offset(68, 52),
            Paint()
              ..color = _yellow
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round);

      case 'riz':
        // A bowl of rice — mound of white grains in a simple bowl.
        canvas.drawArc(const Rect.fromLTWH(22, 58, 56, 24), 0, pi, false, line);
        canvas.drawLine(const Offset(22, 58), const Offset(78, 58), line);
        final mound = Path()
          ..moveTo(28, 58)
          ..quadraticBezierTo(50, 28, 72, 58)
          ..close();
        canvas.drawPath(mound, Paint()..color = const Color(0xFFF5F0E6));
        canvas.drawPath(mound, line..strokeWidth = 2.4);
        line.strokeWidth = 3.4;
        // Grain dots.
        for (final o in [const Offset(42, 46), const Offset(50, 42), const Offset(58, 46)]) {
          canvas.drawCircle(o, 2.2, Paint()..color = _navy.withValues(alpha: 0.25));
        }

      case 'eau':
        // A water drop — unmistakable at any size.
        final drop = Path()
          ..moveTo(50, 14)
          ..quadraticBezierTo(72, 44, 50, 82)
          ..quadraticBezierTo(28, 44, 50, 14)
          ..close();
        canvas.drawPath(drop, Paint()..color = _blue);
        canvas.drawPath(drop, line);
        canvas.drawOval(const Rect.fromLTWH(40, 52, 20, 10),
            Paint()..color = Colors.white.withValues(alpha: 0.35));

      case 'feu':
        // Three flame tongues over a log — fire without being scary.
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(28, 68, 44, 12), const Radius.circular(4)),
          Paint()..color = const Color(0xFF6B4A2B),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(28, 68, 44, 12), const Radius.circular(4)),
          line,
        );
        final flame = Path()
          ..moveTo(50, 18)
          ..quadraticBezierTo(68, 44, 58, 66)
          ..quadraticBezierTo(50, 52, 42, 66)
          ..quadraticBezierTo(32, 44, 50, 18)
          ..close();
        canvas.drawPath(flame, Paint()..color = _yellow);
        canvas.drawPath(flame, line);
        canvas.drawPath(
          Path()
            ..moveTo(50, 28)
            ..quadraticBezierTo(58, 48, 52, 60)
            ..quadraticBezierTo(50, 50, 48, 60)
            ..quadraticBezierTo(42, 48, 50, 28)
            ..close(),
          Paint()..color = _brick,
        );

      case 'mot':
        // A speech bubble — the French word for "word".
        final bubble = RRect.fromRectAndRadius(
            const Rect.fromLTWH(18, 22, 64, 40), const Radius.circular(12));
        canvas.drawRRect(bubble, Paint()..color = PrimarTheme.sheet);
        canvas.drawRRect(bubble, line);
        final tail = Path()
          ..moveTo(36, 62)
          ..lineTo(28, 74)
          ..lineTo(46, 62)
          ..close();
        canvas.drawPath(tail, Paint()..color = PrimarTheme.sheet);
        canvas.drawPath(tail, line..strokeWidth = 2.4);
        line.strokeWidth = 3.4;
        canvas.drawLine(const Offset(30, 38), const Offset(70, 38),
            Paint()
              ..color = _navy.withValues(alpha: 0.35)
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round);
        canvas.drawLine(const Offset(30, 48), const Offset(58, 48),
            Paint()
              ..color = _navy.withValues(alpha: 0.35)
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round);

      case 'roc':
        // A single boulder — lumpy oval, enough for roc/rock.
        final rock = Path()
          ..moveTo(24, 58)
          ..quadraticBezierTo(22, 38, 42, 30)
          ..quadraticBezierTo(68, 26, 76, 48)
          ..quadraticBezierTo(78, 68, 52, 74)
          ..quadraticBezierTo(28, 76, 24, 58)
          ..close();
        canvas.drawPath(rock, Paint()..color = const Color(0xFF8A8F98));
        canvas.drawPath(rock, line);
        canvas.drawLine(const Offset(38, 42), const Offset(52, 50),
            line..strokeWidth = 2.2..color = _navy.withValues(alpha: 0.25));

      case 'mer':
        // Two wave crests — the sea at a glance.
        for (var i = 0; i < 2; i++) {
          final y = 44.0 + i * 18;
          canvas.drawArc(Rect.fromLTWH(16, y, 68, 28), 0.1, pi - 0.2, false,
              Paint()
                ..color = _blue.withValues(alpha: 0.85 - i * 0.2)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 8
                ..strokeCap = StrokeCap.round);
        }
        canvas.drawLine(const Offset(16, 72), const Offset(84, 72), line);

      default:
        // Never reached: the generator only offers drawable words. Drawn as a
        // neutral placeholder rather than crashing if that ever slips.
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(28, 34, 44, 44), const Radius.circular(10)),
          line,
        );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WordPainter old) => old.word != word;
}
