import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';

/// RecurringSessionService
///
/// Handles creation and management of recurring sessions
/// from approved booking requests
class RecurringSessionService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Create a recurring session from an approved booking request
  static Future<Map<String, dynamic>> createRecurringSessionFromBooking(
    BookingRequest bookingRequest,
  ) async {
    try {
      // Calculate start date (next available session date)
      final startDate = _calculateStartDate(bookingRequest);

      // Create recurring session data
      final sessionData = <String, dynamic>{
        'request_id': bookingRequest.id,
        'student_id': bookingRequest.studentId,
        'tutor_id': bookingRequest.tutorId,
        'frequency': bookingRequest.frequency,
        'days': bookingRequest.days,
        'times': bookingRequest.times,
        'location': bookingRequest.location,
        'address': bookingRequest.address,
        'payment_plan': bookingRequest.paymentPlan,
        'monthly_total': bookingRequest.monthlyTotal,
        'start_date': startDate.toIso8601String(),
        'end_date': null, // Ongoing
        'status': 'active',
        'total_sessions_completed': 0,
        'total_revenue': 0.0,
        // Denormalized data
        'student_name': bookingRequest.studentName,
        'student_avatar_url': bookingRequest.studentAvatarUrl,
        'student_type': bookingRequest.studentType,
        'tutor_name': bookingRequest.tutorName,
        'tutor_avatar_url': bookingRequest.tutorAvatarUrl,
        'tutor_rating': bookingRequest.tutorRating,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Add location_description if available
      if (bookingRequest.locationDescription != null) {
        sessionData['location_description'] = bookingRequest.locationDescription;
      }

      // Insert into recurring_sessions table
      final response = await _supabase
          .from('recurring_sessions')
          .insert(sessionData)
          .select()
          .single();

      print('✅ Recurring session created: ${response['id']}');

      // Generate initial individual sessions (next 8 weeks)
      try {
        await generateIndividualSessions(
          recurringSessionId: response['id'] as String,
          weeksAhead: 8,
        );
        print('✅ Initial individual sessions generated');
      } catch (e) {
        print('⚠️ Failed to generate initial individual sessions: $e');
        // Don't fail the recurring session creation if individual session generation fails
      }

      return response;
    } catch (e) {
      print('❌ Error creating recurring session: $e');
      rethrow;
    }
  }

  /// Calculate the start date for the recurring session
  /// Returns the next occurrence of the first requested day
  static DateTime _calculateStartDate(BookingRequest request) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Get the first day from the request
    final firstDay = request.days.first;
    final dayIndex = _getDayIndex(firstDay);
    
    // Calculate days until next occurrence
    int daysUntil = (dayIndex - now.weekday) % 7;
    if (daysUntil == 0) {
      // If today is the day, check the time
      final timeStr = request.times[firstDay];
      if (timeStr != null) {
        final timeParts = timeStr.replaceAll(' ', '').split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1].replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final sessionTime = DateTime(now.year, now.month, now.day, hour, minute);
        
        // If session time has passed today, schedule for next week
        if (now.isAfter(sessionTime)) {
          daysUntil = 7;
        }
      }
    }
    
    return today.add(Duration(days: daysUntil));
  }

  /// Get day index (Monday = 1, Sunday = 7)
  static int _getDayIndex(String day) {
    const days = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
      'Saturday': 6,
      'Sunday': 7,
    };
    return days[day] ?? 1;
  }

  /// Get all recurring sessions for a tutor
  static Future<List<Map<String, dynamic>>> getTutorRecurringSessions({
    String? status,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      var query = _supabase
          .from('recurring_sessions')
          .select()
          .eq('tutor_id', userId);

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      final response = await query.order('start_date', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error fetching tutor recurring sessions: $e');
      throw Exception('Failed to fetch recurring sessions: $e');
    }
  }

  /// Get all recurring sessions for a student/parent
  static Future<List<Map<String, dynamic>>> getStudentRecurringSessions(
    String studentId, {
    String? status,
  }) async {
    try {
      var query = _supabase
          .from('recurring_sessions')
          .select()
          .eq('student_id', studentId);

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      final response = await query.order('start_date', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error fetching student recurring sessions: $e');
      throw Exception('Failed to fetch recurring sessions: $e');
    }
  }

  /// Update session status
  static Future<void> updateSessionStatus(
    String sessionId,
    String status, {
    String? pauseReason,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (pauseReason != null) {
        updateData['pause_reason'] = pauseReason;
      }

      await _supabase
          .from('recurring_sessions')
          .update(updateData)
          .eq('id', sessionId);

      print('✅ Session status updated: $sessionId -> $status');
    } catch (e) {
      print('❌ Error updating session status: $e');
      rethrow;
    }
  }

  /// Generate individual session instances from a recurring session
  ///
  /// Creates individual sessions for the next [weeksAhead] weeks
  /// based on the recurring session's schedule (days, times, frequency)
  static Future<void> generateIndividualSessions({
    required String recurringSessionId,
    int weeksAhead = 8,
  }) async {
    try {
      // Get recurring session details
      final recurringSession = await _supabase
          .from('recurring_sessions')
          .select()
          .eq('id', recurringSessionId)
          .single();

      final startDate = DateTime.parse(recurringSession['start_date'] as String);
      final days = (recurringSession['days'] as List).cast<String>();
      final times = recurringSession['times'] as Map<String, dynamic>;
      final location = recurringSession['location'] as String;
      final address = recurringSession['address'] as String?;
      final tutorId = recurringSession['tutor_id'] as String;
      final studentId = recurringSession['student_id'] as String;

      // Get subject from booking request or use default
      String subject = 'Tutoring Session';
      if (recurringSession['request_id'] != null) {
        final request = await _supabase
            .from('booking_requests')
            .select('subject')
            .eq('id', recurringSession['request_id'])
            .maybeSingle();
        subject = request?['subject'] as String? ?? subject;
      }

      // Default duration (can be made configurable)
      const durationMinutes = 60;

      // Calculate end date (weeksAhead weeks from start)
      final endDate = startDate.add(Duration(days: weeksAhead * 7));

      // Generate sessions for each day in the schedule
      final sessionsToCreate = <Map<String, dynamic>>[];
      final currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final targetDate = DateTime(endDate.year, endDate.month, endDate.day);

      // Iterate through each week
      for (var week = 0; week < weeksAhead; week++) {
        // For each day in the schedule
        for (final day in days) {
          final dayIndex = _getDayIndex(day);
          final timeStr = times[day] as String?;
          
          if (timeStr == null || timeStr.isEmpty) continue;

          // Calculate date for this day
          final weekStart = currentDate.add(Duration(days: week * 7));
          final daysOffset = (dayIndex - weekStart.weekday) % 7;
          final sessionDate = weekStart.add(Duration(days: daysOffset));

          // Skip if before start date or after end date
          if (sessionDate.isBefore(currentDate) || sessionDate.isAfter(targetDate)) {
            continue;
          }

          // Parse time
          final timeParts = timeStr.replaceAll(' ', '').split(':');
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minuteStr = timeParts.length > 1 
              ? timeParts[1].replaceAll(RegExp(r'[^\d]'), '')
              : '0';
          final minute = int.tryParse(minuteStr) ?? 0;
          final isPM = timeStr.toUpperCase().contains('PM');
          final hour24 = isPM && hour != 12 
              ? hour + 12 
              : (hour == 12 && !isPM ? 0 : hour);

          // Format time as HH:MM:SS
          final timeFormatted = '${hour24.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
          final dateFormatted = sessionDate.toIso8601String().split('T')[0];

          // Check if session already exists
          final existingSession = await _supabase
              .from('individual_sessions')
              .select('id')
              .eq('recurring_session_id', recurringSessionId)
              .eq('scheduled_date', dateFormatted)
              .eq('scheduled_time', timeFormatted)
              .maybeSingle();

          if (existingSession != null) {
            continue; // Session already exists, skip
          }

          // Create session data
          final sessionData = <String, dynamic>{
            'recurring_session_id': recurringSessionId,
            'tutor_id': tutorId,
            'learner_id': studentId,
            'parent_id': recurringSession['student_type'] == 'parent' ? studentId : null,
            'subject': subject,
            'scheduled_date': dateFormatted,
            'scheduled_time': timeFormatted,
            'duration_minutes': durationMinutes,
            'location': location == 'hybrid' ? 'online' : location, // Default hybrid to online
            'onsite_address': location == 'onsite' || location == 'hybrid' ? address : null,
            'status': 'scheduled',
            'created_at': DateTime.now().toIso8601String(),
          };

          sessionsToCreate.add(sessionData);
        }
      }

      // Batch insert sessions (in chunks of 100 to avoid payload limits)
      if (sessionsToCreate.isNotEmpty) {
        const chunkSize = 100;
        for (var i = 0; i < sessionsToCreate.length; i += chunkSize) {
          final chunk = sessionsToCreate.skip(i).take(chunkSize).toList();
          await _supabase.from('individual_sessions').insert(chunk);
        }
        print('✅ Generated ${sessionsToCreate.length} individual sessions');
      } else {
        print('ℹ️ No new individual sessions to generate');
      }
    } catch (e) {
      print('❌ Error generating individual sessions: $e');
      rethrow;
    }
  }
}
