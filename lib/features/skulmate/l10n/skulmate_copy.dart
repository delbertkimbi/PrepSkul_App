import 'package:flutter/widgets.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:provider/provider.dart';
import '../models/deck_study_intent_mode.dart';
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

  String get importPhotosTitle =>
      isFrench ? 'Importer des photos' : 'Import photos';

  String get importPhotosContinue => isFrench ? 'Continuer' : 'Continue';

  String importPhotosLimit(int count, int max) => isFrench
      ? '$count sur $max photos'
      : '$count of $max photos';

  String get importPhotosAdd => isFrench ? 'Ajouter une photo' : 'Add photo';

  String get puzzleSequenceTitle =>
      isFrench ? 'Coffre du savoir' : 'Knowledge Vault';

  String get puzzleSequenceSubtitle => isFrench
      ? 'Déverrouille chaque chambre avec tes notes'
      : 'Unlock each chamber using your notes';

  String get puzzleMissionLine => isFrench
      ? 'Chaque chambre teste une facette de ton cours — diagramme, choix, ordre.'
      : 'Each chamber tests a different slice of your notes — diagram, choices, order.';

  String puzzleIntroSteps(int count) => isFrench
      ? '$count étapes à placer'
      : '$count steps to place';

  String puzzleIntroTime(int minutes) => isFrench
      ? '~$minutes min'
      : '~$minutes min';

  String puzzleIntroReward(int xp) => isFrench
      ? '+$xp XP possible'
      : 'Up to +$xp XP';

  String puzzleIntroMastery(String topic) => isFrench
      ? 'Maîtrise · $topic'
      : 'Mastery · $topic';

  String get puzzleStartButton =>
      isFrench ? 'Commencer le puzzle' : 'Start puzzle';

  String get briefingScreenTitle =>
      isFrench ? 'Avant de jouer' : 'Before you play';

  String get briefingLearningSection =>
      isFrench ? 'CE QUE TU APPRENDS' : 'WHAT YOU\'RE LEARNING';

  String get briefingHowToPlaySection =>
      isFrench ? 'COMMENT JOUER' : 'HOW TO PLAY';

  String get briefingReadySection =>
      isFrench ? 'PRÊT' : 'READY';

  String get briefingStartButton =>
      isFrench ? 'Commencer' : 'Start game';

  String get briefingJourneySection =>
      isFrench ? 'PARCOURS DU COFFRE' : 'VAULT JOURNEY';

  String puzzleChamberProgress(int current, int total) => isFrench
      ? 'Étape $current sur $total'
      : 'Step $current of $total';

  String get puzzleDiagramDecrypting => isFrench
      ? 'Déchiffrement du diagramme…'
      : 'Decrypting vault diagram…';

  String get puzzleVaultLocked => isFrench
      ? 'Diagramme du coffre'
      : 'Vault diagram';

  String puzzleVaultChamberLabel(int index) => isFrench
      ? 'Étape $index'
      : 'Step $index';

  String get puzzleStepTypePick =>
      isFrench ? 'Choix' : 'Pick the answer';

  String get puzzleStepTypeHotspot =>
      isFrench ? 'Associe les étiquettes' : 'Match the labels';

  String get puzzleStepTypeOrder =>
      isFrench ? 'Ordre' : 'Tap in order';

  String puzzleOrderProgress(int done, int total) => isFrench
      ? '$done sur $total dans l\'ordre'
      : '$done of $total in order';

  String briefingTopicLine(String topic) => isFrench
      ? 'Sujet · $topic'
      : 'Topic · $topic';

  /// Narrative prompt — never "What is step 3?"
  String puzzleNextPrompt({
    required int placedCount,
    String? previousStepLabel,
    required int total,
  }) {
    if (placedCount == 0) {
      return isFrench
          ? 'Par quoi commence ce processus ?'
          : 'What happens first in this process?';
    }
    if (placedCount >= total - 1) {
      return isFrench
          ? 'Dernière pièce. Que se passe-t-il ensuite ?'
          : 'Last piece. What happens next?';
    }
    if (previousStepLabel != null && previousStepLabel.trim().isNotEmpty) {
      final short = previousStepLabel.length > 42
          ? '${previousStepLabel.substring(0, 39)}…'
          : previousStepLabel;
      return isFrench
          ? 'Que vient après « $short » ?'
          : 'What comes after "$short"?';
    }
    return isFrench
        ? 'Que se passe-t-il ensuite ?'
        : 'What happens next?';
  }

  String get puzzleWrongStepNudge => isFrench
      ? 'Pas tout à fait. Essaie une autre carte.'
      : 'Not quite. Try another card.';

  String get puzzleStepCorrect => isFrench ? 'Bien placé.' : 'Locked in.';

  String get puzzleWrongStep => puzzleWrongStepNudge;

  String get puzzleSlotLabel => isFrench
      ? 'Prochaine étape'
      : 'Next in the sequence';

  String get puzzleGoalHeader => isFrench
      ? 'TON OBJECTIF'
      : 'YOUR GOAL';

  String get puzzleTapLabelThenSlot => isFrench
      ? 'Touche une étiquette, puis la case qui correspond.'
      : 'Tap a label, then the slot it belongs in.';

  String get puzzleSlotEmpty => isFrench ? 'Case vide' : 'Empty slot';

  String get puzzlePickFromBelow => isFrench
      ? 'Choisis ta réponse'
      : 'Pick your answer';

  String get puzzleWhyLabel => isFrench ? 'POURQUOI' : 'WHY THIS FITS';

  String puzzleProgressPlaced(int placed, int total) => isFrench
      ? '$placed sur $total placées'
      : '$placed of $total placed';

  String puzzleCoachHint(int completed, int total) {
    if (completed == 0) {
      return isFrench
          ? 'Commence par la première étape du processus.'
          : 'Start with the first step in the process.';
    }
    if (completed >= total - 1) {
      return isFrench
          ? 'Dernière étape ! Tu y es presque.'
          : 'Last step! You are almost there.';
    }
    if (completed >= total ~/ 2) {
      return isFrench
          ? 'Tu avances bien. Choisis la prochaine étape.'
          : 'You are on a roll. Pick what happens next.';
    }
    return isFrench
        ? 'Bonne piste. Continue dans l\'ordre logique.'
        : 'Good start. Keep building the sequence.';
  }

  String get puzzleSequenceComplete => isFrench
      ? 'Parfait ! Séquence complète.'
      : 'Perfect! Sequence complete.';

  String puzzleProgressText(int placed, int total) =>
      puzzleProgressPlaced(placed, total);

  String get puzzlePickTileHint => puzzlePickFromBelow;

  String get puzzleConceptTilesLabel =>
      isFrench ? 'Cartes disponibles' : 'Available cards';

  String get matchingConnected => isFrench ? 'Connecté !' : 'Connected!';

  String matchingPairLinked(String left, String right) => isFrench
      ? '« $left » ↔ « $right »'
      : '"$left" ↔ "$right"';

  String get matchingContinueButton =>
      isFrench ? 'Continuer' : 'Continue';

  String get matchingSectionComplete => isFrench
      ? 'Section terminée ! Appuie sur Continuer quand tu es prêt.'
      : 'Section complete! Tap Continue when you are ready.';

  String get matchingTimeUpContinue => isFrench
      ? 'Temps écoulé. Les réponses sont révélées. Appuie sur Continuer.'
      : 'Time is up. Answers revealed. Tap Continue when ready.';

  String get matchingNiceMatch => isFrench
      ? 'Bien joué ! Bonne association.'
      : 'Nice match!';

  String get matchingTryAgain => isFrench
      ? 'Pas tout à fait. Réessaie.'
      : 'Oops! Not quite. Try again.';

  String get fillBlankCorrect => isFrench
      ? 'Correct ! Beau travail.'
      : 'Correct! Nice work.';

  String fillBlankIncorrect(String answer) => isFrench
      ? 'Pas tout à fait. La bonne réponse : $answer'
      : 'Not quite. The answer is: $answer';

  String fillBlankTimeUp(String answer) => isFrench
      ? 'Temps écoulé. La bonne réponse : $answer'
      : "Time's up. The answer is: $answer";

  String get fillBlankEmptyAnswer => isFrench
      ? 'Choisis ou tape une réponse.'
      : 'Pick or type an answer first.';

  String get matchingTapHint => isFrench
      ? 'Touche un terme, puis sa définition. Retour instantané.'
      : 'Tap a term, then its match. Instant feedback.';

  String intakePhotoContextSummary(String summary) {
    final trimmed = summary.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.endsWith('?')) return trimmed;
    return isFrench
        ? '$trimmed Comment veux-tu réviser ?'
        : '$trimmed How would you like to revise?';
  }

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

  String get myDecks => isFrench ? 'Mes paquets' : 'My decks';

  String get allGamesTitle => isFrench ? 'Mes jeux' : 'My games';

  String get allDecksTitle => isFrench ? 'Paquets' : 'Decks';

  String get publicDecks => isFrench ? 'Paquets publics' : 'Public decks';

  String get searchGamesHint =>
      isFrench ? 'Rechercher mes jeux' : 'Search my games';

  String get searchDecksHint => searchMyDecks;

  String get emptyGamesLibrary => isFrench
      ? 'Aucun jeu pour l\'instant. Importe des notes pour commencer.'
      : 'No games yet. Upload notes to get started.';

  String get emptyPublicDecks => isFrench
      ? 'Les paquets publics arrivent bientôt — classement par matière.'
      : 'Public decks are coming soon — browse by subject here.';

  String get studyDeck => isFrench ? 'Réviser le paquet' : 'Study deck';

  String get tapToRevealAnswer =>
      isFrench ? 'Appuie pour voir la réponse' : 'Tap to reveal answer';

  String get memoriseSwipeTrueFalse => isFrench
      ? 'Glisse à droite = Vrai, à gauche = Faux'
      : 'Swipe right = True, left = False';

  String get memoriseSwipeKnow => isFrench
      ? 'Glisse à droite si tu sais, à gauche sinon'
      : 'Swipe right if you know it, left if not';

  String get memoriseTapReveal => isFrench
      ? 'Touchez la carte pour révéler'
      : 'Tap card to reveal';

  String get startLearning => isFrench ? 'Commencer' : 'Start learning';

  String get magicImport => isFrench ? 'Import magique' : 'Magic Import';

  String get magicImportSubtitle => isFrench
      ? 'Transforme PDF, notes, YouTube et plus en cartes'
      : 'Turn PDFs, notes, YouTube and more into flashcards';

  String get photoNotes =>
      isFrench ? 'Photographier tes notes' : 'Photograph your notes';

  String get subdecks => isFrench ? 'Sous-paquets' : 'Subdecks';

  String get leaderboardSharePrompt => isFrench
      ? 'Tu veux tes amis ici ?'
      : 'Want your friends here?';

  String get leaderboardShareBody => isFrench
      ? 'Partage le paquet avec eux.'
      : 'Share the deck with them.';

  String get shareDeck => isFrench ? 'Partager le paquet' : 'Share deck';

  String get deckLesson => isFrench ? 'Leçon du paquet' : 'Deck lesson';

  String get addToDeck => isFrench ? 'Ajouter au paquet' : 'Add to deck';

  String get writeOwnCards => isFrench
      ? 'Écris tes propres cartes'
      : 'Write your own cards';

  String get makeLesson => isFrench
      ? 'Crée une leçon étape par étape'
      : 'Make a step-by-step lesson';

  String get createNotes => isFrench
      ? 'Crée des notes libres'
      : 'Create freeform notes';

  String get importSources => isFrench
      ? 'Notes, YouTube, PDF…'
      : 'Notes, YouTube, PDF…';

  String get aiTutorMode => isFrench ? 'Tuteur IA' : 'AI Tutor';

  String get aiTutorSubtitle => isFrench
      ? 'Apprends étape par étape'
      : 'Learn step by step';

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
      ? 'Colle ton texte ici. SkulMate le transformera en jeux de révision.'
      : 'Drop your notes here. SkulMate will turn them into revision games.';

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

  String get recordingTooShort => isFrench
      ? 'Enregistrement trop court. Parle au moins 15 secondes avant de continuer.'
      : 'Recording is too short. Speak for at least 15 seconds before continuing.';

  String get more => isFrench ? 'Plus' : 'More';

  String get history => isFrench ? 'Historique' : 'History';

  String get noRecordedSessions => isFrench
      ? 'Aucune session enregistrée pour le moment.'
      : 'No recorded sessions yet.';

  String get recordLecture =>
      isFrench ? 'Enregistrer le cours' : 'Record lecture';

  String get quizlet => 'Quizlet';

  String get deck => isFrench ? 'Paquet' : 'Deck';

  String get selectDeck => isFrench ? 'Choisir un paquet' : 'Select deck';

  String get searchMyDecks =>
      isFrench ? 'Rechercher mes paquets' : 'Search my decks';

  String get emptyDecksHint => isFrench
      ? 'Importe des notes pour créer ton premier paquet.'
      : 'Upload notes to create your first deck.';

  String get deckStudyChatTitle =>
      isFrench ? 'Aide-moi à réviser ce paquet' : 'Help me study this deck';

  String get deckStudyUserMessage => isFrench
      ? 'Aide-moi à réviser ce paquet.'
      : 'Help me study this deck.';

  String deckStudyChatPrompt(String deckTitle) => isFrench
      ? 'Parfait — comment veux-tu travailler sur $deckTitle ?'
      : 'Great — how would you like to work through $deckTitle?';

  String get deckStudyRefinePlaceholder =>
      isFrench ? 'Je veux apprendre…' : 'I want to learn…';

  String deckStudyModeLabel(DeckStudyIntentMode mode) {
    switch (mode) {
      case DeckStudyIntentMode.tutor:
        return isFrench ? 'Comprendre' : 'Understand';
      case DeckStudyIntentMode.drill:
        return isFrench ? 'Drill' : 'Drill';
      case DeckStudyIntentMode.play:
        return isFrench ? 'Jouer' : 'Play';
      case DeckStudyIntentMode.path:
        return isFrench ? 'Parcours' : 'Path';
      case DeckStudyIntentMode.scroll:
        return isFrench ? 'Défilement' : 'Scroll';
    }
  }

  String deckStudyModeSubtitle(DeckStudyIntentMode mode, String deckTitle) {
    switch (mode) {
      case DeckStudyIntentMode.tutor:
        return isFrench
            ? 'Tuteur IA — explications et quiz rapides'
            : 'AI tutor — explanations and quick checks';
      case DeckStudyIntentMode.drill:
        return isFrench
            ? 'Rappel actif avec tes cartes'
            : 'Active recall with your cards';
      case DeckStudyIntentMode.play:
        return isFrench
            ? 'Jeux interactifs depuis ce paquet'
            : 'Interactive games from this deck';
      case DeckStudyIntentMode.path:
        return deckTitle;
      case DeckStudyIntentMode.scroll:
        return isFrench
            ? 'Parcourir tes cartes en flux'
            : 'Swipe through your deck';
    }
  }

  String deckStudyModeCta(DeckStudyIntentMode mode) {
    switch (mode) {
      case DeckStudyIntentMode.tutor:
        return isFrench ? 'Comprendre' : 'Understand';
      case DeckStudyIntentMode.drill:
        return isFrench ? 'Drill' : 'Drill';
      case DeckStudyIntentMode.play:
        return isFrench ? 'Jouer' : 'Play';
      case DeckStudyIntentMode.path:
        return isFrench ? 'Commencer le parcours' : 'Start path';
      case DeckStudyIntentMode.scroll:
        return isFrench ? 'Défilement' : 'Scroll';
    }
  }

  String get saveDeckTitle =>
      isFrench ? 'Enregistrer comme paquet ?' : 'Save as a deck?';

  String get saveDeckSubtitle => isFrench
      ? 'Garde ce contenu comme paquet réutilisable pour notes, jeux et tuteur IA.'
      : 'Keep this upload as a reusable deck for notes, games, and AI tutor study.';

  String get saveDeckToggle =>
      isFrench ? 'Créer un paquet' : 'Create a deck';

  String get saveDeckNameLabel =>
      isFrench ? 'Nom du paquet' : 'Deck name';

  String get saveDeckConfirm =>
      isFrench ? 'Enregistrer le paquet' : 'Save deck';

  String get saveDeckSkip =>
      isFrench ? 'Pas maintenant' : 'Not now';

  String get addDeckTitle =>
      isFrench ? 'Nouveau paquet' : 'New deck';

  String get addDeckSubtitle => isFrench
      ? 'Importe des notes — on crée un paquet réutilisable avec résumés et cartes.'
      : 'Import notes — we\'ll build a reusable deck with summaries and cards.';

  String get addDeckCta =>
      isFrench ? 'Créer un paquet' : 'Create a deck';

  String get deckCreateTitle =>
      isFrench ? 'Ajouter un paquet' : 'Add deck';

  String get deckCreateInMyDecks =>
      isFrench ? 'Dans : Mes paquets' : 'In: My decks';

  String get deckNameLabel =>
      isFrench ? 'Nom du paquet' : 'Deck name';

  String get deckNamePlaceholder =>
      isFrench ? 'Ex. Enzymes' : 'E.g. Enzymes';

  String get deckColourLabel =>
      isFrench ? 'Couleur' : 'Colour';

  String get noCardsYet =>
      isFrench ? 'Pas encore de cartes' : 'No cards yet';

  String get noCardsSubtitle => isFrench
      ? 'Ajoute des cartes pour commencer à réviser'
      : 'Add some cards to start quizzing';

  String get writeCards =>
      isFrench ? 'Écrire des cartes' : 'Write cards';

  String get scrollFinishSession =>
      isFrench ? 'Terminer' : 'Done';

  String get scrollLeaveTitle =>
      isFrench ? 'Quitter la séance ?' : 'Leave session?';

  String get scrollLeaveBody => isFrench
      ? 'Ta progression sera enregistrée.'
      : 'Your progress so far will be saved.';

  String get scrollLeaveConfirm =>
      isFrench ? 'Quitter' : 'Leave';

  String get publicDecksComingSoonTitle =>
      isFrench ? 'Paquets publics bientôt' : 'Public decks coming soon';

  String get publicDecksComingSoonBody => isFrench
      ? 'Découvre et révise des paquets partagés par d\'autres apprenants, classés par matière et niveau.'
      : 'Browse and study decks shared by other learners — organised by subject and level.';

  String get orImportMaterial =>
      isFrench ? 'Ou importer du contenu' : 'Or import material';

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
          ? 'Reprenez là où il/elle s\'est arrêté(e). La progression est sauvegardée.'
          : 'Pick up where they left off. Progress is saved automatically.';
    }
    return isFrench
        ? 'Reprends là où tu t\'es arrêté. Ta progression est sauvegardée.'
        : 'Resume where you left off. Your progress is saved automatically.';
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
      ? 'Tes crédits sont actifs. Pas de limite gratuite à afficher.'
      : 'Your credits are active. No free daily limits apply.';

  String plansHeroWithCredits(int balance) => isFrench
      ? 'Tu as $balance crédits de révision. Continue à générer des jeux.'
      : 'You have $balance revision credits. Keep generating games.';

  String get plansHeroWithCreditsShort => isFrench
      ? 'Continue à générer des jeux quand tu veux.'
      : 'Keep generating games anytime.';

  String get plansHeroFreeRemaining => isFrench
      ? 'Révision gratuite disponible aujourd\'hui. Voir ton quota ci-dessous.'
      : 'Free revision available today. See your quota below.';

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
      ? 'Joue quelques jeux de révision. Tes sujets apparaîtront ici.'
      : 'Play a few revision games. Your topics will show up here.';

  String get progressActivityTitle =>
      isFrench ? 'Activité' : 'Activity';

  String progressSessionsOnDay(int count) {
    if (count == 0) {
      return isFrench ? 'Aucun jeu ce jour-là' : 'No games on this day';
    }
    if (count == 1) {
      return isFrench ? '1 jeu ce jour-là' : '1 game on this day';
    }
    return isFrench ? '$count jeux ce jour-là' : '$count games on this day';
  }

  String progressXpToNext(int xp) => isFrench
      ? '$xp XP pour le niveau suivant'
      : '$xp XP to next level';

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

  String intakeErrorTitle(SkulMateIntakeSource source, String raw) {
    if (source == SkulMateIntakeSource.youtube) {
      return youtubeIntakeErrorTitle(raw);
    }
    if (source == SkulMateIntakeSource.lecture) {
      return lectureErrorTitle(raw);
    }
    if (source == SkulMateIntakeSource.photo ||
        source == SkulMateIntakeSource.document) {
      final lower = raw.toLowerCase();
      if (lower.contains('image processing') ||
          lower.contains('provider') ||
          lower.contains('ocr')) {
        return isFrench
            ? 'Impossible de lire ce fichier'
            : 'Could not read this file';
      }
    }
    return isFrench
        ? 'Impossible d\'analyser la source'
        : 'Could not analyze source';
  }

  String intakeErrorDetails(SkulMateIntakeSource source, String raw) {
    if (source == SkulMateIntakeSource.youtube) {
      return youtubeIntakeErrorDetails(raw);
    }
    if (source == SkulMateIntakeSource.lecture) {
      return lectureErrorDetails(raw);
    }
    return raw;
  }

  String youtubeIntakeErrorTitle(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('no captions') || lower.contains('no usable captions')) {
      return isFrench
          ? 'Pas de sous-titres pour cette vidéo'
          : 'No captions for this video';
    }
    if (lower.contains('caption service') ||
        lower.contains('not available yet')) {
      return isFrench
          ? 'Service de sous-titres indisponible'
          : 'Caption service unavailable';
    }
    return isFrench
        ? 'Impossible de lire cette vidéo YouTube'
        : 'Could not read this YouTube video';
  }

  String youtubeIntakeErrorDetails(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('caption service') ||
        lower.contains('not available yet')) {
      return isFrench
          ? 'Tu peux quand même lancer la génération. Nous récupérerons les sous-titres côté serveur. Sinon, colle tes notes manuellement.'
          : 'You can still start generation. We will fetch captions on the server. Or paste notes manually.';
    }
    if (lower.contains('no captions') || lower.contains('no usable captions')) {
      return isFrench
          ? 'Essaie une vidéo avec sous-titres activés, ou colle tes notes manuellement.'
          : 'Try a video with subtitles on, or paste notes manually.';
    }
    return raw;
  }

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

  String get scrollObjective => isFrench
      ? 'Fais défiler — révèle, puis dis si tu le savais.'
      : 'Swipe up — reveal, then mark if you knew it.';

  String get scrollSwipeHint =>
      isFrench ? 'Glisse vers le haut' : 'Swipe up';

  String get scrollRevealAction =>
      isFrench ? 'Révéler' : 'Reveal';

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
      ? '$known sur $reviewed. Continuer ou terminer la séance ?'
      : '$known of $reviewed. Keep scrolling or wrap up?';

  String get scrollSessionEndTitle =>
      isFrench ? 'Séance terminée' : 'Session complete';

  String scrollSessionEndBody(int reviewed, int known) => isFrench
      ? 'Tu as revu $reviewed carte${reviewed == 1 ? '' : 's'} ($known bien connue${known == 1 ? '' : 's'}).'
      : 'You reviewed $reviewed card${reviewed == 1 ? '' : 's'} ($known marked known).';

  String get scrollEmptyQueue => isFrench
      ? 'Rien à défiler pour l\'instant. Crée un jeu ou reviens quand des révisions sont dues.'
      : 'Nothing to scroll yet. Create a game or come back when reviews are due.';

  String get scrollLoadingTitle =>
      isFrench ? 'Leçon en chargement…' : 'Lesson loading…';

  String get scrollLoadingSubtitle => isFrench
      ? 'Préparation de ta session de révision'
      : 'Getting your revision session ready';

  String get scrollMusicOn => isFrench ? 'Musique' : 'Music';

  String get scrollMusicOff => isFrench ? 'Muet' : 'Muted';

  String get scrollSfxOn => isFrench ? 'Sons' : 'SFX';

  String get scrollSfxOff => isFrench ? 'Sons off' : 'SFX off';

  String get scrollListen => isFrench ? 'Écouter' : 'Listen';

  String get scrollListenMode => isFrench ? 'Mode écoute' : 'Listen mode';

  String get scrollPlayAloud => isFrench ? 'Lire à voix haute' : 'Play aloud';

  String get scrollHookDefault =>
      isFrench ? 'POV : tu comprends enfin' : 'POV: you finally get it';

  String get scrollTermLabel => isFrench ? 'Terme' : 'Term';

  String get scrollQuickCheck =>
      isFrench ? 'Vérification rapide' : 'Quick check';

  String get scrollMatchLabel => isFrench ? 'Associer' : 'Match';

  String get scrollRevealMatch =>
      isFrench ? 'Révéler la paire' : 'Reveal the pair';

  String get scrollCelebrateTitle =>
      isFrench ? 'Belle série !' : 'Nice streak!';

  String get scrollCelebrateBody => isFrench
      ? 'Continue — tu es en feu.'
      : 'Keep going — you\'re on a roll.';

  String get scrollFeedTypeLabel => isFrench ? 'Défilement' : 'Scroll';

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
