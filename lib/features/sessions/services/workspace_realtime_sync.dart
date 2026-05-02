import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/sessions/domain/workspace_sync_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

/// Whether a workspace broadcast should mutate local state (learners trust tutor only).
bool isAuthorizedWorkspaceBroadcast({
  required String? fromUserId,
  required String currentUserId,
  required String tutorUserId,
}) {
  if (fromUserId == null || fromUserId.isEmpty) return false;
  if (fromUserId == currentUserId) return false;
  return fromUserId == tutorUserId;
}

Map<String, dynamic>? _coerceStringKeyedMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

/// Supabase Realtime broadcast bridge for [WorkspacePacket]s (session-scoped).
///
/// Channel: `session_workspace_<sessionId>`, event: `workspace_packet`.
/// Payload: `{ from_user_id, packet: { type, ... } }`.
class WorkspaceRealtimeSync {
  WorkspaceRealtimeSync({
    required this.sessionId,
    required this.currentUserId,
    required this.tutorUserId,
  }) : workspace = WorkspaceSyncController();

  final String sessionId;
  final WorkspaceSyncController workspace;
  final String currentUserId;
  final String tutorUserId;

  RealtimeChannel? _channel;

  bool get _isTutor => currentUserId == tutorUserId;

  Future<void> subscribe() async {
    await unsubscribe();
    try {
      _channel = SupabaseService.client.channel('session_workspace_$sessionId');
      _channel!.onBroadcast(
        event: 'workspace_packet',
        callback: (payload, [ref]) {
          final from = payload['from_user_id'] as String?;
          final packetMap = _coerceStringKeyedMap(payload['packet']);
          if (!isAuthorizedWorkspaceBroadcast(
            fromUserId: from,
            currentUserId: currentUserId,
            tutorUserId: tutorUserId,
          )) {
            return;
          }
          if (packetMap == null) return;
          final applied = workspace.applyRemoteJson(packetMap);
          if (applied == null) {
            LogService.debug('[WORKSPACE] Ignored malformed packet: $packetMap');
          }
        },
      );
      _channel!.subscribe();
      LogService.success(
        '[WORKSPACE] Realtime subscribed session_workspace_$sessionId',
      );
    } catch (e) {
      LogService.warning('[WORKSPACE] subscribe failed: $e');
      _channel = null;
    }
  }

  Future<void> unsubscribe() async {
    try {
      await _channel?.unsubscribe();
    } catch (e) {
      LogService.debug('[WORKSPACE] unsubscribe: $e');
    }
    _channel = null;
  }

  /// Tutor-only: optimistic local apply + broadcast to learners.
  Future<void> publishPacket(WorkspacePacket packet) async {
    if (!_isTutor) return;
    final ch = _channel;
    if (ch == null) return;
    workspace.applyPacket(packet);
    try {
      await ch.sendBroadcastMessage(
        event: 'workspace_packet',
        payload: {
          'from_user_id': currentUserId,
          'packet': packet.toJson(),
        },
      );
    } catch (e) {
      LogService.warning('[WORKSPACE] broadcast failed: $e');
    }
  }
}
