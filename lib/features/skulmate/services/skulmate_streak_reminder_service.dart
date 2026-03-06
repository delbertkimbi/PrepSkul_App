import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/push_notification_service.dart';
import 'game_stats_service.dart';

/// Service for scheduling daily streak reminder notifications.
/// Uses local notifications; does not require backend.
class SkulMateStreakReminderService {
  static const String _enabledKey = 'skulmate_streak_reminder_enabled';
  static const String _hourKey = 'skulmate_streak_reminder_hour';
  static const String _minuteKey = 'skulmate_streak_reminder_minute';
  static const int _defaultHour = 18; // 6 PM
  static const int _defaultMinute = 0;

  /// Whether streak reminder is enabled
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  /// Set enabled state
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (enabled) {
      await rescheduleIfNeeded();
    } else {
      await PushNotificationService().cancelSkulMateStreakReminder();
    }
  }

  /// Get reminder time (hour 0-23, minute 0-59)
  static Future<({int hour, int minute})> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hour: prefs.getInt(_hourKey) ?? _defaultHour,
      minute: prefs.getInt(_minuteKey) ?? _defaultMinute,
    );
  }

  /// Set reminder time
  static Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, hour.clamp(0, 23));
    await prefs.setInt(_minuteKey, minute.clamp(0, 59));
    if (await isEnabled()) {
      await rescheduleIfNeeded();
    }
  }

  /// Reschedule the daily reminder if needed.
  /// Call on app open when user enters skulMate, or after game completion.
  /// - If user played today and has streak: optionally skip today's reminder.
  /// - If enabled and not played today: schedule for configured time.
  static Future<void> rescheduleIfNeeded() async {
    if (kIsWeb) return;

    try {
      final enabled = await isEnabled();
      if (!enabled) return;

      final stats = await GameStatsService.getStats();
      if (stats.currentStreak <= 0) return;

      final now = DateTime.now();
      final lastPlayed = stats.lastPlayedDate;
      final playedToday = lastPlayed != null &&
          lastPlayed.year == now.year &&
          lastPlayed.month == now.month &&
          lastPlayed.day == now.day;

      if (playedToday) {
        await PushNotificationService().cancelSkulMateStreakReminder();
        LogService.debug('🔥 [StreakReminder] User played today - reminder cancelled');
        return;
      }

      final time = await getReminderTime();
      await PushNotificationService().scheduleSkulMateStreakReminder(
        hour: time.hour,
        minute: time.minute,
        streakCount: stats.currentStreak,
      );
      LogService.info('🔥 [StreakReminder] Scheduled for ${time.hour}:${time.minute.toString().padLeft(2, '0')}');
    } catch (e) {
      LogService.warning('🔥 [StreakReminder] Error rescheduling: $e');
    }
  }

}
