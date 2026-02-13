import 'package:flutter/foundation.dart' show kDebugMode;

/// Live session test accounts configuration.
///
/// Add the Supabase auth user IDs (auth.users.id) for one learner and one tutor
/// who may join and attend live sessions even before the scheduled date/time.
/// All other users remain restricted to joining only at the scheduled time.
///
/// For local testing: when [restrictJoinsToTestUsersForLocalTesting] is true,
/// only the users in [_testUserIds] can join any session; all others are blocked.
///
/// To find user IDs: Supabase Dashboard → Authentication → Users, or query
/// `auth.users` (id column).
class LiveSessionTestConfig {
  LiveSessionTestConfig._();

  /// Tutor and learner UIDs for local testing. Only these two can join sessions
  /// when [restrictJoinsToTestUsersForLocalTesting] is true.
  static const List<String> _testUserIds = [
    '69047dc1-b0ed-4de6-ac33-e27b95413079', // Tutor test account
    '8954db0d-1dfd-4013-bdbb-2c7ac843bce6', // Learner test account
  ];

  /// When true (and in debug/local), only [_testUserIds] can join sessions.
  /// Set to false to allow all users to join (e.g. production or open testing).
  static const bool restrictJoinsToTestUsersForLocalTesting = true;

  /// Returns true if [userId] is one of the dedicated live-session test accounts.
  static bool isTestUser(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return _testUserIds.contains(userId);
  }

  /// Backwards‑compatible alias used in some screens to allow certain
  /// accounts to join live sessions before the scheduled start time.
  ///
  /// Currently this is identical to [isTestUser]; extracted as a separate
  /// method so behaviour can be tuned later without touching call sites.
  static bool isTestUserForEarlyJoin(String? userId) {
    return isTestUser(userId);
  }

  /// Returns true if the user is allowed to join a session.
  /// When [restrictJoinsToTestUsersForLocalTesting] is true (debug only),
  /// only test users can join; otherwise all users can join.
  static bool canUserJoinSession(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    if (!restrictJoinsToTestUsersForLocalTesting || !kDebugMode) {
      return true;
    }
    return _testUserIds.contains(userId);
  }

  /// Message shown when join is blocked due to local testing restriction.
  static String get localTestingRestrictionMessage =>
      'Session join is restricted to test accounts for local testing.';
}
