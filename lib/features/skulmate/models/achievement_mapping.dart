import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:prepskul/core/services/log_service.dart';

class AchievementMapping {
  static final Map<String, String> _iosAchievements = {};
  static final Map<String, String> _androidAchievements = {};

  static void initialize({
    required Map<String, String> iosMap,
    required Map<String, String> androidMap,
  }) {
    _iosAchievements.clear();
    _androidAchievements.clear();
    _iosAchievements.addAll(iosMap);
    _androidAchievements.addAll(androidMap);
    LogService.debug('🎮 [AchievementMapping] Initialized with ${_iosAchievements.length} iOS and ${_androidAchievements.length} Android mappings.');
  }

  static String? getPlatformAchievementId(String achievementId) {
    if (kIsWeb) return null; // Platform achievements not available on web

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _iosAchievements[achievementId];
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidAchievements[achievementId];
    }
    return null;
  }

  static String? getIOSAchievementId(String achievementId) {
    return _iosAchievements[achievementId];
  }

  static String? getAndroidAchievementId(String achievementId) {
    return _androidAchievements[achievementId];
  }
}

