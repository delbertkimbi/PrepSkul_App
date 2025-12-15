import '../models/trial_session_model.dart';

/// Utility class for session date/time operations
class SessionDateUtils {
  /// Get the full DateTime for a trial session (combines date and time)
  static DateTime getSessionDateTime(TrialSession session) {
    final date = session.scheduledDate;
    final timeParts = session.scheduledTime.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Check if a session has expired (date/time has passed)
  static bool isSessionExpired(TrialSession session) {
    final sessionDateTime = getSessionDateTime(session);
    return sessionDateTime.isBefore(DateTime.now());
  }

  /// Check if a session is in the future
  static bool isSessionUpcoming(TrialSession session) {
    final sessionDateTime = getSessionDateTime(session);
    return sessionDateTime.isAfter(DateTime.now());
  }

  /// Calculate payment deadline (default: 24 hours before session)
  static DateTime getPaymentDeadline(TrialSession session, {int hoursBefore = 24}) {
    final sessionDateTime = getSessionDateTime(session);
    return sessionDateTime.subtract(Duration(hours: hoursBefore));
  }

  /// Get time remaining until session as a formatted string
  static String getTimeUntilSession(TrialSession session) {
    final sessionDateTime = getSessionDateTime(session);
    final now = DateTime.now();
    
    if (sessionDateTime.isBefore(now)) {
      return 'Expired';
    }
    
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
