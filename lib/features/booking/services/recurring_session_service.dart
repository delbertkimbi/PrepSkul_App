import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';

/// RecurringSessionService
///
/// Handles creation and management of recurring sessions
/// from approved booking requests
class RecurringSessionService {
  static final _supabase = SupabaseService.client;

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
}





