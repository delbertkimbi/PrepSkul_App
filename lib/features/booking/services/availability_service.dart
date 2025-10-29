import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/booking/models/recurring_session_model.dart';

/// AvailabilityService
///
/// Handles tutor availability and conflict detection:
/// - Check if requested times conflict with existing sessions
/// - Get tutor's available time slots
/// - Manage tutor's availability schedule
class AvailabilityService {
  static final _supabase = SupabaseService.client;

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
  static Future<TutorAvailability> getTutorAvailability(
      String tutorId) async {
    try {
      final tutorProfile = await _supabase
          .from('tutor_profiles')
          .select('available_schedule, availability_schedule')
          .eq('user_id', tutorId)
          .single();

      // Parse available_schedule (array of strings like "Weekday evenings")
      final availableSchedule =
          tutorProfile['available_schedule'] as List?;
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
              'Friday'
            ]);
          }
          if (scheduleStr.contains('weekend')) {
            availableDays.addAll(['Saturday', 'Sunday']);
          }
        }
      }

      // If no availability data, assume all days available
      if (availableDays.isEmpty) {
        availableDays.addAll([
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ]);
      }

      // Parse availability_schedule JSONB (detailed schedule with times)
      final detailedSchedule =
          tutorProfile['availability_schedule'] as Map<String, dynamic>?;

      return TutorAvailability(
        tutorId: tutorId,
        availableDays: availableDays.toList(),
        detailedSchedule: detailedSchedule,
      );
    } catch (e) {
      throw Exception('Failed to get tutor availability: $e');
    }
  }

  /// Get tutor's blocked time slots (from existing sessions)
  static Future<Map<String, List<String>>> getBlockedTimeSlots(
      String tutorId) async {
    try {
      final sessions = await _supabase
          .from('recurring_sessions')
          .select()
          .eq('tutor_id', tutorId)
          .eq('status', 'active');

      final List<RecurringSession> activeSessions = (sessions as List)
          .map((json) => RecurringSession.fromJson(json))
          .toList();

      final Map<String, List<String>> blockedSlots = {};

      for (final session in activeSessions) {
        for (final day in session.days) {
          final time = session.times[day];
          if (time != null) {
            if (!blockedSlots.containsKey(day)) {
              blockedSlots[day] = [];
            }
            blockedSlots[day]!.add(time);
          }
        }
      }

      return blockedSlots;
    } catch (e) {
      throw Exception('Failed to get blocked time slots: $e');
    }
  }

  /// Get available time slots for a specific day
  static Future<List<String>> getAvailableTimesForDay({
    required String tutorId,
    required String day,
  }) async {
    try {
      // Get blocked slots
      final blockedSlots = await getBlockedTimeSlots(tutorId);
      final dayBlockedSlots = blockedSlots[day] ?? [];

      // All possible time slots (in production, this comes from tutor's settings)
      final allSlots = [
        '12:00 PM',
        '12:30 PM',
        '1:00 PM',
        '1:30 PM',
        '2:00 PM',
        '2:30 PM',
        '3:00 PM',
        '3:30 PM',
        '4:00 PM',
        '4:30 PM',
        '5:00 PM',
        '5:30 PM',
        '6:00 PM',
        '6:30 PM',
        '7:00 PM',
        '7:30 PM',
        '8:00 PM',
        '8:30 PM',
        '9:00 PM',
        '9:30 PM',
      ];

      // Filter out blocked slots
      return allSlots
          .where((slot) => !dayBlockedSlots.contains(slot))
          .toList();
    } catch (e) {
      throw Exception('Failed to get available times: $e');
    }
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

