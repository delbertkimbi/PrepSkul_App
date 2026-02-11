import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/features/booking/services/individual_session_service.dart';
import 'package:prepskul/features/booking/services/session_payment_service.dart';
import 'package:prepskul/features/payment/services/user_credits_service.dart';
import 'package:prepskul/features/sessions/services/connection_quality_service.dart';
import 'package:prepskul/features/sessions/services/location_sharing_service.dart';
import 'package:prepskul/features/sessions/services/agora_recording_service.dart';

/// Session Lifecycle Service
///
/// Handles the complete lifecycle of normal recurring sessions:
/// - Start session (with notifications and Meet link handling)
/// - End session (with duration calculation and earnings)
/// - Cancel session (with refund handling)
/// - No-show detection
/// - Status transitions
class SessionLifecycleService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Start a session
  ///
  /// Records timestamps, updates status, sends notifications,
  /// handles online/onsite differences
  static Future<void> startSession(
    String sessionId, {
    bool isOnline = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get session details
      final session = await _supabase
          .from('individual_sessions')
          .select('''
            tutor_id,
            learner_id,
            parent_id,
            status,
            location,
            meeting_link,
            scheduled_date,
            scheduled_time,
            recurring_session_id
          ''')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      // Authorization check
      if (session['tutor_id'] != userId) {
        throw Exception('Unauthorized: Only the tutor can start the session');
      }

      // Status validation
      if (session['status'] != 'scheduled' && session['status'] != 'in_progress') {
        throw Exception('Session cannot be started. Current status: ${session['status']}');
      }

      final now = DateTime.now().toIso8601String();
      final sessionLocation = session['location'] as String;
      // Location should only be 'online' or 'onsite' (hybrid is a preference only)
      // If somehow 'hybrid' exists, default to online
      final actualLocation = sessionLocation == 'hybrid' ? 'online' : sessionLocation;
      final isSessionOnline = actualLocation == 'online';

      // Update session status
      final updateData = <String, dynamic>{
        'tutor_joined_at': now,
        'status': 'in_progress',
        'updated_at': now,
      };

      // Set session_started_at if not already set
      final existingSession = await _supabase
          .from('individual_sessions')
          .select('session_started_at')
          .eq('id', sessionId)
          .maybeSingle();

      if (existingSession == null) {
        throw Exception('Session not found: $sessionId');
      }

      if (existingSession['session_started_at'] == null) {
        updateData['session_started_at'] = now;
      }

      await _supabase
          .from('individual_sessions')
          .update(updateData)
          .eq('id', sessionId);

      // Create attendance record for tutor
      await _createAttendanceRecord(
        sessionId: sessionId,
        userId: userId,
        userType: 'tutor',
        joinedAt: DateTime.now(),
        isOnline: isSessionOnline,
      );

      // Start connection quality monitoring for online sessions
      if (isSessionOnline) {
        ConnectionQualityService.startMonitoring(sessionId);
      }

      // Start location sharing for onsite sessions
      // Location sharing helps parents track session location for safety
      if (!isSessionOnline && actualLocation == 'onsite') {
        // Start location sharing for tutor automatically when session starts
        try {
          await LocationSharingService.startLocationSharing(
            sessionId: sessionId,
            userId: userId,
            userType: 'tutor',
            updateInterval: const Duration(seconds: 30),
          );
          LogService.success('Location sharing started for tutor');
        } catch (e) {
          LogService.warning('Failed to start location sharing: $e');
          // Don't fail session start if location sharing fails
        }
        
        // Also start location sharing for learner if they join
        // This will be triggered when learner joins the session
        // For now, tutor location is the primary tracking point
      }
      // For online sessions: ensure Meet link exists
      if (isSessionOnline) {
        String? meetLink = session['meeting_link'] as String?;
        
        if (meetLink == null || meetLink.isEmpty) {
          // Generate Meet link if it doesn't exist
          meetLink = await IndividualSessionService.getOrGenerateMeetLink(sessionId);
          
          if (meetLink != null) {
            await _supabase
                .from('individual_sessions')
                .update({'meeting_link': meetLink})
                .eq('id', sessionId);
          }
        }

        // Start Agora Cloud Recording for online sessions
        // This replaces Fathom recording for Agora video sessions
        try {
          LogService.info('🎙️ [Recording] Starting for session: $sessionId');
          await AgoraRecordingService.startRecording(sessionId);
          LogService.success('Agora recording started for session: $sessionId');
        } catch (e) {
          LogService.warning('Failed to start Agora recording: $e');
          // Don't fail session start if recording fails
        }

        // Legacy: Fathom recording (if using Google Meet instead of Agora)
        // Fathom automatically records this session via calendar monitoring
        // The PrepSkul VA is already added as an attendee when the calendar event
        // is created (in GoogleCalendarService.createSessionEvent), so Fathom will:
        // 1. Detect the calendar event on PrepSkul VA's calendar
        // 2. Auto-join the meeting when it starts
        // 3. Automatically start recording and transcribing
        // 4. Send webhook with summary/transcript when ready
        LogService.debug('📹 Fathom will automatically record this session via calendar monitoring (if using Google Meet)');
      }

      // Send notifications to both learner and parent if applicable
      final learnerId = session['learner_id'] as String?;
      final parentId = session['parent_id'] as String?;
      
      // Get the final Meet link (either existing or newly generated)
      String? finalMeetLink;
      if (isSessionOnline) {
        finalMeetLink = session['meeting_link'] as String?;
        // If Meet link was just generated, fetch it from the updated session
        if (finalMeetLink == null || finalMeetLink.isEmpty) {
          final updatedSession = await _supabase
              .from('individual_sessions')
              .select('meeting_link')
              .eq('id', sessionId)
              .maybeSingle();
          finalMeetLink = updatedSession?['meeting_link'] as String?;
        }
      }
      
      // Send notification to learner (if exists)
      if (learnerId != null) {
        await _sendSessionStartedNotification(
          sessionId: sessionId,
          studentId: learnerId,
          isOnline: isSessionOnline,
          meetLink: finalMeetLink,
          isParent: false,
        );
      }
      
      // Send notification to parent (if exists and different from learner)
      if (parentId != null && parentId != learnerId) {
        await _sendSessionStartedNotification(
          sessionId: sessionId,
          studentId: parentId,
          isOnline: isSessionOnline,
          meetLink: finalMeetLink,
          isParent: true,
        );
      }

      LogService.success('Session started: $sessionId');
    } catch (e) {
      LogService.error('Error starting session: $e');
      rethrow;
    }
  }

  /// End a session
  ///
  /// Records end time, calculates duration, updates status,
  /// triggers earnings calculation, sends notifications
  static Future<void> endSession(
    String sessionId, {
    String? tutorNotes,
    String? progressNotes,
    String? homeworkAssigned,
    String? nextFocusAreas,
    int? studentEngagement, // 1-5 scale
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();

      // Get session details
      final session = await _supabase
          .from('individual_sessions')
          .select('''
            tutor_id,
            learner_id,
            parent_id,
            status,
            session_started_at,
            duration_minutes,
            recurring_session_id,
            location
          ''')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      // Authorization check
      if (session['tutor_id'] != userId) {
        throw Exception('Unauthorized: Only the tutor can end the session');
      }

      // Status validation
      if (session['status'] != 'in_progress') {
        throw Exception('Session is not in progress. Current status: ${session['status']}');
      }

      // Extract learner_id and parent_id early for use in credit deduction
      final learnerId = session['learner_id'] as String?;
      final parentId = session['parent_id'] as String?;

      // Calculate actual duration
      int? actualDurationMinutes;
      if (session['session_started_at'] != null) {
        final startTime = DateTime.parse(session['session_started_at'] as String);
        actualDurationMinutes = now.difference(startTime).inMinutes;
      } else {
        // Fallback to scheduled duration
        actualDurationMinutes = session['duration_minutes'] as int?;
      }

      // Update session status
      final updateData = <String, dynamic>{
        'session_ended_at': now.toIso8601String(),
        'status': 'completed',
        'actual_duration_minutes': actualDurationMinutes,
        'updated_at': now.toIso8601String(),
      };

      if (tutorNotes != null && tutorNotes.isNotEmpty) {
        updateData['session_notes'] = tutorNotes;
      }

      await _supabase
          .from('individual_sessions')
          .update(updateData)
          .eq('id', sessionId);

      // Update attendance record
      // Stop connection quality monitoring
      ConnectionQualityService.stopMonitoring();
      
      // Stop location sharing for onsite sessions (including hybrid)
      if (session['location'] == 'onsite' || session['location'] == 'hybrid') {
        await LocationSharingService.stopLocationSharing(sessionId);
      }
      await _updateAttendanceRecord(
        sessionId: sessionId,
        userId: userId,
        leftAt: now,
        durationMinutes: actualDurationMinutes,
      isOnline: session['location'] == 'online',
      );

      // Create tutor feedback record (if provided)
      if (tutorNotes != null ||
          progressNotes != null ||
          homeworkAssigned != null ||
          nextFocusAreas != null ||
          studentEngagement != null) {
        await _createTutorFeedback(
          sessionId: sessionId,
          recurringSessionId: session['recurring_session_id'] as String?,
          tutorNotes: tutorNotes,
          progressNotes: progressNotes,
          homeworkAssigned: homeworkAssigned,
          nextFocusAreas: nextFocusAreas,
          studentEngagement: studentEngagement,
        );
      }

      // Update recurring session totals
      if (session['recurring_session_id'] != null) {
        // Call the private method via a public wrapper or duplicate the logic
        await _updateRecurringSessionTotals(
          session['recurring_session_id'] as String,
        );
      }

      // Create payment record (includes earnings calculation)
      double? sessionCostXaf;
      try {
        await SessionPaymentService.createSessionPayment(sessionId);
        
        // Get session cost for credit deduction
        if (session['recurring_session_id'] != null) {
          final recurringSession = await _supabase
              .from('recurring_sessions')
              .select('monthly_total, frequency')
              .eq('id', session['recurring_session_id'])
              .maybeSingle();
          
          if (recurringSession != null) {
            final monthlyTotal = (recurringSession['monthly_total'] as num).toDouble();
            final frequency = recurringSession['frequency'] as int;
            // Calculate session cost: monthlyTotal / (frequency * 4)
            sessionCostXaf = monthlyTotal / (frequency * 4);
          }
        }
      } catch (e) {
        LogService.warning('Error creating session payment: $e');
        // Don't fail the session end if payment creation fails
      }

      // Deduct credits for completed session
      if (sessionCostXaf != null) {
        try {
          final creditsDeducted = await UserCreditsService.deductCreditsForSession(
            sessionId,
            sessionCostXaf,
          );
          
          if (creditsDeducted) {
            LogService.success('Credits deducted for session: $sessionId');
            
            // Check for low balance after deduction
            if (session['recurring_session_id'] != null) {
              final recurringSession = await _supabase
                  .from('recurring_sessions')
                  .select('monthly_total, student_id')
                  .eq('id', session['recurring_session_id'])
                  .maybeSingle();
              
              if (recurringSession != null) {
                final monthlyTotal = (recurringSession['monthly_total'] as num).toDouble();
                final studentUserId = recurringSession['student_id'] as String? ?? learnerId ?? parentId;
                
                if (studentUserId != null) {
                  // Check and notify if balance is low
                  await UserCreditsService.checkAndNotifyLowBalance(
                    studentUserId,
                    monthlyTotal,
                  );
                }
              }
            }
          } else {
            // Insufficient credits - mark session as payment_pending
            LogService.warning('Insufficient credits for session: $sessionId');
            await _supabase
                .from('individual_sessions')
                .update({'status': 'payment_pending'})
                .eq('id', sessionId);
            
            // Create payment request for missing amount
            // Note: This will be handled by the payment service
            // For now, just log the issue
            LogService.warning('Session marked as payment_pending due to insufficient credits');
          }
        } catch (e) {
          LogService.warning('Error deducting credits for session: $e');
          // Don't fail the session end if credit deduction fails
        }
      }

      // Stop Agora Cloud Recording for online sessions
      if (session['location'] == 'online') {
        try {
          LogService.info('🛑 [Recording] Stopping for session: $sessionId');
          await AgoraRecordingService.stopRecording(sessionId);
          LogService.success('Agora recording stopped for session: $sessionId');
        } catch (e) {
          LogService.warning('Failed to stop Agora recording: $e');
          // Don't fail session end if recording stop fails
        }

        // Legacy: Fathom recording stops automatically when meeting ends
        // No manual stop needed - Fathom detects meeting end via Google Calendar event
        LogService.debug('Session ended - Fathom will automatically stop recording when meeting ends (if using Google Meet)');
      }

      // Get payment ID to include in notification
      String? paymentId;
      try {
        final paymentRecord = await _supabase
            .from('session_payments')
            .select('id, session_fee, payment_status')
            .eq('session_id', sessionId)
            .maybeSingle();
        paymentId = paymentRecord?['id'] as String?;
      } catch (e) {
        LogService.warning('Could not fetch payment record for notification: $e');
      }
      
      // Send notification to learner (if exists)
      if (learnerId != null) {
        await _sendSessionCompletedNotification(
          sessionId: sessionId,
          studentId: learnerId,
          paymentId: paymentId,
          isParent: false,
        );
        
        // Schedule feedback reminder for learner
        try {
          await _scheduleFeedbackReminder(
            sessionId: sessionId,
            studentId: learnerId,
            sessionEndTime: now,
          );
        } catch (e) {
          LogService.warning('Error scheduling feedback reminder: $e');
        }
      }
      
      // Send notification to parent (if exists and different from learner)
      if (parentId != null && parentId != learnerId) {
        await _sendSessionCompletedNotification(
          sessionId: sessionId,
          studentId: parentId,
          paymentId: paymentId,
          isParent: true,
        );
        
        // Schedule feedback reminder for parent too
        try {
          await _scheduleFeedbackReminder(
            sessionId: sessionId,
            studentId: parentId,
            sessionEndTime: now,
          );
        } catch (e) {
          LogService.warning('Error scheduling feedback reminder for parent: $e');
        }
      }

      LogService.success('Session ended: $sessionId');
    } catch (e) {
      LogService.error('Error ending session: $e');
      rethrow;
    }
  }

  /// Cancel a session
  ///
  /// Handles cancellation by tutor or student, with refund logic
  static Future<void> cancelSession(
    String sessionId, {
    required String reason,
    String? cancelledBy,
    bool requestRefund = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id ?? cancelledBy;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get session details
      final session = await _supabase
          .from('individual_sessions')
          .select('''
            tutor_id,
            learner_id,
            parent_id,
            status,
            scheduled_date,
            scheduled_time,
            recurring_session_id
          ''')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      // Authorization check
      final isTutor = session['tutor_id'] == userId;
      final isStudent = session['learner_id'] == userId || session['parent_id'] == userId;

      if (!isTutor && !isStudent) {
        throw Exception('Unauthorized: Not a participant in this session');
      }

      // Status validation
      if (session['status'] == 'completed') {
        throw Exception('Cannot cancel a completed session');
      }

      if (session['status'] == 'cancelled') {
        throw Exception('Session is already cancelled');
      }

      final now = DateTime.now();

      // Update session status
      await _supabase
          .from('individual_sessions')
          .update({
            'status': 'cancelled',
            'cancellation_reason': reason,
            'cancelled_by': userId,
            'cancellation_requested_at': now.toIso8601String(),
            'cancellation_approved_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', sessionId);

      // Handle refund if requested
      if (requestRefund) {
        // TODO: Process refund via Fapshi
        // await PaymentService.processRefund(sessionId, reason);
      }

      // Cancel earnings if they exist
      await _supabase
          .from('tutor_earnings')
          .update({
            'earnings_status': 'cancelled',
            'updated_at': now.toIso8601String(),
          })
          .eq('session_id', sessionId)
          .eq('earnings_status', 'pending');

      // Send notifications
      final otherPartyId = isTutor
          ? (session['learner_id'] ?? session['parent_id'])
          : session['tutor_id'];

      if (otherPartyId != null) {
        await _sendSessionCancelledNotification(
          sessionId: sessionId,
          otherPartyId: otherPartyId as String,
          cancelledBy: isTutor ? 'tutor' : 'student',
          reason: reason,
        );
      }

      LogService.success('Session cancelled: $sessionId');
    } catch (e) {
      LogService.error('Error cancelling session: $e');
      rethrow;
    }
  }

  /// Detect and handle no-show
  ///
  /// Called automatically 15 minutes after scheduled start time
  static Future<void> detectNoShow(String sessionId) async {
    try {
      final session = await _supabase
          .from('individual_sessions')
          .select('''
            tutor_id,
            learner_id,
            parent_id,
            status,
            scheduled_date,
            scheduled_time,
            tutor_joined_at,
            learner_joined_at
          ''')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      if (session['status'] != 'scheduled' && session['status'] != 'in_progress') {
        return; // Session already handled
      }

      final tutorJoined = session['tutor_joined_at'] != null;
      final learnerJoined = session['learner_joined_at'] != null;

      String? noShowType;
      if (!tutorJoined && !learnerJoined) {
        // Both no-show - mark as cancelled
        await cancelSession(
          sessionId,
          reason: 'No-show: Neither party attended',
          cancelledBy: null, // System cancellation
        );
        return;
      } else if (!tutorJoined) {
        noShowType = 'no_show_tutor';
      } else if (!learnerJoined) {
        noShowType = 'no_show_learner';
      }

      if (noShowType != null) {
        await _supabase
            .from('individual_sessions')
            .update({
              'status': noShowType,
              'no_show_detected_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', sessionId);

        // Send notification to the party that showed up
        final notifiedUserId = noShowType == 'no_show_tutor'
            ? (session['learner_id'] ?? session['parent_id'])
            : session['tutor_id'];

        if (notifiedUserId != null) {
          await NotificationService.createNotification(
            userId: notifiedUserId as String,
            type: 'session_no_show',
            title: '⚠️ No-Show Detected',
            message: 'The other party did not attend the session.',
            priority: 'high',
            actionUrl: '/sessions/$sessionId',
            actionText: 'View Session',
            icon: '⚠️',
          );
        }
      }
    } catch (e) {
      LogService.error('Error detecting no-show: $e');
    }
  }

  // ========================================
  // PRIVATE HELPER METHODS
  // ========================================

  /// Create attendance record
  static Future<void> _createAttendanceRecord({
    required String sessionId,
    required String userId,
    required String userType,
    required DateTime joinedAt,
    bool isOnline = false,
  }) async {
    try {
      final attendanceData = <String, dynamic>{
        'session_id': sessionId,
        'user_id': userId,
        'user_type': userType,
        'joined_at': joinedAt.toIso8601String(),
        'attendance_status': 'present',
        'created_at': DateTime.now().toIso8601String(),
      };

      // For online sessions, assess and store connection quality
      if (isOnline) {
        try {
          final connectionQuality = await ConnectionQualityService.assessConnectionQuality();
          attendanceData['connection_quality'] = connectionQuality;
          attendanceData['meet_link_used'] = true;
          LogService.info('Connection quality at join: $connectionQuality');
        } catch (e) {
          LogService.warning('Error assessing connection quality: $e');
          // Continue without connection quality if assessment fails
        }
      }

      await _supabase.from('session_attendance').insert(attendanceData);
    } catch (e) {
      LogService.warning('Error creating attendance record: $e');
      // Don't fail the session start if attendance fails
    }
  }

  /// Update attendance record
  static Future<void> _updateAttendanceRecord({
    required String sessionId,
    required String userId,
    required DateTime leftAt,
    int? durationMinutes,
    bool isOnline = false,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'left_at': leftAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (durationMinutes != null) {
        updateData['duration_minutes'] = durationMinutes;
      }

      // For online sessions, update with final connection quality assessment
      if (isOnline) {
        try {
          // Get best quality from monitoring period
          final bestQuality = await ConnectionQualityService.getBestQuality();
          updateData['connection_quality'] = bestQuality;
          LogService.info('Final connection quality: $bestQuality');
        } catch (e) {
          LogService.warning('Error getting final connection quality: $e');
          // Continue without updating quality if assessment fails
        }
      }

      await _supabase
          .from('session_attendance')
          .update(updateData)
          .eq('session_id', sessionId)
          .eq('user_id', userId);
    } catch (e) {
      LogService.warning('Error updating attendance record: $e');
    }
  }

  /// Create tutor feedback
  static Future<void> _createTutorFeedback({
    required String sessionId,
    String? recurringSessionId,
    String? tutorNotes,
    String? progressNotes,
    String? homeworkAssigned,
    String? nextFocusAreas,
    int? studentEngagement,
  }) async {
    try {
      final feedbackData = <String, dynamic>{
        'session_id': sessionId,
        'tutor_feedback_submitted_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      if (recurringSessionId != null) {
        feedbackData['recurring_session_id'] = recurringSessionId;
      }

      if (tutorNotes != null) {
        feedbackData['tutor_notes'] = tutorNotes;
      }

      if (progressNotes != null) {
        feedbackData['tutor_progress_notes'] = progressNotes;
      }

      if (homeworkAssigned != null) {
        feedbackData['tutor_homework_assigned'] = homeworkAssigned;
      }

      if (nextFocusAreas != null) {
        feedbackData['tutor_next_focus_areas'] = nextFocusAreas;
      }

      if (studentEngagement != null) {
        feedbackData['tutor_student_engagement'] = studentEngagement;
      }

      await _supabase.from('session_feedback').insert(feedbackData);

      // Update session with feedback_id
      final feedback = await _supabase
          .from('session_feedback')
          .select('id')
          .eq('session_id', sessionId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (feedback != null) {
        await _supabase
            .from('individual_sessions')
            .update({'feedback_id': feedback['id']})
            .eq('id', sessionId);
      }
    } catch (e) {
      LogService.warning('Error creating tutor feedback: $e');
      // Don't fail the session end if feedback fails
    }
  }

  /// Calculate and create earnings record
  static Future<void> _calculateAndCreateEarnings(String sessionId) async {
    try {
      // Get session and recurring session details
      final session = await _supabase
          .from('individual_sessions')
          .select('''
            tutor_id,
            recurring_session_id,
            location,
            transportation_cost,
            recurring_sessions!inner(
              monthly_total,
              frequency
            )
          ''')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      final recurringData = session['recurring_sessions'] as Map<String, dynamic>;
      final monthlyTotal = recurringData['monthly_total'] as num;
      final frequency = recurringData['frequency'] as int;

      // Calculate session fee (monthly_total / (frequency * 4))
      // Assuming 4 weeks per month
      final sessionFee = (monthlyTotal / (frequency * 4)).toDouble();
      final platformFee = sessionFee * 0.15; // 15% (ONLY on session fee, NOT transportation)
      final tutorEarnings = sessionFee * 0.85; // 85%

      // Get transportation cost (if onsite session)
      final location = session['location'] as String? ?? 'online';
      final isOnsite = location == 'onsite';
      final transportationCost = isOnsite 
          ? ((session['transportation_cost'] as num?)?.toDouble() ?? 0.0)
          : 0.0;
      final transportationEarnings = transportationCost; // 100% to tutor (no platform fee)
      final totalTutorEarnings = tutorEarnings + transportationEarnings;
      final earningsType = transportationCost > 0 ? 'combined' : 'session';

      // Create earnings record
      final earningsData = <String, dynamic>{
        'tutor_id': session['tutor_id'],
        'session_id': sessionId,
        'session_fee': sessionFee,
        'platform_fee': platformFee,
        'tutor_earnings': totalTutorEarnings, // Total: session + transportation
        'transportation_earnings': transportationEarnings,
        'earnings_type': earningsType,
        'earnings_status': 'pending', // Will become 'active' when payment confirmed
        'created_at': DateTime.now().toIso8601String(),
      };

      if (session['recurring_session_id'] != null) {
        earningsData['recurring_session_id'] = session['recurring_session_id'];
      }

      await _supabase.from('tutor_earnings').insert(earningsData);

      LogService.success('Earnings calculated for session: $sessionId');
    } catch (e) {
      LogService.warning('Error calculating earnings: $e');
      // Don't fail the session end if earnings calculation fails
    }
  }

  /// Send session started notification
  /// 
  /// Sends notification to student or parent when session starts
  static Future<void> _sendSessionStartedNotification({
    required String sessionId,
    required String studentId,
    required bool isOnline,
    String? meetLink,
    bool isParent = false,
  }) async {
    try {
      final userType = isParent ? 'parent' : 'student';
      final messagePrefix = isParent ? "Your child's" : 'Your';
      final message = isOnline
          ? '$messagePrefix session has started! ${meetLink != null ? "Join the meeting now: $meetLink" : ""}'
          : '$messagePrefix session has started!';

      // Create in-app notification
      await NotificationService.createNotification(
        userId: studentId,
        type: 'session_started',
        title: '🎓 Session Started',
        message: message,
        priority: 'high',
        actionUrl: '/sessions/$sessionId',
        actionText: isOnline && meetLink != null ? 'Join Meeting' : 'View Session',
        icon: '🎓',
        metadata: {
          'session_id': sessionId,
          'is_online': isOnline,
          'meet_link': meetLink,
          'user_type': userType,
        },
      );

      // Send email/push notification via API (if available)
      if (isOnline && meetLink != null) {
        try {
          await NotificationHelperService.notifySessionStarted(
            userId: studentId,
            sessionId: sessionId,
            meetLink: meetLink,
          );
        } catch (e) {
          // Silently fail - in-app notification already sent
          LogService.warning('Could not send email/push notification for session start: $e');
        }
      }
    } catch (e) {
      LogService.warning('Error sending session started notification: $e');
    }
  }

  /// Send session completed notification
  /// 
  /// Sends notification to student or parent with payment information if applicable
  static Future<void> _sendSessionCompletedNotification({
    required String sessionId,
    required String studentId,
    String? paymentId,
    bool isParent = false,
  }) async {
    try {
      // Get session details for notification
      String? sessionFee;
      String? paymentStatus;
      if (paymentId != null) {
        try {
          final payment = await _supabase
              .from('session_payments')
              .select('session_fee, payment_status')
              .eq('id', paymentId)
              .maybeSingle();
          if (payment != null) {
            sessionFee = (payment['session_fee'] as num?)?.toStringAsFixed(0);
            paymentStatus = payment['payment_status'] as String?;
          }
        } catch (e) {
          LogService.warning('Could not fetch payment details: $e');
        }
      }
      
      // Create notification with payment information
      final userType = isParent ? 'parent' : 'student';
      final messagePrefix = isParent ? "Your child's" : 'Your';
      final message = paymentId != null && paymentStatus == 'unpaid'
          ? '$messagePrefix session has been completed. Payment of ${sessionFee ?? 'N/A'} XAF is due. Please complete payment.'
          : '$messagePrefix session has been completed. Please provide feedback when ready.';
      
      final actionUrl = paymentId != null && paymentStatus == 'unpaid'
          ? '/payments/session/$paymentId'
          : '/sessions/$sessionId/feedback';
      
      final actionText = paymentId != null && paymentStatus == 'unpaid'
          ? 'Pay Now'
          : 'Provide Feedback';
      
      await NotificationService.createNotification(
        userId: studentId,
        type: 'session_completed',
        title: 'Session Completed',
        message: message,
        priority: paymentId != null && paymentStatus == 'unpaid' ? 'high' : 'normal',
        actionUrl: actionUrl,
        actionText: actionText,
        icon: '✅',
        metadata: {
          'session_id': sessionId,
          'user_type': userType,
          if (paymentId != null) 'payment_id': paymentId,
          if (sessionFee != null) 'session_fee': sessionFee,
          if (paymentStatus != null) 'payment_status': paymentStatus,
        },
      );
    } catch (e) {
      LogService.warning('Error sending session completed notification: $e');
    }
  }

  /// Schedule feedback reminder for 24 hours after session end
  static Future<void> _scheduleFeedbackReminder({
    required String sessionId,
    required String studentId,
    required DateTime sessionEndTime,
  }) async {
    try {
      // Calculate 24 hours from session end
      final reminderTime = sessionEndTime.add(const Duration(hours: 24));
      
      // Schedule via NotificationHelperService
      await NotificationHelperService.scheduleFeedbackReminder(
        userId: studentId,
        sessionId: sessionId,
        reminderTime: reminderTime,
      );
      
      LogService.success('Feedback reminder scheduled for session: $sessionId at $reminderTime');
    } catch (e) {
      LogService.warning('Error scheduling feedback reminder: $e');
      // Don't rethrow - reminder scheduling shouldn't fail session end
    }
  }

  /// Send session cancelled notification
  static Future<void> _sendSessionCancelledNotification({
    required String sessionId,
    required String otherPartyId,
    required String cancelledBy,
    required String reason,
  }) async {
    try {
      final cancelledByName = cancelledBy == 'tutor' ? 'Tutor' : 'Student';

      await NotificationService.createNotification(
        userId: otherPartyId,
        type: 'session_cancelled',
        title: '⚠️ Session Cancelled',
        message: '$cancelledByName has cancelled the session. Reason: $reason',
        priority: 'high',
        actionUrl: '/sessions/$sessionId',
        actionText: 'View Details',
        icon: '⚠️',
        metadata: {
          'session_id': sessionId,
          'cancelled_by': cancelledBy,
          'reason': reason,
        },
      );
    } catch (e) {
      LogService.warning('Error sending session cancelled notification: $e');
    }
  }

  /// Update recurring session totals after a session is completed
  static Future<void> _updateRecurringSessionTotals(String recurringSessionId) async {
    try {
      // Count completed sessions
      final completedSessions = await _supabase
          .from('individual_sessions')
          .select('id')
          .eq('recurring_session_id', recurringSessionId)
          .eq('status', 'completed');

      final totalCompleted = (completedSessions as List).length;

      // Get last session date
      final lastSession = await _supabase
          .from('individual_sessions')
          .select('scheduled_date')
          .eq('recurring_session_id', recurringSessionId)
          .eq('status', 'completed')
          .order('scheduled_date', ascending: false)
          .limit(1)
          .maybeSingle();

      final updateData = <String, dynamic>{
        'total_sessions_completed': totalCompleted,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (lastSession != null && lastSession['scheduled_date'] != null) {
        updateData['last_session_date'] = lastSession['scheduled_date'];
      }

      await _supabase
          .from('recurring_sessions')
          .update(updateData)
          .eq('id', recurringSessionId);

      LogService.success('Updated recurring session totals: $recurringSessionId');
    } catch (e) {
      LogService.error('Error updating recurring session totals: $e');
      // Don't rethrow - this is a background update
    }
  }
}