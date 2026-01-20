import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/services/notification_navigation_service.dart';
import 'package:prepskul/core/services/notification_analytics_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Notification Item Widget
/// 
/// Displays a single notification with icon, title, message, timestamp, and actions
/// Timestamps update automatically every minute
class NotificationItem extends StatefulWidget {
  final Map<String, dynamic> notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const NotificationItem({
    super.key,
    required this.notification,
    this.onTap,
    this.onDelete,
  });

  @override
  State<NotificationItem> createState() => _NotificationItemState();
}

class _NotificationItemState extends State<NotificationItem> {
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    // Update timestamp more frequently for new notifications (every 10 seconds)
    // Then switch to every minute for older notifications
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        final createdAt = DateTime.tryParse(widget.notification['created_at'] as String? ?? '');
        if (createdAt != null) {
          final difference = DateTime.now().difference(createdAt);
          // For notifications less than 1 hour old, update every 10 seconds
          // For older notifications, update every minute (but we'll keep 10s for simplicity)
          setState(() {});
        }
      }
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  String _getIcon(String? type) {
    // Return empty string to remove emoji display
    // Icons will be handled by Material icons instead
    return '';
  }
  
  IconData _getIconData(String? type) {
    switch (type) {
      case 'booking_request':
      case 'booking_accepted':
      case 'booking_rejected':
        return PhosphorIcons.bookOpen();
      case 'trial_request':
      case 'trial_accepted':
      case 'trial_rejected':
        return PhosphorIcons.graduationCap();
      case 'payment_received':
      case 'payment_successful':
      case 'payment_failed':
        return PhosphorIcons.creditCard();
      case 'session_completed':
      case 'session_reminder':
      case 'session_starting_soon':
        return PhosphorIcons.clock();
      case 'profile_approved':
        return PhosphorIcons.checkCircle();
      case 'profile_rejected':
      case 'profile_improvement':
        return PhosphorIcons.pencil();
      case 'review_received':
        return PhosphorIcons.star();
      default:
        return PhosphorIcons.bell();
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
  
  /// Get border color based on priority
  Color _getPriorityBorderColor(String? priority, bool isRead) {
    if (isRead) {
      return AppTheme.softBorder;
    }
    switch (priority) {
      case 'urgent':
        return Colors.red.withOpacity(0.4);
      case 'high':
        return Colors.orange.withOpacity(0.3);
      case 'normal':
        return AppTheme.primaryColor.withOpacity(0.2);
      case 'low':
        return AppTheme.softBorder;
      default:
        return AppTheme.softBorder;
    }
  }
  
  /// Get border width based on priority
  double _getPriorityBorderWidth(String? priority, bool isRead) {
    if (isRead) {
      return 0.5;
    }
    switch (priority) {
      case 'urgent':
        return 2.0;
      case 'high':
        return 1.5;
      case 'normal':
        return 1.0;
      case 'low':
        return 0.5;
      default:
        return 0.5;
    }
  }

  /// Build user avatar with first letter or profile picture
  Widget _buildUserAvatar(
    Map<String, dynamic>? metadata,
    String? senderAvatarUrl,
    String? senderInitials,
    String priority,
  ) {
    // Extract sender name from metadata (tutor_name, student_name, or sender_name)
    final tutorName = metadata?['tutor_name'] as String?;
    final studentName = metadata?['student_name'] as String?;
    final senderName = metadata?['sender_name'] as String?;
    
    // Determine the sender name and initials
    String? displayName;
    String? displayInitials = senderInitials;
    
    if (tutorName != null && tutorName.isNotEmpty) {
      displayName = tutorName;
      displayInitials = tutorName[0].toUpperCase();
    } else if (studentName != null && studentName.isNotEmpty) {
      displayName = studentName;
      displayInitials = studentName[0].toUpperCase();
    } else if (senderName != null && senderName.isNotEmpty) {
      displayName = senderName;
      displayInitials = senderName[0].toUpperCase();
    }
    
    // If we have sender info, show avatar (even without profile pic)
    if (displayName != null || senderAvatarUrl != null || senderInitials != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primaryColor, // Deep blue background
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: senderAvatarUrl != null && senderAvatarUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: senderAvatarUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppTheme.primaryColor,
                    child: Center(
                      child: Text(
                        displayInitials ?? '?',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppTheme.primaryColor,
                    child: Center(
                      child: Text(
                        displayInitials ?? '?',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                )
              : Container(
                  color: AppTheme.primaryColor,
                  child: Center(
                    child: Text(
                      displayInitials ?? '?',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
      );
    }
    
    // No sender info - show Material icon with brand color background
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
      child: Center(
        child: Icon(
          _getIconData(widget.notification['type'] as String?),
          size: 22,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }


  /// Get enhanced message with user names for better context
  String _getEnhancedMessage(String? message, Map<String, dynamic>? metadata) {
    if (message == null || message.isEmpty) return '';
    
    // Extract user names from metadata
    final tutorName = metadata?['tutor_name'] as String?;
    final studentName = metadata?['student_name'] as String?;
    final senderName = metadata?['sender_name'] as String?;
    
    // If message already contains the name, return as is
    if (tutorName != null && message.contains(tutorName)) {
      return message;
    }
    if (studentName != null && message.contains(studentName)) {
      return message;
    }
    if (senderName != null && message.contains(senderName)) {
      return message;
    }
    
    // For specific notification types, enhance the message
    final type = widget.notification['type'] as String?;
    
    // Trial-related notifications
    if (type == 'trial_accepted' && tutorName != null) {
      return 'Your trial request with $tutorName has been approved. Tap to view details and pay.';
    }
    if (type == 'trial_rejected' && tutorName != null) {
      return '$tutorName has declined your trial request. Tap to find another tutor.';
    }
    if (type == 'trial_request' && studentName != null) {
      return '$studentName wants to book a trial session. Tap to review and respond.';
    }
    
    // Booking-related notifications
    if (type == 'booking_accepted' && tutorName != null) {
      return 'Your booking request with $tutorName has been approved. Tap to view details.';
    }
    if (type == 'booking_rejected' && tutorName != null) {
      return '$tutorName has declined your booking request. Tap to find another tutor.';
    }
    if (type == 'booking_request' && studentName != null) {
      return '$studentName wants to book sessions. Tap to review and respond.';
    }
    
    // Payment notifications
    if (type == 'payment_received' && studentName != null) {
      return 'Payment received from $studentName. Tap to view details.';
    }
    if (type == 'payment_request_paid' && tutorName != null) {
      return 'Your payment to $tutorName has been confirmed. Tap to view booking.';
    }
    
    // Return original message if no enhancement needed
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final isRead = widget.notification['is_read'] == true;
    final title = widget.notification['title'] as String? ?? 'Notification';
    final message = widget.notification['message'] as String? ?? '';
    final createdAt = DateTime.parse(widget.notification['created_at'] as String);
    final timeAgo = _getTimeAgo(createdAt);
    final priority = widget.notification['priority'] as String? ?? 'normal';
    final actionText = widget.notification['action_text'] as String?;
    final actionUrl = widget.notification['action_url'] as String?;

    // Extract metadata for avatar and image preview
    final metadata = widget.notification['metadata'] as Map<String, dynamic>?;
    final senderAvatarUrl = metadata?['sender_avatar_url'] as String?;
    final senderInitials = metadata?['sender_initials'] as String?;
    final imageUrl = widget.notification['image_url'] as String? ?? 
                     metadata?['image_url'] as String?;

    return Dismissible(
      key: Key(widget.notification['id'] as String),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          PhosphorIcons.trash(),
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) async {
        await NotificationService.deleteNotification(widget.notification['id'] as String);
        widget.onDelete?.call();
      },
      child: InkWell(
        onTap: () {
          final notificationId = widget.notification['id'] as String;
          final notificationType = widget.notification['type'] as String? ?? 'general';
          
          // Track analytics
          NotificationAnalyticsService.trackNotificationOpened(
            notificationId: notificationId,
            notificationType: notificationType,
          );
          
          if (!isRead) {
            NotificationService.markAsRead(notificationId);
          }
          
          // Navigate to action URL if it exists
          if (actionUrl != null && actionUrl.isNotEmpty) {
            NotificationNavigationService.navigateToAction(
              context: context,
              actionUrl: actionUrl,
              notificationType: notificationType,
              metadata: metadata,
            );
          }
          
          widget.onTap?.call();
        },
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                // Subtle background color difference: light grey for read, white for unread
                color: isRead ? Colors.grey[50] : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isRead 
                      ? Colors.grey[200]! 
                      : _getPriorityBorderColor(priority, isRead),
                  width: isRead ? 0.5 : _getPriorityBorderWidth(priority, isRead),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isRead ? 0.01 : 0.03),
                    blurRadius: isRead ? 2 : 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Avatar (always show if sender info available, otherwise show icon)
                _buildUserAvatar(metadata, senderAvatarUrl, senderInitials, priority),
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
                                fontSize: 13,
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                                color: AppTheme.textDark,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _getEnhancedMessage(message, metadata),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textMedium,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Image preview (if available)
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 150,
                              color: AppTheme.softBackground,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 150,
                              color: AppTheme.softBackground,
                              child: Icon(
                                PhosphorIcons.imageSquare(),
                                color: AppTheme.textLight,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        timeAgo,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
            // Subtle left border indicator for unread (like Facebook/LinkedIn)
            if (!isRead)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
