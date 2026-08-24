/// A short, specific teach beat after the second miss on a skill.
///
/// One miss is a slip. The same skill missed twice in a session is a pattern
/// worth naming — the word, the sound, the number, and what went wrong — then
/// handing the child another go. It is not the policy reteach (that waits for
/// a misconception to recur three times and may change the skill). This stays
/// on the item they were doing and runs entirely on device.
library;

import 'figure.dart';
import 'intervention.dart';
import 'literacy.dart';
import 'misconception.dart';
import 'skill.dart';

/// Counts misses per skill this session. Offers a micro-lesson on the 2nd.
class SessionMissWatch {
  final Map<String, int> _counts = {};

  /// How many misses [key] has this session.
  int countFor(String key) => _counts[key] ?? 0;

  /// True only on the miss that makes this the second one for [key].
  ///
  /// First miss → false. Third and later → false. Same skill, two misses,
  /// whether consecutive or with a hit in between → true on the second.
  bool onMiss(String key) {
    _counts[key] = (_counts[key] ?? 0) + 1;
    return _counts[key] == 2;
  }

  /// Skill id when the engine is driving; otherwise topic + level so the
  /// staircase still groups "the same kind of item".
  static String keyFor({String? skillId, required PrimarItem item}) =>
      skillId ?? '${item.topicId}@${item.level}';
}

/// Everything the card and the voice need, in both languages.
class MicroLesson {
  const MicroLesson({
    required this.title,
    required this.coachLine,
    required this.gestureHint,
    required this.cta,
    required this.locale,
    required this.misconception,
    required this.item,
    this.skillId,
    this.letter,
    this.sound,
    this.chosenIndex = -1,
  });

  /// Skill + what went wrong, short enough to read at a glance.
  final String title;

  /// One or two sentences naming the word/sound/number and the misconception.
  final String coachLine;

  /// Tiny teach gesture a child can do with a finger. Empty if none.
  final String gestureHint;

  final String cta;
  final String locale;
  final Misconception misconception;
  final PrimarItem item;
  final String? skillId;
  final String? letter;
  final String? sound;
  final int chosenIndex;

  /// What Mate speaks — the coach line, not the button.
  String get spoken => coachLine;

  bool get showLetterCard =>
      letter != null && sound != null && letter!.isNotEmpty;

  factory MicroLesson.build({
    required PrimarItem item,
    required String locale,
    required int chosenIndex,
    String? skillId,
    Misconception? misconception,
  }) {
    final miss = misconception ??
        (chosenIndex >= 0 ? classifyMiss(item, chosenIndex) : Misconception.unclear);
    final ctx = _Bits.from(item, locale);
    final chosen = (chosenIndex >= 0 && chosenIndex < item.options.length)
        ? ctx.labelOf(item.options[chosenIndex])
        : null;
    final fr = locale == 'fr';
    final letter = ctx.letter;
    final sound = letter == null
        ? ctx.sound
        : (ctx.sound ?? soundForLetter(letter, locale: locale));

    return MicroLesson(
      title: _title(ctx, miss: miss, skillId: skillId, fr: fr),
      coachLine: _coach(ctx, miss: miss, chosen: chosen, fr: fr),
      gestureHint: _gesture(miss, ctx, fr: fr),
      cta: fr ? 'Réessaie' : 'Try again',
      locale: locale,
      misconception: miss,
      item: item,
      skillId: skillId,
      letter: letter,
      sound: sound,
      chosenIndex: chosenIndex,
    );
  }
}

class _Bits {
  _Bits({
    required this.item,
    required this.locale,
    this.answer,
    this.sound,
    this.letter,
    this.word,
    this.quantity,
  });

  final PrimarItem item;
  final String locale;
  final String? answer;
  final String? sound;
  final String? letter;
  final String? word;
  final int? quantity;

  factory _Bits.from(PrimarItem item, String locale) {
    String? answer;
    if (item.options.isNotEmpty &&
        item.answerIndex >= 0 &&
        item.answerIndex < item.options.length) {
      answer = _label(item.options[item.answerIndex], locale);
    }
    answer ??= item.sayTarget;

    String? letter;
    String? word;
    String? sound;
    int? quantity;
    for (final f in [...item.prompt, ...item.options]) {
      if (f is LetterFigure) letter ??= f.letter;
      if (f is WordFigure) word ??= f.word;
      if (f is PictureFigure) word ??= f.word;
      if (f is SoundFigure && f.phraseId.startsWith('sound:')) {
        sound ??= f.phraseId.substring(6);
      }
      if (f is SoundFigure && f.phraseId.startsWith('word:')) {
        word ??= f.phraseId.substring(5);
      }
      if (f is QuantityFigure) quantity ??= f.count;
    }
    if (item.options.isNotEmpty &&
        item.answerIndex >= 0 &&
        item.answerIndex < item.options.length) {
      final a = item.options[item.answerIndex];
      if (a is LetterFigure) letter = a.letter;
      if (a is WordFigure) word = a.word;
      if (a is PictureFigure) word = a.word;
      if (a is NumeralFigure) quantity = a.value;
      if (a is QuantityFigure) quantity = a.count;
    }
    if (sound == null && letter != null) {
      sound = soundForLetter(letter, locale: locale);
    }
    return _Bits(
      item: item,
      locale: locale,
      answer: answer,
      sound: sound,
      letter: letter,
      word: word,
      quantity: quantity,
    );
  }

  String? labelOf(Figure f) => _label(f, locale);
}

String? _label(Figure f, String locale) => switch (f) {
      LetterFigure(:final letter) => letter,
      WordFigure(:final word) => word,
      PictureFigure(:final word) => word,
      NumeralFigure(:final value) => '$value',
      QuantityFigure(:final count) => '$count',
      SoundFigure(:final phraseId) => phraseId.startsWith('sound:')
          ? phraseId.substring(6)
          : phraseId.startsWith('word:')
              ? phraseId.substring(5)
              : phraseId,
      _ => null,
    };

String _title(_Bits ctx,
    {required Misconception miss, String? skillId, required bool fr}) {
  final skill = skillId == null ? null : skillsById[skillId]?.label;
  final wrong = _wrongBit(ctx, miss, fr);
  if (skill != null && skill.isNotEmpty) {
    return fr ? '${_frSkill(skillId, skill)} — $wrong' : '$skill — $wrong';
  }
  return wrong;
}

String _frSkill(String? id, String en) {
  return switch (id) {
    'pa.rhyme' => 'Rimes',
    'pa.initial' => 'Premier son',
    'pa.blend' => 'Fusionner les sons',
    'pa.segment.end' => 'Dernier son',
    'letter.shape' => 'Forme des lettres',
    'letter.shape.reversal' => 'Lettres miroir',
    'letter.sound' => 'Son des lettres',
    'decode.blend' => 'Lire un mot',
    'decode.word' => 'Lire un mot',
    'num.count' => 'Compter',
    'num.numeral' => 'Les nombres',
    'num.compare' => 'Plus et moins',
    'num.add' => 'Addition',
    'num.subtract' => 'Soustraction',
    _ => en,
  };
}

String _wrongBit(_Bits ctx, Misconception miss, bool fr) {
  final a = ctx.answer;
  final chosenLetter = ctx.letter;
  return switch (miss) {
    Misconception.letterReversal => fr
        ? (a == null ? 'Regarde de quel côté va la lettre' : 'C’est $a, pas son miroir')
        : (a == null ? 'Watch which way the letter faces' : "It's $a, not its mirror"),
    Misconception.letterShape => fr
        ? (a == null ? 'Regarde bien la forme' : 'La lettre est $a')
        : (a == null ? 'Look at the shape' : 'The letter is $a'),
    Misconception.letterSound => fr
        ? (chosenLetter == null || ctx.sound == null
            ? 'Écoute le son'
            : '$chosenLetter dit ${ctx.sound}')
        : (chosenLetter == null || ctx.sound == null
            ? 'Listen to the sound'
            : '$chosenLetter says ${ctx.sound}'),
    Misconception.offByOne => fr
        ? (a == null ? 'Recompte un par un' : 'Ça fait $a — pas un de plus')
        : (a == null ? 'Count one by one' : "That's $a — not one more"),
    Misconception.countingUnstable => fr
        ? (a == null ? 'Compte un par un' : 'Compte jusqu’à $a')
        : (a == null ? 'Count one by one' : 'Count all the way to $a'),
    Misconception.operandEcho => fr
        ? (a == null ? 'Cherche le total, pas un chiffre de la question' : 'Le total est $a')
        : (a == null
            ? 'Find the total, not a number from the question'
            : 'The total is $a'),
    Misconception.wrongOperation => fr
        ? (a == null ? 'Écoute le signe' : 'Le résultat est $a')
        : (a == null ? 'Listen to the sign' : 'The answer is $a'),
    Misconception.unclear => fr
        ? (a == null ? 'Regarde encore' : 'On cherche ${ _quote(a, fr)}')
        : (a == null ? 'Have another look' : "We're looking for ${ _quote(a, fr)}"),
  };
}

String _quote(String s, bool fr) =>
    RegExp(r'^\d+$').hasMatch(s) ? s : (fr ? '« $s »' : "'$s'");

String _coach(_Bits ctx,
    {required Misconception miss, required String? chosen, required bool fr}) {
  final a = ctx.answer;
  final word = ctx.word;
  final sound = ctx.sound;
  final n = ctx.quantity ?? int.tryParse(a ?? '');

  switch (miss) {
    case Misconception.letterReversal:
      if (chosen != null && a != null) {
        return fr
            ? 'Tu as pris $chosen. $a et $chosen sont des miroirs — regarde de quel côté va la bosse de $a.'
            : "You picked '$chosen'. '$a' and '$chosen' are mirrors — watch which way the bump on '$a' faces.";
      }
      break;
    case Misconception.letterShape:
      if (chosen != null && a != null) {
        return fr
            ? 'Tu as pris $chosen. Trace $a avec le doigt — compte les bosses.'
            : "You picked '$chosen'. Trace '$a' with your finger — count the humps.";
      }
      break;
    case Misconception.letterSound:
      if (a != null && sound != null) {
        return fr
            ? '${chosen == null ? 'Écoute' : 'Tu as pris $chosen. Écoute'} : la lettre $a dit $sound.'
            : "${chosen == null ? 'Listen' : "You picked '$chosen'. Listen"}: the letter $a says $sound.";
      }
      break;
    case Misconception.offByOne:
    case Misconception.countingUnstable:
      if (n != null) {
        final count = _countAloud(n, ctx.locale);
        return fr
            ? 'Tu ${chosen == null ? 'étais tout près' : 'as dit $chosen'}. Touche chaque chose : $count. Ça fait $n.'
            : "You ${chosen == null ? 'were close' : 'said $chosen'}. Touch each one: $count. That makes $n.";
      }
      break;
    case Misconception.operandEcho:
      if (chosen != null && a != null) {
        return fr
            ? '$chosen est dans la question. Ce n’est pas le total — le total, c’est $a. Join les deux groupes.'
            : "$chosen is in the question. That's not the total — the total is $a. Join the two groups.";
      }
      break;
    case Misconception.wrongOperation:
      if (a != null) {
        return fr
            ? 'Écoute le signe. Plus, on joint. Moins, on retire. Ici le résultat est $a.'
            : 'Listen to the sign. Plus means join. Minus means take away. Here the answer is $a.';
      }
      break;
    case Misconception.unclear:
      break;
  }

  if (word != null && a != null && word != a) {
    return fr
        ? 'Pour « $word », on veut ${_quote(a, true)}${chosen == null ? '' : ', pas ${_quote(chosen, true)}'}.'
        : "For '$word', we want ${ _quote(a, false)}${chosen == null ? '' : ", not ${ _quote(chosen, false)}"}.";
  }
  if (sound != null && a != null) {
    return fr
        ? 'Le son $sound va avec ${_quote(a, true)}.'
        : "The sound $sound goes with ${ _quote(a, false)}.";
  }
  if (a != null) {
    return fr
        ? 'Regarde bien : c’est ${_quote(a, true)}.${chosen == null ? '' : ' Pas ${_quote(chosen, true)}.'}'
        : "Look closely: it is ${ _quote(a, false)}.${chosen == null ? '' : " Not ${ _quote(chosen, false)}."}";
  }
  return fr
      ? 'On va le revoir lentement, puis tu réessaies.'
      : "We'll look at this slowly, then you have another go.";
}

String _gesture(Misconception miss, _Bits ctx, {required bool fr}) {
  final plan = interventionFor(miss);
  // Child-facing gesture, not the parent-facing registry sentence.
  final child = switch (miss) {
    Misconception.letterReversal => fr
        ? 'Pointe la bosse : à gauche c’est b, à droite c’est d.'
        : 'Point at the bump: left is b, right is d.',
    Misconception.letterShape => fr
        ? 'Trace les deux lettres. Où le trait est-il différent ?'
        : 'Trace both letters. Where is the extra stroke?',
    Misconception.letterSound => fr
        ? 'Dis le son, puis un mot qui commence comme ça.'
        : 'Say the sound, then a word that starts with it.',
    Misconception.offByOne || Misconception.countingUnstable => fr
        ? 'Touche chaque objet en disant un nombre.'
        : 'Touch each object as you say a number.',
    Misconception.operandEcho => fr
        ? 'Cache les nombres, join les groupes, puis compte.'
        : 'Cover the numbers, join the groups, then count.',
    Misconception.wrongOperation => fr
        ? 'Fais le geste : joindre, ou enlever.'
        : 'Do the gesture: join, or take away.',
    Misconception.unclear => '',
  };
  if (child.isNotEmpty) return child;
  return plan.what;
}

String _countAloud(int n, String locale) {
  const en = [
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
    'nine', 'ten', 'eleven', 'twelve',
  ];
  const fr = [
    'zéro', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit',
    'neuf', 'dix', 'onze', 'douze',
  ];
  final words = locale == 'fr' ? fr : en;
  if (n <= 0) return words[0];
  if (n >= words.length) return '$n';
  return List.generate(n, (i) => words[i + 1]).join(', ');
}
