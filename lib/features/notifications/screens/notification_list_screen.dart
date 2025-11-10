import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/services/notification_navigation_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/notifications/widgets/notification_item.dart';
import 'package:prepskul/features/notifications/screens/notification_preferences_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  String _filter = 'all'; // 'all', 'unread', 'booking', 'payment', 'session'
  StreamSubscription? _notificationStream;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _notificationStream?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notifications = await NotificationService.getUserNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToNotifications() {
    _notificationStream = NotificationService.watchNotifications().listen((
      notifications,
    ) {
      if (mounted) {
        setState(() {
          _notifications = notifications;
        });
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
    _loadNotifications();
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications();
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
          // LinkedIn-style Header with Logo and Name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // PrepSkul Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb
                      ? Image.network(
                          'https://prepskul.com/logo-blue.png',
                          width: 40,
                          height: 40,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.school,
                                color: Colors.white,
                                size: 24,
                              ),
                            );
                          },
                        )
                      : Image.asset(
                          'assets/images/app_logo(blue).png',
                          width: 40,
                          height: 40,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.school,
                                color: Colors.white,
                                size: 24,
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(width: 12),
                // PrepSkul Name
                Text(
                  'PrepSkul',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                // Notification count badge
                if (_notifications.any((n) => n['is_read'] == false))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_notifications.where((n) => n['is_read'] == false).length}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotifications.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _refreshNotifications,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _groupedNotifications.length,
                      itemBuilder: (context, index) {
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
                                    _loadNotifications();
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
        setState(() {
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: AppTheme.textLight),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filter == 'unread'
                ? 'You\'re all caught up!'
                : 'You don\'t have any notifications yet.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    // Mark as read
    if (notification['is_read'] == false) {
      NotificationService.markAsRead(notification['id'] as String);
    }

    // Navigate to related content if action URL exists
    final actionUrl = notification['action_url'] as String?;
    final notificationType = notification['type'] as String?;
    final metadata = notification['metadata'] as Map<String, dynamic>?;

    if (actionUrl != null) {
      // Import and use NotificationNavigationService
      // Note: We'll need to import it at the top of the file
      await NotificationNavigationService.navigateToAction(
        context: context,
        actionUrl: actionUrl,
        notificationType: notificationType,
        metadata: metadata,
      );
    } else if (notificationType != null) {
      // Fallback: navigate based on notification type
      await NotificationNavigationService.navigateToAction(
        context: context,
        actionUrl: null,
        notificationType: notificationType,
        metadata: metadata,
      );
    }
  }
}
