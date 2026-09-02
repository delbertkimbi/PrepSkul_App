/// The parent-facing wording, in both languages.
///
/// Everything a *child* sees is already language-neutral — quantities, letters,
/// shapes and pictures — and everything a child hears comes from the closed
/// voice catalogue. The parent screens were the only English left, and they
/// were the screens that decided whether a Francophone family got past the
/// first page at all.
///
/// Deliberately a flat map rather than a localisation framework. There are two
/// languages and about thirty strings; ARB files, code generation and a
/// delegate would be more machinery than content. When a third language
/// arrives, this becomes the thing to replace — not the thing to extend.
class S {
  const S(this.locale);

  final String locale;

  bool get _fr => locale == 'fr';

  String _(String en, String fr) => _fr ? fr : en;

  // Language page.
  String get pickLanguageKicker => _('CHOOSE A LANGUAGE', 'CHOISISSEZ UNE LANGUE');
  String get pickLanguage => _('Which language?', 'Quelle langue ?');
  String get pickLanguageNote => _(
        'The one your child is learning to read in.',
        "Celle dans laquelle votre enfant apprend à lire.",
      );

  // Voice page.
  String get voiceKicker => _('WHO WILL TEACH THEM', 'QUI VA LEUR APPRENDRE');
  String get voiceTitle => _('Choose a voice', 'Choisissez une voix');
  String get voiceNote => _(
        'Tap the speaker to hear each one. Your child will learn with this voice.',
        "Touchez le haut-parleur pour écouter. Votre enfant apprendra avec cette voix.",
      );

  // Name page.
  String get nameKicker => _('FIRST, WHO IS PLAYING', "D'ABORD, QUI JOUE");
  String get nameTitle => _('What should we call them?', 'Comment doit-on les appeler ?');
  String get nameNote => _(
        'Just a first name. It stays on this phone.',
        'Juste un prénom. Il reste sur ce téléphone.',
      );
  String get nameHint => _('Ayuk', 'Ayuk');
  String get next => _('Next', 'Suivant');

  // Age page.
  String get ageKicker => _('ABOUT YOUR CHILD', 'À PROPOS DE VOTRE ENFANT');
  String get ageTitle => _('How old are they?', 'Quel âge ont-ils ?');
  String get ageNote => _(
        'This only picks the first question. What they do next decides the '
            'rest — two children the same age often start far apart.',
        "Cela choisit seulement la première question. C'est ce qu'ils font "
            'ensuite qui décide du reste — deux enfants du même âge commencent '
            'souvent très loin l’un de l’autre.',
      );
  String get olderThan => _('older', 'plus');

  // School page.
  String get schoolKicker => _('ABOUT THIS YEAR', 'CETTE ANNÉE');
  String get schoolTitle =>
      _('How much school have they had?', "Combien d'école ont-ils eu ?");
  String get schoolNote => _(
        'Days they actually went, not the class they are registered in.',
        "Les jours où ils y sont allés, pas la classe où ils sont inscrits.",
      );
  String get schoolNone => _('Not this year', 'Pas cette année');
  String get schoolNoneSub => _('They have not been going', "Ils n'y vont pas");
  String get schoolPatchy => _('On and off', 'De temps en temps');
  String get schoolPatchySub =>
      _('Some weeks, not others', 'Certaines semaines, pas d’autres');
  String get schoolDaily => _('Most days', 'Presque tous les jours');
  String get schoolDailySub => _('They go regularly', 'Ils y vont régulièrement');

  // Subject page.
  String get subjectKicker => _('WHERE TO START', 'PAR OÙ COMMENCER');
  String get subjectTitle =>
      _('What should we look at first?', 'Que regardons-nous en premier ?');
  String get subjectNote => _(
        'You can come back and do the others after.',
        'Vous pourrez revenir faire les autres ensuite.',
      );

  // What-they-can-do page.
  String get seenKicker => _('WHAT YOU HAVE SEEN', 'CE QUE VOUS AVEZ VU');
  String get seenNote => _(
        'Pick the furthest one you have actually watched them do.',
        'Choisissez la dernière chose que vous les avez vraiment vus faire.',
      );

  String get back => _('Back', 'Retour');

  // Handoff.
  String handoffTitle(String name) =>
      _('Now hand the phone to $name.', 'Passez le téléphone à $name.');
  String get handoffBody => _(
        'The game shows them how it works — they do not need you to explain '
            'anything. Sit close by, but let them tap for themselves.',
        "Le jeu leur montre comment ça marche — vous n'avez rien à expliquer. "
            'Restez près d’eux, mais laissez-les toucher eux-mêmes.',
      );
  String get handoffButton => _('They have it', 'C’est bon');

  // A new way of answering, shown once, the first time it appears.
  //
  // These are read by an adult if one is nearby, but the card is built to work
  // without them: a child gets the spoken line and a picture of the gesture,
  // because the child holding the phone is the one who cannot read.
  String get newWayKicker => _('SOMETHING NEW', 'QUELQUE CHOSE DE NOUVEAU');
  String get spellHow =>
      _('Tap the letters to build the word.', 'Touche les lettres pour écrire le mot.');
  String get matchHow => _('Join each one to its partner.', 'Relie chaque chose à sa paire.');
  String get orderHow =>
      _('Drag them in order, smallest first.', 'Glisse-les dans l’ordre, du plus petit au plus grand.');
  String get newWayGo => _('Got it', 'C’est compris');

  // Result.
  String comfortably(String name, String can) =>
      _('$name comfortably $can.', '$name y arrive : $can.');
  String get nextStep => _('NEXT STEP', 'PROCHAINE ÉTAPE');
  String get playAgain => _('Play again', 'Rejouer');
  String get backToPath => _('Back to path', 'Retour au parcours');
  String get statLevel => _('LEVEL', 'NIVEAU');
  String get statCorrect => _('GOT RIGHT', 'RÉUSSIS');
  String get statTime => _('THINKING TIME', 'TEMPS DE RÉFLEXION');
  String get privacy => _(
        'Works without internet. Nothing about your child leaves this phone.',
        'Fonctionne sans internet. Rien sur votre enfant ne quitte ce téléphone.',
      );
}
