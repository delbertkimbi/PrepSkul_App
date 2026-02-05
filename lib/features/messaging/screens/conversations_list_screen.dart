import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/error_handler_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/chat_service.dart';
import '../models/conversation_model.dart';
import '../widgets/empty_conversations_state.dart';
import 'chat_screen.dart';

/// Conversations List Screen
/// 
/// Displays all conversations for the current user
/// Shows last message preview, unread badges, and search
class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String _selectedTab = 'all'; // 'all' or 'archived'
  StreamSubscription? _conversationStream;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _subscribeToConversations();
  }

  @override
  void dispose() {
    _conversationStream?.cancel();
    ChatService.unsubscribeFromConversations();
    super.dispose();
  }

  Future<void> _loadConversations({bool refresh = false}) async {
    try {
      if (refresh) {
        safeSetState(() {
          _conversations = [];
          _isLoading = true;
        });
      } else {
        safeSetState(() => _isLoading = true);
      }

      final conversations = _selectedTab == 'archived'
          ? await ChatService.getArchivedConversations()
          : await ChatService.getConversations();

      if (mounted) {
        safeSetState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      LogService.error('Error loading conversations: $e');
      if (mounted) {
        safeSetState(() => _isLoading = false);
        ErrorHandlerService.showErrorSnackbar(
          context,
          e,
          'Failed to load conversations. Please try again.',
          () => _loadConversations(refresh: true),
        );
      }
    }
  }

  void _subscribeToConversations() {
    _conversationStream = ChatService.watchConversations().listen((conversations) async {
      if (mounted) {
        // Reload conversations based on current tab
        await _loadConversations(refresh: true);
      }
    });
  }

  List<Conversation> get _filteredConversations {
    // Deduplicate conversations - show only the most recent conversation per user
    final Map<String, Conversation> uniqueConversations = {};
    
    for (final conversation in _conversations) {
      // Use other user ID as key for deduplication
      final otherUserId = conversation.studentId == (SupabaseService.currentUser?.id ?? '')
          ? conversation.tutorId
          : conversation.studentId;
      
      // If we haven't seen this user yet, or this conversation is more recent, use it
      if (!uniqueConversations.containsKey(otherUserId) ||
          (conversation.lastMessageAt != null &&
           uniqueConversations[otherUserId]!.lastMessageAt != null &&
           conversation.lastMessageAt!.isAfter(uniqueConversations[otherUserId]!.lastMessageAt!))) {
        uniqueConversations[otherUserId] = conversation;
      }
    }
    
    // Return sorted by last message time (most recent first)
    final deduplicated = uniqueConversations.values.toList();
    deduplicated.sort((a, b) {
      if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
      if (a.lastMessageAt == null) return 1;
      if (b.lastMessageAt == null) return -1;
      return b.lastMessageAt!.compareTo(a.lastMessageAt!);
    });
    
    return deduplicated;
  }
  
  Future<void> _handleArchiveAction(Conversation conversation) async {
    try {
      if (_selectedTab == 'archived') {
        // Unarchive
        await ChatService.unarchiveConversation(conversation.id);
        if (mounted) {
          ErrorHandlerService.showSuccess(context, 'Conversation unarchived');
          await _loadConversations(refresh: true);
        }
      } else {
        // Archive
        await ChatService.archiveConversation(conversation.id);
        if (mounted) {
          ErrorHandlerService.showSuccess(context, 'Conversation archived');
          await _loadConversations(refresh: true);
        }
      }
    } catch (e) {
      LogService.error('Error archiving/unarchiving conversation: $e');
      if (mounted) {
        ErrorHandlerService.showErrorSnackbar(
          context,
          e,
          'Failed to ${_selectedTab == 'archived' ? 'unarchive' : 'archive'} conversation',
        );
      }
    }
  }

  String _formatLastMessageTime(DateTime? time) {
    if (time == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(time);
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildTab('All', 'all'),
                const SizedBox(width: 20),
                _buildTab('Archived', 'archived'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: 5,
              itemBuilder: (context, index) => ShimmerLoading.sessionCard(),
            )
          : _filteredConversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => _loadConversations(refresh: true),
                  color: AppTheme.primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: _filteredConversations.length,
                    itemBuilder: (context, index) {
                      return _buildConversationCard(_filteredConversations[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildTab(String label, String value) {
    final isSelected = _selectedTab == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = value;
        });
        _loadConversations(refresh: true);
      },
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? AppTheme.textDark : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            width: label.length * 8.0,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    // Show archived empty state
    if (_selectedTab == 'archived') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.archive_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No archived conversations',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show main empty state - user-type aware
    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService.getUserProfile(),
      builder: (context, snapshot) {
        final userType = snapshot.data?['user_type'] as String? ?? 'student';
        final isStudentOrParent = userType == 'student' || userType == 'parent' || userType == 'learner';
        
        return Center(
          child: EmptyConversationsState(
            userType: userType,
            onFindTutor: isStudentOrParent ? () async {
              try {
                final route = userType == 'parent' ? '/parent-nav' : '/student-nav';
                Navigator.pushReplacementNamed(
                  context,
                  route,
                  arguments: {'initialTab': 1}, // Find Tutors tab
                );
              } catch (e) {
                LogService.error('Error navigating to find tutors: $e');
                // Fallback: just navigate to student-nav
                Navigator.pushReplacementNamed(
                  context,
                  '/student-nav',
                  arguments: {'initialTab': 1},
                );
              }
            } : null,
          ),
        );
      },
    );
  }

  Widget _buildConversationCard(Conversation conversation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(conversation: conversation),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar with unread badge - using CachedNetworkImage widget for better loading
              Stack(
                children: [
                  ClipOval(
                    child: conversation.otherUserAvatarUrl != null &&
                            conversation.otherUserAvatarUrl!.isNotEmpty &&
                            (conversation.otherUserAvatarUrl!.startsWith('http://') ||
                             conversation.otherUserAvatarUrl!.startsWith('https://'))
                        ? CachedNetworkImage(
                            imageUrl: conversation.otherUserAvatarUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            cacheKey: 'conversation_avatar_${conversation.id}',
                            memCacheWidth: 96,
                            memCacheHeight: 96,
                            placeholder: (context, url) => Container(
                              width: 48,
                              height: 48,
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 48,
                              height: 48,
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              child: Center(
                                child: Text(
                                  conversation.otherUserName?.isNotEmpty == true
                                      ? conversation.otherUserName![0].toUpperCase()
                                      : 'U',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            child: Center(
                              child: Text(
                                conversation.otherUserName?.isNotEmpty == true
                                    ? conversation.otherUserName![0].toUpperCase()
                                    : 'U',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (conversation.unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                        child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Center(
                          child: Text(
                            conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              // Conversation info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.otherUserName ?? 'Unknown User',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.lastMessageTime != null)
                          Text(
                            _formatLastMessageTime(conversation.lastMessageTime),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      conversation.lastMessagePreview ?? 'No messages yet',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: conversation.unreadCount > 0
                            ? AppTheme.textDark
                            : Colors.grey[600],
                        fontWeight: conversation.unreadCount > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // 3-dot menu for options
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AppTheme.textLight,
                  size: 20,
                ),
                onSelected: (value) {
                  if (value == 'archive') {
                    _handleArchiveAction(conversation);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(
                          _selectedTab == 'archived' ? Icons.unarchive : Icons.archive_outlined,
                          size: 18,
                          color: AppTheme.textDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedTab == 'archived' ? 'Unarchive' : 'Archive',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
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
        ),
      ),
    );
  }
}

