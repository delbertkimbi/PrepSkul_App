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
  static bool _legacyParticipantColumnWarningLogged = false;

  static DateTime? _parseSessionStart(Map<String, dynamic> session) {
    final dateStr = session['scheduled_date'] as String?;
    final timeStr = session['scheduled_time'] as String?;
    if (dateStr == null || dateStr.isEmpty) return null;
    final safeTime = (timeStr == null || timeStr.isEmpty) ? '00:00:00' : timeStr;
    try {
      return DateTime.parse('${dateStr}T$safeTime');
    } catch (_) {
      return null;
    }
  }

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

      // Use optional join to include sessions even if recurring_sessions join fails
      // Also include tutor_name, tutor_avatar_url, learner_name, learner_avatar_url, and subject from recurring_sessions for display
      var query = _supabase.from('individual_sessions').select('''
            *,
            recurring_sessions(
              id,
              frequency,
              days,
              times,
              start_date,
              monthly_total,
              payment_plan,
              tutor_name,
              tutor_avatar_url,
              learner_name,
              learner_avatar_url,
              learner_id,
              learner_type,
              subject
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

      // Use optional join to include sessions even if recurring_sessions join fails
      // Also include tutor_name, tutor_avatar_url, learner_name, learner_avatar_url, and subject from recurring_sessions for display
      var query = _supabase
          .from('individual_sessions')
          .select('''
            *,
            recurring_sessions(
              id,
              subject,
              frequency,
              days,
              times,
              start_date,
              monthly_total,
              payment_plan,
              tutor_name,
              tutor_avatar_url,
              learner_name,
              learner_avatar_url,
              learner_id,
              learner_type
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
  /// Only returns sessions that have been paid for
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

      // Fetch sessions where user is direct learner/parent.
      var query = _supabase.from('individual_sessions').select('''
            *,
            recurring_sessions(
              id,
              tutor_name,
              tutor_avatar_url,
              tutor_id,
              subject
            )
          ''')
          .or('learner_id.eq.$userId,parent_id.eq.$userId')
          .inFilter('status', ['scheduled', 'in_progress'])
          .gte('scheduled_date', queryDate.toIso8601String().split('T')[0]);

      final response = await query
          .order('scheduled_date', ascending: true)
          .order('scheduled_time', ascending: true)
          .limit(limit * 2); // Fetch more to filter by payment status

      // Also fetch sessions where user is enrolled via classroom participants.
      // Support both schema variants:
      // - new: session_participants.individual_session_id
      // - legacy: session_participants.session_id
      List<Map<String, dynamic>> participantRows = [];
      try {
        final rows = await _supabase
            .from('session_participants')
            .select('''
              individual_session_id,
              individual_sessions(
                *,
                recurring_sessions(
                  id,
                  tutor_name,
                  tutor_avatar_url,
                  tutor_id,
                  subject
                )
              )
            ''')
            .eq('user_id', userId)
            .not('individual_session_id', 'is', null);
        participantRows = (rows as List).cast<Map<String, dynamic>>();
      } catch (e) {
        final error = e.toString();
        if (error.contains('42703') &&
            error.contains('session_participants.individual_session_id')) {
          if (!_legacyParticipantColumnWarningLogged) {
            _legacyParticipantColumnWarningLogged = true;
            LogService.warning(
              'session_participants uses legacy session_id column; falling back for participant lookup.',
            );
          }
          final rows = await _supabase
              .from('session_participants')
              .select('''
                session_id,
                individual_sessions(
                  *,
                  recurring_sessions(
                    id,
                    tutor_name,
                    tutor_avatar_url,
                    tutor_id,
                    subject
                  )
                )
              ''')
              .eq('user_id', userId)
              .not('session_id', 'is', null);
          participantRows = (rows as List).cast<Map<String, dynamic>>();
        } else {
          rethrow;
        }
      }

      // Build set of group-class session IDs with paid enrollment.
      final paidGroupEnrollmentRows = await _supabase
          .from('group_class_enrollments')
          .select('listing_id, status, group_class_listings(individual_session_id)')
          .eq('user_id', userId)
          .eq('status', 'paid');

      final paidGroupSessionIds = <String>{};
      for (final row in (paidGroupEnrollmentRows as List).cast<Map<String, dynamic>>()) {
        final listing = row['group_class_listings'] as Map<String, dynamic>?;
        final sessionId = listing?['individual_session_id'] as String?;
        if (sessionId != null && sessionId.isNotEmpty) {
          paidGroupSessionIds.add(sessionId);
        }
      }

      // Merge direct + participant sessions (dedupe by id).
      final sessionsById = <String, Map<String, dynamic>>{};
      for (final session in (response as List).cast<Map<String, dynamic>>()) {
        final id = session['id'] as String?;
        if (id != null && id.isNotEmpty) {
          sessionsById[id] = session;
        }
      }
      for (final row in participantRows) {
        final session = row['individual_sessions'] as Map<String, dynamic>?;
        final id = session?['id'] as String?;
        if (session != null && id != null && id.isNotEmpty) {
          sessionsById[id] = session;
        }
      }

      // Filter to paid recurring OR paid group-class sessions.
      final sessions = sessionsById.values.toList();
      final paidSessions = <Map<String, dynamic>>[];
      
      for (final session in sessions) {
        final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
        final sessionId = session['id'] as String?;
        if (sessionId != null && paidGroupSessionIds.contains(sessionId)) {
          paidSessions.add(session);
          continue;
        }

        if (recurringData != null) {
          final recurringSessionId = recurringData['id'] as String?;
          if (recurringSessionId != null) {
            // Check payment status by querying payment_requests
            try {
              final paymentResponse = await _supabase
                  .from('payment_requests')
                  .select('status')
                  .eq('recurring_session_id', recurringSessionId)
                  .limit(1);
              
              final paymentRequests = paymentResponse as List<dynamic>?;
              if (paymentRequests != null && paymentRequests.isNotEmpty) {
                // Check if any payment request is paid
                final hasPaidPayment = paymentRequests.any((pr) {
                  final prMap = pr as Map<String, dynamic>;
                  final status = (prMap['status'] as String? ?? '').toLowerCase();
                  return status == 'paid' || status == 'completed';
                });
                
                if (hasPaidPayment) {
                  paidSessions.add(session);
                }
              }
            } catch (e) {
              // If payment_requests query fails, skip this session
              LogService.warning('Error checking payment status for session ${session['id']}: $e');
            }
          }
        }
      }

      // Final classification by full local date+time so same-day already-held
      // sessions do not remain in "Upcoming" due to date-only filtering.
      final upcoming = paidSessions.where((session) {
        final status = (session['status'] as String? ?? '').toLowerCase();
        if (status == 'in_progress') return true;
        final start = _parseSessionStart(session);
        if (start == null) return true; // fail-open if data is malformed
        return !start.isBefore(now);
      }).toList();

      upcoming.sort((a, b) {
        final aStart = _parseSessionStart(a);
        final bStart = _parseSessionStart(b);
        if (aStart == null && bStart == null) return 0;
        if (aStart == null) return 1;
        if (bStart == null) return -1;
        return aStart.compareTo(bStart);
      });

      return upcoming.take(limit).toList();
    } catch (e) {
      LogService.error('Error fetching student upcoming sessions: $e');
      rethrow;
    }
  }

  /// Get past individual sessions for a student/parent
  /// Only returns sessions that have been paid for
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

      // Fetch sessions where user is direct learner/parent.
      var query = _supabase.from('individual_sessions').select('''
            *,
            recurring_sessions(
              id,
              tutor_name,
              tutor_avatar_url,
              tutor_id,
              subject
            )
          ''')
          .or('learner_id.eq.$userId,parent_id.eq.$userId')
          .inFilter('status', ['completed', 'cancelled', 'no_show_tutor', 'no_show_learner'])
          .lte('scheduled_date', queryDate.toIso8601String().split('T')[0]);

      final response = await query
          .order('scheduled_date', ascending: false)
          .order('scheduled_time', ascending: false)
          .limit(limit * 2); // Fetch more to filter by payment status

      // Also fetch sessions where user is enrolled via classroom participants.
      // Support both schema variants:
      // - new: session_participants.individual_session_id
      // - legacy: session_participants.session_id
      List<Map<String, dynamic>> participantRows = [];
      try {
        final rows = await _supabase
            .from('session_participants')
            .select('''
              individual_session_id,
              individual_sessions(
                *,
                recurring_sessions(
                  id,
                  tutor_name,
                  tutor_avatar_url,
                  tutor_id,
                  subject
                )
              )
            ''')
            .eq('user_id', userId)
            .not('individual_session_id', 'is', null);
        participantRows = (rows as List).cast<Map<String, dynamic>>();
      } catch (e) {
        final error = e.toString();
        if (error.contains('42703') &&
            error.contains('session_participants.individual_session_id')) {
          if (!_legacyParticipantColumnWarningLogged) {
            _legacyParticipantColumnWarningLogged = true;
            LogService.warning(
              'session_participants uses legacy session_id column; falling back for participant lookup.',
            );
          }
          final rows = await _supabase
              .from('session_participants')
              .select('''
                session_id,
                individual_sessions(
                  *,
                  recurring_sessions(
                    id,
                    tutor_name,
                    tutor_avatar_url,
                    tutor_id,
                    subject
                  )
                )
              ''')
              .eq('user_id', userId)
              .not('session_id', 'is', null);
          participantRows = (rows as List).cast<Map<String, dynamic>>();
        } else {
          rethrow;
        }
      }

      // Build set of group-class session IDs with paid enrollment.
      final paidGroupEnrollmentRows = await _supabase
          .from('group_class_enrollments')
          .select('listing_id, status, group_class_listings(individual_session_id)')
          .eq('user_id', userId)
          .eq('status', 'paid');

      final paidGroupSessionIds = <String>{};
      for (final row in (paidGroupEnrollmentRows as List).cast<Map<String, dynamic>>()) {
        final listing = row['group_class_listings'] as Map<String, dynamic>?;
        final sessionId = listing?['individual_session_id'] as String?;
        if (sessionId != null && sessionId.isNotEmpty) {
          paidGroupSessionIds.add(sessionId);
        }
      }

      // Merge direct + participant sessions (dedupe by id).
      final sessionsById = <String, Map<String, dynamic>>{};
      for (final session in (response as List).cast<Map<String, dynamic>>()) {
        final id = session['id'] as String?;
        if (id != null && id.isNotEmpty) {
          sessionsById[id] = session;
        }
      }
      for (final row in participantRows) {
        final session = row['individual_sessions'] as Map<String, dynamic>?;
        final id = session?['id'] as String?;
        if (session != null && id != null && id.isNotEmpty) {
          sessionsById[id] = session;
        }
      }

      // Filter to paid recurring OR paid group-class sessions.
      final sessions = sessionsById.values.toList();
      final paidSessions = <Map<String, dynamic>>[];
      
      for (final session in sessions) {
        final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
        final sessionId = session['id'] as String?;
        if (sessionId != null && paidGroupSessionIds.contains(sessionId)) {
          paidSessions.add(session);
          continue;
        }

        if (recurringData != null) {
          final recurringSessionId = recurringData['id'] as String?;
          if (recurringSessionId != null) {
            // Check payment status by querying payment_requests
            try {
              final paymentResponse = await _supabase
                  .from('payment_requests')
                  .select('status')
                  .eq('recurring_session_id', recurringSessionId)
                  .limit(1);
              
              final paymentRequests = paymentResponse as List<dynamic>?;
              if (paymentRequests != null && paymentRequests.isNotEmpty) {
                // Check if any payment request is paid
                final hasPaidPayment = paymentRequests.any((pr) {
                  final prMap = pr as Map<String, dynamic>;
                  final status = (prMap['status'] as String? ?? '').toLowerCase();
                  return status == 'paid' || status == 'completed';
                });
                
                if (hasPaidPayment) {
                  paidSessions.add(session);
                }
              }
            } catch (e) {
              // If payment_requests query fails, skip this session
              LogService.warning('Error checking payment status for session ${session['id']}: $e');
            }
          }
        }
      }

      // Include sessions that are explicitly past by status OR by full date+time.
      final past = paidSessions.where((session) {
        final status = (session['status'] as String? ?? '').toLowerCase();
        if (status == 'completed' ||
            status == 'cancelled' ||
            status == 'no_show_tutor' ||
            status == 'no_show_learner') {
          return true;
        }
        final start = _parseSessionStart(session);
        if (start == null) return false;
        return start.isBefore(now);
      }).toList();

      past.sort((a, b) {
        final aStart = _parseSessionStart(a);
        final bStart = _parseSessionStart(b);
        if (aStart == null && bStart == null) return 0;
        if (aStart == null) return 1;
        if (bStart == null) return -1;
        return bStart.compareTo(aStart);
      });

      return past.take(limit).toList();
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
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

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
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

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
            learner_id,
            parent_id,
            recurring_sessions!inner(
              tutor_id
            )
          ''')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

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

        // Get session details (learner_id/parent_id from same session select)
        final scheduledDate = DateTime.parse(session['scheduled_date'] as String);
        final scheduledTime = session['scheduled_time'] as String;
        final durationMinutes = session['duration_minutes'] as int;
        final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
        final tutorId = recurringData?['tutor_id'] as String;
        final subject = 'Tutoring Session';
        final studentId = session['learner_id'] as String? ?? session['parent_id'] as String?;
        
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
          .maybeSingle();

      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

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
