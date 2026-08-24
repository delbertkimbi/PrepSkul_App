/// Spoken and written feedback that names the thing the child just did.
///
/// Generic praise ("Good job!", "Try again!") teaches nothing a child can use.
/// A sharp tutor points at the word, the sound, the number, or the picture they
/// chose — and says what to do with it next.
///
/// ## Variety without noise
///
/// Each situation has two or three phrasings. The variant is chosen from the
/// item id and the attempt count, not from a random roll — so the same miss
/// always gets a stable line in tests, and consecutive *different* items still
/// feel fresh because their ids differ.
library;

import 'figure.dart';
import 'literacy.dart';
import 'micro_lesson.dart';
import 'misconception.dart';
import 'parent_phrases.dart';

/// One turn of feedback the session can speak and (optionally) show.
class TutorFeedback {
  const TutorFeedback({
    required this.text,
    required this.parentMoment,
    required this.id,
    this.parentBridgeId,
  });

  /// What Mate says. Always mentions something from the item when possible.
  final String text;

  /// Which parent recording belongs beside this line, if any.
  final ParentMoment parentMoment;

  /// Stable cache / queue key. Not a catalogue phrase — device TTS speaks [text].
  final String id;

  /// Catalogue voice-line id used only to unlock the parent recording.
  ///
  /// When the teaching voice is not a parent, this is ignored. When it is, the
  /// bridge is queued first so the right clip plays — appreciation on success,
  /// encouragement on struggle, patience while thinking.
  final String? parentBridgeId;

  /// Correct tap / build / match.
  factory TutorFeedback.correct({
    required PrimarItem item,
    required String locale,
    String? skillId,
    int streak = 0,
    int retryCount = 0,
    Misconception? misconception,
  }) {
    final ctx = _Ctx.from(item, locale: locale, skillId: skillId);
    final v = _variant(item.id, streak + retryCount);
    final text = _correctLine(ctx, v: v, firstTry: retryCount == 0, streak: streak);
    return TutorFeedback(
      text: text,
      parentMoment: ParentMoment.appreciation,
      parentBridgeId: 'yes',
      id: 'tutor_ok_${item.id}_$v',
    );
  }

  /// Wrong tap — name what they chose and what was needed.
  factory TutorFeedback.incorrect({
    required PrimarItem item,
    required String locale,
    int chosenIndex = -1,
    String? skillId,
    int retryCount = 0,
    Misconception? misconception,
  }) {
    final ctx = _Ctx.from(item, locale: locale, skillId: skillId);
    final chosen = (chosenIndex >= 0 && chosenIndex < item.options.length)
        ? _label(item.options[chosenIndex], locale)
        : null;
    final miss = misconception ??
        (chosenIndex >= 0 ? classifyMiss(item, chosenIndex) : Misconception.unclear);
    final v = _variant(item.id, retryCount + miss.index);
    final text = _incorrectLine(
      ctx,
      chosen: chosen,
      miss: miss,
      v: v,
      secondMiss: retryCount > 0,
    );
    return TutorFeedback(
      text: text,
      parentMoment: ParentMoment.encouragement,
      parentBridgeId: 'look_again',
      id: 'tutor_miss_${item.id}_$v',
    );
  }

  /// After teaching, handing the same question back.
  factory TutorFeedback.retryCue({
    required PrimarItem item,
    required String locale,
    String? skillId,
  }) {
    final ctx = _Ctx.from(item, locale: locale, skillId: skillId);
    final v = _variant(item.id, 1);
    final text = _retryLine(ctx, v: v);
    return TutorFeedback(
      text: text,
      parentMoment: ParentMoment.encouragement,
      parentBridgeId: 'now_you_try',
      id: 'tutor_retry_${item.id}_$v',
    );
  }

  /// Child has been thinking — patience, never "try again".
  factory TutorFeedback.waiting({
    required PrimarItem item,
    required String locale,
    String? skillId,
  }) {
    final ctx = _Ctx.from(item, locale: locale, skillId: skillId);
    final v = _variant(item.id, 2);
    final text = _waitingLine(ctx, v: v);
    return TutorFeedback(
      text: text,
      parentMoment: ParentMoment.patience,
      parentBridgeId: 'take_your_time',
      id: 'tutor_wait_${item.id}_$v',
    );
  }

  /// Speak-back matched. Names the target they said.
  factory TutorFeedback.speakMatched({
    required String target,
    required String locale,
    String? heard,
  }) {
    final fr = locale == 'fr';
    final said = (heard != null && heard.trim().isNotEmpty) ? heard.trim() : target;
    final v = _variant(target, said.length);
    final text = fr
        ? switch (v) {
            0 => "Je t'ai entendu : « $said ». C'est ça !",
            1 => "Oui — « $said ». Bien dit !",
            _ => "Parfait. Tu as dit « $target ».",
          }
        : switch (v) {
            0 => "I heard '$said'. That's it!",
            1 => "Yes — you said '$said'. Nice and clear.",
            _ => "Got it. '$target' — well said.",
          };
    return TutorFeedback(
      text: text,
      parentMoment: ParentMoment.appreciation,
      parentBridgeId: 'i_heard_you',
      id: 'tutor_say_${target}_$v',
    );
  }

  /// Speak-back not heard — warmth only, never a mark. Still names the target.
  factory TutorFeedback.speakWarm({
    required String target,
    required String locale,
  }) {
    final fr = locale == 'fr';
    final v = _variant(target, 3);
    final text = fr
        ? switch (v) {
            0 => "On reprendra « $target » plus tard. Tu peux continuer.",
            1 => "Pas grave. Le mot était « $target » — on avance.",
            _ => "Continue. « $target » t'attend une autre fois.",
          }
        : switch (v) {
            0 => "We'll catch '$target' another time. You can keep going.",
            1 => "No worry. The word was '$target' — on we go.",
            _ => "All good. '$target' will wait for next time.",
          };
    return TutorFeedback(
      text: text,
      parentMoment: ParentMoment.none,
      id: 'tutor_say_warm_${target}_$v',
    );
  }

  /// Speak-back heard something else — name heard→correct. Never a wrong mark.
  ///
  /// The child may try again for the bonus; silence after this costs nothing.
  factory TutorFeedback.speakCorrective({
    required String target,
    required String locale,
    required String heard,
  }) {
    final fr = locale == 'fr';
    final said = heard.trim();
    final v = _variant(target, said.length + 1);
    final text = fr
        ? switch (v) {
            0 => "J'ai entendu « $said ». Le mot, c'est « $target » — redis-le si tu veux.",
            1 => "Tu as dit « $said ». Essaie « $target ».",
            _ => "Presque — j'ai entendu « $said ». Dis « $target ».",
          }
        : switch (v) {
            0 => "I heard '$said'. The word is '$target' — say it again if you like.",
            1 => "You said '$said'. Try '$target'.",
            _ => "Almost — I heard '$said'. Say '$target'.",
          };
    return TutorFeedback(
      text: text,
      parentMoment: ParentMoment.encouragement,
      parentBridgeId: 'look_again',
      id: 'tutor_say_fix_${target}_$v',
    );
  }

  /// Opening line for a reteach card — names the letter or the pattern.
  factory TutorFeedback.reteach({
    required String locale,
    String? letter,
    String? sound,
    Misconception? misconception,
  }) {
    final fr = locale == 'fr';
    final v = _variant(letter ?? misconception?.name ?? 'reteach', 0);
    String text;
    if (letter != null) {
      final s = sound ?? soundForLetter(letter, locale: locale);
      text = fr
          ? (s == null
              ? "Une autre façon de voir la lettre $letter."
              : "Regarde la lettre $letter — elle dit $s.")
          : (s == null
              ? "Another way to look at the letter $letter."
              : "Look at the letter $letter — it says $s.");
    } else {
      text = fr
          ? switch (misconception) {
              Misconception.offByOne || Misconception.countingUnstable =>
                "Comptons autrement — un par un.",
              Misconception.operandEcho || Misconception.wrongOperation =>
                "Écoutons bien la question cette fois.",
              _ => "Essayons d'une autre façon.",
            }
          : switch (misconception) {
              Misconception.offByOne || Misconception.countingUnstable =>
                "Let's count a different way — one by one.",
              Misconception.operandEcho || Misconception.wrongOperation =>
                "Listen closely to the question this time.",
              _ => "Let's try that a different way.",
            };
    }
    // Keep a touch of variety without losing the content.
    if (v == 1 && letter == null && !fr) {
      text = "Fresh angle. $text";
    }
    return TutorFeedback(
      text: text,
      parentMoment: ParentMoment.patience,
      parentBridgeId: 'have_a_look',
      id: 'tutor_reteach_${letter ?? misconception?.name ?? 'x'}_$v',
    );
  }

  /// Spoken line for the session micro-lesson. Always names the item.
  factory TutorFeedback.microLesson(MicroLesson lesson) {
    return TutorFeedback(
      text: lesson.spoken,
      parentMoment: ParentMoment.patience,
      parentBridgeId: 'have_a_look',
      id: 'tutor_micro_${lesson.item.id}_${lesson.misconception.name}',
    );
  }
}

// --- internals ---------------------------------------------------------------

int _variant(String seed, int salt) => (seed.hashCode.abs() + salt) % 3;

String? _label(Figure f, String locale) => switch (f) {
      LetterFigure(:final letter) => letter,
      WordFigure(:final word) => word,
      PictureFigure(:final word) => word,
      NumeralFigure(:final value) => '$value',
      QuantityFigure(:final count, :final token) =>
        '${_tokenName(token, count, locale)} ($count)',
      SoundFigure(:final phraseId) => _soundLabel(phraseId, locale),
      ShapeFigure() => locale == 'fr' ? 'cette forme' : 'this shape',
      SymbolFigure() => null,
      PhraseFigure(:final first, :final joiner, :final second) =>
          '$first $joiner $second',
    };

String? _soundLabel(String phraseId, String locale) {
  if (phraseId.startsWith('sound:')) {
    final s = phraseId.substring(6);
    return locale == 'fr' ? 'le son $s' : 'the sound $s';
  }
  if (phraseId.startsWith('word:')) return phraseId.substring(5);
  if (phraseId.startsWith('letter:')) return phraseId.substring(7);
  return null;
}

String _tokenName(CountToken token, int n, String locale) {
  final many = n != 1;
  if (locale == 'fr') {
    return switch (token) {
      CountToken.mango => many ? 'mangues' : 'mangue',
      CountToken.ball => many ? 'ballons' : 'ballon',
      CountToken.fish => many ? 'poissons' : 'poisson',
      CountToken.leaf => many ? 'feuilles' : 'feuille',
      CountToken.star => many ? 'étoiles' : 'étoile',
      CountToken.dot => many ? 'points' : 'point',
      CountToken.square => many ? 'carrés' : 'carré',
      CountToken.triangle => many ? 'triangles' : 'triangle',
    };
  }
  return switch (token) {
    CountToken.mango => many ? 'mangoes' : 'mango',
    CountToken.ball => many ? 'balls' : 'ball',
    CountToken.fish => many ? 'fish' : 'fish',
    CountToken.leaf => many ? 'leaves' : 'leaf',
    CountToken.star => many ? 'stars' : 'star',
    CountToken.dot => many ? 'dots' : 'dot',
    CountToken.square => many ? 'squares' : 'square',
    CountToken.triangle => many ? 'triangles' : 'triangle',
  };
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

enum _Kind {
  letter,
  letterSound,
  word,
  rhyme,
  blend,
  initial,
  endSound,
  count,
  compare,
  add,
  subtract,
  spell,
  order,
  match,
  shape,
  other,
}

class _Ctx {
  _Ctx({
    required this.item,
    required this.locale,
    required this.kind,
    required this.answer,
    required this.promptHint,
    this.skillId,
    this.quantity,
    this.token,
    this.sound,
    this.promptWord,
  });

  final PrimarItem item;
  final String locale;
  final _Kind kind;
  final String? answer;
  final String? promptHint;
  final String? skillId;
  final int? quantity;
  final CountToken? token;
  final String? sound;
  final String? promptWord;

  bool get fr => locale == 'fr';

  factory _Ctx.from(PrimarItem item, {required String locale, String? skillId}) {
    final id = item.id.toLowerCase();
    final skill = (skillId ?? '').toLowerCase();
    final answer = item.options.isNotEmpty &&
            item.answerIndex >= 0 &&
            item.answerIndex < item.options.length
        ? _label(item.options[item.answerIndex], locale)
        : (item.sayTarget);

    QuantityFigure? q;
    // Prefer the answer's quantity when the child is matching a numeral to a
    // group — otherwise the first distractor pile steals the count we name.
    final answerFig = item.options.isNotEmpty &&
            item.answerIndex >= 0 &&
            item.answerIndex < item.options.length
        ? item.options[item.answerIndex]
        : null;
    if (answerFig is QuantityFigure) {
      q = answerFig;
    } else {
      for (final f in item.prompt) {
        if (f is QuantityFigure) {
          q = f;
          break;
        }
      }
    }

    String? promptWord;
    for (final f in item.prompt) {
      if (f is PictureFigure) promptWord = f.word;
      if (f is WordFigure) promptWord = f.word;
      if (f is SoundFigure && f.phraseId.startsWith('word:')) {
        promptWord = f.phraseId.substring(5);
      }
    }

    String? sound;
    for (final f in item.prompt) {
      if (f is SoundFigure && f.phraseId.startsWith('sound:')) {
        sound = f.phraseId.substring(6);
      }
    }
    if (sound == null && answer != null && answer.length == 1) {
      sound = soundForLetter(answer, locale: locale);
    }

    final kind = _inferKind(id, skill, item, answer);

    return _Ctx(
      item: item,
      locale: locale,
      kind: kind,
      answer: answer,
      promptHint: promptWord ?? sound ?? answer,
      skillId: skillId,
      quantity: q?.count,
      token: q?.token,
      sound: sound,
      promptWord: promptWord,
    );
  }
}

_Kind _inferKind(String id, String skill, PrimarItem item, String? answer) {
  if (item.interaction == Interaction.spell) return _Kind.spell;
  if (item.interaction == Interaction.order) return _Kind.order;
  if (item.interaction == Interaction.match) return _Kind.match;

  if (id.contains('rhyme') || skill.contains('rhyme')) return _Kind.rhyme;
  if (id.contains('blend') || skill.contains('blend')) return _Kind.blend;
  if (id.contains('initial') ||
      id.contains('soundpicture') ||
      skill.contains('initial') ||
      skill.contains('pa.initial')) {
    return _Kind.initial;
  }
  if (id.contains('endsound') ||
      id.contains('end-sound') ||
      skill.contains('segment') ||
      skill.contains('end')) {
    return _Kind.endSound;
  }
  if (id.contains('count') ||
      skill.contains('count') ||
      skill.startsWith('num.cardinal')) {
    return _Kind.count;
  }
  if (id.contains('compare') || skill.contains('compar')) return _Kind.compare;
  if (id.contains('add') ||
      id.contains('plus') ||
      skill.contains('add') ||
      skill.contains('join')) {
    return _Kind.add;
  }
  if (id.contains('sub') ||
      id.contains('minus') ||
      skill.contains('sub') ||
      skill.contains('take')) {
    return _Kind.subtract;
  }
  if (id.startsWith('l') || skill.contains('shape.compos')) return _Kind.shape;

  final spoken = item.spoken ?? '';
  if (spoken.startsWith('sound:') || item.prompt.any((f) => f is SoundFigure)) {
    if (answer != null && answer.length == 1) return _Kind.letterSound;
  }
  if (answer != null && answer.length == 1) return _Kind.letter;
  if (answer != null && answer.length > 1 && int.tryParse(answer) == null) {
    return _Kind.word;
  }
  if (answer != null && int.tryParse(answer) != null) return _Kind.count;
  return _Kind.other;
}

String _q(String? s) => s == null || s.isEmpty ? '' : "'$s'";

String _correctLine(_Ctx ctx, {required int v, required bool firstTry, required int streak}) {
  final a = ctx.answer;
  final fr = ctx.fr;

  String streakBit() {
    if (streak < 3) return '';
    if (fr) return v == 0 ? ' Encore une !' : ' Tu enchaînes.';
    return v == 0 ? ' That is a streak!' : ' You are on a run.';
  }

  switch (ctx.kind) {
    case _Kind.rhyme:
      final other = ctx.promptWord;
      if (a != null && other != null && other != a) {
        return fr
            ? switch (v) {
                0 => "Oui ! « $other » et « $a » riment.",
                1 => "Bien vu — « $a » sonne comme « $other ».",
                _ => "Exact. Tu entends la même fin dans « $other » et « $a ».",
              }
            : switch (v) {
                0 => "Yes! '$other' and '$a' rhyme. Hear the ending?",
                1 => "Nice — '$a' sounds like '$other' at the end.",
                _ => "That's it. Same ending in '$other' and '$a'.",
              };
      }
      break;
    case _Kind.blend:
      if (a != null) {
        return fr
            ? switch (v) {
                0 => "Oui ! Ces sons font « $a ».",
                1 => "Tu as collé les sons — « $a ».",
                _ => "Bravo. Les sons ensemble, c'est « $a ».",
              }
            : switch (v) {
                0 => "Yes! Those sounds make '$a'.",
                1 => "You pushed the sounds together — '$a'.",
                _ => "That's the word: '$a'.",
              };
      }
      break;
    case _Kind.initial:
      if (a != null) {
        final tip = ctx.promptWord ?? a;
        final s = ctx.sound ?? (tip.isNotEmpty ? tip[0] : '');
        return fr
            ? switch (v) {
                0 => "Oui — « $tip » commence par $s…",
                1 => "Bien. Le premier son de « $tip », c'est ça.",
                _ => "Exact. « $tip » démarre comme ça.",
              }
            : switch (v) {
                0 => "Yes — '$tip' starts with ${s.isEmpty ? 'that sound' : '$s…'}.",
                1 => "Got it. First sound in '$tip'.",
                _ => "That's the starter sound for '$tip'.",
              };
      }
      break;
    case _Kind.endSound:
      if (a != null) {
        final tip = ctx.promptWord ?? a;
        return fr
            ? "Oui — « $tip » et « $a » finissent pareil."
            : "Yes — '$tip' and '$a' end the same way.";
      }
      break;
    case _Kind.letterSound:
      if (a != null) {
        final s = ctx.sound ?? soundForLetter(a, locale: ctx.locale) ?? a;
        return fr
            ? switch (v) {
                0 => "Oui ! La lettre $a dit $s.",
                1 => "Bien. $a — $s.",
                _ => "C'est $a, et ça dit $s.",
              }
            : switch (v) {
                0 => "Yes! The letter $a says $s.",
                1 => "That's $a — it says $s.",
                _ => "Letter $a. Sound: $s.",
              };
      }
      break;
    case _Kind.letter:
      if (a != null) {
        return fr
            ? switch (v) {
                0 => "Oui — c'est la lettre $a.",
                1 => "Bien vu. $a.",
                _ => "Exactement : $a.",
              }
            : switch (v) {
                0 => "Yes — that is the letter $a.",
                1 => "Got it. Letter $a.",
                _ => "That's $a.",
              };
      }
      break;
    case _Kind.word:
    case _Kind.spell:
      if (a != null) {
        return fr
            ? switch (v) {
                0 => firstTry ? "Oui ! Le mot est « $a »." : "Oui — « $a ». Tu l'as eu.",
                1 => "Bien. « $a ».",
                _ => "Exact. Tu lis « $a ».",
              }
            : switch (v) {
                0 => firstTry ? "Yes! The word is '$a'." : "Yes — '$a'. You got it.",
                1 => "That's the word: '$a'.",
                _ => "You read '$a'.",
              };
      }
      break;
    case _Kind.count:
      final n = int.tryParse(a ?? '') ?? ctx.quantity;
      final things = ctx.token != null && n != null
          ? _tokenName(ctx.token!, n, ctx.locale)
          : null;
      if (n != null) {
        return fr
            ? switch (v) {
                0 => things == null
                    ? "Oui — il y en a $n."
                    : "Oui — $n $things.",
                1 => "Bien compté : $n.",
                _ => "Exact. $n.",
              }
            : switch (v) {
                0 => things == null
                    ? "Yes — there are $n."
                    : "Yes — $n $things.",
                1 => "Nice counting: $n.",
                _ => "That's $n.",
              };
      }
      break;
    case _Kind.compare:
      return fr
          ? switch (v) {
              0 => "Oui — celui-là en a le plus.",
              1 => "Bien. Tu as trouvé le plus grand groupe.",
              _ => "Exact. Plus, c'est celui-là.",
            }
          : switch (v) {
              0 => "Yes — that one has the most.",
              1 => "Nice. You found the bigger group.",
              _ => "That's the one with more.",
            };
    case _Kind.add:
      if (a != null) {
        return fr
            ? "Oui ! Ensemble, ça fait $a."
            : "Yes! Altogether that makes $a.";
      }
      break;
    case _Kind.subtract:
      if (a != null) {
        return fr
            ? "Oui — il en reste $a."
            : "Yes — $a left.";
      }
      break;
    case _Kind.order:
      return fr
          ? "Oui — dans le bon ordre."
          : "Yes — in the right order.";
    case _Kind.match:
      return fr
          ? "Oui — chaque groupe a son nombre."
          : "Yes — each group has its number.";
    case _Kind.shape:
      return fr
          ? switch (v) {
              0 => "Oui — cette forme-là.",
              1 => "Bien. Tu as trouvé la bonne pièce.",
              _ => "Exact. Ça correspond.",
            }
          : switch (v) {
              0 => "Yes — that shape fits.",
              1 => "Nice. You found the matching piece.",
              _ => "That's the one.",
            };
    case _Kind.other:
      break;
  }

  if (a != null) {
    return fr
        ? "Oui — c'est ${_frQuote(a)}.${streakBit()}"
        : "Yes — ${_q(a)}.$streakBit()";
  }
  return fr ? "Oui !${streakBit()}" : "Yes!${streakBit()}";
}

String _incorrectLine(
  _Ctx ctx, {
  required String? chosen,
  required Misconception miss,
  required int v,
  required bool secondMiss,
}) {
  final a = ctx.answer;
  final fr = ctx.fr;

  // Misconception-specific beats generic "look again".
  if (miss == Misconception.letterReversal && chosen != null && a != null) {
    return fr
        ? switch (v) {
            0 => "Presque — tu as pris $chosen. Regarde de quel côté va $a.",
            1 => "Attention : $chosen et $a sont des miroirs. C'est $a.",
            _ => "Tourne la lettre dans ta tête — on veut $a, pas $chosen.",
          }
        : switch (v) {
            0 => "Almost — you tapped '$chosen'. Watch which way '$a' faces.",
            1 => "Careful: '$chosen' and '$a' are mirrors. We need '$a'.",
            _ => "Flip it in your head — '$a', not '$chosen'.",
          };
  }
  if (miss == Misconception.offByOne && a != null) {
    final n = int.tryParse(a) ?? ctx.quantity;
    final count = n != null ? _countAloud(n, ctx.locale) : null;
    final things = ctx.token != null && n != null
        ? _tokenName(ctx.token!, n, ctx.locale)
        : null;
    if (chosen != null && count != null) {
      return fr
          ? "Tu as dit $chosen. Recompte${things == null ? '' : ' les $things'} : $count…"
          : "You said $chosen. Count${things == null ? '' : ' the $things'} again: $count…";
    }
  }
  if (miss == Misconception.operandEcho && chosen != null && a != null) {
    return fr
        ? "Tu as repris le $chosen de la question. Le total, c'est $a."
        : "You echoed the $chosen from the question. The answer is $a.";
  }
  if (miss == Misconception.wrongOperation && a != null) {
    return fr
        ? "Écoute bien le signe — le résultat est $a."
        : "Listen to the sign — the answer is $a.";
  }
  if (miss == Misconception.countingUnstable && a != null) {
    final n = int.tryParse(a) ?? ctx.quantity;
    final count = n != null ? _countAloud(n, ctx.locale) : null;
    if (count != null) {
      return fr
          ? "On compte un par un : $count. Ça fait $a."
          : "Count one by one: $count. That makes $a.";
    }
  }

  switch (ctx.kind) {
    case _Kind.rhyme:
      if (chosen != null && a != null && ctx.promptWord != null) {
        return fr
            ? "Presque — tu as pris « $chosen ». On veut ce qui rime avec « ${ctx.promptWord} » : « $a »."
            : "Almost — you tapped '$chosen'. We need what rhymes with '${ctx.promptWord}': '$a'.";
      }
      break;
    case _Kind.initial:
      if (chosen != null && ctx.promptWord != null) {
        final s = ctx.sound ?? ctx.promptWord![0];
        return fr
            ? "Presque — tu as pris « $chosen ». On veut le mot qui commence comme « ${ctx.promptWord} » — $s…"
            : "Almost — you tapped '$chosen'. We need the word that starts like '${ctx.promptWord}' — $s…";
      }
      break;
    case _Kind.blend:
      if (a != null) {
        return fr
            ? "Écoute encore les sons… ensemble, ils font « $a »."
            : "Listen to the sounds again… together they make '$a'.";
      }
      break;
    case _Kind.letterSound:
      if (chosen != null && a != null) {
        final s = ctx.sound ?? soundForLetter(a, locale: ctx.locale) ?? a;
        return fr
            ? "Tu as pris $chosen. La lettre qui dit $s, c'est $a."
            : "You picked '$chosen'. The letter that says $s is '$a'.";
      }
      break;
    case _Kind.word:
    case _Kind.spell:
      if (chosen != null && a != null) {
        return fr
            ? secondMiss
                ? "Le mot est « $a »."
                : "Presque — tu as pris « $chosen ». Le mot est « $a »."
            : secondMiss
                ? "The word is '$a'."
                : "Almost — you tapped '$chosen'. The word is '$a'.";
      }
      if (a != null) {
        return fr ? "Le mot est « $a »." : "The word is '$a'.";
      }
      break;
    case _Kind.count:
      if (chosen != null && a != null) {
        final n = int.tryParse(a) ?? ctx.quantity;
        final count = n != null ? _countAloud(n, ctx.locale) : null;
        final things = ctx.token != null && n != null
            ? _tokenName(ctx.token!, n, ctx.locale)
            : null;
        if (count != null) {
          return fr
              ? "Tu as dit $chosen. Recompte${things == null ? '' : ' les $things'} : $count…"
              : "You said $chosen. Count${things == null ? '' : ' the $things'} again: $count…";
        }
      }
      break;
    case _Kind.add:
    case _Kind.subtract:
      if (chosen != null && a != null) {
        return fr
            ? "Tu as choisi $chosen. Regarde : la réponse est $a."
            : "You chose $chosen. Look — the answer is $a.";
      }
      break;
    default:
      break;
  }

  if (chosen != null && a != null && chosen != a) {
    return fr
        ? "Presque — tu as pris ${_frQuote(chosen)}. C'est ${_frQuote(a)}."
        : "Almost — you tapped '$chosen'. It is '$a'.";
  }
  if (a != null) {
    return fr
        ? secondMiss
            ? "Regarde : c'est ${_frQuote(a)}."
            : "Regarde encore — c'est ${_frQuote(a)}."
        : secondMiss
            ? "Look: it is '$a'."
            : "Have another look — it is '$a'.";
  }
  return fr ? "Regarde encore. Celui-ci." : "Have another look. This one.";
}

String _frQuote(String s) =>
    RegExp(r'^\d+$').hasMatch(s) ? s : '« $s »';

String _retryLine(_Ctx ctx, {required int v}) {
  final a = ctx.answer;
  final fr = ctx.fr;
  if (a != null) {
    return fr
        ? switch (v) {
            0 => "À toi — trouve ${_frQuote(a)}.",
            1 => "Réessaie. Tu cherches ${_frQuote(a)}.",
            _ => "Un essai de plus pour ${_frQuote(a)}.",
          }
        : switch (v) {
            0 => "Your turn — find '$a'.",
            1 => "Try that again. You want '$a'.",
            _ => "One more go at '$a'.",
          };
  }
  return fr
      ? "À toi. Réessaie."
      : "Your turn. Have another go.";
}

String _waitingLine(_Ctx ctx, {required int v}) {
  final fr = ctx.fr;
  switch (ctx.kind) {
    case _Kind.count:
      final things = ctx.token != null && ctx.quantity != null
          ? _tokenName(ctx.token!, ctx.quantity!, ctx.locale)
          : null;
      if (things != null) {
        return fr
            ? "Prends ton temps. Compte les $things une par une."
            : "Take your time. Count the $things one by one.";
      }
      break;
    case _Kind.rhyme:
      if (ctx.promptWord != null) {
        return fr
            ? "Cherche ce qui sonne comme « ${ctx.promptWord} »."
            : "Look for what sounds like '${ctx.promptWord}'.";
      }
      break;
    case _Kind.initial:
      if (ctx.promptWord != null) {
        return fr
            ? "Quel mot commence comme « ${ctx.promptWord} » ?"
            : "Which word starts like '${ctx.promptWord}'?";
      }
      break;
    case _Kind.letterSound:
      if (ctx.sound != null) {
        return fr
            ? "Écoute le son : ${ctx.sound}. Quelle lettre ?"
            : "Listen for ${ctx.sound}. Which letter?";
      }
      break;
    case _Kind.word:
    case _Kind.spell:
      if (ctx.answer != null) {
        return fr
            ? "Regarde bien les lettres de « ${ctx.answer} »…"
            : "Look closely at the letters…";
      }
      break;
    default:
      break;
  }
  return fr
      ? switch (v) {
          0 => "Prends ton temps.",
          1 => "Regarde bien.",
          _ => "Tu peux y arriver.",
        }
      : switch (v) {
          0 => "Take your time.",
          1 => "Have a good look.",
          _ => "You can do this.",
        };
}

/// Banned as *primary* feedback — tests assert generated lines avoid these.
const List<String> bannedPrimaryFeedback = [
  'great job',
  'good job',
  'try again',
  'keep going',
  'you\'re learning',
  'you are learning',
  'bien joué',
  'bravo!', // alone, without content — we allow "Bravo." only with a word
];
