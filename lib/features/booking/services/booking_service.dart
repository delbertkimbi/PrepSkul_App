import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';

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
          .select('full_name, user_type, avatar_url')
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

      // Map user_type to student_type for booking_requests constraint
      // Constraint expects: ('learner', 'parent')
      // user_type can be: ('learner', 'student', 'tutor', 'parent')
      final rawUserType = userProfile['user_type'] as String?;
      final userType = (rawUserType ?? 'learner').toLowerCase().trim();

      // Determine student_type with explicit validation
      String studentType;
      if (userType == 'learner' || userType == 'student') {
        studentType = 'learner';
      } else if (userType == 'parent') {
        studentType = 'parent';
      } else {
        // Log unexpected value and default to 'learner'
        print(
          '⚠️ Unexpected user_type: "$rawUserType" (normalized: "$userType"), defaulting to "learner"',
        );
        studentType = 'learner';
      }

      // Final validation - ensure it's one of the allowed values
      if (studentType != 'learner' && studentType != 'parent') {
        print(
          '❌ Invalid student_type after mapping: "$studentType", forcing to "learner"',
        );
        studentType = 'learner';
      }

      print(
        '🔍 Booking request - user_type: "$rawUserType" → student_type: "$studentType"',
      );

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
        'student_type': studentType, // Validated: 'learner' or 'parent'
        'tutor_name': tutorProfileData?['full_name'] ?? 'Tutor',
        'tutor_rating':
            (tutorProfile?['admin_approved_rating'] as num?)?.toDouble() ?? 0.0,
      };

      // Insert into booking_requests table
      try {
        final response = await SupabaseService.client
            .from('booking_requests')
            .insert(requestData)
            .select()
            .single();

        final requestId = response['id'] as String;
        final studentName = userProfile['full_name'] as String? ?? 'Student';
        final studentAvatarUrl = userProfile['avatar_url'] as String?;
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
            senderAvatarUrl: studentAvatarUrl,
          );
        } catch (e) {
          print('⚠️ Failed to send booking request notification: $e');
          // Don't fail the request creation if notification fails
        }
      } catch (e) {
        print('❌ Error inserting booking request: $e');
        rethrow;
      }
    } catch (e) {
      print('❌ Error creating booking request: $e');
      rethrow;
    }
  }

  /// Get all booking requests for a tutor (including Trial Sessions)
  static Future<List<BookingRequest>> getTutorBookingRequests({
    String? status,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      print('🔍 Fetching all requests for tutor: $userId');

      // 1. Fetch Recurring Booking Requests
      var bookingQuery = SupabaseService.client
          .from('booking_requests')
          .select('*')
          .eq('tutor_id', userId);

      if (status != null && status != 'all') {
        bookingQuery = bookingQuery.eq('status', status);
      }

      final bookingResponse = await bookingQuery.order('created_at', ascending: false);
      final bookingList = (bookingResponse as List).map((json) {
        try {
          return BookingRequest.fromJson(json);
        } catch (e) {
          print('Error parsing booking request: $e');
          return null;
        }
      }).whereType<BookingRequest>().toList();

      // 2. Fetch Trial Sessions
      List<BookingRequest> trialList = [];
      try {
        var trialQuery = SupabaseService.client
            .from('trial_sessions')
            // Use learner_id for the join relation as there is no student_id column
            // Also fetch email so we always have a meaningful identifier
            .select(
              '*, student:profiles!learner_id(full_name, avatar_url, user_type, email)',
            )
            .eq('tutor_id', userId);

          if (status != null && status != 'all') {
          // If filtering for pending, we should also include 'pending_payment' if that's a valid status for tutor action
          // But sticking to 'pending' for now as that's likely what the tutor needs to approve
          trialQuery = trialQuery.eq('status', status);
        }

        final trialResponse = await trialQuery.order('created_at', ascending: false);
        trialList = (trialResponse as List).map((json) {
          try {
            final studentProfile = json['student'] as Map<String, dynamic>? ?? {};
            return BookingRequest.fromTrialSession(json, studentProfile, null);
          } catch (e) {
            print('Error parsing trial session: $e');
            return null;
          }
        }).whereType<BookingRequest>().toList();
      } catch (e) {
        print('❌ Error fetching trial sessions: $e');
        // Continue with just booking list if trials fail
      }

      // 3. Merge and Sort
      final allRequests = [...bookingList, ...trialList];
      allRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first

      print('✅ Found ${allRequests.length} total requests (${bookingList.length} recurring, ${trialList.length} trials)');
      return allRequests;

    } catch (e) {
      print('❌ Error fetching tutor requests: $e');
      return []; 
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

      // Create payment request when tutor approves
      String? paymentRequestId;
      try {
        paymentRequestId =
            await PaymentRequestService.createPaymentRequestOnApproval(
              bookingRequest,
            );
        print(
          '✅ Payment request created for approved booking: $paymentRequestId',
        );
      } catch (e) {
        print('⚠️ Failed to create payment request: $e');
      }

      // Send notification to student
      try {
        final tutorName = request.tutorName;
        final subject = 'Tutoring Sessions';
        await NotificationHelperService.notifyBookingRequestAccepted(
          studentId: request.studentId,
          tutorId: request.tutorId,
          requestId: requestId,
          tutorName: tutorName,
          subject: subject,
          paymentRequestId: paymentRequestId,
          senderAvatarUrl: request.tutorAvatarUrl,
        );
      } catch (e) {
        print('⚠️ Failed to send booking acceptance notification: $e');
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
          senderAvatarUrl: request.tutorAvatarUrl,
        );
      } catch (e) {
        print('⚠️ Failed to send booking rejection notification: $e');
      }

      return bookingRequest;
    } catch (e) {
      print('❌ Error rejecting booking request: $e');
      rethrow;
    }
  }

  /// Approve a Trial Session
  static Future<void> approveTrialRequest(String sessionId, {String? responseNotes}) async {
    try {
      print('Approving trial session: $sessionId');
      
      // 1. Update status
      // NOTE: Column name in DB is `tutor_response_notes` (not `tutor_response`)
      final updateData = {
        'status': 'approved',
        'responded_at': DateTime.now().toIso8601String(),
        'tutor_response_notes': responseNotes,
      };

      // Update trial session without join (no FK relationship in DB)
      final updatedSession = await SupabaseService.client
          .from('trial_sessions')
          .update(updateData)
          .eq('id', sessionId)
          .select()
          .single();

      print('✅ Trial session status updated to approved');

      // Fetch student profile separately using learner_id
      final learnerId = updatedSession['learner_id'] as String;
      final studentProfile = await SupabaseService.client
              .from('profiles')
              .select('full_name, avatar_url, user_type')
              .eq('id', learnerId)
              .maybeSingle() as Map<String, dynamic>? ??
          <String, dynamic>{};

      // 2. Build a BookingRequest representation of this trial
      final bookingRequest =
          BookingRequest.fromTrialSession(updatedSession, studentProfile, null);

      // 3. Create Payment Request (non‑blocking for notifications)
      String? paymentRequestId;
      try {
        paymentRequestId =
            await PaymentRequestService.createPaymentRequestOnApproval(
          bookingRequest,
        );
        print('✅ Payment request created for trial: $paymentRequestId');
      } catch (e) {
        print('⚠️ Error creating payment request for trial: $e');
        // We still want to notify the learner that the trial was approved
      }

      // 4. Notify Student (always attempt, even if payment request failed)
      try {
        // Fetch tutor profile for avatar + display name
        final tutorId = SupabaseService.currentUser!.id;
        final tutorProfile = await SupabaseService.client
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', tutorId)
            .maybeSingle();

        final tutorName = tutorProfile?['full_name'] as String? ?? 'Your Tutor';
        final tutorAvatarUrl = tutorProfile?['avatar_url'] as String?;

        // Reuse booking accepted notification so student can jump straight to payment
        await NotificationHelperService.notifyBookingRequestAccepted(
          studentId: bookingRequest.studentId,
          tutorId: bookingRequest.tutorId,
          requestId: sessionId,
          tutorName: tutorName,
          subject: 'Trial Session: ${bookingRequest.subject ?? "Tutoring"}',
          paymentRequestId: paymentRequestId,
          senderAvatarUrl: tutorAvatarUrl,
        );
      } catch (e) {
        print('⚠️ Error sending approval notification for trial: $e');
      }
    } catch (e) {
      print('❌ Error approving trial request: $e');
      rethrow;
    }
  }

  /// Reject a Trial Session
  static Future<void> rejectTrialRequest(String sessionId, {required String reason}) async {
    try {
      print('Rejecting trial session: $sessionId');
      
      final updateData = {
        'status': 'rejected',
        'responded_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
      };

      // Update trial session without join (no FK relationship in DB)
      final updatedSession = await SupabaseService.client
          .from('trial_sessions')
          .update(updateData)
          .eq('id', sessionId)
          .select()
          .single();

      print('✅ Trial session rejected');

      // Fetch student profile separately using learner_id
      final learnerId = updatedSession['learner_id'] as String;
      final studentProfile = await SupabaseService.client
          .from('profiles')
          .select('full_name, avatar_url, user_type')
          .eq('id', learnerId)
          .maybeSingle() as Map<String, dynamic>? ??
          <String, dynamic>{};

      // Notify Student
      try {
        final bookingRequest = BookingRequest.fromTrialSession(
          updatedSession, 
          studentProfile, 
          null
        );
        
        // Fetch tutor profile for avatar
        final tutorId = SupabaseService.currentUser!.id;
        final tutorProfile = await SupabaseService.client
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', tutorId)
            .maybeSingle();
        
        final tutorName = tutorProfile?['full_name'] as String? ?? 'Your Tutor';
        final tutorAvatarUrl = tutorProfile?['avatar_url'] as String?;
        
        await NotificationHelperService.notifyBookingRequestRejected(
          studentId: bookingRequest.studentId,
          tutorId: bookingRequest.tutorId,
          requestId: sessionId,
          tutorName: tutorName,
          rejectionReason: reason,
          senderAvatarUrl: tutorAvatarUrl,
        );
      } catch (e) {
        print('⚠️ Error sending rejection notification: $e');
      }
    } catch (e) {
      print('❌ Error rejecting trial request: $e');
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
