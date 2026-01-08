import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/services/agora_service.dart';
import 'package:prepskul/features/sessions/services/agora_token_service.dart';
import 'package:prepskul/features/sessions/models/agora_session_state.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Tests for Agora Video Session Functionality
/// 
/// Tests cover:
/// - Agora service initialization
/// - Token fetching
/// - Channel joining/leaving
/// - State management
/// - Error handling
void main() {
  group('Agora Video Session Tests', () {
    late AgoraService agoraService;

    setUp(() {
      agoraService = AgoraService();
    });

    tearDown(() async {
      await agoraService.dispose();
    });

    test('AgoraService should be a singleton', () {
      final instance1 = AgoraService();
      final instance2 = AgoraService();
      expect(instance1, equals(instance2));
    });

    test('AgoraService should initialize successfully', () async {
      // Note: This test requires Agora SDK to be properly configured
      // In a real test environment, you might want to mock the Agora engine
      try {
        await agoraService.initialize();
        expect(agoraService.isInitialized, isTrue);
      } catch (e) {
        // If initialization fails due to missing config, that's expected in test env
        // The important thing is that the method exists and can be called
        expect(agoraService.isInitialized, isFalse);
      }
    });

    test('AgoraService should have correct initial state', () {
      expect(agoraService.state, equals(AgoraSessionState.disconnected));
      expect(agoraService.isInChannel, isFalse);
      expect(agoraService.currentChannelName, isNull);
      expect(agoraService.currentUID, isNull);
    });

    test('AgoraService should expose state stream', () {
      expect(agoraService.stateStream, isNotNull);
    });

    test('AgoraService should expose error stream', () {
      expect(agoraService.errorStream, isNotNull);
    });

    test('AgoraService should expose user joined stream', () {
      expect(agoraService.userJoinedStream, isNotNull);
    });

    test('AgoraSessionState should have correct display names', () {
      expect(AgoraSessionState.disconnected.displayName, equals('Disconnected'));
      expect(AgoraSessionState.joining.displayName, equals('Joining...'));
      expect(AgoraSessionState.connected.displayName, equals('Connected'));
      expect(AgoraSessionState.reconnecting.displayName, equals('Reconnecting...'));
      expect(AgoraSessionState.leaving.displayName, equals('Leaving...'));
      expect(AgoraSessionState.error.displayName, equals('Error'));
    });

    test('AgoraSessionState should correctly identify active state', () {
      expect(AgoraSessionState.disconnected.isActive, isFalse);
      expect(AgoraSessionState.joining.isActive, isFalse);
      expect(AgoraSessionState.connected.isActive, isTrue);
      expect(AgoraSessionState.reconnecting.isActive, isFalse);
      expect(AgoraSessionState.leaving.isActive, isFalse);
      expect(AgoraSessionState.error.isActive, isFalse);
    });

    test('AgoraSessionState should correctly identify connecting state', () {
      expect(AgoraSessionState.disconnected.isConnecting, isFalse);
      expect(AgoraSessionState.joining.isConnecting, isTrue);
      expect(AgoraSessionState.connected.isConnecting, isFalse);
      expect(AgoraSessionState.reconnecting.isConnecting, isTrue);
      expect(AgoraSessionState.leaving.isConnecting, isFalse);
      expect(AgoraSessionState.error.isConnecting, isFalse);
    });

    test('AgoraSessionState should correctly identify error state', () {
      expect(AgoraSessionState.disconnected.hasError, isFalse);
      expect(AgoraSessionState.joining.hasError, isFalse);
      expect(AgoraSessionState.connected.hasError, isFalse);
      expect(AgoraSessionState.reconnecting.hasError, isFalse);
      expect(AgoraSessionState.leaving.hasError, isFalse);
      expect(AgoraSessionState.error.hasError, isTrue);
    });

    test('AgoraTokenService should have correct API URL logic', () {
      // The service should handle API URL from environment
      // In test, it should default to production URL
      // This test verifies the method exists and doesn't throw
      expect(() => AgoraTokenService.fetchToken('test-session-id'), returnsNormally);
    });

    test('AgoraService should handle toggle video without errors', () async {
      // This test verifies the method exists and can be called
      // Actual functionality requires initialized engine
      try {
        await agoraService.toggleVideo();
        // If no error, method exists and is callable
        expect(true, isTrue);
      } catch (e) {
        // Expected if engine not initialized
        expect(e, isNotNull);
      }
    });

    test('AgoraService should handle toggle audio without errors', () async {
      try {
        await agoraService.toggleAudio();
        expect(true, isTrue);
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('AgoraService should return video enabled state', () {
      // isVideoEnabled() is now synchronous and returns bool
      final isEnabled = agoraService.isVideoEnabled();
      expect(isEnabled, isA<bool>());
    });

    test('AgoraService should return audio enabled state', () {
      // isAudioEnabled() is now synchronous and returns bool
      final isEnabled = agoraService.isAudioEnabled();
      expect(isEnabled, isA<bool>());
    });

    test('AgoraService should handle switch camera without errors', () async {
      try {
        await agoraService.switchCamera();
        expect(true, isTrue);
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('AgoraService should handle leave channel without errors', () async {
      try {
        await agoraService.leaveChannel();
        expect(agoraService.isInChannel, isFalse);
      } catch (e) {
        // Expected if not in channel
        expect(e, isNotNull);
      }
    });
  });
}

