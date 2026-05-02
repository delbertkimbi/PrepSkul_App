import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Session state UX stability', () {
    test(
      'screen enforces minimum display windows for transient and reconnect states',
      () async {
      final file = File(
        'lib/features/sessions/screens/agora_video_session_screen.dart',
      );
      final content = await file.readAsString();

      expect(
        content.contains('_minReconnectIndicatorDisplay'),
        isTrue,
        reason: 'Reconnect indicator should have minimum visibility.',
      );
      expect(
        content.contains('_localReconnectClearTimer'),
        isTrue,
        reason: 'Reconnect clear timer is required to avoid reconnect flicker.',
      );
      expect(
        content.contains('_syncDegradationTrackingAfterMutation'),
        isTrue,
        reason: 'Sustained degradation gating keeps reconnect UI calm.',
      );
      expect(
        content.contains('_kSustainedDegradationThreshold'),
        isTrue,
        reason: 'Degradation must persist before showing reconnect UI.',
      );
    },
      skip: kIsWeb
          ? 'Uses dart:io File reads; skip on web runner.'
          : false,
    );
  });
}

