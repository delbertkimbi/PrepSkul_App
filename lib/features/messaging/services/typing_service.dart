import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Typing Service
/// 
/// Handles typing indicators for conversations
/// Uses Supabase Realtime channels to broadcast typing events
/// 
/// Features:
/// - Send typing events when user types
/// - Listen for typing events from other users
/// - Debounce typing (send after 1 second of inactivity)
/// - Auto-clear after 3 seconds of no typing

class TypingService {
  static final SupabaseClient _supabase = SupabaseService.client;
  static RealtimeChannel? _typingChannel;
  static Timer? _typingDebounceTimer;
  static Timer? _typingClearTimer;
  static String? _currentConversationId;
  static String? _currentUserId;
  static final Map<String, StreamController<bool>> _typingStreams = {};
  static final Map<String, DateTime> _otherUserTyping = {}; // Track when other users are typing

  /// Initialize typing service for a conversation
  static void initialize(String conversationId) {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    _currentConversationId = conversationId;
    _currentUserId = userId;

    // Initialize channel if not already done
    if (_typingChannel == null) {
      _typingChannel = _supabase.channel('typing_$userId');
      _typingChannel!.subscribe();
    }

    // Listen for typing events in this conversation
    _listenToTypingEvents(conversationId);
  }

  /// Send typing event (debounced)
  static void sendTypingEvent(String conversationId) {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null || conversationId != _currentConversationId) return;

    // Cancel existing debounce timer
    _typingDebounceTimer?.cancel();

    // Send typing event after 1 second of inactivity (debounce)
    _typingDebounceTimer = Timer(const Duration(seconds: 1), () {
      _broadcastTypingEvent(conversationId, userId, true);
      
      // Auto-clear typing after 3 seconds
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(const Duration(seconds: 3), () {
        _broadcastTypingEvent(conversationId, userId, false);
      });
    });
  }

  /// Broadcast typing event via Realtime channel
  static void _broadcastTypingEvent(String conversationId, String userId, bool isTyping) {
    try {
      if (_typingChannel == null) return;

      _typingChannel!.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'conversation_id': conversationId,
          'user_id': userId,
          'is_typing': isTyping,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      LogService.error('Error broadcasting typing event: $e');
    }
  }

  /// Listen for typing events in a conversation
  static void _listenToTypingEvents(String conversationId) {
    if (_typingChannel == null) return;

    _typingChannel!.onBroadcast(
      event: 'typing',
      callback: (payload, [ref]) {
        final eventConversationId = payload['conversation_id'] as String?;
        final eventUserId = payload['user_id'] as String?;
        final isTyping = payload['is_typing'] as bool? ?? false;

        // Only process events for current conversation and not from current user
        if (eventConversationId == conversationId &&
            eventUserId != _currentUserId) {
          // Update typing state
          if (isTyping) {
            _otherUserTyping[eventUserId!] = DateTime.now();
          } else {
            _otherUserTyping.remove(eventUserId);
          }

          // Notify listeners
          final controller = _typingStreams[conversationId];
          if (controller != null && !controller.isClosed) {
            controller.add(isTyping);
          }
        }
      },
    );
  }

  /// Get typing stream for a conversation
  static Stream<bool> watchTyping(String conversationId) {
    // Return existing stream if available
    if (_typingStreams.containsKey(conversationId)) {
      return _typingStreams[conversationId]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<bool>.broadcast();
    _typingStreams[conversationId] = controller;

    // Clean up when stream is cancelled
    controller.onCancel = () {
      _typingStreams.remove(conversationId);
    };

    return controller.stream;
  }

  /// Stop typing (called when user stops typing or sends message)
  static void stopTyping(String conversationId) {
    _typingDebounceTimer?.cancel();
    _typingClearTimer?.cancel();
    
    final userId = SupabaseService.currentUser?.id;
    if (userId != null) {
      _broadcastTypingEvent(conversationId, userId, false);
    }
  }

  /// Check if other user is typing
  static bool isOtherUserTyping(String conversationId) {
    // Check if any typing event is recent (within last 3 seconds)
    final now = DateTime.now();
    for (final typingTime in _otherUserTyping.values) {
      if (now.difference(typingTime).inSeconds < 3) {
        return true;
      }
    }
    return false;
  }

  /// Cleanup typing service
  static void dispose() {
    _typingDebounceTimer?.cancel();
    _typingClearTimer?.cancel();
    _typingChannel?.unsubscribe();
    _typingChannel = null;
    
    for (final controller in _typingStreams.values) {
      controller.close();
    }
    _typingStreams.clear();
    _otherUserTyping.clear();
    
    _currentConversationId = null;
    _currentUserId = null;
  }
}
