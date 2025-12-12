import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/google_calendar_auth_service.dart';
import 'package:prepskul/features/sessions/services/meet_service.dart';

/// IndividualSessionService
///
/// Handles individual session instances (generated from recurring sessions)
/// Includes start/end tracking, Google Meet link generation, and status management
class IndividualSessionService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Get individual sessions for a recurring session
  static Future<List<Map<String, dynamic>>> getSessionsForRecurring(
    String recurringSessionId, {
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('individual_sessions')
          .select()
          .eq('recurring_session_id', recurringSessionId);

      if (status != null) {
        query = query.eq('status', status);
      }

      if (startDate != null) {
        query = query.gte('scheduled_date', startDate.toIso8601String().split('T')[0]);
      }

      if (endDate != null) {
        query = query.lte('scheduled_date', endDate.toIso8601String().split('T')[0]);
      }

      final response = await query
          .order('scheduled_date', ascending: false)
          .order('scheduled_time', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.error('Error fetching individual sessions: $e');
      rethrow;
    }
  }

  /// Get upcoming individual sessions for a tutor
  static Future<List<Map<String, dynamic>>> getTutorUpcomingSessions({
    int limit = 10,
    DateTime? afterDate,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();
      final queryDate = afterDate ?? now;

      var query = _supabase.from('individual_sessions').select('''
            *,
            recurring_sessions!inner(
              student_name,
              student_avatar_url
            )
          ''')
          .eq('tutor_id', userId)
          .inFilter('status', ['scheduled', 'in_progress'])
          .gte('scheduled_date', queryDate.toIso8601String().split('T')[0]);

      final response = await query
          .order('scheduled_date', ascending: true)
          .order('scheduled_time', ascending: true)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.error('Error fetching tutor upcoming sessions: $e');
      rethrow;
    }
  }

  /// Get past individual sessions for a tutor
  static Future<List<Map<String, dynamic>>> getTutorPastSessions({
    int limit = 20,
    DateTime? beforeDate,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();
      final queryDate = beforeDate ?? now;

      var query = _supabase
          .from('individual_sessions')
          .select('''
            *,
            recurring_sessions!inner(
              student_name,
              student_avatar_url,
              subject
            )
          ''')
          .eq('tutor_id', userId)
          .inFilter('status', ['completed', 'cancelled', 'no_show_tutor', 'no_show_learner'])
          .lte('scheduled_date', queryDate.toIso8601String().split('T')[0]);

      final response = await query
          .order('scheduled_date', ascending: false)
          .order('scheduled_time', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.error('Error fetching tutor past sessions: $e');
      rethrow;
    }
  }

  /// Get upcoming individual sessions for a student/parent
  static Future<List<Map<String, dynamic>>> getStudentUpcomingSessions({
    int limit = 10,
    DateTime? afterDate,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();
      final queryDate = afterDate ?? now;

      var query = _supabase.from('individual_sessions').select('''
            *,
            recurring_sessions!inner(
              tutor_name,
              tutor_avatar_url
            )
          ''')
          .or('learner_id.eq.$userId,parent_id.eq.$userId')
          .inFilter('status', ['scheduled', 'in_progress'])
          .gte('scheduled_date', queryDate.toIso8601String().split('T')[0]);

      final response = await query
          .order('scheduled_date', ascending: true)
          .order('scheduled_time', ascending: true)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.error('Error fetching student upcoming sessions: $e');
      rethrow;
    }
  }

  /// Get past individual sessions for a student/parent
  static Future<List<Map<String, dynamic>>> getStudentPastSessions({
    int limit = 20,
    DateTime? beforeDate,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();
      final queryDate = beforeDate ?? now;

      var query = _supabase.from('individual_sessions').select('''
            *,
            recurring_sessions!inner(
              tutor_name,
              tutor_avatar_url
            )
          ''')
          .or('learner_id.eq.$userId,parent_id.eq.$userId')
          .inFilter('status', ['completed', 'cancelled', 'no_show_tutor', 'no_show_learner'])
          .lte('scheduled_date', queryDate.toIso8601String().split('T')[0]);

      final response = await query
          .order('scheduled_date', ascending: false)
          .order('scheduled_time', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.error('Error fetching student past sessions: $e');
      rethrow;
    }
  }

  /// Start a session (tutor joins)
  static Future<void> startSession(String sessionId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now().toIso8601String();

      // Check if session exists and tutor is authorized
      final session = await _supabase
          .from('individual_sessions')
          .select('tutor_id, status')
          .eq('id', sessionId)
          .single();

      if (session['tutor_id'] != userId) {
        throw Exception('Unauthorized: Not the tutor for this session');
      }

      if (session['status'] != 'scheduled' && session['status'] != 'in_progress') {
        throw Exception('Session cannot be started. Current status: ${session['status']}');
      }

      // Update session: mark tutor as joined and start session
      final updateData = <String, dynamic>{
        'tutor_joined_at': now,
        'status': 'in_progress',
        'updated_at': now,
      };

      // If session hasn't started yet, set session_started_at
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

      LogService.success('Session started: $sessionId');
    } catch (e) {
      LogService.error('Error starting session: $e');
      rethrow;
    }
  }

  /// End a session
  static Future<void> endSession(String sessionId, {String? notes}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();

      // Check if session exists and tutor is authorized
      final session = await _supabase
          .from('individual_sessions')
          .select('tutor_id, status, session_started_at, duration_minutes')
          .eq('id', sessionId)
          .single();

      if (session['tutor_id'] != userId) {
        throw Exception('Unauthorized: Not the tutor for this session');
      }

      if (session['status'] != 'in_progress') {
        throw Exception('Session is not in progress. Current status: ${session['status']}');
      }

      // Calculate actual duration
      int? actualDurationMinutes;
      if (session['session_started_at'] != null) {
        final startTime = DateTime.parse(session['session_started_at'] as String);
        actualDurationMinutes = now.difference(startTime).inMinutes;
      } else {
        // Fallback to scheduled duration if start time not recorded
        actualDurationMinutes = session['duration_minutes'] as int?;
      }

      // Update session: mark as completed
      final updateData = <String, dynamic>{
        'session_ended_at': now.toIso8601String(),
        'status': 'completed',
        'actual_duration_minutes': actualDurationMinutes,
        'updated_at': now.toIso8601String(),
      };

      if (notes != null && notes.isNotEmpty) {
        updateData['session_notes'] = notes;
      }

      await _supabase
          .from('individual_sessions')
          .update(updateData)
          .eq('id', sessionId);

      // Update recurring session totals
      await _updateRecurringSessionTotals(session['recurring_session_id'] as String);

      LogService.success('Session ended: $sessionId');
    } catch (e) {
      LogService.error('Error ending session: $e');
      rethrow;
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

  /// Generate or retrieve Google Meet link for a session
  ///
  /// Checks if link exists, otherwise generates one via Google Calendar API
  static Future<String?> getOrGenerateMeetLink(String sessionId) async {
    try {
      // First, check if link already exists
      final session = await _supabase
          .from('individual_sessions')
          .select('''
            meeting_link,
            location,
            scheduled_date,
            scheduled_time,
            duration_minutes,
            recurring_sessions!inner(
              tutor_id,
              student_name,
              subject
            )
          ''')
          .eq('id', sessionId)
          .single();

      if (session['meeting_link'] != null && (session['meeting_link'] as String).isNotEmpty) {
        return session['meeting_link'] as String;
      }

      // If no link exists and session is online or hybrid, generate one
      // For hybrid sessions, Meet link is available for online mode
      if (session['location'] == 'online' || session['location'] == 'hybrid') {
        // Check if Google Calendar is authenticated
        final isAuth = await GoogleCalendarAuthService.isAuthenticated();
        if (!isAuth) {
          LogService.warning('Google Calendar not authenticated. Please sign in first.');
          return null;
        }

        // Get session details
        final scheduledDate = DateTime.parse(session['scheduled_date'] as String);
        final scheduledTime = session['scheduled_time'] as String;
        final durationMinutes = session['duration_minutes'] as int;
        final recurringData = session['recurring_sessions'] as Map<String, dynamic>;
        final tutorId = recurringData['tutor_id'] as String;
        final subject = recurringData['subject'] as String? ?? 'Tutoring Session';

        // Get student ID from individual session (learner_id or parent_id)
        final sessionData = await _supabase
            .from('individual_sessions')
            .select('learner_id, parent_id')
            .eq('id', sessionId)
            .single();

        final studentId = sessionData['learner_id'] as String? ?? sessionData['parent_id'] as String?;
        
        if (studentId != null) {
          // Use MeetService for consistent Meet link generation
          final meetLink = await MeetService.generateIndividualSessionMeetLink(
            sessionId: sessionId,
            tutorId: tutorId,
            studentId: studentId,
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime,
            durationMinutes: durationMinutes,
            subject: subject,
          );

          LogService.success('Meet link generated for session: $sessionId');
          return meetLink;
        }
      }

      return null;
    } catch (e) {
      LogService.error('Error getting/generating Meet link: $e');
      return null;
    }
  }

  /// Cancel a session
  static Future<void> cancelSession(
    String sessionId, {
    required String reason,
    String? cancelledBy,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id ?? cancelledBy;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final session = await _supabase
          .from('individual_sessions')
          .select('tutor_id, status')
          .eq('id', sessionId)
          .single();

      if (session['status'] == 'completed') {
        throw Exception('Cannot cancel a completed session');
      }

      if (session['status'] == 'cancelled') {
        throw Exception('Session is already cancelled');
      }

      await _supabase
          .from('individual_sessions')
          .update({
            'status': 'cancelled',
            'cancellation_reason': reason,
            'cancelled_by': userId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);

      LogService.success('Session cancelled: $sessionId');
    } catch (e) {
      LogService.error('Error cancelling session: $e');
      rethrow;
    }
  }
}
