import 'student_tab_index.dart';
import 'tutor_tab_index.dart';

/// Semantic navigation arguments — avoids brittle hard-coded tab indices.
class NavTabArgs {
  NavTabArgs._();

  static Map<String, dynamic> student({
    String? tab,
    int? initialTab,
    String? highlightRequestId,
    String? sessionId,
    String? trialId,
  }) {
    return {
      if (tab != null) 'tab': tab,
      if (initialTab != null) 'initialTab': initialTab,
      if (highlightRequestId != null) 'highlightRequestId': highlightRequestId,
      if (sessionId != null) 'sessionId': sessionId,
      if (trialId != null) 'trialId': trialId,
    };
  }

  static Map<String, dynamic> studentHome() => student(tab: 'home');

  static Map<String, dynamic> studentFindTutors() => student(tab: 'findTutors');

  static Map<String, dynamic> studentSkulMate() => student(tab: 'skulMate');

  static Map<String, dynamic> studentRequests({String? highlightRequestId}) =>
      student(tab: 'requests', highlightRequestId: highlightRequestId);

  static Map<String, dynamic> studentProfile() => student(tab: 'profile');

  static Map<String, dynamic> tutor({
    String? tab,
    int? initialTab,
    String? sessionId,
    String? trialId,
    String? bookingId,
  }) {
    return {
      if (tab != null) 'tab': tab,
      if (initialTab != null) 'initialTab': initialTab,
      if (sessionId != null) 'sessionId': sessionId,
      if (trialId != null) 'trialId': trialId,
      if (bookingId != null) 'bookingId': bookingId,
    };
  }

  static Map<String, dynamic> tutorRequests({String? bookingId}) =>
      tutor(tab: 'requests', bookingId: bookingId);

  static Map<String, dynamic> tutorSessions({String? sessionId}) =>
      tutor(tab: 'sessions', sessionId: sessionId);

  /// Resolve a student/parent bottom-nav index from route arguments.
  static int? resolveStudentTabIndex(Map<String, dynamic>? args) {
    if (args == null) return null;
    final tabKey = args['tab'] as String?;
    if (tabKey != null) {
      switch (tabKey) {
        case 'home':
          return StudentTabIndex.home;
        case 'findTutors':
          return StudentTabIndex.findTutors;
        case 'skulMate':
          return StudentTabIndex.skulMate >= 0
              ? StudentTabIndex.skulMate
              : StudentTabIndex.home;
        case 'requests':
          return StudentTabIndex.requests;
        case 'profile':
          return StudentTabIndex.profile;
      }
    }
    return args['initialTab'] as int?;
  }

  /// Resolve a tutor bottom-nav index from route arguments.
  static int? resolveTutorTabIndex(Map<String, dynamic>? args) {
    if (args == null) return null;
    final tabKey = args['tab'] as String?;
    if (tabKey != null) {
      switch (tabKey) {
        case 'home':
          return TutorTabIndex.home;
        case 'requests':
          return TutorTabIndex.requests;
        case 'sessions':
          return TutorTabIndex.sessions;
        case 'profile':
          return TutorTabIndex.profile;
      }
    }
    return args['initialTab'] as int?;
  }
}
