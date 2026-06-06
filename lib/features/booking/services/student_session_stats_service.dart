import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/features/booking/services/individual_session_service.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart';
import 'package:prepskul/features/booking/utils/session_date_utils.dart';

/// Shared student/parent session counts for home dashboard and badges.
/// Mirrors classification logic in [MySessionsScreen].
class StudentSessionStatsService {
  /// Upcoming session count (individual + paid approved trials).
  static Future<int> countUpcomingSessions() async {
    try {
      final upcoming = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      try {
        final indUpcoming =
            await IndividualSessionService.getStudentUpcomingSessions(limit: 50);
        for (final s in indUpcoming) {
          final id = s['id'] as String?;
          if (id != null && id.isNotEmpty && seenIds.add(id)) {
            upcoming.add(s);
          }
        }
      } catch (e) {
        LogService.warning('StudentSessionStats: individual upcoming failed: $e');
      }

      try {
        final trials = await TrialSessionService.getStudentTrialSessions();
        for (final trial in trials) {
          final trialId = trial.id;
          if (seenIds.contains(trialId)) continue;

          final status = trial.status;
          final paymentStatus = trial.paymentStatus;
          final isApproved =
              status == 'approved' || status == 'scheduled' || status == 'in_progress';
          final isPaid =
              paymentStatus == 'paid' || paymentStatus == 'completed';

          if (!isApproved || !isPaid) continue;

          final isExpired = SessionDateUtils.isSessionExpired(trial);
          final isInProgress = SessionDateUtils.isSessionInProgress(trial);
          final isUpcomingTime = SessionDateUtils.isSessionUpcoming(trial);
          final isCompleted = status == 'completed' ||
              status == 'cancelled' ||
              status == 'rejected' ||
              status == 'expired';

          if (isExpired || status == 'expired' || isCompleted) continue;
          if (isInProgress || isUpcomingTime) {
            seenIds.add(trialId);
            upcoming.add({'id': trialId});
          }
        }
      } catch (e) {
        LogService.warning('StudentSessionStats: trials failed: $e');
      }

      return upcoming.length;
    } catch (e) {
      LogService.error('StudentSessionStats countUpcomingSessions: $e');
      return 0;
    }
  }

  /// All-time countable sessions (individual past+upcoming + paid historical trials).
  static Future<int> countAllTimeSessions() async {
    try {
      int count = 0;
      final tutorIds = <String>{};

      try {
        final indUpcoming =
            await IndividualSessionService.getStudentUpcomingSessions(limit: 50);
        count += indUpcoming.length;
        for (final s in indUpcoming) {
          final recurring = s['recurring_sessions'] as Map<String, dynamic>?;
          final tid = (recurring?['tutor_id'] as String?) ?? (s['tutor_id'] as String?);
          if (tid != null && tid.isNotEmpty) tutorIds.add(tid);
        }
      } catch (e) {
        LogService.warning('StudentSessionStats: individual upcoming for all-time: $e');
      }

      try {
        final indPast =
            await IndividualSessionService.getStudentPastSessions(limit: 200);
        count += indPast.length;
        for (final s in indPast) {
          final recurring = s['recurring_sessions'] as Map<String, dynamic>?;
          final tid = (recurring?['tutor_id'] as String?) ?? (s['tutor_id'] as String?);
          if (tid != null && tid.isNotEmpty) tutorIds.add(tid);
        }
      } catch (e) {
        LogService.warning('StudentSessionStats: individual past failed: $e');
      }

      try {
        final trials = await TrialSessionService.getStudentTrialSessions();
        for (final t in trials) {
          final status = t.status.toLowerCase();
          final paymentStatus = t.paymentStatus.toLowerCase();
          final isPaid = paymentStatus == 'paid' || paymentStatus == 'completed';
          final isCountable = isPaid &&
              status != 'rejected' &&
              status != 'cancelled';
          if (isCountable) {
            count += 1;
            if (t.tutorId.isNotEmpty) tutorIds.add(t.tutorId);
          }
        }
      } catch (e) {
        LogService.warning('StudentSessionStats: trials for all-time: $e');
      }

      return count;
    } catch (e) {
      LogService.error('StudentSessionStats countAllTimeSessions: $e');
      return 0;
    }
  }
}
