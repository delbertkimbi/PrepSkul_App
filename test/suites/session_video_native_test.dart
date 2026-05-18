// Optional runner: AgoraService tests that call the real RTC MethodChannel.
// Use on emulator/device or when native test bindings are available:
//
//   flutter test test/suites/session_video_native_test.dart
//
// The default hermetic suite is:
//   flutter test test/suites/session_video_suite_test.dart

import 'package:flutter_test/flutter_test.dart';

import '../features/sessions/agora_video_session_test.dart' as agora_video_session_test;

void main() {
  group('Session / video — native Agora bindings', () {
    agora_video_session_test.main();
  });
}
