import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists how a deck/game was last played — scroll vs classic flashcards.
class ScrollPlayModePrefs {
  ScrollPlayModePrefs._();

  static const _prefix = 'skulmate_play_mode_';
  static const scroll = 'scroll';
  static const flashcards = 'flashcards';

  static Future<String?> preferredModeFor(String gameId) async {
    if (gameId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$gameId');
  }

  static Future<void> setPreferredMode({
    required String gameId,
    required String mode,
  }) async {
    if (gameId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$gameId', mode);
  }

  static Future<void> markScroll(String gameId) =>
      setPreferredMode(gameId: gameId, mode: scroll);

  static Future<void> markFlashcards(String gameId) =>
      setPreferredMode(gameId: gameId, mode: flashcards);

  /// Batch load for game library labels.
  static Future<Map<String, String>> loadAllForGames(
    Iterable<String> gameIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, String>{};
    for (final id in gameIds) {
      if (id.isEmpty) continue;
      final mode = prefs.getString('$_prefix$id');
      if (mode != null) out[id] = mode;
    }
    return out;
  }

  /// Also check deck progress modesCompleted for scroll.
  static bool deckProgressIndicatesScroll(String modesCompletedJson) {
    try {
      final decoded = jsonDecode(modesCompletedJson);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).contains('scroll');
      }
    } catch (_) {}
    return false;
  }
}
