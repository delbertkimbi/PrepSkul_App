import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase C DoD validation', () {
    test('session screen includes anti-flicker windows and glass polish', () async {
      final screenFile = File(
        'lib/features/sessions/screens/agora_video_session_screen.dart',
      );
      final content = await screenFile.readAsString();

      // Reconnect chip + sustained-degradation threshold replace older transient-copy windows.
      expect(content.contains('_minReconnectIndicatorDisplay'), isTrue);
      expect(content.contains('_kSustainedDegradationThreshold'), isTrue);
      expect(content.contains('BackdropFilter('), isTrue);
      expect(content.contains('ui.ImageFilter.blur'), isTrue);
    });

    test('controls meet accessibility baseline (size + semantics)', () async {
      final screenFile = File(
        'lib/features/sessions/screens/agora_video_session_screen.dart',
      );
      final content = await screenFile.readAsString();

      expect(content.contains('Semantics('), isTrue);
      expect(content.contains('button: true'), isTrue);
      expect(content.contains('double buttonSize = 58'), isTrue);
    });

    test('classroom workspace tool stack mounts IndexedStack (Preply parity)', () async {
      final screenFile = File(
        'lib/features/sessions/screens/agora_video_session_screen.dart',
      );
      final stackFile = File(
        'lib/features/sessions/widgets/classroom_workspace_indexed_stack.dart',
      );
      final screen = await screenFile.readAsString();
      final stack = await stackFile.readAsString();

      expect(screen.contains('ClassroomWorkspaceIndexedStack'), isTrue);
      expect(stack.contains('IndexedStack'), isTrue);
      expect(stack.contains('sizing: StackFit.expand'), isTrue);
      expect(screen.contains('_kClassroomDualPaneMinWidth'), isTrue);
    });
  });
}

