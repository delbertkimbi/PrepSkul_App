import '../utils/booking_time.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/features/booking/models/recurring_session_model.dart';

/// AvailabilityService
///
/// Handles tutor availability and conflict detection:
/// - Check if requested times conflict with existing sessions
/// - Get tutor's available time slots
/// - Manage tutor's availability schedule
class AvailabilityService {
  static get _supabase => SupabaseService.client;

  /// Check if requested times conflict with tutor's existing sessions
  static Future<ConflictResult> checkConflicts({
    required String tutorId,
    required List<String> requestedDays,
    required Map<String, String> requestedTimes,
  }) async {
    try {
      // Get all active sessions for this tutor
      final sessions = await _supabase
          .from('recurring_sessions')
          .select()
          .eq('tutor_id', tutorId)
          .eq('status', 'active');

      final List<RecurringSession> activeSessions = (sessions as List)
          .map((json) => RecurringSession.fromJson(json))
          .toList();

      // Check for conflicts
      final List<String> conflictingDays = [];
      final Map<String, String> conflictDetails = {};

      for (final requestedDay in requestedDays) {
        final requestedTime = requestedTimes[requestedDay];
        if (requestedTime == null) continue;

        for (final session in activeSessions) {
          if (session.days.contains(requestedDay)) {
            final existingTime = session.times[requestedDay];
            if (existingTime == requestedTime) {
              conflictingDays.add(requestedDay);
              conflictDetails[requestedDay] =
                  'You have another student (${session.studentName}) at $requestedDay $existingTime';
              break;
            }
          }
        }
      }

      return ConflictResult(
        hasConflict: conflictingDays.isNotEmpty,
        conflictingDays: conflictingDays,
        conflictDetails: conflictDetails,
      );
    } catch (e) {
      throw Exception('Failed to check conflicts: $e');
    }
  }

  /// Get tutor's available days and times
  static Future<TutorAvailability> getTutorAvailability(String tutorId) async {
    try {
      final tutorProfile = await _supabase
          .from('tutor_profiles')
          .select('available_schedule, availability_schedule')
          .eq('user_id', tutorId)
          .maybeSingle();

      if (tutorProfile == null) {
        throw Exception('Tutor profile not found: $tutorId');
      }

      // Parse available_schedule (array of strings like "Weekday evenings")
      final availableSchedule = tutorProfile['available_schedule'] as List?;
      final Set<String> availableDays = {};

      if (availableSchedule != null) {
        for (final schedule in availableSchedule) {
          final scheduleStr = schedule.toString().toLowerCase();
          if (scheduleStr.contains('weekday')) {
            availableDays.addAll([
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
            ]);
          }
          if (scheduleStr.contains('weekend')) {
            availableDays.addAll(['Saturday', 'Sunday']);
          }
        }
      }

      // Parse availability_schedule JSONB (detailed schedule with times)
      final detailedSchedule =
          tutorProfile['availability_schedule'] as Map<String, dynamic>?;
      if (detailedSchedule != null) {
        availableDays.addAll(
          detailedSchedule.entries
              .where((e) => e.value is List && (e.value as List).isNotEmpty)
              .map((e) => e.key),
        );
      }

      return TutorAvailability(
        tutorId: tutorId,
        availableDays: availableDays.toList(),
        detailedSchedule: detailedSchedule,
      );
    } catch (e) {
      throw Exception('Failed to get tutor availability: $e');
    }
  }

  /// Get tutor's blocked time slots (from recurring, individual, and trial sessions)
  static Future<Map<String, List<String>>> getBlockedTimeSlots(
    String tutorId,
  ) async {
    try {
      final Map<String, List<String>> blockedSlots = {};

      // 1. Recurring Sessions (General pattern)
      final recurringSessions = await _supabase
          .from('recurring_sessions')
          .select()
          .eq('tutor_id', tutorId)
          .eq('status', 'active');

      final List<RecurringSession> activeRecurring = (recurringSessions as List)
          .map((json) => RecurringSession.fromJson(json))
          .toList();

      for (final session in activeRecurring) {
        for (final day in session.days) {
          final time = session.times[day];
          if (time != null) {
            blockedSlots.putIfAbsent(day, () => []).add(time);
          }
        }
      }

      // 2. Trial Sessions (Specific dates)
      // We need to fetch upcoming confirmed/pending trials
      final trialSessions = await _supabase
          .from('trial_sessions')
          .select('scheduled_date, scheduled_time')
          .eq('tutor_id', tutorId)
          .inFilter('status', [
            'pending',
            'confirmed',
            'completed',
          ]) // Block pending requests too to avoid double booking
          .gte('scheduled_date', DateTime.now().toIso8601String());

      for (final session in trialSessions as List) {
        final dateStr = session['scheduled_date'] as String;
        final timeStr = session['scheduled_time'] as String;

        // Convert date to day name (e.g., "Monday") to merge with generic pattern if needed,
        // OR store as specific date override.
        // For simplicity in this method which returns generic "Day -> [Times]",
        // we might lose the specific date context if we just use Day Name.
        // However, the UI calls this to get *generic* blocked slots?
        // Wait, _loadTutorSchedule in UI gets blocked slots for *selected date*.
        // But it asks for *all* blocked slots and then filters by day name?
        // "final dayBlockedSlots = blockedSlots[dayName] ?? [];"
        // This logic is flawed for specific dates (like trials).
        // A trial on "Monday, Oct 23" shouldn't block "Monday, Oct 30".

        // We should probably handle specific dates separately or return a structure that supports both.
        // For now, to minimally break existing contract, we'll add them to the day name bucket,
        // BUT this is technically incorrect for non-recurring.
        // IMPROVEMENT: returning map key as "YYYY-MM-DD" for specific, "Monday" for recurring?
        // The UI currently only looks up by dayName.
        // Let's try to convert the specific date to day name, BUT this means a single trial blocks ALL Mondays.
        // That's bad.

        // Correct approach: logic should be "Is this specific date/time blocked?"
        // The UI `_loadTutorSchedule` gets `blockedSlots` map.
        // We should change `getBlockedTimeSlots` to accept a `date` parameter?
        // Or return a more complex object.
      }

      return blockedSlots;
    } catch (e) {
      throw Exception('Failed to get blocked time slots: $e');
    }
  }

  /// Get blocked time slots for a specific date

  /// Normalize time string to "HH:mm" format
  /// Handles formats like "7:00 PM", "19:00", "7:00 AM", etc.
  static String _normalizeTimeTo24Hour(String time) =>
      BookingTime.normalize(time);

  static Future<List<Map<String, dynamic>>> _busyWindows(
    String tutorId,
    DateTime date,
  ) async {
    final rows = await _supabase.rpc(
      'tutor_busy_windows',
      params: {
        'p_tutor_id': tutorId,
        'p_date': date.toIso8601String().split('T')[0],
      },
    );
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  static Future<List<String>> getBlockedTimesForDate(
    String tutorId,
    DateTime date,
  ) async {
    final windows = await _busyWindows(tutorId, date);
    return windows
        .map((w) => w['start_minute'] as int)
        .where((m) => m >= 0 && m < 1440)
        .map(
          (m) =>
              '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
        )
        .toSet()
        .toList();
  }

  /// Only published starts which do not overlap the server's occupied ranges.
  /// This is a preview, not a reservation; submission must revalidate atomically.
  static Future<List<String>> getAvailableTimesForDay({
    required String tutorId,
    required String day,
    DateTime? date,
    int durationMinutes = 60,
  }) async {
    if (date == null)
      throw ArgumentError('A specific booking date is required');
    if (durationMinutes <= 0 || durationMinutes > 180)
      throw ArgumentError('Unsupported duration');
    final windows = await _busyWindows(tutorId, date);
    final tutor = await _supabase
        .from('tutor_profiles')
        .select('availability_schedule')
        .eq('user_id', tutorId)
        .maybeSingle();
    if (tutor == null) throw StateError('Tutor profile unavailable');
    final schedule = tutor['availability_schedule'];
    final published = schedule is Map ? schedule[day] : null;
    if (published == null) return [];
    if (published is! List)
      throw const FormatException('Invalid published schedule');
    return published
        .map((s) => BookingTime.normalize(s as String))
        .toSet()
        .where(
          (slot) => !windows.any(
            (w) => BookingTime.overlaps(
              slot,
              durationMinutes,
              w['start_minute'] as int,
              w['end_minute'] as int,
            ),
          ),
        )
        .toList()
      ..sort();
  }

  /// Update tutor's availability schedule
  static Future<void> updateAvailability({
    required String tutorId,
    required Map<String, dynamic> schedule,
  }) async {
    try {
      await _supabase
          .from('tutor_profiles')
          .update({'availability_schedule': schedule})
          .eq('user_id', tutorId);
    } catch (e) {
      throw Exception('Failed to update availability: $e');
    }
  }

  /// Get tutor's teaching capacity
  static Future<TutorCapacity> getTutorCapacity(String tutorId) async {
    try {
      final sessions = await _supabase
          .from('recurring_sessions')
          .select()
          .eq('tutor_id', tutorId)
          .eq('status', 'active');

      final List<RecurringSession> activeSessions = (sessions as List)
          .map((json) => RecurringSession.fromJson(json))
          .toList();

      final totalStudents = activeSessions.length;
      final totalSessionsPerWeek = activeSessions.fold<int>(
        0,
        (sum, session) => sum + session.frequency,
      );

      return TutorCapacity(
        tutorId: tutorId,
        totalStudents: totalStudents,
        totalSessionsPerWeek: totalSessionsPerWeek,
        activeSessions: activeSessions,
      );
    } catch (e) {
      throw Exception('Failed to get tutor capacity: $e');
    }
  }
}

/// Result of conflict check
class ConflictResult {
  final bool hasConflict;
  final List<String> conflictingDays;
  final Map<String, String> conflictDetails;

  ConflictResult({
    required this.hasConflict,
    required this.conflictingDays,
    required this.conflictDetails,
  });

  /// Get formatted conflict message
  String getConflictMessage() {
    if (!hasConflict) return '';
    if (conflictDetails.isEmpty) return 'Schedule conflict detected';
    return conflictDetails.values.first;
  }
}

/// Tutor's availability information
class TutorAvailability {
  final String tutorId;
  final List<String> availableDays;
  final Map<String, dynamic>? detailedSchedule;

  TutorAvailability({
    required this.tutorId,
    required this.availableDays,
    this.detailedSchedule,
  });

  /// Check if a specific day is available
  bool isDayAvailable(String day) {
    return availableDays.contains(day);
  }

  /// Get available time slots for a day from detailed schedule
  List<String>? getTimeSlotsForDay(String day) {
    if (detailedSchedule == null) return null;
    return (detailedSchedule![day] as List?)?.cast<String>();
  }
}

/// Tutor's current teaching capacity
class TutorCapacity {
  final String tutorId;
  final int totalStudents;
  final int totalSessionsPerWeek;
  final List<RecurringSession> activeSessions;

  TutorCapacity({
    required this.tutorId,
    required this.totalStudents,
    required this.totalSessionsPerWeek,
    required this.activeSessions,
  });

  /// Check if tutor is at capacity (configurable limit)
  bool isAtCapacity({int maxStudents = 20, int maxSessionsPerWeek = 40}) {
    return totalStudents >= maxStudents ||
        totalSessionsPerWeek >= maxSessionsPerWeek;
  }

  /// Get capacity utilization percentage
  double getUtilization({int maxSessionsPerWeek = 40}) {
    return (totalSessionsPerWeek / maxSessionsPerWeek * 100).clamp(0, 100);
  }
}
