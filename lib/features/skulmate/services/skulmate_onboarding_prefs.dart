import 'package:shared_preferences/shared_preferences.dart';

/// First-visit flags for SkulMate tab onboarding.
class SkulMateOnboardingPrefs {
  SkulMateOnboardingPrefs._();

  static const _welcomeKey = 'skulmate_welcome_seen_v1';

  static Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_welcomeKey) ?? false;
  }

  static Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeKey, true);
  }
}
