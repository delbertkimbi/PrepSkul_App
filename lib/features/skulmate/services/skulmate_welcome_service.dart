import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import '../services/skulmate_service.dart';

/// Per-user welcome sheet state for first SkulMate tab visit.
class SkulMateWelcomeService {
  static const String _welcomeSeenKeyPrefix = 'skulmate_welcome_seen_';
  static const String _legacyKey = 'skulmate_welcome_seen';

  static String _userKey() {
    final userId = SupabaseService.client.auth.currentUser?.id ?? '';
    return userId.isNotEmpty ? '$_welcomeSeenKeyPrefix$userId' : _legacyKey;
  }

  static Future<bool> hasSeenWelcome() async {
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
      LogService.error('Error checking SkulMate welcome status: $e');
      return false;
    }
  }

  static Future<void> clearForUser(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_welcomeSeenKeyPrefix$userId');
      await prefs.remove(_legacyKey);
      // Legacy onboarding keys from removed flow.
      await prefs.remove('skulmate_onboarding_completed_$userId');
      await prefs.remove('skulmate_onboarding_completed');
    } catch (e) {
      LogService.error('Error clearing SkulMate welcome prefs: $e');
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_userKey(), true);
      LogService.success('SkulMate welcome marked as seen');
    } catch (e) {
      LogService.error('Error marking SkulMate welcome seen: $e');
    }
  }

  /// Whether to show the one-time welcome sheet on SkulMate tab visit.
  static Future<bool> shouldShow() async {
    try {
      if (await hasSeenWelcome()) return false;

      final result = await SkulMateService.getGamesPaginated(limit: 1).timeout(
        const Duration(seconds: 2),
      );
      final games = result['games'] as List;
      if (games.isNotEmpty) {
        await markSeen();
        return false;
      }

      return true;
    } catch (e) {
      LogService.error('Error checking if should show SkulMate welcome: $e');
      return false;
    }
  }
}
