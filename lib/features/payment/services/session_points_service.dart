import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/booking/services/individual_session_service.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart';
import 'package:prepskul/features/booking/utils/session_date_utils.dart';

/// Session Points Service
///
/// Business rule:
/// - 1 paid/upcoming session = 10 points
/// - Points should represent sessions a learner can still attend.
class SessionPointsService {
  static const int pointsPerSession = 10;

  /// Returns paid/upcoming sessions count for current learner/parent.
  static Future<int> getPaidUpcomingSessionsCount() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return 0;

      // Individual sessions are already filtered to paid in IndividualSessionService.
      final individualUpcoming =
          await IndividualSessionService.getStudentUpcomingSessions(limit: 500);
      final individualIds = individualUpcoming
          .map((s) => s['id'] as String?)
          .whereType<String>()
          .toSet();
      final individualSessionKeys = individualUpcoming
          .map((s) {
            final tutorId = s['tutor_id'] as String?;
            final date = s['scheduled_date'] as String?;
            final time = s['scheduled_time'] as String?;
            if (tutorId == null || date == null || time == null) return null;
            return '$tutorId|$date|$time';
          })
          .whereType<String>()
          .toSet();

      // Trials: use TrialSessionService (same source My Sessions uses),
      // then apply paid/upcoming filters locally for consistency.
      final trials = await TrialSessionService.getStudentTrialSessions();
      var paidTrialUpcomingCount = 0;
      for (final trial in trials) {
        final isUpcomingStatus = trial.status == 'approved' ||
            trial.status == 'scheduled' ||
            trial.status == 'in_progress';
        final isPaid =
            trial.paymentStatus == 'paid' || trial.paymentStatus == 'completed';
        if (!isUpcomingStatus || !isPaid) continue;
        // Must be genuinely upcoming by date+time, not status-only.
        if (!SessionDateUtils.isSessionUpcoming(trial) &&
            !SessionDateUtils.isSessionInProgress(trial)) {
          continue;
        }
        // Avoid double counting when trial is already represented by an
        // upcoming individual session row.
        if (individualIds.contains(trial.id)) continue;
        final trialKey =
            '${trial.tutorId}|${trial.scheduledDate.toIso8601String().split('T')[0]}|${trial.scheduledTime}';
        if (individualSessionKeys.contains(trialKey)) continue;
        paidTrialUpcomingCount++;
      }

      return individualIds.length + paidTrialUpcomingCount;
    } catch (e) {
      LogService.error('Error loading paid upcoming sessions count: $e');
      return 0;
    }
  }

  /// Returns points using the rule: 10 points per paid/upcoming session.
  static Future<int> getAvailableSessionPoints() async {
    final count = await getPaidUpcomingSessionsCount();
    return count * pointsPerSession;
  }
}
