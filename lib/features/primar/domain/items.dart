import 'dart:math';

import 'figure.dart';
import 'strokes.dart';

/// Item generation.
///
/// Items are generated to hit a requested difficulty level (1–10) rather than
/// generated randomly and scored afterwards. The staircase asks for a level and
/// gets an item that genuinely sits there, which is what makes the resulting
/// mastery number worth trusting.
///
/// Zero model calls, zero marginal cost, unlimited items.

enum Operation { add, subtract }

class Item {
  const Item({
    required this.id,
    required this.level,
    required this.op,
    required this.operandA,
    required this.operandB,
    required this.answer,
    required this.options,
    required this.answerIndex,
  });

  final String id;
  final int level;
  final Operation op;
  final Shape operandA;
  final Shape operandB;
  final Shape answer;

  /// Answer plus three distractors, already shuffled.
  final List<Shape> options;
  final int answerIndex;
}

class _LevelSpec {
  const _LevelSpec({
    required this.ops,
    required this.minWeight,
    required this.maxWeight,
    required this.allowCurves,
    required this.targetDistractorDistance,
  });

  final List<Operation> ops;
  final int minWeight;
  final int maxWeight;
  final bool allowCurves;

  /// Smaller = distractors sit closer to the answer = harder discrimination.
  final int targetDistractorDistance;
}

const Map<int, _LevelSpec> _levels = {
  1: _LevelSpec(ops: [Operation.add], minWeight: 2, maxWeight: 2, allowCurves: false, targetDistractorDistance: 2),
  2: _LevelSpec(ops: [Operation.add], minWeight: 2, maxWeight: 3, allowCurves: true, targetDistractorDistance: 2),
  3: _LevelSpec(ops: [Operation.add], minWeight: 3, maxWeight: 4, allowCurves: true, targetDistractorDistance: 2),
  4: _LevelSpec(ops: [Operation.add], minWeight: 4, maxWeight: 4, allowCurves: true, targetDistractorDistance: 1),
  5: _LevelSpec(ops: [Operation.add, Operation.subtract], minWeight: 3, maxWeight: 4, allowCurves: true, targetDistractorDistance: 2),
  6: _LevelSpec(ops: [Operation.subtract], minWeight: 4, maxWeight: 4, allowCurves: true, targetDistractorDistance: 2),
  7: _LevelSpec(ops: [Operation.add, Operation.subtract], minWeight: 4, maxWeight: 5, allowCurves: true, targetDistractorDistance: 1),
  8: _LevelSpec(ops: [Operation.subtract], minWeight: 5, maxWeight: 6, allowCurves: true, targetDistractorDistance: 1),
  9: _LevelSpec(ops: [Operation.add, Operation.subtract], minWeight: 5, maxWeight: 6, allowCurves: true, targetDistractorDistance: 1),
  10: _LevelSpec(ops: [Operation.subtract], minWeight: 6, maxWeight: 6, allowCurves: true, targetDistractorDistance: 1),
};

int clampLevel(num n) => n.round().clamp(1, 10);

T _pick<T>(List<T> list, Random rng) => list[rng.nextInt(list.length)];

List<T> _shuffled<T>(List<T> list, Random rng) {
  final out = List<T>.from(list);
  for (var i = out.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = out[i];
    out[i] = out[j];
    out[j] = tmp;
  }
  return out;
}

List<Shape> _buildDistractors(
  Shape answer,
  Shape operandA,
  Shape operandB,
  Operation op,
  _LevelSpec spec,
  Random rng,
) {
  final candidates = <Shape>[];
  final seen = <String>{shapeKey(answer)};

  void offer(Shape shape) {
    if (shape.isEmpty) return;
    final key = shapeKey(shape);
    if (seen.contains(key)) return;
    seen.add(key);
    candidates.add(shape);
  }

  // The mistake a learner actually makes: applying the wrong operation.
  offer(op == Operation.subtract ? operandA : (operandA.isNotEmpty ? operandA : operandB));
  if (op == Operation.add) offer(operandB);

  // One stroke too many.
  final unused = allStrokeIds
      .where((id) => !answer.contains(id) && (spec.allowCurves || strokes[id]!.kind != StrokeKind.curve))
      .toList();
  for (final extra in _shuffled(unused, rng).take(4)) {
    offer(shapeUnion(answer, [extra]));
  }

  // One stroke short.
  if (answer.length > 1) {
    for (final drop in _shuffled(answer, rng).take(3)) {
      offer(shapeDifference(answer, [drop]));
    }
  }

  // A stroke swapped for one it is easy to confuse with — the near miss.
  for (final s in _shuffled(answer, rng)) {
    for (final twin in strokes[s]!.confusableWith) {
      if (!answer.contains(twin)) {
        offer(shapeUnion(shapeDifference(answer, [s]), [twin]));
      }
    }
  }

  // Prefer distractors sitting at the level's intended discrimination distance.
  final ranked = candidates
      .map((shape) => MapEntry(shape, (shapeDistance(shape, answer) - spec.targetDistractorDistance).abs()))
      .toList()
    ..sort((x, y) => x.value.compareTo(y.value));

  final chosen = <Shape>[];
  for (final entry in ranked) {
    if (chosen.length >= 3) break;
    chosen.add(entry.key);
  }

  // Last resort, so an item is never malformed.
  while (chosen.length < 3) {
    final filler = shapeUnion(answer, [_pick(allStrokeIds, rng)]);
    final clashes = chosen.any((c) => shapesEqual(c, filler)) || shapesEqual(filler, answer);
    chosen.add(clashes ? _pick(composites, rng).strokes : filler);
  }

  return chosen.take(3).toList();
}

List<Shape> _splitShape(Shape shape, Random rng) {
  final shuffled = _shuffled(shape, rng);
  final cut = 1 + rng.nextInt(shuffled.length - 1);
  return [shuffled.sublist(0, cut), shuffled.sublist(cut)];
}

Item generateItem(int level, Random rng, [int index = 0]) {
  final lvl = clampLevel(level);
  final spec = _levels[lvl]!;

  final pool = composites.where((c) {
    if (c.weight < spec.minWeight || c.weight > spec.maxWeight) return false;
    if (!spec.allowCurves && shapeHasKind(c.strokes, StrokeKind.curve)) return false;
    return c.strokes.length >= 2;
  }).toList();

  final composite = _pick(pool.isNotEmpty ? pool : composites, rng);
  final op = _pick(spec.ops, rng);

  Shape operandA;
  Shape operandB;
  Shape answer;

  if (op == Operation.add) {
    final parts = _splitShape(composite.strokes, rng);
    operandA = parts[0];
    operandB = parts[1];
    answer = shapeUnion(operandA, operandB);
  } else {
    // Remove a proper, non-empty subset so something always remains.
    final removable = _shuffled(composite.strokes, rng);
    final removeCount = 1 + rng.nextInt(max(1, composite.strokes.length - 2));
    operandB = removable.sublist(0, removeCount);
    operandA = composite.strokes;
    answer = shapeDifference(operandA, operandB);
    if (answer.isEmpty) {
      operandB = [removable.first];
      answer = shapeDifference(operandA, operandB);
    }
  }

  final distractors = _buildDistractors(answer, operandA, operandB, op, spec, rng);
  final options = _shuffled([answer, ...distractors], rng);
  final answerIndex = options.indexWhere((o) => shapesEqual(o, answer));

  return Item(
    id: 'L$lvl-$index-${shapeKey(answer)}',
    level: lvl,
    op: op,
    operandA: operandA,
    operandB: operandB,
    answer: answer,
    options: options,
    answerIndex: answerIndex,
  );
}

/// The three worked examples shown before a child's first item. The rule is
/// taught by watching shapes come together — never by reading an instruction.
List<Item> demonstrationItems() {
  const scripted = [
    ('circle', Operation.add),
    ('plus', Operation.add),
    ('square', Operation.subtract),
  ];

  final out = <Item>[];
  for (var i = 0; i < scripted.length; i++) {
    final (compositeId, op) = scripted[i];
    final composite = composites.firstWhere((c) => c.id == compositeId, orElse: () => composites.first);

    if (op == Operation.add) {
      final half = (composite.strokes.length / 2).ceil();
      final operandA = composite.strokes.sublist(0, half);
      final operandB = composite.strokes.sublist(half);
      out.add(Item(
        id: 'demo-$i',
        level: 1,
        op: Operation.add,
        operandA: operandA,
        operandB: operandB,
        answer: shapeUnion(operandA, operandB),
        options: const [],
        answerIndex: -1,
      ));
    } else {
      const operandB = <StrokeId>[StrokeId.top];
      out.add(Item(
        id: 'demo-$i',
        level: 1,
        op: Operation.subtract,
        operandA: composite.strokes,
        operandB: operandB,
        answer: shapeDifference(composite.strokes, operandB),
        options: const [],
        answerIndex: -1,
      ));
    }
  }
  return out;
}

/// Which shape skill each generator configuration serves.
enum _ShapeSkillForm {
  composeBasic,
  composeCurve,
  composeMulti,
  discriminate,
  decompose,
  flex,
}

const Map<String, _ShapeSkillForm> _formForSkill = {
  'shape.compose.basic': _ShapeSkillForm.composeBasic,
  'shape.compose.curve': _ShapeSkillForm.composeCurve,
  'shape.compose.multi': _ShapeSkillForm.composeMulti,
  'shape.discriminate': _ShapeSkillForm.discriminate,
  'shape.decompose': _ShapeSkillForm.decompose,
  'shape.flex': _ShapeSkillForm.flex,
};

const String shapeTopicId = 'foundational.visual-reasoning.shape-composition';

bool canGenerateShapeSkill(String skillId) => _formForSkill.containsKey(skillId);

int _levelForForm(_ShapeSkillForm form, int spread) => clampLevel(switch (form) {
      _ShapeSkillForm.composeBasic => 1,
      _ShapeSkillForm.composeCurve => 2,
      _ShapeSkillForm.composeMulti => 3,
      _ShapeSkillForm.discriminate => 4,
      _ShapeSkillForm.decompose => 6,
      _ShapeSkillForm.flex => 7,
    } +
        spread -
        1);

/// One question for a named shape skill.
Item generateShapeItemForSkill(
  String skillId,
  Random rng, {
  int index = 0,
  int spread = 1,
}) {
  final form = _formForSkill[skillId];
  if (form == null) {
    throw ArgumentError('no generator for shape skill $skillId');
  }
  return generateItem(_levelForForm(form, spread), rng, index);
}

/// Bridges a shape [Item] into the shared session type.
PrimarItem primarFromShapeItem(Item item) {
  return PrimarItem(
    id: item.id,
    level: item.level,
    topicId: shapeTopicId,
    prompt: [
      ShapeFigure(item.operandA),
      SymbolFigure(item.op == Operation.add ? MathSymbol.plus : MathSymbol.minus),
      ShapeFigure(item.operandB),
      const SymbolFigure(MathSymbol.equals),
    ],
    options: item.options.map<Figure>((o) => ShapeFigure(o)).toList(),
    answerIndex: item.answerIndex,
    spoken: 'your_turn',
    teach: const ['it_is_this_one', 'these_make_this'],
  );
}
