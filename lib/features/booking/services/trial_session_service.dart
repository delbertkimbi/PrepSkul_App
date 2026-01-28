import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/features/booking/services/booking_service.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/payment/services/fapshi_service.dart';
import 'package:prepskul/features/sessions/services/meet_service.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/features/booking/utils/session_date_utils.dart';
import 'package:prepskul/core/services/google_calendar_service.dart';
import 'package:prepskul/core/services/google_calendar_auth_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/features/messaging/services/conversation_lifecycle_service.dart';
import 'package:flutter/foundation.dart';

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
    double? overrideTrialFee, // Optional: Use this fee instead of fetching from DB (for discounts)
    String? rescheduleSessionId, // Optional: ID of the session being rescheduled
    String? learnerId, // Optional: For parents, specify which learner (child) to book for
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

      // Get trial fee - use override if provided (for discounts), otherwise fetch from DB
      final trialFee = overrideTrialFee ?? await PricingService.getTrialSessionPrice(
        durationMinutes,
      );

      // Get user profile to determine if parent or student
      // FIX: Use .limit(1) to handle potential duplicate profiles (from role switching issues)
      final userProfileResponse = await _supabase
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .limit(1)
          .maybeSingle();
      
      if (userProfileResponse == null) {
        throw Exception('User profile not found');
      }
      
      final userProfile = userProfileResponse;

      final userType = userProfile['user_type'] as String;
      final isParent = userType == 'parent';

      // FIX: For parents, determine the actual learner (child) ID
      // If learnerId is provided, use it; otherwise, for parents, we need to handle this
      String actualLearnerId = learnerId ?? userId;
      
      // If parent and no learnerId provided, check if parent has linked learners
      // For now, if parent books, we'll use parent's ID as learner_id (parent can attend)
      // TODO: In future, add UI for parents to select which child they're booking for
      if (isParent && learnerId == null) {
        // For now, allow parent to book for themselves (they can attend the session)
        // This is a temporary solution until we add child selection UI
        actualLearnerId = userId;
        LogService.info('Parent booking trial session - using parent ID as learner_id (temporary)');
      }

      // DEMO MODE FIX: If tutorId is not a valid UUID (e.g., "tutor_001"),
      // use the current user's ID as a placeholder for testing
      // In production, this will be a real tutor's UUID
      String validTutorId = tutorId;
      if (!_isValidUUID(tutorId)) {
        LogService.warning('DEMO MODE: Using user ID as tutor ID for testing');
        validTutorId = userId; // Use self as tutor for demo
      }

      // Check if user already has an active trial session with this tutor
      // Skip this check if we're rescheduling an existing session (rescheduleSessionId is provided)
      if (rescheduleSessionId == null) {
      // Check for pending trials (always block pending regardless of date)
      final pendingTrials = await _supabase
          .from('trial_sessions')
          .select('id, status, scheduled_date, scheduled_time')
          .eq('tutor_id', validTutorId)
          .eq('requester_id', userId)
          .eq('status', 'pending')
          .limit(1)
          .maybeSingle();

      if (pendingTrials != null) {
        final message =
            'You already have a pending trial session request with this tutor. Please wait for the tutor to respond or complete your existing trial before booking another one.';
        
        // In debug mode, allow multiple trials but log a warning
        if (kDebugMode) {
          LogService.warning('[DEBUG] Multiple trial sessions allowed in debug mode. Original message: $message');
          // Continue with trial creation in debug mode
        } else {
          // In production, enforce the one-trial-per-tutor rule
          throw Exception(message);
        }
      }

      // Check for approved or scheduled trials - only block if they are upcoming (not expired)
      final approvedTrials = await _supabase
          .from('trial_sessions')
          .select('id, status, scheduled_date, scheduled_time')
          .eq('tutor_id', validTutorId)
          .eq('requester_id', userId)
          .or('status.eq.approved,status.eq.scheduled')
          .order('created_at', ascending: false);

      if (approvedTrials.isNotEmpty) {
        // Check each trial to see if it's upcoming
        for (final trialData in approvedTrials) {
          final status = trialData['status'] as String;
          final scheduledDateStr = trialData['scheduled_date'] as String?;
          final scheduledTimeStr = trialData['scheduled_time'] as String?;
          
          // For approved/scheduled trials, only block if they are upcoming
          if (scheduledDateStr != null && scheduledTimeStr != null) {
            try {
              // Parse scheduled date and time
              final scheduledDate = DateTime.parse(scheduledDateStr);
              final timeParts = scheduledTimeStr.split(':');
              final hour = int.tryParse(timeParts[0]) ?? 0;
              final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
              final sessionDateTime = DateTime(
                scheduledDate.year,
                scheduledDate.month,
                scheduledDate.day,
                hour,
                minute,
              );
              
              // Check if session is upcoming (in the future)
              final isUpcoming = sessionDateTime.isAfter(DateTime.now());
              
              if (isUpcoming) {
                // Block booking - trial is upcoming
                String message;
                if (status == 'approved') {
                  message = 'You already have an approved trial session with this tutor';
                  message += ' scheduled for $scheduledDateStr at $scheduledTimeStr';
                  message += '. Please complete this trial before booking another one.';
                } else if (status == 'scheduled') {
                  message = 'You already have a scheduled trial session with this tutor';
                  message += ' on $scheduledDateStr at $scheduledTimeStr';
                  message += '. Please complete this trial before booking another one.';
                } else {
                  message = 'You already have an active trial session with this tutor scheduled for $scheduledDateStr at $scheduledTimeStr. Please complete it before booking another one.';
                }

                // In debug mode, allow multiple trials but log a warning
                if (kDebugMode) {
                  LogService.warning('[DEBUG] Multiple trial sessions allowed in debug mode. Original message: $message');
                  // Continue with trial creation in debug mode
                } else {
                  // In production, enforce the one-trial-per-tutor rule
                  throw Exception(message);
                }
              }
              // If trial is expired, don't block - continue to next trial
            } catch (e) {
              // If parsing fails, assume it's not upcoming and continue
              LogService.warning('Error parsing trial session date/time: $e');
            }
          } else {
            // If no scheduled date/time but status is approved/scheduled, still block
            String message;
            if (status == 'approved') {
              message = 'You already have an approved trial session with this tutor. Please complete this trial before booking another one.';
            } else if (status == 'scheduled') {
              message = 'You already have a scheduled trial session with this tutor. Please complete this trial before booking another one.';
            } else {
              message = 'You already have an active trial session with this tutor. Please complete it before booking another one.';
            }

            // In debug mode, allow multiple trials but log a warning
            if (kDebugMode) {
              LogService.warning('[DEBUG] Multiple trial sessions allowed in debug mode. Original message: $message');
              // Continue with trial creation in debug mode
            } else {
              // In production, enforce the one-trial-per-tutor rule
              throw Exception(message);
            }
          }
        }
      }
      } else {
        // If rescheduling, log that we're skipping the duplicate check
        LogService.debug('Rescheduling session $rescheduleSessionId - skipping duplicate trial check');
      }

      // Check for schedule conflicts with other tutors at the same time
      // Convert scheduledDate to DateTime and get day name
      final sessionDate = DateTime.parse(scheduledDate.toIso8601String().split('T')[0]);
      final dayName = _getDayName(sessionDate);
      final requestedTimes = <String, String>{dayName: scheduledTime};
      final requestedDays = <String>[dayName];
      
      try {
        final studentConflict = await BookingService.checkStudentScheduleConflicts(
          studentId: userId,
          requestedDays: requestedDays,
          requestedTimes: requestedTimes,
        );
        
        if (studentConflict.hasConflict) {
          // Build conflict message
          final conflictMessages = studentConflict.conflictDetails.values.toList();
          final conflictMessage = conflictMessages.join('\n');
          throw Exception(
            'Schedule Conflict: You already have a session scheduled at the same time with another tutor.\n\n$conflictMessage\n\nPlease choose a different time slot.'
          );
        }
      } catch (e) {
        // If conflict check fails, log but don't block - the error might be from the conflict itself
        if (e.toString().contains('Schedule Conflict')) {
          rethrow; // Re-throw conflict errors
        }
        LogService.warning('Error checking trial schedule conflicts: $e');
        // Continue with trial creation if conflict check fails (non-blocking)
      }

      // Create trial session data
      final trialData = {
        'tutor_id': validTutorId,
        'learner_id': actualLearnerId, // Use actual learner ID (child for parents, self for students)
        'parent_id': isParent ? userId : null,
        'requester_id': userId, // Always the person making the request
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
      // Use .limit(1) and handle as list to avoid maybeSingle() issues with multiple rows
      final responseList = await _supabase
          .from('trial_sessions')
          .insert(trialData)
          .select()
          .limit(1);
      
      if (responseList == null || (responseList as List).isEmpty) {
        throw Exception('Failed to create trial session - no response from database');
      }
      
      final response = (responseList as List)[0] as Map<String, dynamic>;

      if (response == null) {
        throw Exception('Failed to create trial session - no response from database');
      }

      final trialSession = TrialSession.fromJson(response);

      // Get student name for notification
      // FIX: Use .limit(1) to handle potential duplicate profiles
      final studentProfile = await _supabase
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', userId)
          .limit(1)
          .maybeSingle();

      final studentName = studentProfile?['full_name'] as String? ?? 'Student';
      final studentAvatarUrl = studentProfile?['avatar_url'] as String?;

      // Send notification to tutor
      try {
        if (rescheduleSessionId != null) {
          // This is a reschedule request - send special notification
        await NotificationHelperService.notifyTrialRequestCreated(
          tutorId: validTutorId,
          studentId: userId,
          trialId: trialSession.id,
          studentName: studentName,
          subject: subject,
          scheduledDate: scheduledDate,
          scheduledTime: scheduledTime,
          senderAvatarUrl: studentAvatarUrl,
            isReschedule: true,
            originalSessionId: rescheduleSessionId,
          );
        } else {
          // Regular trial request
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
        }
      } catch (e) {
        LogService.warning('Failed to send trial request notification: $e');
        // Don't fail the trial creation if notification fails
      }

      // Schedule session countdown reminders for ALL sessions (pending, approved, or paid)
      // Reminders will be sent at 24h, 1h, and 15min before session time
      // This ensures users get notified regardless of session status
      try {
        // Get tutor name
        String tutorName = 'Tutor';
        try {
          // FIX: Use .limit(1) to handle potential duplicate profiles
          final tutorProfile = await _supabase
              .from('profiles')
              .select('full_name')
              .eq('id', validTutorId)
              .limit(1)
              .maybeSingle();
          tutorName = tutorProfile?['full_name'] as String? ?? 'Tutor';
        } catch (e) {
          LogService.warning('Could not fetch tutor name for reminders: $e');
        }

        // Calculate session start datetime
        final timeParts = scheduledTime.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
        final sessionStart = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          hour,
          minute,
        );

        await NotificationHelperService.scheduleSessionReminders(
          tutorId: validTutorId,
          studentId: userId,
          sessionId: trialSession.id,
          sessionType: 'trial',
          tutorName: tutorName,
          studentName: studentName,
          sessionStart: sessionStart,
          subject: subject,
        );
        
        LogService.success('Session countdown reminders scheduled for new trial session: ${trialSession.id}');
      } catch (e) {
        LogService.warning('Failed to schedule session reminders for new trial: $e');
        // Don't fail trial creation if reminder scheduling fails
      }

      return trialSession;
    } catch (e) {
      LogService.error('Trial booking error: $e');
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
            LogService.debug('DB payment_status for ${json['id']}: ${json['payment_status']}');
            return TrialSession.fromJson(json);
          })
          .toList();
      
      // Debug: Log after mapping
      for (var trial in trials) {
        LogService.debug('Mapped trial ${trial.id}: paymentStatus=${trial.paymentStatus}');
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
          .maybeSingle();
      
      if (trialResponse == null) {
        throw Exception('Trial session not found: $sessionId');
      }

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
          .maybeSingle();

      if (updated == null) {
        throw Exception('Failed to update trial session: $sessionId');
      }

      final trialSession = TrialSession.fromJson(updated);

      // Get tutor name for notification
      // FIX: Use .limit(1) to handle potential duplicate profiles
      final tutorProfile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', trialSession.tutorId)
          .limit(1)
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
        LogService.warning('Failed to send trial acceptance notification: $e');
        // Don't fail the approval if notification fails
      }

      // Schedule payment reminder notifications
      try {
        final sessionDateTime = SessionDateUtils.getSessionDateTime(trialSession);
        final paymentDeadline = SessionDateUtils.getPaymentDeadline(trialSession, hoursBefore: 24);
        
        await NotificationHelperService.schedulePaymentReminders(
          studentId: trialSession.learnerId ?? trialSession.requesterId,
          sessionId: sessionId,
          sessionType: 'trial',
          paymentDeadline: paymentDeadline,
          subject: subject,
          amount: trialSession.trialFee,
          currency: 'XAF',
        );
        
        LogService.success('Payment reminders scheduled for trial session: $sessionId');
      } catch (e) {
        LogService.warning('Failed to schedule payment reminders: $e');
        // Don't fail approval if reminder scheduling fails
      }

      // Schedule session countdown reminders (24h, 1h, 15min before session)
      // This works for ALL sessions (approved or not) - reminders will be sent when time comes
      try {
        final sessionDateTime = SessionDateUtils.getSessionDateTime(trialSession);
        
        // Get student name
        String studentName = 'Student';
        try {
          final studentProfile = await _supabase
              .from('profiles')
              .select('full_name')
              .eq('id', trialSession.learnerId ?? trialSession.requesterId)
              .maybeSingle();
          studentName = studentProfile?['full_name'] as String? ?? 'Student';
        } catch (e) {
          LogService.warning('Could not fetch student name for reminders: $e');
        }
        
        await NotificationHelperService.scheduleSessionReminders(
          tutorId: trialSession.tutorId,
          studentId: trialSession.learnerId ?? trialSession.requesterId,
          sessionId: sessionId,
          sessionType: 'trial',
          tutorName: tutorName,
          studentName: studentName,
          sessionStart: sessionDateTime,
          subject: subject,
        );
        
        LogService.success('Session countdown reminders scheduled for trial session: $sessionId');
      } catch (e) {
        LogService.warning('Failed to schedule session reminders: $e');
        // Don't fail approval if reminder scheduling fails
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
          .maybeSingle();

      if (updated == null) {
        throw Exception('Failed to update trial session: $sessionId');
      }

      final trialSession = TrialSession.fromJson(updated);

      // Get tutor name for notification
      // FIX: Use .limit(1) to handle potential duplicate profiles
      final tutorProfile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', trialSession.tutorId)
          .limit(1)
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
        LogService.warning('Failed to send trial rejection notification: $e');
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
      final paymentStatus = session['payment_status'] as String?;
      
      // Only allow cancellation for unpaid sessions
      if (paymentStatus != null && 
          (paymentStatus.toLowerCase() == 'paid' || 
           paymentStatus.toLowerCase() == 'completed')) {
        throw Exception('Cannot cancel a paid session. Please request a date change instead.');
      }
      
      // Check if session has expired (time passed)
      final scheduledDate = session['scheduled_date'] as String;
      final scheduledTime = session['scheduled_time'] as String;
      if (scheduledDate != null && scheduledTime != null) {
        try {
          final dateParts = scheduledDate.split('T')[0].split('-');
          final timeParts = scheduledTime.split(':');
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final day = int.parse(dateParts[2]);
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
          final sessionDateTime = DateTime(year, month, day, hour, minute);
          
          if (sessionDateTime.isBefore(DateTime.now())) {
            throw Exception('Cannot cancel an expired session. It has already passed.');
          }
        } catch (e) {
          // If date parsing fails, continue (don't block cancellation)
        }
      }
      
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
      final sessionScheduledDate = session['scheduled_date'] as String;
      final sessionScheduledTime = session['scheduled_time'] as String;

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
        LogService.warning('Failed to send cancellation notification to tutor: $e');
        // Don't fail cancellation if notification fails
      }

      // Cancel calendar event if one exists
      final calendarEventId = session['calendar_event_id'] as String?;
      if (calendarEventId != null && calendarEventId.isNotEmpty) {
        try {
          await GoogleCalendarService.cancelEvent(calendarEventId);
          LogService.success('Calendar event cancelled for trial: $sessionId');
        } catch (e) {
          LogService.warning('Failed to cancel calendar event for trial $sessionId: $e');
        }
      }

      LogService.success('Trial session cancelled: $sessionId');
    } catch (e) {
      LogService.error('Error cancelling trial session: $e');
      rethrow;
    }
  }

  /// Delete a trial session (permanently removes from database)
  /// Only allowed for pending sessions (tutor hasn't approved yet)
  /// Also deletes associated payment records
  /// For approved sessions, use cancelApprovedTrialSession instead
  /// Delete trial session
  /// 
  /// Rules:
  /// - Pending: Can delete with optional reason
  /// - Approved (unpaid): Can delete with required reason
  /// - Paid: Cannot delete (only modify allowed)
  static Future<void> deleteTrialSession({
    required String sessionId,
    String? reason, // Optional for pending, required for approved
  }) async {
    try {
      // Get session details
      final session = await _supabase
          .from('trial_sessions')
          .select('status, payment_status, tutor_id, learner_id, requester_id, subject, scheduled_date, scheduled_time, fapshi_trans_id')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Trial session not found');
      }

      final status = session['status'] as String?;
      final paymentStatus = session['payment_status'] as String?;
      
      // Paid sessions cannot be deleted
      if (paymentStatus != null && 
          (paymentStatus.toLowerCase() == 'paid' || 
           paymentStatus.toLowerCase() == 'completed')) {
        throw Exception('Cannot delete a paid session. You can only modify it.');
      }
      
      // Approved sessions require a reason
      if (status == 'approved' || status == 'scheduled') {
        if (reason == null || reason.trim().isEmpty) {
          throw Exception('A reason is required to delete an approved session.');
        }
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

          LogService.success('Deleted associated payment request: $fapshiTransId');
        } catch (e) {
          // If payment_requests table doesn't exist or record not found, that's okay
          // Trial payments are primarily stored in trial_sessions table
          LogService.info('No payment_requests record to delete: $e');
        }
      }

      // For approved sessions, mark as cancelled instead of deleting
      if (status == 'approved' || status == 'scheduled') {
        await _supabase
            .from('trial_sessions')
            .update({
              'status': 'cancelled',
              'rejection_reason': reason ?? 'Deleted by student',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', sessionId);
        
        // Notify tutor about deletion
        try {
          final requesterProfile = await _supabase
              .from('profiles')
              .select('full_name, user_type')
              .eq('id', session['requester_id'] as String)
              .maybeSingle();
          
          final requesterName = requesterProfile?['full_name'] as String? ?? 'Student/Parent';
          
          await NotificationHelperService.notifyTrialSessionCancelled(
            tutorId: session['tutor_id'] as String,
            studentId: session['learner_id'] as String,
            trialId: sessionId,
            studentName: requesterName,
            subject: session['subject'] as String,
            scheduledDate: DateTime.parse(session['scheduled_date'] as String),
            scheduledTime: session['scheduled_time'] as String,
            cancellationReason: reason ?? 'Session deleted by student',
            cancelledBy: requesterProfile?['user_type'] as String? ?? 'student',
          );
        } catch (e) {
          LogService.warning('Failed to send deletion notification: $e');
        }
        
        LogService.success('Approved trial session cancelled (deleted): $sessionId');
        return;
      }
      
      // For pending sessions, delete completely
      // Delete any notifications related to this trial session
      try {
        await _supabase.from('notifications').delete().contains('metadata', {
          'trial_session_id': sessionId,
        });

        LogService.success('Deleted associated notifications');
      } catch (e) {
        // If notifications table doesn't have this field or query fails, that's okay
        LogService.info('Could not delete notifications (might not exist): $e');
      }

      // Notify tutor about pending session deletion (optional reason)
      if (reason != null && reason.trim().isNotEmpty) {
        try {
          final requesterProfile = await _supabase
              .from('profiles')
              .select('full_name')
              .eq('id', session['requester_id'] as String)
              .maybeSingle();
          
          final requesterName = requesterProfile?['full_name'] as String? ?? 'Student';
          
          await NotificationHelperService.notifyTrialRequestDeleted(
            tutorId: session['tutor_id'] as String,
            studentId: session['learner_id'] as String,
            trialId: sessionId,
            studentName: requesterName,
            subject: session['subject'] as String,
            deletionReason: reason,
          );
        } catch (e) {
          LogService.warning('Failed to send deletion notification: $e');
        }
      }

      // Delete the trial session itself
      await _supabase.from('trial_sessions').delete().eq('id', sessionId);

      LogService.success('Trial session deleted: $sessionId');
    } catch (e) {
      LogService.error('Error deleting trial session: $e');
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

  /// Modify trial session (student-initiated)
  /// 
  /// Rules:
  /// - Pending: Can modify without reason (just updates request)
  /// - Approved/Paid: Requires reason
  /// - Updates session details and notifies tutor
  static Future<void> modifyTrialSession({
    required String sessionId,
    DateTime? scheduledDate,
    String? scheduledTime,
    int? durationMinutes,
    String? location,
    String? address,
    String? locationDescription,
    String? trialGoal,
    String? learnerChallenges,
    String? learnerLevel,
    String? modificationReason, // Required for approved/paid sessions
  }) async {
    try {
      // Get current session
      final session = await _supabase
          .from('trial_sessions')
          .select('status, payment_status, tutor_id, learner_id, requester_id, subject')
          .eq('id', sessionId)
          .maybeSingle();
      
      if (session == null) {
        throw Exception('Trial session not found');
      }
      
      final status = session['status'] as String?;
      final paymentStatus = session['payment_status'] as String?;
      final isPaid = paymentStatus != null && 
                    (paymentStatus.toLowerCase() == 'paid' || 
                     paymentStatus.toLowerCase() == 'completed');
      final isApproved = status == 'approved' || status == 'scheduled';
      
      // Check if session time has passed (for paid sessions, we allow modification if time has passed)
      // We need to get the full session to check the date/time
      final fullSession = await _supabase
          .from('trial_sessions')
          .select('scheduled_date, scheduled_time')
          .eq('id', sessionId)
          .maybeSingle();
      
      bool isTimePassed = false;
      if (fullSession != null) {
        final scheduledDate = DateTime.parse(fullSession['scheduled_date'] as String);
        final scheduledTime = fullSession['scheduled_time'] as String? ?? '00:00';
        final timeParts = scheduledTime.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
        final sessionDateTime = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, hour, minute);
        isTimePassed = sessionDateTime.isBefore(DateTime.now());
      }
      
      // Paid sessions can only be modified if time has passed (missed session)
      // Otherwise, they cannot be modified
      if (isPaid && !isTimePassed) {
        throw Exception('Cannot modify a paid session that has not yet occurred. Please request a date change after the session time.');
      }
      
      // Approved/expired/cancelled sessions require a reason (except pending)
      final isExpired = status == 'expired';
      final isCancelled = status == 'cancelled';
      if ((isApproved || isExpired || isCancelled) && 
          (modificationReason == null || modificationReason.trim().isEmpty)) {
        throw Exception('A reason is required to modify an ${isExpired ? 'expired' : isCancelled ? 'cancelled' : 'approved'} session.');
      }
      
      // Build update data
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (scheduledDate != null) {
        updateData['scheduled_date'] = scheduledDate.toIso8601String().split('T')[0];
      }
      if (scheduledTime != null) {
        updateData['scheduled_time'] = scheduledTime;
      }
      if (durationMinutes != null) {
        updateData['duration_minutes'] = durationMinutes;
      }
      if (location != null) {
        updateData['location'] = location;
      }
      if (address != null) {
        updateData['address'] = address;
      }
      if (locationDescription != null) {
        updateData['location_description'] = locationDescription;
      }
      if (trialGoal != null) {
        updateData['trial_goal'] = trialGoal;
      }
      if (learnerChallenges != null) {
        updateData['learner_challenges'] = learnerChallenges;
      }
      if (learnerLevel != null) {
        updateData['learner_level'] = learnerLevel;
      }
      
      // If pending, reset status to ensure it's still pending after modification
      if (status == 'pending') {
        // Keep as pending - modification doesn't change approval status
      } else if (isPaid && isTimePassed) {
        // For paid sessions that have passed (missed), reset to pending and keep payment status
        // The payment was made, but since session was missed, it needs re-approval for new date
        updateData['status'] = 'pending';
        updateData['responded_at'] = null;
        updateData['tutor_response_notes'] = null;
        updateData['rejection_reason'] = null; // Clear any previous rejection reason
        // Keep payment_status as 'paid' - don't reset it since payment was already made
      } else if (isApproved || status == 'expired' || status == 'cancelled') {
        // For approved/expired/cancelled sessions, modification resets to pending (needs re-approval)
        // This allows rescheduling missed/expired sessions
        updateData['status'] = 'pending';
        updateData['responded_at'] = null;
        updateData['tutor_response_notes'] = null;
        updateData['rejection_reason'] = null; // Clear any previous rejection reason
        updateData['payment_status'] = 'unpaid'; // Reset payment status if it was set
      }
      
      // Update session
      await _supabase
          .from('trial_sessions')
          .update(updateData)
          .eq('id', sessionId);
      
      // Notify tutor about modification
      try {
        final requesterProfile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', session['requester_id'] as String)
            .maybeSingle();
        
        final requesterName = requesterProfile?['full_name'] as String? ?? 'Student';
        
        final isExpired = status == 'expired';
        final isCancelled = status == 'cancelled';
        
        if (status == 'pending') {
          // Pending session modified - notify as update
          await NotificationHelperService.notifyTrialRequestUpdated(
            tutorId: session['tutor_id'] as String,
            studentId: session['learner_id'] as String,
            trialId: sessionId,
            studentName: requesterName,
            subject: session['subject'] as String,
          );
        } else if (isPaid && isTimePassed) {
          // Paid session that was missed - notify as modification requiring re-approval
          await NotificationHelperService.notifyTrialSessionModified(
            tutorId: session['tutor_id'] as String,
            studentId: session['learner_id'] as String,
            trialId: sessionId,
            studentName: requesterName,
            subject: session['subject'] as String,
            modificationReason: modificationReason ?? 'Request to reschedule a missed paid session',
          );
        } else if (isApproved || isExpired || isCancelled) {
          // Approved/expired/cancelled session modified - notify as modification requiring re-approval
          // For expired/cancelled, this is a request to reschedule a missed session
          await NotificationHelperService.notifyTrialSessionModified(
            tutorId: session['tutor_id'] as String,
            studentId: session['learner_id'] as String,
            trialId: sessionId,
            studentName: requesterName,
            subject: session['subject'] as String,
            modificationReason: modificationReason ?? 
                (isExpired || isCancelled 
                    ? 'Request to reschedule a missed/expired session'
                    : 'Session modified by student'),
          );
        }
      } catch (e) {
        LogService.warning('Failed to send modification notification: $e');
      }
      
      LogService.success('Trial session modified: $sessionId');
    } catch (e) {
      LogService.error('Error modifying trial session: $e');
      rethrow;
    }
  }
  
  /// Request modification from tutor (tutor-initiated)
  /// 
  /// Tutor can request changes to date, time, location
  /// Learner must accept for changes to apply
  static Future<String> requestTrialModification({
    required String sessionId,
    required DateTime proposedDate,
    required String proposedTime,
    int? proposedDurationMinutes,
    String? proposedLocation,
    String? proposedAddress,
    String? proposedLocationDescription,
    required String reason,
    String? additionalNotes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');
      
      // Get session to verify tutor ownership
      final session = await _supabase
          .from('trial_sessions')
          .select('tutor_id, learner_id, scheduled_date, scheduled_time, duration_minutes, location')
          .eq('id', sessionId)
          .maybeSingle();
      
      if (session == null) {
        throw Exception('Trial session not found');
      }
      
      if (session['tutor_id'] != userId) {
        throw Exception('Only the tutor can request modifications');
      }
      
      // Create modification request in session_reschedule_requests table
      final requestId = await _supabase
          .from('session_reschedule_requests')
          .insert({
            'session_id': sessionId,
            'session_type': 'trial',
            'requested_by': userId,
            'requested_by_type': 'tutor',
            'original_date': session['scheduled_date'],
            'original_time': session['scheduled_time'],
            'proposed_date': proposedDate.toIso8601String().split('T')[0],
            'proposed_time': proposedTime,
            'proposed_duration_minutes': proposedDurationMinutes ?? session['duration_minutes'],
            'proposed_location': proposedLocation ?? session['location'],
            'proposed_address': proposedAddress,
            'proposed_location_description': proposedLocationDescription,
            'reason': reason,
            'additional_notes': additionalNotes,
            'tutor_approved': true, // Tutor auto-approves their own request
            'student_approved': false,
            'status': 'pending',
          })
          .select('id')
          .maybeSingle()
          .then((result) {
            if (result == null) {
              throw Exception('Failed to create modification request');
            }
            return result['id'] as String;
          });
      
      // Notify learner about modification request
      try {
        final tutorProfile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
        
        final tutorName = tutorProfile?['full_name'] as String? ?? 'Tutor';
        
        await NotificationHelperService.notifyTutorModificationRequest(
          tutorId: userId,
          studentId: session['learner_id'] as String,
          trialId: sessionId,
          tutorName: tutorName,
          subject: session['subject'] as String? ?? 'Trial Session',
          reason: reason,
        );
      } catch (e) {
        LogService.warning('Failed to send modification request notification: $e');
      }
      
      LogService.success('Tutor modification request created: $requestId');
      return requestId;
    } catch (e) {
      LogService.error('Error creating tutor modification request: $e');
      rethrow;
    }
  }
  
  /// Accept tutor's modification request (learner-initiated)
  /// 
  /// When learner accepts, session is automatically updated to tutor's proposal
  static Future<void> acceptTutorModificationRequest(String requestId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');
      
      // Get modification request
      final request = await _supabase
          .from('session_reschedule_requests')
          .select('*')
          .eq('id', requestId)
          .maybeSingle();
      
      if (request == null) {
        throw Exception('Modification request not found');
      }
      
      if (request['status'] != 'pending') {
        throw Exception('Modification request is not pending');
      }
      
      final sessionId = request['session_id'] as String;
      final sessionType = request['session_type'] as String;
      
      if (sessionType != 'trial') {
        throw Exception('This method is for trial sessions only');
      }
      
      // Verify learner is the requester
      final session = await _supabase
          .from('trial_sessions')
          .select('learner_id, parent_id, requester_id')
          .eq('id', sessionId)
          .maybeSingle();
      
      if (session == null) {
        throw Exception('Trial session not found');
      }
      
      final learnerId = session['learner_id'] as String;
      final parentId = session['parent_id'] as String?;
      final requesterId = session['requester_id'] as String;
      
      if (userId != learnerId && userId != parentId && userId != requesterId) {
        throw Exception('Only the learner/parent can accept modification requests');
      }
      
      // Mark student as approved
      await _supabase
          .from('session_reschedule_requests')
          .update({
            'student_approved': true,
            'status': 'approved',
            'approved_at': DateTime.now().toIso8601String(),
            'approved_by': userId,
          })
          .eq('id', requestId);
      
      // Apply modifications to trial session
      final updateData = <String, dynamic>{
        'scheduled_date': request['proposed_date'],
        'scheduled_time': request['proposed_time'],
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (request['proposed_duration_minutes'] != null) {
        updateData['duration_minutes'] = request['proposed_duration_minutes'];
      }
      if (request['proposed_location'] != null) {
        updateData['location'] = request['proposed_location'];
      }
      if (request['proposed_address'] != null) {
        updateData['address'] = request['proposed_address'];
      }
      if (request['proposed_location_description'] != null) {
        updateData['location_description'] = request['proposed_location_description'];
      }
      
      // If session was approved, keep it approved (modification doesn't reset approval)
      // If session was pending, keep it pending
      final currentSession = await _supabase
          .from('trial_sessions')
          .select('status')
          .eq('id', sessionId)
          .maybeSingle();
      
      final currentStatus = currentSession?['status'] as String?;
      if (currentStatus == 'approved' || currentStatus == 'scheduled') {
        // Keep approved status
      } else {
        // Keep current status
      }
      
      await _supabase
          .from('trial_sessions')
          .update(updateData)
          .eq('id', sessionId);
      
      // Notify tutor that modification was accepted
      try {
        final learnerProfile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', requesterId)
            .maybeSingle();
        
        final learnerName = learnerProfile?['full_name'] as String? ?? 'Student';
        
        await NotificationHelperService.notifyModificationAccepted(
          tutorId: request['requested_by'] as String,
          studentId: learnerId,
          trialId: sessionId,
          studentName: learnerName,
        );
      } catch (e) {
        LogService.warning('Failed to send acceptance notification: $e');
      }
      
      LogService.success('Tutor modification request accepted: $requestId');
    } catch (e) {
      LogService.error('Error accepting tutor modification request: $e');
      rethrow;
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

      // Allow payment for pending, approved, or scheduled sessions
      // This enables sandbox testing and flexibility for production
      if (trial.status != 'pending' && 
          trial.status != 'approved' && 
          trial.status != 'scheduled') {
        throw Exception(
          'Cannot pay for a trial session with status: ${trial.status}',
        );
      }

      if (trial.paymentStatus == 'paid' || trial.paymentStatus == 'completed') {
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
      LogService.error('Error initiating payment: $e');
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

      // Check database directly for payment status and transaction ID
      final trialData = await _supabase
          .from('trial_sessions')
          .select('payment_status, fapshi_trans_id, meet_link')
          .eq('id', sessionId)
          .maybeSingle();
      
      // Check if payment was already confirmed (webhook might have processed it)
      final paymentStatus = trialData?['payment_status'] as String? ?? trial.paymentStatus;
      final isAlreadyPaid = paymentStatus.toLowerCase() == 'paid' || 
                            paymentStatus.toLowerCase() == 'completed';
      final existingTransId = trialData?['fapshi_trans_id'] as String?;
      
      if (isAlreadyPaid && existingTransId != null && existingTransId.isNotEmpty) {
        // Payment already confirmed - just verify Meet link exists and return
        LogService.info('Payment already confirmed (likely by webhook). Verifying Meet link...');
        
        // If Meet link doesn't exist and it's online, generate it
        final existingMeetLink = trialData?['meet_link'] as String?;
        if (trial.location == 'online' && (existingMeetLink == null || existingMeetLink.isEmpty)) {
          try {
            final meetLink = await MeetService.generateTrialMeetLink(
              trialSessionId: sessionId,
              tutorId: trial.tutorId,
              studentId: trial.learnerId,
              scheduledDate: trial.scheduledDate,
              scheduledTime: trial.scheduledTime,
              durationMinutes: trial.durationMinutes,
            );
            
            await _supabase
                .from('trial_sessions')
                .update({'meet_link': meetLink})
                .eq('id', sessionId);
            
            LogService.success('Meet link generated for already-confirmed payment');
            return true;
          } catch (e) {
            LogService.warning('Error generating Meet link for already-confirmed payment: $e');
            return false;
          }
        }
        
        // Payment confirmed and Meet link exists (or not needed for onsite)
        return true;
      }

      // Payment not yet confirmed - update payment status
      final now = DateTime.now().toIso8601String();
      await _supabase
          .from('trial_sessions')
          .update({
            'payment_status': 'paid',
            'status': 'scheduled',
            'fapshi_trans_id': transactionId,
            'updated_at': now,
            // Note: payment_confirmed_at column may not exist, using updated_at as fallback
          })
          .eq('id', sessionId);

      // Parse scheduled date and time
      // scheduledDate is already a DateTime in the model
      final scheduledDate = trial.scheduledDate;
      final scheduledTime = trial.scheduledTime;

      // Generate Meet link - webhook will handle this server-side for both tutor and learner
      // For immediate availability, try client-side if calendar is connected
      // Otherwise, webhook will generate it and both parties will get notified
      String? meetLink;
      var calendarOk = false;
      
      // Try client-side generation if calendar is connected (for immediate availability)
      try {
        final isCalendarConnected = await GoogleCalendarAuthService.isAuthenticated();
        if (isCalendarConnected) {
        meetLink = await MeetService.generateTrialMeetLink(
          trialSessionId: sessionId,
          tutorId: trial.tutorId,
          studentId: trial.learnerId,
          scheduledDate: scheduledDate,
          scheduledTime: scheduledTime,
          durationMinutes: trial.durationMinutes,
        );
          calendarOk = true;
          LogService.success('Meet link generated client-side: $meetLink');
        } else {
          LogService.info('Calendar not connected - webhook will generate Meet link server-side');
        }
      } catch (e) {
        LogService.warning('Client-side Meet link generation failed - webhook will handle it: $e');
        // Don't fail - webhook will generate link server-side
      }

      // Update trial_sessions with meet_link if we have it
      // Webhook will also update it when payment is confirmed
      if (meetLink != null) {
      await _supabase
          .from('trial_sessions')
          .update({'meet_link': meetLink})
          .eq('id', sessionId);
      }

      // Create an individual session instance so trial appears in upcoming sessions
      try {
        LogService.info('📅 Creating individual session for trial: $sessionId');
        LogService.info('📅 Session details: tutor=${trial.tutorId}, learner=${trial.learnerId}, date=$scheduledDate, time=$scheduledTime');
        
        final sessionData = {
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
          'address': null, // Trial sessions don't have address field in model
          'location_description': null, // Trial sessions don't have location_description field in model
        };
        
        LogService.debug('📅 Individual session data: $sessionData');
        
        final insertedSession = await _supabase
            .from('individual_sessions')
            .insert(sessionData)
            .select('id, scheduled_date, status')
            .single();
        
        LogService.success('✅ Individual session created for trial: ${insertedSession['id']}, date: ${insertedSession['scheduled_date']}, status: ${insertedSession['status']}');
      } catch (e, stackTrace) {
        LogService.error('❌ Error creating individual session for trial: $e');
        LogService.error('📚 Stack trace: $stackTrace');
        // Continue - trial record is still valid even if individual_sessions creation fails
      }

      // Notify tutor that session is ready and payment received (outside catch block)
      try {
        // Get learner name for notification
        final learnerProfile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', trial.learnerId)
            .maybeSingle();
        
        final learnerName = learnerProfile?['full_name'] as String? ?? 'Student';
        
        await NotificationHelperService.notifyTutorSessionReady(
          tutorId: trial.tutorId,
          sessionId: trial.id,
          sessionType: 'trial',
          learnerName: learnerName,
          subject: trial.subject,
          scheduledDate: scheduledDate ?? trial.scheduledDate,
          scheduledTime: scheduledTime,
          meetLink: meetLink,
        );
        
        LogService.success('Notified tutor that session is ready: ${trial.id}');
      } catch (e) {
        LogService.warning('Failed to notify tutor: $e');
        // Don't fail payment completion if notification fails
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

      // Create conversation for messaging after payment is confirmed
      try {
        LogService.info('💬 Creating conversation for paid trial session...');
        await ConversationLifecycleService.createConversationForTrial(
          trialSessionId: sessionId,
          studentId: trial.learnerId,
          tutorId: trial.tutorId,
        );
        LogService.success('✅ Conversation created successfully for trial session');
      } catch (e, stackTrace) {
        LogService.error('❌ Failed to create conversation for trial session: $e');
        LogService.error('📚 Stack trace: $stackTrace');
        // Don't fail payment completion if conversation creation fails
      }

      LogService.success('Payment completed for trial: $sessionId', 'calendarOk=$calendarOk');

      return calendarOk;
    } catch (e) {
      LogService.error('Error completing payment: $e');
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
            .maybeSingle();
        
        if (response == null) {
          throw Exception('Trial session not found: $sessionId');
        }

        return TrialSession.fromJson(response as Map<String, dynamic>);
      } catch (e) {
        // Check if it's a network error
        final errorString = e.toString().toLowerCase();
        final isNetworkError = errorString.contains('failed to fetch') ||
            errorString.contains('clientexception') ||
            errorString.contains('network') ||
            errorString.contains('connection');
        
        if (isNetworkError && attempt < maxRetries) {
          LogService.warning('Network error fetching trial session (attempt $attempt/$maxRetries), retrying...');
          await Future.delayed(Duration(milliseconds: retryDelay * attempt));
          continue;
        }
        
        // If it's the last attempt or not a network error, throw
        LogService.error('Failed to fetch trial session after $attempt attempts: $e');
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


  /// Auto-cancel expired trial sessions that haven't been paid
  /// 
  /// Cancels sessions where:
  /// - Status is 'approved' or 'scheduled'
  /// - Payment status is NOT 'paid' or 'completed'
  /// - Scheduled date/time has passed
  static Future<int> autoCancelExpiredSessions() async {
    try {
      final now = DateTime.now();
      final today = now.toIso8601String().split('T')[0];
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      // Query expired unpaid sessions
      // Get sessions where date has passed OR (date is today and time has passed)
      final expiredQuery = _supabase
          .from('trial_sessions')
          .select()
          .inFilter('status', ['approved', 'scheduled'])
          .not('payment_status', 'in', ['paid', 'completed'])
          .or('scheduled_date.lt.$today,scheduled_date.eq.$today.and(scheduled_time.lte.$currentTime)');
      
      final expiredSessions = await expiredQuery;
      
      if (expiredSessions.isEmpty) {
        return 0;
      }
      
      int cancelledCount = 0;
      
      for (final sessionData in expiredSessions as List) {
        final sessionId = sessionData['id'] as String;
        final scheduledDate = sessionData['scheduled_date'] as String;
        final scheduledTime = sessionData['scheduled_time'] as String;
        
        // Parse and verify the session has actually passed
        try {
          final dateParts = scheduledDate.split('T')[0].split('-');
          final timeParts = scheduledTime.split(':');
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final day = int.parse(dateParts[2]);
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
          
          final sessionDateTime = DateTime(year, month, day, hour, minute);
          
          // Only cancel if at least 24 hours have passed (grace period)
          final timeSinceSession = now.difference(sessionDateTime);
          if (timeSinceSession.inHours >= 24) {
            // Cancel the session (use 'cancelled' not 'expired' - expired is not a valid status)
            await _supabase
                .from('trial_sessions')
                .update({
                  'status': 'cancelled',
                  'rejection_reason': 'Payment not completed before session time - session expired',
                  'updated_at': now.toIso8601String(),
                })
                .eq('id', sessionId);
            
            // Notify both parties
            final learnerId = sessionData['learner_id'] as String?;
            final requesterId = sessionData['requester_id'] as String?;
            final tutorId = sessionData['tutor_id'] as String?;
            final subject = sessionData['subject'] as String? ?? 'Trial Session';
            
            final studentId = learnerId ?? requesterId;
            
            if (studentId != null) {
              try {
                await NotificationService.createNotification(
                  userId: studentId,
                  type: 'trial_expired',
                  title: '⏰ Trial Session Expired',
                  message: 'Payment not completed before session time. The session has been cancelled.',
                  priority: 'high',
                );
              } catch (e) {
                LogService.warning('Failed to notify student of expired session: $e');
              }
            }
            
            if (tutorId != null) {
              try {
                await NotificationService.createNotification(
                  userId: tutorId,
                  type: 'trial_expired',
                  title: '⏰ Trial Session Expired',
                  message: 'A trial session for $subject was cancelled because payment was not completed before the session time.',
                  priority: 'normal',
                );
              } catch (e) {
                LogService.warning('Failed to notify tutor of expired session: $e');
              }
            }
            
            cancelledCount++;
            LogService.success('Cancelled expired trial session: $sessionId');
          }
        } catch (e) {
          LogService.warning('Error processing expired session $sessionId: $e');
          continue;
        }
      }
      
      if (cancelledCount > 0) {
        LogService.success('Auto-cancelled $cancelledCount expired trial session(s)');
      }
      
      return cancelledCount;
    } catch (e) {
      LogService.error('Error auto-cancelling expired sessions: $e');
      rethrow;
    }
  }

  /// Auto-detect and mark expired trial sessions that were never attended
  /// 
  /// Marks sessions as 'expired' where:
  /// - Status is 'approved' or 'scheduled'
  /// - Payment status IS 'paid' or 'completed'
  /// - Scheduled date/time has passed
  /// - Session was never started (no attendance)
  static Future<int> autoMarkExpiredAttendedSessions() async {
    try {
      final now = DateTime.now();
      final today = now.toIso8601String().split('T')[0];
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      // Query expired paid sessions that were never attended
      final expiredQuery = _supabase
          .from('trial_sessions')
          .select()
          .inFilter('status', ['approved', 'scheduled'])
          .inFilter('payment_status', ['paid', 'completed'])
          .or('scheduled_date.lt.$today,scheduled_date.eq.$today.and(scheduled_time.lte.$currentTime)');
      
      final expiredSessions = await expiredQuery;
      
      if (expiredSessions.isEmpty) {
        return 0;
      }
      
      int markedCount = 0;
      
      for (final sessionData in expiredSessions as List) {
        final sessionId = sessionData['id'] as String;
        final scheduledDate = sessionData['scheduled_date'] as String;
        final scheduledTime = sessionData['scheduled_time'] as String;
        final status = sessionData['status'] as String;
        
        // Skip if already expired
        if (status == 'completed' || status == 'cancelled') {
          continue;
        }
        
        // Parse and verify the session has actually passed
        try {
          final dateParts = scheduledDate.split('T')[0].split('-');
          final timeParts = scheduledTime.split(':');
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final day = int.parse(dateParts[2]);
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
          
          final sessionDateTime = DateTime(year, month, day, hour, minute);
          
          // Check if session expired (at least 15 minutes after scheduled time)
          final expirationTime = sessionDateTime.add(const Duration(minutes: 15));
          
          // Only mark if at least 24 hours have passed since session time (grace period)
          final timeSinceSession = now.difference(sessionDateTime);
          if (timeSinceSession.inHours >= 24 && expirationTime.isBefore(now)) {
            // Mark as cancelled (use 'cancelled' not 'expired' - expired is not a valid status)
            // For paid sessions that were never attended, we mark as cancelled with reason
            await _supabase
                .from('trial_sessions')
                .update({
                  'status': 'cancelled',
                  'rejection_reason': 'Session expired - never attended',
                  'updated_at': now.toIso8601String(),
                })
                .eq('id', sessionId);
            
            // Notify both parties
            final learnerId = sessionData['learner_id'] as String?;
            final requesterId = sessionData['requester_id'] as String?;
            final tutorId = sessionData['tutor_id'] as String?;
            final subject = sessionData['subject'] as String? ?? 'Trial Session';
            
            final studentId = learnerId ?? requesterId;
            
            if (studentId != null) {
              try {
                // Send in-app notification to student
                await NotificationService.createNotification(
                  userId: studentId,
                  type: 'trial_expired',
                  title: '⏰ Session Expired',
                  message: 'Your trial session for $subject has expired. It was never attended.',
                  priority: 'normal',
                  actionUrl: '/sessions/$sessionId',
                  actionText: 'View Details',
                  icon: '⏰',
                  metadata: {
                    'session_id': sessionId,
                    'session_type': 'trial',
                    'subject': subject,
                  },
                );
              } catch (e) {
                LogService.warning('Failed to notify student of expired session: $e');
              }
            }
            
            if (tutorId != null) {
              try {
                // Send in-app notification to tutor
                await NotificationService.createNotification(
                  userId: tutorId,
                  type: 'trial_expired',
                  title: '⏰ Session Expired',
                  message: 'A trial session for $subject has expired. It was never attended.',
                  priority: 'normal',
                  actionUrl: '/sessions/$sessionId',
                  actionText: 'View Details',
                  icon: '⏰',
                  metadata: {
                    'session_id': sessionId,
                    'session_type': 'trial',
                    'subject': subject,
                  },
                );
              } catch (e) {
                LogService.warning('Failed to notify tutor of expired session: $e');
              }
            }
            
            markedCount++;
            LogService.success('Marked expired trial session: $sessionId');
          }
        } catch (e) {
          LogService.warning('Error processing expired session $sessionId: $e');
          continue;
        }
      }
      
      if (markedCount > 0) {
        LogService.success('Auto-marked $markedCount expired trial session(s)');
      }
      
      return markedCount;
    } catch (e) {
      LogService.error('Error auto-marking expired sessions: $e');
      rethrow;
    }
  }

  /// Get day name from date
  static String _getDayName(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  /// Normalize time string for comparison
  static String _normalizeTime(String time) {
    // Remove any whitespace and convert to lowercase for comparison
    return time.trim().toLowerCase();
  }

}