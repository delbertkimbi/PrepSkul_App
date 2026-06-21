import 'package:flutter/widgets.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:provider/provider.dart';
import '../models/skulmate_intake_models.dart';
import '../models/next_stop_suggestion.dart';

/// Bilingual SkulMate UI strings (EN/FR).
class SkulMateCopy {
  SkulMateCopy(this.isFrench);

  final bool isFrench;

  factory SkulMateCopy.of(BuildContext context) {
    final code = context.watch<LanguageNotifier>().currentLocale.languageCode;
    return SkulMateCopy(code == 'fr');
  }

  /// Use in callbacks / async handlers — never [watch] outside build.
  factory SkulMateCopy.read(BuildContext context) {
    final code =
        context.read<LanguageNotifier>().currentLocale.languageCode;
    return SkulMateCopy(code == 'fr');
  }

  String get heroQuestion => isFrench
      ? 'Qu\'est-ce qu\'on révise aujourd\'hui ?'
      : 'What shall we revise today?';

  String get intentPlaceholder =>
      isFrench ? 'Je veux réviser…' : 'I want to revise…';

  String get continueSection => jumpBackIn;

  String get jumpBackIn =>
      isFrench ? 'Reprendre' : 'Jump back in';

  /// Gentle resurfacing — no exam/syllabus wording.
  String get rerouteNudgeLead =>
      isFrench ? 'Ça vaut un autre essai' : 'Worth another look';

  String get rerouteNudgeAction =>
      isFrench ? 'Rejouer' : 'Replay';

  String get rerouteNudgeDismiss =>
      isFrench ? 'Pas maintenant' : 'Not now';

  String get tutorEscalationTitle => isFrench
      ? 'Un coup de main ?'
      : 'Want a hand with this?';

  String tutorEscalationBody(String gameTitle) => isFrench
      ? 'Si $gameTitle reste difficile, un tuteur PrepSkul peut t\'aider à clarifier.'
      : 'If $gameTitle is still tricky, a PrepSkul tutor can help you get unstuck.';

  String get tutorEscalationAction =>
      isFrench ? 'Voir les tuteurs' : 'Browse tutors';

  String get tutorEscalationDismiss =>
      isFrench ? 'Pas maintenant' : 'Not now';

  String get viewAll => isFrench ? 'Tout voir' : 'View all';

  String get showLess => isFrench ? 'Réduire' : 'Show less';

  String get intentSheetTitle => isFrench
      ? 'Comment veux-tu réviser ?'
      : 'How do you want to revise?';

  String get intakeChatTitle => isFrench ? 'Discussion' : 'Chat';

  String get intakeAnalyzing => isFrench
      ? 'Lecture de ton contenu…'
      : 'Reading your material…';

  String get intakeTopicChip =>
      isFrench ? 'Sujet' : 'Topic';

  String get intakeTopicFallbackYoutube => isFrench
      ? 'cette vidéo YouTube'
      : 'this YouTube video';

  String get intakeTopicFallbackNotes => isFrench
      ? 'tes notes'
      : 'your notes';

  String get intakeTopicFallbackLecture => isFrench
      ? 'ton enregistrement'
      : 'your recording';

  String get intakeTopicFallbackPhoto => isFrench
      ? 'tes photos'
      : 'your photo notes';

  String get intakeTopicFallbackDocument => isFrench
      ? 'ton document'
      : 'your document';

  String get intakeTopicFallbackGeneric => isFrench
      ? 'ton contenu'
      : 'your material';

  String intakeChatSummary(String topicLabel) => isFrench
      ? 'On dirait que tu as partagé du contenu sur $topicLabel. Comment veux-tu réviser ?'
      : 'It looks like you\'ve shared material on $topicLabel. How would you like to revise?';

  String modeCardSubtitle(SkulMateIntentMode mode, String topicLabel) {
    if (mode == SkulMateIntentMode.path) return topicLabel;
    return modeSubtitle(mode);
  }

  String get intakeRefinePlaceholder =>
      isFrench ? 'Je veux réviser…' : 'I want to revise…';

  String get myGames => isFrench ? 'Mes jeux' : 'My games';

  String get upload => isFrench ? 'Importer' : 'Upload';

  String get photo => isFrench ? 'Photo' : 'Photo';

  String get paste => isFrench ? 'Coller' : 'Paste';

  String get youtube => 'YouTube';

  String get sessions => isFrench ? 'Séances' : 'Sessions';

  /// @deprecated Use [sessions]
  String get fromClass => sessions;

  String get pasteNotesTitle =>
      isFrench ? 'Coller des notes' : 'Paste notes';

  String get pasteNotesSubtitle => isFrench
      ? 'Colle ton texte ici — SkulMate le transformera en jeux de révision.'
      : 'Drop your notes here — SkulMate will turn them into revision games.';

  String get pasteTitleOptional =>
      isFrench ? 'Titre (optionnel)' : 'Title (optional)';

  String get pasteTitleHint => isFrench
      ? 'Ex. Biologie chapitre 3'
      : 'e.g. Biology chapter 3';

  String get pasteYourNotes =>
      isFrench ? 'Tes notes' : 'Your notes';

  String get pasteNotesHint => isFrench
      ? 'Colle ou tape tes notes ici…'
      : 'Paste or type your notes here…';

  String pasteCharCount(int len, int min, bool ok) => isFrench
      ? '$len / $min caractères${ok ? ' ✓' : ''}'
      : '$len / $min characters${ok ? ' ✓' : ''}';

  String get continueLabel =>
      isFrench ? 'Continuer' : 'Continue';

  String get youtubeImportTitle =>
      isFrench ? 'Importer depuis YouTube' : 'Import from YouTube';

  String get youtubeImportSubtitle => isFrench
      ? 'Colle un lien de vidéo pour créer des jeux à partir du contenu.'
      : 'Paste a video link to build games from the content.';

  String get youtubeUrlLabel =>
      isFrench ? 'Lien YouTube' : 'YouTube link';

  String get youtubeImportHint => isFrench
      ? 'Les vidéos publiques youtube.com et youtu.be sont prises en charge.'
      : 'Public youtube.com and youtu.be links are supported.';

  String get importFromNotes =>
      isFrench ? 'Importer depuis des notes' : 'Import from notes';

  String get searchHint => isFrench ? 'Rechercher' : 'Search';

  String get historyEmpty => isFrench
      ? 'Aucun jeu pour le moment. Importe des notes pour commencer.'
      : 'No games yet. Import notes to get started.';

  String get startRecording =>
      isFrench ? 'Commencer l\'enregistrement' : 'Start recording';

  String get stopRecording =>
      isFrench ? 'Arrêter l\'enregistrement' : 'Stop recording';

  String get recordingComplete =>
      isFrench ? 'Enregistrement terminé !' : 'Recording complete!';

  String recordingDuration(String duration) => isFrench
      ? 'Durée : $duration'
      : 'Duration: $duration';

  String get generateNotes =>
      isFrench ? 'Générer des notes' : 'Generate notes';

  String get recordAgain =>
      isFrench ? 'Réenregistrer' : 'Record again';

  String get micPermissionDenied => isFrench
      ? 'Autorise l\'accès au micro pour enregistrer.'
      : 'Allow microphone access to record.';

  String get recordingFailed => isFrench
      ? 'Impossible de démarrer l\'enregistrement.'
      : 'Could not start recording.';

  String get lectureRecordingTitle =>
      isFrench ? 'Cours enregistré' : 'Recorded lecture';

  String lectureRecordingPlaceholder(String duration, String? path) => isFrench
      ? 'Enregistrement audio du cours ($duration). Transcription en cours de préparation.${path != null ? '\n\n[Fichier: $path]' : ''}'
      : 'Audio lecture recording ($duration). Transcription will be added soon.${path != null ? '\n\n[File: $path]' : ''}';

  String get transcribingNotes =>
      isFrench ? 'Transcription en cours…' : 'Transcribing…';

  String get transcriptionFailed => isFrench
      ? 'Impossible de transcrire l\'enregistrement. Réessaie.'
      : 'Could not transcribe the recording. Please try again.';

  String get transcriptTooShort => isFrench
      ? 'Pas assez de parole détectée. Enregistre un peu plus longtemps.'
      : 'Not enough speech detected. Record a bit longer.';

  String get more => isFrench ? 'Plus' : 'More';

  String get history => isFrench ? 'Historique' : 'History';

  String get noRecordedSessions => isFrench
      ? 'Aucune session enregistrée pour le moment.'
      : 'No recorded sessions yet.';

  String get recordLecture =>
      isFrench ? 'Enregistrer le cours' : 'Record lecture';

  String get quizlet => 'Quizlet';

  String get deck => isFrench ? 'Paquet' : 'Deck';

  String get comingSoon =>
      isFrench ? 'Bientôt disponible' : 'Coming soon';

  String get welcomeSheetTitle =>
      isFrench ? 'Bienvenue sur SkulMate' : 'Welcome to SkulMate';

  String welcomeHeadline({bool isParent = false}) {
    if (isParent) {
      return isFrench
          ? 'Aidez votre enfant à transformer ses notes en jeux de révision'
          : 'Help your child turn notes into revision games';
    }
    return isFrench
        ? 'Transforme tes notes en jeux de révision'
        : 'Turn your notes into revision games';
  }

  String welcomeBenefitNotes({bool isParent = false}) {
    if (isParent) {
      return isFrench
          ? 'Importez ses notes, documents ou photos pour générer quiz et cartes.'
          : 'Import their notes, documents, or photos to generate quizzes and flashcards.';
    }
    return isFrench
        ? 'Importe tes notes, documents ou photos pour générer des quiz et cartes.'
        : 'Import notes, documents, or photos to generate quizzes and flashcards.';
  }

  String welcomeBenefitResume({bool isParent = false}) {
    if (isParent) {
      return isFrench
          ? 'Reprenez là où il/elle s\'est arrêté(e) — la progression est sauvegardée.'
          : 'Pick up where they left off — progress is saved automatically.';
    }
    return isFrench
        ? 'Reprends là où tu t\'es arrêté — ta progression est sauvegardée.'
        : 'Resume where you left off — your progress is saved automatically.';
  }

  String welcomeBenefitLeaderboard({bool isParent = false}) {
    if (isParent) {
      return isFrench
          ? 'Suivez l\'XP et le classement de votre enfant avec ses amis.'
          : 'Track their XP and leaderboard progress with friends.';
    }
    return isFrench
        ? 'Gagne de l\'XP et grimpe au classement avec tes amis.'
        : 'Earn XP and climb the leaderboard with friends.';
  }

  String welcomeAiLine({bool isParent = false}) {
    if (isParent) {
      return isFrench
          ? 'L\'IA crée des quiz, cartes et jeux d\'association à partir de leur contenu.'
          : 'AI builds quizzes, flashcards, and matching games from their content.';
    }
    return isFrench
        ? 'L\'IA crée des quiz, cartes et jeux d\'association à partir de ton contenu.'
        : 'AI builds quizzes, flashcards, and matching games from your content.';
  }

  String get welcomeCta =>
      isFrench ? 'C\'est parti !' : 'Let\'s go!';

  String get paywallTitle =>
      isFrench ? 'Continue à réviser' : 'Keep revising';

  String get paywallSubtitle => isFrench
      ? 'Tu as utilisé ta révision gratuite du jour. Ajoute des crédits pour continuer maintenant.'
      : 'You\'ve used today\'s free revision. Add credits to keep going now.';

  String get paywallUsageTitle => isFrench
      ? 'Ta révision gratuite aujourd\'hui'
      : 'Your free revision today';

  String get paywallDocLabel =>
      isFrench ? 'Documents et texte' : 'Documents & text';

  String get paywallImageLabel =>
      isFrench ? 'Images' : 'Images';

  String paywallCreditsBalance(int balance) => isFrench
      ? 'Solde : $balance crédits'
      : 'Balance: $balance credits';

  String get paywallCreditsActiveHint => isFrench
      ? 'Tes crédits sont actifs — pas de limite gratuite à afficher.'
      : 'Your credits are active — no free daily limits apply.';

  String plansHeroWithCredits(int balance) => isFrench
      ? 'Tu as $balance crédits de révision. Continue à générer des jeux.'
      : 'You have $balance revision credits. Keep generating games.';

  String get plansHeroWithCreditsShort => isFrench
      ? 'Continue à générer des jeux quand tu veux.'
      : 'Keep generating games anytime.';

  String get plansHeroFreeRemaining => isFrench
      ? 'Révision gratuite disponible aujourd\'hui — voir ton quota ci-dessous.'
      : 'Free revision available today — see your quota below.';

  String activePlanBadge(String tier) => isFrench
      ? 'Forfait $tier actif'
      : '$tier plan active';

  String get plansTopUpHeading => isFrench
      ? 'Recharger les crédits'
      : 'Top up credits';

  String get plansChooseHeading => isFrench
      ? 'Choisir un forfait'
      : 'Choose a plan';

  String get paywallSeeAllPlans =>
      isFrench ? 'Voir tous les forfaits' : 'See all plans';

  String get revisionPlansTitle =>
      isFrench ? 'Crédits de révision' : 'Revision credits';

  String get myProgressTitle =>
      isFrench ? 'Ma progression' : 'My progress';

  String get progressXpLabel => isFrench ? 'XP total' : 'Total XP';

  String progressLevelLabel(int level) => isFrench
      ? 'Niveau $level'
      : 'Level $level';

  String get progressStreakLabel =>
      isFrench ? 'Série en cours' : 'Current streak';

  String progressBestStreak(int best) => isFrench
      ? 'Meilleure série : $best jours'
      : 'Best streak: $best days';

  String get progressGamesLabel =>
      isFrench ? 'Jeux joués' : 'Games played';

  String progressAccuracy(double pct) => isFrench
      ? 'Précision : ${pct.toStringAsFixed(0)}%'
      : 'Accuracy: ${pct.toStringAsFixed(0)}%';

  String get progressTopicsTitle => isFrench
      ? 'Tes sujets en cours'
      : 'Your focus topics';

  String get progressTopicsEmpty => isFrench
      ? 'Joue quelques jeux de révision — tes sujets apparaîtront ici.'
      : 'Play a few revision games — your topics will show up here.';

  String get nextStopTitle =>
      isFrench ? 'Prochaine étape' : 'Next stop';

  String nextStopHeadline(NextStopSuggestion s) {
    switch (s.kind) {
      case NextStopKind.dueReview:
        return isFrench
            ? 'Réviser : ${s.subtitle ?? s.title}'
            : 'Review: ${s.subtitle ?? s.title}';
      case NextStopKind.weakTopic:
        return isFrench
            ? 'Retravailler : ${s.title}'
            : 'Revisit: ${s.title}';
      case NextStopKind.continueGame:
        return isFrench
            ? 'Reprendre : ${s.title}'
            : 'Continue: ${s.title}';
      case NextStopKind.fromSession:
        final tutor = s.tutorName ?? (isFrench ? 'ton tuteur' : 'your tutor');
        return isFrench
            ? 'Après ta séance avec $tutor : ${s.subtitle ?? s.title}'
            : 'From your session with $tutor: ${s.subtitle ?? s.title}';
    }
  }

  String nextStopCta(NextStopKind kind) {
    switch (kind) {
      case NextStopKind.dueReview:
        return isFrench ? 'Réviser' : 'Review';
      case NextStopKind.weakTopic:
        return isFrench ? 'Rejouer' : 'Replay';
      case NextStopKind.continueGame:
        return isFrench ? 'Continuer' : 'Continue';
      case NextStopKind.fromSession:
        return isFrench ? 'Réviser la séance' : 'Review session';
    }
  }

  String progressMasteryBandLabel(String band) {
    switch (band) {
      case 'solid':
        return isFrench ? 'Solide' : 'Solid';
      case 'building':
        return isFrench ? 'En progrès' : 'Building';
      default:
        return isFrench ? 'À retravailler' : 'Needs work';
    }
  }

  String get profileRevisionSection =>
      isFrench ? 'Ma révision' : 'My revision';

  String get profileViewGames =>
      isFrench ? 'Voir mes jeux' : 'View my games';

  String get profileCreditsCta =>
      isFrench ? 'Crédits' : 'Credits';

  String lectureErrorTitle(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('not enough speech') || lower.contains('too short')) {
      return isFrench
          ? 'Pas assez de parole détectée'
          : 'Not enough speech detected';
    }
    if (lower.contains('network') ||
        lower.contains('failed to fetch') ||
        lower.contains('connection')) {
      return isFrench ? 'Problème de connexion' : 'Connection problem';
    }
    if (lower.contains('not found') || lower.contains('permission')) {
      return isFrench
          ? 'Enregistrement introuvable'
          : 'Recording not found';
    }
    return isFrench
        ? 'Impossible de transcrire'
        : 'Could not transcribe lecture';
  }

  String lectureErrorDetails(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('not enough speech') || lower.contains('too short')) {
      return transcriptTooShort;
    }
    if (lower.contains('network') || lower.contains('failed to fetch')) {
      return isFrench
          ? 'Vérifie ta connexion et réessaie.'
          : 'Check your connection and try again.';
    }
    return raw;
  }

  String get friendsTitle => isFrench ? 'Amis' : 'Friends';

  String get friendsTab => isFrench ? 'Amis' : 'Friends';

  String get requestsTab => isFrench ? 'Demandes' : 'Requests';

  String get challengesTitle => isFrench ? 'Défis' : 'Challenges';

  String get challengesAll => isFrench ? 'Tous' : 'All';

  String get challengesSent => isFrench ? 'Envoyés' : 'Sent';

  String get challengesReceived => isFrench ? 'Reçus' : 'Received';

  String get addFriendTitle => isFrench ? 'Ajouter un ami' : 'Add Friend';

  String get createChallengeTitle =>
      isFrench ? 'Créer un défi' : 'Create Challenge';

  String get tellSkulMateMore => isFrench
      ? 'Dis-en plus sur ce que tu veux réviser…'
      : 'Tell us more about what you want to revise…';

  String get errorAddCredits =>
      isFrench ? 'Ajouter des crédits' : 'Add revision credits';

  String get errorGoBack => isFrench ? 'Retour' : 'Go back';

  String get errorTryAgain => isFrench ? 'Réessayer' : 'Try again';

  String get errorManualText => isFrench
      ? 'Saisir le texte manuellement'
      : 'Enter text manually instead';

  String get scrollFeedTitle =>
      isFrench ? 'Révision rapide' : 'Quick revision';

  String get scrollTapReveal =>
      isFrench ? 'Appuie pour voir la réponse' : 'Tap to reveal answer';

  String get scrollTapTerm =>
      isFrench ? 'Appuie pour revoir le terme' : 'Tap to see term again';

  String get scrollGotIt => isFrench ? 'Je sais' : 'Got it';

  String get scrollAgain => isFrench ? 'Encore' : 'Again';

  String get scrollDone => isFrench ? 'Terminer' : 'Done';

  String get scrollKeepGoing =>
      isFrench ? 'Continuer' : 'Keep going';

  String get scrollGateTitle =>
      isFrench ? 'Belle série !' : 'Nice run!';

  String scrollGateBody(int known, int reviewed) => isFrench
      ? '$known sur $reviewed — continuer ou terminer la séance ?'
      : '$known of $reviewed — keep scrolling or wrap up?';

  String get scrollSessionEndTitle =>
      isFrench ? 'Séance terminée' : 'Session complete';

  String scrollSessionEndBody(int reviewed, int known) => isFrench
      ? 'Tu as revu $reviewed carte${reviewed == 1 ? '' : 's'} ($known bien connue${known == 1 ? '' : 's'}).'
      : 'You reviewed $reviewed card${reviewed == 1 ? '' : 's'} ($known marked known).';

  String get scrollEmptyQueue => isFrench
      ? 'Rien à défiler pour l\'instant — crée un jeu ou reviens quand des révisions sont dues.'
      : 'Nothing to scroll yet — create a game or come back when reviews are due.';

  String modeLabel(SkulMateIntentMode mode) {
    switch (mode) {
      case SkulMateIntentMode.play:
        return isFrench ? 'Jouer' : 'Play';
      case SkulMateIntentMode.scroll:
        return isFrench ? 'Défiler' : 'Scroll';
      case SkulMateIntentMode.path:
        return isFrench ? 'Parcours' : 'Path';
      case SkulMateIntentMode.drill:
        return isFrench ? 'Répéter' : 'Drill';
      case SkulMateIntentMode.sheet:
        return isFrench ? 'Fiche' : 'Sheet';
      case SkulMateIntentMode.fromClass:
        return isFrench ? 'Depuis le cours' : 'From class';
    }
  }

  String modeSubtitle(SkulMateIntentMode mode) {
    switch (mode) {
      case SkulMateIntentMode.play:
        return isFrench
            ? 'Transforme en quiz ou jeu'
            : 'Turn this into a quiz or game';
      case SkulMateIntentMode.scroll:
        return isFrench
            ? 'Révision en défilement'
            : 'Swipe through bite-sized revision';
      case SkulMateIntentMode.path:
        return isFrench
            ? 'Itinéraire étape par étape'
            : 'Step-by-step learn route';
      case SkulMateIntentMode.drill:
        return isFrench
            ? 'Cartes de rappel actif'
            : 'Quick recall cards';
      case SkulMateIntentMode.sheet:
        return isFrench
            ? 'Fiche de révision'
            : 'One-page summary to revise';
      case SkulMateIntentMode.fromClass:
        return isFrench
            ? 'Révision depuis ta session'
            : 'Revision from your live session';
    }
  }

  String modeCta(SkulMateIntentMode mode) {
    switch (mode) {
      case SkulMateIntentMode.play:
        return isFrench ? 'Commencer à jouer' : 'Start playing';
      case SkulMateIntentMode.scroll:
        return isFrench ? 'Commencer à défiler' : 'Start scrolling';
      case SkulMateIntentMode.path:
        return isFrench ? 'Commencer le parcours' : 'Start path';
      case SkulMateIntentMode.drill:
        return isFrench ? 'Commencer à répéter' : 'Start drilling';
      case SkulMateIntentMode.sheet:
        return isFrench ? 'Créer la fiche' : 'Create sheet';
      case SkulMateIntentMode.fromClass:
        return isFrench
            ? 'Jouer le défi du cours'
            : 'Play class challenge';
    }
  }
}
