import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/chat_service.dart';
import '../services/conversation_lifecycle_service.dart';
import '../services/chat_suggestion_service.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../widgets/action_suggestion_banner.dart';
import 'package:prepskul/features/booking/screens/book_trial_session_screen.dart';
import 'package:prepskul/core/services/tutor_service.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  StreamSubscription? _messageStream;
  String? _errorMessage;
  ChatSuggestion? _suggestion;
  bool _bannerDismissed = false;
  bool _showBookTrialButton = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    _loadSuggestions();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load tutor information. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageStream?.cancel();
    ChatService.unsubscribeFromMessages(widget.conversation.id);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      safeSetState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final messages = await ChatService.getMessages(
        conversationId: widget.conversation.id,
      );

      if (mounted) {
        safeSetState(() {
          _messages = messages;
          _isLoading = false;
        });
        
        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
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

  void _subscribeToMessages() {
    _messageStream = ChatService.watchMessages(widget.conversation.id).listen((messages) {
      if (mounted) {
        safeSetState(() {
          _messages = messages;
        });
        
        // Scroll to bottom on new message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
        
        // Mark messages as read
        _markMessagesAsRead();
      }
    });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This conversation is no longer active'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    safeSetState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      // Preview message first (optional - can show warnings)
      final preview = await ChatService.previewMessage(content);
      if (preview['willBlock'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(preview['warnings']?.first ?? 'Message contains prohibited content'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        safeSetState(() {
          _isSending = false;
        });
        return;
      }

      // Send message
      await ChatService.sendMessage(
        conversationId: widget.conversation.id,
        content: content,
      );

      // Clear input
      _messageController.clear();

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      LogService.error('Error sending message: $e');
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        safeSetState(() {
          _errorMessage = errorMsg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        safeSetState(() {
          _isSending = false;
        });
      }
    }
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              backgroundImage: widget.conversation.otherUserAvatarUrl != null &&
                      widget.conversation.otherUserAvatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(widget.conversation.otherUserAvatarUrl!)
                  : null,
              child: widget.conversation.otherUserAvatarUrl == null ||
                      widget.conversation.otherUserAvatarUrl!.isEmpty
                  ? Text(
                      widget.conversation.otherUserName?.isNotEmpty == true
                          ? widget.conversation.otherUserName![0].toUpperCase()
                          : 'U',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.otherUserName ?? 'Unknown User',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  if (widget.conversation.status == 'active')
                    Text(
                      'Active',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.green[600],
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
                      fontSize: 14,
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
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
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
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation!',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_shouldShowBanner() ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show banner after first message or date separator
                          if (_shouldShowBanner() && index == 0) {
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
                          final messageIndex = _shouldShowBanner() ? index - 1 : index;
                          if (messageIndex < 0 || messageIndex >= _messages.length) {
                            return const SizedBox.shrink();
                          }
                          
                          final message = _messages[messageIndex];
                          final showTimeSeparator = _shouldShowTimeSeparator(messageIndex);
                          
                          return Column(
                            children: [
                              if (showTimeSeparator)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _formatMessageTime(message.createdAt),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
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
                    icon: const Icon(Icons.close, size: 18),
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
          
          // Message input
          Container(
            padding: const EdgeInsets.all(12),
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
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _isSending || _messageController.text.trim().isEmpty
                          ? Colors.grey[300]
                          : AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isSending || _messageController.text.trim().isEmpty
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
    
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isCurrentUser 
              ? CrossAxisAlignment.end 
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser 
                    ? AppTheme.primaryColor 
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                  bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isCurrentUser ? Colors.white : AppTheme.textDark,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isCurrentUser 
                              ? Colors.white.withOpacity(0.7)
                              : Colors.grey[600],
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead 
                              ? Icons.done_all 
                              : Icons.done,
                          size: 14,
                          color: message.isRead
                              ? Colors.blue[300]
                              : Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (message.isFiltered)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 12, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Message flagged for review',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

