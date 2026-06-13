import '../config/app_config.dart';

/// Bottom-nav indices for student/parent shell (varies when SkulMate is enabled).
class StudentTabIndex {
  StudentTabIndex._();

  static const int home = 0;
  static const int findTutors = 1;

  static int get skulMate => AppConfig.enableSkulMate ? 2 : -1;

  static int get requests => AppConfig.enableSkulMate ? 3 : 2;

  static int get profile => AppConfig.enableSkulMate ? 4 : 3;
}
