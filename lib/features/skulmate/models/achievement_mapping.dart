/// Maps in-app achievement ids to optional Game Center / Play Games ids.
class AchievementMapping {
  AchievementMapping._();

  static const Map<String, String> _platformIds = <String, String>{};

  static String? getPlatformAchievementId(String achievementId) {
    return _platformIds[achievementId];
  }
}
