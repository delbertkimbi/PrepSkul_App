import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/services/notification_navigation_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/notifications/widgets/notification_item.dart';
import 'package:prepskul/features/notifications/screens/notification_preferences_screen.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/widgets/empty_state_widget.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';
import 'dart:async';

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

    return filtered;
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
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
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
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textDark),
            onPressed: () {
              Navigator.push(
                context,
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
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _groupedNotifications.length + 
                                (_isLoadingMore ? 1 : 0) +
                                (!_hasMore && _notifications.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Loading indicator at bottom
                        if (index >= _groupedNotifications.length) {
                          if (_isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (!_hasMore && _notifications.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  'No more notifications',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }
                        
                        final group = _groupedNotifications.entries
                            .toList()[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: 12,
                                top: index > 0 ? 24 : 0,
                              ),
                              child: Text(
                                group.key,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                            ),
                            ...group.value.map(
                              (notification) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: NotificationItem(
                                  notification: notification,
                                  onTap: () {
                                    // Handle notification tap (navigate to related content)
                                    _handleNotificationTap(notification);
                                  },
                                  onDelete: () {
                                    _loadNotifications(refresh: true);
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
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
      labelStyle: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
      ),
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