import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/auth_service.dart' hide LogService;
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// NotificationService
///
/// Handles creating and managing in-app notifications
/// Supports real-time updates, preferences, and scheduled notifications
class NotificationService {
  static final _supabase = SupabaseService.client;

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
      LogService.success('Notification created for user: $userId, type: $type');
    } catch (e) {
      LogService.error('Error creating notification: $e');
      // Don't throw - notifications are not critical
    }
  }

  /// Calculate smart priority score for a notification
  /// Higher score = higher priority
  static double _calculatePriorityScore(Map<String, dynamic> notification) {
    double score = 0.0;
    
    // Base priority from database
    final priority = notification['priority'] as String? ?? 'normal';
    switch (priority) {
      case 'urgent':
        score += 100;
        break;
      case 'high':
        score += 50;
        break;
      case 'normal':
        score += 25;
        break;
      case 'low':
        score += 10;
        break;
    }
    
    // Type-based priority
    final type = notification['type'] as String? ?? 'general';
    if (type.contains('payment') || type.contains('payout')) {
      score += 40; // Payments are high priority
    } else if (type.contains('session_starting') || type.contains('session_reminder')) {
      score += 35; // Session reminders are time-sensitive
    } else if (type.contains('booking_request')) {
      score += 30; // Booking requests need quick response
    } else if (type.contains('message') || type.contains('chat')) {
      score += 20; // Messages are moderately important
    } else if (type.contains('profile_approved')) {
      score += 25; // Profile approval is important
    }
    
    // Time sensitivity
    final createdAt = DateTime.parse(notification['created_at'] as String);
    final now = DateTime.now();
    final ageInHours = now.difference(createdAt).inHours;
    
    if (ageInHours < 1) {
      score += 20; // Very recent = higher priority
    } else if (ageInHours < 6) {
      score += 10; // Recent = moderate boost
    } else if (ageInHours > 48) {
      score -= 10; // Old = lower priority
    }
    
    // Unread boost
    if (notification['is_read'] == false) {
      score += 15; // Unread notifications are more important
    }
    
    // Action URL boost (actionable notifications are more important)
    if (notification['action_url'] != null && 
        (notification['action_url'] as String).isNotEmpty) {
      score += 10;
    }
    
    return score;
  }

  /// Get all notifications for current user
  /// Filters out tutor-specific notifications for non-tutor users
  /// Sorts by smart priority score
  static Future<List<Map<String, dynamic>>> getUserNotifications({
    bool? unreadOnly,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get user role to filter tutor-specific notifications
      final userRole = await AuthService.getUserRole();

      var query = _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId);

      if (unreadOnly == true) {
        query = query.eq('is_read', false);
      }

      final response = await query.order('created_at', ascending: false);
      var notifications = (response as List).cast<Map<String, dynamic>>();

      // Check if user is admin
      final profile = await _supabase
          .from('profiles')
          .select('is_admin, user_type')
          .eq('id', userId)
          .maybeSingle();
      final isAdmin = profile?['is_admin'] as bool? ?? false;
      final userType = profile?['user_type'] as String?;
      final isAdminUser = isAdmin || userType == 'admin';

      // Filter out tutor-specific notifications for non-tutor users
      if (userRole != 'tutor') {
        final tutorSpecificTypes = [
          'profile_approved',
          'profile_rejected',
          'profile_improvement',
          'profile_complete', // Profile completion notifications
        ];
        
        notifications = notifications.where((notification) {
          final type = notification['type'] as String?;
          // Check if notification title/message contains tutor-specific content
          final title = (notification['title'] as String? ?? '').toLowerCase();
          final message = (notification['message'] as String? ?? '').toLowerCase();
          
          // Filter out tutor-specific notification types
          if (type != null && tutorSpecificTypes.contains(type)) {
            return false;
          }
          
          // Filter out notifications with tutor-specific keywords
          final tutorKeywords = [
            'tutor profile',
            'complete your profile to get verified',
            'connect with students',
            'become visible',
            'tutor onboarding',
          ];
          
          final hasTutorKeyword = tutorKeywords.any((keyword) => 
            title.contains(keyword) || message.contains(keyword)
          );
          
          return !hasTutorKeyword;
        }).toList();
      }

      // Filter out admin-specific notifications for non-admin users
      if (!isAdminUser) {
        final adminSpecificTypes = [
          'user_signup',
          'tutor_request',
          'tutor_request_matched',
          'tutor_request_updated',
          'tutor_request_deleted',
          'tutor_request_status_changed',
        ];
        
        notifications = notifications.where((notification) {
          final type = notification['type'] as String?;
          final title = (notification['title'] as String? ?? '').toLowerCase();
          final message = (notification['message'] as String? ?? '').toLowerCase();
          final actionUrl = (notification['action_url'] as String? ?? '').toLowerCase();
          
          // Filter out admin-specific notification types
          if (type != null && adminSpecificTypes.contains(type)) {
            return false;
          }
          
          // Filter out notifications with admin-specific keywords
          final adminKeywords = [
            'new user signup',
            'tutor request',
            'has submitted a new tutor request',
            'has completed their survey',
          ];
          
          final hasAdminKeyword = adminKeywords.any((keyword) => 
            title.contains(keyword) || message.contains(keyword)
          );
          
          // Filter out notifications with admin action URLs
          final hasAdminActionUrl = actionUrl.contains('/admin/');
          
          return !hasAdminKeyword && !hasAdminActionUrl;
        }).toList();
      }

      // Calculate priority scores and sort by them (highest first)
      final notificationsWithScores = notifications.map((notification) {
        final score = _calculatePriorityScore(notification);
        return {
          ...notification,
          '_priority_score': score,
        };
      }).toList();
      
      // Sort by priority score (descending), then by created_at (descending)
      notificationsWithScores.sort((a, b) {
        final scoreA = a['_priority_score'] as double;
        final scoreB = b['_priority_score'] as double;
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA); // Higher score first
        }
        // If scores are equal, sort by time (newest first)
        final timeA = DateTime.parse(a['created_at'] as String);
        final timeB = DateTime.parse(b['created_at'] as String);
        return timeB.compareTo(timeA);
      });
      
      // Remove the temporary score field before returning
      return notificationsWithScores.map((notification) {
        final Map<String, dynamic> cleaned = Map.from(notification);
        cleaned.remove('_priority_score');
        return cleaned;
      }).toList();
    } catch (e) {
      LogService.error('Error fetching notifications: $e');
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  /// Get notifications for current user with pagination
  /// 
  /// [limit] - Number of notifications to fetch (default: 20)
  /// [offset] - Number of notifications to skip (default: 0)
  /// [unreadOnly] - Filter to only unread notifications
  /// 
  /// Returns a map with 'notifications' list and 'hasMore' boolean
  static Future<Map<String, dynamic>> getUserNotificationsPaginated({
    int limit = 20,
    int offset = 0,
    bool? unreadOnly,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get user role to filter tutor-specific notifications
      final userRole = await AuthService.getUserRole();

      // Check if user is admin
      final profile = await _supabase
          .from('profiles')
          .select('is_admin, user_type')
          .eq('id', userId)
          .maybeSingle();
      final isAdmin = profile?['is_admin'] as bool? ?? false;
      final userType = profile?['user_type'] as String?;
      final isAdminUser = isAdmin || userType == 'admin';

      var query = _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId);

      if (unreadOnly == true) {
        query = query.eq('is_read', false);
      }

      // Apply ordering, limit, and offset
      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      
      var notifications = (response as List).cast<Map<String, dynamic>>();

      // Filter out tutor-specific notifications for non-tutor users
      if (userRole != 'tutor') {
        final tutorSpecificTypes = [
          'profile_approved',
          'profile_rejected',
          'profile_improvement',
          'profile_complete',
        ];
        
        notifications = notifications.where((notification) {
          final type = notification['type'] as String?;
          final title = (notification['title'] as String? ?? '').toLowerCase();
          final message = (notification['message'] as String? ?? '').toLowerCase();
          
          if (type != null && tutorSpecificTypes.contains(type)) {
            return false;
          }
          
          final tutorKeywords = [
            'tutor profile',
            'complete your profile to get verified',
            'connect with students',
            'become visible',
            'tutor onboarding',
          ];
          
          final hasTutorKeyword = tutorKeywords.any((keyword) => 
            title.contains(keyword) || message.contains(keyword)
          );
          
          return !hasTutorKeyword;
        }).toList();
      }

      // Filter out admin-specific notifications for non-admin users
      if (!isAdminUser) {
        final adminSpecificTypes = [
          'user_signup',
          'tutor_request',
          'tutor_request_matched',
          'tutor_request_updated',
          'tutor_request_deleted',
          'tutor_request_status_changed',
        ];
        
        notifications = notifications.where((notification) {
          final type = notification['type'] as String?;
          final title = (notification['title'] as String? ?? '').toLowerCase();
          final message = (notification['message'] as String? ?? '').toLowerCase();
          final actionUrl = (notification['action_url'] as String? ?? '').toLowerCase();
          
          // Filter out admin-specific notification types
          if (type != null && adminSpecificTypes.contains(type)) {
            return false;
          }
          
          // Filter out notifications with admin-specific keywords
          final adminKeywords = [
            'new user signup',
            'tutor request',
            'has submitted a new tutor request',
            'has completed their survey',
          ];
          
          final hasAdminKeyword = adminKeywords.any((keyword) => 
            title.contains(keyword) || message.contains(keyword)
          );
          
          // Filter out notifications with admin action URLs
          final hasAdminActionUrl = actionUrl.contains('/admin/');
          
          return !hasAdminKeyword && !hasAdminActionUrl;
        }).toList();
      }

      // Calculate priority scores and sort by them (highest first)
      final notificationsWithScores = notifications.map((notification) {
        final score = _calculatePriorityScore(notification);
        return {
          ...notification,
          '_priority_score': score,
        };
      }).toList();
      
      // Sort by priority score (descending), then by created_at (descending)
      notificationsWithScores.sort((a, b) {
        final scoreA = a['_priority_score'] as double;
        final scoreB = b['_priority_score'] as double;
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA); // Higher score first
        }
        // If scores are equal, sort by time (newest first)
        final timeA = DateTime.parse(a['created_at'] as String);
        final timeB = DateTime.parse(b['created_at'] as String);
        return timeB.compareTo(timeA);
      });
      
      // Remove the temporary score field before returning
      final sortedNotifications = notificationsWithScores.map((notification) {
        final Map<String, dynamic> cleaned = Map.from(notification);
        cleaned.remove('_priority_score');
        return cleaned;
      }).toList();

      // Check if there are more notifications
      final hasMore = sortedNotifications.length == limit;

      return {
        'notifications': sortedNotifications,
        'hasMore': hasMore,
      };
    } catch (e) {
      LogService.error('Error fetching notifications: $e');
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
      LogService.error('Error marking notification as read: $e');
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
      LogService.error('Error marking all notifications as read: $e');
    }
  }

  /// Get unread notification count for current user
  static Future<int> getUnreadCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return 0;
      }

      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      LogService.error('Error getting unread count: $e');
      return 0;
    }
  }

  /// Watch notifications in real-time
  /// Returns a stream of notifications for the current user
  /// Uses Realtime subscription to listen for changes
  static Stream<List<Map<String, dynamic>>> watchNotifications({
    bool unreadOnly = false,
  }) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    // Create a controller for the stream
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    
    // Initial load
    getUserNotifications(unreadOnly: unreadOnly).then((notifications) {
      if (!controller.isClosed) {
        controller.add(notifications);
      }
    });

    // Subscribe to Realtime changes
    final channel = _supabase.channel('notifications_$userId');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        // Refresh notifications when changes occur
        getUserNotifications(unreadOnly: unreadOnly).then((notifications) {
          if (!controller.isClosed) {
            controller.add(notifications);
          }
        });
      },
    ).subscribe();

    // Clean up when stream is cancelled
    controller.onCancel = () {
      channel.unsubscribe();
    };

    return controller.stream;
  }

  /// Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      LogService.error('Error deleting notification: $e');
    }
  }

  /// Delete all notifications for current user
  static Future<void> deleteAllNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      LogService.error('Error deleting all notifications: $e');
    }
  }

  /// Get notification preferences for current user
  /// Returns a map with preference settings or null if not set
  static Future<Map<String, dynamic>?> getPreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Try to get preferences from user_profiles or a preferences table
      // For now, we'll use user_profiles and add a preferences JSON column
      // If that doesn't exist, we'll return default preferences
      try {
        final response = await _supabase
            .from('user_profiles')
            .select('notification_preferences')
            .eq('id', userId)
            .maybeSingle();

        if (response != null && response['notification_preferences'] != null) {
          return Map<String, dynamic>.from(response['notification_preferences'] as Map);
        }
      } catch (e) {
        LogService.debug('Notification preferences not found in user_profiles: $e');
      }

      // Return default preferences if none found
      return {
        'email_enabled': true,
        'in_app_enabled': true,
        'push_enabled': true,
      };
    } catch (e) {
      LogService.error('Error getting notification preferences: $e');
      // Return default preferences on error
      return {
        'email_enabled': true,
        'in_app_enabled': true,
        'push_enabled': true,
      };
    }
  }

  /// Update notification preferences for current user
  static Future<void> updatePreferences({
    required bool emailEnabled,
    required bool inAppEnabled,
    required bool pushEnabled,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final preferences = {
        'email_enabled': emailEnabled,
        'in_app_enabled': inAppEnabled,
        'push_enabled': pushEnabled,
      };

      // Try to update in user_profiles
      try {
      await _supabase
            .from('user_profiles')
            .update({
              'notification_preferences': preferences,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);
        
        LogService.success('Notification preferences updated for user: $userId');
      } catch (e) {
        // If user_profiles doesn't have notification_preferences column,
        // we'll need to create a separate preferences table or handle it differently
        LogService.warning('Could not update preferences in user_profiles: $e');
        // For now, we'll just log - in production, you'd want to create a preferences table
        throw Exception('Notification preferences update not supported yet. Please create a notification_preferences table or add notification_preferences column to user_profiles.');
      }
    } catch (e) {
      LogService.error('Error updating notification preferences: $e');
      rethrow;
    }
  }
}