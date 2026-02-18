import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../services/skulmate_service.dart';

/// Service for managing skulMate onboarding state
class SkulMateOnboardingService {
  static const String _onboardingCompletedKey = 'skulmate_onboarding_completed';

  /// Check if user has completed skulMate onboarding
  static Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingCompletedKey) ?? false;
    } catch (e) {
      LogService.error('Error checking onboarding status: $e');
      return false;
    }
  }

  /// Mark onboarding as completed
  static Future<void> markOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);
      LogService.success('skulMate onboarding marked as completed');
    } catch (e) {
      LogService.error('Error marking onboarding complete: $e');
    }
  }

  /// Check if onboarding should be shown
  /// Returns false if user already has games (skip onboarding)
  static Future<bool> shouldShowOnboarding() async {
    try {
      // If already completed, don't show
      if (await hasCompletedOnboarding()) {
        return false;
      }

      // If user has games, skip onboarding
      final result = await SkulMateService.getGamesPaginated(limit: 1);
      final games = result['games'] as List;
      if (games.isNotEmpty) {
        // User has games, mark onboarding as complete automatically
        await markOnboardingComplete();
        return false;
      }

      return true;
    } catch (e) {
      LogService.error('Error checking if should show onboarding: $e');
      // On error, show onboarding to be safe
      return true;
    }
  }
}
