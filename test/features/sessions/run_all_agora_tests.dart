/// Comprehensive Test Runner for Agora Video Session Flow
/// 
/// This script runs all Agora-related tests to ensure the entire flow works seamlessly.
/// 
/// Tests cover:
/// - Service layer (AgoraService, TokenService, RecordingService)
/// - UI layer (AgoraVideoSessionScreen, VideoView widget)
/// - Navigation integration (TutorSessionsScreen, MySessionsScreen)
/// - End-to-end flow (session start → video call → session end)

import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'agora_video_session_test.dart' as agora_service_test;
import 'agora_token_service_test.dart' as token_service_test;
import 'agora_recording_service_test.dart' as recording_service_test;
import 'agora_session_navigation_test.dart' as navigation_test;
import 'screen_sharing_test.dart' as screen_sharing_test;
import 'agora_screen_sharing_integration_test.dart' as screen_sharing_integration_test;

void main() {
  group('🧪 Complete Agora Video Session Flow Tests', () {
    group('📦 Service Layer Tests', () {
      agora_service_test.main();
    });

    group('🔑 Token Service Tests', () {
      token_service_test.main();
    });

    group('📹 Recording Service Tests', () {
      recording_service_test.main();
    });

    group('🧭 Navigation Tests', () {
      navigation_test.main();
    });

    group('🖥️ Screen Sharing Tests', () {
      screen_sharing_test.main();
    });

    group('🖥️ Screen Sharing Integration Tests', () {
      screen_sharing_integration_test.main();
    });
  });
}

