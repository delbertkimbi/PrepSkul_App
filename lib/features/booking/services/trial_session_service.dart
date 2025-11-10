import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/payment/services/fapshi_service.dart';
import 'package:prepskul/features/sessions/services/meet_service.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';

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

      // Calculate trial fee based on duration
      // Base: 30 min = 2000 XAF, 60 min = 3500 XAF
      final trialFee = durationMinutes == 30 ? 2000.0 : 3500.0;

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
        'location': location,
        'onsite_address': address, // Use onsite_address instead of address
        'location_description': locationDescription,
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
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      final studentName = studentProfile?['full_name'] as String? ?? 'Student';

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
          .select()
          .eq('requester_id', userId);

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((json) => TrialSession.fromJson(json))
          .toList();
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
      // Get trial session first
      final trialResponse = await _supabase
          .from('trial_sessions')
          .select()
          .eq('id', sessionId)
          .single();

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

  /// Cancel a trial session (student/parent)
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
  }) async {
    try {
      // Get trial session
      final trial = await getTrialSessionById(sessionId);

      if (trial.paymentStatus == 'paid') {
        throw Exception('Payment already completed');
      }

      // Initiate payment
      final paymentResponse = await FapshiService.initiateDirectPayment(
        amount: trial.trialFee.toInt(),
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
  static Future<void> completePaymentAndGenerateMeet({
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

      // Generate Meet link
      await MeetService.generateTrialMeetLink(
        trialSessionId: sessionId,
        tutorId: trial.tutorId,
        studentId: trial.learnerId,
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
        durationMinutes: trial.durationMinutes,
      );

      // Send notification to student and tutor
      await NotificationService.createNotification(
        userId: trial.learnerId,
        type: 'trial_payment_completed',
        title: 'Payment Successful',
        message:
            'Your trial session payment has been confirmed. Meet link is now available.',
      );

      await NotificationService.createNotification(
        userId: trial.tutorId,
        type: 'trial_payment_completed',
        title: 'Trial Payment Received',
        message:
            'Student has completed payment for trial session. Meet link generated.',
      );

      print(
        '✅ Payment completed and Meet link generated for trial: $sessionId',
      );
    } catch (e) {
      print('❌ Error completing payment: $e');
      rethrow;
    }
  }

  /// Get single trial session by ID
  static Future<TrialSession> getTrialSessionById(String sessionId) async {
    try {
      final response = await _supabase
          .from('trial_sessions')
          .select()
          .eq('id', sessionId)
          .single();

      return TrialSession.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch trial session: $e');
    }
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
