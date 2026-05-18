import 'dart:async' show StreamController, unawaited;
import 'dart:math';

import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_profile_service.dart';

/// Ephemeral Meet-style lesson messages (Realtime broadcast — not persisted).
class IncallChatMessage {
  IncallChatMessage({
    required this.fromUserId,
    required this.displayName,
    required this.text,
    required this.sentAtMs,
    required this.messageId,
  });

  final String fromUserId;
  final String displayName;
  final String text;
  final int sentAtMs;
  final String messageId;
}

class IncallChatRealtime {
  IncallChatRealtime({
    required this.sessionId,
    required SessionParticipantBundle bundle,
  }) : _bundle = bundle;

  final String sessionId;
  final SessionParticipantBundle _bundle;

  final StreamController<IncallChatMessage> _controller =
      StreamController<IncallChatMessage>.broadcast();

  Stream<IncallChatMessage> get messages => _controller.stream;

  RealtimeChannel? _channel;
  DateTime? _lastSendAt;
  static const int maxMessageLength = 500;
  static const Duration minSendGap = Duration(milliseconds: 280);

  Set<String> get _allowedUserIds {
    final s = <String>{};
    final t = _bundle.tutorUserId;
    final l = _bundle.learnerUserId;
    if (t != null && t.isNotEmpty) s.add(t);
    if (l != null && l.isNotEmpty) s.add(l);
    return s;
  }

  void subscribe() {
    try {
      final prev = _channel;
      _channel = null;
      if (prev != null) {
        unawaited(prev.unsubscribe());
      }
      final ch =
          SupabaseService.client.channel('session_incall_chat_$sessionId');
      _channel = ch;
      ch.onBroadcast(
        event: 'incall_message',
        callback: (Map<String, dynamic> payload, [Object? ref]) {
          try {
            final from = payload['from_user_id'];
            final text = payload['text'] as String?;
            final displayName = payload['display_name'] as String? ?? '';
            final sentRaw = payload['sent_at_ms'];
            final mid = payload['message_id'] as String? ?? '';

            final fromStr = from is String ? from : null;
            if (fromStr == null ||
                text == null ||
                text.trim().isEmpty ||
                mid.isEmpty) {
              return;
            }
            final allowed = _allowedUserIds;
            if (!allowed.contains(fromStr)) {
              LogService.warning(
                '[INCALL_CHAT] Dropped msg from unauthorized user.',
              );
              return;
            }

            final sentMs = sentRaw is int
                ? sentRaw
                : int.tryParse('$sentRaw') ?? DateTime.now().millisecondsSinceEpoch;

            _controller.add(
              IncallChatMessage(
                fromUserId: fromStr,
                displayName: displayName,
                text: text,
                sentAtMs: sentMs,
                messageId: mid,
              ),
            );
          } catch (_) {}
        },
      );

      ch.subscribe();
      LogService.success(
        '✅ In-call chat Realtime subscribed: session_incall_chat_$sessionId',
      );
    } catch (e) {
      LogService.warning('[INCALL_CHAT] subscribe failed: $e');
      _channel = null;
    }
  }

  Future<void> unsubscribe() async {
    try {
      await _channel?.unsubscribe();
    } catch (_) {}
    _channel = null;
  }

  /// Returns broadcast [messageId] on success, or `null` on validation / channel / rate-limit failure.
  Future<String?> send({
    required String fromUserId,
    required String displayName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > maxMessageLength) return null;

    final nowMonotonic = DateTime.now();
    if (_lastSendAt != null &&
        nowMonotonic.difference(_lastSendAt!) < minSendGap) {
      return null;
    }

    final ch = _channel;
    if (ch == null) {
      LogService.warning('[INCALL_CHAT] send skipped — no channel');
      return null;
    }

    final messageId =
        'm_${DateTime.now().millisecondsSinceEpoch}_${Random.secure().nextInt(99999)}';

    try {
      await ch.sendBroadcastMessage(
        event: 'incall_message',
        payload: {
          'from_user_id': fromUserId,
          'display_name': displayName.trim().isEmpty ? 'Participant' : displayName.trim(),
          'text': trimmed,
          'sent_at_ms': DateTime.now().millisecondsSinceEpoch,
          'message_id': messageId,
        },
      );
      _lastSendAt = nowMonotonic;
      return messageId;
    } catch (e) {
      LogService.warning('[INCALL_CHAT] sendBroadcast failed: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    await unsubscribe();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
