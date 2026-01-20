import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Notification Analytics Service
/// 
/// Tracks user engagement with notifications:
/// - Notification opened (tap)
/// - Action button clicked
/// - Notification dismissed
/// - Time spent viewing
/// - Notification type engagement rates
class NotificationAnalyticsService {
  static final _supabase = SupabaseService.client;
  static String get _apiBaseUrl => AppConfig.effectiveApiBaseUrl;

  /// Track notification opened (when user taps notification)
  static Future<void> trackNotificationOpened({
    required String notificationId,
    required String notificationType,
    String? userId,
  }) async {
    try {
      final currentUserId = userId ?? _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        LogService.warning('Cannot track notification opened: user not authenticated');
        return;
      }

      // Store locally in Supabase for quick access
      await _supabase.from('notification_analytics').insert({
        'user_id': currentUserId,
        'notification_id': notificationId,
        'notification_type': notificationType,
        'event_type': 'opened',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Also send to API for aggregation
      try {
        await http.post(
          Uri.parse('$_apiBaseUrl/api/notifications/analytics'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'userId': currentUserId,
            'notificationId': notificationId,
            'notificationType': notificationType,
            'eventType': 'opened',
          }),
        );
      } catch (e) {
        // Fail silently - analytics are not critical
        LogService.warning('Failed to send analytics to API: $e');
      }

      LogService.success('Tracked notification opened: $notificationId');
    } catch (e) {
      LogService.error('Error tracking notification opened: $e');
      // Don't throw - analytics are not critical
    }
  }

  /// Track action button clicked
  static Future<void> trackActionClicked({
    required String notificationId,
    required String notificationType,
    required String actionUrl,
    String? userId,
  }) async {
    try {
      final currentUserId = userId ?? _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        LogService.warning('Cannot track action clicked: user not authenticated');
        return;
      }

      await _supabase.from('notification_analytics').insert({
        'user_id': currentUserId,
        'notification_id': notificationId,
        'notification_type': notificationType,
        'event_type': 'action_clicked',
        'metadata': {'action_url': actionUrl},
        'created_at': DateTime.now().toIso8601String(),
      });

      // Also send to API
      try {
        await http.post(
          Uri.parse('$_apiBaseUrl/api/notifications/analytics'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'userId': currentUserId,
            'notificationId': notificationId,
            'notificationType': notificationType,
            'eventType': 'action_clicked',
            'actionUrl': actionUrl,
          }),
        );
      } catch (e) {
        LogService.warning('Failed to send analytics to API: $e');
      }

      LogService.success('Tracked action clicked: $notificationId');
    } catch (e) {
      LogService.error('Error tracking action clicked: $e');
    }
  }

  /// Track notification dismissed
  static Future<void> trackNotificationDismissed({
    required String notificationId,
    required String notificationType,
    String? userId,
  }) async {
    try {
      final currentUserId = userId ?? _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return;
      }

      await _supabase.from('notification_analytics').insert({
        'user_id': currentUserId,
        'notification_id': notificationId,
        'notification_type': notificationType,
        'event_type': 'dismissed',
        'created_at': DateTime.now().toIso8601String(),
      });

      LogService.success('Tracked notification dismissed: $notificationId');
    } catch (e) {
      LogService.error('Error tracking notification dismissed: $e');
    }
  }

  /// Get user engagement stats for notification types
  /// Returns engagement rates per notification type
  static Future<Map<String, double>> getUserEngagementRates({
    String? userId,
    int days = 30,
  }) async {
    try {
      final currentUserId = userId ?? _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return {};
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      // Get all analytics events for user
      final response = await _supabase
          .from('notification_analytics')
          .select('notification_type, event_type')
          .eq('user_id', currentUserId)
          .gte('created_at', cutoffDate.toIso8601String());
      
      final events = (response as List).cast<Map<String, dynamic>>();

      if (events.isEmpty) {
        return {};
      }

      // Group by notification type
      final Map<String, List<String>> typeEvents = {};
      for (final event in events) {
        final type = event['notification_type'] as String? ?? 'general';
        typeEvents.putIfAbsent(type, () => []).add(event['event_type'] as String? ?? '');
      }

      // Calculate engagement rates (opens / total notifications of that type)
      final Map<String, double> engagementRates = {};
      for (final entry in typeEvents.entries) {
        final opens = entry.value.where((e) => e == 'opened').length;
        final total = entry.value.length;
        engagementRates[entry.key] = total > 0 ? opens / total : 0.0;
      }

      return engagementRates;
    } catch (e) {
      LogService.error('Error getting user engagement rates: $e');
      return {};
    }
  }
}

