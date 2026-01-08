import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'dart:convert';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

/// Chat Service
/// 
/// Handles all messaging operations:
/// - Send messages (with validation via API)
/// - Get conversations list
/// - Get messages for a conversation
/// - Mark messages as read
/// - Real-time subscriptions for messages and conversations
class ChatService {
  static final SupabaseClient _supabase = SupabaseService.client;
  static final String _apiBaseUrl = AppConfig.apiBaseUrl;
  
  // Cache for active subscriptions
  static final Map<String, RealtimeChannel> _activeChannels = {};
  static final Map<String, StreamController<List<Message>>> _messageStreams = {};
  static final Map<String, StreamController<List<Conversation>>> _conversationStreams = {};

  /// Send a message
  /// 
  /// Validates message through API, then stores in database
  static Future<Message> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Send to API for validation and filtering
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/messages/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAccessToken()}',
        },
        body: jsonEncode({
          'conversationId': conversationId,
          'content': content.trim(),
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Message send request timed out');
        },
      );

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        final error = responseData['error'] as String? ?? 'Failed to send message';
        final reason = responseData['reason'] as String?;
        throw Exception(reason != null ? '$error: $reason' : error);
      }

      // Message was successfully sent and stored
      final messageData = responseData['message'] as Map<String, dynamic>;
      return Message.fromJson(messageData, currentUserId: userId);
      
    } catch (e) {
      LogService.error('Error sending message: $e');
      rethrow;
    }
  }

  /// Preview message filter results (without sending)
  static Future<Map<String, dynamic>> previewMessage(String content) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/messages/preview'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'content': content,
        }),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Message preview request timed out');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to preview message');
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      LogService.error('Error previewing message: $e');
      return {
        'hasWarnings': false,
        'willBlock': false,
        'warnings': [],
        'flags': [],
      };
    }
  }

  /// Get all conversations for current user
  static Future<List<Conversation>> getConversations() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get conversations for current user
      final response = await _supabase
          .from('conversations')
          .select('*')
          .or('student_id.eq.$userId,tutor_id.eq.$userId')
          .eq('status', 'active')
          .order('last_message_at', ascending: false);

      if (response.isEmpty) {
        return [];
      }

      final conversations = <Conversation>[];
      
      for (final convData in response) {
        final convId = convData['id'] as String;
        
        // Get other user's info
        final otherUserId = convData['student_id'] == userId 
            ? convData['tutor_id'] 
            : convData['student_id'];
        
        final otherUserProfile = await _getUserProfile(otherUserId);
        
        // Get last message preview
        String? lastMessagePreview;
        DateTime? lastMessageTime;
        final lastMessageResponse = await _supabase
            .from('messages')
            .select('content, created_at')
            .eq('conversation_id', convId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        
        if (lastMessageResponse != null) {
          lastMessagePreview = lastMessageResponse['content'] as String?;
          if (lastMessageResponse['created_at'] != null) {
            lastMessageTime = DateTime.parse(lastMessageResponse['created_at'] as String);
          }
        }
        
        // Get unread count
        final unreadResponse = await _supabase
            .from('messages')
            .select('id')
            .eq('conversation_id', convId)
            .eq('is_read', false)
            .neq('sender_id', userId);
        
        final unreadCount = (unreadResponse as List).length;

        conversations.add(Conversation(
          id: convData['id'] as String,
          studentId: convData['student_id'] as String,
          tutorId: convData['tutor_id'] as String,
          trialSessionId: convData['trial_session_id'] as String?,
          bookingRequestId: convData['booking_request_id'] as String?,
          recurringSessionId: convData['recurring_session_id'] as String?,
          individualSessionId: convData['individual_session_id'] as String?,
          status: convData['status'] as String? ?? 'active',
          expiresAt: convData['expires_at'] != null
              ? DateTime.parse(convData['expires_at'] as String)
              : null,
          lastMessageAt: convData['last_message_at'] != null
              ? DateTime.parse(convData['last_message_at'] as String)
              : null,
          createdAt: DateTime.parse(convData['created_at'] as String),
          otherUserName: otherUserProfile['full_name'] as String?,
          otherUserAvatarUrl: otherUserProfile['avatar_url'] as String?,
          unreadCount: unreadCount,
          lastMessagePreview: lastMessagePreview,
          lastMessageTime: lastMessageTime,
        ));
      }

      return conversations;
    } catch (e) {
      LogService.error('Error getting conversations: $e');
      rethrow;
    }
  }

  /// Get messages for a conversation
  static Future<List<Message>> getMessages({
    required String conversationId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get messages with sender profile info
      final response = await _supabase
          .from('messages')
          .select('''
            *,
            sender:profiles!messages_sender_id_fkey(
              full_name,
              avatar_url
            )
          ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response.isEmpty) {
        return [];
      }

      final messages = <Message>[];
      for (final msgData in response) {
        final senderData = msgData['sender'] as Map<String, dynamic>?;
        
        messages.add(Message.fromJson({
          ...msgData,
          'sender_name': senderData?['full_name'],
          'sender_avatar_url': senderData?['avatar_url'],
        }, currentUserId: userId));
      }

      // Reverse to get chronological order (oldest first)
      return messages.reversed.toList();
    } catch (e) {
      LogService.error('Error getting messages: $e');
      rethrow;
    }
  }

  /// Mark messages as read
  static Future<void> markAsRead({
    required String conversationId,
    List<String>? messageIds,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Mark all unread messages in conversation as read
      if (messageIds != null && messageIds.isNotEmpty) {
        await _supabase
            .from('messages')
            .update({
              'is_read': true,
              'read_at': DateTime.now().toIso8601String(),
            })
            .eq('conversation_id', conversationId)
            .inFilter('id', messageIds)
            .neq('sender_id', userId) // Don't mark own messages as read
            .eq('is_read', false);
      } else {
        // Mark all unread messages in conversation as read
        await _supabase
            .from('messages')
            .update({
              'is_read': true,
              'read_at': DateTime.now().toIso8601String(),
            })
            .eq('conversation_id', conversationId)
            .neq('sender_id', userId) // Don't mark own messages as read
            .eq('is_read', false);
      }
    } catch (e) {
      LogService.error('Error marking messages as read: $e');
      // Don't rethrow - this is not critical
    }
  }

  /// Watch messages in real-time for a conversation
  static Stream<List<Message>> watchMessages(String conversationId) {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    // Return existing stream if available
    if (_messageStreams.containsKey(conversationId)) {
      return _messageStreams[conversationId]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<List<Message>>.broadcast();
    _messageStreams[conversationId] = controller;

    // Initial load
    getMessages(conversationId: conversationId).then((messages) {
      if (!controller.isClosed) {
        controller.add(messages);
      }
    }).catchError((error) {
      if (!controller.isClosed) {
        LogService.error('Error loading initial messages: $error');
        controller.addError(error);
      }
    });

    // Subscribe to Realtime changes
    final channel = _supabase.channel('messages_$conversationId');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) {
        // Reload messages when changes occur
        getMessages(conversationId: conversationId).then((messages) {
          if (!controller.isClosed) {
            controller.add(messages);
          }
        }).catchError((error) {
          if (!controller.isClosed) {
            LogService.error('Error reloading messages: $error');
          }
        });
      },
    ).subscribe();

    _activeChannels['messages_$conversationId'] = channel;

    // Clean up when stream is cancelled
    controller.onCancel = () {
      channel.unsubscribe();
      _activeChannels.remove('messages_$conversationId');
      _messageStreams.remove(conversationId);
    };

    return controller.stream;
  }

  /// Watch conversations in real-time
  static Stream<List<Conversation>> watchConversations() {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    const streamKey = 'conversations_all';

    // Return existing stream if available
    if (_conversationStreams.containsKey(streamKey)) {
      return _conversationStreams[streamKey]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<List<Conversation>>.broadcast();
    _conversationStreams[streamKey] = controller;

    // Initial load
    getConversations().then((conversations) {
      if (!controller.isClosed) {
        controller.add(conversations);
      }
    }).catchError((error) {
      if (!controller.isClosed) {
        LogService.error('Error loading initial conversations: $error');
        controller.addError(error);
      }
    });

    // Subscribe to Realtime changes on conversations table
    final channel = _supabase.channel('conversations_$userId');
    
    // Subscribe to conversations where user is student
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'conversations',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'student_id',
        value: userId,
      ),
      callback: (payload) {
        // Reload conversations when changes occur
        getConversations().then((conversations) {
          if (!controller.isClosed) {
            controller.add(conversations);
          }
        }).catchError((error) {
          if (!controller.isClosed) {
            LogService.error('Error reloading conversations: $error');
          }
        });
      },
    );
    
    // Subscribe to conversations where user is tutor
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'conversations',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'tutor_id',
        value: userId,
      ),
      callback: (payload) {
        // Reload conversations when changes occur
        getConversations().then((conversations) {
          if (!controller.isClosed) {
            controller.add(conversations);
          }
        }).catchError((error) {
          if (!controller.isClosed) {
            LogService.error('Error reloading conversations: $error');
          }
        });
      },
    );
    
    channel.subscribe();

    _activeChannels['conversations_$userId'] = channel;

    // Clean up when stream is cancelled
    controller.onCancel = () {
      channel.unsubscribe();
      _activeChannels.remove('conversations_$userId');
      _conversationStreams.remove(streamKey);
    };

    return controller.stream;
  }

  /// Unsubscribe from a conversation's message stream
  static void unsubscribeFromMessages(String conversationId) {
    final channel = _activeChannels.remove('messages_$conversationId');
    channel?.unsubscribe();
    _messageStreams[conversationId]?.close();
    _messageStreams.remove(conversationId);
  }

  /// Unsubscribe from conversations stream
  static void unsubscribeFromConversations() {
    final userId = SupabaseService.currentUser?.id;
    if (userId != null) {
      final channel = _activeChannels.remove('conversations_$userId');
      channel?.unsubscribe();
    }
    _conversationStreams['conversations_all']?.close();
    _conversationStreams.remove('conversations_all');
  }

  /// Get access token for API requests
  static Future<String> _getAccessToken() async {
    try {
      final session = _supabase.auth.currentSession;
      return session?.accessToken ?? '';
    } catch (e) {
      LogService.error('Error getting access token: $e');
      return '';
    }
  }

  /// Get user profile
  static Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      
      return response ?? {};
    } catch (e) {
      LogService.error('Error getting user profile: $e');
      return {};
    }
  }
}

