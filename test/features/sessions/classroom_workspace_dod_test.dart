import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Automated DoD for tutor–learner workspace (realtime + dual-pane + reducer).
/// Keeps transport, flags, and resolver wiring from drifting without review.
void main() {
  group('Classroom workspace DoD (file guards)', () {
    test('app config gates workspace realtime env', () async {
      final file = File('lib/core/config/app_config.dart');
      final c = await file.readAsString();
      expect(c.contains('enableClassroomWorkspaceRealtime'), isTrue);
      expect(c.contains('CLASSROOM_WORKSPACE_REALTIME_ENABLED'), isTrue);
    });

    test('realtime sync uses stable channel + broadcast + auth helper', () async {
      final file = File(
        'lib/features/sessions/services/workspace_realtime_sync.dart',
      );
      final c = await file.readAsString();
      expect(c.contains(r"channel('session_workspace_$sessionId')"), isTrue);
      expect(c.contains("event: 'workspace_packet'"), isTrue);
      expect(c.contains('isAuthorizedWorkspaceBroadcast'), isTrue);
      expect(c.contains('applyRemoteJson'), isTrue);
      // subscribe() must remain non-awaited on this SDK surface (analyzer-safe).
      expect(c.contains('_channel!.subscribe();'), isTrue);
    });

    test('session resolves tutor id before workspace subscribe', () async {
      final profile = File(
        'lib/features/sessions/services/session_profile_service.dart',
      );
      final screen = File(
        'lib/features/sessions/screens/agora_video_session_screen.dart',
      );
      expect(
        (await profile.readAsString()).contains('getTutorUserIdForSession'),
        isTrue,
      );
      final s = await screen.readAsString();
      expect(s.contains('getTutorUserIdForSession'), isTrue);
      expect(s.contains('_setupWorkspaceRealtime'), isTrue);
      expect(s.contains('AppConfig.enableClassroomWorkspaceRealtime'), isTrue);
      expect(s.contains('publishPacket'), isTrue);
    });

    test('reducer is single entry for remote + local workspace packets', () async {
      final file = File(
        'lib/features/sessions/domain/workspace_sync_state.dart',
      );
      final c = await file.readAsString();
      expect(c.contains('WorkspacePacket'), isTrue);
      expect(c.contains('reduceWorkspace'), isTrue);
      expect(c.contains('class WorkspaceSyncController'), isTrue);
    });
  });
}
