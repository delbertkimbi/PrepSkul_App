import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

/// Session Reschedule Service
///
/// Handles rescheduling requests with mutual agreement requirement
/// Both tutor and student must approve for reschedule to take effect
class SessionRescheduleService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Request to reschedule a session
  ///
  /// Creates a reschedule request that requires approval from the other party
  static Future<Map<String, dynamic>> requestReschedule({
    required String sessionId,
    required DateTime proposedDate,
    required String proposedTime,
    required String reason,
    String? additionalNotes,
    int? proposedDurationMinutes,
    String? proposedLocation,
    String? proposedAddress,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Determine session type and get session details
      // Try individual_sessions first (recurring sessions)
      Map<String, dynamic>? session;
      String sessionType = 'recurring';
      String? tableName = 'individual_sessions';
      
      try {
        session = await _supabase
            .from('individual_sessions')
            .select('''
              tutor_id,
              learner_id,
              parent_id,
              scheduled_date,
              scheduled_time,
              duration_minutes,
              location,
              onsite_address,
              recurring_session_id,
              status
            ''')
            .eq('id', sessionId)
            .maybeSingle();
      } catch (e) {
        // If not found, try trial_sessions
      }
      
      // If not found in individual_sessions, try trial_sessions
      if (session == null) {
        try {
          session = await _supabase
              .from('trial_sessions')
              .select('''
                tutor_id,
                learner_id,
                parent_id,
                scheduled_date,
                scheduled_time,
                duration_minutes,
                location,
                onsite_address,
                location_description,
                status,
                payment_status
              ''')
              .eq('id', sessionId)
              .maybeSingle();
          
          if (session != null) {
            sessionType = 'trial';
            tableName = 'trial_sessions';
          }
        } catch (e) {
          // Session not found in either table
        }
      }
      
      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      // Determine requester type
      String requestedByType;
      if (session['tutor_id'] == userId) {
        requestedByType = 'tutor';
      } else if (session['learner_id'] == userId || session['parent_id'] == userId) {
        requestedByType = session['parent_id'] == userId ? 'parent' : 'student';
      } else {
        throw Exception('Unauthorized: Not a participant in this session');
      }

      // Check if session can be rescheduled
      // Allow rescheduling for:
      // - Scheduled sessions (upcoming)
      // - Completed/missed/no_show paid sessions (for making up missed sessions)
      final sessionStatus = session['status'] as String? ?? '';
      final isPaid = session['payment_status'] == 'paid' || 
                     session['payment_status'] == 'completed' ||
                     (sessionType == 'recurring' && session['recurring_session_id'] != null); // Recurring sessions are paid
      
      final canReschedule = sessionStatus == 'scheduled' || 
                           (isPaid && (sessionStatus == 'completed' || 
                                       sessionStatus == 'no_show_tutor' || 
                                       sessionStatus == 'no_show_learner' ||
                                       sessionStatus == 'missed'));
      
      if (!canReschedule) {
        throw Exception('This session cannot be rescheduled. Only scheduled sessions or missed/completed paid sessions can be rescheduled.');
      }

      // Check if there's already a pending reschedule request
      final existingRequest = await _supabase
          .from('session_reschedule_requests')
          .select('id, status')
          .eq('session_id', sessionId)
          .eq('status', 'pending')
          .maybeSingle();

      if (existingRequest != null) {
        throw Exception('A reschedule request is already pending for this session');
      }

      // Store original date/time if not already stored
      final originalDate = session['original_scheduled_date'] ?? session['scheduled_date'];
      final originalTime = session['original_scheduled_time'] ?? session['scheduled_time'];

      // Create reschedule request
      final requestData = <String, dynamic>{
        'session_id': sessionId,
        'session_type': sessionType,
        'requested_by': userId,
        'requested_by_type': requestedByType,
        'original_date': originalDate,
        'original_time': originalTime,
        'proposed_date': proposedDate.toIso8601String().split('T')[0],
        'proposed_time': proposedTime,
        'reason': reason,
        'status': 'pending',
        'tutor_approved': requestedByType == 'tutor', // Auto-approve if tutor requested
        'student_approved': requestedByType != 'tutor', // Auto-approve if student/parent requested
      };
      
      // Add recurring_session_id only for recurring sessions
      if (sessionType == 'recurring' && session['recurring_session_id'] != null) {
        requestData['recurring_session_id'] = session['recurring_session_id'];
      }

      if (additionalNotes != null && additionalNotes.isNotEmpty) {
        requestData['additional_notes'] = additionalNotes;
      }

      if (proposedDurationMinutes != null) {
        requestData['proposed_duration_minutes'] = proposedDurationMinutes;
      } else {
        requestData['proposed_duration_minutes'] = session['duration_minutes'];
      }

      if (proposedLocation != null) {
        requestData['proposed_location'] = proposedLocation;
      } else {
        requestData['proposed_location'] = session['location'];
      }

      if (proposedAddress != null) {
        requestData['proposed_address'] = proposedAddress;
      } else if (proposedLocation == 'onsite' || proposedLocation == 'hybrid') {
        requestData['proposed_address'] = session['onsite_address'];
      }
      
      // Add location_description for trial sessions
      if (sessionType == 'trial' && session['location_description'] != null) {
        requestData['proposed_location_description'] = session['location_description'];
      }

      final response = await _supabase
          .from('session_reschedule_requests')
          .insert(requestData)
          .select()
          .maybeSingle();
      
      if (response == null) {
        throw Exception('Failed to create reschedule request');
      }

      // Update session with reschedule request ID and store original date/time
      await _supabase
          .from(tableName!)
          .update({
            'reschedule_request_id': response['id'],
            'original_scheduled_date': originalDate,
            'original_scheduled_time': originalTime,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);

      // Send notification to the other party
      try {
        final otherPartyId = requestedByType == 'tutor'
            ? (session['learner_id'] ?? session['parent_id'])
            : session['tutor_id'];

        if (otherPartyId != null) {
          // Get names for notification
          final requesterProfile = await _supabase
              .from('profiles')
              .select('full_name')
              .eq('id', userId)
              .maybeSingle();

          final requesterName = requesterProfile?['full_name'] as String? ?? 'User';

          // Send notification via API
          await _sendNotificationViaAPI(
            userId: otherPartyId as String,
            type: 'session_reschedule_request',
            title: 'Session Reschedule Request',
            message: '$requesterName has requested to reschedule a session. Please review and respond.',
            priority: 'high',
            actionUrl: '/sessions/${response['id']}/reschedule',
            actionText: 'Review Request',
            icon: '📅',
            metadata: {
              'session_id': sessionId,
              'reschedule_request_id': response['id'],
              'session_type': sessionType,
              'requester_name': requesterName,
              'proposed_date': requestData['proposed_date'],
              'proposed_time': requestData['proposed_time'],
            },
            sendEmail: true,
          );
        }
      } catch (e) {
        LogService.warning('Failed to send reschedule request notification: $e');
        // Don't fail the request if notification fails
      }

      LogService.success('Reschedule request created: ${response['id']}');
      return response;
    } catch (e) {
      LogService.error('Error creating reschedule request: $e');
      rethrow;
    }
  }

  /// Approve a reschedule request
  ///
  /// When both parties approve, the session is automatically rescheduled
  static Future<void> approveRescheduleRequest(String requestId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get reschedule request (without join first to get session_type)
      final request = await _supabase
          .from('session_reschedule_requests')
          .select('*')
          .eq('id', requestId)
          .maybeSingle();

      if (request == null) {
        throw Exception('Reschedule request not found: $requestId');
      }

      if (request['status'] != 'pending') {
        throw Exception('Reschedule request is not pending');
      }

      // Get session details based on session_type
      final sessionType = request['session_type'] as String;
      final sessionId = request['session_id'] as String;
      
      Map<String, dynamic>? session;
      if (sessionType == 'recurring') {
        session = await _supabase
            .from('individual_sessions')
            .select('tutor_id, learner_id, parent_id, status')
            .eq('id', sessionId)
            .maybeSingle();
      } else {
        session = await _supabase
            .from('trial_sessions')
            .select('tutor_id, learner_id, parent_id, status')
            .eq('id', sessionId)
            .maybeSingle();
      }

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }
      
      // Determine approver type
      bool isTutor = session['tutor_id'] == userId;
      bool isStudent = session['learner_id'] == userId || session['parent_id'] == userId;

      if (!isTutor && !isStudent) {
        throw Exception('Unauthorized: Not a participant in this session');
      }

      // Update approval status
      final updateData = <String, dynamic>{};
      if (isTutor) {
        updateData['tutor_approved'] = true;
      } else {
        updateData['student_approved'] = true;
      }

      await _supabase
          .from('session_reschedule_requests')
          .update(updateData)
          .eq('id', requestId);

      // Check if both parties have approved
      final updatedRequest = await _supabase
          .from('session_reschedule_requests')
          .select('tutor_approved, student_approved')
          .eq('id', requestId)
          .maybeSingle();

      if (updatedRequest == null) {
        throw Exception('Reschedule request not found: $requestId');
      }

      final tutorApproved = updatedRequest['tutor_approved'] as bool;
      final studentApproved = updatedRequest['student_approved'] as bool;

      if (tutorApproved && studentApproved) {
        // Both parties approved - reschedule the session
        await _applyReschedule(requestId, request);
      }

      // Send notification to requester
      try {
        final requesterId = request['requested_by'] as String;
        final approverProfile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();

        final approverName = approverProfile?['full_name'] as String? ?? 'User';

        await _sendNotificationViaAPI(
          userId: requesterId,
          type: tutorApproved && studentApproved
              ? 'session_rescheduled'
              : 'session_reschedule_approved',
          title: tutorApproved && studentApproved
              ? '✅ Session Rescheduled!'
              : '✅ Reschedule Request Approved',
          message: tutorApproved && studentApproved
              ? 'Your session has been rescheduled. Both parties have approved the new time.'
              : '$approverName has approved your reschedule request. Waiting for the other party to approve.',
          priority: 'high',
          actionUrl: '/sessions/${request['session_id']}',
          actionText: 'View Session',
          icon: '✅',
          metadata: {
            'session_id': request['session_id'],
            'reschedule_request_id': requestId,
          },
          sendEmail: true,
        );
      } catch (e) {
        LogService.warning('Failed to send approval notification: $e');
      }

      LogService.success('Reschedule request approved: $requestId');
    } catch (e) {
      LogService.error('Error approving reschedule request: $e');
      rethrow;
    }
  }

  /// Reject a reschedule request
  static Future<void> rejectRescheduleRequest(
    String requestId, {
    String? reason,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get reschedule request
      final request = await _supabase
          .from('session_reschedule_requests')
          .select('*')
          .eq('id', requestId)
          .maybeSingle();

      if (request == null) {
        throw Exception('Reschedule request not found: $requestId');
      }

      if (request['status'] != 'pending') {
        throw Exception('Reschedule request is not pending');
      }

      final sessionType = request['session_type'] as String;
      final sessionId = request['session_id'] as String;
      
      // Get session details based on type
      Map<String, dynamic>? sessionResponse;
      if (sessionType == 'recurring') {
        sessionResponse = await _supabase
            .from('individual_sessions')
            .select('tutor_id, learner_id, parent_id')
            .eq('id', sessionId)
            .maybeSingle();
      } else {
        sessionResponse = await _supabase
            .from('trial_sessions')
            .select('tutor_id, learner_id, parent_id')
            .eq('id', sessionId)
            .maybeSingle();
      }
      
      if (sessionResponse == null) {
        throw Exception('Session not found: $sessionId');
      }
      
      final session = sessionResponse;
      
      // Check authorization
      final isTutor = session['tutor_id'] == userId;
      final isStudent = session['learner_id'] == userId || session['parent_id'] == userId;

      if (!isTutor && !isStudent) {
        throw Exception('Unauthorized: Not a participant in this session');
      }

      // Update request status
      await _supabase
          .from('session_reschedule_requests')
          .update({
            'status': 'rejected',
            'rejected_by': userId,
            'rejection_reason': reason ?? 'Reschedule request rejected',
            'rejected_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      // Clear reschedule request from session
      final tableName = sessionType == 'recurring' ? 'individual_sessions' : 'trial_sessions';
      await _supabase
          .from(tableName)
          .update({
            'reschedule_request_id': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);

      // CRITICAL: If student rejects, cancel the session
      // If tutor rejects, just reject the request (session remains)
      if (isStudent) {
        LogService.info('Student rejected reschedule request - cancelling session');
        
        // Cancel the session
        if (sessionType == 'recurring') {
          await _supabase
              .from('individual_sessions')
              .update({
                'status': 'cancelled',
                'cancellation_reason': 'Session cancelled due to reschedule request rejection',
                'cancelled_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', sessionId);
        } else {
          // Trial session
          await _supabase
              .from('trial_sessions')
              .update({
                'status': 'cancelled',
                'rejection_reason': 'Session cancelled due to reschedule request rejection',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', sessionId);
        }
      }

      // Send notification to requester
      try {
        final requesterId = request['requested_by'] as String;
        final rejecterProfile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();

        final rejecterName = rejecterProfile?['full_name'] as String? ?? 'User';

        // If student rejected, notify tutor that session is cancelled
        // If tutor rejected, notify student that request was rejected
        final notificationMessage = isStudent
            ? '$rejecterName has rejected your reschedule request. The session has been cancelled.${reason != null ? ' Reason: $reason' : ''}'
            : '$rejecterName has rejected your reschedule request.${reason != null ? ' Reason: $reason' : ''}';
        
        await _sendNotificationViaAPI(
          userId: requesterId,
          type: isStudent ? 'session_cancelled' : 'session_reschedule_rejected',
          title: isStudent ? '❌ Session Cancelled' : '⚠️ Reschedule Request Rejected',
          message: notificationMessage,
          priority: 'high',
          icon: isStudent ? '❌' : '⚠️',
          metadata: {
            'session_id': request['session_id'],
            'session_type': sessionType,
            'reschedule_request_id': requestId,
            'rejection_reason': reason,
            'cancelled': isStudent,
          },
          sendEmail: true,
        );
      } catch (e) {
        LogService.warning('Failed to send rejection notification: $e');
      }

      LogService.success('Reschedule request rejected: $requestId');
    } catch (e) {
      LogService.error('Error rejecting reschedule request: $e');
      rethrow;
    }
  }

  /// Apply the reschedule (update session with new date/time)
  static Future<void> _applyReschedule(
    String requestId,
    Map<String, dynamic> request,
  ) async {
    try {
      final sessionId = request['session_id'] as String;
      final sessionType = request['session_type'] as String;
      final proposedDate = request['proposed_date'] as String;
      final proposedTime = request['proposed_time'] as String;
      final proposedDuration = request['proposed_duration_minutes'] as int?;
      final proposedLocation = request['proposed_location'] as String?;
      final proposedAddress = request['proposed_address'] as String?;
      final proposedLocationDescription = request['proposed_location_description'] as String?;
      
      final tableName = sessionType == 'recurring' ? 'individual_sessions' : 'trial_sessions';

      // Update session
      final updateData = <String, dynamic>{
        'scheduled_date': proposedDate,
        'scheduled_time': proposedTime,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (proposedDuration != null) {
        updateData['duration_minutes'] = proposedDuration;
      }

      if (proposedLocation != null) {
        updateData['location'] = proposedLocation;
      }

      if (proposedAddress != null) {
        updateData['onsite_address'] = proposedAddress;
      }

      // If location changed to online, clear address
      if (proposedLocation == 'online') {
        updateData['onsite_address'] = null;
        if (sessionType == 'trial') {
          updateData['location_description'] = null;
        }
      }
      
      // Add location_description for trial sessions
      if (sessionType == 'trial' && proposedLocationDescription != null) {
        updateData['location_description'] = proposedLocationDescription;
      }

      await _supabase
          .from(tableName)
          .update(updateData)
          .eq('id', sessionId);

      // Update reschedule request status
      await _supabase
          .from('session_reschedule_requests')
          .update({
            'status': 'approved',
            'approved_at': DateTime.now().toIso8601String(),
            'approved_by': _supabase.auth.currentUser?.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      // Clear reschedule request ID from session
      await _supabase
          .from(tableName)
          .update({
            'reschedule_request_id': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);

      // If session has a Meet link, it may need to be regenerated
      // (This can be handled separately or the Meet link can be updated)

      LogService.success('Session rescheduled: $sessionId');
    } catch (e) {
      LogService.error('Error applying reschedule: $e');
      rethrow;
    }
  }

  /// Get reschedule requests for a session
  static Future<List<Map<String, dynamic>>> getRescheduleRequests({
    String? sessionId,
    String? status,
  }) async {
    try {
      var query = _supabase
          .from('session_reschedule_requests')
          .select('*');

      if (sessionId != null) {
        query = query.eq('session_id', sessionId);
      }

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.error('Error fetching reschedule requests: $e');
      rethrow;
    }
  }

  /// Cancel a reschedule request (by the requester)
  static Future<void> cancelRescheduleRequest(String requestId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get request
      final request = await _supabase
          .from('session_reschedule_requests')
          .select('requested_by, status, session_id, session_type')
          .eq('id', requestId)
          .maybeSingle();
      
      if (request == null) {
        throw Exception('Reschedule request not found: $requestId');
      }
      
      final sessionType = request['session_type'] as String;
      final sessionId = request['session_id'] as String;

      if (request['requested_by'] != userId) {
        throw Exception('Unauthorized: Only the requester can cancel the request');
      }

      if (request['status'] != 'pending') {
        throw Exception('Only pending requests can be cancelled');
      }

      // Update status
      await _supabase
          .from('session_reschedule_requests')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      // Clear reschedule request from session
      final tableName = sessionType == 'recurring' ? 'individual_sessions' : 'trial_sessions';
      await _supabase
          .from(tableName)
          .update({
            'reschedule_request_id': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);

      LogService.success('Reschedule request cancelled: $requestId');
    } catch (e) {
      LogService.error('Error cancelling reschedule request: $e');
      rethrow;
    }
  }

  /// Helper method to send notifications via API
  static Future<void> _sendNotificationViaAPI({
    required String userId,
    required String type,
    required String title,
    required String message,
    String priority = 'normal',
    String? actionUrl,
    String? actionText,
    String? icon,
    Map<String, dynamic>? metadata,
    bool sendEmail = true,
  }) async {
    // Always create in-app notification first (this always works)
    await NotificationService.createNotification(
      userId: userId,
      type: type,
      title: title,
      message: message,
      priority: priority,
      actionUrl: actionUrl,
      actionText: actionText,
      icon: icon,
      metadata: metadata,
    );

    // Try to send via API for email/push notifications (optional - API might not be deployed)
    try {
      // Use AppConfig instead of hardcoded URL - ensures correct domain
      final apiBaseUrl = AppConfig.effectiveApiBaseUrl;

      final response = await http.post(
        Uri.parse('$apiBaseUrl/notifications/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'type': type,
          'title': title,
          'message': message,
          'priority': priority,
          'actionUrl': actionUrl,
          'actionText': actionText,
          'icon': icon,
          'metadata': metadata,
          'sendEmail': sendEmail,
        }),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Notification API request timed out');
        },
      );

      if (response.statusCode == 200) {
        // Success - email/push notifications sent via API
        // In-app notification already created above
      }
      // If API returns error, in-app notification is still created (silent fail)
    } catch (e) {
      // API call failed (network error, timeout, or API not deployed)
      // This is expected if API is not deployed - in-app notification already created above
      // Silent fail - notification still works via in-app
    }
  }
}
