import 'models/game_model.dart';

/// Types the app treats as "coming soon" in the game library (cannot open from dashboard).
/// Auto-generation must not leave the user stuck with only these types.
class SkulMateClientGamePolicy {
  SkulMateClientGamePolicy._();

  static const Set<GameType> comingSoonInLibrary = {
    GameType.diagramLabel,
    GameType.match3,
    GameType.bubblePop,
    GameType.wordSearch,
    GameType.crossword,
    GameType.simulation,
    GameType.mystery,
    GameType.escapeRoom,
  };

  static bool isReleasedInClient(GameType t) =>
      !comingSoonInLibrary.contains(t);

  /// API [gameType] strings to try when auto returns a broken or unreleased type.
  static const List<String> autoStableApiTypes = [
    'quiz',
    'flashcards',
    'matching',
    'fill_blank',
    'drag_drop',
  ];
}
