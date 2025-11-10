import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';

class BookingService {
  /// Create a booking request in the database
  static Future<void> createBookingRequest({
    required String tutorId,
    required int frequency,
    required List<String> days,
    required Map<String, String> times,
    required String location,
    String? address,
    String? locationDescription,
    required String paymentPlan,
    required double monthlyTotal,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get user profile for denormalized data
      final userProfile = await SupabaseService.client
          .from('profiles')
          .select('full_name, user_type')
          .eq('id', userId)
          .single();

      // Get tutor profile for denormalized data
      final tutorProfile = await SupabaseService.client
          .from('tutor_profiles')
          .select('user_id, admin_approved_rating, base_session_price')
          .eq('user_id', tutorId)
          .maybeSingle();

      final tutorUserId = tutorProfile?['user_id'] as String? ?? tutorId;

      final tutorProfileData = await SupabaseService.client
          .from('profiles')
          .select('full_name')
          .eq('id', tutorUserId)
          .maybeSingle();

      // Create booking request data
      final requestData = {
        'student_id': userId,
        'tutor_id': tutorUserId,
        'frequency': frequency,
        'days': days,
        'times': times,
        'location': location,
        'address': address,
        'location_description': locationDescription,
        'payment_plan': paymentPlan,
        'monthly_total': monthlyTotal,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        // Denormalized data
        'student_name': userProfile['full_name'],
        'student_type': userProfile['user_type'],
        'tutor_name': tutorProfileData?['full_name'] ?? 'Tutor',
        'tutor_rating':
            (tutorProfile?['admin_approved_rating'] as num?)?.toDouble() ?? 0.0,
      };

      // Insert into booking_requests table
      final response = await SupabaseService.client
          .from('booking_requests')
          .insert(requestData)
          .select()
          .single();

      final requestId = response['id'] as String;
      final studentName = userProfile['full_name'] as String? ?? 'Student';
      final subject =
          'Tutoring Sessions'; // Could be extracted from request if available

      print('✅ Booking request created successfully: $requestId');

      // Send notification to tutor
      try {
        await NotificationHelperService.notifyBookingRequestCreated(
          tutorId: tutorUserId,
          studentId: userId,
          requestId: requestId,
          studentName: studentName,
          subject: subject,
        );
      } catch (e) {
        print('⚠️ Failed to send booking request notification: $e');
        // Don't fail the request creation if notification fails
      }
    } catch (e) {
      print('❌ Error creating booking request: $e');
      rethrow;
    }
  }

  /// Get all booking requests for a tutor
  static Future<List<BookingRequest>> getTutorBookingRequests({
    String? status,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      var query = SupabaseService.client
          .from('booking_requests')
          .select()
          .eq('tutor_id', userId);

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => BookingRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching tutor booking requests: $e');
      throw Exception('Failed to fetch booking requests: $e');
    }
  }

  /// Get all booking requests for a student/parent
  static Future<List<BookingRequest>> getStudentBookingRequests(
    String studentId,
  ) async {
    try {
      var query = SupabaseService.client
          .from('booking_requests')
          .select()
          .eq('student_id', studentId);

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => BookingRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching student booking requests: $e');
      throw Exception('Failed to fetch booking requests: $e');
    }
  }

  /// Get single booking request by ID
  static Future<BookingRequest> getBookingRequestById(String requestId) async {
    try {
      final response = await SupabaseService.client
          .from('booking_requests')
          .select()
          .eq('id', requestId)
          .single();

      return BookingRequest.fromJson(response);
    } catch (e) {
      print('❌ Error fetching booking request: $e');
      throw Exception('Failed to fetch booking request: $e');
    }
  }

  /// Approve a booking request (tutor)
  static Future<BookingRequest> approveBookingRequest(
    String requestId, {
    String? responseNotes,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Verify the request belongs to this tutor
      final request = await getBookingRequestById(requestId);
      if (request.tutorId != userId) {
        throw Exception('Unauthorized: This request is not for you');
      }

      if (request.status != 'pending') {
        throw Exception('Request is not pending');
      }

      // Check for conflicts
      final hasConflict = await _checkScheduleConflicts(request);

      final updateData = {
        'status': 'approved',
        'responded_at': DateTime.now().toIso8601String(),
        'tutor_response': responseNotes,
        'has_conflict': hasConflict,
      };

      final updated = await SupabaseService.client
          .from('booking_requests')
          .update(updateData)
          .eq('id', requestId)
          .select()
          .single();

      final bookingRequest = BookingRequest.fromJson(updated);

      print('✅ Booking request approved: $requestId');

      // Send notification to student
      try {
        final tutorName = request.tutorName;
        final subject = 'Tutoring Sessions'; // Could be extracted if available
        await NotificationHelperService.notifyBookingRequestAccepted(
          studentId: request.studentId,
          tutorId: request.tutorId,
          requestId: requestId,
          tutorName: tutorName,
          subject: subject,
        );
      } catch (e) {
        print('⚠️ Failed to send booking acceptance notification: $e');
        // Don't fail the approval if notification fails
      }

      return bookingRequest;
    } catch (e) {
      print('❌ Error approving booking request: $e');
      rethrow;
    }
  }

  /// Reject a booking request (tutor)
  static Future<BookingRequest> rejectBookingRequest(
    String requestId, {
    required String reason,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Verify the request belongs to this tutor
      final request = await getBookingRequestById(requestId);
      if (request.tutorId != userId) {
        throw Exception('Unauthorized: This request is not for you');
      }

      if (request.status != 'pending') {
        throw Exception('Request is not pending');
      }

      final updateData = {
        'status': 'rejected',
        'responded_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
      };

      final updated = await SupabaseService.client
          .from('booking_requests')
          .update(updateData)
          .eq('id', requestId)
          .select()
          .single();

      final bookingRequest = BookingRequest.fromJson(updated);

      print('✅ Booking request rejected: $requestId');

      // Send notification to student
      try {
        final tutorName = request.tutorName;
        await NotificationHelperService.notifyBookingRequestRejected(
          studentId: request.studentId,
          tutorId: request.tutorId,
          requestId: requestId,
          tutorName: tutorName,
          rejectionReason: reason,
        );
      } catch (e) {
        print('⚠️ Failed to send booking rejection notification: $e');
        // Don't fail the rejection if notification fails
      }

      return bookingRequest;
    } catch (e) {
      print('❌ Error rejecting booking request: $e');
      rethrow;
    }
  }

  /// Check for schedule conflicts with existing sessions
  static Future<bool> _checkScheduleConflicts(BookingRequest request) async {
    try {
      // Check conflicts with existing recurring sessions for this tutor
      final existingSessions = await SupabaseService.client
          .from('recurring_sessions')
          .select()
          .eq('tutor_id', request.tutorId)
          .eq('status', 'active');

      for (final session in existingSessions) {
        final sessionDays = List<String>.from(session['days'] as List);
        final sessionTimes = Map<String, String>.from(session['times'] as Map);

        // Check if any day/time overlaps
        for (final day in request.days) {
          if (sessionDays.contains(day)) {
            final requestTime = request.times[day];
            final sessionTime = sessionTimes[day];
            if (requestTime == sessionTime) {
              return true; // Conflict found
            }
          }
        }
      }

      return false; // No conflicts
    } catch (e) {
      print('⚠️ Error checking conflicts: $e');
      return false; // Assume no conflict on error
    }
  }
}
