import 'package:prepskul/core/services/supabase_service.dart';
import 'dart:async';

/// NotificationService
///
/// Handles creating and managing in-app notifications
/// Supports real-time updates, preferences, and scheduled notifications
class NotificationService {
  static final _supabase = SupabaseService.client;
  static StreamSubscription? _notificationStream;

  /// Create a notification for a user
  ///
  /// [priority] can be 'low', 'normal', 'high', or 'urgent'
  /// [actionUrl] is a deep link to related content (e.g., '/bookings/123')
  /// [actionText] is the text for the action button (e.g., 'View Booking')
  /// [icon] is an emoji or icon name (e.g., '🎓', 'booking')
  /// [expiresAt] is when the notification should be auto-deleted (optional)
  /// [metadata] contains additional data like session_id, booking_id, etc.
  static Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    String priority = 'normal',
    String? actionUrl,
    String? actionText,
    String? icon,
    DateTime? expiresAt,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notificationData = {
        'user_id': userId,
        'type': type,
        'notification_type': type, // For backward compatibility
        'title': title,
        'message': message,
        'data': data,
        'metadata': metadata,
        'priority': priority,
        'action_url': actionUrl,
        'action_text': actionText,
        'icon': icon,
        'expires_at': expiresAt?.toIso8601String(),
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Remove null values
      notificationData.removeWhere((key, value) => value == null);

      await _supabase.from('notifications').insert(notificationData);
      print('✅ Notification created for user: $userId, type: $type');
    } catch (e) {
      print('❌ Error creating notification: $e');
      // Don't throw - notifications are not critical
    }
  }

  /// Get all notifications for current user
  static Future<List<Map<String, dynamic>>> getUserNotifications({
    bool? unreadOnly,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      var query = _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId);

      if (unreadOnly == true) {
        query = query.eq('is_read', false);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for current user
  static Future<void> markAllAsRead() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
    }
  }

  /// Get unread notification count
  static Future<int> getUnreadCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return 0;
      }

      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  /// Get real-time stream of notifications for current user
  ///
  /// Automatically updates when new notifications are created or updated
  /// Remember to cancel the stream when done: stream.cancel()
  static Stream<List<Map<String, dynamic>>> watchNotifications({
    bool unreadOnly = false,
  }) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
          final notifications = (data as List).cast<Map<String, dynamic>>();

          // Filter by unread if requested
          final filtered = unreadOnly
              ? notifications.where((n) => n['is_read'] == false).toList()
              : notifications;

          // Sort by created_at descending
          filtered.sort((a, b) {
            try {
              final aTime = DateTime.parse(a['created_at'] ?? '');
              final bTime = DateTime.parse(b['created_at'] ?? '');
              return bTime.compareTo(aTime);
            } catch (e) {
              return 0;
            }
          });

          return filtered;
        });
  }

  /// Schedule a notification for future delivery
  ///
  /// Used for reminders (e.g., session starting in 30 minutes)
  static Future<void> scheduleNotification({
    required String userId,
    required String notificationType,
    required String title,
    required String message,
    required DateTime scheduledFor,
    String? relatedId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final scheduledData = {
        'user_id': userId,
        'notification_type': notificationType,
        'title': title,
        'message': message,
        'scheduled_for': scheduledFor.toIso8601String(),
        'status': 'pending',
        'related_id': relatedId,
        'metadata': metadata,
      };

      await _supabase.from('scheduled_notifications').insert(scheduledData);
      print(
        '✅ Notification scheduled for user: $userId, scheduled for: $scheduledFor',
      );
    } catch (e) {
      print('❌ Error scheduling notification: $e');
    }
  }

  /// Get notification preferences for current user
  static Future<Map<String, dynamic>?> getPreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return null;
      }

      // Use the database function to get or create preferences
      final response = await _supabase.rpc(
        'get_or_create_notification_preferences',
        params: {'p_user_id': userId},
      );

      return response as Map<String, dynamic>?;
    } catch (e) {
      print('❌ Error getting notification preferences: $e');
      return null;
    }
  }

  /// Update notification preferences for current user
  static Future<void> updatePreferences({
    bool? emailEnabled,
    bool? inAppEnabled,
    bool? pushEnabled,
    Map<String, dynamic>? typePreferences,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? digestEnabled,
    String? digestFrequency,
    String? digestTime,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Ensure preferences exist
      await getPreferences();

      final updates = <String, dynamic>{};
      if (emailEnabled != null) updates['email_enabled'] = emailEnabled;
      if (inAppEnabled != null) updates['in_app_enabled'] = inAppEnabled;
      if (pushEnabled != null) updates['push_enabled'] = pushEnabled;
      if (typePreferences != null)
        updates['type_preferences'] = typePreferences;
      if (quietHoursStart != null)
        updates['quiet_hours_start'] = quietHoursStart;
      if (quietHoursEnd != null) updates['quiet_hours_end'] = quietHoursEnd;
      if (digestEnabled != null) updates['digest_enabled'] = digestEnabled;
      if (digestFrequency != null)
        updates['digest_frequency'] = digestFrequency;
      if (digestTime != null) updates['digest_time'] = digestTime;

      await _supabase
          .from('notification_preferences')
          .update(updates)
          .eq('user_id', userId);

      print('✅ Notification preferences updated');
    } catch (e) {
      print('❌ Error updating notification preferences: $e');
      rethrow;
    }
  }

  /// Check if a notification should be sent based on user preferences
  ///
  /// This is typically called server-side, but can be used client-side for UI hints
  static Future<bool> shouldSendNotification({
    required String notificationType,
    required String channel, // 'email' or 'in_app'
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return true; // Default to sending if not authenticated
      }

      final response = await _supabase.rpc(
        'should_send_notification',
        params: {
          'p_user_id': userId,
          'p_notification_type': notificationType,
          'p_channel': channel,
        },
      );

      return response as bool? ?? true;
    } catch (e) {
      print('❌ Error checking notification preference: $e');
      return true; // Default to sending on error
    }
  }

  /// Cancel a scheduled notification
  static Future<void> cancelScheduledNotification(
    String scheduledNotificationId,
  ) async {
    try {
      await _supabase
          .from('scheduled_notifications')
          .update({'status': 'cancelled'})
          .eq('id', scheduledNotificationId);
      print('✅ Scheduled notification cancelled: $scheduledNotificationId');
    } catch (e) {
      print('❌ Error cancelling scheduled notification: $e');
    }
  }

  /// Get scheduled notifications for current user
  static Future<List<Map<String, dynamic>>> getScheduledNotifications({
    String? status, // 'pending', 'sent', 'cancelled', 'failed'
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return [];
      }

      var query = _supabase
          .from('scheduled_notifications')
          .select()
          .eq('user_id', userId);

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('scheduled_for', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error getting scheduled notifications: $e');
      return [];
    }
  }

  /// Cleanup: Cancel the notification stream
  static void dispose() {
    _notificationStream?.cancel();
    _notificationStream = null;
  }
}
