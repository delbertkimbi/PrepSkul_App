import 'dart:math';

import 'figure.dart';
import 'items.dart' as shapes;
import 'literacy.dart';
import 'numeracy.dart';

/// What a child can be measured on.
///
/// Every subject produces the same [PrimarItem], so the staircase, the session
/// loop, the renderer and the mastery pipeline are written once and shared.
/// Adding reading or spelling later means adding a generator here, not a second
/// version of everything.
enum Subject { shapes, numeracy, reading }

/// The order a parent sees them in.
///
/// Reading first because it is the one the engine actually drives and the one
/// this product exists for. Kept separate from the enum's own order so that
/// changing what a parent sees first never touches anything that has been
/// written to disk.
const List<Subject> subjectOrder = [Subject.reading, Subject.numeracy, Subject.shapes];

extension SubjectMeta on Subject {
  /// Kept for callers that predate locale support. Reading in French must use
  /// [topicIdFor] — mastery written to the English node for a child learning in
  /// French would merge two different sets of letter sounds into one score.
  String get topicId => topicIdFor('en');

  String topicIdFor(String locale) => switch (this) {
        Subject.shapes => shapeTopicId,
        Subject.numeracy => numeracyTopicId,
        Subject.reading => locale == 'fr' ? literacyTopicIdFr : literacyTopicIdEn,
      };

  /// Shown to the parent choosing what to measure. Never to the child.
  /// What a parent chooses between.
  ///
  /// "Shapes" was too narrow a name for what that engine is actually for —
  /// putting things together, taking them apart, spotting what is missing. It
  /// is thinking, and it is where stories and everyday reasoning belong as they
  /// arrive. Calling it "Other" is honest about that and leaves room; calling
  /// it "Shapes" quietly promised a geometry lesson.
  String label(String locale) => switch (this) {
        Subject.reading => locale == 'fr' ? 'Lecture' : 'Reading',
        Subject.numeracy => locale == 'fr' ? 'Maths' : 'Math',
        Subject.shapes => locale == 'fr' ? 'Autre' : 'Other',
      };

  String blurb(String locale) => switch (this) {
        Subject.reading => locale == 'fr'
            ? 'Lettres, sons et premiers mots'
            : 'Letters, sounds and first words',
        Subject.numeracy => locale == 'fr'
            ? 'Compter, comparer, additionner'
            : 'Counting, comparing, adding and taking away',
        Subject.shapes => locale == 'fr'
            ? 'Formes, motifs et raisonnement'
            : 'Shapes, patterns and thinking',
      };
}

const String shapeTopicId = shapes.shapeTopicId;

/// Bridges the shape engine's own item type into the shared one.
PrimarItem _fromShapeItem(shapes.Item item) => shapes.primarFromShapeItem(item);

/// How many choices a child is offered at a given level.
///
/// Four options put the guessing floor at 25%, which is why the very weakest
/// children were sitting near 39% correct even after the staircase had dropped
/// them as far as it could go: level 1 was still too hard, and there was
/// nowhere further down. The content floor sat above the floor of the
/// population this exists for.
///
/// Two choices at the bottom is what early-years assessment actually does. It
/// is not a difficulty cheat — a child still has to discriminate — but it puts
/// a real success within reach of a child who currently fails two in three.
int optionsForLevel(int level) {
  if (level <= 2) return 2;
  if (level == 3) return 3;
  return 4;
}

/// Trims an item to the number of choices its level calls for.
///
/// The answer is always kept, and the distractors kept are the ones *closest*
/// to it, so a shorter list is an easier guess but never an easier question.
PrimarItem _withOptionCount(PrimarItem item, int count) {
  if (item.options.length <= count) return item;

  final answer = item.options[item.answerIndex];
  final others = <Figure>[];
  for (var i = 0; i < item.options.length; i++) {
    if (i != item.answerIndex) others.add(item.options[i]);
  }

  final kept = <Figure>[answer, ...others.take(count - 1)];
  // Keep the answer's position varied rather than always first.
  final at = item.id.hashCode.abs() % kept.length;
  final shuffled = [...kept]
    ..removeAt(0)
    ..insert(at, answer);

  return PrimarItem(
    id: item.id,
    level: item.level,
    topicId: item.topicId,
    prompt: item.prompt,
    options: shuffled,
    answerIndex: at,
    spoken: item.spoken,
    // Dropping this was silently stripping the explanation from every item at
    // levels 1–3 — exactly the levels the weakest children live at.
    teach: item.teach,
    // Same trap: this rebuild has to carry every field forward or the feature
    // that set it silently stops existing below level four.
    interaction: item.interaction,
    sayTarget: item.sayTarget,
  );
}

PrimarItem generateForSubject(
  Subject subject,
  int level,
  Random rng, [
  int index = 0,
  String locale = 'en',
]) {
  final item = switch (subject) {
    Subject.shapes => _fromShapeItem(shapes.generateItem(level, rng, index)),
    Subject.numeracy => generateNumeracyItem(level, rng, index),
    // Locale was accepted by the literacy generator and never passed to it, so
    // a French session silently taught English letter sounds. The picker was
    // not the only thing missing — the content underneath it was English too.
    Subject.reading => generateLiteracyItem(level, rng, index: index, locale: locale),
  };
  return _withOptionCount(item, optionsForLevel(level));
}

/// The worked examples shown before a child's first item in each subject.
List<PrimarItem> demonstrationsFor(Subject subject, [String locale = 'en']) {
  return switch (subject) {
    Subject.shapes => shapes.demonstrationItems().map(_demoFromShape).toList(),
    Subject.numeracy => _numeracyDemos(),
    Subject.reading => _readingDemos(locale),
  };
}

PrimarItem _demoFromShape(shapes.Item item) {
  return PrimarItem(
    id: item.id,
    level: item.level,
    topicId: shapeTopicId,
    prompt: [
      ShapeFigure(item.operandA),
      SymbolFigure(item.op == shapes.Operation.add ? MathSymbol.plus : MathSymbol.minus),
      ShapeFigure(item.operandB),
      const SymbolFigure(MathSymbol.equals),
    ],
    // A demonstration shows the answer rather than asking for it.
    options: [ShapeFigure(item.answer)],
    answerIndex: 0,
    spoken: item.op == shapes.Operation.add ? 'these_make_this' : 'take_away',
  );
}

/// Two worked examples: the same letter twice, then a spoken letter matched to
/// its shape. Reading cannot be demonstrated silently, so these lean on the
/// voice rather than on animation alone.
List<PrimarItem> _readingDemos(String locale) {
  final fr = locale == 'fr';
  final topic = fr ? literacyTopicIdFr : literacyTopicIdEn;
  // The second demonstration says a letter's sound aloud, so it has to be a
  // letter that exists in the language being taught with the sound that
  // language gives it. /sss/ happens to be shared; the first letter is not.
  final first = fr ? 'a' : 'm';
  final firstSound = fr ? 'ah' : 'mmm';

  return [
    PrimarItem(
      id: 'demo-r0',
      level: 1,
      topicId: topic,
      prompt: [LetterFigure(first), const SymbolFigure(MathSymbol.equals)],
      options: [LetterFigure(first)],
      answerIndex: 0,
      spoken: 'find_the_same',
    ),
    PrimarItem(
      id: 'demo-r1',
      level: 1,
      topicId: topic,
      prompt: [LetterFigure(first), const SymbolFigure(MathSymbol.equals)],
      options: [LetterFigure(first)],
      answerIndex: 0,
      spoken: 'sound:$firstSound',
    ),
  ];
}

/// Three worked sums: count, join, separate. Enough for a child to infer the
/// rule without a word of instruction.
List<PrimarItem> _numeracyDemos() {
  return const [
    PrimarItem(
      id: 'demo-n0',
      level: 1,
      topicId: numeracyTopicId,
      prompt: [QuantityFigure(3), SymbolFigure(MathSymbol.equals)],
      options: [NumeralFigure(3)],
      answerIndex: 0,
      spoken: 'how_many',
    ),
    PrimarItem(
      id: 'demo-n1',
      level: 1,
      topicId: numeracyTopicId,
      prompt: [
        QuantityFigure(2),
        SymbolFigure(MathSymbol.plus),
        QuantityFigure(3),
        SymbolFigure(MathSymbol.equals),
      ],
      options: [NumeralFigure(5)],
      answerIndex: 0,
      spoken: 'how_many_altogether',
    ),
    PrimarItem(
      id: 'demo-n2',
      level: 1,
      topicId: numeracyTopicId,
      prompt: [
        QuantityFigure(5),
        SymbolFigure(MathSymbol.minus),
        QuantityFigure(2),
        SymbolFigure(MathSymbol.equals),
      ],
      options: [NumeralFigure(3)],
      answerIndex: 0,
      spoken: 'how_many_left',
    ),
  ];
}
