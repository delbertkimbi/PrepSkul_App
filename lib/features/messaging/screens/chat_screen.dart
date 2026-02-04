import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import '../services/chat_service.dart';
import '../services/conversation_lifecycle_service.dart';
import '../services/chat_suggestion_service.dart';
import '../services/typing_service.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../widgets/action_suggestion_banner.dart';
import 'package:prepskul/features/booking/screens/book_trial_session_screen.dart';
import 'package:prepskul/core/services/tutor_service.dart';
import 'package:prepskul/core/services/error_handler_service.dart';

/// Message status enum for UI
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

/// Chat Screen
/// 
/// Displays messages in a conversation with real-time updates
/// Supports sending messages, read receipts, and error handling
class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false; // For pagination
  bool _hasMoreMessages = true; // Track if more messages available
  int _currentOffset = 0; // Current pagination offset
  static const int _messagesPerPage = 50; // Messages per page
  bool _isSending = false;
  StreamSubscription? _messageStream;
  String? _errorMessage;
  ChatSuggestion? _suggestion;
  bool _bannerDismissed = false;
  bool _showBookTrialButton = false;
  bool _hasText = false;
  bool _isArchived = false;
  Timer? _typingDebounceTimer; // For typing indicators
  Timer? _messageBatchTimer; // For message batching
  List<String> _pendingMessages = []; // Messages waiting to be sent
  Set<String> _loadedMessageIds = {}; // Track loaded message IDs for pagination
  Set<String> _optimisticMessageIds = {}; // Track optimistic message IDs for deduplication
  Map<String, Timer> _optimisticMessageTimers = {}; // Timers to remove optimistic messages after timeout
  StreamSubscription? _typingStream;
  bool _isOtherUserTyping = false;
  Message? _replyingToMessage; // Message being replied to

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMessages();
    _subscribeToMessages();
    _loadSuggestions();
    _checkArchiveStatus();
    _initializeTyping();
    // Listen to text changes to update button state and typing
    _messageController.addListener(_onTextChanged);
    // Listen to scroll for lazy loading
    _scrollController.addListener(_onScroll);
  }

  /// Initialize typing service
  void _initializeTyping() {
    TypingService.initialize(widget.conversation.id);
    
    // Listen for typing events
    _typingStream = TypingService.watchTyping(widget.conversation.id).listen((isTyping) {
      if (mounted) {
        setState(() {
          _isOtherUserTyping = isTyping;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App went to background - cleanup inactive channels
      ChatService.onAppPaused();
    }
  }

  /// Handle scroll events for lazy loading
  void _onScroll() {
    // Load more messages when user scrolls near the top
    if (_scrollController.position.pixels < 200 && 
        !_isLoadingMore && 
        _hasMoreMessages &&
        !_isLoading) {
      _loadMoreMessages();
    }
  }
  
  Future<void> _checkArchiveStatus() async {
    try {
      final isArchived = await ChatService.isConversationArchived(widget.conversation.id);
      if (mounted) {
        setState(() {
          _isArchived = isArchived;
        });
      }
    } catch (e) {
      LogService.error('Error checking archive status: $e');
    }
  }
  
  Future<void> _handleArchiveAction() async {
    try {
      if (_isArchived) {
        await ChatService.unarchiveConversation(widget.conversation.id);
        if (mounted) {
          setState(() {
            _isArchived = false;
          });
          ErrorHandlerService.showSuccess(context, 'Conversation unarchived');
        }
      } else {
        await ChatService.archiveConversation(widget.conversation.id);
        if (mounted) {
          setState(() {
            _isArchived = true;
          });
          ErrorHandlerService.showSuccess(context, 'Conversation archived');
        }
      }
    } catch (e) {
      LogService.error('Error archiving/unarchiving conversation: $e');
      if (mounted) {
        ErrorHandlerService.showErrorSnackbar(
          context,
          e,
          'Failed to ${_isArchived ? 'unarchive' : 'archive'} conversation',
        );
      }
    }
  }
  
  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    
    // Send typing event when user types
    if (hasText) {
      TypingService.sendTypingEvent(widget.conversation.id);
    } else {
      TypingService.stopTyping(widget.conversation.id);
    }
  }
  
  Future<void> _loadSuggestions() async {
    try {
      final suggestion = await ChatSuggestionService.getSuggestions(widget.conversation);
      if (mounted) {
        safeSetState(() {
          _suggestion = suggestion;
          _showBookTrialButton = suggestion != null && suggestion.type == SuggestionType.bookTrial;
        });
      }
    } catch (e) {
      LogService.error('Error loading suggestions: $e');
    }
  }
  
  Future<void> _navigateToBookTrial() async {
    try {
      if (_suggestion == null) return;
      
      // Load tutor data
      final tutorData = await TutorService.fetchTutorById(_suggestion!.tutorId);
      if (tutorData != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookTrialSessionScreen(tutor: tutorData),
          ),
        );
      }
    } catch (e) {
      LogService.error('Error navigating to book trial: $e');
      if (mounted) {
        ErrorHandlerService.showErrorSnackbar(
          context,
          e,
          'Failed to load tutor information. Please try again.',
          _navigateToBookTrial,
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingDebounceTimer?.cancel();
    _messageBatchTimer?.cancel();
    // Cancel all optimistic message timers
    for (final timer in _optimisticMessageTimers.values) {
      timer.cancel();
    }
    _optimisticMessageTimers.clear();
    _messageStream?.cancel();
    _typingStream?.cancel();
    TypingService.stopTyping(widget.conversation.id);
    ChatService.unsubscribeFromMessages(widget.conversation.id);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      safeSetState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentOffset = 0;
        _hasMoreMessages = true;
      });

      final messages = await ChatService.getMessages(
        conversationId: widget.conversation.id,
        limit: _messagesPerPage,
        offset: _currentOffset,
      );

      if (mounted) {
        safeSetState(() {
          _messages = messages;
          _isLoading = false;
          _currentOffset = messages.length;
          // If we got fewer messages than requested, no more available
          _hasMoreMessages = messages.length >= _messagesPerPage;
          // Track loaded message IDs
          _loadedMessageIds = messages.map((m) => m.id).toSet();
        });
        
        // Mark messages as read when chat screen opens
        _markMessagesAsRead();
        
        // Scroll to bottom on initial load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollToBottom(animated: false);
          }
        });
      }
    } catch (e) {
      LogService.error('Error loading messages: $e');
      if (mounted) {
        safeSetState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load messages. Please try again.';
        });
      }
    }
  }

  /// Load more messages when scrolling up (lazy loading)
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    try {
      safeSetState(() {
        _isLoadingMore = true;
      });

      // Save current scroll position
      final previousScrollExtent = _scrollController.position.maxScrollExtent;

      final newMessages = await ChatService.getMessages(
        conversationId: widget.conversation.id,
        limit: _messagesPerPage,
        offset: _currentOffset,
      );

      if (mounted && newMessages.isNotEmpty) {
        safeSetState(() {
          // Prepend new messages to existing list (only if not already loaded)
          final newMessageIds = newMessages.map((m) => m.id).toSet();
          final uniqueNewMessages = newMessages.where((m) => !_loadedMessageIds.contains(m.id)).toList();
          
          if (uniqueNewMessages.isNotEmpty) {
            _messages = [...uniqueNewMessages, ..._messages];
            _currentOffset += uniqueNewMessages.length;
            _loadedMessageIds.addAll(newMessageIds);
          }
          
          _hasMoreMessages = newMessages.length >= _messagesPerPage;
          _isLoadingMore = false;
        });

        // Maintain scroll position after loading
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final newScrollExtent = _scrollController.position.maxScrollExtent;
            final scrollDifference = newScrollExtent - previousScrollExtent;
            _scrollController.jumpTo(_scrollController.position.pixels + scrollDifference);
          }
        });
      } else {
        safeSetState(() {
          _hasMoreMessages = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      LogService.error('Error loading more messages: $e');
      if (mounted) {
        safeSetState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _subscribeToMessages() {
    _messageStream = ChatService.watchMessages(widget.conversation.id).listen((messages) {
      if (mounted) {
        // Merge real-time updates with existing paginated list
        _mergeRealTimeMessages(messages);
      }
    });
  }

  /// Merge real-time message updates with existing paginated list
  /// Preserves pagination state and only adds/updates messages that are new or changed
  /// Uses ID-based deduplication for optimistic messages
  void _mergeRealTimeMessages(List<Message> realTimeMessages) {
    // Separate real messages from optimistic messages
    final realMessages = realTimeMessages.where((m) => !m.id.startsWith('temp_')).toList();
    
    // Start with existing messages (preserving pagination)
    final mergedMessages = List<Message>.from(_messages);
    
    // Track optimistic messages to remove (process after all real messages are added)
    final optimisticToRemove = <String>{};
    
    // Process each real-time message
        for (final realMsg in realMessages) {
      // Check if message already exists in our list
      final existingIndex = mergedMessages.indexWhere((m) => m.id == realMsg.id);
      
      if (existingIndex != -1) {
        // Update existing message (e.g., read receipt update)
        mergedMessages[existingIndex] = realMsg;
      } else {
        // New message - add it if it's within our loaded range
        // For pagination: only add if it's newer than the oldest loaded message
        // or if we're at the bottom (no pagination loaded)
        if (_messages.isEmpty || 
            realMsg.createdAt.isAfter(_messages.last.createdAt) ||
            realMsg.createdAt.isAtSameMomentAs(_messages.last.createdAt)) {
          // New message at the end - add it
          mergedMessages.add(realMsg);
          _loadedMessageIds.add(realMsg.id);
          
          // Try to match with optimistic messages (more lenient matching)
          // Match optimistic messages even if content is slightly different (handles formatting)
          for (final optMsg in mergedMessages.where((m) => m.id.startsWith('temp_'))) {
            // Match by content (normalized), sender, conversation, and time window (within 60 seconds for better matching)
            final optContent = optMsg.content.trim().toLowerCase();
            final realContent = realMsg.content.trim().toLowerCase();
            final contentMatch = optContent == realContent || 
                                (optContent.length > 10 && realContent.length > 10 && 
                                 (optContent.contains(realContent.substring(0, optContent.length > realContent.length ? realContent.length : optContent.length)) ||
                                  realContent.contains(optContent.substring(0, realContent.length > optContent.length ? optContent.length : realContent.length))));
            final senderMatch = optMsg.senderId == realMsg.senderId;
            final conversationMatch = optMsg.conversationId == realMsg.conversationId;
            final timeWindow = realMsg.createdAt.difference(optMsg.createdAt).inSeconds.abs() < 60; // Increased window
            
            if (contentMatch && senderMatch && conversationMatch && timeWindow) {
              optimisticToRemove.add(optMsg.id);
              LogService.debug('✅ Matched optimistic message ${optMsg.id} with real message ${realMsg.id}');
            }
          }
        }
        // If message is older than our oldest loaded message, it's from pagination
        // and we don't add it here (it will be loaded via pagination if user scrolls up)
      }
    }
    
    // Remove matched optimistic messages (after processing all real messages)
    for (final optId in optimisticToRemove) {
      mergedMessages.removeWhere((m) => m.id == optId);
      _optimisticMessageIds.remove(optId);
      _optimisticMessageTimers[optId]?.cancel();
      _optimisticMessageTimers.remove(optId);
      LogService.debug('🗑️ Removed optimistic message: $optId');
    }
    
    // Sort by creation time to maintain order
        mergedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        
        safeSetState(() {
          _messages = mergedMessages;
        });
        
    // Smart scroll: only auto-scroll if user is near bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _isNearBottom()) {
        _scrollToBottom(animated: true);
          }
        });
        
        // Mark messages as read
        _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final unreadMessages = _messages
          .where((msg) => !msg.isRead && !msg.isCurrentUser)
          .map((msg) => msg.id)
          .toList();
      
      if (unreadMessages.isNotEmpty) {
        await ChatService.markAsRead(
          conversationId: widget.conversation.id,
          messageIds: unreadMessages,
        );
      }
    } catch (e) {
      LogService.error('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    // Check conversation is still valid
    final isValid = await ConversationLifecycleService.isConversationValid(widget.conversation.id);
    if (!isValid) {
      if (mounted) {
        ErrorHandlerService.showErrorSnackbar(
          context,
          'This conversation is no longer active',
          'This conversation is no longer active',
        );
      }
      return;
    }

    // Get current user info for optimistic message
    final currentUserId = SupabaseService.currentUser?.id;
    final currentUserName = SupabaseService.currentUser?.userMetadata?['full_name'] as String? ?? 
                           widget.conversation.otherUserName ?? 'You';
    final currentUserAvatarUrl = SupabaseService.currentUser?.userMetadata?['avatar_url'] as String?;

    // Create optimistic message (show immediately)
    final optimisticId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = Message(
      id: optimisticId,
      conversationId: widget.conversation.id,
      senderId: currentUserId ?? '',
      content: content,
      createdAt: DateTime.now(),
      senderName: currentUserName,
      senderAvatarUrl: currentUserAvatarUrl,
      isCurrentUser: true,
      moderationStatus: 'pending', // Mark as pending until confirmed
    );

    // Track optimistic message ID
    _optimisticMessageIds.add(optimisticId);

    // Set timeout to remove optimistic message if real message doesn't arrive (increased to 30s to prevent disappearing)
    _optimisticMessageTimers[optimisticId] = Timer(const Duration(seconds: 30), () {
      if (mounted && _optimisticMessageIds.contains(optimisticId)) {
        // Only remove if we're sure it failed (check if real message exists)
        final realMessageExists = _messages.any((m) => 
          !m.id.startsWith('temp_') && 
          m.content.trim() == optimisticMessage.content.trim() &&
          m.senderId == optimisticMessage.senderId &&
          (m.createdAt.difference(optimisticMessage.createdAt).inSeconds.abs() < 30)
        );
        
        if (!realMessageExists) {
          safeSetState(() {
            _messages = _messages.where((m) => m.id != optimisticId).toList();
            _optimisticMessageIds.remove(optimisticId);
          });
          _optimisticMessageTimers.remove(optimisticId);
          LogService.warning('Removed optimistic message after timeout: $optimisticId');
        }
      }
    });

    // Add optimistic message to UI immediately for instant feedback
    safeSetState(() {
      _messages = [..._messages, optimisticMessage];
      _isSending = false; // Clear loading immediately - send feels instant
      _errorMessage = null;
    });

    // Clear input and reply state immediately
    _messageController.clear();
    safeSetState(() {
      _replyingToMessage = null;
    });

    // Stop typing indicator
    TypingService.stopTyping(widget.conversation.id);

    // Scroll to bottom immediately (user just sent a message)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollToBottom(animated: true);
      }
    });

    // Send message in background (non-blocking)
    try {
      // Preview message first (optional - can show warnings)
      final preview = await ChatService.previewMessage(content);
      if (preview['willBlock'] == true) {
        // Remove optimistic message and show error
        if (mounted) {
          safeSetState(() {
            _messages = _messages.where((m) => m.id != optimisticMessage.id).toList();
            _isSending = false;
          });
          ErrorHandlerService.showErrorSnackbar(
            context,
            preview['warnings']?.first ?? 'Message contains prohibited content',
            'Message contains prohibited content',
          );
        }
        return;
      }

      // Send message (real message will replace optimistic via realtime)
      // Don't await - let it happen in background for instant feel
      ChatService.sendMessage(
        conversationId: widget.conversation.id,
        content: content,
        replyToMessageId: _replyingToMessage?.id,
      ).then((_) {
        // Success - immediately update optimistic message to show "sent" status
        // This prevents messages from staying in "sending" state if realtime is slow
        if (mounted && _optimisticMessageIds.contains(optimisticId)) {
          safeSetState(() {
            final optIndex = _messages.indexWhere((m) => m.id == optimisticId);
            if (optIndex != -1) {
              // Update optimistic message to show as "sent" (moderationStatus = approved means sent)
              _messages[optIndex] = _messages[optIndex].copyWith(
                moderationStatus: 'approved',
              );
              LogService.debug('✅ Updated optimistic message to sent status: $optimisticId');
            }
          });
        }
        // Real message will arrive via realtime subscription and replace the optimistic one
      }).catchError((error) {
        // Only handle errors - success is handled by realtime subscription
        LogService.error('Error sending message: $error');
        if (mounted) {
          final errorMsg = error.toString().replaceFirst('Exception: ', '');
          safeSetState(() {
            _messages = _messages.where((m) => m.id != optimisticMessage.id).toList();
            _errorMessage = errorMsg;
            _isSending = false;
          });
          ErrorHandlerService.showErrorSnackbar(
            context,
            error,
            'Failed to send message',
            () => _sendMessage(),
          );
        }
        return null; // Return null to satisfy catchError return type
      });

      // The real message will arrive via realtime subscription and replace the optimistic one
      // Don't remove optimistic message prematurely - let it stay until real message arrives
      // This prevents messages from disappearing
    } catch (e) {
      // Handle any errors from preview message
      LogService.error('Error in message send flow: $e');
      if (mounted) {
        safeSetState(() {
          _messages = _messages.where((m) => m.id != optimisticMessage.id).toList();
          _isSending = false;
        });
        ErrorHandlerService.showErrorSnackbar(
          context,
          e,
          'Failed to send message. Please try again.',
          () => _sendMessage(),
        );
      }
    }
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inMinutes < 1) {
      return 'Active';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(lastSeen);
    }
  }

  /// Check if user is near bottom of scroll (within 100px)
  bool _isNearBottom() {
    if (!_scrollController.hasClients) return false;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final distanceFromBottom = maxScroll - currentScroll;
    
    // Consider "near bottom" if within 100px
    return distanceFromBottom < 100;
  }

  /// Scroll to bottom of message list
  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    
    if (animated) {
      _scrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(maxScroll);
    }
  }

  /// Build empty state with contextual messages
  Widget _buildEmptyState() {
    // Check if conversation is archived
    if (_isArchived) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.archive_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'This conversation is archived',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unarchive to continue the conversation',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          ),
        );
      }

    // Default empty state for new conversation
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation by sending a message!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (_showBookTrialButton) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _navigateToBookTrial,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'Book a Trial Session',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build skeleton loader for initial message load
  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        final isRight = index % 3 == 0; // Alternate left/right
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isRight) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                ),
                const SizedBox(width: 8),
              ],
              Container(
                width: MediaQuery.of(context).size.width * 0.6,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 14,
                      width: MediaQuery.of(context).size.width * 0.4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              if (isRight) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(time)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE HH:mm').format(time);
    } else {
      return DateFormat('MMM d, HH:mm').format(time);
    }
  }

  bool _shouldShowTimeSeparator(int index) {
    if (index == 0) return true;
    
    final current = _messages[index].createdAt;
    final previous = _messages[index - 1].createdAt;
    
    return current.difference(previous).inHours >= 1;
  }
  
  bool _shouldShowBanner() {
    return _suggestion != null &&
           !_bannerDismissed &&
           _messages.isNotEmpty &&
           _suggestion!.type == SuggestionType.bookTrial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(), color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              backgroundImage: widget.conversation.otherUserAvatarUrl != null &&
                      widget.conversation.otherUserAvatarUrl!.isNotEmpty &&
                      (widget.conversation.otherUserAvatarUrl!.startsWith('http://') ||
                       widget.conversation.otherUserAvatarUrl!.startsWith('https://'))
                  ? CachedNetworkImageProvider(widget.conversation.otherUserAvatarUrl!)
                  : null,
              child: widget.conversation.otherUserAvatarUrl == null ||
                      widget.conversation.otherUserAvatarUrl!.isEmpty ||
                      (!widget.conversation.otherUserAvatarUrl!.startsWith('http://') &&
                       !widget.conversation.otherUserAvatarUrl!.startsWith('https://'))
                  ? Text(
                      widget.conversation.otherUserName?.isNotEmpty == true
                          ? widget.conversation.otherUserName![0].toUpperCase()
                          : 'U',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.otherUserName ?? 'Unknown User',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  // Show active status based on last_seen (within 5 minutes = active)
                  if (widget.conversation.isOtherUserActive)
                    Text(
                      'Active',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppTheme.accentGreen,
                      ),
                    )
                  else if (_isOtherUserTyping)
                    Text(
                      'Typing...',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppTheme.accentGreen,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else if (widget.conversation.otherUserLastSeen != null)
                    Text(
                      _formatLastSeen(widget.conversation.otherUserLastSeen!),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppTheme.textLight,
                      ),
                    ),
                ],
              ),
            ),
            // Book trial button
            if (_showBookTrialButton)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextButton(
                  onPressed: _navigateToBookTrial,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Book trial',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.textDark,
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(PhosphorIcons.dotsThreeVertical(), color: AppTheme.textDark),
            onSelected: (value) {
              if (value == 'archive') {
                _handleArchiveAction();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(
                      _isArchived ? Icons.unarchive : Icons.archive_outlined,
                      size: 18,
                      color: AppTheme.textDark,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isArchived ? 'Unarchive' : 'Archive',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? _buildSkeletonLoader()
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length + 
                                   (_shouldShowBanner() ? 1 : 0) + 
                                   (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show loading indicator at top when loading more
                          if (_isLoadingMore && index == 0) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Loading more...',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          // Adjust index for loading indicator
                          final adjustedIndex = _isLoadingMore ? index - 1 : index;
                          
                          // Show banner after first message or date separator
                          if (_shouldShowBanner() && adjustedIndex == 0) {
                            return ActionSuggestionBanner(
                              message: _suggestion?.message ?? 'Book a trial while this tutor is still available',
                              onTap: _navigateToBookTrial,
                              onDismiss: () {
                                setState(() {
                                  _bannerDismissed = true;
                                });
                              },
                            );
                          }
                          
                          // Adjust index if banner is shown
                          final messageIndex = _shouldShowBanner() ? adjustedIndex - 1 : adjustedIndex;
                          if (messageIndex < 0 || messageIndex >= _messages.length) {
                            return const SizedBox.shrink();
                          }
                          
                          final message = _messages[messageIndex];
                          final showTimeSeparator = _shouldShowTimeSeparator(messageIndex);
                          
                          return Column(
                            children: [
                              if (showTimeSeparator)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _formatMessageTime(message.createdAt),
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                  ),
                                ),
                              _buildMessageBubble(message),
                            ],
                          );
                        },
                      ),
          ),
          
          // Error message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red[50],
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(PhosphorIcons.x(), size: 18),
                    color: Colors.red[700],
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          
          // Reply banner (if replying)
          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.softBackground,
                border: Border(
                  bottom: BorderSide(color: AppTheme.softBorder, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_replyingToMessage!.isCurrentUser ? 'You' : (_replyingToMessage!.senderName ?? 'Unknown')}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyingToMessage!.content,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(PhosphorIcons.x(), size: 18, color: AppTheme.textLight),
                    onPressed: () {
                      safeSetState(() {
                        _replyingToMessage = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          
          // Message input - seamless single color like WhatsApp/Preply
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.softBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.softBorder,
                          width: 1,
                        ),
                      ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.poppins(
                          color: AppTheme.textLight,
                          fontSize: 13,
                        ),
                        filled: true,
                          fillColor: AppTheme.softBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _isSending || !_hasText
                          ? AppTheme.primaryColor.withOpacity(0.3)
                          : AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: _hasText ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: IconButton(
                      icon: PhosphorIcon(
                        PhosphorIcons.paperPlaneTilt(),
                        color: _hasText ? Colors.white : Colors.white.withOpacity(0.5),
                        size: 18,
                      ),
                      onPressed: _isSending || !_hasText
                          ? null
                          : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isCurrentUser = message.isCurrentUser;
    final isOptimistic = message.id.startsWith('temp_');
    final messageStatus = _getMessageStatus(message);
    final hasReply = message.replyToMessageId != null;
    
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: GestureDetector(
          onLongPress: () {
            // Long press to reply
            safeSetState(() {
              _replyingToMessage = message;
            });
          },
          onTap: messageStatus == MessageStatus.failed && isCurrentUser
              ? () => _retryFailedMessage(message)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isCurrentUser 
                  ? AppTheme.primaryColor 
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isCurrentUser 
                  ? null
                  : Border.all(
                      color: AppTheme.softBorder,
                      width: 1,
                    ),
              // Neumorphic shadow effect
              boxShadow: [
                // Light shadow (top-left)
                BoxShadow(
                  color: isCurrentUser 
                      ? Colors.black.withOpacity(0.1)
                      : Colors.white,
                  blurRadius: 6,
                  offset: const Offset(-2, -2),
                  spreadRadius: 0,
                ),
                // Dark shadow (bottom-right)
                BoxShadow(
                  color: isCurrentUser
                      ? Colors.black.withOpacity(0.15)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(2, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reply preview if this message is a reply
                if (hasReply) ...[
                  Container(
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? Colors.white.withOpacity(0.2)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                      border: Border(
                        left: BorderSide(
                          color: isCurrentUser
                              ? Colors.white.withOpacity(0.5)
                              : AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.replyToSenderName ?? 'Unknown',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isCurrentUser
                                ? Colors.white
                                : AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message.replyToContent ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: isCurrentUser
                                ? Colors.white.withOpacity(0.8)
                                : AppTheme.textMedium,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
                // Message content
                Text(
                  message.content,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isCurrentUser ? Colors.white : AppTheme.textDark,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 3),
                // Timestamp and status
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.createdAt),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: isCurrentUser 
                            ? Colors.white.withOpacity(0.8)
                            : AppTheme.textLight,
                      ),
                    ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                      _buildMessageStatusIndicator(messageStatus, message),
                      ],
                    ],
                  ),
                ],
              ),
          ),
        ),
      ),
    );
  }

  /// Get message status based on message state
  MessageStatus _getMessageStatus(Message message) {
    final isOptimistic = message.id.startsWith('temp_');
    
    if (isOptimistic) {
      // Like WhatsApp: show checkmark immediately, no progress indicator
      // If optimistic message has been successfully sent (moderationStatus = approved),
      // show it as "sent" instead of "sending"
      if (message.moderationStatus == 'approved') {
        return MessageStatus.sent;
      }
      // Show as sent immediately (like WhatsApp) - no "sending" state
      return MessageStatus.sent;
    }
    
    // Check if message is in queue (failed)
    // This would require checking MessageQueueService, but for now we'll use moderation status
    if (message.moderationStatus == 'failed') {
      return MessageStatus.failed;
    }
    
    if (message.isRead) {
      return MessageStatus.read;
    }
    
    // Default to sent (delivered if we had delivery receipts)
    return MessageStatus.sent;
  }

  /// Build message status indicator widget
  Widget _buildMessageStatusIndicator(MessageStatus status, Message message) {
    switch (status) {
      case MessageStatus.sending:
        // Like WhatsApp: show checkmark immediately, no progress indicator
        return PhosphorIcon(
          PhosphorIcons.check(),
          size: 12,
          color: Colors.white.withOpacity(0.7),
        );
      
      case MessageStatus.sent:
        return PhosphorIcon(
          PhosphorIcons.check(),
          size: 12,
          color: Colors.white.withOpacity(0.7),
        );
      
      case MessageStatus.delivered:
        return SizedBox(
          width: 16,
          height: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                PhosphorIcons.check(),
                size: 14,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 2),
              PhosphorIcon(
                PhosphorIcons.check(),
                size: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ],
          ),
        );
      
      case MessageStatus.read:
        // Both ticks should be blue when message is read - positioned close together like WhatsApp
        return SizedBox(
          width: 18,
          height: 14,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                child: PhosphorIcon(
                  PhosphorIcons.check(),
                  size: 12,
                  color: Colors.blue[400]!,
                ),
              ),
              Positioned(
                left: 6, // Overlap slightly for WhatsApp-like appearance
                child: PhosphorIcon(
                  PhosphorIcons.check(),
                  size: 12,
                  color: Colors.blue[400]!,
                ),
              ),
            ],
          ),
        );
      
      case MessageStatus.failed:
        return GestureDetector(
          onTap: () => _retryFailedMessage(message),
          child: Tooltip(
            message: 'Tap to retry',
            child: Icon(
              Icons.error_outline,
              size: 14,
              color: Colors.red[300],
        ),
      ),
    );
    }
  }

  /// Retry sending a failed message
  Future<void> _retryFailedMessage(Message message) async {
    try {
      // Remove failed message from UI
      safeSetState(() {
        _messages = _messages.where((m) => m.id != message.id).toList();
      });

      // Retry sending
      await ChatService.sendMessage(
        conversationId: message.conversationId,
        content: message.content,
      );
    } catch (e) {
      LogService.error('Error retrying message: $e');
      if (mounted) {
        ErrorHandlerService.showErrorSnackbar(
          context,
          e,
          'Failed to retry message',
          () => _retryFailedMessage(message),
        );
      }
    }
  }
}

