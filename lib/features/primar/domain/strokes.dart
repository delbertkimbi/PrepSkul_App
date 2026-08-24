import 'dart:ui';

/// The visual vocabulary.
///
/// Every shape a child sees is a SET of strokes drawn on a shared 100x100 grid.
/// Because shapes are sets, "add" is union and "subtract" is difference — the
/// whole item engine is set arithmetic over this table, with no text anywhere.
///
/// Nothing here is language-dependent, which is the point: identical items work
/// for Anglophone and Francophone learners with no translation layer.
///
/// Strokes are built as [Path]s rather than parsed from SVG so there is no
/// parser dependency and no per-frame string work.

enum StrokeId {
  top,
  bottom,
  left,
  right,
  vert,
  horiz,
  diagA,
  diagB,
  arcL,
  arcR,
  arcT,
  arcB,
  chevU,
  chevD,
  triL,
  triR,
  innerBox,
  innerRing,
}

enum StrokeKind { line, diagonal, curve }

/// Frame bounds for the shared drawing grid.
const double _a = 22;
const double _z = 78;
const double _m = 50;

Path _line(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  return path;
}

Path _arc(Offset from, Offset to, double radius, {required bool clockwise}) {
  return Path()
    ..moveTo(from.dx, from.dy)
    ..arcToPoint(to, radius: Radius.circular(radius), clockwise: clockwise);
}

class Stroke {
  const Stroke(this.id, this.build, this.kind, this.confusableWith);

  final StrokeId id;
  final Path Function() build;
  final StrokeKind kind;
  final List<StrokeId> confusableWith;
}

final Map<StrokeId, Stroke> strokes = {
  StrokeId.top: Stroke(
    StrokeId.top,
    () => _line(const [Offset(_a, _a), Offset(_z, _a)]),
    StrokeKind.line,
    const [StrokeId.bottom, StrokeId.horiz],
  ),
  StrokeId.bottom: Stroke(
    StrokeId.bottom,
    () => _line(const [Offset(_a, _z), Offset(_z, _z)]),
    StrokeKind.line,
    const [StrokeId.top, StrokeId.horiz],
  ),
  StrokeId.left: Stroke(
    StrokeId.left,
    () => _line(const [Offset(_a, _a), Offset(_a, _z)]),
    StrokeKind.line,
    const [StrokeId.right, StrokeId.vert],
  ),
  StrokeId.right: Stroke(
    StrokeId.right,
    () => _line(const [Offset(_z, _a), Offset(_z, _z)]),
    StrokeKind.line,
    const [StrokeId.left, StrokeId.vert],
  ),
  StrokeId.vert: Stroke(
    StrokeId.vert,
    () => _line(const [Offset(_m, _a), Offset(_m, _z)]),
    StrokeKind.line,
    const [StrokeId.left, StrokeId.right],
  ),
  StrokeId.horiz: Stroke(
    StrokeId.horiz,
    () => _line(const [Offset(_a, _m), Offset(_z, _m)]),
    StrokeKind.line,
    const [StrokeId.top, StrokeId.bottom],
  ),
  StrokeId.diagA: Stroke(
    StrokeId.diagA,
    () => _line(const [Offset(_a, _z), Offset(_z, _a)]),
    StrokeKind.diagonal,
    const [StrokeId.diagB],
  ),
  StrokeId.diagB: Stroke(
    StrokeId.diagB,
    () => _line(const [Offset(_a, _a), Offset(_z, _z)]),
    StrokeKind.diagonal,
    const [StrokeId.diagA],
  ),
  StrokeId.arcL: Stroke(
    StrokeId.arcL,
    () => _arc(const Offset(_m, _a), const Offset(_m, _z), 28, clockwise: false),
    StrokeKind.curve,
    const [StrokeId.arcR],
  ),
  StrokeId.arcR: Stroke(
    StrokeId.arcR,
    () => _arc(const Offset(_m, _a), const Offset(_m, _z), 28, clockwise: true),
    StrokeKind.curve,
    const [StrokeId.arcL],
  ),

  /// Deliberately radius 40, not 28.
  ///
  /// At radius 28 these are exact semicircles of the very same circle that
  /// arcL + arcR draw, so adding one to a shape that already contains the
  /// circle paints nothing at all — two different shapes render pixel-identical
  /// and a child gets marked wrong for an answer that looked correct. The
  /// shallower radius makes the horizontal pair a visibly distinct lens.
  StrokeId.arcT: Stroke(
    StrokeId.arcT,
    () => _arc(const Offset(_a, _m), const Offset(_z, _m), 40, clockwise: true),
    StrokeKind.curve,
    const [StrokeId.arcB],
  ),
  StrokeId.arcB: Stroke(
    StrokeId.arcB,
    () => _arc(const Offset(_a, _m), const Offset(_z, _m), 40, clockwise: false),
    StrokeKind.curve,
    const [StrokeId.arcT],
  ),
  StrokeId.chevU: Stroke(
    StrokeId.chevU,
    () => _line(const [Offset(_a, 64), Offset(_m, 32), Offset(_z, 64)]),
    StrokeKind.diagonal,
    const [StrokeId.chevD],
  ),
  StrokeId.chevD: Stroke(
    StrokeId.chevD,
    () => _line(const [Offset(_a, 36), Offset(_m, 68), Offset(_z, 36)]),
    StrokeKind.diagonal,
    const [StrokeId.chevU],
  ),
  StrokeId.triL: Stroke(
    StrokeId.triL,
    () => _line(const [Offset(_m, 24), Offset(24, 74)]),
    StrokeKind.diagonal,
    const [StrokeId.triR, StrokeId.diagA],
  ),
  StrokeId.triR: Stroke(
    StrokeId.triR,
    () => _line(const [Offset(_m, 24), Offset(76, 74)]),
    StrokeKind.diagonal,
    const [StrokeId.triL, StrokeId.diagB],
  ),
  StrokeId.innerBox: Stroke(
    StrokeId.innerBox,
    () => _line(const [
      Offset(38, 38),
      Offset(62, 38),
      Offset(62, 62),
      Offset(38, 62),
      Offset(38, 38),
    ]),
    StrokeKind.line,
    const [StrokeId.innerRing],
  ),
  StrokeId.innerRing: Stroke(
    StrokeId.innerRing,
    () => Path()..addOval(Rect.fromCircle(center: const Offset(_m, _m), radius: 14)),
    StrokeKind.curve,
    const [StrokeId.innerBox],
  ),
};

const List<StrokeId> allStrokeIds = StrokeId.values;

/// A shape is just a set of strokes. Order never matters.
typedef Shape = List<StrokeId>;

Shape canonical(Iterable<StrokeId> shape) {
  final present = shape.toSet();
  return allStrokeIds.where(present.contains).toList(growable: false);
}

String shapeKey(Shape shape) => canonical(shape).map((s) => s.name).join('+');

bool shapesEqual(Shape a, Shape b) => shapeKey(a) == shapeKey(b);

Shape shapeUnion(Shape a, Shape b) => canonical({...a, ...b});

Shape shapeDifference(Shape a, Shape b) {
  final remove = b.toSet();
  return canonical(a.where((s) => !remove.contains(s)));
}

/// How many strokes differ between two shapes — the distractor-difficulty metric.
int shapeDistance(Shape a, Shape b) {
  final setA = a.toSet();
  final setB = b.toSet();
  var d = 0;
  for (final s in setA) {
    if (!setB.contains(s)) d++;
  }
  for (final s in setB) {
    if (!setA.contains(s)) d++;
  }
  return d;
}

bool shapeHasKind(Shape shape, StrokeKind kind) =>
    shape.any((id) => strokes[id]!.kind == kind);

/// Whole shapes worth building toward. Composition rules stay legible because
/// every target is something a child can recognise once it snaps together.
class Composite {
  const Composite(this.id, this.strokes, this.weight);

  final String id;
  final Shape strokes;

  /// Roughly how many strokes a learner must hold in mind at once.
  final int weight;
}

const List<Composite> composites = [
  Composite('circle', [StrokeId.arcL, StrokeId.arcR], 2),
  Composite('plus', [StrokeId.vert, StrokeId.horiz], 2),
  Composite('cross', [StrokeId.diagA, StrokeId.diagB], 2),
  Composite('diamond', [StrokeId.chevU, StrokeId.chevD], 2),
  Composite('lens', [StrokeId.arcT, StrokeId.arcB], 2),
  Composite('corner', [StrokeId.left, StrokeId.bottom], 2),
  Composite('triangle', [StrokeId.triL, StrokeId.triR, StrokeId.bottom], 3),
  Composite('channel', [StrokeId.left, StrokeId.right, StrokeId.bottom], 3),
  Composite('square', [StrokeId.top, StrokeId.bottom, StrokeId.left, StrokeId.right], 4),
  Composite('squarePlus', [
    StrokeId.top,
    StrokeId.bottom,
    StrokeId.left,
    StrokeId.right,
    StrokeId.vert,
    StrokeId.horiz,
  ], 6),
  Composite('squareCross', [
    StrokeId.top,
    StrokeId.bottom,
    StrokeId.left,
    StrokeId.right,
    StrokeId.diagA,
    StrokeId.diagB,
  ], 6),
  Composite('circleCross', [StrokeId.arcL, StrokeId.arcR, StrokeId.diagA, StrokeId.diagB], 4),
  Composite('circlePlus', [StrokeId.arcL, StrokeId.arcR, StrokeId.vert, StrokeId.horiz], 4),
  Composite('nestedBox', [
    StrokeId.top,
    StrokeId.bottom,
    StrokeId.left,
    StrokeId.right,
    StrokeId.innerBox,
  ], 5),
  Composite('nestedRing', [StrokeId.arcL, StrokeId.arcR, StrokeId.innerRing], 3),
  Composite('boxedRing', [
    StrokeId.top,
    StrokeId.bottom,
    StrokeId.left,
    StrokeId.right,
    StrokeId.innerRing,
  ], 5),
  Composite('star', [StrokeId.vert, StrokeId.horiz, StrokeId.diagA, StrokeId.diagB], 4),
];
