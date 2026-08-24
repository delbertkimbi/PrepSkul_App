/// The curriculum, as a graph rather than a ladder.
///
/// ## Why this replaces the level number
///
/// Everything until now hung off a single integer from 1 to 10. That number can
/// say a child is "at 6". It cannot say *which* thing they cannot do, because
/// level 6 is three different skills bundled together, and it cannot say what
/// has to be true before level 7 is even reachable.
///
/// So a child who confuses b and d and a child who cannot blend sounds both
/// stall at the same number, and both get the same response: more level-6
/// items. That is the difference between an assessment machine and a teacher.
///
/// A graph fixes it. Skills have prerequisites. A learner sits on a *frontier*
/// — the set of skills whose groundwork is done — rather than on a rung. When
/// something goes wrong the engine can drop to the prerequisite that actually
/// explains it, instead of lowering a difficulty dial.
///
/// ## The honesty rule
///
/// A skill in this graph is not a promise that the app can teach it. Several of
/// these — rhyming, syllable clapping, oral blending — are real, load-bearing
/// prerequisites that this app currently has no way to present, because they
/// need a child to *speak* or to hear rhythm rather than tap a tile.
///
/// They stay in the graph and are marked [teachable] `false`. The policy never
/// selects them. They are here because leaving them out would make the graph a
/// lie — it would claim letter sounds rest on nothing — and because the gaps
/// are the roadmap.
///
/// A missing rung is honest. A rung that pretends to hold weight is not.
library;

import 'subjects.dart';

/// Which broad strand of reading a skill belongs to.
///
/// These are the strands the evidence base keeps arriving at independently:
/// hearing the sounds in words, mapping sounds to letters, pulling a word off
/// the page, and knowing what it means. A child can be strong in one and absent
/// in another, which is exactly what a single level number cannot express.
enum Strand {
  /// Knowing how many are there.
  counting,

  /// More, less, and putting amounts in order.
  comparison,

  /// Joining and taking away.
  arithmetic,

  /// Putting parts together and taking them apart.
  visualReasoning,

  /// Hearing sound in speech, before any letter is involved.
  phonologicalAwareness,

  /// Telling letters apart, and knowing which sound each makes.
  letterKnowledge,

  /// Turning letters into a spoken word.
  decoding,

  /// Knowing what the word means once it has been decoded.
  meaning,
}

/// One thing a child can either do or not do.
class Skill {
  const Skill({
    required this.id,
    required this.strand,
    required this.label,
    required this.prerequisites,
    required this.teachable,
    this.subject = Subject.reading,
    this.transferFrom = const [],
  });

  /// Which path this skill belongs to.
  ///
  /// Ids are namespaced (`decode.read`, `num.add`) so one lookup table can
  /// hold every subject without collision, but a *path* must never mix them:
  /// a child working on counting has no business seeing letter sounds queued
  /// behind it. Defaulted to reading so the fourteen reading skills did not
  /// each need a line added.
  final Subject subject;

  /// Stable, and deliberately readable. These end up in stored learner state
  /// and in any future crosswalk to an external framework, so they must not be
  /// renamed casually.
  final String id;

  final Strand strand;

  /// What a parent would call it.
  final String label;

  /// What has to be in place first. A skill whose prerequisites are unmet is
  /// not "too hard" — it is unreachable, and drilling it teaches nothing.
  final List<String> prerequisites;

  /// Whether an item generator can actually produce this skill today.
  ///
  /// False means the skill is real and the app cannot present it yet. See the
  /// honesty rule in the library doc.
  final bool teachable;

  /// Skills whose content counts as a *transfer* test for this one.
  ///
  /// Getting the same question right eleven times is evidence of one thing;
  /// getting it right in a context it was never taught in is evidence of
  /// another. A child who learned /b/ from *ball* has not shown they know /b/
  /// until they meet it in *bag*.
  final List<String> transferFrom;
}

/// Reading, in the order a child actually acquires it.
///
/// The order is not a syllabus running left to right. It is a dependency
/// order, taken from where the reading evidence converges: sound awareness
/// before letters carry sounds, letter shapes told apart before they carry
/// sounds at all, blending before whole words, meaning alongside — never after
/// — decoding.
///
/// One deliberate choice worth naming: [letterShapeReversal] is its own skill
/// rather than part of letter shapes. b/d confusion is the most common early
/// reading difficulty there is, it is spatial rather than phonic, and a child
/// who has it needs a different intervention from a child who simply has not
/// met the letter. Folding it into "letter shapes" makes it invisible.
const List<Skill> readingSkills = [
  // ---- Phonological awareness. None of it teachable here yet. ----
  Skill(
    id: 'pa.rhyme',
    strand: Strand.phonologicalAwareness,
    label: 'Hears when two words rhyme',
    prerequisites: [],
    // Built. The objection recorded here was that it "needs a child to hear
    // and judge, with no written form involved" and that every interaction is
    // a tap on a tile — which read as a wall and was actually a failure of
    // imagination. A tap on a *picture* involves no written form at all, and
    // pa.blend and pa.segment now both work exactly that way.
    //
    // Rhyme is the earliest phonological skill a child has, which is why it
    // sits at the root with no prerequisites. English only in practice: the
    // French picture bank has no rhyming pair in it yet, so the generator
    // falls back there rather than asking a question with no right answer.
    teachable: true,
  ),
  Skill(
    id: 'pa.syllable',
    strand: Strand.phonologicalAwareness,
    label: 'Hears the beats in a word',
    prerequisites: ['pa.rhyme'],
    // Built, once the vocabulary could support it.
    //
    // It was blocked on the bank, not the idea: about thirty-two one-syllable
    // words, four with two and none with three, so a child answering "one"
    // every time would have scored near ninety percent. Banana, tomato and
    // umbrella were drawn to give the rung a third rung to stand on, and the
    // generator picks the count first and then a word that has it, so the
    // questions stay even however lopsided the bank gets.
    //
    // The counts are written down in `syllablesOf` rather than derived: every
    // rule for guessing syllables from English spelling mishears the silent e,
    // and a rung that teaches hearing cannot be built on one that mishears.
    teachable: true,
  ),
  Skill(
    id: 'pa.initial',
    strand: Strand.phonologicalAwareness,
    label: 'Hears the sound a word starts with',
    prerequisites: ['pa.syllable'],
    // This one *is* reachable: the word is spoken and pictured, and the child
    // picks the letter. It is doing double duty as awareness and as letters.
    teachable: true,
  ),
  Skill(
    id: 'pa.blend',
    strand: Strand.phonologicalAwareness,
    label: 'Pushes separate sounds together into a word',
    prerequisites: ['pa.initial'],
    // Built. The sounds are played one at a time and the child taps the
    // picture of the word they make — no letter appears anywhere, which is
    // what makes it phonological awareness rather than early decoding.
    //
    // This is the rung the research is loudest about: a child who cannot blend
    // orally does not decode, whatever else they know about letters.
    teachable: true,
  ),
  Skill(
    id: 'pa.segment',
    strand: Strand.phonologicalAwareness,
    // Relabelled to match what is actually asked.
    //
    // It said "Breaks a word back into its sounds", which is full
    // segmentation — every phoneme, in order. What the app can present is
    // final-sound isolation: hear a word, find another that ends the same way.
    // That is a real and standard rung of segmenting, and it is not the whole
    // of it, so the label says the narrower true thing rather than the wider
    // one the generator cannot back up.
    label: 'Hears the sound a word ends with',
    prerequisites: ['pa.blend'],
    teachable: true,
  ),

  // ---- Letter knowledge. ----
  Skill(
    id: 'letter.shape',
    strand: Strand.letterKnowledge,
    label: 'Tells two letters apart',
    prerequisites: [],
    teachable: true,
  ),
  Skill(
    id: 'letter.shape.reversal',
    strand: Strand.letterKnowledge,
    label: 'Tells apart letters that are mirror images',
    prerequisites: ['letter.shape'],
    teachable: true,
  ),
  Skill(
    id: 'letter.sound',
    strand: Strand.letterKnowledge,
    label: 'Knows the sound each letter makes',
    prerequisites: ['letter.shape', 'pa.initial'],
    teachable: true,
    // Hearing a sound at the start of a spoken word is the same knowledge
    // arriving from the other direction.
    transferFrom: ['pa.initial'],
  ),

  // ---- Decoding. ----
  Skill(
    id: 'decode.build',
    strand: Strand.decoding,
    label: 'Builds a short word from its sounds',
    prerequisites: ['letter.sound'],
    teachable: true,
  ),
  Skill(
    id: 'decode.read',
    strand: Strand.decoding,
    label: 'Reads a short word',
    prerequisites: ['decode.build'],
    teachable: true,
    // Building a word and reading one are the two directions of the same
    // mapping, so each tests whether the other transferred.
    transferFrom: ['decode.build'],
  ),
  Skill(
    id: 'decode.sentence',
    strand: Strand.decoding,
    label: 'Reads several words together',
    prerequisites: ['decode.read'],
    // Built as an ordering task: the phrase is spoken, the words arrive
    // scrambled, and the child drags them into place.
    //
    // Picking a picture would have been the obvious shape and it is the wrong
    // one — this app draws single objects, and there is no drawing of "cat on
    // mat". Ordering needs no new artwork and cannot be passed without reading
    // each word, which is exactly the thing being measured.
    teachable: true,
  ),

  // ---- Meaning. ----
  Skill(
    id: 'meaning.word',
    strand: Strand.meaning,
    label: 'Knows what the word they read means',
    prerequisites: ['decode.read'],
    // Built, at last, and built the way this comment said it had to be.
    //
    // The objection it used to record still stands and is worth keeping: for a
    // long time `decode.read` already meant matching a word to a picture, so
    // decoding and meaning arrived in the same move and one item was the
    // evidence for both. Marking this teachable then would have given it the
    // *identical* generator — two skills fed by one question, a distinction
    // the app claimed and could not observe.
    //
    // What makes it honest now is that the question runs the other way. The
    // word is the prompt and pictures are the answers, so nothing on screen
    // resembles anything else and shape-matching cannot get a child across.
    // See LiteracyForm.wordMeaning.
    teachable: true,
    transferFrom: ['decode.read'],
  ),
  Skill(
    id: 'meaning.sentence',
    strand: Strand.meaning,
    label: 'Understands what a sentence says',
    prerequisites: ['decode.sentence', 'meaning.word'],
    // Built as a listening task: the phrase is spoken, and the answers are
    // miniature scenes — two pictures with a joiner between them — composed
    // from drawings already in the bank. No new artwork, and no way to pass
    // by recognising a single object rather than the whole situation.
    //
    // decode.sentence got past the same wall by changing the interaction
    // (ordering words) rather than adding pictures. This is the comprehension
    // equivalent: composing two known pictures instead of drawing a scene.
    teachable: true,
    transferFrom: ['decode.sentence', 'meaning.word'],
  ),
];

/// The graph, indexed.
/// Numeracy, as a graph.
///
/// ## Why this exists
///
/// The learning engine — the skill graph, the mastery estimate, the spaced
/// review, the misconception repairs — applied to reading and to nothing else.
/// Numeracy ran on the adaptive staircase it started with: a level number that
/// went up and down. The product's whole claim is a system that knows *you are
/// here, you need this next*, and that claim held for one subject out of three.
///
/// ## Why these prerequisites
///
/// Counting comes before everything, because a child who cannot say how many
/// are in a group cannot compare two groups or join them. Comparison sits
/// beside naming rather than after it: telling which pile is bigger does not
/// require knowing the numeral for either, and children do it first.
/// Arithmetic waits for both.
///
/// The order is deliberately not the old level ladder. That ladder mixed forms
/// at each step to keep a session varied, which is the right thing for a
/// session and the wrong thing for a graph — it made every skill depend on
/// every earlier one whether it really did or not.
const List<Skill> numeracySkills = [
  Skill(
    id: 'num.count',
    subject: Subject.numeracy,
    strand: Strand.counting,
    label: 'Counts a group and names how many',
    prerequisites: [],
    teachable: true,
  ),
  Skill(
    id: 'num.numeral',
    subject: Subject.numeracy,
    strand: Strand.counting,
    label: 'Sees a number and makes that many',
    prerequisites: ['num.count'],
    teachable: true,
    // The same knowledge asked backwards, which is exactly what a transfer
    // check is for.
    transferFrom: ['num.count'],
  ),
  Skill(
    id: 'num.compare',
    subject: Subject.numeracy,
    strand: Strand.comparison,
    label: 'Says which group has more',
    prerequisites: ['num.count'],
    teachable: true,
  ),
  Skill(
    id: 'num.match',
    subject: Subject.numeracy,
    strand: Strand.comparison,
    label: 'Joins each group to its number',
    prerequisites: ['num.numeral'],
    teachable: true,
  ),
  Skill(
    id: 'num.order',
    subject: Subject.numeracy,
    strand: Strand.comparison,
    label: 'Puts amounts in order, smallest first',
    prerequisites: ['num.compare'],
    teachable: true,
  ),
  Skill(
    id: 'num.add',
    subject: Subject.numeracy,
    strand: Strand.arithmetic,
    label: 'Joins two groups and counts them all',
    prerequisites: ['num.count', 'num.compare'],
    teachable: true,
  ),
  Skill(
    id: 'num.subtract',
    subject: Subject.numeracy,
    strand: Strand.arithmetic,
    label: 'Takes some away and counts what is left',
    prerequisites: ['num.add'],
    teachable: true,
  ),
  Skill(
    id: 'num.missing',
    subject: Subject.numeracy,
    strand: Strand.arithmetic,
    label: 'Works out what is missing from a sum',
    prerequisites: ['num.add', 'num.subtract'],
    teachable: true,
  ),
];

/// Visual reasoning — shape composition on the learning engine.
///
/// The old staircase mixed add and subtract at every level to keep sessions
/// varied. That is right for a session and wrong for a graph: a child's
/// performance on joining and on taking away landed on one number, so
/// neither was measurable.
const List<Skill> shapesSkills = [
  Skill(
    id: 'shape.compose.basic',
    subject: Subject.shapes,
    strand: Strand.visualReasoning,
    label: 'Puts two straight parts together',
    prerequisites: [],
    teachable: true,
  ),
  Skill(
    id: 'shape.compose.curve',
    subject: Subject.shapes,
    strand: Strand.visualReasoning,
    label: 'Puts together shapes with curves',
    prerequisites: ['shape.compose.basic'],
    teachable: true,
  ),
  Skill(
    id: 'shape.compose.multi',
    subject: Subject.shapes,
    strand: Strand.visualReasoning,
    label: 'Puts together three or four parts',
    prerequisites: ['shape.compose.curve'],
    teachable: true,
  ),
  Skill(
    id: 'shape.discriminate',
    subject: Subject.shapes,
    strand: Strand.visualReasoning,
    label: 'Tells apart shapes that differ by one stroke',
    prerequisites: ['shape.compose.multi'],
    teachable: true,
  ),
  Skill(
    id: 'shape.decompose',
    subject: Subject.shapes,
    strand: Strand.visualReasoning,
    label: 'Takes a part away from a shape',
    prerequisites: ['shape.discriminate'],
    teachable: true,
  ),
  Skill(
    id: 'shape.flex',
    subject: Subject.shapes,
    strand: Strand.visualReasoning,
    label: 'Joins and takes away without being told which',
    prerequisites: ['shape.decompose'],
    teachable: true,
    transferFrom: ['shape.compose.multi', 'shape.decompose'],
  ),
];

/// Every skill in the product, whatever subject it belongs to.
final Map<String, Skill> skillsById = {
  for (final s in [...readingSkills, ...numeracySkills, ...shapesSkills]) s.id: s,
};

/// Skills that can actually be presented to a child today.
/// The skills a given subject can actually present.
List<Skill> teachableSkillsFor(Subject subject) => switch (subject) {
      Subject.reading => readingSkills.where((s) => s.teachable).toList(),
      Subject.numeracy => numeracySkills.where((s) => s.teachable).toList(),
      Subject.shapes => shapesSkills.where((s) => s.teachable).toList(),
    };

/// Reading's teachable skills.
///
/// Kept as the unqualified name because reading is what the engine was built
/// for and most callers mean it, but anything that could be asked about a
/// different subject should take one explicitly.
List<Skill> get teachableSkills => teachableSkillsFor(Subject.reading);

/// Everything [id] rests on, transitively, nearest first.
///
/// Used when a misconception recurs: the answer to "they keep failing this" is
/// usually a rung below it, not more of the same.
List<String> prerequisitesOf(String id, {Set<String>? seen}) {
  final visited = seen ?? <String>{};
  final skill = skillsById[id];
  if (skill == null || !visited.add(id)) return const [];

  final out = <String>[];
  for (final p in skill.prerequisites) {
    if (visited.contains(p)) continue;
    out.add(p);
  }
  for (final p in [...out]) {
    out.addAll(prerequisitesOf(p, seen: visited));
  }
  return out;
}
