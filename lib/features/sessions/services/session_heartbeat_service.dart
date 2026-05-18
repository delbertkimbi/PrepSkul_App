import 'dart:async';

import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

/// Lightweight heartbeat sender so the peer can reliably detect when a user
/// has actually left the call (refresh, app kill, crash) instead of waiting
/// forever in a \"reconnecting\" state.
class SessionHeartbeatService {
  static final SessionHeartbeatService _instance =
      SessionHeartbeatService._internal();

  factory SessionHeartbeatService() => _instance;

  SessionHeartbeatService._internal();

  RealtimeChannel? _channel;
  Timer? _timer;
  String? _sessionId;
  String? _userId;

  /// Emits the user_id of the peer when a definitive \"left\" signal is
  /// received from Supabase.
  final StreamController<String> _peerLeftController =
      StreamController<String>.broadcast();
  final StreamController<String> _peerBeatController =
      StreamController<String>.broadcast();
  DateTime? _lastPeerBeatAt;

  Stream<String> get peerLeftStream => _peerLeftController.stream;
  Stream<String> get peerBeatStream => _peerBeatController.stream;
  DateTime? get lastPeerBeatAt => _lastPeerBeatAt;

  bool get isRunning => _timer != null;

  Future<void> start({required String sessionId, required String userId}) async {
    _sessionId = sessionId;
    _userId = userId;
    await _channel?.unsubscribe();

    final client = SupabaseService.client;
    _channel = client.channel('session_heartbeat_$sessionId');

    _channel!
      ..onBroadcast(
        event: 'left',
        callback: (payload, [ref]) {
          final fromUserId = payload['user_id'] as String?;
          final ts = payload['ts'] as String?;
          LogService.info(
            '[HEARTBEAT] Received left signal for session=$sessionId from=$fromUserId at=$ts',
          );
          if (fromUserId != null && fromUserId != _userId) {
            _peerLeftController.add(fromUserId);
          }
        },
      )
      ..onBroadcast(
        event: 'beat',
        callback: (payload, [ref]) {
          final fromUserId = payload['user_id'] as String?;
          if (fromUserId != null && fromUserId != _userId) {
            _lastPeerBeatAt = DateTime.now();
            _peerBeatController.add(fromUserId);
          }
          LogService.debug(
            '[HEARTBEAT] Beat from user=$fromUserId session=$sessionId',
          );
        },
      );

    _channel!.subscribe();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        await _channel!.sendBroadcastMessage(
          event: 'beat',
          payload: {
            'user_id': _userId,
            'ts': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        LogService.warning('[HEARTBEAT] Failed to send heartbeat: $e');
      }
    });

    LogService.info(
      '[HEARTBEAT] Started heartbeat for session=$sessionId user=$_userId',
    );
  }

  Future<void> sendLeftSignal() async {
    final channel = _channel;
    if (channel == null || _sessionId == null || _userId == null) return;
    try {
      await channel.sendBroadcastMessage(
        event: 'left',
        payload: {
          'user_id': _userId,
          'ts': DateTime.now().toIso8601String(),
        },
      );
      LogService.info(
        '[HEARTBEAT] Sent left signal for session=$_sessionId user=$_userId',
      );
    } catch (e) {
      LogService.warning('[HEARTBEAT] Failed to send left signal: $e');
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    if (_channel != null) {
      try {
        await _channel!.unsubscribe();
      } catch (e) {
        LogService.warning('[HEARTBEAT] Failed to unsubscribe channel: $e');
      }
    }
    _channel = null;
    _lastPeerBeatAt = null;
    LogService.info('[HEARTBEAT] Stopped heartbeat for session=$_sessionId');
  }
}

