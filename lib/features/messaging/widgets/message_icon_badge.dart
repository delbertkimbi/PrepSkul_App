import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/messaging/screens/conversations_list_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Message Icon Badge Widget
/// 
/// Displays a message icon with unread conversations badge
/// Tappable to open conversations list
/// Shows total unread messages across all conversations
class MessageIconBadge extends StatefulWidget {
  final Color? iconColor;
  
  const MessageIconBadge({super.key, this.iconColor});

  @override
  State<MessageIconBadge> createState() => _MessageIconBadgeState();
}

class _MessageIconBadgeState extends State<MessageIconBadge> with WidgetsBindingObserver {
  int _unreadCount = 0;
  StreamSubscription? _conversationStream;
  RealtimeChannel? _realtimeChannel;
  Timer? _reloadDebounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnreadCount();
    _subscribeToConversations();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload count when app comes to foreground
      _debouncedReload();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload count when widget becomes visible again (e.g., returning from chat)
    _debouncedReload();
  }

  void _debouncedReload() {
    _reloadDebounceTimer?.cancel();
    _reloadDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadUnreadCount();
    });
  }

  Future<void> _loadUnreadCount() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _unreadCount = 0;
          });
        }
        return;
      }

      // Get all conversations where user is student or tutor
      final conversationsResponse = await SupabaseService.client
          .from('conversations')
          .select('id')
          .or('student_id.eq.$userId,tutor_id.eq.$userId');

      if (conversationsResponse.isEmpty) {
        if (mounted) {
          setState(() {
            _unreadCount = 0;
          });
        }
        return;
      }

      final conversationIds = (conversationsResponse as List)
          .map((c) => c['id'] as String)
          .toList();

      if (conversationIds.isEmpty) {
        if (mounted) {
          setState(() {
            _unreadCount = 0;
          });
        }
        return;
      }

      // Get total unread messages across all conversations
      // Only count messages not sent by current user
      final unreadResponse = await SupabaseService.client
          .from('messages')
          .select('id')
          .inFilter('conversation_id', conversationIds)
          .eq('is_read', false)
          .neq('sender_id', userId);

      // Count the results (Supabase returns a list, count its length)
      final unreadCount = (unreadResponse as List).length;

      if (mounted) {
        setState(() {
          _unreadCount = unreadCount;
        });
      }
    } catch (e) {
      LogService.error('Error loading unread message count: $e');
      if (mounted) {
        setState(() {
          _unreadCount = 0;
        });
      }
    }
  }

  void _subscribeToConversations() {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;

      // Subscribe to messages table changes for real-time updates
      // Use a single channel with multiple filters
      _realtimeChannel = SupabaseService.client
          .channel('message_badge_${userId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              // Reload unread count when messages change (INSERT, UPDATE, DELETE)
              // This includes when is_read is updated
              LogService.debug('Message badge: Message change detected: ${payload.eventType}');
              _debouncedReload();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversations',
            callback: (payload) {
              // Reload unread count when conversations change
              LogService.debug('Message badge: Conversation change detected: ${payload.eventType}');
              _debouncedReload();
            },
          )
          .subscribe();
    } catch (e) {
      LogService.error('Error subscribing to conversation updates: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reloadDebounceTimer?.cancel();
    _conversationStream?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ConversationsListScreen(),
          ),
        ).then((_) {
          // Reload count when returning from conversations list
          _loadUnreadCount();
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.iconColor != null 
                  ? Colors.white.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.chat,
              color: widget.iconColor ?? AppTheme.textDark,
              size: 24,
            ),
          ),
          if (_unreadCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Center(
                  child: Text(
                    _unreadCount > 99 ? '99+' : '$_unreadCount',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/messaging/screens/conversations_list_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Message Icon Badge Widget
/// 
/// Displays a message icon with unread conversations badge
/// Tappable to open conversations list
/// Shows total unread messages across all conversations
class MessageIconBadge extends StatefulWidget {
  final Color? iconColor;
  
  const MessageIconBadge({super.key, this.iconColor});

  @override
  State<MessageIconBadge> createState() => _MessageIconBadgeState();
}

class _MessageIconBadgeState extends State<MessageIconBadge> with WidgetsBindingObserver {
  int _unreadCount = 0;
  StreamSubscription? _conversationStream;
  RealtimeChannel? _realtimeChannel;
  Timer? _reloadDebounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnreadCount();
    _subscribeToConversations();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload count when app comes to foreground
      _debouncedReload();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload count when widget becomes visible again (e.g., returning from chat)
    _debouncedReload();
  }

  void _debouncedReload() {
    _reloadDebounceTimer?.cancel();
    _reloadDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadUnreadCount();
    });
  }

  Future<void> _loadUnreadCount() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _unreadCount = 0;
          });
        }
        return;
      }

      // Get all conversations where user is student or tutor
      final conversationsResponse = await SupabaseService.client
          .from('conversations')
          .select('id')
          .or('student_id.eq.$userId,tutor_id.eq.$userId');

      if (conversationsResponse.isEmpty) {
        if (mounted) {
          setState(() {
            _unreadCount = 0;
          });
        }
        return;
      }

      final conversationIds = (conversationsResponse as List)
          .map((c) => c['id'] as String)
          .toList();

      if (conversationIds.isEmpty) {
        if (mounted) {
          setState(() {
            _unreadCount = 0;
          });
        }
        return;
      }

      // Get total unread messages across all conversations
      // Only count messages not sent by current user
      final unreadResponse = await SupabaseService.client
          .from('messages')
          .select('id')
          .inFilter('conversation_id', conversationIds)
          .eq('is_read', false)
          .neq('sender_id', userId);

      // Count the results (Supabase returns a list, count its length)
      final unreadCount = (unreadResponse as List).length;

      if (mounted) {
        setState(() {
          _unreadCount = unreadCount;
        });
      }
    } catch (e) {
      LogService.error('Error loading unread message count: $e');
      if (mounted) {
        setState(() {
          _unreadCount = 0;
        });
      }
    }
  }

  void _subscribeToConversations() {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;

      // Subscribe to messages table changes for real-time updates
      // Use a single channel with multiple filters
      _realtimeChannel = SupabaseService.client
          .channel('message_badge_${userId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              // Reload unread count when messages change (INSERT, UPDATE, DELETE)
              // This includes when is_read is updated
              LogService.debug('Message badge: Message change detected: ${payload.eventType}');
              _debouncedReload();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversations',
            callback: (payload) {
              // Reload unread count when conversations change
              LogService.debug('Message badge: Conversation change detected: ${payload.eventType}');
              _debouncedReload();
            },
          )
          .subscribe();
    } catch (e) {
      LogService.error('Error subscribing to conversation updates: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reloadDebounceTimer?.cancel();
    _conversationStream?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ConversationsListScreen(),
          ),
        ).then((_) {
          // Reload count when returning from conversations list
          _loadUnreadCount();
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.iconColor != null 
                  ? Colors.white.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.chat,
              color: widget.iconColor ?? AppTheme.textDark,
              size: 24,
            ),
          ),
          if (_unreadCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Center(
                  child: Text(
                    _unreadCount > 99 ? '99+' : '$_unreadCount',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
