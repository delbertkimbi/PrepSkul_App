/// What each level means.
///
/// ## Why this file exists
///
/// The three generators each hold their own level table — stroke weights in
/// `items.dart`, forms and number ranges in `numeracy.dart`, rungs in
/// `literacy.dart`. Those tables say what an item *looks like* at level 7. None
/// of them says what a child who has settled at level 7 can actually do, and
/// that is the only thing a parent, a teacher or a funder ever asks.
///
/// So this is the outcome layer: one row per subject per level, written in the
/// terms someone outside the code would use. It is not decoration. It is:
///
///  * what the result screen and the roadmap read from, so a level is never
///    reported to a parent as a bare number;
///  * the contract a test holds the generators to — a level that claims
///    "adds two groups" and generates counting items is a lie this catches;
///  * the brief handed to a model when it is asked to author an alternative
///    explanation, a new word list or a new item form. A prompt that says
///    "make a level 7 numeracy question" gets whatever the model imagines.
///    A prompt that says "the child can add two groups up to 12 and cannot yet
///    take away" gets something usable.
///
/// ## The ordering rule
///
/// Every progression here is the one the evidence supports, not the one a
/// syllabus lists. Letters are told apart by shape before they carry a sound,
/// because b/d confusion is a visual problem before it is a phonics one.
/// Quantity is matched to numeral before either is added, because a child who
/// cannot see that five dots *is* "5" cannot meaningfully add. Shapes are put
/// together before they are taken apart, because decomposition is the harder
/// direction and every curriculum that leads with it loses children.
///
/// ## What a level is not
///
/// A level is not a school year, and nothing here may imply one. A nine-year-old
/// at level 2 and a six-year-old at level 7 are both ordinary in the population
/// this serves — that mismatch is the entire premise of the product, and a
/// curriculum that maps levels back onto grades would quietly reintroduce it.
library;

import 'subjects.dart';

/// One level of one subject.
class Outcome {
  const Outcome({
    required this.level,
    required this.can,
    required this.canFr,
    required this.taught,
    required this.evidence,
    required this.watchFor,
  });

  final int level;

  /// What a child working here can do, in a sentence a parent would say.
  /// Always an ability, never a deficit.
  final String can;

  /// The same claim for a Francophone parent.
  ///
  /// This sits beside [can] rather than in a translation file because it is
  /// the same fact, and a result screen that reported a French child's level
  /// in English would undo the language choice at the one screen the parent
  /// actually reads.
  final String canFr;

  /// [can] in the language being taught.
  String canIn(String locale) => locale == 'fr' ? canFr : can;

  /// The thing being taught at this level — the mechanic, named honestly.
  final String taught;

  /// What the app actually puts on screen to find out. This has to match what
  /// the generator does; a test checks that it does.
  final String evidence;

  /// The mistake that means a child is not ready to move on. Feeds the
  /// misconception tracker's parent-facing summary.
  final String watchFor;
}

/// Bands, for anywhere a single number would be read as a verdict.
///
/// Deliberately vague and deliberately not school years. A parent should be
/// able to tell that their child moved without being handed a comparison to
/// the class down the road.
String bandFor(double level, [String locale = 'en']) {
  final fr = locale == 'fr';
  if (level < 2.5) return fr ? 'premiers pas' : 'first steps';
  if (level < 4.5) return fr ? 'ça se construit' : 'building up';
  if (level < 6.5) return fr ? 'de plus en plus sûr' : 'getting confident';
  if (level < 8.5) return fr ? 'ça marche bien' : 'working well';
  return fr ? 'prêt pour la suite' : 'ready for more';
}

const Map<Subject, List<Outcome>> curriculum = {
  Subject.numeracy: _numeracy,
  Subject.reading: _reading,
  Subject.shapes: _shapes,
};

/// The outcome for a level, or the nearest one that exists.
Outcome outcomeFor(Subject subject, int level) {
  final rows = curriculum[subject]!;
  final at = level.clamp(1, rows.length);
  return rows[at - 1];
}

/// Numbers.
///
/// The spine is cardinality first — a numeral is a name for a quantity, and a
/// child who has not made that link is doing arithmetic on symbols they cannot
/// picture. Adding does not appear until level 5, well after both directions of
/// the count-to-numeral link have been established.
const List<Outcome> _numeracy = [
  Outcome(
    level: 1,
    can: 'counts a small group of things, up to three',
    canFr: 'compte un petit groupe, jusqu\'à trois',
    taught: 'cardinality — the last number you say is how many there are',
    evidence: 'a group of objects is shown; the child picks the numeral',
    watchFor: 'counting past the last object, or landing one out',
  ),
  Outcome(
    level: 2,
    can: 'counts up to five, and finds a group when given the number',
    canFr: 'compte jusqu\'à cinq, et trouve un groupe quand on lui donne le nombre',
    taught: 'the link runs both ways — numeral to quantity as well as back',
    evidence: 'both directions are asked: count to a numeral, and find that many',
    watchFor: 'one direction working and the other not',
  ),
  Outcome(
    level: 3,
    can: 'counts to six and can say which of two groups is bigger',
    canFr: 'compte jusqu\'à six et dit lequel de deux groupes est le plus grand',
    taught: 'comparison without counting — more and less as a judgement',
    evidence: 'two groups side by side; the child picks the larger',
    watchFor: 'picking the group that takes up more space rather than more things',
  ),
  Outcome(
    level: 4,
    can: 'works with numbers to nine, and joins each group to its number',
    canFr: 'travaille jusqu\'à neuf, et relie chaque groupe à son nombre',
    taught: 'the quantity–numeral relationship held across a whole set at once',
    evidence: 'a match board: three groups, three numerals, joined by hand',
    watchFor: 'solving by elimination rather than by seeing the pairs',
  ),
  Outcome(
    level: 5,
    can: 'counts to ten, orders groups by size, and adds two of them together',
    canFr: 'compte jusqu\'à dix, range les groupes par taille, et en additionne deux',
    taught: 'ordinality alongside addition — a sequence, not just a comparison',
    evidence: 'four groups dragged into order, and two groups with a plus',
    watchFor: 'answering with one of the two operands instead of the total',
  ),
  Outcome(
    level: 6,
    can: 'adds within ten and holds the number–quantity link across a whole set',
    canFr: 'additionne jusqu\'à dix et garde le lien nombre–quantité sur tout un ensemble',
    taught: 'addition without recounting from one',
    evidence: 'addition, match boards and ordering at the same range',
    watchFor: 'counting every object again from one each time',
  ),
  Outcome(
    level: 7,
    can: 'adds and takes away within twelve',
    canFr: 'additionne et soustrait jusqu\'à douze',
    taught: 'subtraction as taking away, alongside addition',
    evidence: 'both operations, unsignalled, so the symbol has to be read',
    watchFor: 'adding when the sign says take away',
  ),
  Outcome(
    level: 8,
    can: 'takes away within fifteen',
    canFr: 'soustrait jusqu\'à quinze',
    taught: 'subtraction on its own, at a size too large to count on fingers',
    evidence: 'subtraction only, with larger numbers',
    watchFor: 'answers one out, which usually means counting the start number',
  ),
  Outcome(
    level: 9,
    can: 'adds, takes away, and works out a missing part',
    canFr: 'additionne, soustrait, et trouve la partie manquante',
    taught: 'the unknown can sit anywhere in the sentence, not only at the end',
    evidence: 'a missing addend: one part and the whole are shown',
    watchFor: 'adding the two visible numbers instead of finding the difference',
  ),
  Outcome(
    level: 10,
    can: 'works with numbers to twenty, including missing parts',
    canFr: 'travaille jusqu\'à vingt, y compris les parties manquantes',
    taught: 'the same relationships, at a size that needs strategy not counting',
    evidence: 'subtraction and missing addends to twenty',
    watchFor: 'accuracy holding but time climbing — a sign of counting, not knowing',
  ),
];

/// Letters and words.
///
/// Five rungs, in acquisition order: tell letters apart, attach a sound to a
/// shape, hear that sound inside a word, build a word from sounds, read a word
/// whole. Reading a word does not appear until level 9 because everything
/// before it is what makes reading a word possible.
const List<Outcome> _reading = [
  Outcome(
    level: 1,
    can: 'tells two clearly different letters apart',
    canFr: 'distingue deux lettres bien différentes',
    taught: 'letters are shapes with fixed forms, and the form is the letter',
    evidence: 'a letter is shown; the child finds the same one again',
    watchFor: 'choosing by size or colour rather than by shape',
  ),
  Outcome(
    level: 2,
    can: 'tells similar letters apart',
    canFr: 'distingue des lettres qui se ressemblent',
    taught: 'orientation is part of the letter — b and d are not the same shape',
    evidence: 'the same task, with a confusable letter as the distractor',
    watchFor: 'b/d and p/q reversals, the most common early-reading difficulty',
  ),
  Outcome(
    level: 3,
    can: 'knows some letters by shape and is starting on their sounds',
    canFr: 'reconnaît des lettres à leur forme et commence leurs sons',
    taught: 'a letter carries a sound, not only a name',
    evidence: 'shape matching, mixed with the first sound questions',
    watchFor: 'giving the letter name where the sound is asked for',
  ),
  Outcome(
    level: 4,
    can: 'picks the letter that makes a given sound',
    canFr: 'choisit la lettre qui fait un son donné',
    taught: 'the sound-to-letter link, in the direction writing needs',
    evidence: 'a sound is spoken; the child picks the letter',
    watchFor: 'a sound heard correctly but mapped to a lookalike letter',
  ),
  Outcome(
    level: 5,
    can: 'knows most letter sounds reliably',
    canFr: 'connaît la plupart des sons des lettres',
    taught: 'the same link, across the wider letter set',
    evidence: 'sound-to-letter across the full taught alphabet',
    watchFor: 'vowels lagging behind consonants, which is normal and worth naming',
  ),
  Outcome(
    level: 6,
    can: 'hears the sound a word begins with',
    canFr: 'entend le son par lequel un mot commence',
    taught: 'phonemic awareness — a word is made of sounds you can pull apart',
    evidence: 'a word is spoken; the child picks the letter it starts with',
    watchFor: 'answering from the picture rather than from the sound',
  ),
  Outcome(
    level: 7,
    can: 'hears first sounds reliably across many words',
    canFr: 'entend le premier son dans beaucoup de mots',
    taught: 'the same skill, without the support of a familiar word',
    evidence: 'initial sounds across the decodable word list',
    watchFor: 'blends heard as a single sound',
  ),
  Outcome(
    level: 8,
    can: 'builds a short word from its sounds',
    canFr: 'construit un mot court à partir de ses sons',
    taught: 'blending — sounds in order make a word',
    evidence: 'letters are offered; the child spells the spoken word',
    watchFor: 'right letters in the wrong order, which is sequencing not phonics',
  ),
  Outcome(
    level: 9,
    can: 'reads a short word and knows what it means',
    canFr: 'lit un mot court et sait ce qu\'il veut dire',
    taught: 'decoding and meaning together, which is what reading is',
    evidence: 'a picture is shown; the child picks the word that names it',
    watchFor: 'matching word shapes rather than decoding — the reason every word here can be pictured',
  ),
  Outcome(
    level: 10,
    can: 'reads short words on sight',
    canFr: 'lit des mots courts d\'un seul coup d\'œil',
    taught: 'fluency — the word is recognised rather than worked out',
    evidence: 'reading words, with confusable words as distractors',
    watchFor: 'accuracy holding while speed does not improve',
  ),
];

/// Shapes.
///
/// Not a topic on its own so much as the visual reasoning that letters and
/// numbers both sit on. Putting together comes before taking apart throughout,
/// and the distractors get closer to the answer rather than the shapes getting
/// merely more complicated.
const List<Outcome> _shapes = [
  Outcome(
    level: 1,
    can: 'sees that two straight pieces make one shape',
    canFr: 'voit que deux morceaux droits font une forme',
    taught: 'composition — parts make a whole',
    evidence: 'two pieces and a plus; the child picks the shape they make',
    watchFor: 'picking a piece rather than the whole',
  ),
  Outcome(
    level: 2,
    can: 'puts together shapes that include curves',
    canFr: 'assemble des formes avec des courbes',
    taught: 'the same idea, with curved parts as well as straight ones',
    evidence: 'composition with up to three strokes',
    watchFor: 'curves treated as interchangeable regardless of direction',
  ),
  Outcome(
    level: 3,
    can: 'puts together shapes of three or four parts',
    canFr: 'assemble des formes de trois ou quatre parties',
    taught: 'holding more parts in mind at once',
    evidence: 'composition, three to four strokes',
    watchFor: 'losing a part — the answer right except for one stroke',
  ),
  Outcome(
    level: 4,
    can: 'tells apart shapes that differ by a single stroke',
    canFr: 'distingue des formes qui diffèrent d\'un seul trait',
    taught: 'precision — near-misses are now the distractors',
    evidence: 'four-stroke composition with one-stroke distractors',
    watchFor: 'answering quickly and wrongly, which means scanning not comparing',
  ),
  Outcome(
    level: 5,
    can: 'takes a part away from a shape as well as adding one',
    canFr: 'enlève une partie d\'une forme aussi bien qu\'il en ajoute',
    taught: 'decomposition — the harder direction',
    evidence: 'both operations, mixed',
    watchFor: 'adding when the sign says take away',
  ),
  Outcome(
    level: 6,
    can: 'takes a part away from a four-part shape',
    canFr: 'enlève une partie d\'une forme de quatre parties',
    taught: 'decomposition on its own',
    evidence: 'subtraction only, four strokes',
    watchFor: 'picking the part removed instead of what is left',
  ),
  Outcome(
    level: 7,
    can: 'works both directions on shapes of four or five parts',
    canFr: 'va dans les deux sens sur des formes de quatre ou cinq parties',
    taught: 'flexibility — the operation changes without warning',
    evidence: 'mixed operations, one-stroke distractors',
    watchFor: 'one direction reliable and the other not',
  ),
  Outcome(
    level: 8,
    can: 'takes apart shapes of five or six parts',
    canFr: 'décompose des formes de cinq ou six parties',
    taught: 'decomposition at the limit of what can be held visually',
    evidence: 'subtraction, five to six strokes, close distractors',
    watchFor: 'time climbing sharply, which means the shape no longer fits in mind at once',
  ),
  Outcome(
    level: 9,
    can: 'works both directions on complex shapes',
    canFr: 'va dans les deux sens sur des formes complexes',
    taught: 'the full mechanic at full size',
    evidence: 'mixed operations, five to six strokes',
    watchFor: 'errors clustering on one operation',
  ),
  Outcome(
    level: 10,
    can: 'takes apart the most complex shapes here, accurately',
    canFr: 'décompose sans erreur les formes les plus complexes d\'ici',
    taught: 'nothing new — this is the ceiling of the current engine',
    evidence: 'subtraction, six strokes, closest distractors',
    watchFor: 'a child sitting here comfortably has outgrown this subject',
  ),
];
