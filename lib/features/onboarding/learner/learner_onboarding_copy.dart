class LearnerOnboardingCopy {
  const LearnerOnboardingCopy(this.isFrench);
  final bool isFrench;

  String get brand => 'PrepSkul';

  String get welcomeKicker => isFrench ? 'TON TUTEUR' : 'YOUR TUTOR';
  String get welcomeTitle =>
      isFrench ? 'Salut ! Moi c’est Mate.' : 'Hi there! I’m Mate.';
  String get welcomeNote => isFrench
      ? 'On commence par ton école, pas un formulaire de matching.'
      : 'We start with your school, not a tutor-matching form.';
  String get welcomeCta => isFrench ? 'C’est parti !' : 'Let’s go';

  String get languageKicker => isFrench ? 'LANGUE' : 'LANGUAGE';
  String get languageTitle => isFrench
      ? 'On se parle en quelle langue ?'
      : 'What language should I use with you?';
  String get languageNote => isFrench
      ? 'Tu pourras changer plus tard. Je lis chaque question à voix haute.'
      : 'You can switch later. I’ll read each question out loud.';

  String get whoKicker => isFrench ? 'TOI' : 'YOU';
  String get whoTitle =>
      isFrench ? 'Qui apprend ici ?' : 'Who is learning here?';
  String get whoStudent => isFrench ? 'C’est moi l’élève' : 'I’m the student';
  String get whoParent => isFrench
      ? 'Je suis parent, et j’apprends aussi'
      : 'I’m a parent, and I’m studying too';
  String get whoNote => isFrench
      ? 'Les deux comptes sont des élèves pour moi. Personne ne “surveille”.'
      : 'Both accounts are students for me. Nobody is “watching”.';

  String get nameKicker => isFrench ? 'PRÉNOM' : 'NAME';
  String get nameTitle => isFrench ? 'Comment je t’appelle ?' : 'What should I call you?';
  String get nameHint => isFrench ? 'Ton prénom' : 'Your first name';
  String get next => isFrench ? 'Continuer' : 'Continue';
  String get skip => isFrench ? 'Passer' : 'Skip';
  String get back => isFrench ? 'Retour' : 'Back';

  String get countryKicker => isFrench ? 'PAYS' : 'COUNTRY';
  String get countryTitle => isFrench
      ? 'Où est ton école ?'
      : 'Where is your school?';
  String get countryNote => isFrench
      ? 'Cameroun d’abord. On adapte le système scolaire, pas un modèle US.'
      : 'Cameroon first. We adapt the school system, not a US grade list.';

  String get cityKicker => isFrench ? 'VILLE' : 'CITY';
  String get cityTitle => isFrench ? 'Tu es où ?' : 'Which city?';

  String get systemKicker => isFrench ? 'SYSTÈME' : 'SYSTEM';
  String get systemTitle => isFrench
      ? 'Francophone ou anglophone ?'
      : 'Francophone or anglophone?';
  String get systemNote => isFrench
      ? 'Ça change les classes et les examens. Ce n’est pas la même école.'
      : 'This changes the classes and exams. It’s not the same school.';

  String get levelKicker => isFrench ? 'CLASSE' : 'CLASS';
  String get levelTitle => isFrench
      ? 'Tu es en quelle classe ?'
      : 'What class are you in?';

  String get subjectKicker => isFrench ? 'MATIÈRE' : 'SUBJECT';
  String get subjectTitle => isFrench
      ? 'De quoi tu as le plus besoin maintenant ?'
      : 'What do you need the most help with right now?';

  String get examKicker => isFrench ? 'EXAMEN' : 'EXAM';
  String get examTitle => isFrench
      ? 'Tu vises quel examen ?'
      : 'Which exam are you aiming at?';
  String get examNote => isFrench
      ? 'On s’en sert comme objectif, pas comme script.'
      : 'I treat it as a goal, not a script.';

  String get whenKicker => isFrench ? 'QUAND' : 'WHEN';
  String get whenTitle => isFrench
      ? 'C’est pour quand, cet examen ?'
      : 'How soon is that exam?';

  String get channelKicker => isFrench ? 'VOIX' : 'VOICE';
  String get channelTitle => isFrench
      ? 'Tu préfères parler, écrire, ou les deux ?'
      : 'Do you like speaking, typing, or both?';
  String get channelNote => isFrench
      ? 'Sur un téléphone partagé, tape. Chez toi, parle.'
      : 'On a shared phone, type. At home, speak.';

  String get paceKicker => isFrench ? 'RYTHME' : 'PACE';
  String get paceTitle => isFrench
      ? 'Quel rythme te va ?'
      : 'What teaching pace fits you?';

  String get feelKicker => isFrench ? 'JOUR J' : 'EXAM DAY';
  String get feelTitle => isFrench
      ? 'Le jour de l’examen, tu es plutôt…'
      : 'On exam day you usually…';

  String get interestKicker => isFrench ? 'TOI' : 'YOU';
  String get interestTitle => isFrench
      ? 'T’aimes quoi, hors de l’école ?'
      : 'What are you into outside school?';
  String get interestNote => isFrench
      ? 'Je m’en sers pour les exemples. Tu peux en choisir plusieurs.'
      : 'I’ll use these in examples. Pick as many as you like.';

  String get readyKicker => isFrench ? 'PRÊT' : 'READY';
  String get readyTitle => isFrench
      ? 'Je te coach. Un tuteur PrepSkul prend le relais si on bloque.'
      : 'I’ll tutor you. A PrepSkul live tutor steps in if we get stuck.';
  String get readyNote => isFrench
      ? 'Plus de 100 matières. BEPC, Bac, GCE, et ce que tu m’apportes.'
      : 'A hundred subjects. BEPC, Bac, GCE, and whatever you bring me.';
  String get readyCta => isFrench ? 'Continuer' : 'Continue';

  String payTitle(String name) {
    if (name.trim().isEmpty) {
      return isFrench ? 'Essaie Super.' : 'Try Super.';
    }
    return isFrench ? '${name.trim()}, essaie Super.' : '${name.trim()}, try Super.';
  }

  String get payNote => isFrench
      ? '7 jours offerts. Ensuite 2 500 XAF par mois.'
      : '7 days free. Then 2,500 XAF a month.';
  String get payCta => isFrench ? 'Essayer Super' : 'Try Super';
  String get paySkip => isFrench ? 'Pas maintenant' : 'Not now';
  List<String> get payBenefits => isFrench
      ? const [
          'Leçons Mate illimitées',
          'Drills BEPC, Bac et GCE',
          'Un tuteur live si on bloque',
        ]
      : const [
          'Unlimited Mate lessons',
          'Exam drills for BEPC, Bac, and GCE',
          'A live tutor if we get stuck',
        ];

  String ofCount(int at, int total) =>
      isFrench ? '${at + 1} sur $total' : '${at + 1} of $total';
}
