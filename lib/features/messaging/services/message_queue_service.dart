import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'chat_service.dart';
import '../models/message_model.dart';

/// Message Queue Service
/// 
/// Queues failed messages for retry with exponential backoff
/// Supports offline message sending
/// 
/// Queue States:
/// - sending: Message is currently being sent
/// - pending: Message is queued for retry
/// - failed: Message failed after max retries

enum MessageQueueStatus {
  sending,
  pending,
  failed,
}

class QueuedMessage {
  final String id;
  final String conversationId;
  final String content;
  final DateTime createdAt;
  final int retryCount;
  final MessageQueueStatus status;
  final String? errorMessage;
  final DateTime? nextRetryAt;

  QueuedMessage({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.createdAt,
    this.retryCount = 0,
    this.status = MessageQueueStatus.pending,
    this.errorMessage,
    this.nextRetryAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'status': status.name,
      'errorMessage': errorMessage,
      'nextRetryAt': nextRetryAt?.toIso8601String(),
    };
  }

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      status: MessageQueueStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageQueueStatus.pending,
      ),
      errorMessage: json['errorMessage'] as String?,
      nextRetryAt: json['nextRetryAt'] != null
          ? DateTime.parse(json['nextRetryAt'] as String)
          : null,
    );
  }

  QueuedMessage copyWith({
    String? id,
    String? conversationId,
    String? content,
    DateTime? createdAt,
    int? retryCount,
    MessageQueueStatus? status,
    String? errorMessage,
    DateTime? nextRetryAt,
  }) {
    return QueuedMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    );
  }
}

class MessageQueueService {
  static const String _queueKey = 'message_queue';
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static Timer? _retryTimer;

  /// Add a message to the queue
  static Future<void> queueMessage({
    required String conversationId,
    required String content,
  }) async {
    try {
      final queue = await _getQueue();
      final queuedMessage = QueuedMessage(
        id: 'queue_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: conversationId,
        content: content,
        createdAt: DateTime.now(),
        status: MessageQueueStatus.pending,
      );

      queue.add(queuedMessage);
      await _saveQueue(queue);

      LogService.info('Queued message for conversation: $conversationId');
      
      // Start processing queue if not already running
      _processQueue();
    } catch (e) {
      LogService.error('Error queueing message: $e');
    }
  }

  /// Process the message queue
  static Future<void> _processQueue() async {
    // Cancel existing timer if any
    _retryTimer?.cancel();

    try {
      final queue = await _getQueue();
      final now = DateTime.now();

      // Filter messages ready for retry
      final readyMessages = queue.where((msg) {
        if (msg.status == MessageQueueStatus.failed) return false;
        if (msg.status == MessageQueueStatus.sending) return false;
        if (msg.nextRetryAt != null && msg.nextRetryAt!.isAfter(now)) {
          return false;
        }
        return true;
      }).toList();

      if (readyMessages.isEmpty) {
        // Schedule next check for messages with future retry times
        final futureMessages = queue.where((msg) => msg.nextRetryAt != null).toList();
        if (futureMessages.isNotEmpty) {
          futureMessages.sort((a, b) => 
            (a.nextRetryAt ?? DateTime.now()).compareTo(b.nextRetryAt ?? DateTime.now()));
          final nextRetry = futureMessages.first.nextRetryAt!;
          final delay = nextRetry.difference(now);
          if (delay > Duration.zero) {
            _retryTimer = Timer(delay, () => _processQueue());
          }
        }
        return;
      }

      // Process messages one at a time
      for (final queuedMessage in readyMessages) {
        await _sendQueuedMessage(queuedMessage);
      }

      // Schedule next check
      _scheduleNextRetry();
    } catch (e) {
      LogService.error('Error processing queue: $e');
    }
  }

  /// Send a queued message
  static Future<void> _sendQueuedMessage(QueuedMessage queuedMessage) async {
    try {
      // Mark as sending
      await _updateMessageStatus(queuedMessage.id, MessageQueueStatus.sending);

      // Attempt to send
      await ChatService.sendMessage(
        conversationId: queuedMessage.conversationId,
        content: queuedMessage.content,
      );

      // Success - remove from queue
      await _removeFromQueue(queuedMessage.id);
      LogService.success('Successfully sent queued message: ${queuedMessage.id}');
    } catch (e) {
      LogService.error('Error sending queued message: $e');
      
      // Update retry count and schedule retry
      final queue = await _getQueue();
      final messageIndex = queue.indexWhere((m) => m.id == queuedMessage.id);
      
      if (messageIndex != -1) {
        final updatedMessage = queue[messageIndex];
        final newRetryCount = updatedMessage.retryCount + 1;

        if (newRetryCount >= _maxRetries) {
          // Max retries reached - mark as failed
          await _updateMessageStatus(
            queuedMessage.id,
            MessageQueueStatus.failed,
            errorMessage: e.toString(),
          );
        } else {
          // Schedule retry with exponential backoff
          final retryDelay = _initialRetryDelay * (1 << newRetryCount); // 2s, 4s, 8s
          final nextRetryAt = DateTime.now().add(retryDelay);

          await _updateMessage(
            queuedMessage.id,
            updatedMessage.copyWith(
              retryCount: newRetryCount,
              status: MessageQueueStatus.pending,
              errorMessage: e.toString(),
              nextRetryAt: nextRetryAt,
            ),
          );
        }
      }
    }
  }

  /// Schedule next retry check
  static void _scheduleNextRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 5), () => _processQueue());
  }

  /// Get all queued messages
  static Future<List<QueuedMessage>> getQueuedMessages() async {
    return await _getQueue();
  }

  /// Get queued messages for a conversation
  static Future<List<QueuedMessage>> getQueuedMessagesForConversation(String conversationId) async {
    final queue = await _getQueue();
    return queue.where((m) => m.conversationId == conversationId).toList();
  }

  /// Retry a failed message manually
  static Future<void> retryMessage(String messageId) async {
    try {
      final queue = await _getQueue();
      final message = queue.firstWhere((m) => m.id == messageId);
      
      // Reset retry count and status
      await _updateMessage(
        messageId,
        message.copyWith(
          retryCount: 0,
          status: MessageQueueStatus.pending,
          errorMessage: null,
          nextRetryAt: null,
        ),
      );

      // Process queue immediately
      _processQueue();
    } catch (e) {
      LogService.error('Error retrying message: $e');
    }
  }

  /// Remove a message from queue
  static Future<void> _removeFromQueue(String messageId) async {
    try {
      final queue = await _getQueue();
      queue.removeWhere((m) => m.id == messageId);
      await _saveQueue(queue);
    } catch (e) {
      LogService.error('Error removing message from queue: $e');
    }
  }

  /// Update message status
  static Future<void> _updateMessageStatus(
    String messageId,
    MessageQueueStatus status, {
    String? errorMessage,
  }) async {
    try {
      final queue = await _getQueue();
      final messageIndex = queue.indexWhere((m) => m.id == messageId);
      
      if (messageIndex != -1) {
        queue[messageIndex] = queue[messageIndex].copyWith(
          status: status,
          errorMessage: errorMessage,
        );
        await _saveQueue(queue);
      }
    } catch (e) {
      LogService.error('Error updating message status: $e');
    }
  }

  /// Update message
  static Future<void> _updateMessage(String messageId, QueuedMessage updatedMessage) async {
    try {
      final queue = await _getQueue();
      final messageIndex = queue.indexWhere((m) => m.id == messageId);
      
      if (messageIndex != -1) {
        queue[messageIndex] = updatedMessage;
        await _saveQueue(queue);
      }
    } catch (e) {
      LogService.error('Error updating message: $e');
    }
  }

  /// Get queue from storage
  static Future<List<QueuedMessage>> _getQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_queueKey);
      
      if (json == null) return [];

      final List<dynamic> decoded = jsonDecode(json);
      return decoded.map((m) => QueuedMessage.fromJson(Map<String, dynamic>.from(m))).toList();
    } catch (e) {
      LogService.error('Error getting queue: $e');
      return [];
    }
  }

  /// Save queue to storage
  static Future<void> _saveQueue(List<QueuedMessage> queue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(queue.map((m) => m.toJson()).toList());
      await prefs.setString(_queueKey, json);
    } catch (e) {
      LogService.error('Error saving queue: $e');
    }
  }

  /// Clear all queued messages
  static Future<void> clearQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      _retryTimer?.cancel();
      LogService.success('Cleared message queue');
    } catch (e) {
      LogService.error('Error clearing queue: $e');
    }
  }
}
