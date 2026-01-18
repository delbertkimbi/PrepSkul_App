import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';
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
  
  /// Get API base URL with safety checks
  /// 
  /// This ensures we NEVER use app.prepskul.com/api (which doesn't have API routes)
  /// Always uses www.prepskul.com/api (where Next.js API is hosted)
  /// Works on iOS, Android, and Web regardless of .env loading
  static String get _apiBaseUrl {
    final configured = AppConfig.effectiveApiBaseUrl;
    
    // Safety check: if somehow app.prepskul.com is returned, force www
    if (configured.contains('app.prepskul.com')) {
      LogService.warning('⚠️ Invalid API URL detected: $configured');
      LogService.warning('✅ Correcting to: https://www.prepskul.com/api');
      return 'https://www.prepskul.com/api';
    }
    
    // Additional validation: ensure it's www.prepskul.com/api or localhost
    if (!configured.contains('www.prepskul.com/api') && 
        !configured.contains('localhost') &&
        !configured.contains('127.0.0.1')) {
      LogService.warning('⚠️ Unexpected API URL: $configured');
      LogService.warning('✅ Using fallback: https://www.prepskul.com/api');
      return 'https://www.prepskul.com/api';
    }
    
    return configured;
  }
  
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
      final apiUrl = '$_apiBaseUrl/messages/send';
      
      // Debug logging to verify correct URL (works on all platforms)
      if (kDebugMode) {
        LogService.info('📡 Messaging API URL: $apiUrl');
        LogService.info('📡 Expected: https://www.prepskul.com/api/messages/send');
        if (apiUrl.contains('app.prepskul.com')) {
          LogService.error('❌ CRITICAL: Wrong domain detected!');
        }
      }
      
      // Increase timeout for localhost (local development can be slower)
      final timeoutDuration = apiUrl.contains('localhost') || apiUrl.contains('127.0.0.1')
          ? const Duration(seconds: 30)
          : const Duration(seconds: 10);
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAccessToken()}',
        },
        body: jsonEncode({
          'conversationId': conversationId,
          'content': content.trim(),
        }),
      ).timeout(
        timeoutDuration,
        onTimeout: () {
          throw TimeoutException('Message send request timed out after ${timeoutDuration.inSeconds}s. URL: $apiUrl');
        },
      );

      // Check response status and content BEFORE parsing JSON
      final responseBodyTrimmed = response.body.trim();
      
      // First check for HTML error pages
      if (responseBodyTrimmed.startsWith('<!DOCTYPE') || 
          responseBodyTrimmed.startsWith('<html') ||
          (responseBodyTrimmed.startsWith('<') && response.statusCode >= 400)) {
        LogService.error('API returned HTML error page: Status ${response.statusCode}, URL: $_apiBaseUrl/messages/send');
        LogService.error('Response preview: ${responseBodyTrimmed.length > 200 ? responseBodyTrimmed.substring(0, 200) : responseBodyTrimmed}');
        throw Exception('API endpoint returned an error page (HTML). Status: ${response.statusCode}. Please check if the endpoint exists at $_apiBaseUrl/messages/send and the server is running.');
      }

      // Check status code - handle errors appropriately
      if (response.statusCode >= 400) {
        // Try to parse as JSON error response first
        if (responseBodyTrimmed.startsWith('{') || responseBodyTrimmed.startsWith('[')) {
          try {
            final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
            final errorMsg = errorData?['error'] as String? ?? 'Unknown error';
            LogService.error('API returned JSON error: Status ${response.statusCode}, Error: $errorMsg');
            throw Exception('API error: $errorMsg');
          } catch (e) {
            if (e is FormatException) {
              // Fall through to HTML error handling
              LogService.error('Failed to parse error JSON: $e');
            } else {
              rethrow;
            }
          }
        }
        // If not JSON, it's likely HTML or plain text error
        LogService.error('API returned non-JSON error response: Status ${response.statusCode}');
        throw Exception('API endpoint returned an error. Status: ${response.statusCode}. Response: ${responseBodyTrimmed.length > 100 ? responseBodyTrimmed.substring(0, 100) : responseBodyTrimmed}');
      }

      // Validate response is JSON before parsing (for success cases)
      if (response.statusCode == 200) {
        if (!responseBodyTrimmed.startsWith('{') && !responseBodyTrimmed.startsWith('[')) {
          LogService.error('API returned non-JSON response for status 200: ${responseBodyTrimmed.substring(0, 100)}');
          throw Exception('API endpoint returned invalid response format.');
        }
      }

      // Parse JSON response
      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        LogService.error('Failed to parse JSON response: $e');
        LogService.error('Response body: ${responseBodyTrimmed.length > 200 ? responseBodyTrimmed.substring(0, 200) : responseBodyTrimmed}');
        throw Exception('API returned invalid JSON response. Please check the server logs.');
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
      // Increase timeout for localhost (local development can be slower)
      final apiUrl = '$_apiBaseUrl/messages/preview';
      final timeoutDuration = apiUrl.contains('localhost') || apiUrl.contains('127.0.0.1')
          ? const Duration(seconds: 30)
          : const Duration(seconds: 5);
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'content': content,
        }),
      ).timeout(
        timeoutDuration,
        onTimeout: () {
          throw TimeoutException('Message preview request timed out after ${timeoutDuration.inSeconds}s. URL: $apiUrl');
        },
      );

      // Check response status and content BEFORE parsing JSON
      final responseBodyTrimmed = response.body.trim();
      
      // First check for HTML error pages
      if (responseBodyTrimmed.startsWith('<!DOCTYPE') || 
          responseBodyTrimmed.startsWith('<html') ||
          (responseBodyTrimmed.startsWith('<') && response.statusCode >= 400)) {
        LogService.error('Preview API returned HTML error page: Status ${response.statusCode}, URL: $_apiBaseUrl/messages/preview');
        LogService.error('Response preview: ${responseBodyTrimmed.length > 200 ? responseBodyTrimmed.substring(0, 200) : responseBodyTrimmed}');
        // Return safe default instead of throwing for preview
        return {
          'hasWarnings': false,
          'willBlock': false,
          'warnings': [],
          'flags': [],
        };
      }

      // Check status code - handle errors appropriately
      if (response.statusCode >= 400) {
        // Try to parse as JSON error response first
        if (responseBodyTrimmed.startsWith('{') || responseBodyTrimmed.startsWith('[')) {
          try {
            final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
            final errorMsg = errorData?['error'] as String? ?? 'Unknown error';
            LogService.error('Preview API returned JSON error: Status ${response.statusCode}, Error: $errorMsg');
            // Return safe default for preview
            return {
              'hasWarnings': false,
              'willBlock': false,
              'warnings': [],
              'flags': [],
            };
          } catch (e) {
            if (e is FormatException) {
              // Fall through to safe default
              LogService.error('Failed to parse preview error JSON: $e');
            }
          }
        }
        // If not JSON, return safe default
        LogService.error('Preview API returned non-JSON error response: Status ${response.statusCode}');
        return {
          'hasWarnings': false,
          'willBlock': false,
          'warnings': [],
          'flags': [],
        };
      }

      // Validate response is JSON before parsing (for success cases)
      if (response.statusCode == 200) {
        if (!responseBodyTrimmed.startsWith('{') && !responseBodyTrimmed.startsWith('[')) {
          LogService.error('Preview API returned non-JSON response for status 200: ${responseBodyTrimmed.substring(0, 100)}');
          return {
            'hasWarnings': false,
            'willBlock': false,
            'warnings': [],
            'flags': [],
          };
        }
      }

      // Parse JSON response
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        LogService.error('Failed to parse preview JSON response: $e');
        LogService.error('Response body: ${responseBodyTrimmed.length > 200 ? responseBodyTrimmed.substring(0, 200) : responseBodyTrimmed}');
        // Return safe default for preview
        return {
          'hasWarnings': false,
          'willBlock': false,
          'warnings': [],
          'flags': [],
        };
      }
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
  static Future<List<Conversation>> getConversations({bool includeArchived = false}) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get archived conversation IDs for current user
      List<String> archivedConversationIds = [];
      if (!includeArchived) {
        final archivedResponse = await _supabase
            .from('user_archived_conversations')
            .select('conversation_id')
            .eq('user_id', userId);
        
        archivedConversationIds = (archivedResponse as List)
            .map((item) => item['conversation_id'] as String)
            .toList();
      }

      // Get conversations for current user
      var query = _supabase
          .from('conversations')
          .select('*')
          .or('student_id.eq.$userId,tutor_id.eq.$userId')
          .eq('status', 'active');
      
      // Exclude archived conversations if not including them
      if (!includeArchived && archivedConversationIds.isNotEmpty) {
        // Filter out archived conversations
        final allConversations = await query.order('last_message_at', ascending: false);
        final response = (allConversations as List).where((conv) {
          return !archivedConversationIds.contains(conv['id'] as String);
        }).toList();
        
        if (response.isEmpty) {
          return [];
        }
        
        // Continue with filtered conversations
        final conversations = <Conversation>[];
        
        for (final convData in response) {
          final convId = convData['id'] as String;
          
          // Get other user's info
          final otherUserId = convData['student_id'] == userId 
              ? convData['tutor_id'] 
              : convData['student_id'];
          
          final otherUserProfile = await _getUserProfile(otherUserId);
          
          // Log avatar URL for debugging
          final avatarUrl = otherUserProfile['avatar_url'] as String?;
          if (avatarUrl != null && avatarUrl.isNotEmpty) {
            LogService.debug('📸 Avatar URL for user $otherUserId: $avatarUrl');
          } else {
            LogService.warning('⚠️ No avatar URL found for user $otherUserId');
          }
          
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
      }
      
      // If no archived conversations to filter, proceed normally
      final response = await query.order('last_message_at', ascending: false);

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
        
        // Log avatar URL for debugging
        final avatarUrl = otherUserProfile['avatar_url'] as String?;
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          LogService.debug('📸 Avatar URL for user $otherUserId: $avatarUrl');
        } else {
          LogService.warning('⚠️ No avatar URL found for user $otherUserId');
        }
        
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

  /// Archive a conversation for the current user
  static Future<void> archiveConversation(String conversationId) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if conversation exists and user is a participant
      final convResponse = await _supabase
          .from('conversations')
          .select('id, student_id, tutor_id')
          .eq('id', conversationId)
          .maybeSingle();

      if (convResponse == null) {
        throw Exception('Conversation not found');
      }

      final studentId = convResponse['student_id'] as String;
      final tutorId = convResponse['tutor_id'] as String;

      if (userId != studentId && userId != tutorId) {
        throw Exception('User is not a participant in this conversation');
      }

      // Archive the conversation
      await _supabase
          .from('user_archived_conversations')
          .upsert({
            'user_id': userId,
            'conversation_id': conversationId,
            'archived_at': DateTime.now().toIso8601String(),
          });

      LogService.success('✅ Conversation archived successfully');
    } catch (e) {
      LogService.error('Error archiving conversation: $e');
      rethrow;
    }
  }

  /// Unarchive a conversation for the current user
  static Future<void> unarchiveConversation(String conversationId) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Remove from archived conversations
      await _supabase
          .from('user_archived_conversations')
          .delete()
          .eq('user_id', userId)
          .eq('conversation_id', conversationId);

      LogService.success('✅ Conversation unarchived successfully');
    } catch (e) {
      LogService.error('Error unarchiving conversation: $e');
      rethrow;
    }
  }

  /// Check if a conversation is archived for the current user
  static Future<bool> isConversationArchived(String conversationId) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        return false;
      }

      final response = await _supabase
          .from('user_archived_conversations')
          .select('id')
          .eq('user_id', userId)
          .eq('conversation_id', conversationId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      LogService.error('Error checking archive status: $e');
      return false;
    }
  }

  /// Get archived conversations for current user
  static Future<List<Conversation>> getArchivedConversations() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get archived conversation IDs for current user
      final archivedResponse = await _supabase
          .from('user_archived_conversations')
          .select('conversation_id')
          .eq('user_id', userId);
      
      final archivedConversationIds = (archivedResponse as List)
          .map((item) => item['conversation_id'] as String)
          .toList();

      if (archivedConversationIds.isEmpty) {
        return [];
      }

      // Get conversations that are archived
      final response = await _supabase
          .from('conversations')
          .select('*')
          .or('student_id.eq.$userId,tutor_id.eq.$userId')
          .eq('status', 'active')
          .inFilter('id', archivedConversationIds)
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
        
        // Log avatar URL for debugging
        final avatarUrl = otherUserProfile['avatar_url'] as String?;
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          LogService.debug('📸 Avatar URL for user $otherUserId: $avatarUrl');
        } else {
          LogService.warning('⚠️ No avatar URL found for user $otherUserId');
        }
        
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
      LogService.error('Error getting archived conversations: $e');
      rethrow;
    }
  }

  /// Get user profile
  static Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    try {
      // First, get the profile with user_type to determine if we need to check tutor_profiles
      final profileResponse = await _supabase
          .from('profiles')
          .select('full_name, avatar_url, user_type')
          .eq('id', userId)
          .maybeSingle();
      
      if (profileResponse == null) {
        LogService.warning('⚠️ Profile not found for user: $userId');
        return {};
      }
      
      // For tutors, also check tutor_profiles.profile_photo_url (which is the primary source)
      String? avatarUrl = profileResponse['avatar_url'] as String?;
      final userType = profileResponse['user_type'] as String?;
      
      if (userType == 'tutor') {
        try {
          final tutorProfileResponse = await _supabase
              .from('tutor_profiles')
              .select('profile_photo_url')
              .eq('user_id', userId)
              .maybeSingle();
          
          // Use profile_photo_url from tutor_profiles if available, otherwise fallback to avatar_url from profiles
          final profilePhotoUrl = tutorProfileResponse?['profile_photo_url'] as String?;
          if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
            avatarUrl = profilePhotoUrl;
            LogService.debug('📸 Using tutor profile_photo_url for user $userId: $avatarUrl');
          } else if (avatarUrl == null || avatarUrl.isEmpty) {
            LogService.debug('📸 No profile_photo_url found in tutor_profiles, using avatar_url from profiles');
          }
        } catch (e) {
          LogService.warning('⚠️ Error fetching tutor profile for user $userId: $e');
          // Continue with avatar_url from profiles
        }
      }
      String? validAvatarUrl;
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        // Ensure URL is valid (starts with http:// or https://)
        if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
          validAvatarUrl = avatarUrl;
        } else {
          // If it's a relative path, try to construct full Supabase Storage URL
          // This handles cases where avatar_url might be stored as a path
          LogService.warning('⚠️ Avatar URL is not a full URL for user $userId: $avatarUrl');
          // For now, return null - the UI will show initials as fallback
          validAvatarUrl = null;
        }
      }
      
      return {
        'full_name': profileResponse['full_name'],
        'avatar_url': validAvatarUrl,
      };
    } catch (e) {
      LogService.error('Error getting user profile: $e');
      return {};
    }
  }
}

