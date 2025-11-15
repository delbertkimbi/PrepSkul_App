import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/google_calendar_service.dart';

/// Meet Service
/// 
/// Handles Google Meet link generation and access control
/// Documentation: docs/PHASE_1.2_IMPLEMENTATION_PLAN.md

class MeetService {
  static final _supabase = SupabaseService.client;

  /// Generate Meet link for trial session
  /// 
  /// Creates calendar event and generates Meet link
  /// Adds PrepSkul VA as attendee for Fathom auto-join
  /// 
  /// Parameters:
  /// - [trialSessionId]: Trial session ID
  /// - [tutorId]: Tutor user ID
  /// - [studentId]: Student user ID
  /// - [scheduledDate]: Session date
  /// - [scheduledTime]: Session time
  /// - [durationMinutes]: Session duration
  static Future<String> generateTrialMeetLink({
    required String trialSessionId,
    required String tutorId,
    required String studentId,
    required DateTime scheduledDate,
    required String scheduledTime,
    required int durationMinutes,
  }) async {
    try {
      // Get tutor and student emails
      final tutorProfile = await _supabase
          .from('profiles')
          .select('email, full_name')
          .eq('id', tutorId)
          .maybeSingle();

      final studentProfile = await _supabase
          .from('profiles')
          .select('email, full_name')
          .eq('id', studentId)
          .maybeSingle();

      final tutorEmail = tutorProfile?['email'] as String?;
      final studentEmail = studentProfile?['email'] as String?;

      if (tutorEmail == null || studentEmail == null) {
        throw Exception('Tutor or student email not found');
      }

      // Parse scheduled time
      final timeParts = scheduledTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1].split(' ')[0]);
      final isPM = scheduledTime.toUpperCase().contains('PM');
      final hour24 = isPM && hour != 12 ? hour + 12 : (hour == 12 && !isPM ? 0 : hour);

      final startTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        hour24,
        minute,
      );

      // Get trial session details
      final trialSession = await _supabase
          .from('trial_sessions')
          .select('subject')
          .eq('id', trialSessionId)
          .maybeSingle();

      final subject = trialSession?['subject'] as String? ?? 'Trial Session';

      // Create calendar event with Meet link
      final calendarEvent = await GoogleCalendarService.createSessionEvent(
        title: 'Trial Session: $subject',
        startTime: startTime,
        durationMinutes: durationMinutes,
        attendeeEmails: [tutorEmail, studentEmail],
        description: 'PrepSkul trial tutoring session',
      );

      // Update trial session with Meet link and calendar event ID
      await _supabase
          .from('trial_sessions')
          .update({
            'meet_link': calendarEvent.meetLink,
            'calendar_event_id': calendarEvent.id,
            'meet_link_generated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', trialSessionId);

      return calendarEvent.meetLink;
    } catch (e) {
      print('❌ Error generating trial Meet link: $e');
      rethrow;
    }
  }

  /// Generate permanent Meet link for recurring session
  /// 
  /// Creates a recurring calendar event with permanent Meet link
  /// 
  /// Parameters:
  /// - [recurringSessionId]: Recurring session ID
  /// - [tutorId]: Tutor user ID
  /// - [studentId]: Student user ID
  static Future<String> generateRecurringMeetLink({
    required String recurringSessionId,
    required String tutorId,
    required String studentId,
  }) async {
    try {
      // Get recurring session details
      final session = await _supabase
          .from('recurring_sessions')
          .select('start_date, days, times, frequency')
          .eq('id', recurringSessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('Recurring session not found');
      }

      // Get tutor and student emails
      final tutorProfile = await _supabase
          .from('profiles')
          .select('email')
          .eq('id', tutorId)
          .maybeSingle();

      final studentProfile = await _supabase
          .from('profiles')
          .select('email')
          .eq('id', studentId)
          .maybeSingle();

      final tutorEmail = tutorProfile?['email'] as String?;
      final studentEmail = studentProfile?['email'] as String?;

      if (tutorEmail == null || studentEmail == null) {
        throw Exception('Tutor or student email not found');
      }

      // Parse start date and first session time
      final startDate = DateTime.parse(session['start_date'] as String);
      final times = session['times'] as Map<String, dynamic>;
      final firstDay = (session['days'] as List).first as String;
      final firstTime = times[firstDay] as String? ?? '10:00 AM';

      // Parse time
      final timeParts = firstTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1].split(' ')[0]);
      final isPM = firstTime.toUpperCase().contains('PM');
      final hour24 = isPM && hour != 12 ? hour + 12 : (hour == 12 && !isPM ? 0 : hour);

      final startTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        hour24,
        minute,
      );

      // Default duration: 60 minutes for recurring sessions
      const durationMinutes = 60;

      // Create calendar event with Meet link
      final calendarEvent = await GoogleCalendarService.createSessionEvent(
        title: 'PrepSkul Tutoring Session',
        startTime: startTime,
        durationMinutes: durationMinutes,
        attendeeEmails: [tutorEmail, studentEmail],
        description: 'Regular PrepSkul tutoring session',
      );

      // Update recurring session with Meet link
      await _supabase
          .from('recurring_sessions')
          .update({
            'meet_link': calendarEvent.meetLink,
            'calendar_event_id': calendarEvent.id,
          })
          .eq('id', recurringSessionId);

      return calendarEvent.meetLink;
    } catch (e) {
      print('❌ Error generating recurring Meet link: $e');
      rethrow;
    }
  }

  /// Generate Meet link for individual session (regular session)
  /// 
  /// Creates calendar event and generates Meet link for a specific individual session
  /// Called when session starts if link doesn't exist
  /// 
  /// Parameters:
  /// - [sessionId]: Individual session ID
  /// - [tutorId]: Tutor user ID
  /// - [studentId]: Student user ID (learner_id or parent_id)
  /// - [scheduledDate]: Session date
  /// - [scheduledTime]: Session time
  /// - [durationMinutes]: Session duration
  /// - [subject]: Session subject
  static Future<String> generateIndividualSessionMeetLink({
    required String sessionId,
    required String tutorId,
    required String studentId,
    required DateTime scheduledDate,
    required String scheduledTime,
    required int durationMinutes,
    required String subject,
  }) async {
    try {
      // Get tutor and student emails
      final tutorProfile = await _supabase
          .from('profiles')
          .select('email, full_name')
          .eq('id', tutorId)
          .maybeSingle();

      final studentProfile = await _supabase
          .from('profiles')
          .select('email, full_name')
          .eq('id', studentId)
          .maybeSingle();

      final tutorEmail = tutorProfile?['email'] as String?;
      final studentEmail = studentProfile?['email'] as String?;

      if (tutorEmail == null || studentEmail == null) {
        throw Exception('Tutor or student email not found');
      }

      // Parse scheduled time
      final timeParts = scheduledTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1].split(' ')[0]);
      final isPM = scheduledTime.toUpperCase().contains('PM');
      final hour24 = isPM && hour != 12 ? hour + 12 : (hour == 12 && !isPM ? 0 : hour);

      final startTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        hour24,
        minute,
      );

      // Create calendar event with Meet link
      final calendarEvent = await GoogleCalendarService.createSessionEvent(
        title: 'PrepSkul Session: $subject',
        startTime: startTime,
        durationMinutes: durationMinutes,
        attendeeEmails: [tutorEmail, studentEmail],
        description: 'PrepSkul tutoring session - $subject',
      );

      // Update individual session with Meet link and calendar event ID
      await _supabase
          .from('individual_sessions')
          .update({
            'meeting_link': calendarEvent.meetLink,
            'calendar_event_id': calendarEvent.id,
            'meet_link_generated_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);

      print('✅ Meet link generated for individual session: $sessionId');
      return calendarEvent.meetLink;
    } catch (e) {
      print('❌ Error generating individual session Meet link: $e');
      rethrow;
    }
  }

  /// Verify Meet link access (payment check)
  /// 
  /// Checks if user can access Meet link (payment must be verified)
  /// 
  /// Parameters:
  /// - [sessionId]: Session ID (trial or recurring)
  /// - [sessionType]: 'trial' or 'recurring'
  static Future<bool> canAccessMeetLink(String sessionId, String sessionType) async {
    try {
      if (sessionType == 'trial') {
        final session = await _supabase
            .from('trial_sessions')
            .select('payment_status, status')
            .eq('id', sessionId)
            .maybeSingle();

        if (session == null) return false;

        final paymentStatus = session['payment_status'] as String?;
        final status = session['status'] as String?;

        // Can access if payment is paid and status is scheduled or completed
        return paymentStatus == 'paid' && 
               (status == 'scheduled' || status == 'completed');
      } else if (sessionType == 'recurring') {
        final session = await _supabase
            .from('recurring_sessions')
            .select('status')
            .eq('id', sessionId)
            .maybeSingle();

        if (session == null) return false;

        final status = session['status'] as String?;
        // Can access if session is active
        return status == 'active';
      }

      return false;
    } catch (e) {
      print('❌ Error checking Meet link access: $e');
      return false;
    }
  }
}






