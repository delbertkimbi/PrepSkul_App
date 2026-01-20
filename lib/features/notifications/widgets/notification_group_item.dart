import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/services/notification_navigation_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/notifications/widgets/notification_item.dart';
import 'package:intl/intl.dart';

/// Notification Group Item Widget
/// 
/// Displays a group of similar notifications (e.g., "3 new booking requests")
/// Can be expanded to show individual notifications
class NotificationGroupItem extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final String groupType;
  final String summaryMessage;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const NotificationGroupItem({
    super.key,
    required this.notifications,
    required this.groupType,
    required this.summaryMessage,
    this.onTap,
    this.onDelete,
  });

  @override
  State<NotificationGroupItem> createState() => _NotificationGroupItemState();
}

class _NotificationGroupItemState extends State<NotificationGroupItem> {
  bool _isExpanded = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _unreadCount = widget.notifications.where((n) => n['is_read'] == false).length;
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  Color _getCategoryColor(String type) {
    if (type.contains('booking')) {
      return AppTheme.primaryColor; // Blue
    } else if (type.contains('payment')) {
      return Colors.green;
    } else if (type.contains('session')) {
      return Colors.purple;
    } else if (type.contains('message')) {
      return Colors.orange;
    }
    return AppTheme.textMedium;
  }

  IconData _getCategoryIcon(String type) {
    if (type.contains('booking')) {
      return Icons.book_online;
    } else if (type.contains('payment')) {
      return Icons.payment;
    } else if (type.contains('session')) {
      return Icons.access_time;
    } else if (type.contains('message')) {
      return Icons.chat;
    }
    return Icons.notifications;
  }

  Future<void> _markAllAsRead() async {
    for (final notification in widget.notifications) {
      if (notification['is_read'] == false) {
        await NotificationService.markAsRead(notification['id'] as String);
      }
    }
    setState(() {
      _unreadCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.notifications.length;
    final latestNotification = widget.notifications.first;
    final createdAt = DateTime.parse(latestNotification['created_at'] as String);
    final timeAgo = _getTimeAgo(createdAt);
    final categoryColor = _getCategoryColor(widget.groupType);
    final categoryIcon = _getCategoryIcon(widget.groupType);
    final hasUnread = _unreadCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasUnread
              ? categoryColor.withOpacity(0.3)
              : AppTheme.softBorder,
          width: hasUnread ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Group header (always visible)
          GestureDetector(
            onTap: () {
              if (widget.notifications.length == 1) {
                // Single notification - navigate directly
                final notification = widget.notifications.first;
                final actionUrl = notification['action_url'] as String?;
                final notificationType = notification['type'] as String?;
                final metadata = notification['metadata'] as Map<String, dynamic>?;
                if (actionUrl != null && actionUrl.isNotEmpty) {
                  NotificationNavigationService.navigateToAction(
                    context: context,
                    actionUrl: actionUrl,
                    notificationType: notificationType,
                    metadata: metadata,
                  );
                }
                widget.onTap?.call();
              } else {
                // Multiple notifications - toggle expand
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Center(
                      child: Icon(
                        categoryIcon,
                        size: 22,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.summaryMessage,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: hasUnread
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: AppTheme.textDark,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: categoryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              timeAgo,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.textLight,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$count ${count == 1 ? 'notification' : 'notifications'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: categoryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Expand/collapse icon
                  if (widget.notifications.length > 1)
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppTheme.textMedium,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
          // Expanded individual notifications
          if (_isExpanded && widget.notifications.length > 1)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.softBorder,
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Mark all as read button
                  if (_unreadCount > 0)
                    InkWell(
                      onTap: _markAllAsRead,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.done_all,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Mark all as read',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Individual notifications
                  ...widget.notifications.map(
                    (notification) => Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: AppTheme.softBorder,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: NotificationItem(
                        notification: notification,
                        onTap: () {
                          widget.onTap?.call();
                        },
                        onDelete: () {
                          widget.onDelete?.call();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

