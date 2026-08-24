/// The words a child reads, and where they come from.
///
/// ## Built from Cameroon, not for Cameroon
///
/// The difference is not decoration. A word list assembled somewhere else and
/// then "localised" arrives with apples, sleds and squirrels, and gets patched
/// by swapping a few nouns. A list built from here starts with mango, plantain
/// and the moto that goes past the door, and generalises outward — because the
/// *structure* is what travels, not the vocabulary.
///
/// So this is a bank of entries tagged by region, with the Cameroon set as the
/// default rather than the exception. Adding Kenya or Senegal later means
/// adding entries and a region code, not rewriting the reading engine.
///
/// ## The two constraints, which are not the same constraint
///
/// This took getting wrong to see clearly:
///
///  * **Reading a word** needs it to be *decodable* — every letter making the
///    sound the child has been taught. "mango" is not decodable early on; the
///    'a' is not a short /a/ and the 'ng' is a digraph nobody has met yet.
///  * **Hearing what a word starts with** needs nothing of the sort. It needs a
///    picture and a first sound. A child who cannot read a letter can look at a
///    mango and hear /m/.
///
/// Conflating them is what kept the local vocabulary out. The whole rich set of
/// things a Cameroonian child actually knows — mango, plantain, drum — was
/// excluded from *everything* because it could not be used for one rung.
///
/// Now [decodable] gates only the reading rungs. Everything drawable is
/// available to the sound rungs, and that is where a child's own world can
/// finally show up.
library;

/// One word the app can put in front of a child.
class WordEntry {
  const WordEntry(
    this.word, {
    required this.decodable,
    this.locale = 'en',
    this.regions = const {},
  });

  /// The written form.
  final String word;

  /// Whether it can be sounded out with letters a beginner has been taught.
  /// Only the reading and spelling rungs care.
  final bool decodable;

  final String locale;

  /// Where this word is at home. Empty means everywhere — a bus is a bus.
  ///
  /// A word is never *withheld* from another region; regional tagging only
  /// decides what comes first. A child in Douala and a child in Nairobi should
  /// both meet a mango, and only one of them should meet it constantly.
  final Set<String> regions;

  bool get isLocal => regions.isNotEmpty;
}

/// Region codes. ISO-3166 alpha-2, so this lines up with anything else later.
const String regionCameroon = 'CM';

/// The bank.
///
/// Every entry here must have a drawing in `WordPicture`, and a test enforces
/// it: a word with no picture is a blank tile in a pick-the-picture question,
/// and a word a child cannot see the meaning of is shape-matching practice.
const List<WordEntry> wordBank = [
  // ---- Cameroon first. These are the things within arm's reach. ----
  WordEntry('mango', decodable: false, regions: {regionCameroon}),
  WordEntry('plantain', decodable: false, regions: {regionCameroon}),
  WordEntry('drum', decodable: false, regions: {regionCameroon}),
  WordEntry('yam', decodable: true, regions: {regionCameroon}),
  WordEntry('hen', decodable: true, regions: {regionCameroon}),
  WordEntry('pot', decodable: true, regions: {regionCameroon}),
  WordEntry('mat', decodable: true, regions: {regionCameroon}),
  WordEntry('net', decodable: true, regions: {regionCameroon}),
  WordEntry('tin', decodable: true, regions: {regionCameroon}),
  WordEntry('pan', decodable: true, regions: {regionCameroon}),

  // ---- Added to complete the letter cards. ----
  //
  // Each of a, d, k, n, t, v and y had exactly one drawable word, so no card
  // could be built for them — a card needs two pictures that share nothing but
  // their first sound. These are the second word for each.
  //
  // "tap" is the tap in the yard rather than one over a sink, which is what it
  // means in most of the houses this is built for.
  WordEntry('tap', decodable: true, regions: {regionCameroon}),
  WordEntry('dog', decodable: true),
  WordEntry('ant', decodable: false),
  WordEntry('kite', decodable: false),
  WordEntry('nest', decodable: false),
  WordEntry('vase', decodable: false),
  WordEntry('yoyo', decodable: false),

  // ---- Everywhere. A bus is a bus. ----
  WordEntry('bus', decodable: true),
  WordEntry('cup', decodable: true),
  WordEntry('hat', decodable: true),
  WordEntry('bag', decodable: true),
  WordEntry('box', decodable: true),
  WordEntry('bed', decodable: true),
  WordEntry('pen', decodable: true),
  WordEntry('leg', decodable: true),
  WordEntry('van', decodable: true),
  WordEntry('sun', decodable: true),
  WordEntry('fan', decodable: true),
  WordEntry('log', decodable: true),
  WordEntry('cat', decodable: true),
  WordEntry('ball', decodable: false),
  WordEntry('apple', decodable: false),
  WordEntry('fish', decodable: false),
  WordEntry('key', decodable: false),
  WordEntry('star', decodable: false),

  // ---- Longer words, so beats can be counted. ----
  //
  // Three syllables each. None are decodable and none need to be: the rung
  // they exist for is oral, and asking a beginner to sound out "umbrella"
  // would be a different and much crueller question.
  WordEntry('banana', decodable: false),
  WordEntry('tomato', decodable: false),
  WordEntry('umbrella', decodable: false),

  // ---- French. Thin, and honestly so. ----
  //
  // The constraint is not the language, it is the picture set: a word earns a
  // place here once it can be drawn. A short honest list beats a long one where
  // half the words show nothing.
  WordEntry('sac', decodable: true, locale: 'fr'),
  WordEntry('lit', decodable: true, locale: 'fr'),
  WordEntry('pot', decodable: true, locale: 'fr'),
  WordEntry('bus', decodable: true, locale: 'fr'),
  WordEntry('lune', decodable: true, locale: 'fr'),
  WordEntry('main', decodable: true, locale: 'fr'),
  WordEntry('mangue', decodable: false, locale: 'fr', regions: {regionCameroon}),

  // ---- French, widened. ----
  //
  // The list above was seven words. A Francophone child — the larger half of
  // this country — met every reading rung drawn from a seventh of the material
  // an Anglophone child got, and the sound rungs fell back constantly for want
  // of options.
  //
  // None of these needed new artwork; they reuse drawings already here through
  // WordPicture's alias map. What they are not is *decodable*: French spelling
  // puts silent letters at the end of most of them, so they feed the picture
  // and sound rungs and are kept away from the ones that ask a child to sound
  // a word out.
  WordEntry('chat', decodable: false, locale: 'fr'),
  WordEntry('nid', decodable: true, locale: 'fr'),
  WordEntry('tapis', decodable: false, locale: 'fr'),
  WordEntry('tasse', decodable: false, locale: 'fr'),
  WordEntry('poule', decodable: false, locale: 'fr', regions: {regionCameroon}),
  WordEntry('ballon', decodable: false, locale: 'fr'),

  // ---- French, expanded again. ----
  //
  // Thirteen words was still a seventh of English. Every rung a Francophone
  // child met drew from that short list, and rhyme/end-sound had almost no
  // groups to build fair questions from. None of these need new artwork —
  // they alias drawings already here, the same way chat aliases cat.
  WordEntry('chien', decodable: false, locale: 'fr'),
  WordEntry('poisson', decodable: false, locale: 'fr'),
  WordEntry('soleil', decodable: false, locale: 'fr'),
  WordEntry('chapeau', decodable: false, locale: 'fr'),
  WordEntry('boite', decodable: false, locale: 'fr'),
  WordEntry('banane', decodable: false, locale: 'fr'),
  WordEntry('tomate', decodable: false, locale: 'fr'),
  WordEntry('parapluie', decodable: false, locale: 'fr'),
  WordEntry('tambour', decodable: false, locale: 'fr', regions: {regionCameroon}),
  WordEntry('stylo', decodable: false, locale: 'fr'),
  WordEntry('etoile', decodable: false, locale: 'fr'),
  WordEntry('cle', decodable: false, locale: 'fr'),
  WordEntry('fourmi', decodable: false, locale: 'fr'),
  WordEntry('pomme', decodable: false, locale: 'fr'),
  WordEntry('jambe', decodable: false, locale: 'fr'),
  WordEntry('ventilo', decodable: false, locale: 'fr'),
  // Short decodable words — three letters, taught letters only.
  WordEntry('bol', decodable: true, locale: 'fr'),
  WordEntry('fil', decodable: true, locale: 'fr'),
  WordEntry('sol', decodable: true, locale: 'fr'),
  WordEntry('rat', decodable: true, locale: 'fr'),
  WordEntry('plat', decodable: true, locale: 'fr'),

  // ---- French decodable, shared drawings. ----
  //
  // Same objects, French labels — a pan is a pan in Douala. These push the
  // readable set toward parity with English without new artwork.
  WordEntry('pan', decodable: true, locale: 'fr'),
  WordEntry('tin', decodable: true, locale: 'fr'),
  WordEntry('net', decodable: true, locale: 'fr'),
  WordEntry('mat', decodable: true, locale: 'fr'),
  WordEntry('fan', decodable: true, locale: 'fr'),
  WordEntry('van', decodable: true, locale: 'fr'),
  WordEntry('pen', decodable: true, locale: 'fr'),
  WordEntry('cup', decodable: true, locale: 'fr'),
  WordEntry('hen', decodable: true, locale: 'fr', regions: {regionCameroon}),
  WordEntry('tap', decodable: true, locale: 'fr'),
  WordEntry('pin', decodable: true, locale: 'fr'),

  // ---- French, local drawings. ----
  //
  // Cameroon-relevant nouns that no English alias could carry honestly — a moto
  // is not a bus, riz is not a yam, and eau is not a tap. Each earned its own
  // icon so the picture rungs can use them without shape-matching.
  WordEntry('moto', decodable: true, locale: 'fr', regions: {regionCameroon}),
  WordEntry('riz', decodable: true, locale: 'fr', regions: {regionCameroon}),
  WordEntry('arbre', decodable: false, locale: 'fr'),
  WordEntry('gobelet', decodable: false, locale: 'fr'),
  WordEntry('eau', decodable: false, locale: 'fr'),
  WordEntry('feu', decodable: true, locale: 'fr'),
  // Short decodable words that needed a picture of their own.
  WordEntry('mot', decodable: true, locale: 'fr'),
  WordEntry('lot', decodable: true, locale: 'fr'),
  WordEntry('roc', decodable: true, locale: 'fr'),
  WordEntry('mer', decodable: true, locale: 'fr'),
  WordEntry('plantain', decodable: false, locale: 'fr', regions: {regionCameroon}),
];

/// Words for a language, local ones first.
///
/// Ordering rather than filtering, on purpose. A child should meet their own
/// world early and often, and the rest of the world too — a list that only ever
/// showed local objects would be as narrow as one that never did.
List<WordEntry> wordsFor(String locale, {String region = regionCameroon}) {
  final mine = wordBank.where((w) => w.locale == locale).toList();
  final local = mine.where((w) => w.regions.contains(region)).toList();
  final rest = mine.where((w) => !w.regions.contains(region)).toList();
  return [...local, ...rest];
}

/// Words a child can be asked to *read*, which must be decodable.
List<String> readableWords(String locale, {String region = regionCameroon}) =>
    wordsFor(locale, region: region).where((w) => w.decodable).map((w) => w.word).toList();

/// Words a child can be shown a *picture* of, decodable or not.
///
/// This is the wider set, and it is where the local vocabulary lives: a child
/// hearing what "mango" starts with never has to spell it.
List<String> picturableWords(String locale, {String region = regionCameroon}) =>
    wordsFor(locale, region: region).map((w) => w.word).toList();
