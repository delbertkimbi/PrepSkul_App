import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// File-structure guards for Preply-parity classroom milestones (recovery, audio,
/// scroll sync, QoE hooks). Complements [classroom_workspace_dod_test] and
/// [phase_c_dod_validation_test].
void main() {
  group('Preply classroom DoD (file guards)', () {
    test('app config exposes audio profile mode + backup call URL env', () async {
      final file = File('lib/core/config/app_config.dart');
      final c = await file.readAsString();
      expect(c.contains('classroomAudioProfileMode'), isTrue);
      expect(c.contains('CLASSROOM_AUDIO_PROFILE_MODE'), isTrue);
      expect(c.contains('classroomBackupCallUrl'), isTrue);
      expect(c.contains('CLASSROOM_BACKUP_CALL_URL'), isTrue);
      expect(c.contains('enableClassroomAudioOnlyFallback'), isTrue);
      expect(c.contains('CLASSROOM_AUDIO_ONLY_FALLBACK_ENABLED'), isTrue);
    });

    test('agora service wires tutoring audio profile + QoE telemetry', () async {
      final file = File('lib/features/sessions/services/agora_service.dart');
      final c = await file.readAsString();
      expect(c.contains('_applyTutoringAudioProfile'), isTrue);
      expect(c.contains('AppConfig.classroomAudioProfileMode'), isTrue);
      expect(c.contains('audio_profile_selected'), isTrue);
      expect(c.contains('localCameraPublishingSignalStream'), isTrue);
      expect(c.contains('_markLocalCameraPublishingSignal'), isTrue);
    });

    test('live session screen wires recovery banner + QoE + heartbeat subscriptions',
        () async {
      final file = File(
        'lib/features/sessions/screens/agora_video_session_screen.dart',
      );
      final c = await file.readAsString();
      expect(c.contains('Recovery mode:'), isTrue);
      expect(c.contains('_emitRecoveryQoe'), isTrue);
      expect(c.contains('QoeTelemetryService.buildCorrelationId'), isTrue);
      expect(c.contains('classroom_recovery_mode_enter'), isTrue);
      expect(c.contains('classroom_recovery_mode_exit'), isTrue);
      expect(c.contains('session_screen_recovery'), isTrue);
      expect(c.contains('peerBeatStream'), isTrue);
      expect(c.contains('_scheduleAudioOnlyFallbackIfNeeded'), isTrue);
      expect(c.contains('audio_only_fallback_prompt_shown'), isTrue);
      expect(c.contains('session_screen_audio_fallback'), isTrue);
    });

    test('heartbeat service exposes peer beat stream for recovery lag detection',
        () async {
      final file = File(
        'lib/features/sessions/services/session_heartbeat_service.dart',
      );
      final c = await file.readAsString();
      expect(c.contains('peerBeatStream'), isTrue);
      expect(c.contains('lastPeerBeatAt'), isTrue);
      expect(c.contains("event: 'beat'"), isTrue);
    });

    test('workspace PDF/notes scroll publishes SCROLL_TO for tutors only', () async {
      final file = File(
        'lib/features/sessions/widgets/classroom_workspace_indexed_stack.dart',
      );
      final c = await file.readAsString();
      expect(c.contains('_followRemoteScroll'), isTrue);
      expect(c.contains('ScrollToPacket'), isTrue);
      expect(c.contains('_canPublishScroll'), isTrue);
    });

    test('talk-time analytics emits QoE summary on leave', () async {
      final file = File(
        'lib/features/sessions/services/agora_service.dart',
      );
      final c = await file.readAsString();
      expect(c.contains('talk_time_summary'), isTrue);
      expect(c.contains('SessionModeStatisticsService'), isTrue);
    });

    test('prejoin lobby exposes readiness checklist + device probe', () async {
      final file = File(
        'lib/features/sessions/screens/agora_prejoin_screen.dart',
      );
      final c = await file.readAsString();
      expect(c.contains('_buildReadinessChecklist'), isTrue);
      expect(c.contains('DeviceReadinessService'), isTrue);
    });

    test('chat vocabulary long-press path remains wired', () async {
      final screen = File('lib/features/messaging/screens/chat_screen.dart');
      final service = File('lib/features/messaging/services/chat_service.dart');
      final s = await screen.readAsString();
      final svc = await service.readAsString();
      expect(s.contains('addWordToVocabularyDeck'), isTrue);
      expect(svc.contains('addWordToVocabularyDeck'), isTrue);
    });
  });
}
