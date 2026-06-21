import 'skulmate_streak_reminder_service.dart';

/// Hook called when user completes a game — reschedule from tomorrow.
/// Used by GameStatsService to avoid circular imports.
void onSkulMateGameCompleted() {
  SkulMateStreakReminderService.recordActivityAndReschedule();
}
