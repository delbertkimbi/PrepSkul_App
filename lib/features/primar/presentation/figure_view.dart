import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/figure.dart';
import '../services/primar_voice.dart';
import 'primar_theme.dart';
import 'shape_view.dart';
import 'word_picture.dart';

/// Renders any [Figure] — the single widget every subject draws through.
///
/// A note on numerals and letters: elsewhere the rule is that nothing a child
/// looks at is type, because the child cannot read. Numerals and letters are the
/// exception, and deliberately so — recognising them *is* the learning
/// objective. They are content, not instructions.
class FigureView extends StatelessWidget {
  const FigureView({
    super.key,
    required this.figure,
    this.color = PrimarTheme.questionInk,
    this.size = 68,
  });

  final Figure figure;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return switch (figure) {
      ShapeFigure(:final shape) => ShapeView(
        shape: shape,
        color: color,
        size: size,
      ),
      QuantityFigure(:final count, :final token) => _TenFrame(
        count: count,
        token: token,
        color: color,
        size: size,
      ),
      NumeralFigure(:final value) => _Numeral(
        value: value,
        color: color,
        size: size,
      ),
      LetterFigure(:final letter) => _Letter(
        letter: letter,
        color: color,
        size: size,
      ),
      WordFigure(:final word, :final withPicture) => _Word(
        word: word,
        color: color,
        size: size,
        withPicture: withPicture,
      ),
      SoundFigure(:final phraseId) => _Listen(phraseId: phraseId, size: size),
      PictureFigure(:final word) => WordPicture(word: word, size: size * 1.35),
      PhraseFigure(:final first, :final joiner, :final second) => _Phrase(
        first: first,
        joiner: joiner,
        second: second,
        size: size,
      ),
      SymbolFigure(:final symbol) => _Symbol(symbol: symbol, size: size * 0.42),
    };
  }
}

/// A miniature scene: two pictures with a joiner between them.
///
/// Sized to fit inside an answer tile at phone width. The joiner is type on
/// purpose — a child at this rung can read three-letter words like "on", and
/// seeing it cements that joiners are words too.
class _Phrase extends StatelessWidget {
  const _Phrase({
    required this.first,
    required this.joiner,
    required this.second,
    required this.size,
  });

  final String first;
  final String joiner;
  final String second;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pic = size * 0.42;
    return SizedBox(
      width: size * 1.55,
      height: size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          WordPicture(word: first, size: pic),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.04),
            child: Text(
              joiner,
              style: PrimarTheme.label(joiner.length <= 3 ? 13 : 11).copyWith(
                color: PrimarTheme.questionInk.withValues(alpha: 0.72),
              ),
            ),
          ),
          WordPicture(word: second, size: pic),
        ],
      ),
    );
  }
}

/// Quantities are drawn in a ten-frame — two rows of five.
///
/// This is the standard manipulative maths teachers use, and it is not
/// decoration: the fixed frame lets a child recognise five and ten at a glance
/// instead of counting one by one, which is the actual skill being built.
/// Marks are drawn, never generated, so the count is exact every time.
class _TenFrame extends StatelessWidget {
  const _TenFrame({
    required this.count,
    required this.token,
    required this.color,
    required this.size,
  });

  final int count;
  final CountToken token;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TenFramePainter(count: count, token: token, color: color),
      ),
    );
  }
}

class _TenFramePainter extends CustomPainter {
  _TenFramePainter({
    required this.count,
    required this.token,
    required this.color,
  });

  final int count;
  final CountToken token;
  final Color color;

  /// Counts this size or smaller are shown loose, with no frame.
  ///
  /// A five-by-two grid holding three marks is seven empty boxes and three full
  /// ones, and what a child looks at is the emptiness. At small counts the frame
  /// teaches nothing they cannot already see — three is recognised at a glance
  /// — while shrinking the things themselves to specks. Below the threshold the
  /// objects get the whole box; at six and above the frame earns its place,
  /// because that is where "five and one more" starts doing real work.
  static const int looseUpTo = 5;

  @override
  void paint(Canvas canvas, Size size) {
    if (count <= looseUpTo && CountToken.things.contains(token)) {
      _paintLoose(canvas, size);
      return;
    }

    // Beyond ten the frame grows a second block rather than shrinking the marks
    // past the point a child can tell them apart.
    final frames = (count / 10).ceil().clamp(1, 3);
    const cols = 5;
    final rows = 2 * frames;

    // Cells must stay square. Stretching a 5x2 grid to fill a square box turns
    // every cell into a tall sliver and the marks become unreadable, so the
    // frame is sized to the tighter axis and centred in the box instead.
    final cell = (size.width / cols) < (size.height / rows)
        ? size.width / cols
        : size.height / rows;
    final frameW = cell * cols;
    final frameH = cell * rows;
    final originX = (size.width - frameW) / 2;
    final originY = (size.height - frameH) / 2;

    final radius = cell * 0.28;

    final framePaint = Paint()
      ..color = PrimarTheme.navy.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.06;

    final markPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // The empty frame first, so a child sees how many spaces are still open —
    // that gap is what teaches "three more makes ten".
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawRect(
          Rect.fromLTWH(
            originX + c * cell,
            originY + r * cell,
            cell,
            cell,
          ).deflate(cell * 0.03),
          framePaint,
        );
      }
    }

    var drawn = 0;
    for (var r = 0; r < rows && drawn < count; r++) {
      for (var c = 0; c < cols && drawn < count; c++) {
        final center = Offset(
          originX + c * cell + cell / 2,
          originY + r * cell + cell / 2,
        );
        _paintMark(canvas, center, radius, markPaint);
        drawn++;
      }
    }
  }

  /// Small counts, laid out as things on a table rather than in a grid.
  ///
  /// Two rows at most, centred, each object taking as much of the box as the
  /// count allows. Three mangoes at this size are three mangoes; three mangoes
  /// in a ten-frame are three specks above seven empty squares.
  void _paintLoose(Canvas canvas, Size size) {
    final perRow = count <= 3 ? count : (count / 2).ceil();
    final rows = (count / perRow).ceil();

    final cellW = size.width / perRow;
    final cellH = size.height / rows;
    final r = (cellW < cellH ? cellW : cellH) * 0.42;

    var drawn = 0;
    for (var row = 0; row < rows && drawn < count; row++) {
      final remaining = count - drawn;
      final inRow = remaining < perRow ? remaining : perRow;
      // Short rows are centred rather than left-aligned, so four things read as
      // a block and three as a line — both easier to count than a ragged edge.
      final startX = (size.width - inRow * cellW) / 2;
      final y = size.height / 2 + (row - (rows - 1) / 2) * cellH;

      for (var c = 0; c < inRow; c++) {
        _paintThing(
          canvas,
          Offset(startX + c * cellW + cellW / 2, y),
          r,
          token,
        );
        drawn++;
      }
    }
  }

  void _paintMark(
    Canvas canvas,
    Offset center,
    double radius,
    Paint markPaint,
  ) {
    switch (token) {
      case CountToken.dot:
        canvas.drawCircle(center, radius, markPaint);
      case CountToken.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: radius * 1.9,
              height: radius * 1.9,
            ),
            Radius.circular(radius * 0.35),
          ),
          markPaint,
        );
      case CountToken.triangle:
        final path = Path()
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx + radius, center.dy + radius * 0.85)
          ..lineTo(center.dx - radius, center.dy + radius * 0.85)
          ..close();
        canvas.drawPath(path, markPaint);
      case CountToken.mango:
      case CountToken.ball:
      case CountToken.fish:
      case CountToken.leaf:
      case CountToken.star:
        // Things keep their own colours. A grey mango is not a mango, and the
        // whole point of counting a mango rather than a dot is that a child
        // recognises it before they count it.
        _paintThing(canvas, center, radius * 1.15, token);
    }
  }

  @override
  bool shouldRepaint(covariant _TenFramePainter old) =>
      old.count != count || old.color != color || old.token != token;
}

/// Draws one countable object, centred, at the given radius.
///
/// Small, flat and high-contrast on purpose: these are rendered ten to a frame
/// at a few dozen pixels each, so detail is wasted and silhouette is
/// everything. A child has to tell what it is at a glance and then stop looking
/// at it, because the task is counting, not identifying.
void _paintThing(Canvas canvas, Offset at, double r, CountToken token) {
  final line = Paint()
    ..color = PrimarTheme.navy.withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.16
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  switch (token) {
    case CountToken.mango:
      final body = Path()
        ..moveTo(at.dx - r * 0.1, at.dy + r)
        ..quadraticBezierTo(
          at.dx - r * 1.15,
          at.dy + r * 0.1,
          at.dx - r * 0.4,
          at.dy - r * 0.75,
        )
        ..quadraticBezierTo(
          at.dx + r * 0.5,
          at.dy - r * 1.15,
          at.dx + r * 0.95,
          at.dy - r * 0.1,
        )
        ..quadraticBezierTo(
          at.dx + r * 1.05,
          at.dy + r * 0.8,
          at.dx - r * 0.1,
          at.dy + r,
        );
      canvas.drawPath(body, Paint()..color = const Color(0xFFE79A2B));
      canvas.drawPath(body, line);
      canvas.drawLine(
        Offset(at.dx - r * 0.35, at.dy - r * 0.8),
        Offset(at.dx - r * 0.5, at.dy - r * 1.25),
        Paint()
          ..color = const Color(0xFF2F7D4F)
          ..strokeWidth = r * 0.22
          ..strokeCap = StrokeCap.round,
      );

    case CountToken.ball:
      // A pentagon on white, and nothing else.
      //
      // The first cut radiated three seams out from a centre panel the way a
      // real football does. At the twenty-odd pixels these are actually drawn
      // at, that read as a steering wheel. Silhouette is all that survives at
      // this size, so the detail goes and the one shape that says "football"
      // stays.
      canvas.drawCircle(at, r, Paint()..color = const Color(0xFFF4F6FA));
      final pent = Path();
      for (var i = 0; i < 5; i++) {
        final a = -pi / 2 + i * 2 * pi / 5;
        final p = Offset(at.dx + r * 0.5 * cos(a), at.dy + r * 0.5 * sin(a));
        i == 0 ? pent.moveTo(p.dx, p.dy) : pent.lineTo(p.dx, p.dy);
      }
      pent.close();
      canvas.drawPath(pent, Paint()..color = PrimarTheme.navy);
      canvas.drawCircle(at, r, line);

    case CountToken.fish:
      final body = Path()
        ..addOval(
          Rect.fromCenter(
            center: Offset(at.dx + r * 0.12, at.dy),
            width: r * 1.7,
            height: r * 1.15,
          ),
        );
      final tail = Path()
        ..moveTo(at.dx - r * 0.72, at.dy)
        ..lineTo(at.dx - r * 1.15, at.dy - r * 0.55)
        ..lineTo(at.dx - r * 1.15, at.dy + r * 0.55)
        ..close();
      canvas.drawPath(tail, Paint()..color = const Color(0xFF1E88A8));
      canvas.drawPath(body, Paint()..color = const Color(0xFF35A7C4));
      canvas.drawPath(tail, line);
      canvas.drawPath(body, line);
      canvas.drawCircle(
        Offset(at.dx + r * 0.55, at.dy - r * 0.15),
        r * 0.13,
        Paint()..color = PrimarTheme.navy,
      );

    case CountToken.leaf:
      final leaf = Path()
        ..moveTo(at.dx, at.dy + r)
        ..quadraticBezierTo(at.dx - r * 1.2, at.dy, at.dx, at.dy - r)
        ..quadraticBezierTo(at.dx + r * 1.2, at.dy, at.dx, at.dy + r)
        ..close();
      canvas.drawPath(leaf, Paint()..color = const Color(0xFF3E9B5F));
      canvas.drawPath(leaf, line);
      canvas.drawLine(
        Offset(at.dx, at.dy + r * 0.85),
        Offset(at.dx, at.dy - r * 0.85),
        Paint()
          ..color = const Color(0xFF25693F)
          ..strokeWidth = r * 0.14,
      );

    case CountToken.star:
      final path = Path();
      for (var i = 0; i < 10; i++) {
        final rad = i.isEven ? r : r * 0.45;
        final a = -pi / 2 + i * pi / 5;
        final p = Offset(at.dx + rad * cos(a), at.dy + rad * sin(a));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = PrimarTheme.yellow);
      canvas.drawPath(path, line);

    case CountToken.dot:
    case CountToken.square:
    case CountToken.triangle:
      break;
  }
}

class _Numeral extends StatelessWidget {
  const _Numeral({
    required this.value,
    required this.color,
    required this.size,
  });

  final int value;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: FittedBox(
          child: Text(
            '$value',
            style: PrimarTheme.display(
              size * 0.72,
              color: color,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({
    required this.letter,
    required this.color,
    required this.size,
  });

  final String letter;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: FittedBox(
          child: Text(
            letter,
            style: PrimarTheme.display(
              size * 0.72,
              color: color,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// A written word. Wider than tall, so it gets a slot of its own rather than
/// being squeezed into the square a single glyph uses.
class _Word extends StatelessWidget {
  const _Word({
    required this.word,
    required this.color,
    required this.size,
    this.withPicture = true,
  });

  final String word;
  final Color color;
  final double size;
  final bool withPicture;

  @override
  Widget build(BuildContext context) {
    final pictured = withPicture && WordPicture.canDraw(word);

    return SizedBox(
      width: size * 1.9,
      height: size * 1.5,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The picture carries the meaning; the letters carry the reading.
          // Without the picture a child is matching shapes, not reading.
          if (pictured) WordPicture(word: word, size: size * 0.86),
          Flexible(
            child: FittedBox(
              child: Text(
                word,
                style: PrimarTheme.display(
                  size * 0.52,
                  color: color,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Symbol extends StatelessWidget {
  const _Symbol({required this.symbol, required this.size});

  final MathSymbol symbol;
  final double size;

  @override
  Widget build(BuildContext context) {
    return switch (symbol) {
      MathSymbol.plus => OperatorGlyph(isAdd: true, size: size),
      MathSymbol.minus => OperatorGlyph(isAdd: false, size: size),
      MathSymbol.equals => EqualsGlyph(size: size),
      MathSymbol.unknown => _Unknown(size: size),
      MathSymbol.greater => _MoreMark(size: size, ascending: true),
      MathSymbol.less => _MoreMark(size: size, ascending: false),
    };
  }
}

/// The blank in a sum. Same dashed slot used for a missing shape, so the
/// meaning carries across subjects without explanation.
class _Unknown extends StatelessWidget {
  const _Unknown({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => MysterySlot(size: size * 2.1);
}

/// "Which is more" drawn as ascending bars.
///
/// A greater-than sign is a convention children meet years later; three rising
/// steps read as "more" without being taught.
class _MoreMark extends StatelessWidget {
  const _MoreMark({required this.size, required this.ascending});

  final double size;
  final bool ascending;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size * 1.6,
    height: size * 1.6,
    child: CustomPaint(painter: _MoreMarkPainter(ascending: ascending)),
  );
}

class _MoreMarkPainter extends CustomPainter {
  _MoreMarkPainter({required this.ascending});

  final bool ascending;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PrimarTheme.blue
      ..style = PaintingStyle.fill;

    final w = size.width / 5;
    final heights = ascending ? [0.35, 0.62, 0.92] : [0.92, 0.62, 0.35];

    for (var i = 0; i < 3; i++) {
      final h = size.height * heights[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * (i * 1.5 + 0.4), size.height - h, w, h),
          Radius.circular(w * 0.35),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MoreMarkPainter old) =>
      old.ascending != ascending;
}

/// A sound, made visible.
///
/// A big friendly speaker that plays the phrase and plays it again on every
/// press. The replay is the point: the old blank box gave a child exactly one
/// chance to catch a sound, and a child who looked away, or whose phone was in
/// a noisy room, had no way back to the question.
class _Listen extends StatefulWidget {
  const _Listen({required this.phraseId, required this.size});

  final String phraseId;
  final double size;

  @override
  State<_Listen> createState() => _ListenState();
}

class _ListenState extends State<_Listen> with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void didUpdateWidget(covariant _Listen old) {
    super.didUpdateWidget(old);
    // A new question means a new sound; the previous one is gone.
    if (old.phraseId != widget.phraseId) _ring.forward(from: 0);
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  void _play() {
    PrimarVoice.instance.chime(Sfx.tap);
    PrimarVoice.instance.say(VoiceLines.byId(widget.phraseId));
    _ring.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.size * 1.5;

    return GestureDetector(
      onTap: _play,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: d,
        height: d,
        child: AnimatedBuilder(
          animation: _ring,
          builder: (context, child) =>
              CustomPaint(painter: _ListenPainter(_ring.value), child: child),
          child: Center(
            child: Icon(
              Icons.volume_up_rounded,
              size: d * 0.42,
              color: PrimarTheme.answerInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _ListenPainter extends CustomPainter {
  _ListenPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.34;

    canvas.drawCircle(c, r, Paint()..color = PrimarTheme.tintBlue);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = PrimarTheme.blue.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.035,
    );

    // Two rings travelling outward, so the button reads as *making a sound*
    // rather than as an icon of a speaker.
    for (final phase in [t, (t + 0.5) % 1.0]) {
      final spread = r + phase * r * 0.85;
      canvas.drawCircle(
        c,
        spread,
        Paint()
          ..color = PrimarTheme.blue.withValues(alpha: 0.42 * (1 - phase))
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.03,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ListenPainter old) => old.t != t;
}
