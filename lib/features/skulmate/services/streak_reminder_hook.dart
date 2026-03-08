import 'package:prepskul/core/services/push_notification_service.dart';

/// Hook called when user completes a game - cancels today's streak reminder.
/// Used by GameStatsService to avoid circular imports.
void onSkulMateGameCompleted() {
  PushNotificationService().cancelSkulMateStreakReminder();
}
