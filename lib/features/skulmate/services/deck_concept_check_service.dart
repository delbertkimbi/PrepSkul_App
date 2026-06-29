import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether a learner passed the deck concept check gate.
class DeckConceptCheckService {
  static const _prefix = 'skulmate_deck_concept_passed_';

  static Future<bool> hasPassed(String deckKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$deckKey') ?? false;
  }

  static Future<void> markPassed(String deckKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$deckKey', true);
  }

  static Future<void> clearPassed(String deckKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$deckKey');
  }
}
