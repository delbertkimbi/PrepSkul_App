import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import '../services/skulmate_service.dart';

/// Service for managing skulMate onboarding state
/// Uses user-scoped keys so each user sees onboarding on first use (e.g. after switching accounts)
class SkulMateOnboardingService {
  static const String _onboardingCompletedKeyPrefix = 'skulmate_onboarding_completed_';
  static const String _legacyKey = 'skulmate_onboarding_completed';

  static String _userKey() {
    final userId = SupabaseService.client.auth.currentUser?.id ?? '';
    return userId.isNotEmpty
        ? '$_onboardingCompletedKeyPrefix$userId'
        : _legacyKey;
  }

  /// Check if current user has completed skulMate onboarding
  static Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _userKey();
      final value = prefs.getBool(key);
      if (value != null) return value;
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        return prefs.getBool(_legacyKey) ?? false;
      }
      return false;
    } catch (e) {
      LogService.error('Error checking onboarding status: $e');
      return false;
    }
  }

  /// Clear onboarding flag for a specific user (logout / account switch).
  static Future<void> clearForUser(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_onboardingCompletedKeyPrefix$userId');
      await prefs.remove(_legacyKey);
    } catch (e) {
      LogService.error('Error clearing skulMate onboarding: $e');
    }
  }

  /// Mark onboarding as completed for current user
  static Future<void> markOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userKey(), true);
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
