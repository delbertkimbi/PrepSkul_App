import 'dart:math';

import 'figure.dart';
import 'numeracy.dart';
import 'items.dart' as shapes;
import 'representation.dart';
import 'word_bank.dart';

/// Foundational literacy.
///
/// This is the half of learning poverty that is measured in reading, and the
/// progression follows how a child actually gets there: first tell letters
/// apart by shape, then attach a sound to a shape, then hear where a sound sits
/// inside a word, then read a whole word.
///
/// ## Why the first rung is visual
///
/// Confusing b with d is the single most common early-reading difficulty, and
/// it is a visual-spatial problem before it is a phonics one — the same letter
/// reflected. That rung shares its whole mechanic with the shape-composition
/// engine, which is why the two subjects sit on one staircase rather than two.
///
/// ## Why audio is not optional here
///
/// Every rung above the first asks "which letter makes this sound" or "which
/// word is this". A child who cannot read cannot be given that instruction in
/// writing. The prompt is spoken, and the answer is tapped.
///
/// ## On French
///
/// French and English phonics are different systems, not translations of each
/// other — different vowel inventory, different letter-sound regularity,
/// different teaching order. The English scope below is complete enough to
/// test with. The French scope is a deliberately small starter set and wants a
/// Francophone teacher's review before it goes near a child.

const String literacyTopicIdEn = 'foundational.literacy.letters-and-words.en';
const String literacyTopicIdFr = 'foundational.literacy.letters-and-words.fr';

/// Letters that are genuinely easy to mistake for one another, which is what
/// makes a distractor a real test rather than a giveaway.
const Map<String, List<String>> _confusable = {
  'b': ['d', 'p', 'q'],
  'd': ['b', 'p', 'q'],
  'p': ['q', 'b', 'd'],
  'q': ['p', 'b', 'g'],
  'm': ['n', 'w'],
  'n': ['m', 'u', 'h'],
  'u': ['n', 'v'],
  'a': ['e', 'o'],
  'e': ['a', 'c'],
  'o': ['a', 'c', 'e'],
  'i': ['l', 'j', 't'],
  'l': ['i', 't', 'j'],
  'j': ['i', 'g'],
  'g': ['q', 'j', 'y'],
  's': ['z', 'c'],
  'z': ['s'],
  'f': ['t', 'l'],
  't': ['f', 'l', 'i'],
  'v': ['w', 'u', 'y'],
  'w': ['v', 'm'],
  'c': ['e', 'o', 's'],
  'h': ['n', 'k'],
  'k': ['h', 'x'],
  'r': ['n', 'v'],
  'x': ['k', 'y'],
  'y': ['v', 'g', 'x'],
};

/// The sound a letter makes, spoken — not its alphabet name. A child blending
/// "cat" needs /k/, never "see".
const Map<String, String> _lettersEn = {
  'm': 'mmm', 's': 'sss', 'a': 'aah', 't': 'tuh', 'p': 'puh', 'n': 'nnn',
  'c': 'kuh', 'd': 'duh', 'g': 'guh', 'o': 'ohh', 'b': 'buh', 'f': 'fff',
  'e': 'eh', 'l': 'lll', 'h': 'huh', 'r': 'rrr', 'i': 'ih', 'u': 'uh',
  'j': 'juh', 'v': 'vvv', 'w': 'wuh', 'k': 'kuh', 'y': 'yuh', 'z': 'zzz',
};


/// The wider decodable list, used where a word is only ever *heard* — initial
/// sounds and spelling. Nothing here is shown as a bare word to be chosen.
const List<String> _wordsEn = [
  'cat', 'dog', 'sun', 'cup', 'bed', 'pen', 'hat', 'map', 'bag', 'box',
  'leg', 'pot', 'van', 'web', 'zip', 'yam', 'hut', 'fan', 'net', 'pig',
  'bus', 'log', 'mat', 'jug', 'kid',
];

const Map<String, String> _lettersFr = {
  'a': 'ah', 'i': 'ee', 'o': 'oh', 'u': 'ue', 'e': 'euh',
  'm': 'mmm', 'l': 'lll', 's': 'sss', 'r': 'rrr', 'f': 'fff',
  'p': 'puh', 't': 'tuh', 'd': 'duh', 'n': 'nnn', 'v': 'vvv',
};

const List<String> _wordsFr = [
  'lit', 'sac', 'pot', 'bus', 'lune', 'main', 'mangue',
  'chat', 'nid', 'tapis', 'tasse', 'poule', 'ballon',
  'chien', 'poisson', 'soleil', 'chapeau', 'boite', 'banane', 'tomate',
  'parapluie', 'tambour', 'stylo', 'etoile', 'cle', 'fourmi', 'pomme',
  'jambe', 'ventilo', 'bol', 'fil', 'sol', 'rat', 'plat', 'nid',
  'pan', 'tin', 'net', 'mat', 'fan', 'van', 'pen', 'cup', 'hen', 'tap', 'pin',
];


/// The kinds of reading question this file can build.
///
/// Public because the curriculum graph now addresses them by name: a skill is
/// mapped to a form, and a private type cannot appear in that mapping.
enum LiteracyForm {
  /// Hear a sound, pick the *picture* whose name starts with it.
  soundPicture,
  letterShape,
  letterSound,
  initialSound,
  spellWord,
  readWord,

  /// Hear separate sounds, pick the picture of the word they make.
  ///
  /// Blending, and the first rung that is genuinely *pre*-literate: no letter
  /// appears anywhere in the question. A child who cannot recognise a single
  /// letter can do this, and a child who cannot do this will not decode, which
  /// is why it sits under letter.sound in the graph rather than after it.
  blendSounds,

  /// Hear a word, tap how many beats it has.
  ///
  /// Answered with counted dots rather than numerals, because a child at this
  /// rung is pre-literate by definition and may not read "3" either. The dots
  /// are the same ten-frame the numeracy side uses.
  syllableCount,

  /// Hear a word, pick another picture whose name rhymes with it.
  ///
  /// Rhyme is the earliest phonological skill there is — children hear it
  /// before they can isolate a single sound, which is why this sits at the
  /// root of the graph with no prerequisites at all.
  rhyme,

  /// Hear a word, pick another picture whose name *ends* the same way.
  ///
  /// Final-sound isolation. The mirror of [soundPicture], which does the same
  /// for the sound a word starts with, and deliberately built on the same
  /// machinery — pictures for the options, because four sounds rendered as
  /// four identical buttons is not a question a pre-reader can see.
  endSound,

  /// Put several written words in the order of a spoken phrase.
  ///
  /// The first rung where a child reads more than one word at a time, and the
  /// first that feels to them like reading rather than like a puzzle about
  /// letters.
  ///
  /// Ordering rather than picking, because picking needs a picture of the
  /// whole phrase and this app draws single objects. A child dragging "mat",
  /// "on", "cat" into place has to read each one to know where it goes, which
  /// is the thing being measured.
  readPhrase,

  /// Read a written word — no picture, no voice — and pick what it *means*.
  ///
  /// The first rung where reading stops being a matching exercise. Every form
  /// above it can be passed by pairing shapes or sounds; this one cannot,
  /// because nothing on the screen resembles anything else on it. The child
  /// has to go from letters to a word to a thing.
  ///
  /// It is also where the product stopped. `meaning.word` sat in the graph
  /// marked unteachable, so a child who could read "cat" had finished
  /// everything there was, six skills in. That is what "the content is too
  /// basic" measured out to.
  wordMeaning,

  /// Hear a short phrase and pick the miniature scene it describes.
  ///
  /// Comprehension, not decoding: the phrase is spoken and the answers are
  /// two pictures with a joiner between them. No new artwork — the same move
  /// [readPhrase] made when single-object drawings could not show a whole
  /// sentence.
  sentenceMeaning,
}

class _LitLevel {
  const _LitLevel(this.forms, this.optionSpread);
  final List<LiteracyForm> forms;

  /// How closely distractors resemble the answer. 0 means near-identical.
  final int optionSpread;
}

const Map<int, _LitLevel> _levels = {
  1: _LitLevel([LiteracyForm.letterShape], 2),
  2: _LitLevel([LiteracyForm.letterShape], 1),
  3: _LitLevel([LiteracyForm.letterShape, LiteracyForm.letterSound], 1),
  4: _LitLevel([LiteracyForm.letterSound], 2),
  5: _LitLevel([LiteracyForm.letterSound], 1),
  6: _LitLevel([LiteracyForm.letterSound, LiteracyForm.initialSound], 1),
  7: _LitLevel([LiteracyForm.initialSound], 1),
  8: _LitLevel([LiteracyForm.initialSound, LiteracyForm.spellWord], 1),
  9: _LitLevel([LiteracyForm.spellWord, LiteracyForm.readWord], 1),
  10: _LitLevel([LiteracyForm.readWord], 0),
};

int _clampLevel(num n) => n.round().clamp(1, 10);

T _pick<T>(List<T> list, Random rng) => list[rng.nextInt(list.length)];

List<T> _shuffled<T>(List<T> list, Random rng) {
  final out = List<T>.from(list);
  for (var i = out.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final t = out[i];
    out[i] = out[j];
    out[j] = t;
  }
  return out;
}

/// Three wrong letters, preferring ones that genuinely look or sound alike.
List<String> _letterDistractors(String answer, List<String> pool, int spread, Random rng) {
  final seen = <String>{answer};
  final out = <String>[];

  void offer(String l) {
    if (l == answer || seen.contains(l) || !pool.contains(l)) return;
    seen.add(l);
    out.add(l);
  }

  if (spread <= 1) {
    for (final c in _confusable[answer] ?? const <String>[]) {
      offer(c);
    }
  }
  for (final l in _shuffled(pool, rng)) {
    if (out.length >= 3) break;
    offer(l);
  }
  return out.take(3).toList();
}

/// Wrong words that differ by a single sound, so the item tests decoding rather
/// than shape-guessing at a glance.
List<String> _wordDistractors(String answer, List<String> pool, Random rng) {
  int distance(String a, String b) {
    if (a.length != b.length) return 9;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) d++;
    }
    return d;
  }

  final ranked = pool.where((w) => w != answer).toList()
    ..sort((x, y) => distance(answer, x).compareTo(distance(answer, y)));

  // Keep a little randomness so the same word does not always draw the same
  // three neighbours.
  final near = ranked.take(6).toList();
  return _shuffled(near, rng).take(3).toList();
}

/// Letters that are one another's mirror image.
///
/// b/d is the most common early-reading difficulty there is, and it is a
/// spatial problem rather than a phonic one — which is why it gets its own
/// skill and its own item variant rather than being folded into "letter
/// shapes", where it would be invisible.
const Map<String, List<String>> _reversalPairs = {
  'b': ['d', 'p'],
  'd': ['b', 'q'],
  'p': ['q', 'b'],
  'q': ['p', 'd'],
};

/// Which reading skill each form supplies evidence for.
///
/// The bridge between the curriculum graph and the thing a child actually taps.
/// The graph decides *what* to work on; this decides which generator can ask
/// about it. Keeping the mapping in one place means a skill can never quietly
/// end up with no way to be practised.
const Map<String, LiteracyForm> _formForSkill = {
  'letter.shape': LiteracyForm.letterShape,
  'letter.shape.reversal': LiteracyForm.letterShape,
  'pa.initial': LiteracyForm.soundPicture,
  'letter.sound': LiteracyForm.letterSound,
  'decode.build': LiteracyForm.spellWord,
  'decode.read': LiteracyForm.readWord,
  'meaning.word': LiteracyForm.wordMeaning,
  'pa.rhyme': LiteracyForm.rhyme,
  'pa.syllable': LiteracyForm.syllableCount,
  'pa.blend': LiteracyForm.blendSounds,
  'pa.segment': LiteracyForm.endSound,
  'decode.sentence': LiteracyForm.readPhrase,
  'meaning.sentence': LiteracyForm.sentenceMeaning,
};

/// Whether this skill can be asked about at all.
bool canGenerateSkill(String skillId) =>
    _formForSkill.containsKey(skillId) ||
    canGenerateNumeracySkill(skillId) ||
    shapes.canGenerateShapeSkill(skillId);

/// The sound a letter makes, or null if it is not one we teach.
///
/// Exposed because the reteach card needs to *say* the sound while showing the
/// letter, and a card that showed a letter in silence would be the same
/// nothing-to-hear problem the blank prompts were.
String? soundForLetter(String letter, {String locale = 'en'}) =>
    (locale == 'fr' ? _lettersFr : _lettersEn)[letter.toLowerCase()];

/// An item for a named skill, rather than for a level.
///
/// The level argument still exists underneath because it controls how close the
/// distractors sit — genuinely a difficulty dial, and a useful one. What it no
/// longer controls is *what the child is asked about*, which is now the
/// curriculum graph's job.
PrimarItem generateItemForSkill(
  String skillId,
  Random rng, {
  int index = 0,
  String locale = 'en',
  int spread = 1,
  Support support = Support.full,
}) {
  // Numeracy skills live in their own file but come through the same door, so
  // the engine never has to know which subject it is driving.
  if (canGenerateNumeracySkill(skillId)) {
    return generateNumeracyItemForSkill(skillId, rng,
        index: index, spread: spread);
  }

  if (shapes.canGenerateShapeSkill(skillId)) {
    return shapes.primarFromShapeItem(
      shapes.generateShapeItemForSkill(skillId, rng,
          index: index, spread: spread),
    );
  }

  final form = _formForSkill[skillId];
  if (form == null) {
    throw ArgumentError('no generator for skill $skillId');
  }
  return generateLiteracyItem(
    _levelHintFor(form),
    rng,
    index: index,
    locale: locale,
    force: form,
    reversalOnly: skillId == 'letter.shape.reversal',
    spreadOverride: spread,
    support: support,
  );
}

/// A level whose word list and range suit the form. Difficulty within the skill
/// comes from [spread], not from here.
int _levelHintFor(LiteracyForm form) => switch (form) {
      LiteracyForm.soundPicture => 6,
      LiteracyForm.letterShape => 2,
      LiteracyForm.letterSound => 5,
      LiteracyForm.initialSound => 7,
      LiteracyForm.spellWord => 9,
      LiteracyForm.readWord => 10,
      LiteracyForm.wordMeaning => 10,
      // Both sit low: they are oral skills that come before letters, and the
      // level only picks which word list is in play.
      LiteracyForm.rhyme => 6,
      LiteracyForm.syllableCount => 6,
      LiteracyForm.blendSounds => 6,
      LiteracyForm.endSound => 6,
      LiteracyForm.readPhrase => 10,
      LiteracyForm.sentenceMeaning => 10,
    };

PrimarItem generateLiteracyItem(
  int level,
  Random rng, {
  int index = 0,
  String locale = 'en',
  LiteracyForm? force,
  bool reversalOnly = false,
  int? spreadOverride,
  Support support = Support.full,
}) {
  final fr = locale == 'fr';
  final letters = (fr ? _lettersFr : _lettersEn).keys.toList();
  final sounds = fr ? _lettersFr : _lettersEn;
  // Words that can be drawn. Every form that shows a word prefers these, so a
  // child always has something to look at rather than a sound they may have
  // missed.
  // Two different questions, and conflating them is what kept the local
  // vocabulary out: reading a word needs it decodable, hearing what it starts
  // with only needs a picture.
  final pictured = picturableWords(locale);
  final readable = readableWords(locale);
  final words = fr ? _wordsFr : _wordsEn;
  final topicId = fr ? literacyTopicIdFr : literacyTopicIdEn;

  final lvl = _clampLevel(level);
  final spec = _levels[lvl]!;
  // The graph names the skill; the level only tunes how close the wrong
  // answers sit. When nothing is forced this falls back to the old behaviour.
  final LiteracyForm form = force ?? _pick<LiteracyForm>(spec.forms, rng);
  final optionSpread = spreadOverride ?? spec.optionSpread;

  List<Figure> prompt;
  List<Figure> options;
  int answerIndex;
  String? spoken;
  List<String> teach = const [];

  switch (form) {
    case LiteracyForm.letterShape:
      // Which of these is the same letter? Pure visual discrimination, and the
      // only literacy rung that needs no sound at all.
      // The reversal skill is the same question aimed squarely at b/d and p/q.
      //
      // A general letter-shape item picks any letter and any near-misses, so a
      // child sent here *because* they keep reversing letters would mostly get
      // questions that never test a reversal. The intervention has to contain
      // the thing it is intervening on.
      final mirrored = _reversalPairs.keys.where(letters.contains).toList();
      final target = reversalOnly && mirrored.isNotEmpty
          ? _pick(mirrored, rng)
          : _pick(letters, rng);

      final forced = reversalOnly
          ? (_reversalPairs[target] ?? const <String>[])
              .where(letters.contains)
              .toList()
          : const <String>[];

      prompt = [LetterFigure(target), const SymbolFigure(MathSymbol.equals)];
      final choices = _shuffled(
        [
          target,
          ...forced,
          ..._letterDistractors(target, letters, optionSpread, rng)
              .where((l) => !forced.contains(l)),
        ].take(4).toList(),
        rng,
      );
      options = choices.map<Figure>((l) => LetterFigure(l)).toList();
      answerIndex = choices.indexOf(target);
      spoken = 'find_the_same';
      // Naming the letter and its sound together is systematic phonics — the
      // letter shape and the sound it makes, taught as one thing.
      teach = ['it_is_this_one', 'letter:$target', 'this_letter_says', 'sound:${sounds[target]}'];

    case LiteracyForm.letterSound:
      // The sound is spoken; the child picks the letter that makes it.
      //
      // A letter sound cannot be drawn, so the prompt is the sound itself: a
      // button that says it, and says it again on every press. It used to be an
      // empty dashed box, which gave a child one chance to catch it and no way
      // back.
      final target = _pick(letters, rng);
      prompt = [SoundFigure('sound:${sounds[target]}')];
      final choices = _shuffled(
        [target, ..._letterDistractors(target, letters, optionSpread, rng)],
        rng,
      );
      options = choices.map<Figure>((l) => LetterFigure(l)).toList();
      answerIndex = choices.indexOf(target);
      spoken = 'sound:${sounds[target]}';
      teach = ['it_is_this_one', 'letter:$target', 'this_letter_says', 'sound:${sounds[target]}'];

    case LiteracyForm.soundPicture:
      // Hear /b/, point at the ball.
      //
      // This is phonemic awareness with no letter anywhere on screen, which is
      // the right order: hearing the sound inside a word comes before knowing
      // which mark stands for it. It also means a child who cannot read a
      // single letter can answer, and answer *correctly*, in their first
      // minute — which the letter version could not offer them.
      //
      // Every option is a picture, so the whole question is lookable-at. The
      // only thing that must be heard is the sound itself, and that has a
      // button that repeats it.
      final byLetter = <String, List<String>>{};
      for (final w in pictured) {
        if (letters.contains(w[0])) byLetter.putIfAbsent(w[0], () => []).add(w);
      }
      final startable = byLetter.keys.where((l) => byLetter[l]!.isNotEmpty).toList();

      if (startable.length < 2) {
        // Not enough pictured words to build a fair question. Fall through to
        // the letter version rather than ship a question with one real option.
        return generateLiteracyItem(lvl, rng,
            index: index, locale: locale, force: LiteracyForm.initialSound);
      }

      final startLetter = _pick(startable, rng);
      final answerWord = _pick(byLetter[startLetter]!, rng);

      final others = _shuffled(
        startable.where((l) => l != startLetter).toList(),
        rng,
      ).take(3).map((l) => _pick(byLetter[l]!, rng)).toList();

      final wordChoices = _shuffled([answerWord, ...others], rng);

      return PrimarItem(
        id: 'R$lvl-$index-soundpic',
        level: lvl,
        topicId: topicId,
        prompt: [SoundFigure('sound:${sounds[startLetter]}')],
        options: wordChoices.map<Figure>((w) => PictureFigure(w)).toList(),
        answerIndex: wordChoices.indexOf(answerWord),
        spoken: 'sound:${sounds[startLetter]}',
        teach: [
          'word:$answerWord',
          'listen',
          'sound:${sounds[startLetter]}',
          'letter:$startLetter',
        ],
        sayTarget: answerWord,
      );

    case LiteracyForm.initialSound:
      // A whole word is spoken; the child picks the letter it starts with.
      //
      // Restricted to words that can be drawn, so the child sees the thing and
      // hears its name. "What does *bus* start with" is answerable by a child
      // looking at a bus; a blank box is answerable only by a child who caught
      // the audio first time.
      final sayable =
          words.where((w) => letters.contains(w[0]) && pictured.contains(w)).toList();
      final word = _pick(
          sayable.isEmpty ? words.where((w) => letters.contains(w[0])).toList() : sayable, rng);
      final target = word[0];
      prompt = [
        if (pictured.contains(word)) PictureFigure(word),
        SoundFigure('word:$word'),
      ];
      final choices = _shuffled(
        [target, ..._letterDistractors(target, letters, optionSpread, rng)],
        rng,
      );
      options = choices.map<Figure>((l) => LetterFigure(l)).toList();
      answerIndex = choices.indexOf(target);
      spoken = 'word:$word';
      teach = ['word:$word', 'listen', 'sound:${sounds[target]}', 'letter:$target'];

    case LiteracyForm.spellWord:
      // Hear a word, then build it letter by letter. Recognising a written word
      // and producing one are different skills, and a child who can only pick
      // from four has not yet learned to spell.
      // Every letter must have a recorded sound, or sounding the word out
      // reaches for audio that does not exist. 'six' and 'box' are excluded
      // for exactly this reason: there is no /x/ in the sound table.
      final spellable = words
          .where((w) => w.length <= 4 && w.split('').every(sounds.containsKey))
          .toList();
      // Drawable first, for the same reason: a child spelling a word they can
      // see is spelling a thing, not transcribing a noise.
      final drawableSpellable = spellable.where(pictured.contains).toList();
      final pool = drawableSpellable.isNotEmpty
          ? drawableSpellable
          : (spellable.isEmpty ? words : spellable);
      final word = _pick(pool, rng);
      final target = word.split('');
      final decoys = _shuffled(
        letters.where((l) => !target.contains(l)).toList(),
        rng,
      ).take(3).toList();

      prompt = [
        if (pictured.contains(word)) PictureFigure(word),
        SoundFigure('word:$word'),
      ];
      options = const [];
      answerIndex = 0;
      spoken = 'word:$word';
      teach = [
        'word:$word',
        'listen',
        for (final l in target)
          if (sounds.containsKey(l)) 'sound:${sounds[l]}',
      ];

      return PrimarItem(
        id: 'R$lvl-$index-spell',
        level: lvl,
        topicId: topicId,
        prompt: prompt,
        options: options,
        answerIndex: answerIndex,
        spoken: spoken,
        teach: teach,
        interaction: Interaction.spell,
        spellTarget: target,
        spellPool: _shuffled([...target, ...decoys], rng),
      );

    case LiteracyForm.readWord:
      // A word is spoken; the child picks it in writing, beside its picture.
      // Only picturable words appear here: choosing between four bare written
      // words is shape-matching, not reading.

      // No picture set for this language yet: fall back to hearing a word and
      // choosing its first letter, which needs no picture and is a real rung.
      if (pictured.isEmpty) {
        final heard = _pick(words.where((w) => letters.contains(w[0])).toList(), rng);
        final first = heard[0];
        prompt = [const SymbolFigure(MathSymbol.unknown)];
        final letterChoices = _shuffled(
          [first, ..._letterDistractors(first, letters, optionSpread, rng)],
          rng,
        );
        return PrimarItem(
          id: 'R$lvl-$index-initial',
          level: lvl,
          topicId: topicId,
          prompt: prompt,
          options: letterChoices.map<Figure>((l) => LetterFigure(l)).toList(),
          answerIndex: letterChoices.indexOf(first),
          spoken: 'word:$heard',
          teach: [
            'word:$heard',
            'listen',
            if (sounds.containsKey(first)) 'sound:${sounds[first]}',
            'letter:$first',
          ],
        );
      }

      final word = _pick(readable.isEmpty ? pictured : readable, rng);
      // The picture is the question at first — "which of these words says
      // *this thing*" — and then it goes.
      //
      // This is the single most important place support has to fade. A child
      // who always sees a bed beside the words can pick the right word without
      // reading a letter of it, forever. Once they are strong the picture is
      // withdrawn and the word is spoken instead, so the only route to the
      // answer is through the letters.
      prompt = switch (support) {
        Support.full => [PictureFigure(word), SoundFigure('word:$word')],
        Support.partial => [SoundFigure('word:$word')],
        Support.none => [SoundFigure('word:$word')],
      };
      final choices = _shuffled(
          [word, ..._wordDistractors(word, readable.isEmpty ? pictured : readable, rng)], rng);
      // No pictures on the option tiles.
      //
      // They used to carry their own drawings, which made the whole rung
      // answerable without reading: the child heard "bed", looked for the bed
      // picture among four, and tapped it. The prompt is where the meaning
      // belongs; the options are the letters, and the letters are the point.
      options = choices.map<Figure>((w) => WordFigure(w, withPicture: false)).toList();
      answerIndex = choices.indexOf(word);
      spoken = 'word:$word';
      teach = ['it_is_this_one', 'word:$word'];

    case LiteracyForm.blendSounds:
      // The word is spoken as its separate sounds and the child picks the
      // picture. Nothing written appears at all — that is the point.
      //
      // Restricted to words whose every letter makes the sound we teach for
      // it, because the question is a promise: push these sounds together and
      // you get this word. "kite" would break that promise, so a word only
      // qualifies if it is decodable *and* drawable.
      final blendable = pictured
          .where((w) =>
              readable.contains(w) &&
              w.length >= 2 &&
              w.length <= 4 &&
              w.split('').every(sounds.containsKey))
          .toList();

      if (blendable.length < 2) {
        // Not enough to build a fair set of options. Falling back rather than
        // shipping a question with one real answer and three blanks.
        return generateLiteracyItem(lvl, rng,
            index: index, locale: locale, force: LiteracyForm.soundPicture);
      }

      final blendWord = _pick(blendable, rng);
      final blendOthers =
          _shuffled(blendable.where((w) => w != blendWord).toList(), rng)
              .take(3)
              .toList();
      final blendChoices = _shuffled([blendWord, ...blendOthers], rng);

      return PrimarItem(
        id: 'R$lvl-$index-blend',
        level: lvl,
        topicId: topicId,
        // One SoundFigure per sound, so the row *looks* like separate pieces
        // waiting to be pushed together and each can be replayed on its own.
        prompt: [
          for (final letter in blendWord.split(''))
            SoundFigure('sound:${sounds[letter]}'),
        ],
        options: blendChoices.map<Figure>((w) => PictureFigure(w)).toList(),
        answerIndex: blendChoices.indexOf(blendWord),
        spokenAll: [
          for (final letter in blendWord.split('')) 'sound:${sounds[letter]}',
        ],
        teach: [
          'listen',
          for (final letter in blendWord.split('')) 'sound:${sounds[letter]}',
          'so_that_makes',
          'word:$blendWord',
        ],
        sayTarget: blendWord,
      );

    case LiteracyForm.syllableCount:
      // The count is chosen first, then a word that has it.
      //
      // The other way round — pick a word, ask its count — inherits the bank's
      // shape, and the bank is thirty-one one-beat words against seven longer
      // ones. A child would meet "one" nearly every time and could pass by
      // always saying one. Choosing the count first makes the questions even
      // however lopsided the vocabulary is.
      final byBeats = <int, List<String>>{};
      for (final w in pictured) {
        final n = syllablesOf[w];
        if (n != null) byBeats.putIfAbsent(n, () => []).add(w);
      }
      final beatChoices = byBeats.keys.toList()..sort();

      if (beatChoices.length < 2) {
        return generateLiteracyItem(lvl, rng,
            index: index, locale: locale, force: LiteracyForm.soundPicture);
      }

      final beats = _pick(beatChoices, rng);
      final beatWord = _pick(byBeats[beats]!, rng);

      return PrimarItem(
        id: 'R$lvl-$index-syllable',
        level: lvl,
        topicId: topicId,
        prompt: [PictureFigure(beatWord), SoundFigure('word:$beatWord')],
        // Dots, not numerals. Counting is the answer; reading a digit is a
        // different skill and not one this rung is entitled to require.
        options: beatChoices
            .map<Figure>((n) => QuantityFigure(n, token: CountToken.dot))
            .toList(),
        answerIndex: beatChoices.indexOf(beats),
        spoken: 'word:$beatWord',
        teach: ['word:$beatWord', 'listen', 'count:$beats'],
      );

    case LiteracyForm.rhyme:
      // Grouped by rime — the vowel and everything after it, which for the
      // three-letter decodable words here is the last two letters.
      //
      // Decodable only, for the same reason the end-sound rung needs it: in a
      // decodable word every letter makes the sound we teach for it, so a
      // shared spelling of the rime really is a shared sound. Without that,
      // "kite" and "site" rhyme but so would "kite" and "vase" by the letters.
      final byRime = <String, List<String>>{};
      if (fr) {
        // French reads its endings out of [frenchSounds], because its spelling
        // hides them. Decodability is not the gate here — the table is.
        for (final w in pictured) {
          final sound = frenchSounds[w];
          if (sound != null) byRime.putIfAbsent(sound.rime, () => []).add(w);
        }
      } else {
        for (final w in pictured.where(readable.contains)) {
          if (w.length < 3) continue;
          byRime.putIfAbsent(w.substring(w.length - 2), () => []).add(w);
        }
      }
      final rhymable =
          byRime.keys.where((r) => byRime[r]!.length >= 2).toList();

      // Still falls back if the bank cannot make a fair question — a rhyming
      // pair plus three non-rhyming distractors.
      if (rhymable.isEmpty || byRime.keys.length < 4) {
        return generateLiteracyItem(lvl, rng,
            index: index, locale: locale, force: LiteracyForm.soundPicture);
      }

      final rime = _pick(rhymable, rng);
      final rhymePair = _shuffled(byRime[rime]!, rng);
      final rhymeCue = rhymePair[0];
      final rhymeMatch = rhymePair[1];

      final rhymeOthers = _shuffled(
        byRime.keys.where((r) => r != rime).toList(),
        rng,
      ).take(3).map((r) => _pick(byRime[r]!, rng)).toList();

      final rhymeChoices = _shuffled([rhymeMatch, ...rhymeOthers], rng);

      return PrimarItem(
        id: 'R$lvl-$index-rhyme',
        level: lvl,
        topicId: topicId,
        prompt: [PictureFigure(rhymeCue), SoundFigure('word:$rhymeCue')],
        options: rhymeChoices.map<Figure>((w) => PictureFigure(w)).toList(),
        answerIndex: rhymeChoices.indexOf(rhymeMatch),
        spoken: 'word:$rhymeCue',
        teach: [
          'word:$rhymeCue',
          'word:$rhymeMatch',
          'look_at_both',
        ],
        sayTarget: rhymeMatch,
      );

    case LiteracyForm.endSound:
      // Which of these ends the same way? Grouped by final letter rather than
      // first, which is the only difference from soundPicture — and the
      // difference that makes it a different skill.
      // Decodable words only, grouped by their final letter.
      //
      // The restriction is the whole correctness of this rung. Grouping every
      // drawable word by last letter paired "kite" with "vase" — both end in a
      // silent e, which is not a sound at all, so a rung whose label promises
      // "hears the sound a word ends with" was quietly matching spelling.
      //
      // In a decodable word every letter makes the sound we teach for it, so
      // the last letter *is* the last sound. That is exactly the guarantee
      // needed here, and `readable` already carries it.
      final byEnd = <String, List<String>>{};
      if (fr) {
        for (final w in pictured) {
          final sound = frenchSounds[w];
          if (sound != null) byEnd.putIfAbsent(sound.last, () => []).add(w);
        }
      } else {
        for (final w in pictured.where(readable.contains)) {
          final last = w[w.length - 1];
          if (sounds.containsKey(last)) byEnd.putIfAbsent(last, () => []).add(w);
        }
      }
      // Needs a letter with at least two words for the pair, and two more
      // letters for the distractors.
      final pairable =
          byEnd.keys.where((l) => byEnd[l]!.length >= 2).toList();

      if (pairable.isEmpty || byEnd.keys.length < 3) {
        return generateLiteracyItem(lvl, rng,
            index: index, locale: locale, force: LiteracyForm.soundPicture);
      }

      final endLetter = _pick(pairable, rng);
      final pair = _shuffled(byEnd[endLetter]!, rng);
      final cue = pair[0];
      final match = pair[1];

      final endOthers = _shuffled(
        byEnd.keys.where((l) => l != endLetter).toList(),
        rng,
      ).take(3).map((l) => _pick(byEnd[l]!, rng)).toList();

      final endChoices = _shuffled([match, ...endOthers], rng);

      return PrimarItem(
        id: 'R$lvl-$index-endsound',
        level: lvl,
        topicId: topicId,
        // The cue word is shown as a picture *and* spoken. A child who missed
        // the audio can still see what is being asked about, which is the same
        // rule every other listening rung follows.
        prompt: [PictureFigure(cue), SoundFigure('word:$cue')],
        options: endChoices.map<Figure>((w) => PictureFigure(w)).toList(),
        answerIndex: endChoices.indexOf(match),
        spoken: 'word:$cue',
        teach: [
          'word:$cue',
          'listen',
          'sound:${sounds[endLetter]}',
          'word:$match',
        ],
        sayTarget: match,
      );

    case LiteracyForm.readPhrase:
      // Two things and a joiner: "cat on mat". Short on purpose — this is the
      // first time a child has read more than one word, and the difficulty
      // that matters is the number of words, not their length.
      final joiners = phraseJoiners[fr ? 'fr' : 'en'] ?? const <String>[];
      final nouns = pictured.where(readable.contains).toList();

      if (joiners.isEmpty || nouns.length < 2) {
        return generateLiteracyItem(lvl, rng,
            index: index, locale: locale, force: LiteracyForm.readWord);
      }

      final first = _pick(nouns, rng);
      final second = _pick(nouns.where((w) => w != first).toList(), rng);
      final joiner = _pick(joiners, rng);
      final phrase = [first, joiner, second];

      // Shuffled until it is actually shuffled. A row that opens already
      // solved is a question a child answers by doing nothing.
      var shownOrder = _shuffled(List<int>.generate(3, (i) => i), rng);
      for (var attempt = 0;
          attempt < 8 && _isSorted(shownOrder);
          attempt++) {
        shownOrder = _shuffled(shownOrder, rng);
      }

      return PrimarItem(
        id: 'R$lvl-$index-phrase',
        level: lvl,
        topicId: topicId,
        // No prompt row. The phrase is spoken and the words to arrange are the
        // question — showing it written as well would be showing the answer.
        prompt: const [],
        options: const [],
        answerIndex: 0,
        interaction: Interaction.order,
        orderItems: shownOrder
            .map<Figure>((i) => WordFigure(phrase[i], withPicture: false))
            .toList(),
        orderSolution: [for (var i = 0; i < 3; i++) shownOrder.indexOf(i)],
        spokenAll: phrase.map((w) => 'word:$w').toList(),
        teach: [
          'listen',
          ...phrase.map((w) => 'word:$w'),
        ],
      );

    case LiteracyForm.wordMeaning:
      // The word is written, and the answers are pictures. Reversed from
      // readWord on purpose: there the word was the answer and could be found
      // by shape, here it is the question and the only way across is meaning.
      //
      // Nothing is spoken at full support either. Saying the word aloud would
      // hand over the answer, which is the mistake that made every earlier
      // rung passable without reading. Support fades in what the child gets
      // *after* a miss, not in whether the question can be short-circuited.
      final target = _pick(
        pictured.where((w) => readable.contains(w)).toList().isEmpty
            ? pictured
            : pictured.where((w) => readable.contains(w)).toList(),
        rng,
      );

      final others = pictured.where((w) => w != target).toList();
      final decoys = _shuffled(others, rng).take(3).toList();
      final picks = _shuffled([target, ...decoys], rng);

      prompt = [WordFigure(target)];
      options = picks.map<Figure>((w) => PictureFigure(w)).toList();
      answerIndex = picks.indexOf(target);
      // Silent until they have answered. The prompt carries no voice line, so
      // the id here is what gets said when the answer is revealed.
      spoken = support == Support.full ? 'word:$target' : 'have_a_look';
      teach = ['it_is_this_one', 'word:$target'];

    case LiteracyForm.sentenceMeaning:
      // Hear "cat on mat", pick the miniature scene. The phrase is spoken, not
      // written — showing it would be showing the answer. Each option is two
      // pictures and a joiner, composed from drawings already in the bank.
      final joiners = phraseJoiners[fr ? 'fr' : 'en'] ?? const <String>[];
      final nouns = pictured.where(readable.contains).toList();

      if (joiners.isEmpty || nouns.length < 3) {
        return generateLiteracyItem(lvl, rng,
            index: index,
            locale: locale,
            force: LiteracyForm.wordMeaning,
            spreadOverride: spreadOverride,
            support: support);
      }

      final first = _pick(nouns, rng);
      final second = _pick(nouns.where((w) => w != first).toList(), rng);
      final joiner = _pick(joiners, rng);
      final correct = PhraseFigure(first, joiner, second);

      // Distractors change exactly one piece so the child must hold the whole
      // phrase in mind, not latch onto a single familiar picture.
      final wrong = <PhraseFigure>{};
      for (final w in _shuffled(nouns.where((n) => n != first).toList(), rng)) {
        if (wrong.length >= 3) break;
        final d = PhraseFigure(w, joiner, second);
        if (d != correct) wrong.add(d);
      }
      for (final w
          in _shuffled(nouns.where((n) => n != second).toList(), rng)) {
        if (wrong.length >= 3) break;
        final d = PhraseFigure(first, joiner, w);
        if (d != correct) wrong.add(d);
      }
      for (final j in joiners.where((j) => j != joiner)) {
        if (wrong.length >= 3) break;
        final d = PhraseFigure(first, j, second);
        if (d != correct) wrong.add(d);
      }

      if (wrong.length < 3) {
        return generateLiteracyItem(lvl, rng,
            index: index,
            locale: locale,
            force: LiteracyForm.readPhrase,
            spreadOverride: spreadOverride,
            support: support);
      }

      final picks = _shuffled([correct, ...wrong.take(3)], rng);
      final answer = picks.indexOf(correct);

      return PrimarItem(
        id: 'R$lvl-$index-sentence-meaning',
        level: lvl,
        topicId: topicId,
        prompt: const [SoundFigure('listen')],
        options: picks,
        answerIndex: answer,
        spokenAll: ['word:$first', 'word:$joiner', 'word:$second'],
        teach: [
          'listen',
          ...['word:$first', 'word:$joiner', 'word:$second'],
          'it_is_this_one',
        ],
      );
  }

  // What a child could say out loud after getting this right.
  //
  // Letters give their name and words give the word. Nothing is offered on the
  // sound rungs: a recogniser handed /mmm/ in isolation returns noise, and an
  // unearned "I could not hear you" on a child who said it perfectly is exactly
  // what the one-directional rule exists to prevent.
  final say = switch (options[answerIndex]) {
    LetterFigure(:final letter) => letter,
    WordFigure(:final word) => word,
    _ => null,
  };

  return PrimarItem(
    id: 'R$lvl-$index-$form',
    level: lvl,
    topicId: topicId,
    prompt: prompt,
    options: options,
    answerIndex: answerIndex,
    spoken: spoken,
    teach: teach,
    sayTarget: say,
  );
}

/// Everything the voice layer must be able to say for this subject. A closed
/// set, so each line is synthesised once and cached on the device forever.
/// What a French word actually *sounds* like at the end.
///
/// ## Why French needs a table and English does not
///
/// The rhyme and end-sound rungs compare the written ending of a word, and
/// that is sound-correct in English only because both are restricted to
/// decodable words — words where every letter makes the sound we teach for it,
/// so a shared spelling really is a shared sound.
///
/// French breaks that, and not for want of vocabulary. Most French words end
/// in a letter nobody says: "nid" and "lit" rhyme perfectly, both ending /i/,
/// and their written endings are "id" and "it" — so the letter rule misses
/// every real rhyme while "chat" and "plat" match by accident and hide the
/// problem. Adding French words does not help; the rule is wrong.
///
/// So the endings are written down, the same way [syllablesOf] writes beat
/// counts rather than guessing them from spelling.
///
///  * [rime] is the vowel and everything after it — what has to match for two
///    words to rhyme.
///  * [last] is the final sound alone — what the end-sound rung compares.
///
/// Spelled in plain letters rather than IPA, because these strings are only
/// ever compared with each other, never shown or spoken. A word missing from
/// this table is simply not used by those two rungs in French, which is the
/// safe failure: fewer questions rather than wrong ones.
const Map<String, ({String rime, String last})> frenchSounds = {
  'lit': (rime: 'i', last: 'i'),
  'nid': (rime: 'i', last: 'i'),
  'tapis': (rime: 'i', last: 'i'),
  'chat': (rime: 'a', last: 'a'),
  'pot': (rime: 'o', last: 'o'),
  'sac': (rime: 'ak', last: 'k'),
  'bus': (rime: 'ys', last: 's'),
  'tasse': (rime: 'as', last: 's'),
  'poule': (rime: 'ul', last: 'l'),
  'lune': (rime: 'yn', last: 'n'),
  'main': (rime: 'in', last: 'in'),
  'ballon': (rime: 'on', last: 'on'),
  'mangue': (rime: 'ang', last: 'g'),
  'chien': (rime: 'ien', last: 'n'),
  'poisson': (rime: 'on', last: 'on'),
  'soleil': (rime: 'eil', last: 'l'),
  'chapeau': (rime: 'o', last: 'o'),
  'boite': (rime: 'it', last: 't'),
  'banane': (rime: 'an', last: 'n'),
  'tomate': (rime: 'at', last: 't'),
  'parapluie': (rime: 'i', last: 'i'),
  'tambour': (rime: 'our', last: 'r'),
  'stylo': (rime: 'o', last: 'o'),
  'etoile': (rime: 'il', last: 'l'),
  'cle': (rime: 'e', last: 'e'),
  'fourmi': (rime: 'i', last: 'i'),
  'pomme': (rime: 'om', last: 'm'),
  'jambe': (rime: 'amb', last: 'b'),
  'ventilo': (rime: 'o', last: 'o'),
  'bol': (rime: 'ol', last: 'l'),
  'fil': (rime: 'il', last: 'l'),
  'sol': (rime: 'ol', last: 'l'),
  'rat': (rime: 'a', last: 'a'),
  'plat': (rime: 'at', last: 't'),
  'pan': (rime: 'an', last: 'n'),
  'tin': (rime: 'in', last: 'n'),
  'net': (rime: 'et', last: 't'),
  'mat': (rime: 'at', last: 't'),
  'fan': (rime: 'an', last: 'n'),
  'van': (rime: 'an', last: 'n'),
  'pen': (rime: 'en', last: 'n'),
  'cup': (rime: 'up', last: 'p'),
  'hen': (rime: 'en', last: 'n'),
  'tap': (rime: 'ap', last: 'p'),
  'pin': (rime: 'in', last: 'n'),
  'moto': (rime: 'o', last: 'o'),
  'riz': (rime: 'i', last: 'i'),
  'arbre': (rime: 'r', last: 'r'),
  'gobelet': (rime: 'e', last: 't'),
  'eau': (rime: 'o', last: 'o'),
  'feu': (rime: 'eu', last: 'eu'),
  'mot': (rime: 'o', last: 'o'),
  'lot': (rime: 'o', last: 't'),
  'roc': (rime: 'ok', last: 'k'),
  'mer': (rime: 'er', last: 'r'),
  'plantain': (rime: 'in', last: 'n'),
};

/// How many beats each drawable word has.
///
/// Written out rather than counted from the letters. Every rule for guessing
/// syllables from English spelling gets the silent e wrong — "kite" and "vase"
/// come out as two — and a rung that teaches a child to hear beats cannot be
/// built on a rule that mishears them. French is worse.
///
/// A word with no entry here is simply not used by the syllable rung, which is
/// the safe failure: fewer questions rather than wrong ones.
const Map<String, int> syllablesOf = {
  // One.
  'yam': 1, 'hen': 1, 'pot': 1, 'mat': 1, 'net': 1, 'tin': 1, 'pan': 1,
  'tap': 1, 'dog': 1, 'ant': 1, 'kite': 1, 'nest': 1, 'vase': 1, 'bus': 1,
  'cup': 1, 'hat': 1, 'bag': 1, 'box': 1, 'bed': 1, 'pen': 1, 'leg': 1,
  'van': 1, 'sun': 1, 'fan': 1, 'log': 1, 'cat': 1, 'ball': 1, 'fish': 1,
  'key': 1, 'star': 1, 'drum': 1,
  // Two.
  'mango': 2, 'apple': 2, 'yoyo': 2, 'plantain': 2,
  // Three.
  'banana': 3, 'tomato': 3, 'umbrella': 3,
  // French — written out, never guessed from spelling.
  'lit': 1, 'sac': 1, 'lune': 1, 'main': 1,
  'chat': 1, 'nid': 1, 'chien': 1, 'rat': 1, 'bol': 1, 'fil': 1, 'sol': 1,
  'mangue': 2, 'tapis': 2, 'tasse': 2, 'poule': 1, 'ballon': 2,
  'poisson': 2, 'soleil': 2, 'chapeau': 2, 'banane': 2, 'tomate': 2,
  'stylo': 2, 'fourmi': 2, 'pomme': 1, 'jambe': 1, 'ventilo': 3,
  'parapluie': 3, 'tambour': 2, 'boite': 1, 'etoile': 2, 'cle': 1, 'plat': 1,
  'moto': 2, 'arbre': 2, 'gobelet': 2, 'riz': 1, 'eau': 1, 'feu': 1,
  'mot': 1, 'lot': 1, 'roc': 1, 'mer': 1,
};

/// Words that hold a phrase together and cannot be drawn.
///
/// Kept out of the word bank on purpose: every entry there must have a
/// picture, and "on" has no picture — asking a child to pick one would be a
/// blank tile. They are readable and decodable, which is all the phrase rung
/// needs of them.
const Map<String, List<String>> phraseJoiners = {
  'en': ['on', 'in'],
  'fr': ['sur', 'dans'],
};

List<String> literacySpeechCatalogue({String locale = 'en'}) {
  final fr = locale == 'fr';
  return [
    // The joiners, so a phrase is never read aloud with a silent gap in it.
    ...(phraseJoiners[fr ? 'fr' : 'en'] ?? const []).map((w) => 'word:$w'),
    ...(fr ? _lettersFr : _lettersEn).values.map((s) => 'sound:$s'),
    // Both lists: the decodable words a child reads, and everything in the
    // bank they might only be shown a picture of. A word with no recording is
    // a listen button that plays silence, which teaches a child the app is
    // broken.
    ...{
      ...(fr ? _wordsFr : _wordsEn),
      ...picturableWords(locale),
    }.map((w) => 'word:$w'),
  ];
}


/// Whether a row of indices is already in order.
bool _isSorted(List<int> row) {
  for (var i = 1; i < row.length; i++) {
    if (row[i - 1] > row[i]) return false;
  }
  return true;
}
