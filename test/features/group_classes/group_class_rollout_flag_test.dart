import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group class rollout flag wiring', () {
    test('AppConfig exposes GROUP_CLASSES_ENABLED with launch default false', () async {
      final appConfig = File('lib/core/config/app_config.dart');
      final content = await appConfig.readAsString();
      expect(content.contains('enableGroupClasses'), isTrue);
      expect(content.contains('GROUP_CLASSES_ENABLED'), isTrue);
      expect(
        content.contains("_safeEnvBool('GROUP_CLASSES_ENABLED', false)"),
        isTrue,
        reason: 'v1 launch: group classes off unless env explicitly enables',
      );
    });

    test('UI entry points are guarded by enableGroupClasses', () async {
      final tutorHome = await File(
        'lib/features/tutor/screens/tutor_home_screen.dart',
      ).readAsString();
      final findTutors = await File(
        'lib/features/discovery/screens/find_tutors_screen.dart',
      ).readAsString();

      expect(tutorHome.contains('AppConfig.enableGroupClasses'), isTrue);
      expect(findTutors.contains('AppConfig.enableGroupClasses'), isTrue);
    });
  });
}

