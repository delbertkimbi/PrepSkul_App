class LearnerOnboardingCopy {
  const LearnerOnboardingCopy(this.isFrench);
  final bool isFrench;

  String get brand => 'PrepSkul';

  String get welcomeKicker => isFrench ? 'TON TUTEUR' : 'YOUR TUTOR';
  String get welcomeTitle =>
      isFrench ? 'Salut, moi c’est Mate.' : 'Hi. I’m Mate.';
  String get welcomeNote => isFrench
      ? 'Je peux t’aider à comprendre tes cours. Tu cherches un tuteur ? Je peux t’aider à en trouver un.'
      : 'I can help you understand your lessons. Need a tutor? I’ll help you find one.';
  String get welcomeCta => isFrench ? 'C’est parti !' : 'Let’s go';
  String get tutorEntry => isFrench ? 'Je suis tuteur' : 'I’m a tutor';

  String get languageKicker => isFrench ? 'LANGUE' : 'LANGUAGE';
  String get languageTitle => isFrench
      ? 'On se parle en quelle langue ?'
      : 'What language should I use with you?';
  String get languageNote => isFrench
      ? 'Tu pourras changer plus tard. Touche le haut-parleur pour entendre une question.'
      : 'You can switch later. Tap the speaker to hear any question.';

  String get whoKicker => isFrench ? 'TOI' : 'YOU';
  String get whoTitle =>
      isFrench ? 'Qui apprend ici ?' : 'Who is learning here?';
  String get whoStudent => isFrench ? 'C’est moi l’élève' : 'I’m the student';
  String get whoParent =>
      isFrench ? 'Je choisis pour mon enfant' : 'I’m choosing for my child';
  String get whoNote => isFrench
      ? 'Je vais poser quelques questions sur l’élève pour adapter les leçons et trouver un tuteur.'
      : 'I’ll ask a few things about the learner so lessons and tutor suggestions fit them.';

  String get nameKicker => isFrench ? 'PRÉNOM' : 'NAME';
  String get nameTitle =>
      isFrench ? 'Comment je t’appelle ?' : 'What should I call you?';
  String get nameHint => isFrench ? 'Ton prénom' : 'Your first name';
  String meetTitle(String name) =>
      isFrench ? 'Ravi de te rencontrer, $name.' : 'Nice to meet you, $name.';
  String get meetNote => isFrench
      ? 'Je vais utiliser tes réponses pour adapter la suite à tes besoins.'
      : 'I’ll use your answers to make the next steps fit your needs.';
  String get next => isFrench ? 'Continuer' : 'Continue';
  String get listen => isFrench ? 'Écouter' : 'Listen';
  String get skip => isFrench ? 'Passer' : 'Skip';
  String get back => isFrench ? 'Retour' : 'Back';

  String get countryKicker => isFrench ? 'PAYS' : 'COUNTRY';
  String get countryTitle => isFrench
      ? 'Dans quel pays se trouve ton école ?'
      : 'Where is your school located?';
  String get countryNote => isFrench
      ? 'Cameroun d’abord. On adapte le système scolaire, pas un modèle US.'
      : 'Cameroon first. We adapt the school system, not a US grade list.';

  String get cityKicker => isFrench ? 'VILLE' : 'CITY';
  String get cityTitle => isFrench ? 'Tu es où ?' : 'Which city?';

  String get systemKicker => isFrench ? 'SYSTÈME' : 'SYSTEM';
  String get systemTitle => isFrench
      ? 'Ton école suit le système français ou anglais ?'
      : 'Does your school follow the French or English system?';
  String get systemNote => isFrench
      ? 'Je m’en sers pour choisir les bonnes classes et matières.'
      : 'I’ll use this to match your classes and subjects.';

  String get levelKicker => isFrench ? 'CLASSE' : 'CLASS';
  String get levelTitle =>
      isFrench ? 'Tu es en quelle classe ?' : 'What class are you in?';

  String get subjectKicker => isFrench ? 'MATIÈRE' : 'SUBJECT';
  String get subjectTitle => isFrench
      ? 'De quoi tu as le plus besoin maintenant ?'
      : 'What do you need the most help with right now?';

  String get goalTitle => isFrench
      ? 'Qu’aimerais-tu réussir en premier ?'
      : 'What would you like help with first?';
  String get goalLessons => isFrench
      ? 'Comprendre mes cours et devoirs'
      : 'Understand lessons and homework';
  String get goalCatchUp => isFrench
      ? 'Rattraper ce que j’ai manqué'
      : 'Catch up on something I missed';
  String get goalExam =>
      isFrench ? 'Me préparer à un examen' : 'Prepare for an exam';

  String get examKicker => isFrench ? 'EXAMEN' : 'EXAM';
  String get examTitle =>
      isFrench ? 'Tu vises quel examen ?' : 'Which exam are you aiming at?';
  String get examNote => isFrench
      ? 'On s’en sert comme objectif, pas comme script.'
      : 'I treat it as a goal, not a script.';

  String get whenKicker => isFrench ? 'QUAND' : 'WHEN';
  String get whenTitle =>
      isFrench ? 'C’est pour quand, cet examen ?' : 'How soon is that exam?';

  String get channelKicker => isFrench ? 'VOIX' : 'VOICE';
  String get channelTitle => isFrench
      ? 'Tu préfères parler, écrire, ou les deux ?'
      : 'Do you like speaking, typing, or both?';
  String get channelNote => isFrench
      ? 'Sur un téléphone partagé, tape. Chez toi, parle.'
      : 'On a shared phone, type. At home, speak.';

  String get paceKicker => isFrench ? 'RYTHME' : 'PACE';
  String get paceTitle =>
      isFrench ? 'Quel rythme te va ?' : 'What teaching pace fits you?';

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
  String get modeTitle => isFrench
      ? 'Comment préfères-tu apprendre avec un tuteur ?'
      : 'How would you prefer to learn with a tutor?';
  String get modeOnline => isFrench ? 'En ligne' : 'Online';
  String get modeInPerson => isFrench ? 'En personne' : 'In person';
  String get modeFlexible =>
      isFrench ? 'Les deux me conviennent' : 'I’m open to either';

  String readyTitle(String name, String subject, String level) {
    final learner = name.trim().isEmpty
        ? (isFrench ? 'On' : 'Let’s')
        : name.trim();
    final detail = [
      if (subject.isNotEmpty) subject,
      if (level.isNotEmpty) level,
    ].join(isFrench ? ' · ' : ' · ');
    if (detail.isEmpty) {
      return isFrench
          ? '$learner, on avance à ton rythme.'
          : '$learner, let’s learn at your pace.';
    }
    return isFrench
        ? '$learner, on avance en $subject, niveau $level.'
        : '$learner, let’s work on $subject at $level.';
  }

  String readyNote(bool examPrep) => isFrench
      ? examPrep
            ? 'Mate t’aidera à comprendre la matière et à te préparer à l’examen que tu as choisi. Tu peux aussi trouver un tuteur selon ta ville et ta préférence.'
            : 'Mate t’aidera à comprendre tes cours. Tu peux aussi trouver un tuteur selon ta matière, ta classe et ta préférence.'
      : examPrep
      ? 'Mate can help you understand the subject and prepare for the exam you chose. You can also find a tutor based on your location and preference.'
      : 'Mate can help with your lessons. You can also find a tutor based on your subject, class, and learning preference.';
  String get readyCta => isFrench ? 'Continuer' : 'Continue';

  String payTitle(String name) {
    if (name.trim().isEmpty) {
      return isFrench ? 'Essaie Super.' : 'Try Super.';
    }
    return isFrench
        ? '${name.trim()}, essaie Super.'
        : '${name.trim()}, try Super.';
  }

  String payNote(String countryId) => countryId == 'cm'
      ? isFrench
            ? '7 jours offerts. Ensuite 2 500 XAF par mois.'
            : '7 days free. Then 2,500 XAF a month.'
      : isFrench
      ? '7 jours offerts. Le prix local sera affiché avant tout abonnement.'
      : '7 days free. Your local price is shown before you subscribe.';
  String get payCta => isFrench ? 'Essayer Super' : 'Try Super';
  String get paySkip => isFrench ? 'Pas maintenant' : 'Not now';
  List<String> get payBenefits => isFrench
      ? const [
          'Leçons Mate illimitées',
          'Parle sans bouton micro',
          'Trouve ou demande un tuteur live',
        ]
      : const [
          'Unlimited Mate lessons',
          'Talk without tapping a mic',
          'Find or request a live tutor',
        ];

  String ofCount(int at, int total) =>
      isFrench ? '${at + 1} sur $total' : '${at + 1} of $total';
}
