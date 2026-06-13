import 'package:flutter/widgets.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:provider/provider.dart';
import '../models/skulmate_intake_models.dart';

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

  String get viewAll => isFrench ? 'Tout voir' : 'View all';

  String get showLess => isFrench ? 'Réduire' : 'Show less';

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

  String get tellSkulMateMore => isFrench
      ? 'Dis-en plus à SkulMate…'
      : 'Tell SkulMate more…';

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
            ? 'Transforme en jeu'
            : 'Turn this into a game';
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
