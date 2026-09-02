/// Curiosity framing for the Skill Atelier — Anatomy-atelier feel without 3D.
///
/// Each skill gets a short hook (what you'll explore) and a Cameroon-flavoured
/// "did you know" so the home Start card is never a bare skill label.
library;

import 'skill.dart';
import 'subjects.dart';

class SkillAtelierCard {
  const SkillAtelierCard({
    required this.skillId,
    required this.hook,
    required this.hookFr,
    required this.didYouKnow,
    required this.didYouKnowFr,
  });

  final String skillId;
  final String hook;
  final String hookFr;
  final String didYouKnow;
  final String didYouKnowFr;

  String hookIn(String locale) => locale == 'fr' ? hookFr : hook;
  String didYouKnowIn(String locale) =>
      locale == 'fr' ? didYouKnowFr : didYouKnow;
}

const Map<String, SkillAtelierCard> _atelierBySkill = {
  'pa.rhyme': SkillAtelierCard(
    skillId: 'pa.rhyme',
    hook: 'Find words that sing the same ending.',
    hookFr: 'Trouve les mots qui chantent la même fin.',
    didYouKnow:
        'In Cameroon playground songs, rhymes help kids hear sounds before letters.',
    didYouKnowFr:
        'Dans les chansons de cour au Cameroun, les rimes aident à entendre les sons avant les lettres.',
  ),
  'pa.syllable': SkillAtelierCard(
    skillId: 'pa.syllable',
    hook: 'Clap the beats inside a word.',
    hookFr: 'Frappe les battements dans un mot.',
    didYouKnow: 'Many Cameroon names split into clear syllables — A-da-ma, N-go-no.',
    didYouKnowFr:
        'Beaucoup de prénoms camerounais se découpent en syllabes claires — A-da-ma, N-go-no.',
  ),
  'pa.initial': SkillAtelierCard(
    skillId: 'pa.initial',
    hook: 'Catch the first sound you hear.',
    hookFr: 'Attrape le premier son que tu entends.',
    didYouKnow: 'Hearing /b/ in "ball" is the bridge to reading "bag" later.',
    didYouKnowFr:
        'Entendre /b/ dans « balle » est le pont vers lire « sac » plus tard.',
  ),
  'pa.blend': SkillAtelierCard(
    skillId: 'pa.blend',
    hook: 'Squish sounds together to make a word.',
    hookFr: 'Colle les sons pour faire un mot.',
    didYouKnow:
        'Blending is how "c-a-t" becomes cat — the mouth learns before the eyes.',
    didYouKnowFr:
        'Fusionner, c\'est comment « c-a-t » devient chat — la bouche apprend avant les yeux.',
  ),
  'pa.segment': SkillAtelierCard(
    skillId: 'pa.segment',
    hook: 'Pull the last sound off a word.',
    hookFr: 'Découpe le dernier son d\'un mot.',
    didYouKnow:
        'Hearing endings helps kids tell "pin" from "pit" when they read.',
    didYouKnowFr:
        'Entendre la fin aide à distinguer « pin » et « pit » en lecture.',
  ),
  'letter.shape': SkillAtelierCard(
    skillId: 'letter.shape',
    hook: 'Spot letters by their shape.',
    hookFr: 'Repère les lettres par leur forme.',
    didYouKnow: 'b and d look like mirrors — we practice them slowly on purpose.',
    didYouKnowFr:
        'b et d se ressemblent comme un miroir — on les travaille lentement exprès.',
  ),
  'letter.shape.reversal': SkillAtelierCard(
    skillId: 'letter.shape.reversal',
    hook: 'Tell look-alike letters apart.',
    hookFr: 'Distingue les lettres qui se ressemblent.',
    didYouKnow: 'Even strong readers mix b/d when tired — the atelier fixes that gently.',
    didYouKnowFr:
        'Même de bons lecteurs confondent b/d quand ils sont fatigués — l’atelier corrige en douceur.',
  ),
  'letter.sound': SkillAtelierCard(
    skillId: 'letter.sound',
    hook: 'Match each letter to its sound.',
    hookFr: 'Associe chaque lettre à son son.',
    didYouKnow: 'Letter names and letter sounds are different — we teach the sound first.',
    didYouKnowFr:
        'Le nom de la lettre et son son sont différents — on enseigne le son d’abord.',
  ),
  'decode.build': SkillAtelierCard(
    skillId: 'decode.build',
    hook: 'Build a word sound by sound.',
    hookFr: 'Construis un mot son après son.',
    didYouKnow: 'Short Cameroon market words — yes, no, go — are perfect first builds.',
    didYouKnowFr:
        'De courts mots du marché — oui, non, va — sont parfaits pour commencer.',
  ),
  'decode.read': SkillAtelierCard(
    skillId: 'decode.read',
    hook: 'Read the whole word aloud in your head.',
    hookFr: 'Lis le mot entier dans ta tête.',
    didYouKnow: 'Pictures help meaning, but the letters do the reading work.',
    didYouKnowFr:
        'Les images aident le sens, mais ce sont les lettres qui font la lecture.',
  ),
  'decode.sentence': SkillAtelierCard(
    skillId: 'decode.sentence',
    hook: 'Put words in the right order.',
    hookFr: 'Mets les mots dans le bon ordre.',
    didYouKnow:
        'Reading a sentence is like lining up market signs — each word has its place.',
    didYouKnowFr:
        'Lire une phrase, c\'est comme aligner les enseignes du marché — chaque mot a sa place.',
  ),
  'meaning.word': SkillAtelierCard(
    skillId: 'meaning.word',
    hook: 'Choose the picture that matches the word.',
    hookFr: 'Choisis l’image qui va avec le mot.',
    didYouKnow: 'Knowing what a word means makes reading feel useful, not just loud.',
    didYouKnowFr:
        'Comprendre le sens d’un mot rend la lecture utile, pas seulement sonore.',
  ),
  'meaning.sentence': SkillAtelierCard(
    skillId: 'meaning.sentence',
    hook: 'Match two pictures to the story.',
    hookFr: 'Associe deux images à l\'histoire.',
    didYouKnow:
        'Stories in Cameroon homes often start with two things — this skill builds that habit.',
    didYouKnowFr:
        'Les histoires à la maison commencent souvent par deux choses — cette compétence s\'appuie là-dessus.',
  ),
  'num.count': SkillAtelierCard(
    skillId: 'num.count',
    hook: 'Count how many are there.',
    hookFr: 'Compte combien il y en a.',
    didYouKnow: 'Market sellers count oranges the same way — one by one, then the last number.',
    didYouKnowFr:
        'Les vendeurs au marché comptent les oranges de la même façon — une par une, puis le dernier nombre.',
  ),
  'num.numeral': SkillAtelierCard(
    skillId: 'num.numeral',
    hook: 'Connect the number to the group.',
    hookFr: 'Relie le chiffre au groupe.',
    didYouKnow: 'Seeing "5" and five mangoes as the same idea is a big maths leap.',
    didYouKnowFr:
        'Voir « 5 » et cinq mangues comme la même idée est un grand pas en maths.',
  ),
  'num.compare': SkillAtelierCard(
    skillId: 'num.compare',
    hook: 'Decide which group has more.',
    hookFr: 'Décide quel groupe a plus.',
    didYouKnow: 'Bigger looking piles are not always more — count, don’t guess by space.',
    didYouKnowFr:
        'Les tas qui paraissent plus grands n’ont pas toujours plus — compte, ne juge pas à la taille.',
  ),
  'num.match': SkillAtelierCard(
    skillId: 'num.match',
    hook: 'Join each group to its number.',
    hookFr: 'Relie chaque groupe à son chiffre.',
    didYouKnow:
        'Market sellers match piles to prices the same way — number and amount together.',
    didYouKnowFr:
        'Les vendeurs associent les tas aux prix de la même façon — chiffre et quantité ensemble.',
  ),
  'num.order': SkillAtelierCard(
    skillId: 'num.order',
    hook: 'Line amounts up from smallest to biggest.',
    hookFr: 'Range les quantités du plus petit au plus grand.',
    didYouKnow:
        'Ordering is like queuing at school — everyone knows who is first.',
    didYouKnowFr:
        'Ranger, c\'est comme faire la queue à l\'école — tout le monde sait qui est premier.',
  ),
  'num.add': SkillAtelierCard(
    skillId: 'num.add',
    hook: 'Put two groups together.',
    hookFr: 'Réunis deux groupes.',
    didYouKnow: 'Adding is joining — like putting two bowls of groundnuts in one.',
    didYouKnowFr:
        'Additionner, c’est réunir — comme mettre deux bols d’arachides en un.',
  ),
  'num.subtract': SkillAtelierCard(
    skillId: 'num.subtract',
    hook: 'Take some away and see what is left.',
    hookFr: 'Enlève-en et vois ce qui reste.',
    didYouKnow: 'Taking away is everyday: sharing snacks, paying with coins.',
    didYouKnowFr:
        'Enlever, c’est le quotidien : partager un goûter, payer avec des pièces.',
  ),
  'num.missing': SkillAtelierCard(
    skillId: 'num.missing',
    hook: 'Find the number that is missing.',
    hookFr: 'Trouve le nombre qui manque.',
    didYouKnow:
        'Missing-number puzzles are how kids learn sums work both ways.',
    didYouKnowFr:
        'Les nombres manquants montrent que les additions marchent dans les deux sens.',
  ),
  'shape.compose.basic': SkillAtelierCard(
    skillId: 'shape.compose.basic',
    hook: 'Build a simple shape from pieces.',
    hookFr: 'Construis une forme simple avec des pièces.',
    didYouKnow: 'Cloth patterns and house tiles are shape games Cameroon kids already play.',
    didYouKnowFr:
        'Les motifs de tissu et les carreaux de maison sont déjà des jeux de formes.',
  ),
  'shape.compose.curve': SkillAtelierCard(
    skillId: 'shape.compose.curve',
    hook: 'Fit curved pieces together.',
    hookFr: 'Assemble des pièces courbes.',
    didYouKnow:
        'Round pots and bowl rims are curves kids see every day at home.',
    didYouKnowFr:
        'Les marmites rondes et les bords de bols sont des courbes vues chaque jour.',
  ),
  'shape.compose.multi': SkillAtelierCard(
    skillId: 'shape.compose.multi',
    hook: 'Build with three or four parts.',
    hookFr: 'Construis avec trois ou quatre pièces.',
    didYouKnow:
        'More pieces means planning ahead — like fitting bags in a taxi boot.',
    didYouKnowFr:
        'Plus de pièces, c\'est planifier — comme ranger les sacs dans le coffre.',
  ),
  'shape.discriminate': SkillAtelierCard(
    skillId: 'shape.discriminate',
    hook: 'Find the shape that matches.',
    hookFr: 'Trouve la forme qui correspond.',
    didYouKnow: 'Looking carefully at edges is the same skill as spotting letter shapes.',
    didYouKnowFr:
        'Bien regarder les bords, c’est la même compétence que repérer les lettres.',
  ),
  'shape.decompose': SkillAtelierCard(
    skillId: 'shape.decompose',
    hook: 'Take a piece away from a shape.',
    hookFr: 'Enlève une pièce d\'une forme.',
    didYouKnow:
        'Taking apart is how kids see that big shapes are made of small ones.',
    didYouKnowFr:
        'Décomposer, c\'est voir que les grandes formes sont faites de petites.',
  ),
  'shape.flex': SkillAtelierCard(
    skillId: 'shape.flex',
    hook: 'Add or take away — you choose.',
    hookFr: 'Ajoute ou enlève — à toi de choisir.',
    didYouKnow:
        'Flexible thinking with shapes prepares kids for flexible thinking with numbers.',
    didYouKnowFr:
        'Penser souplement avec les formes prépare à penser souplement avec les nombres.',
  ),
};

SkillAtelierCard? atelierForSkill(String? skillId) {
  if (skillId == null) return null;
  return _atelierBySkill[skillId];
}

/// Fallback when a skill has no authored atelier card yet.
SkillAtelierCard atelierFallback({
  required String skillId,
  required String locale,
  Subject subject = Subject.reading,
}) {
  final label = skillsById[skillId]?.label ?? skillId;
  final fr = locale == 'fr';
  return SkillAtelierCard(
    skillId: skillId,
    hook: fr ? 'Explore : $label' : 'Explore: $label',
    hookFr: 'Explore : $label',
    didYouKnow: fr
        ? 'Chaque enfant commence à un endroit différent — le tien est ici.'
        : 'Every child starts somewhere different — yours is here.',
    didYouKnowFr:
        'Chaque enfant commence à un endroit différent — le tien est ici.',
  );
}

SkillAtelierCard atelierFor({
  required String? skillId,
  required String locale,
  Subject subject = Subject.reading,
}) {
  final authored = atelierForSkill(skillId);
  if (authored != null) return authored;
  return atelierFallback(
    skillId: skillId ?? subject.name,
    locale: locale,
    subject: subject,
  );
}
