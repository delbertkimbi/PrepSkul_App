import 'package:intl/intl.dart';

/// Shared on-site presence window and messaging (1h before start → 2h after start).
class OnsitePresenceUtils {
  static const Duration beforeStart = Duration(hours: 1);
  static const Duration afterStart = Duration(hours: 2);

  static DateTime? windowStart(DateTime? scheduledStart) {
    if (scheduledStart == null) return null;
    return scheduledStart.subtract(beforeStart);
  }

  static DateTime? windowEnd(DateTime? scheduledStart) {
    if (scheduledStart == null) return null;
    return scheduledStart.add(afterStart);
  }

  static bool isWithinPresenceWindow(DateTime? scheduledStart) {
    if (scheduledStart == null) return false;
    final now = DateTime.now();
    final start = windowStart(scheduledStart)!;
    final end = windowEnd(scheduledStart)!;
    return !now.isBefore(start) && now.isBefore(end);
  }

  static String windowLabel(DateTime? scheduledStart) {
    if (scheduledStart == null) {
      return 'Check-in opens 1 hour before start and closes 2 hours after start.';
    }
    final start = windowStart(scheduledStart)!;
    final end = windowEnd(scheduledStart)!;
    final fmt = DateFormat('EEE, MMM d · h:mm a');
    return 'Check-in window: ${fmt.format(start)} – ${fmt.format(end)}';
  }

  /// User-facing reason when check-in is blocked (not geocoding).
  static String? checkInBlockedMessage(DateTime? scheduledStart) {
    if (scheduledStart == null) {
      return 'Session time is missing. Please contact support.';
    }
    final now = DateTime.now();
    final open = windowStart(scheduledStart)!;
    final close = windowEnd(scheduledStart)!;
    final fmt = DateFormat('h:mm a on EEE, MMM d');

    if (now.isBefore(open)) {
      return 'Check-in opens at ${fmt.format(open)} (1 hour before the session starts). '
          'You cannot check in yet for this session.';
    }
    if (!now.isBefore(close)) {
      return 'The check-in window closed at ${fmt.format(close)} (2 hours after session start). '
          'Contact support if you need help recording attendance.';
    }
    return null;
  }
}
