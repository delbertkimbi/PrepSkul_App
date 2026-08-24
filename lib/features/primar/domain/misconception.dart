import 'figure.dart';

/// What a child got wrong, not merely that they did.
///
/// A difficulty level says how hard to make the next question. It says nothing
/// about *why* this child missed this one, and two children sitting on the same
/// level can be failing for completely different reasons: one reverses b and d,
/// another counts correctly but lands one short every time. Teaching them the
/// same way helps neither.
///
/// This is deliberately rule-based rather than model-driven, so it runs during
/// an internet shutdown exactly as it runs on wifi. The rules encode errors that
/// early-years teachers already recognise by name.
enum Misconception {
  /// b/d, p/q. The same letter reflected — a spatial confusion, not a phonics
  /// one, and the most common early-reading difficulty there is.
  letterReversal,

  /// m/n, u/n, i/l. Similar shapes that are not reflections.
  letterShape,

  /// The child heard the sound but chose a letter that makes a different one.
  letterSound,

  /// Answered one away. Almost always a counting slip rather than not knowing —
  /// the child counted, and lost or gained one along the way.
  offByOne,

  /// Answered with one of the numbers in the question. The classic "answered
  /// the thing in front of me" move, and a sign the operation itself has not
  /// landed yet.
  operandEcho,

  /// Added when the question asked to take away, or the reverse.
  wrongOperation,

  /// Off by more than one on a count. Suggests the quantity was never counted,
  /// only guessed at.
  countingUnstable,

  /// Nothing recognisable. Kept honest rather than forced into a category.
  unclear,
}

extension MisconceptionTeaching on Misconception {
  /// The extra line spoken when this pattern keeps recurring, on top of the
  /// item's own teaching.
  String? get targetedPhrase => switch (this) {
        Misconception.letterReversal => 'watch_which_way',
        Misconception.letterShape => 'look_at_the_shape',
        Misconception.letterSound => 'listen_to_the_sound',
        Misconception.offByOne => 'count_one_by_one',
        Misconception.operandEcho => 'listen',
        Misconception.wrongOperation => 'listen',
        Misconception.countingUnstable => 'count_one_by_one',
        Misconception.unclear => null,
      };
}

/// Letters that are one another's mirror image.
const Map<String, List<String>> _reversals = {
  'b': ['d', 'p'],
  'd': ['b', 'q'],
  'p': ['q', 'b'],
  'q': ['p', 'd'],
};

int? _numberOf(Figure f) => switch (f) {
      NumeralFigure(:final value) => value,
      QuantityFigure(:final count) => count,
      _ => null,
    };

String? _textOf(Figure f) => switch (f) {
      LetterFigure(:final letter) => letter,
      WordFigure(:final word) => word,
      _ => null,
    };

/// Classifies a single wrong answer.
Misconception classifyMiss(PrimarItem item, int chosenIndex) {
  if (chosenIndex < 0 || chosenIndex >= item.options.length) {
    return Misconception.unclear;
  }

  final chosen = item.options[chosenIndex];
  final answer = item.options[item.answerIndex];

  // --- letters and words -------------------------------------------------
  final chosenText = _textOf(chosen);
  final answerText = _textOf(answer);
  if (chosenText != null && answerText != null) {
    if (chosenText.length == 1 && answerText.length == 1) {
      if (_reversals[answerText]?.contains(chosenText) ?? false) {
        return Misconception.letterReversal;
      }
      // A sound prompt that was missed is about the sound; a shape prompt that
      // was missed is about the shape.
      final askedBySound = item.spoken?.startsWith('sound:') ?? false;
      return askedBySound ? Misconception.letterSound : Misconception.letterShape;
    }
    return Misconception.unclear;
  }

  // --- numbers -----------------------------------------------------------
  final chosenNum = _numberOf(chosen);
  final answerNum = _numberOf(answer);
  if (chosenNum == null || answerNum == null) return Misconception.unclear;

  final operands = item.prompt.map(_numberOf).whereType<int>().toList();
  final symbols = item.prompt.whereType<SymbolFigure>().map((s) => s.symbol).toList();

  // Checked before off-by-one: echoing an operand that happens to sit one away
  // is still an echo, and needs different teaching.
  if (operands.contains(chosenNum) && !operands.contains(answerNum)) {
    return Misconception.operandEcho;
  }

  if (operands.length == 2) {
    final sum = operands[0] + operands[1];
    final difference = (operands[0] - operands[1]).abs();
    if (symbols.contains(MathSymbol.plus) && chosenNum == difference && answerNum == sum) {
      return Misconception.wrongOperation;
    }
    if (symbols.contains(MathSymbol.minus) && chosenNum == sum && answerNum == difference) {
      return Misconception.wrongOperation;
    }
  }

  final gap = (chosenNum - answerNum).abs();
  if (gap == 1) return Misconception.offByOne;
  if (gap >= 2) return Misconception.countingUnstable;

  return Misconception.unclear;
}

/// Counts what keeps going wrong across a session.
///
/// One mistake is noise. The same mistake three times is something to teach
/// against, and that threshold is the whole difference between reacting to a
/// slip and responding to a pattern.
class MisconceptionTracker {
  static const int _threshold = 3;

  final Map<Misconception, int> _counts = {};

  void record(PrimarItem item, int chosenIndex) {
    final m = classifyMiss(item, chosenIndex);
    if (m == Misconception.unclear) return;
    _counts[m] = (_counts[m] ?? 0) + 1;
  }

  Map<Misconception, int> get counts => Map.unmodifiable(_counts);

  /// The pattern worth teaching against, or null if nothing has recurred yet.
  Misconception? get dominant {
    Misconception? best;
    var bestCount = 0;
    for (final entry in _counts.entries) {
      if (entry.value >= _threshold && entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }

  /// A plain sentence for the parent's summary. Written to describe a habit,
  /// never a deficiency — a parent reads this about their own child.
  String? summaryFor(String name) => switch (dominant) {
        Misconception.letterReversal =>
          '$name is mixing up letters that are mirror images, like b and d. '
              'That is one of the most common steps in learning to read.',
        Misconception.letterShape =>
          '$name is still separating letters that look alike.',
        Misconception.letterSound =>
          '$name knows the letter shapes but is still linking them to sounds.',
        Misconception.offByOne =>
          '$name is counting, but often finishes one away. The counting is '
              'there — it is the last step that slips.',
        Misconception.operandEcho =>
          '$name is answering with one of the numbers in the question, which '
              'usually means the operation itself has not landed yet.',
        Misconception.wrongOperation =>
          '$name is adding when the question asks to take away, or the reverse.',
        Misconception.countingUnstable =>
          '$name is estimating quantities rather than counting them.',
        Misconception.unclear || null => null,
      };
}
