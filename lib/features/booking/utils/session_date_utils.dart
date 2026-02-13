import '../models/trial_session_model.dart';

/// Utility class for session date/time operations
class SessionDateUtils {
  static final RegExp _timeRegex = RegExp(
    r'^\s*(\d{1,2})\s*:\s*(\d{2})(?:\s*:\s*(\d{2}))?\s*([AaPp][Mm])?\s*$',
  );

  static ({int hour, int minute}) _parseTimeToHourMinute(String time) {
    final trimmed = time.trim();

    // Quick path for common "HH:mm" / "HH:mm:ss"
    // (still supports whitespace and optional seconds via regex)
    final match = _timeRegex.firstMatch(trimmed);
    if (match == null) {
      // If parsing fails, fall back to 00:00 instead of throwing.
      return (hour: 0, minute: 0);
    }

    var hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final ampm = match.group(4)?.toUpperCase();

    // Normalize for 12-hour formats if AM/PM is present.
    if (ampm == 'PM' && hour != 12) {
      hour += 12;
    } else if (ampm == 'AM' && hour == 12) {
      hour = 0;
    }

    // Clamp to safe ranges.
    if (hour < 0) hour = 0;
    if (hour > 23) hour = hour % 24;
    final safeMinute = minute.clamp(0, 59);

    return (hour: hour, minute: safeMinute);
  }

  /// Get the session *start* DateTime (combines date and time).
  ///
  /// This was previously exposed as [getSessionDateTime]; that method now
  /// delegates to this helper for backwards compatibility.
  static DateTime getSessionStartTime(TrialSession session) {
    final date = session.scheduledDate;
    final parsed = _parseTimeToHourMinute(session.scheduledTime);
    return DateTime(date.year, date.month, date.day, parsed.hour, parsed.minute);
  }

  /// Get the full DateTime for a trial session (start time).
  ///
  /// Kept for backwards compatibility – callers that previously reasoned
  /// about "session time" continue to get the *start* of the session.
  static DateTime getSessionDateTime(TrialSession session) {
    return getSessionStartTime(session);
  }

  /// Get the session *end* DateTime, including a small grace period.
  ///
  /// We add a configurable [extraGrace] so that the system doesn't mark
  /// the session as "expired" at the exact theoretical end time while
  /// participants may still be wrapping up.
  static DateTime getSessionEndTime(
    TrialSession session, {
    Duration? extraGrace,
  }) {
    final start = getSessionStartTime(session);
    final duration = Duration(minutes: session.durationMinutes);
    final grace = extraGrace ?? const Duration(minutes: 5);
    return start.add(duration).add(grace);
  }

  /// Check if a session has expired (date/time has passed)
  static bool isSessionExpired(TrialSession session) {
    final endTime = getSessionEndTime(session);
    return DateTime.now().isAfter(endTime);
  }

  /// Check if a session is in the future
  static bool isSessionUpcoming(TrialSession session) {
    final sessionDateTime = getSessionStartTime(session);
    return sessionDateTime.isAfter(DateTime.now());
  }

  /// Check if a session is currently in progress (between start and end).
  ///
  /// This is useful when we want to distinguish between:
  /// - upcoming (hasn't started yet),
  /// - in‑progress (should show "View/Join Session"), and
  /// - fully past (eligible for "Reschedule").
  static bool isSessionInProgress(TrialSession session) {
    final now = DateTime.now();
    final start = getSessionStartTime(session);
    // Use end time *without* extra grace here; grace is only for expiry.
    final end = getSessionEndTime(session, extraGrace: Duration.zero);
    final hasStarted =
        now.isAfter(start) || now.isAtSameMomentAs(start);
    return hasStarted && now.isBefore(end);
  }

  /// Calculate payment deadline (default: 24 hours before session)
  static DateTime getPaymentDeadline(TrialSession session, {int hoursBefore = 24}) {
    final sessionDateTime = getSessionStartTime(session);
    return sessionDateTime.subtract(Duration(hours: hoursBefore));
  }

  /// Get time remaining until session as a formatted string
  static String getTimeUntilSession(TrialSession session) {
    final now = DateTime.now();
    
    if (isSessionExpired(session)) {
      return 'Expired';
    }

    if (isSessionInProgress(session)) {
      return 'In progress';
    }

    final sessionDateTime = getSessionStartTime(session);
    
    final difference = sessionDateTime.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Starting soon';
    }
  }

  /// Comprehensive check for whether to show "Pay Now" button
  /// 
  /// For trial sessions: Payment is ONLY allowed after tutor approval
  /// - Status must be 'approved' or 'scheduled' (NOT 'pending')
  /// - Payment status must be 'unpaid' or 'pending'
  /// - Session must be upcoming (not expired)
  static bool shouldShowPayNowButton(TrialSession session) {
    // CRITICAL: Do NOT show Pay Now for pending trial sessions
    // Trial sessions require tutor approval before payment
    if (session.status == 'pending') {
      return false;
    }
    
    // Only allow payment for approved or scheduled sessions
    if (session.status != 'approved' && session.status != 'scheduled') {
      return false;
    }
    
    // Don't show if payment is already completed
    final paymentStatus = session.paymentStatus.toLowerCase();
    if (paymentStatus == 'paid' || paymentStatus == 'completed') {
      return false;
    }
    
    // Don't show if session has expired
    if (isSessionExpired(session)) {
      return false;
    }
    
    // Don't show if session is cancelled
    if (session.status == 'cancelled' || session.status == 'expired') {
      return false;
    }
    
    // Show only if session is upcoming and payment is pending
    return isSessionUpcoming(session);
  }

  /// Check if payment deadline has passed
  static bool isPaymentDeadlinePassed(TrialSession session, {int hoursBefore = 24}) {
    final deadline = getPaymentDeadline(session, hoursBefore: hoursBefore);
    return deadline.isBefore(DateTime.now());
  }

  /// Get time remaining until payment deadline
  static Duration getTimeUntilPaymentDeadline(TrialSession session, {int hoursBefore = 24}) {
    final deadline = getPaymentDeadline(session, hoursBefore: hoursBefore);
    final now = DateTime.now();
    
    if (deadline.isBefore(now)) {
      return Duration.zero;
    }
    
    return deadline.difference(now);
  }
}
