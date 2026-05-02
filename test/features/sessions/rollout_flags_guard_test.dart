import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rollout flags guard', () {
    test('app config exposes classroom rollout flags', () async {
      final file = File('lib/core/config/app_config.dart');
      final content = await file.readAsString();

      expect(content.contains('enableClassroomOrchestrator'), isTrue);
      expect(content.contains('enableClassroomDualStream'), isTrue);
      expect(content.contains('enableClassroomQoeTelemetry'), isTrue);
      expect(content.contains('enableClassroomWorkspaceRealtime'), isTrue);
    });

    test('agora service applies dual-stream flag guard', () async {
      final file = File('lib/features/sessions/services/agora_service.dart');
      final content = await file.readAsString();

      // Initialization uses a multi-condition guard (flag + platform support).
      expect(content.contains('AppConfig.enableClassroomDualStream'), isTrue);
      expect(
        content.contains('enableDualStreamMode(enabled: true)'),
        isTrue,
      );
      expect(
        content.contains('if (!AppConfig.enableClassroomDualStream) return;'),
        isTrue,
      );
    });
  });
}

