import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Notification Item Widget
/// 
/// Displays a single notification with icon, title, message, timestamp, and actions
class NotificationItem extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const NotificationItem({
    super.key,
    required this.notification,
    this.onTap,
    this.onDelete,
  });

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

  String _getIcon(String? type) {
    switch (type) {
      case 'booking_request':
      case 'booking_accepted':
      case 'booking_rejected':
        return '🎓';
      case 'trial_request':
      case 'trial_accepted':
      case 'trial_rejected':
        return '🎯';
      case 'payment_received':
      case 'payment_successful':
      case 'payment_failed':
        return '💰';
      case 'session_completed':
      case 'session_reminder':
      case 'session_starting_soon':
        return '⏰';
      case 'profile_approved':
        return '🎉';
      case 'profile_rejected':
      case 'profile_improvement':
        return '📝';
      case 'review_received':
        return '⭐';
      default:
        return '🔔';
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return AppTheme.primaryColor;
      case 'low':
        return AppTheme.textMedium;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] == true;
    final icon = notification['icon'] as String? ?? _getIcon(notification['type'] as String?);
    final title = notification['title'] as String? ?? 'Notification';
    final message = notification['message'] as String? ?? '';
    final createdAt = DateTime.parse(notification['created_at'] as String);
    final timeAgo = _getTimeAgo(createdAt);
    final priority = notification['priority'] as String? ?? 'normal';
    final actionText = notification['action_text'] as String?;

    // Extract metadata for avatar
    final metadata = notification['metadata'] as Map<String, dynamic>?;
    final senderAvatarUrl = metadata?['sender_avatar_url'] as String?;
    final senderInitials = metadata?['sender_initials'] as String?;

    return Dismissible(
      key: Key(notification['id'] as String),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) async {
        await NotificationService.deleteNotification(notification['id'] as String);
        onDelete?.call();
      },
      child: GestureDetector(
        onTap: () {
          if (!isRead) {
            NotificationService.markAsRead(notification['id'] as String);
          }
          onTap?.call();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isRead ? AppTheme.softBorder : _getPriorityColor(priority).withOpacity(0.2),
              width: isRead ? 0.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon or Avatar
              if (senderAvatarUrl != null || senderInitials != null)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getPriorityColor(priority).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: senderAvatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: senderAvatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: _getPriorityColor(priority).withOpacity(0.08),
                              child: Center(
                                child: Text(
                                  senderInitials ?? icon,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: _getPriorityColor(priority).withOpacity(0.08),
                              child: Center(
                                child: Text(
                                  senderInitials ?? icon,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: _getPriorityColor(priority).withOpacity(0.08),
                            child: Center(
                              child: Text(
                                senderInitials ?? icon,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: _getPriorityColor(priority),
                                ),
                              ),
                            ),
                          ),
                  ),
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getPriorityColor(priority).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _getPriorityColor(priority).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      icon,
                      style: const TextStyle(fontSize: 20),
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
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textMedium,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          timeAgo,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textLight,
                          ),
                        ),
                        if (actionText != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              actionText,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
