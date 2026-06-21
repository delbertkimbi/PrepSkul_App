import '../models/game_model.dart';

/// Single source of truth for which game types are playable in the client.
class SkulMateClientGamePolicy {
  SkulMateClientGamePolicy._();

  static const Set<GameType> comingSoonTypes = {
    GameType.diagramLabel,
    GameType.match3,
    GameType.bubblePop,
    GameType.wordSearch,
    GameType.crossword,
    GameType.simulation,
    GameType.mystery,
    GameType.escapeRoom,
  };

  /// @deprecated Use [comingSoonTypes]
  static Set<GameType> get comingSoonInLibrary => comingSoonTypes;

  static bool isReleasedInClient(GameType t) => !comingSoonTypes.contains(t);

  static bool isComingSoonApiType(String apiType) {
    return comingSoonTypes.contains(GameType.fromString(apiType));
  }

  /// API strings the client may generate and open.
  static const List<String> releasedApiTypes = [
    'quiz',
    'flashcards',
    'matching',
    'fill_blank',
    'drag_drop',
    'puzzle_pieces',
  ];

  /// API strings to try when auto returns broken or unreleased types.
  static const List<String> autoStableApiTypes = releasedApiTypes;

  static const List<String> setupSelectableApiTypes = [
    'auto',
    ...releasedApiTypes,
  ];
}
