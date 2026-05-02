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
  });
}

