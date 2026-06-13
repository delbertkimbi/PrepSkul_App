/// Named bottom-navigation tabs for [MainNavigation].
///
/// Prefer [initialTabName] over raw indices so redirects stay correct when
/// tab order changes (e.g. SkulMate vs Requests).
class MainNavTab {
  MainNavTab._();

  static const String home = 'home';
  static const String findTutors = 'find_tutors';
  static const String requests = 'requests';
  static const String sessions = 'sessions';
  static const String profile = 'profile';

  /// Resolves a tab name to the bottom-nav index for the given role.
  /// Returns `null` when [tabName] is unknown for that role.
  static int? indexForRole(String role, String tabName) {
    final normalizedRole = role.toLowerCase();
    final normalizedTab = tabName.toLowerCase();

    if (normalizedRole == 'tutor') {
      switch (normalizedTab) {
        case home:
          return 0;
        case requests:
          return 1;
        case sessions:
          return 2;
        case profile:
          return 3;
      }
      return null;
    }

    if (normalizedRole == 'student' || normalizedRole == 'parent') {
      switch (normalizedTab) {
        case home:
          return 0;
        case findTutors:
          return 1;
        case requests:
          return 2;
        case profile:
          return 3;
      }
      return null;
    }

    return null;
  }

  /// Builds navigation arguments using a named tab (and optional extras).
  static Map<String, dynamic> argsForTab(
    String role,
    String tabName, {
    Map<String, dynamic>? extra,
  }) {
    final index = indexForRole(role, tabName);
    return {
      'initialTabName': tabName,
      if (index != null) 'initialTab': index,
      if (extra != null) ...extra,
    };
  }
}
