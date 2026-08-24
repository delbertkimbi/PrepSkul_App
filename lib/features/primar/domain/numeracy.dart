import 'dart:math';

import 'figure.dart';

/// Foundational numeracy.
///
/// This is the half of learning poverty that is measured in arithmetic, and the
/// progression follows how a child actually builds number sense: recognise a
/// small quantity, match it to a numeral, compare two groups, then join and
/// separate groups.
///
/// Every quantity is drawn as discrete marks, so a count is exact by
/// construction. Nothing here asks a model to draw seven of something and hope.
///
/// Distractors are the mistakes children really make — off by one above all,
/// then answering with one of the operands, then applying the wrong operation.
/// Random wrong answers would make items guessable and the mastery score noise.

const String numeracyTopicId = 'foundational.numeracy.number-sense';

enum _Form {
  countToNumeral,
  numeralToCount,
  compare,
  matchQuantities,
  orderQuantities,
  add,
  subtract,
  missingAddend,
}

class _NumLevel {
  const _NumLevel(this.forms, this.maxValue);
  final List<_Form> forms;
  final int maxValue;
}

/// Ten steps from "how many dots is this" to "what is missing from this sum".
/// Every level offers at least two forms, and from level three at least one of
/// them is something other than tapping a tile.
///
/// Laid out side by side, the first version of this table was ten rows of the
/// same screen: prompt, equals, four numerals to choose between. A child plays
/// fourteen items in a session, so that is one layout fourteen times — and
/// monotony is how a child stops coming back long before difficulty is.
///
/// Matching and ordering are not garnish here. Matching tests the
/// quantity–numeral relationship across a whole set at once, and ordering tests
/// sequence rather than a single pairwise judgement; both are things choosing
/// cannot ask. Spreading them across the range means a session mixes hand
/// movement with tapping wherever a child happens to be sitting.
const Map<int, _NumLevel> _levels = {
  1: _NumLevel([_Form.countToNumeral, _Form.numeralToCount], 3),
  2: _NumLevel([_Form.countToNumeral, _Form.numeralToCount, _Form.matchQuantities], 5),
  3: _NumLevel([_Form.countToNumeral, _Form.compare, _Form.matchQuantities], 6),
  4: _NumLevel(
      [_Form.numeralToCount, _Form.compare, _Form.matchQuantities, _Form.orderQuantities], 9),
  5: _NumLevel([_Form.compare, _Form.orderQuantities, _Form.add], 10),
  6: _NumLevel([_Form.add, _Form.matchQuantities, _Form.orderQuantities], 10),
  7: _NumLevel([_Form.add, _Form.subtract, _Form.orderQuantities], 12),
  8: _NumLevel([_Form.subtract, _Form.compare, _Form.orderQuantities], 15),
  9: _NumLevel([_Form.add, _Form.subtract, _Form.missingAddend], 18),
  10: _NumLevel([_Form.subtract, _Form.missingAddend, _Form.orderQuantities], 20),
};

int _clampLevel(num n) => n.round().clamp(1, 10);

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

/// How the voice should refer to a number while teaching.
///
/// Counting aloud stops at ten — both because the recorded catalogue stops
/// there and because a child working past ten should not be walked from one
/// again, which is the habit those levels exist to replace. Above ten the
/// number is simply named.
///
/// A helper rather than a guard at each call site: adding `compare` to level 8
/// silently pushed a count line to fourteen, and the next table edit would do
/// it again.
String _countOrName(int n) => n <= 10 ? 'count:$n' : 'number:$n';

/// Number words, for the optional speaking step.
///
/// Not a phrase id: this is matched against what a recogniser heard, so it has
/// to be the word a child would actually say. Stops at twenty because that is
/// where the content stops.
const List<String> _numberWords = [
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
  'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
  'sixteen', 'seventeen', 'eighteen', 'nineteen', 'twenty',
];

String? _sayNumber(int? n) =>
    n != null && n >= 0 && n < _numberWords.length ? _numberWords[n] : null;

bool _isSorted(List<int> xs) {
  for (var i = 1; i < xs.length; i++) {
    if (xs[i] < xs[i - 1]) return false;
  }
  return true;
}

/// Wrong answers a child would plausibly give, nearest miss first.
List<int> _numberDistractors(int answer, int maxValue, Random rng, {List<int> preferred = const []}) {
  final seen = <int>{answer};
  final out = <int>[];

  void offer(int v) {
    if (v < 0 || v > maxValue + 2 || seen.contains(v)) return;
    seen.add(v);
    out.add(v);
  }

  // Off by one dominates real errors at this age.
  offer(answer + 1);
  offer(answer - 1);
  // Then the operands themselves, which is the classic "answered the question
  // in front of me" mistake.
  for (final p in preferred) {
    offer(p);
  }
  offer(answer + 2);
  offer(answer - 2);

  // Only if the space is genuinely too small to fill three slots.
  var guard = 0;
  while (out.length < 3 && guard < 40) {
    offer(rng.nextInt(maxValue + 1));
    guard++;
  }
  return out.take(3).toList();
}

/// The skills the engine can ask for, and the form each one is asked in.
///
/// One skill, one form. The level ladder deliberately mixed forms at each step
/// to keep a session varied, which is right for a session and wrong for a
/// graph: it made a child's performance on "which pile is bigger" and on
/// "what is 3 and 2" land on the same number, so neither could be measured.
const Map<String, _Form> _formForSkill = {
  'num.count': _Form.countToNumeral,
  'num.numeral': _Form.numeralToCount,
  'num.compare': _Form.compare,
  'num.match': _Form.matchQuantities,
  'num.order': _Form.orderQuantities,
  'num.add': _Form.add,
  'num.subtract': _Form.subtract,
  'num.missing': _Form.missingAddend,
};

/// Whether the engine has a question for this numeracy skill.
bool canGenerateNumeracySkill(String skillId) =>
    _formForSkill.containsKey(skillId);

/// One question for a named numeracy skill.
///
/// [spread] widens the numbers as a child gets stronger at the *same* skill,
/// which is the job the level number used to do — except that difficulty now
/// moves within a skill instead of moving a child to a different one.
PrimarItem generateNumeracyItemForSkill(
  String skillId,
  Random rng, {
  int index = 0,
  int spread = 1,
}) {
  final form = _formForSkill[skillId];
  if (form == null) {
    throw ArgumentError('no generator for numeracy skill $skillId');
  }
  return _generate(_levelHintFor(form, spread), rng, index, form);
}

/// A level whose number range suits the form, nudged by [spread].
///
/// The form is forced regardless; this only picks how big the numbers get.
int _levelHintFor(_Form form, int spread) {
  final base = switch (form) {
    _Form.countToNumeral => 1,
    _Form.numeralToCount => 2,
    _Form.compare => 3,
    _Form.matchQuantities => 4,
    _Form.orderQuantities => 5,
    _Form.add => 6,
    _Form.subtract => 8,
    _Form.missingAddend => 9,
  };
  return _clampLevel(base + spread - 1);
}

PrimarItem generateNumeracyItem(int level, Random rng, [int index = 0]) =>
    _generate(level, rng, index, null);

PrimarItem _generate(int level, Random rng, int index, _Form? force) {
  final lvl = _clampLevel(level);
  final spec = _levels[lvl]!;
  final _Form form = force ?? _pick(spec.forms, rng);
  final maxV = spec.maxValue;

  List<Figure> prompt;
  List<Figure> options;
  int answerIndex;
  String? spoken;
  // Named and explained on a miss, so the child is taught rather than marked.
  List<String> teach = const [];

  // One kind of thing per item, chosen from the item's own seed.
  //
  // Shared across every quantity on screen on purpose: comparing four mangoes
  // to six footballs is a different and harder question than the one being
  // asked, and a child who gets it wrong has been tripped by the art rather
  // than by the number.
  final token = CountToken.things[rng.nextInt(CountToken.things.length)];
  QuantityFigure q(int n) => QuantityFigure(n, token: token);

  switch (form) {
    case _Form.countToNumeral:
      // How many marks are here? Answer in numerals.
      final n = 1 + rng.nextInt(maxV);
      prompt = [q(n), const SymbolFigure(MathSymbol.equals)];
      final values = _shuffled([n, ..._numberDistractors(n, maxV, rng)], rng);
      options = values.map<Figure>((v) => NumeralFigure(v)).toList();
      answerIndex = values.indexOf(n);
      spoken = 'how_many';
      // Counting aloud is the method, not decoration: a child who cannot yet
      // subitise gets there by hearing each mark counted.
      teach = ['lets_count', _countOrName(n), 'so_that_makes', 'number:$n'];

    case _Form.numeralToCount:
      // The same relationship in reverse, which is a genuinely different skill.
      final n = 1 + rng.nextInt(maxV);
      prompt = [NumeralFigure(n), const SymbolFigure(MathSymbol.equals)];
      final values = _shuffled([n, ..._numberDistractors(n, maxV, rng)], rng);
      options = values.map<Figure>((v) => q(v)).toList();
      answerIndex = values.indexOf(n);
      spoken = 'find_this_many';
      teach = ['number:$n', 'lets_count', _countOrName(n)];

    case _Form.compare:
      // Which group has the most.
      //
      // Every other option must be STRICTLY smaller than the answer. An earlier
      // version offered `answer + 1` as a near-miss distractor, which meant the
      // tile with the most marks was sometimes not the one marked correct — a
      // child who counted properly was told they were wrong.
      final target = 4 + rng.nextInt(max(1, maxV - 3));
      final lesser = <int>{};
      var guard = 0;
      while (lesser.length < 3 && guard < 60) {
        lesser.add(1 + rng.nextInt(target - 1));
        guard++;
      }
      // Only reachable if the range is tiny; walk down from the target instead.
      for (var v = target - 1; lesser.length < 3 && v >= 1; v--) {
        lesser.add(v);
      }

      final values = _shuffled([target, ...lesser.take(3)], rng);
      prompt = [const SymbolFigure(MathSymbol.greater)];
      options = values.map<Figure>((v) => q(v)).toList();
      answerIndex = values.indexOf(target);
      spoken = 'which_is_more';
      teach = ['lets_count', _countOrName(target), 'so_that_makes', 'number:$target'];

    case _Form.matchQuantities:
      // Join each group to its number. Choosing one of four tests recognition;
      // matching a whole set tests the relationship, and cannot be guessed the
      // way a single choice can.
      final values = <int>{};
      var guard = 0;
      while (values.length < 3 && guard < 60) {
        values.add(1 + rng.nextInt(maxV));
        guard++;
      }
      final left = values.toList();
      final right = _shuffled(left, rng);

      return PrimarItem(
        id: 'N$lvl-$index-match',
        level: lvl,
        topicId: numeracyTopicId,
        // No prompt row. A lone "=" floating on an empty sheet says nothing on
        // its own, and the board underneath already shows what to do.
        prompt: const [],
        options: const [],
        answerIndex: 0,
        spoken: 'match_them',
        teach: ['lets_count', for (final v in left) _countOrName(v)],
        interaction: Interaction.match,
        matchLeft: left.map<Figure>((v) => q(v)).toList(),
        matchRight: right.map<Figure>((v) => NumeralFigure(v)).toList(),
        matchPairing: [for (final v in left) right.indexOf(v)],
      );

    case _Form.orderQuantities:
      // Smallest to biggest. Comparison asks one pairwise judgement; ordering
      // asks for the whole sequence at once, which is ordinality rather than
      // cardinality and is the first thing here a child cannot answer by
      // pointing.
      final chosen = <int>{};
      var tries = 0;
      while (chosen.length < 4 && tries < 80) {
        chosen.add(1 + rng.nextInt(maxV));
        tries++;
      }
      final sorted = chosen.toList()..sort();

      // Shuffled, and never handed to the child already solved — a question
      // that opens on its own answer teaches nothing and scores as a success.
      var shown = _shuffled(sorted, rng);
      var reshuffles = 0;
      while (_isSorted(shown) && reshuffles < 20) {
        shown = _shuffled(sorted, rng);
        reshuffles++;
      }
      if (_isSorted(shown)) {
        // Vanishingly unlikely, but a deterministic swap beats a solved item.
        final tmp = shown[0];
        shown[0] = shown[shown.length - 1];
        shown[shown.length - 1] = tmp;
      }

      return PrimarItem(
        id: 'N$lvl-$index-order',
        level: lvl,
        topicId: numeracyTopicId,
        // No prompt row. A lone ">" above the board would be both a worse
        // instruction than the small-to-large rail the board already draws,
        // and indistinguishable from the comparison form that genuinely means
        // "which of these is more".
        prompt: const [],
        options: const [],
        answerIndex: 0,
        spoken: 'put_in_order',
        // Counting aloud stops at ten, and so does the teaching.
        //
        // Above ten the voice names the number instead. Not because the line is
        // missing — it could be recorded — but because a child working at level
        // eight who is walked from one to seventeen has been taught to count
        // from one again, which is the habit this level exists to replace.
        teach: [
          'lets_count',
          for (final v in sorted) _countOrName(v),
        ],
        interaction: Interaction.order,
        orderItems: shown.map<Figure>((v) => q(v)).toList(),
        orderSolution: [for (final v in sorted) shown.indexOf(v)],
      );

    case _Form.add:
      final a = 1 + rng.nextInt(maxV ~/ 2);
      final b = 1 + rng.nextInt(maxV ~/ 2);
      final sum = a + b;
      prompt = [
        q(a),
        const SymbolFigure(MathSymbol.plus),
        q(b),
        const SymbolFigure(MathSymbol.equals),
      ];
      final values = _shuffled(
        [sum, ..._numberDistractors(sum, maxV, rng, preferred: [a, b, (a - b).abs()])],
        rng,
      );
      options = values.map<Figure>((v) => NumeralFigure(v)).toList();
      answerIndex = values.indexOf(sum);
      spoken = 'how_many_altogether';
      teach = sum <= 10
          ? ['lets_count', _countOrName(sum), 'so_that_makes', 'number:$sum']
          : ['it_is_this_one', 'number:$sum'];

    case _Form.subtract:
      final total = 2 + rng.nextInt(maxV - 1);
      final take = 1 + rng.nextInt(total - 1);
      final left = total - take;
      prompt = [
        q(total),
        const SymbolFigure(MathSymbol.minus),
        q(take),
        const SymbolFigure(MathSymbol.equals),
      ];
      final values = _shuffled(
        [left, ..._numberDistractors(left, maxV, rng, preferred: [total, take, total + take])],
        rng,
      );
      options = values.map<Figure>((v) => NumeralFigure(v)).toList();
      answerIndex = values.indexOf(left);
      spoken = 'how_many_left';
      teach = left <= 10
          ? ['lets_count', _countOrName(left), 'so_that_makes', 'number:$left']
          : ['it_is_this_one', 'number:$left'];

    case _Form.missingAddend:
      // The step that separates counting from understanding a sum.
      final a = 1 + rng.nextInt(maxV ~/ 2);
      final missing = 1 + rng.nextInt(maxV ~/ 2);
      final sum = a + missing;
      prompt = [
        NumeralFigure(a),
        const SymbolFigure(MathSymbol.plus),
        const SymbolFigure(MathSymbol.unknown),
        const SymbolFigure(MathSymbol.equals),
        NumeralFigure(sum),
      ];
      final values = _shuffled(
        [missing, ..._numberDistractors(missing, maxV, rng, preferred: [sum, a, sum + a])],
        rng,
      );
      options = values.map<Figure>((v) => NumeralFigure(v)).toList();
      answerIndex = values.indexOf(missing);
      spoken = 'what_is_missing';
      teach = ['it_is_this_one', 'number:$missing'];
  }

  // The answer, as a word a child could say out loud.
  //
  // Only on choose-form items: a match board and an ordering row have no single
  // answer, and asking a child to say something after dragging four tiles would
  // be asking them to name a thing that has no name.
  final answerValue = switch (options[answerIndex]) {
    NumeralFigure(:final value) => value,
    QuantityFigure(:final count) => count,
    _ => null,
  };

  return PrimarItem(
    id: 'N$lvl-$index-$form',
    level: lvl,
    topicId: numeracyTopicId,
    prompt: prompt,
    options: options,
    answerIndex: answerIndex,
    spoken: spoken,
    teach: teach,
    sayTarget: _sayNumber(answerValue),
  );
}
