import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/payment/services/fapshi_service.dart';
import 'package:prepskul/features/sessions/services/meet_service.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/core/services/google_calendar_service.dart';

/// TrialSessionService
///
/// Handles all trial session operations:
/// - Creating trial requests
/// - Fetching trial sessions
/// - Approving/rejecting trials (tutor side)
/// - Managing trial lifecycle
class TrialSessionService {
  static final _supabase = SupabaseService.client;

  /// Create a new trial session request
  static Future<TrialSession> createTrialRequest({
    required String tutorId,
    required String subject,
    required DateTime scheduledDate,
    required String scheduledTime,
    required int durationMinutes,
    required String location,
    String? address,
    String? locationDescription,
    String? trialGoal,
    String? learnerChallenges,
    String? learnerLevel,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Normalize location to match database constraint: 'online' or 'onsite' (lowercase only)
      // Trial sessions only support 'online' and 'onsite', not 'hybrid'
      String normalizedLocation;
      final locationLower = location.trim().toLowerCase();
      if (locationLower.isEmpty || locationLower == 'online') {
        normalizedLocation = 'online';
      } else if (locationLower == 'onsite' || locationLower == 'on-site') {
        normalizedLocation = 'onsite';
      } else if (locationLower == 'hybrid') {
        // Hybrid not supported for trials - default to online
        normalizedLocation = 'online';
      } else {
        // Fallback to online for any other value
        normalizedLocation = 'online';
      }
      final isOnline = normalizedLocation == 'online';

      // Get trial fee from database (admin-controlled pricing)
      final trialFee = await PricingService.getTrialSessionPrice(
        durationMinutes,
      );

      // Get user profile to determine if parent or student
      final userProfile = await _supabase
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .single();

      final userType = userProfile['user_type'] as String;
      final isParent = userType == 'parent';

      // DEMO MODE FIX: If tutorId is not a valid UUID (e.g., "tutor_001"),
      // use the current user's ID as a placeholder for testing
      // In production, this will be a real tutor's UUID
      String validTutorId = tutorId;
      if (!_isValidUUID(tutorId)) {
        print('⚠️ DEMO MODE: Using user ID as tutor ID for testing');
        validTutorId = userId; // Use self as tutor for demo
      }

      // Check if user already has an active trial session with this tutor
      // Check for pending, approved, or scheduled trials
      final pendingTrials = await _supabase
          .from('trial_sessions')
          .select('id, status, scheduled_date, scheduled_time')
          .eq('tutor_id', validTutorId)
          .eq('requester_id', userId)
          .eq('status', 'pending')
          .maybeSingle();

      final approvedTrials = await _supabase
          .from('trial_sessions')
          .select('id, status, scheduled_date, scheduled_time')
          .eq('tutor_id', validTutorId)
          .eq('requester_id', userId)
          .eq('status', 'approved')
          .maybeSingle();

      final scheduledTrials = await _supabase
          .from('trial_sessions')
          .select('id, status, scheduled_date, scheduled_time')
          .eq('tutor_id', validTutorId)
          .eq('requester_id', userId)
          .eq('status', 'scheduled')
          .maybeSingle();

      Map<String, dynamic>? existingTrial;
      if (pendingTrials != null) {
        existingTrial = pendingTrials;
      } else if (approvedTrials != null) {
        existingTrial = approvedTrials;
      } else if (scheduledTrials != null) {
        existingTrial = scheduledTrials;
      }

      if (existingTrial != null) {
        final status = existingTrial['status'] as String;
        final scheduledDate = existingTrial['scheduled_date'] as String?;
        final scheduledTime = existingTrial['scheduled_time'] as String?;

        String message =
            'You already have an active trial session with this tutor';
        if (status == 'pending') {
          message =
              'You already have a pending trial session request with this tutor. Please wait for the tutor to respond or complete your existing trial before booking another one.';
        } else if (status == 'approved') {
          message =
              'You already have an approved trial session with this tutor';
          if (scheduledDate != null && scheduledTime != null) {
            message += ' scheduled for $scheduledDate at $scheduledTime';
          }
          message += '. Please complete this trial before booking another one.';
        } else if (status == 'scheduled') {
          message =
              'You already have a scheduled trial session with this tutor';
          if (scheduledDate != null && scheduledTime != null) {
            message += ' on $scheduledDate at $scheduledTime';
          }
          message += '. Please complete this trial before booking another one.';
        }

        throw Exception(message);
      }

      // Create trial session data
      final trialData = {
        'tutor_id': validTutorId,
        'learner_id': userId,
        'parent_id': isParent ? userId : null,
        'requester_id': userId,
        'subject': subject,
        'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
        'scheduled_time': scheduledTime,
        'duration_minutes': durationMinutes,
        'location': normalizedLocation,
        // For online trials, ignore physical address fields
        'onsite_address': isOnline ? null : address,
        'location_description': isOnline ? null : locationDescription,
        'trial_goal': trialGoal,
        'learner_challenges': learnerChallenges,
        'learner_level': learnerLevel,
        'status': 'pending',
        'trial_fee': trialFee,
        'payment_status': 'unpaid',
        'converted_to_recurring': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Insert into database
      final response = await _supabase
          .from('trial_sessions')
          .insert(trialData)
          .select()
          .single();

      final trialSession = TrialSession.fromJson(response);

      // Get student name for notification
      final studentProfile = await _supabase
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      final studentName = studentProfile?['full_name'] as String? ?? 'Student';
      final studentAvatarUrl = studentProfile?['avatar_url'] as String?;

      // Send notification to tutor
      try {
        await NotificationHelperService.notifyTrialRequestCreated(
          tutorId: validTutorId,
          studentId: userId,
          trialId: trialSession.id,
          studentName: studentName,
          subject: subject,
          scheduledDate: scheduledDate,
          scheduledTime: scheduledTime,
          senderAvatarUrl: studentAvatarUrl,
        );
      } catch (e) {
        print('⚠️ Failed to send trial request notification: $e');
        // Don't fail the trial creation if notification fails
      }

      return trialSession;
    } catch (e) {
      print('❌ Trial booking error: $e');
      throw Exception('Failed to create trial request: $e');
    }
  }

  /// Helper to validate UUID format
  static bool _isValidUUID(String value) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(value);
  }

  /// Get all trial sessions for a student/parent
  static Future<List<TrialSession>> getStudentTrialSessions({
    String? status,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      var query = _supabase
          .from('trial_sessions')
          .select() // Select all fields including payment_status
          .eq('requester_id', userId);

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      final trials = (response as List)
          .map((json) {
            // Debug: Log payment_status from DB
            print('🔍 DB payment_status for ${json['id']}: ${json['payment_status']}');
            return TrialSession.fromJson(json);
          })
          .toList();
      
      // Debug: Log after mapping
      for (var trial in trials) {
        print('🔍 Mapped trial ${trial.id}: paymentStatus=${trial.paymentStatus}');
      }
      
      return trials;
    } catch (e) {
      throw Exception('Failed to fetch trial sessions: $e');
    }
  }

  /// Get all trial sessions for a tutor
  static Future<List<TrialSession>> getTutorTrialSessions({
    String? status,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      var query = _supabase
          .from('trial_sessions')
          .select()
          .eq('tutor_id', userId);

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((json) => TrialSession.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch tutor trial sessions: $e');
    }
  }

  /// Approve a trial session (tutor)
  static Future<TrialSession> approveTrialSession(
    String sessionId, {
    String? responseNotes,
  }) async {
    try {
      // Get trial session first
      final trialResponse = await _supabase
          .from('trial_sessions')
          .select()
          .eq('id', sessionId)
          .single();

      final updateData = {
        'status': 'approved',
        'responded_at': DateTime.now().toIso8601String(),
        'tutor_response_notes': responseNotes,
      };

      final updated = await _supabase
          .from('trial_sessions')
          .update(updateData)
          .eq('id', sessionId)
          .select()
          .single();

      final trialSession = TrialSession.fromJson(updated);

      // Get tutor name for notification
      final tutorProfile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', trialSession.tutorId)
          .maybeSingle();

      final tutorName = tutorProfile?['full_name'] as String? ?? 'Tutor';

      // Parse scheduled date and time
      final scheduledDate = DateTime.parse(
        trialResponse['scheduled_date'] as String,
      );
      final scheduledTime = trialResponse['scheduled_time'] as String;
      final subject = trialResponse['subject'] as String;

      // Send notification to student
      try {
        await NotificationHelperService.notifyTrialRequestAccepted(
          studentId: trialSession.learnerId,
          tutorId: trialSession.tutorId,
          trialId: sessionId,
          tutorName: tutorName,
          subject: subject,
          scheduledDate: scheduledDate,
          scheduledTime: scheduledTime,
        );
      } catch (e) {
        print('⚠️ Failed to send trial acceptance notification: $e');
        // Don't fail the approval if notification fails
      }

      return trialSession;
    } catch (e) {
      throw Exception('Failed to approve trial session: $e');
    }
  }

  /// Reject a trial session (tutor)
  static Future<TrialSession> rejectTrialSession(
    String sessionId, {
    required String reason,
  }) async {
    try {
      final updateData = {
        'status': 'rejected',
        'responded_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
      };

      final updated = await _supabase
          .from('trial_sessions')
          .update(updateData)
          .eq('id', sessionId)
          .select()
          .single();

      final trialSession = TrialSession.fromJson(updated);

      // Get tutor name for notification
      final tutorProfile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', trialSession.tutorId)
          .maybeSingle();

      final tutorName = tutorProfile?['full_name'] as String? ?? 'Tutor';

      // Send notification to student
      try {
        await NotificationHelperService.notifyTrialRequestRejected(
          studentId: trialSession.learnerId,
          tutorId: trialSession.tutorId,
          trialId: sessionId,
          tutorName: tutorName,
          rejectionReason: reason,
        );
      } catch (e) {
        print('⚠️ Failed to send trial rejection notification: $e');
        // Don't fail the rejection if notification fails
      }

      return trialSession;
    } catch (e) {
      throw Exception('Failed to reject trial session: $e');
    }
  }

  /// Cancel a trial session (updates status to cancelled)
  /// Use this for sessions that have been approved or responded to
  static Future<void> cancelTrialSession(String sessionId) async {
    try {
      await _supabase
          .from('trial_sessions')
          .update({'status': 'cancelled'})
          .eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to cancel trial session: $e');
    }
  }

  /// Cancel an approved trial session (by parent/student)
  /// Updates status to 'cancelled' and notifies tutor with reason
  /// For pending sessions, use deleteTrialSession instead
  static Future<void> cancelApprovedTrialSession({
    required String sessionId,
    required String cancellationReason,
  }) async {
    try {
      // Get trial session details
      final session = await _supabase.from('trial_sessions').select(
        'status, tutor_id, learner_id, parent_id, requester_id, subject, scheduled_date, scheduled_time, payment_status, calendar_event_id',
      ).eq('id', sessionId).maybeSingle();

      if (session == null) {
        throw Exception('Trial session not found');
      }

      final status = session['status'] as String?;
      if (status == 'pending') {
        throw Exception(
          'Cannot cancel pending session. Use deleteTrialSession instead.',
        );
      }

      if (status == 'cancelled' || status == 'completed') {
        throw Exception('Trial session is already ${status}.');
      }

      final tutorId = session['tutor_id'] as String;
      final learnerId = session['learner_id'] as String;
      final subject = session['subject'] as String;
      final scheduledDate = session['scheduled_date'] as String;
      final scheduledTime = session['scheduled_time'] as String;

      // Update status to cancelled with reason
      final now = DateTime.now().toIso8601String();
      await _supabase
          .from('trial_sessions')
          .update({
            'status': 'cancelled',
            'rejection_reason':
                cancellationReason, // Reuse this field for cancellation reason
            'updated_at': now,
          })
          .eq('id', sessionId);

      // Get requester name for notification
      final requesterProfile = await _supabase
          .from('profiles')
          .select('full_name, user_type')
          .eq('id', session['requester_id'] as String)
          .maybeSingle();

      final requesterName =
          requesterProfile?['full_name'] as String? ?? 'Student/Parent';
      final requesterType =
          requesterProfile?['user_type'] as String? ?? 'student';

      // Notify tutor about cancellation
      try {
        await NotificationHelperService.notifyTrialSessionCancelled(
          tutorId: tutorId,
          studentId: learnerId,
          trialId: sessionId,
          studentName: requesterName,
          subject: subject,
          scheduledDate: DateTime.parse(scheduledDate),
          scheduledTime: scheduledTime,
          cancellationReason: cancellationReason,
          cancelledBy: requesterType,
        );
      } catch (e) {
        print('⚠️ Failed to send cancellation notification to tutor: $e');
        // Don't fail cancellation if notification fails
      }

      // Cancel calendar event if one exists
      final calendarEventId = session['calendar_event_id'] as String?;
      if (calendarEventId != null && calendarEventId.isNotEmpty) {
        try {
          await GoogleCalendarService.cancelEvent(calendarEventId);
          print('✅ Calendar event cancelled for trial: $sessionId');
        } catch (e) {
          print('⚠️ Failed to cancel calendar event for trial $sessionId: $e');
        }
      }

      print('✅ Trial session cancelled: $sessionId');
    } catch (e) {
      print('❌ Error cancelling trial session: $e');
      rethrow;
    }
  }

  /// Delete a trial session (permanently removes from database)
  /// Only allowed for pending sessions (tutor hasn't approved yet)
  /// Also deletes associated payment records
  /// For approved sessions, use cancelApprovedTrialSession instead
  static Future<void> deleteTrialSession(String sessionId) async {
    try {
      // First check if the session is pending
      final session = await _supabase
          .from('trial_sessions')
          .select('status, payment_status, fapshi_trans_id')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Trial session not found');
      }

      final status = session['status'] as String?;
      if (status != 'pending') {
        throw Exception(
          'Cannot delete trial session. Only pending sessions can be deleted. For approved sessions, please cancel instead.',
        );
      }

      final fapshiTransId = session['fapshi_trans_id'] as String?;

      // Delete any associated payment records if they exist
      // Check if there's a payment record in payment_requests table (if exists)
      if (fapshiTransId != null && fapshiTransId.isNotEmpty) {
        try {
          // Try to find and delete any payment_requests with matching external_id
          // Payment requests might have external_id in metadata or as fapshi_trans_id
          await _supabase
              .from('payment_requests')
              .delete()
              .eq('fapshi_trans_id', fapshiTransId);

          print('✅ Deleted associated payment request: $fapshiTransId');
        } catch (e) {
          // If payment_requests table doesn't exist or record not found, that's okay
          // Trial payments are primarily stored in trial_sessions table
          print('ℹ️ No payment_requests record to delete: $e');
        }
      }

      // Delete any notifications related to this trial session
      try {
        await _supabase.from('notifications').delete().contains('metadata', {
          'trial_session_id': sessionId,
        });

        print('✅ Deleted associated notifications');
      } catch (e) {
        // If notifications table doesn't have this field or query fails, that's okay
        print('ℹ️ Could not delete notifications (might not exist): $e');
      }

      // Delete the trial session itself (this also removes all payment info stored in it)
      await _supabase.from('trial_sessions').delete().eq('id', sessionId);

      print('✅ Trial session deleted: $sessionId');
    } catch (e) {
      print('❌ Error deleting trial session: $e');
      // If it's a foreign key constraint or similar, provide a better message
      if (e.toString().contains('foreign key') ||
          e.toString().contains('constraint')) {
        throw Exception(
          'Cannot delete trial session. It may have related records that prevent deletion.',
        );
      }
      throw Exception('Failed to delete trial session: $e');
    }
  }

  /// Mark trial as completed
  static Future<void> completeTrialSession(String sessionId) async {
    try {
      await _supabase
          .from('trial_sessions')
          .update({'status': 'completed'})
          .eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to complete trial session: $e');
    }
  }

  /// Mark trial as converted to recurring booking
  static Future<void> markAsConverted(
    String sessionId,
    String recurringSessionId,
  ) async {
    try {
      await _supabase
          .from('trial_sessions')
          .update({
            'converted_to_recurring': true,
            'recurring_session_id': recurringSessionId,
          })
          .eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to mark trial as converted: $e');
    }
  }

  /// Initiate payment for trial session
  ///
  /// Starts payment process and updates trial session with transaction ID
  ///
  /// Parameters:
  /// - [sessionId]: Trial session ID
  /// - [phoneNumber]: Student/parent phone number
  ///
  /// Returns: Fapshi transaction ID
  static Future<String> initiatePayment({
    required String sessionId,
    required String phoneNumber,
    TrialSession? trialSession, // Optional: pass if already available to avoid fetch
  }) async {
    try {
      // Get trial session (use provided or fetch)
      final trial = trialSession ?? await getTrialSessionById(sessionId);

      // Guard: only allow payment after tutor has approved the trial
      if (trial.status != 'approved' && trial.status != 'scheduled') {
        throw Exception(
          'You can only pay after the tutor has approved the trial session.',
        );
      }

      if (trial.paymentStatus == 'paid') {
        throw Exception('Payment already completed');
      }

      // Initiate payment
      final paymentResponse = await FapshiService.initiateDirectPayment(
        amount: trial.trialFee.round(),
        phone: phoneNumber,
        externalId: 'trial_$sessionId',
        userId: trial.learnerId,
        message: 'Trial session fee - ${trial.subject}',
      );

      // Update trial session with transaction ID
      await _supabase
          .from('trial_sessions')
          .update({
            'fapshi_trans_id': paymentResponse.transId,
            'payment_initiated_at': DateTime.now().toIso8601String(),
            'payment_status': 'pending',
          })
          .eq('id', sessionId);

      return paymentResponse.transId;
    } catch (e) {
      print('❌ Error initiating payment: $e');
      rethrow;
    }
  }

  /// Complete payment and generate Meet link
  ///
  /// Called after payment is verified (via webhook or polling)
  /// Updates payment status and generates Meet link
  ///
  /// Parameters:
  /// - [sessionId]: Trial session ID
  /// - [transactionId]: Fapshi transaction ID
  /// Returns:
  /// - `true` if a Meet link was created and calendar setup succeeded
  /// - `false` if payment was saved but Meet/Calendar setup failed (session is still created)
  static Future<bool> completePaymentAndGenerateMeet({
    required String sessionId,
    required String transactionId,
  }) async {
    try {
      // Get trial session
      final trial = await getTrialSessionById(sessionId);

      // Update payment status
      await _supabase
          .from('trial_sessions')
          .update({'payment_status': 'paid', 'fapshi_trans_id': transactionId})
          .eq('id', sessionId);

      // Parse scheduled date and time
      // scheduledDate is already a DateTime in the model
      final scheduledDate = trial.scheduledDate;
      final scheduledTime = trial.scheduledTime;

      // Try to generate Meet link via Google Calendar (best effort).
      // Even if this fails (e.g. calendar not connected), we still
      // create the session so the learner can see it in "My Sessions".
      String? meetLink;
      var calendarOk = true;
      try {
        meetLink = await MeetService.generateTrialMeetLink(
          trialSessionId: sessionId,
          tutorId: trial.tutorId,
          studentId: trial.learnerId,
          scheduledDate: scheduledDate,
          scheduledTime: scheduledTime,
          durationMinutes: trial.durationMinutes,
        );
      } catch (e) {
        calendarOk = false;
        meetLink = null;
        print(
          '⚠️ Failed to generate Meet link for trial $sessionId (payment already saved): $e',
        );
      }

      // Update trial_sessions with meet_link (even if null, so it's accessible)
      await _supabase
          .from('trial_sessions')
          .update({'meet_link': meetLink})
          .eq('id', sessionId);

      // Create an individual session instance so trial appears in upcoming sessions
      try {
        await _supabase.from('individual_sessions').insert({
          'recurring_session_id': null,
          'tutor_id': trial.tutorId,
          'learner_id': trial.learnerId,
          'parent_id': trial.parentId,
          'status': 'scheduled',
          'scheduled_date':
              scheduledDate?.toIso8601String().split('T')[0] ??
                  trial.scheduledDate.toIso8601String().split('T')[0],
          'scheduled_time': scheduledTime,
          'subject': trial.subject,
          'duration_minutes': trial.durationMinutes,
          'location': trial.location,
          'meeting_link': meetLink,
          'address': null,
          'location_description': null,
        });
      } catch (e) {
        print(
          '⚠️ Error creating individual session for trial (will still keep trial record): $e',
        );
      }

      // Send notification to student and tutor
      final studentMessage = calendarOk
          ? 'Your trial session payment has been confirmed. Meet link is now available.'
          : 'Your trial session payment has been confirmed. Your lesson will appear under "My Sessions". '
              'You can still join from there even if Google Calendar is not connected.';

      final tutorMessage = calendarOk
          ? 'Student has completed payment for the trial session. Meet link generated.'
          : 'Student has completed payment for the trial session. The session is saved, but Google Calendar is not connected.';

      await NotificationService.createNotification(
        userId: trial.learnerId,
        type: 'trial_payment_completed',
        title: 'Payment Successful',
        message: studentMessage,
      );

      await NotificationService.createNotification(
        userId: trial.tutorId,
        type: 'trial_payment_completed',
        title: 'Trial Payment Received',
        message: tutorMessage,
      );

      print(
        '✅ Payment completed for trial: $sessionId (calendarOk=$calendarOk)',
      );

      return calendarOk;
    } catch (e) {
      print('❌ Error completing payment: $e');
      rethrow;
    }
  }

  /// Get single trial session by ID with retry logic
  static Future<TrialSession> getTrialSessionById(String sessionId) async {
    int maxRetries = 3;
    int retryDelay = 1000; // milliseconds
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await _supabase
            .from('trial_sessions')
            .select()
            .eq('id', sessionId)
            .single();

        return TrialSession.fromJson(response);
      } catch (e) {
        // Check if it's a network error
        final errorString = e.toString().toLowerCase();
        final isNetworkError = errorString.contains('failed to fetch') ||
            errorString.contains('clientexception') ||
            errorString.contains('network') ||
            errorString.contains('connection');
        
        if (isNetworkError && attempt < maxRetries) {
          print('⚠️ Network error fetching trial session (attempt $attempt/$maxRetries), retrying...');
          await Future.delayed(Duration(milliseconds: retryDelay * attempt));
          continue;
        }
        
        // If it's the last attempt or not a network error, throw
        print('❌ Failed to fetch trial session after $attempt attempts: $e');
        throw Exception('Failed to fetch trial session: ${e.toString()}');
      }
    }
    
    // Should never reach here, but just in case
    throw Exception('Failed to fetch trial session after $maxRetries attempts');
  }

  /// Get upcoming trial sessions (for dashboard)
  static Future<List<TrialSession>> getUpcomingTrials() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final response = await _supabase
          .from('trial_sessions')
          .select()
          .or('requester_id.eq.$userId,tutor_id.eq.$userId')
          .inFilter('status', ['approved', 'scheduled'])
          .gte('scheduled_date', today.toIso8601String().split('T')[0])
          .order('scheduled_date', ascending: true)
          .limit(5);

      return (response as List)
          .map((json) => TrialSession.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch upcoming trials: $e');
    }
  }
}
