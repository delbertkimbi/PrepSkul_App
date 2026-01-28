import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/services/notification_navigation_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/notifications/widgets/notification_item.dart';
import 'package:prepskul/features/notifications/widgets/notification_group_item.dart';
import 'package:prepskul/features/notifications/screens/notification_preferences_screen.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/widgets/empty_state_widget.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';
import 'dart:async';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Notification List Screen
///
/// Displays all notifications for the current user
/// Supports filtering, marking as read, and deleting
class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  String _filter = 'all'; // 'all', 'unread', 'booking', 'payment', 'session'
  StreamSubscription? _notificationStream;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _notificationStream?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when user scrolls to 80% of the list
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadMore();
      }
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    try {
      if (refresh) {
        safeSetState(() {
          _notifications = [];
          _currentPage = 0;
          _hasMore = true;
          _isLoading = true;
        });
      } else {
        safeSetState(() => _isLoading = true);
      }

      final result = await NotificationService.getUserNotificationsPaginated(
        limit: _pageSize,
        offset: 0,
        unreadOnly: _filter == 'unread' ? true : null,
      );

      if (mounted) {
        safeSetState(() {
          _notifications = result['notifications'] as List<Map<String, dynamic>>;
          _hasMore = result['hasMore'] as bool;
          _currentPage = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      LogService.error('Error loading notifications: $e');
      if (mounted) {
        safeSetState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    try {
      safeSetState(() => _isLoadingMore = true);

      final nextPage = _currentPage + 1;
      final result = await NotificationService.getUserNotificationsPaginated(
        limit: _pageSize,
        offset: nextPage * _pageSize,
        unreadOnly: _filter == 'unread' ? true : null,
      );

      final newNotifications = result['notifications'] as List<Map<String, dynamic>>;
      final hasMore = result['hasMore'] as bool;

      if (mounted) {
        safeSetState(() {
          _notifications.addAll(newNotifications);
          _hasMore = hasMore;
          _currentPage = nextPage;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      LogService.error('Error loading more notifications: $e');
      if (mounted) {
        safeSetState(() => _isLoadingMore = false);
      }
    }
  }

  void _subscribeToNotifications() {
    _notificationStream = NotificationService.watchNotifications().listen((
      notifications,
    ) {
      if (mounted) {
        // Only append new notifications that aren't already in the list
        final existingIds = _notifications.map((n) => n['id']).toSet();
        final newNotifications = notifications.where((n) => 
          !existingIds.contains(n['id'])
        ).toList();
        
        if (newNotifications.isNotEmpty) {
          safeSetState(() {
            // Prepend new notifications to the list
            _notifications.insertAll(0, newNotifications);
          });
        }
      }
    });
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    var filtered = _notifications;

    // Filter by read status
    if (_filter == 'unread') {
      filtered = filtered.where((n) => n['is_read'] == false).toList();
    } else if (_filter != 'all') {
      // Filter by type
      filtered = filtered.where((n) => n['type'] == _filter).toList();
    }

    // Search functionality removed - no longer needed

    return filtered;
  }

  /// Smart grouping: Group similar notifications together
  Map<String, List<dynamic>> get _smartGroupedNotifications {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    
    // Group notifications by type and time proximity
    final Map<String, List<Map<String, dynamic>>> groups = {};
    
    for (final notification in _filteredNotifications) {
      final type = notification['type'] as String? ?? 'general';
      final createdAt = DateTime.parse(notification['created_at'] as String);
      final metadata = notification['metadata'] as Map<String, dynamic>?;
      
      // Create a group key based on type and context
      String groupKey = type;
      
      // For booking requests, group by type only (all booking requests together)
      if (type.contains('booking_request')) {
        groupKey = 'booking_request_group';
      } else if (type.contains('payment')) {
        groupKey = 'payment_group';
      } else if (type.contains('session_reminder')) {
        groupKey = 'session_reminder_group';
      } else if (type.contains('onboarding_reminder')) {
        // Group all onboarding reminders together
        groupKey = 'onboarding_reminder_group';
      } else if (type.contains('message') || type.contains('chat')) {
        // Group messages by sender if available
        final senderId = metadata?['sender_id'] as String?;
        if (senderId != null) {
          groupKey = 'message_$senderId';
        } else {
          groupKey = 'message_group';
        }
      }
      
      // Only group if notification is recent (within 1 hour)
      final shouldGroup = createdAt.isAfter(oneHourAgo) && 
                          _shouldGroupNotificationType(type);
      
      if (shouldGroup && groups.containsKey(groupKey)) {
        // Add to existing group if within time window
        final existingGroup = groups[groupKey]!;
        final latestInGroup = existingGroup.first;
        final latestTime = DateTime.parse(latestInGroup['created_at'] as String);
        
        // Group if within 1 hour of latest notification in group
        if (createdAt.difference(latestTime).inHours < 1) {
          existingGroup.add(notification);
          // Sort by time (newest first)
          existingGroup.sort((a, b) {
            final timeA = DateTime.parse(a['created_at'] as String);
            final timeB = DateTime.parse(b['created_at'] as String);
            return timeB.compareTo(timeA);
          });
        } else {
          // Too old, create new group
          groups['${groupKey}_${createdAt.millisecondsSinceEpoch}'] = [notification];
        }
      } else {
        // Create new group
        groups['${groupKey}_${createdAt.millisecondsSinceEpoch}'] = [notification];
      }
    }
    
    // Convert groups to list and sort by latest notification time
    final groupedList = groups.entries.map((entry) {
      final notifications = entry.value;
      if (notifications.length > 1) {
        // Return group object
        return {
          'isGroup': true,
          'notifications': notifications,
          'type': notifications.first['type'] as String? ?? 'general',
          'count': notifications.length,
          'latestTime': DateTime.parse(notifications.first['created_at'] as String),
        };
      } else {
        // Single notification
        return {
          'isGroup': false,
          'notification': notifications.first,
          'latestTime': DateTime.parse(notifications.first['created_at'] as String),
        };
      }
    }).toList();
    
    // Sort by latest time (newest first)
    groupedList.sort((a, b) {
      final timeA = a['latestTime'] as DateTime;
      final timeB = b['latestTime'] as DateTime;
      return timeB.compareTo(timeA);
    });
    
    // Now group by time periods (Today, Yesterday, etc.)
    final timeGrouped = <String, List<dynamic>>{
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Older': [],
    };
    
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));
    
    for (final item in groupedList) {
      final latestTime = item['latestTime'] as DateTime;
      final createdDate = DateTime(
        latestTime.year,
        latestTime.month,
        latestTime.day,
      );
      
      if (createdDate == today) {
        timeGrouped['Today']!.add(item);
      } else if (createdDate == yesterday) {
        timeGrouped['Yesterday']!.add(item);
      } else if (createdDate.isAfter(weekAgo)) {
        timeGrouped['This Week']!.add(item);
      } else {
        timeGrouped['Older']!.add(item);
      }
    }
    
    // Remove empty groups
    timeGrouped.removeWhere((key, value) => value.isEmpty);
    
    return timeGrouped;
  }
  
  /// Check if notification type should be grouped
  bool _shouldGroupNotificationType(String type) {
    final groupableTypes = [
      'booking_request',
      'payment_received',
      'payment_confirmed',
      'session_reminder',
      'session_starting_soon',
      'tutor_message',
      'message',
      'onboarding_reminder', // Group duplicate onboarding reminders
    ];
    
    return groupableTypes.any((groupableType) => type.contains(groupableType));
  }
  
  /// Generate summary message for grouped notifications
  String _getGroupSummaryMessage(String type, int count, List<Map<String, dynamic>> notifications) {
    if (type.contains('booking_request')) {
      return '$count new booking request${count > 1 ? 's' : ''}';
    } else if (type.contains('payment')) {
      return '$count payment notification${count > 1 ? 's' : ''}';
    } else if (type.contains('session_reminder')) {
      return '$count session reminder${count > 1 ? 's' : ''}';
    } else if (type.contains('onboarding_reminder')) {
      return 'Complete Your Profile to Get Verified';
    } else if (type.contains('message')) {
      final senderName = notifications.first['metadata']?['sender_name'] as String?;
      if (senderName != null) {
        return '$count new message${count > 1 ? 's' : ''} from $senderName';
      }
      return '$count new message${count > 1 ? 's' : ''}';
    }
    return '$count notification${count > 1 ? 's' : ''}';
  }

  Map<String, List<Map<String, dynamic>>> get _groupedNotifications {
    final grouped = <String, List<Map<String, dynamic>>>{
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Older': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    for (final notification in _filteredNotifications) {
      final createdAt = DateTime.parse(notification['created_at'] as String);
      final createdDate = DateTime(
        createdAt.year,
        createdAt.month,
        createdAt.day,
      );

      if (createdDate == today) {
        grouped['Today']!.add(notification);
      } else if (createdDate == yesterday) {
        grouped['Yesterday']!.add(notification);
      } else if (createdDate.isAfter(weekAgo)) {
        grouped['This Week']!.add(notification);
      } else {
        grouped['Older']!.add(notification);
      }
    }

    // Remove empty groups
    grouped.removeWhere((key, value) => value.isEmpty);

    return grouped;
  }

  Future<void> _markAllAsRead() async {
    await NotificationService.markAllAsRead();
    _loadNotifications(refresh: true);
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(), color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.gear(), color: AppTheme.textDark),
            onPressed: () {
              // Use root navigator to avoid nested navigation issues
              Navigator.of(context, rootNavigator: false).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationPreferencesScreen(),
                ),
              );
            },
          ),
          if (_notifications.any((n) => n['is_read'] == false))
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all read',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('unread', 'Unread'),
                  const SizedBox(width: 8),
                  _buildFilterChip('booking_request', 'Bookings'),
                  const SizedBox(width: 8),
                  _buildFilterChip('payment_received', 'Payments'),
                  const SizedBox(width: 8),
                  _buildFilterChip('session_completed', 'Sessions'),
                ],
              ),
            ),
          ),

          // Notifications List
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (context, index) => ShimmerLoading.listTile(),
                  )
                : _filteredNotifications.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _refreshNotifications,
                    child: _buildSmartGroupedList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filter, String label) {
    final isSelected = _filter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        safeSetState(() {
          _filter = filter;
        });
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelStyle: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
      ),
    );
  }

  Widget _buildSmartGroupedList() {
    final smartGroups = _smartGroupedNotifications;
    int totalItems = 0;
    
    // Calculate total items (groups + time headers)
    for (final timeGroup in smartGroups.entries) {
      final listLength = (timeGroup.value as List).length;
      totalItems += 1 + listLength; // 1 for header, rest for items
    }
    
    final loadingIndicatorCount = (_isLoadingMore ? 1 : 0);
    final endMessageCount = (!_hasMore && _notifications.isNotEmpty ? 1 : 0);
    totalItems += loadingIndicatorCount + endMessageCount;
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        final bottomThreshold = totalItems - loadingIndicatorCount - endMessageCount;
        
        // Loading indicator at bottom
        if (index >= bottomThreshold) {
          if (_isLoadingMore && index == totalItems - 2) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (!_hasMore && _notifications.isNotEmpty && index == totalItems - 1) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No more notifications',
                  style: GoogleFonts.poppins(
                    fontSize: 16, // Increased from 14 (added 2)
                    color: AppTheme.textMedium,
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        
        // Find which time group and item we're rendering
        int itemsSoFar = 0;
        String? currentTimeGroup;
        dynamic currentItem;
        
        for (final timeGroup in smartGroups.entries) {
          final listLength = (timeGroup.value as List).length;
          final groupSize = 1 + listLength; // 1 for header, rest for items
          
          if (index < itemsSoFar + groupSize) {
            currentTimeGroup = timeGroup.key;
            if (index == itemsSoFar) {
              // Render time group header
              return Padding(
                padding: EdgeInsets.only(
                  bottom: 12,
                  top: index > 0 ? 24 : 0,
                ),
                child: Text(
                  currentTimeGroup!,
                  style: GoogleFonts.poppins(
                    fontSize: 16, // Increased from 14 (added 2)
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMedium,
                  ),
                ),
              );
            } else {
              // Render item in this time group
              final itemIndex = index - itemsSoFar - 1;
              final items = timeGroup.value as List;
              currentItem = items[itemIndex];
              break;
            }
          }
          itemsSoFar += groupSize;
        }
        
        if (currentItem == null) {
          return const SizedBox.shrink();
        }
        
        // Render grouped or individual notification
        if (currentItem['isGroup'] == true) {
          final notifications = currentItem['notifications'] as List<Map<String, dynamic>>;
          final type = currentItem['type'] as String;
          final summary = _getGroupSummaryMessage(type, notifications.length, notifications);
          
          return NotificationGroupItem(
            notifications: notifications,
            groupType: type,
            summaryMessage: summary,
            onTap: () {
              if (notifications.length == 1) {
                _handleNotificationTap(notifications.first);
              }
            },
            onDelete: () {
              _loadNotifications(refresh: true);
            },
          );
        } else {
          final notification = currentItem['notification'] as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: NotificationItem(
              notification: notification,
              onTap: () {
                _handleNotificationTap(notification);
              },
              onDelete: () {
                _loadNotifications(refresh: true);
              },
            ),
          );
        }
      },
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget.noNotifications();
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    // Mark as read first
    if (notification['is_read'] == false) {
      NotificationService.markAsRead(notification['id'] as String);
    }

    // Use NotificationNavigationService to handle deep linking
    final actionUrl = notification['action_url'] as String?;
    final notificationType = notification['type'] as String?;
    final metadata = notification['metadata'] as Map<String, dynamic>?;

    await NotificationNavigationService.navigateToAction(
      context: context,
      actionUrl: actionUrl,
      notificationType: notificationType,
      metadata: metadata,
    );
  }
}