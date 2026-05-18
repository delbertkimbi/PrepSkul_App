/// Legacy Agora-focused runner (kept for backwards compatibility).
///
/// For the full session / classroom / video suite (recommended for DoD), run:
///
///   flutter test test/suites/session_video_suite_test.dart
///
/// For AgoraService tests that hit the native RTC channel (emulator/device):
///
///   flutter test test/suites/session_video_native_test.dart
///
/// For all tests under `test/features/sessions/` (directory; excludes suite file):
///
///   flutter test test/features/sessions/

import 'package:flutter_test/flutter_test.dart';

import 'agora_video_session_test.dart' as agora_service_test;
import 'agora_token_service_test.dart' as token_service_test;
import 'agora_recording_service_test.dart' as recording_service_test;
import 'agora_session_navigation_test.dart' as navigation_test;
import 'screen_sharing_test.dart' as screen_sharing_test;
import 'agora_screen_sharing_integration_test.dart'
    as screen_sharing_integration_test;

void main() {
  group('Legacy Agora core tests', () {
    group('Service layer', () {
      agora_service_test.main();
    });

    group('Token service', () {
      token_service_test.main();
    });

    group('Recording service', () {
      recording_service_test.main();
    });

    group('Navigation', () {
      navigation_test.main();
    });

    group('Screen sharing', () {
      screen_sharing_test.main();
    });

    group('Screen sharing integration', () {
      screen_sharing_integration_test.main();
    });
  });
}


