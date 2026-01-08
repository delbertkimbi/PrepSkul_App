# Running Agora Video Session Tests

## Quick Test Commands

### Run All Agora Tests:
```bash
flutter test test/features/sessions/ test/integration/agora_session_flow_integration_test.dart
```

### Run Individual Test Files:
```bash
# Service tests
flutter test test/features/sessions/agora_video_session_test.dart
flutter test test/features/sessions/agora_token_service_test.dart
flutter test test/features/sessions/agora_recording_service_test.dart

# Navigation tests
flutter test test/features/sessions/agora_session_navigation_test.dart

# Integration tests
flutter test test/integration/agora_session_flow_integration_test.dart
```

### Run with Coverage:
```bash
flutter test --coverage test/features/sessions/
```

## Test Coverage

### ✅ Service Layer (agora_video_session_test.dart)
- AgoraService singleton pattern
- Engine initialization
- State management
- Control methods (toggle video/audio, switch camera)
- State transitions

### ✅ Token Service (agora_token_service_test.dart)
- Token fetching from backend
- Authentication requirements
- Error handling

### ✅ Recording Service (agora_recording_service_test.dart)
- Start/stop recording
- Authentication requirements
- Error handling

### ✅ Navigation (agora_session_navigation_test.dart)
- Screen creation with parameters
- Widget initialization
- Integration with TutorSessionsScreen and MySessionsScreen

### ✅ Integration (agora_session_flow_integration_test.dart)
- Complete flow from session screens
- Location-based routing (online vs onsite)
- Session state transitions
- Parameter validation

## Expected Results

All tests should pass, verifying:
1. ✅ AgoraService can be initialized
2. ✅ Tokens can be fetched (with proper auth)
3. ✅ Recording can be started/stopped (with proper auth)
4. ✅ AgoraVideoSessionScreen can be created
5. ✅ Navigation from session screens works
6. ✅ Online sessions route to Agora video
7. ✅ Onsite sessions do not route to Agora video

## Notes

- Some tests may require mocked Agora SDK in full integration
- Authentication tests verify error handling, not actual auth
- Navigation tests verify widget creation, not actual navigation (requires app context)
- Full end-to-end testing requires:
  - Agora credentials configured
  - Supabase authentication
  - Two devices for actual video connection testing

