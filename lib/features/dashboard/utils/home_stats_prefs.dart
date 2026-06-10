import 'package:shared_preferences/shared_preferences.dart';

/// User-scoped SharedPreferences keys for learner/parent home progress counters.
class HomeStatsPrefs {
  HomeStatsPrefs._();

  static String activeTutorsKey(String userId) =>
      'home_active_tutors_count_$userId';

  static String allTimeSessionsKey(String userId) =>
      'home_all_time_sessions_count_$userId';

  static String upcomingSessionsKey(String userId) =>
      'home_upcoming_sessions_count_$userId';

  static const String legacyActiveTutorsKey = 'home_active_tutors_count';
  static const String legacyAllTimeSessionsKey = 'home_all_time_sessions_count';
  static const String legacyUpcomingSessionsKey = 'home_upcoming_sessions_count';

  static Future<({int activeTutors, int allTimeSessions, int upcomingSessions})>
      read(SharedPreferences prefs, String? userId) async {
    if (userId == null || userId.isEmpty) {
      return (activeTutors: 0, allTimeSessions: 0, upcomingSessions: 0);
    }

    var activeTutors = prefs.getInt(activeTutorsKey(userId));
    var allTimeSessions = prefs.getInt(allTimeSessionsKey(userId));
    var upcomingSessions = prefs.getInt(upcomingSessionsKey(userId));

    // One-time migration from legacy global keys.
    if (activeTutors == null &&
        allTimeSessions == null &&
        upcomingSessions == null) {
      activeTutors = prefs.getInt(legacyActiveTutorsKey);
      allTimeSessions = prefs.getInt(legacyAllTimeSessionsKey);
      upcomingSessions = prefs.getInt(legacyUpcomingSessionsKey);
      if (activeTutors != null ||
          allTimeSessions != null ||
          upcomingSessions != null) {
        await write(
          prefs,
          userId,
          activeTutors: activeTutors ?? 0,
          allTimeSessions: allTimeSessions ?? 0,
          upcomingSessions: upcomingSessions ?? 0,
        );
        await clearLegacy(prefs);
      }
    }

    return (
      activeTutors: activeTutors ?? 0,
      allTimeSessions: allTimeSessions ?? 0,
      upcomingSessions: upcomingSessions ?? 0,
    );
  }

  static Future<void> write(
    SharedPreferences prefs,
    String userId, {
    required int activeTutors,
    required int allTimeSessions,
    required int upcomingSessions,
  }) async {
    if (userId.isEmpty) return;
    await prefs.setInt(activeTutorsKey(userId), activeTutors);
    await prefs.setInt(allTimeSessionsKey(userId), allTimeSessions);
    await prefs.setInt(upcomingSessionsKey(userId), upcomingSessions);
    await clearLegacy(prefs);
  }

  static Future<void> clearForUser(
    SharedPreferences prefs,
    String userId,
  ) async {
    if (userId.isEmpty) return;
    await prefs.remove(activeTutorsKey(userId));
    await prefs.remove(allTimeSessionsKey(userId));
    await prefs.remove(upcomingSessionsKey(userId));
  }

  static Future<void> clearLegacy(SharedPreferences prefs) async {
    await prefs.remove(legacyActiveTutorsKey);
    await prefs.remove(legacyAllTimeSessionsKey);
    await prefs.remove(legacyUpcomingSessionsKey);
  }
}
