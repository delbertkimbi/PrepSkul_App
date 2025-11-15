import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/features/booking/services/individual_session_service.dart';
import 'package:prepskul/features/booking/services/session_payment_service.dart';

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
          .single();

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
      final isSessionOnline = sessionLocation == 'online' || isOnline;

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
          .single();

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
      );

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

        // TODO: Start Fathom recording (when Fathom integration is ready)
        // await FathomService.startRecording(sessionId, meetLink);
      }

      // Send notifications
      final studentId = session['learner_id'] ?? session['parent_id'];
      if (studentId != null) {
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
        
        await _sendSessionStartedNotification(
          sessionId: sessionId,
          studentId: studentId as String,
          isOnline: isSessionOnline,
          meetLink: finalMeetLink,
        );
      }

      print('✅ Session started: $sessionId');
    } catch (e) {
      print('❌ Error starting session: $e');
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
          .single();

      // Authorization check
      if (session['tutor_id'] != userId) {
        throw Exception('Unauthorized: Only the tutor can end the session');
      }

      // Status validation
      if (session['status'] != 'in_progress') {
        throw Exception('Session is not in progress. Current status: ${session['status']}');
      }

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
      await _updateAttendanceRecord(
        sessionId: sessionId,
        userId: userId,
        leftAt: now,
        durationMinutes: actualDurationMinutes,
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
      try {
        await SessionPaymentService.createSessionPayment(sessionId);
      } catch (e) {
        print('⚠️ Error creating session payment: $e');
        // Don't fail the session end if payment creation fails
      }

      // For online sessions: stop Fathom recording
      if (session['location'] == 'online') {
        // TODO: Stop Fathom recording (when Fathom integration is ready)
        // await FathomService.stopRecording(sessionId);
      }

      // Send notifications
      final studentId = session['learner_id'] ?? session['parent_id'];
      if (studentId != null) {
        await _sendSessionCompletedNotification(
          sessionId: sessionId,
          studentId: studentId as String,
        );
        
        // Schedule feedback reminder for 24 hours after session end
        try {
          await _scheduleFeedbackReminder(
            sessionId: sessionId,
            studentId: studentId as String,
            sessionEndTime: now,
          );
        } catch (e) {
          print('⚠️ Error scheduling feedback reminder: $e');
          // Don't fail session end if reminder scheduling fails
        }
      }

      print('✅ Session ended: $sessionId');
    } catch (e) {
      print('❌ Error ending session: $e');
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
          .single();

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

      print('✅ Session cancelled: $sessionId');
    } catch (e) {
      print('❌ Error cancelling session: $e');
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
          .single();

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
      print('❌ Error detecting no-show: $e');
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
  }) async {
    try {
      await _supabase.from('session_attendance').insert({
        'session_id': sessionId,
        'user_id': userId,
        'user_type': userType,
        'joined_at': joinedAt.toIso8601String(),
        'attendance_status': 'present',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('⚠️ Error creating attendance record: $e');
      // Don't fail the session start if attendance fails
    }
  }

  /// Update attendance record
  static Future<void> _updateAttendanceRecord({
    required String sessionId,
    required String userId,
    required DateTime leftAt,
    int? durationMinutes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'left_at': leftAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (durationMinutes != null) {
        updateData['duration_minutes'] = durationMinutes;
      }

      await _supabase
          .from('session_attendance')
          .update(updateData)
          .eq('session_id', sessionId)
          .eq('user_id', userId);
    } catch (e) {
      print('⚠️ Error updating attendance record: $e');
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
          .single();

      await _supabase
          .from('individual_sessions')
          .update({'feedback_id': feedback['id']})
          .eq('id', sessionId);
    } catch (e) {
      print('⚠️ Error creating tutor feedback: $e');
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
            recurring_sessions!inner(
              monthly_total,
              frequency
            )
          ''')
          .eq('id', sessionId)
          .single();

      final recurringData = session['recurring_sessions'] as Map<String, dynamic>;
      final monthlyTotal = recurringData['monthly_total'] as num;
      final frequency = recurringData['frequency'] as int;

      // Calculate session fee (monthly_total / (frequency * 4))
      // Assuming 4 weeks per month
      final sessionFee = (monthlyTotal / (frequency * 4)).toDouble();
      final platformFee = sessionFee * 0.15; // 15%
      final tutorEarnings = sessionFee * 0.85; // 85%

      // Create earnings record
      final earningsData = <String, dynamic>{
        'tutor_id': session['tutor_id'],
        'session_id': sessionId,
        'session_fee': sessionFee,
        'platform_fee': platformFee,
        'tutor_earnings': tutorEarnings,
        'earnings_status': 'pending', // Will become 'active' when payment confirmed
        'created_at': DateTime.now().toIso8601String(),
      };

      if (session['recurring_session_id'] != null) {
        earningsData['recurring_session_id'] = session['recurring_session_id'];
      }

      await _supabase.from('tutor_earnings').insert(earningsData);

      print('✅ Earnings calculated for session: $sessionId');
    } catch (e) {
      print('⚠️ Error calculating earnings: $e');
      // Don't fail the session end if earnings calculation fails
    }
  }

  /// Send session started notification
  static Future<void> _sendSessionStartedNotification({
    required String sessionId,
    required String studentId,
    required bool isOnline,
    String? meetLink,
  }) async {
    try {
      final message = isOnline
          ? 'Your session has started! ${meetLink != null ? "Join the meeting now: $meetLink" : ""}'
          : 'Your session has started!';

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
          print('⚠️ Could not send email/push notification for session start: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error sending session started notification: $e');
    }
  }

  /// Send session completed notification
  static Future<void> _sendSessionCompletedNotification({
    required String sessionId,
    required String studentId,
  }) async {
    try {
      await NotificationService.createNotification(
        userId: studentId,
        type: 'session_completed',
        title: '✅ Session Completed',
        message: 'Your session has been completed. Please provide feedback when ready.',
        priority: 'normal',
        actionUrl: '/sessions/$sessionId/feedback',
        actionText: 'Provide Feedback',
        icon: '✅',
        metadata: {
          'session_id': sessionId,
        },
      );
    } catch (e) {
      print('⚠️ Error sending session completed notification: $e');
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
      
      print('✅ Feedback reminder scheduled for session: $sessionId at $reminderTime');
    } catch (e) {
      print('⚠️ Error scheduling feedback reminder: $e');
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
      print('⚠️ Error sending session cancelled notification: $e');
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

      print('✅ Updated recurring session totals: $recurringSessionId');
    } catch (e) {
      print('❌ Error updating recurring session totals: $e');
      // Don't rethrow - this is a background update
    }
  }
}
