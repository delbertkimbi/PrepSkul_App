import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight session signals for the unified intelligence layer.
class SkulMateSessionHistoryService {
  SkulMateSessionHistoryService._();

  static const _followUpPrefix = 'skulmate_tutor_followups_';

  static Future<void> recordTutorFollowUp({
    required String gameId,
    required String topicLabel,
  }) async {
    if (gameId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_followUpPrefix$gameId';
    final count = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, count + 1);
    await prefs.setString('${key}_topic', topicLabel);
    await prefs.setString(
      '${key}_last',
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  static Future<int> tutorFollowUpCount(String gameId) async {
    if (gameId.isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_followUpPrefix$gameId') ?? 0;
  }

  static Future<void> resetTutorFollowUps(String gameId) async {
    if (gameId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_followUpPrefix$gameId');
    await prefs.remove('$_followUpPrefix${gameId}_topic');
    await prefs.remove('$_followUpPrefix${gameId}_last');
  }
}
