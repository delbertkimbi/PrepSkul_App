import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:prepskul/core/theme/app_theme.dart';

/// Mate — the companion.
///
/// A child who cannot read has no way to be told they are doing well. Mate is
/// how encouragement arrives: he watches, reacts, and celebrates. That is not
/// decoration, it is the emotional channel of the whole product.
///
/// Drawn in vectors rather than generated frames or video, deliberately. A
/// reactive character has to answer a tap in the same frame, hold a consistent
/// face across thousands of appearances, weigh kilobytes rather than megabytes,
/// and run on a cheap phone with the network off. Pre-rendered art fails all
/// four. The design was explored with generated concept art; only the rig ships.
///
/// What makes him feel alive is not the poses, it is the physics between them:
/// the antenna lags behind the body instead of moving with it, a jump is
/// preceded by a crouch, and he squashes on landing. Those three things are
/// most of the difference between a character and a picture.
enum Mood {
  /// Waiting. Breathes, blinks, glances around.
  idle,

  /// Intro hop. One arm waving hello.
  wave,

  /// Mouth flaps while a question is being typed.
  talk,

  /// A question is on screen and the child is deciding.
  thinking,

  /// They got it.
  happy,

  /// They missed it. Warm, never disappointed.
  encourage,

  /// End of a session, or Super.
  cheer,

  /// Pointing at something beside him, the same pose as the site SVG Mate.
  point,
}

class Mate extends StatefulWidget {
  const Mate({
    super.key,
    required this.mood,
    this.size = 96,
    this.ink = AppTheme.primaryColor,
    this.body = AppTheme.mateBodyBlue,
    this.belly = AppTheme.mateBellyTeal,
    this.accent = AppTheme.mateAntennaYellow,
    this.keepHopping = false,
    this.flip = false,
  });

  final Mood mood;
  final double size;
  final Color ink;
  final Color body;
  final Color belly;
  final Color accent;

  /// Marketplace Mate keeps a 0.9s hop, matching the site SVG.
  final bool keepHopping;

  /// Mirror so a Mate on the right can point at copy on the left.
  final bool flip;

  @override
  State<Mate> createState() => _MateState();
}

class _MateState extends State<Mate> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  final Random _rng = Random();
  Duration _last = Duration.zero;

  // Body
  double _bodyY = 0;
  double _bodyV = 0;

  /// Antenna angle and its rate of change. Driven by a spring chasing the
  /// body's motion, which is what produces the lag and the overshoot.
  double _antenna = 0;
  double _antennaV = 0;

  double _breath = 0;
  double _reaction = 0;

  /// Fades out after a hard landing so the impact dashes at the feet appear
  /// only on the frames where he actually hits the ground.
  double _impact = 0;

  // Blink
  double _blinkTimer = 2;
  double _blinkFor = 0;

  // Where the pupils are looking, and how long until they drift somewhere else.
  double _gaze = 0;
  double _gazeTarget = 0;
  double _gazeTimer = 1.5;

  /// Time until the next keep-alive hop (site SVG is 0.9s).
  double _hopWait = 0.45;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    if (widget.mood != Mood.idle) _trigger();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce && _ticker.isActive) {
      _ticker.stop();
    } else if (!reduce && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant Mate old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _trigger();
  }

  /// A mood change is an *event*, not just a new pose.
  void _trigger() {
    _reaction = 1;
    switch (widget.mood) {
      case Mood.happy:
        // Crouch first. The dip before a jump is anticipation, and without it
        // the jump reads as a glitch rather than a decision.
        _bodyV = 34;
      case Mood.wave:
        _bodyV = 34;
      case Mood.talk:
        _bodyV = 12;
      case Mood.cheer:
        _bodyV = 46;
      case Mood.encourage:
        _bodyV = 22;
        _antennaV = -7;
      case Mood.thinking:
        _gazeTarget = 0.8;
      case Mood.point:
        _bodyV = 28;
        _gazeTarget = 1.0;
      case Mood.idle:
        _gazeTarget = 0;
    }
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    if (dt <= 0) return;

    _breath += dt * 1.5;
    _reaction = (_reaction - dt * 1.6).clamp(0.0, 1.0);
    _impact = (_impact - dt * 4.5).clamp(0.0, 1.0);

    final wasFalling = _bodyV;

    // Body: a spring back to rest. The initial velocity from _trigger is what
    // makes it dip and then launch.
    const k = 210.0;
    const damping = 13.0;
    _bodyV += (-k * _bodyY - damping * _bodyV) * dt;
    _bodyY += _bodyV * dt;

    // Crossing back through rest while moving fast is a landing.
    if (wasFalling < -18 && _bodyV >= wasFalling && _bodyY < 1 && _bodyY > -1) {
      _impact = 1;
    }

    // Antenna: a softer, slower spring driven by the body's motion, so it
    // trails behind on the way up and whips forward at the top.
    // Amplitude taken from the keyframe reference, where the stalk trails
    // nearly straight down on launch rather than leaning a few degrees.
    final drive = -_bodyV * 0.030;
    _antennaV += ((drive - _antenna) * 90 - _antennaV * 9) * dt;
    _antenna += _antennaV * dt;

    // Blink at irregular intervals. Perfectly periodic blinking is the single
    // fastest way to make a face read as mechanical.
    _blinkTimer -= dt;
    if (_blinkFor > 0) {
      _blinkFor -= dt;
    } else if (_blinkTimer <= 0) {
      _blinkFor = 0.12;
      _blinkTimer = 1.8 + _rng.nextDouble() * 3.4;
    }

    // Gaze drifts rather than snapping, and idles by looking around.
    _gazeTimer -= dt;
    if (_gazeTimer <= 0) {
      _gazeTimer = 1.2 + _rng.nextDouble() * 2.2;
      if (widget.mood == Mood.idle || widget.mood == Mood.talk) {
        _gazeTarget = (_rng.nextDouble() - 0.5) * 1.4;
      } else if (widget.mood == Mood.point) {
        _gazeTarget = 1.0;
      }
    }
    _gaze += (_gazeTarget - _gaze) * (dt * 6).clamp(0.0, 1.0);

    if (widget.keepHopping) {
      _hopWait -= dt;
      if (_hopWait <= 0 && _bodyY.abs() < 3 && _bodyV.abs() < 10) {
        _bodyV = widget.mood == Mood.thinking ? 16 : 30;
        _hopWait = 0.9;
      }
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final float = sin(_breath) * 1.8;

    // Squash and stretch, driven by actual vertical velocity: stretched while
    // travelling, squashed at the moment of landing.
    final stretch = (_bodyV * 0.0022).clamp(-0.16, 0.16);

    // The whole character leans into the direction of travel, which is what
    // stops a jump reading as a lift on a string.
    final tilt = (-_bodyV * 0.0016).clamp(-0.11, 0.11);

    Widget child = SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _MatePainter(
          mood: widget.mood,
          bodyY: -_bodyY + float,
          stretch: stretch,
          tilt: tilt,
          impact: _impact,
          antenna: _antenna,
          blink: _blinkFor > 0,
          gaze: _gaze,
          reaction: _reaction,
          breath: _breath,
          ink: widget.ink,
          body: widget.body,
          belly: widget.belly,
          accent: widget.accent,
        ),
      ),
    );
    if (widget.flip) {
      child = Transform.flip(flipX: true, child: child);
    }
    return child;
  }
}

class _MatePainter extends CustomPainter {
  _MatePainter({
    required this.mood,
    required this.bodyY,
    required this.stretch,
    required this.tilt,
    required this.impact,
    required this.antenna,
    required this.blink,
    required this.gaze,
    required this.reaction,
    required this.breath,
    required this.ink,
    required this.body,
    required this.belly,
    required this.accent,
  });

  final Mood mood;
  final double bodyY;
  final double stretch;
  final double tilt;
  final double impact;
  final double antenna;
  final bool blink;
  final double gaze;
  final double reaction;
  final double breath;
  final Color ink;
  final Color body;
  final Color belly;
  final Color accent;

  Color get _navy => ink;
  Color get _blue => body;
  Color get _teal => belly;
  Color get _yellow => accent;

  bool get _elated => mood == Mood.happy || mood == Mood.cheer;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);

    // Everything below is authored in a 100x100 space.
    canvas.translate(50, 52 + bodyY);
    canvas.rotate(tilt);
    canvas.scale(1 - stretch, 1 + stretch);
    canvas.translate(-50, -52);

    final outline = Paint()
      ..color = _navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    _drawSparks(canvas);
    _drawArms(canvas, outline);
    _drawFeet(canvas);
    _drawBody(canvas);
    // After the body, or the collar is painted underneath it and vanishes.
    _drawAntenna(canvas, outline);
    _drawFace(canvas, outline);
    _drawImpact(canvas);

    canvas.restore();
  }

  /// An egg rather than a rounded rectangle — narrower at the top, heavier at
  /// the bottom, which is what makes a shape read as a creature.
  Path _bodyPath() => Path()
    ..moveTo(50, 15)
    ..cubicTo(68, 15, 79, 30, 79, 50)
    ..cubicTo(79, 72, 68, 85, 50, 85)
    ..cubicTo(32, 85, 21, 72, 21, 50)
    ..cubicTo(21, 30, 32, 15, 50, 15)
    ..close();

  void _drawBody(Canvas canvas) {
    final body = _bodyPath();

    // Hard offset shadow, the same trick the paper surfaces use, so he sits on
    // the page rather than floating above it.
    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(body, Paint()..color = _navy.withValues(alpha: 0.16));
    canvas.restore();

    canvas.drawPath(body, Paint()..color = _blue);

    // The teal belly. It gives him a front, which is most of why the concept
    // sheet read as a character and a flat silhouette does not.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawOval(
      // Kept low deliberately: raised any further it swallows the mouth and
      // the face loses its expression entirely.
      Rect.fromCenter(center: const Offset(50, 91), width: 50, height: 36),
      Paint()..color = _teal,
    );
    canvas.restore();

    canvas.drawPath(
      body,
      Paint()
        ..color = _navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..isAntiAlias = true,
    );
  }

  void _drawFeet(Canvas canvas) {
    final foot = Paint()..color = _navy;
    for (final dx in [-13.0, 13.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(50 + dx, 86), width: 17, height: 9),
        foot,
      );
    }
  }

  void _drawAntenna(Canvas canvas, Paint outline) {
    // The lag lives here: `antenna` is a spring chasing the body, so the stalk
    // trails on the way up and whips over at the top.
    final sway = antenna * 26 + sin(breath * 0.8) * 1.6;
    final tip = Offset(50 + sway, 1);

    canvas.drawPath(
      Path()
        ..moveTo(50, 17)
        ..quadraticBezierTo(50 + sway * 0.4, 8, tip.dx, tip.dy),
      outline,
    );

    // Collar where the stalk meets the body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(50, 17), width: 18, height: 7),
        const Radius.circular(3),
      ),
      Paint()..color = _teal,
    );

    canvas.drawCircle(tip, 5.6, Paint()..color = _yellow);
    canvas.drawCircle(tip, 2.4, Paint()..color = _yellow.withValues(alpha: 0.55));
    canvas.drawCircle(
      tip,
      5.6,
      Paint()
        ..color = _navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  void _drawArms(Canvas canvas, Paint outline) {
    final waving = mood == Mood.wave;
    final talking = mood == Mood.talk;
    final thumb = mood == Mood.encourage;
    final pointing = mood == Mood.point;
    final lift = _elated
        ? 1.0
        : thumb
            ? 0.35
            : talking
                ? 0.42
                : waving
                    ? 0.2
                    : pointing
                        ? 0.15
                        : 0.0;
    final idleWave = _elated
        ? sin(breath * 6) * 3
        : talking
            ? sin(breath * 3.2) * 2.2
            : mood == Mood.idle
                ? sin(breath * 2.2) * 1.4
                : 0.0;

    for (final side in [-1.0, 1.0]) {
      final thinkArm = mood == Mood.thinking && side < 0;
      final waveArm = waving && side > 0;
      final thumbArm = thumb && side < 0;
      final pointArm = pointing && side > 0;
      final shoulder = Offset(50 + side * 30, 56);
      final Offset hand;
      if (thinkArm) {
        hand = const Offset(42, 58);
      } else if (waveArm) {
        hand = Offset(74 + sin(breath * 8) * 7, 22 + cos(breath * 8) * 4);
      } else if (thumbArm) {
        hand = const Offset(22, 34);
      } else if (pointArm) {
        // Site SVG rotates this arm about -16deg on a 1.05s loop.
        final jab = sin(breath * 4) * 6;
        hand = Offset(102 + jab, 38 - jab * 0.35);
      } else if (pointing && side < 0) {
        hand = const Offset(18, 46);
      } else {
        hand = Offset(
          50 + side * (40 + lift * 6) + side * idleWave,
          56 - lift * 30 + (lift == 0 ? 8 : 0),
        );
      }
      final ctrl = Offset(
        50 + side * (40 + lift * 4),
        (shoulder.dy + hand.dy) / 2 - 4,
      );

      canvas.drawPath(
        Path()
          ..moveTo(shoulder.dx, shoulder.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, hand.dx, hand.dy),
        outline,
      );

      // Little splayed hands, straight off the concept sheet. Three short
      // strokes read as fingers at this size; anything more turns to mush.
      if (_elated || waveArm) {
        for (var i = -1; i <= 1; i++) {
          final a = -pi / 2 + i * 0.5 + (side < 0 ? -0.35 : 0.35);
          canvas.drawLine(
            hand,
            Offset(hand.dx + cos(a) * 5.5, hand.dy + sin(a) * 5.5),
            outline,
          );
        }
      } else if (thumbArm) {
        canvas.drawCircle(hand, 3.2, Paint()..color = _navy);
        canvas.drawLine(Offset(hand.dx, hand.dy - 2), Offset(hand.dx, hand.dy - 9), outline);
      } else if (pointArm) {
        canvas.drawCircle(hand, 3.4, Paint()..color = _navy);
        canvas.drawLine(
          hand,
          Offset(hand.dx + 9, hand.dy - 5),
          outline,
        );
      } else {
        canvas.drawCircle(hand, 2.6, Paint()..color = _navy);
      }
    }
  }

  void _drawFace(Canvas canvas, Paint outline) {
    const eyeY = 45.0;
    const eyeL = 36.5;
    const eyeR = 63.5;
    final look = gaze * 2.6;

    if (blink || _elated || mood == Mood.encourage) {
      // Closed and curved upward. The shape of a smile, which is what makes a
      // face read as delighted rather than merely awake.
      for (final x in [eyeL, eyeR]) {
        canvas.drawPath(
          Path()
            ..moveTo(x - 7.5, eyeY + 2)
            ..quadraticBezierTo(x, eyeY - 6.5, x + 7.5, eyeY + 2),
          outline,
        );
      }
    } else {
      for (final x in [eyeL, eyeR]) {
        // Large eyes. The concept sheet gave them roughly a fifth of the body
        // width, and that single proportion carries most of the warmth.
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, eyeY), width: 19, height: 20),
          Paint()..color = Colors.white,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, eyeY), width: 19, height: 20),
          Paint()
            ..color = _navy
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
        canvas.drawCircle(
          Offset(x + look, eyeY + gaze.abs() * 1.2),
          6.0,
          Paint()..color = _navy,
        );
        // A highlight does more for aliveness than any other single detail.
        canvas.drawCircle(
          Offset(x + look + 1.9, eyeY + gaze.abs() * 1.2 - 2.2),
          1.9,
          Paint()..color = Colors.white,
        );
      }
    }

    // Eyebrows carry the difference between "wrong" and "keep going".
    if (mood == Mood.encourage) {
      for (final side in [-1.0, 1.0]) {
        final x = 50 + side * 11;
        canvas.drawPath(
          Path()
            ..moveTo(x - side * 7, eyeY - 13)
            ..quadraticBezierTo(x, eyeY - 16, x + side * 7, eyeY - 12),
          outline,
        );
      }
    }

    if (mood == Mood.talk || mood == Mood.wave || mood == Mood.point) {
      for (final side in [-1.0, 1.0]) {
        final x = 50 + side * 11;
        canvas.drawPath(
          Path()
            ..moveTo(x - side * 6, eyeY - 12)
            ..quadraticBezierTo(x, eyeY - 16, x + side * 6, eyeY - 11),
          outline,
        );
      }
    }

    final mouthY = 63.0;
    switch (mood) {
      case Mood.talk:
        _openMouth(canvas, mouthY, 4.5 + sin(breath * 14).abs() * 7.5);
      case Mood.wave:
        _openMouth(canvas, mouthY, 7 + reaction * 2);
      case Mood.point:
      case Mood.idle:
        canvas.drawPath(
          Path()
            ..moveTo(42, mouthY - 1)
            ..quadraticBezierTo(50, mouthY + 7, 58, mouthY - 1),
          outline,
        );
      case Mood.thinking:
        canvas.drawLine(
          Offset(43 + look, mouthY + 1),
          Offset(56 + look, mouthY - 2),
          outline,
        );
      case Mood.encourage:
        canvas.drawPath(
          Path()
            ..moveTo(42, mouthY)
            ..quadraticBezierTo(50, mouthY + 8, 58, mouthY),
          outline,
        );
      case Mood.happy:
      case Mood.cheer:
        // Open mouth with a teal tongue. The detail that turned a smile into
        // a laugh on the concept sheet.
        _openMouth(canvas, mouthY, 8.0 + reaction * 3);
    }
  }

  void _openMouth(Canvas canvas, double mouthY, double open) {
    final mouth = Path()
      ..moveTo(41, mouthY - 3)
      ..quadraticBezierTo(50, mouthY + open, 59, mouthY - 3)
      ..close();
    canvas.drawPath(mouth, Paint()..color = _navy);
    canvas.save();
    canvas.clipPath(mouth);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(50, mouthY + open * 0.72),
        width: 11,
        height: 8,
      ),
      Paint()..color = _teal,
    );
    canvas.restore();
  }

  /// Short dashes kicking out at the feet on landing. Two frames of this sell
  /// the weight of a jump more than any amount of easing.
  void _drawImpact(Canvas canvas) {
    if (impact <= 0.01) return;
    final paint = Paint()
      ..color = _navy.withValues(alpha: 0.55 * impact)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        final spread = 4.0 + i * 5.0;
        final y = 88.0 - i * 3.5;
        canvas.drawLine(
          Offset(50 + side * (22 + spread), y),
          Offset(50 + side * (27 + spread + 4 * impact), y - 2),
          paint,
        );
      }
    }
  }

  void _drawSparks(Canvas canvas) {
    if (!_elated) return;

    final energy = mood == Mood.cheer ? 1.0 : 0.62;
    final stroke = Paint()
      ..color = _yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 6; i++) {
      final a = -pi / 2 + (i - 2.5) * 0.42;
      final r0 = 42 + reaction * 6;
      canvas.drawLine(
        Offset(50 + r0 * cos(a), 50 + r0 * sin(a)),
        Offset(50 + (r0 + 9 * energy) * cos(a), 50 + (r0 + 9 * energy) * sin(a)),
        stroke,
      );
    }

    // Two paper stars, as on the sheet.
    if (mood == Mood.cheer) {
      for (final p in [const Offset(16, 26), const Offset(84, 30)]) {
        _star(canvas, p, 6.5 + reaction * 1.5);
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final outer = -pi / 2 + i * 2 * pi / 5;
      final inner = outer + pi / 5;
      final po = Offset(c.dx + r * cos(outer), c.dy + r * sin(outer));
      final pin = Offset(c.dx + r * 0.44 * cos(inner), c.dy + r * 0.44 * sin(inner));
      if (i == 0) {
        path.moveTo(po.dx, po.dy);
      } else {
        path.lineTo(po.dx, po.dy);
      }
      path.lineTo(pin.dx, pin.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = _yellow);
  }

  @override
  bool shouldRepaint(covariant _MatePainter old) => true;
}
