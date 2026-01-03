import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/google_calendar_service.dart';
import 'package:prepskul/core/services/google_calendar_auth_service.dart';
import 'package:prepskul/core/services/notification_service.dart';

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
  static Future<String?> generateTrialMeetLink({
    required String trialSessionId,
    required String tutorId,
    required String studentId,
    required DateTime scheduledDate,
    required String scheduledTime,
    required int durationMinutes,
  }) async {
    try {
      // Check if Google Calendar is authenticated first
      final isAuthenticated = await GoogleCalendarAuthService.isAuthenticated();
      if (!isAuthenticated) {
        LogService.warning('Google Calendar not authenticated. Attempting to generate Meet link via API...');
        // Try to generate Meet link via Google Calendar API (will prompt for auth if needed)
        final meetLink = await _generateSimpleMeetLink(trialSessionId);
        if (meetLink != null && meetLink.isNotEmpty) {
          return meetLink;
        }
        // If still no link, log error and return null
        LogService.error('Failed to generate Meet link. Google Calendar authentication required.');
        return null;
      }

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
        LogService.warning('Tutor or student email not found. Attempting to generate Meet link via API...');
        final meetLink = await _generateSimpleMeetLink(trialSessionId);
        if (meetLink != null && meetLink.isNotEmpty) {
          return meetLink;
        }
        LogService.error('Failed to generate Meet link. Tutor and student emails are required.');
        return null;
      }

      // Parse scheduled time
      final timeParts = scheduledTime.split(':');
      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minutePart = timeParts.length > 1 ? timeParts[1].split(' ')[0] : '0';
      final minute = int.tryParse(minutePart) ?? 0;
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

      // Create calendar event with Meet link (requires OAuth verification)
      // Note: Meet links MUST be created through Calendar API - random links don't work
      // If Calendar API fails, we cannot generate valid Meet links
      // Alternative: Use Fathom video (see FATHOM_API_DOCUMENTATION.md)
      final calendarEvent = await GoogleCalendarService.createSessionEvent(
        title: 'Trial Session: $subject',
        startTime: startTime,
        durationMinutes: durationMinutes,
        attendeeEmails: [tutorEmail, studentEmail],
        description: 'PrepSkul trial tutoring session',
      );
      
      final meetLink = calendarEvent.meetLink;
      final calendarEventId = calendarEvent.id;

      // Update trial session with Meet link and calendar event ID
      await _supabase
          .from('trial_sessions')
          .update({
            'meet_link': meetLink,
            'calendar_event_id': calendarEventId,
            'meet_link_generated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', trialSessionId);

      // Send notifications to tutor and student
      await _notifyMeetLinkGenerated(trialSessionId, calendarEvent.meetLink);

      return calendarEvent.meetLink;
    } catch (e) {
      LogService.warning('Error generating calendar Meet link: $e. Attempting fallback...');
      // Fallback: try to generate Meet link via API
      final meetLink = await _generateSimpleMeetLink(trialSessionId);
      if (meetLink != null && meetLink.isNotEmpty) {
        return meetLink;
      }
      LogService.error('Failed to generate Meet link. Error: $e');
      return null;
    }
  }

  /// Generate a Google Meet link using Google Calendar API
  /// This creates a real, valid Google Meet meeting
  /// If authentication fails, returns null and logs a warning
  static Future<String?> _generateSimpleMeetLink(String trialSessionId) async {
    try {
      // Try to authenticate Google Calendar if not already authenticated
      final isAuthenticated = await GoogleCalendarAuthService.isAuthenticated();
      if (!isAuthenticated) {
        LogService.warning('Google Calendar not authenticated. Cannot generate Meet link.');
        LogService.info('Please connect Google Calendar to generate valid Meet links.');
        return null;
      }

      // Get trial session details
      final trialSession = await _supabase
          .from('trial_sessions')
          .select('tutor_id, learner_id, scheduled_date, scheduled_time, duration_minutes, subject')
          .eq('id', trialSessionId)
          .maybeSingle();

      if (trialSession == null) {
        LogService.error('Trial session not found: $trialSessionId');
        return null;
      }

      // Get tutor and student emails
      final tutorProfile = await _supabase
          .from('profiles')
          .select('email, full_name')
          .eq('id', trialSession['tutor_id'] as String)
          .maybeSingle();

      final studentProfile = await _supabase
          .from('profiles')
          .select('email, full_name')
          .eq('id', trialSession['learner_id'] as String)
          .maybeSingle();

      final tutorEmail = tutorProfile?['email'] as String?;
      final studentEmail = studentProfile?['email'] as String?;

      if (tutorEmail == null || studentEmail == null) {
        LogService.warning('Tutor or student email not found. Cannot generate Meet link.');
        return null;
      }

      // Parse scheduled time
      final scheduledDate = DateTime.parse(trialSession['scheduled_date'] as String);
      final scheduledTime = trialSession['scheduled_time'] as String;
      final timeParts = scheduledTime.split(':');
      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minutePart = timeParts.length > 1 ? timeParts[1].split(' ')[0] : '0';
      final minute = int.tryParse(minutePart) ?? 0;
      final isPM = scheduledTime.toUpperCase().contains('PM');
      final hour24 = isPM && hour != 12 ? hour + 12 : (hour == 12 && !isPM ? 0 : hour);

      final startTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        hour24,
        minute,
      );

      final durationMinutes = trialSession['duration_minutes'] as int? ?? 60;
      final subject = trialSession['subject'] as String? ?? 'Trial Session';

      // Create calendar event with Meet link using Google Calendar API
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
      
      LogService.success('Meet link generated via Google Calendar API: ${calendarEvent.meetLink}');
      
      // Send notifications to tutor and student
      await _notifyMeetLinkGenerated(trialSessionId, calendarEvent.meetLink);
      
      return calendarEvent.meetLink;
    } catch (e) {
      LogService.error('Error generating Meet link via Google Calendar API: $e');
      // Return null instead of throwing - this allows the calling code to handle gracefully
      return null;
    }
  }

  /// Send notifications to tutor and student when meet link is generated
  static Future<void> _notifyMeetLinkGenerated(String trialSessionId, String meetLink) async {
    try {
      // Get trial session details
      final trialSession = await _supabase
          .from('trial_sessions')
          .select('tutor_id, learner_id, parent_id, subject')
          .eq('id', trialSessionId)
          .maybeSingle();

      if (trialSession == null) {
        LogService.warning('Trial session not found for meet link notification: $trialSessionId');
        return;
      }

      final tutorId = trialSession['tutor_id'] as String;
      final learnerId = trialSession['learner_id'] as String;
      final subject = trialSession['subject'] as String? ?? 'Trial Session';

      // Get tutor and student names for notification
      final tutorProfile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', tutorId)
          .maybeSingle();
      final studentProfile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', learnerId)
          .maybeSingle();

      final tutorName = tutorProfile?['full_name'] as String? ?? 'Tutor';
      final studentName = studentProfile?['full_name'] as String? ?? 'Student';

      // Notify tutor
      await NotificationService.createNotification(
        userId: tutorId,
        type: 'session_started',
        title: '🎥 Session Meet Link Ready',
        message: 'Your session with $studentName is ready. Click to join the meeting.',
        priority: 'high',
        actionUrl: '/sessions/$trialSessionId',
        actionText: 'Join Session',
        icon: '🎥',
        metadata: {
          'session_id': trialSessionId,
          'session_type': 'trial',
          'meet_link': meetLink,
          'subject': subject,
          'student_name': studentName,
        },
      );

      // Notify student/learner
      await NotificationService.createNotification(
        userId: learnerId,
        type: 'session_started',
        title: '🎥 Session Meet Link Ready',
        message: 'Your session with $tutorName is ready. Click to join the meeting.',
        priority: 'high',
        actionUrl: '/sessions/$trialSessionId',
        actionText: 'Join Session',
        icon: '🎥',
        metadata: {
          'session_id': trialSessionId,
          'session_type': 'trial',
          'meet_link': meetLink,
          'subject': subject,
          'tutor_name': tutorName,
        },
      );

      // Also notify parent if exists
      final parentId = trialSession['parent_id'] as String?;
      if (parentId != null && parentId.isNotEmpty) {
        await NotificationService.createNotification(
          userId: parentId,
          type: 'session_started',
          title: '🎥 Session Meet Link Ready',
          message: 'Your child\'s session with $tutorName is ready. Click to view details.',
          priority: 'high',
          actionUrl: '/sessions/$trialSessionId',
          actionText: 'View Session',
          icon: '🎥',
          metadata: {
            'session_id': trialSessionId,
            'session_type': 'trial',
            'meet_link': meetLink,
            'subject': subject,
            'tutor_name': tutorName,
          },
        );
      }

      LogService.success('Meet link notifications sent to tutor and student');
    } catch (e) {
      LogService.warning('Error sending meet link notifications: $e');
      // Don't fail the whole process if notifications fail
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

      // Create calendar event with Meet link (requires OAuth verification)
      // Note: Meet links MUST be created through Calendar API - random links don't work
      // If Calendar API fails, we cannot generate valid Meet links
      // Alternative: Use Fathom video (see FATHOM_API_DOCUMENTATION.md)
      final calendarEvent = await GoogleCalendarService.createSessionEvent(
        title: 'PrepSkul Tutoring Session',
        startTime: startTime,
        durationMinutes: durationMinutes,
        attendeeEmails: [tutorEmail, studentEmail],
        description: 'Regular PrepSkul tutoring session',
      );
      
      final meetLink = calendarEvent.meetLink;
      final calendarEventId = calendarEvent.id;

      // Update recurring session with Meet link
      await _supabase
          .from('recurring_sessions')
          .update({
            'meet_link': meetLink,
            'calendar_event_id': calendarEventId,
          })
          .eq('id', recurringSessionId);

      return meetLink;
    } catch (e) {
      LogService.error('Error generating recurring Meet link: $e');
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

      // Create calendar event with Meet link (requires OAuth verification)
      // Note: Meet links MUST be created through Calendar API - random links don't work
      // If Calendar API fails, we cannot generate valid Meet links
      // Alternative: Use Fathom video (see FATHOM_API_DOCUMENTATION.md)
      final calendarEvent = await GoogleCalendarService.createSessionEvent(
        title: 'PrepSkul Session: $subject',
        startTime: startTime,
        durationMinutes: durationMinutes,
        attendeeEmails: [tutorEmail, studentEmail],
        description: 'PrepSkul tutoring session - $subject',
      );
      
      final meetLink = calendarEvent.meetLink;
      final calendarEventId = calendarEvent.id;

      // Update individual session with Meet link and calendar event ID
      await _supabase
          .from('individual_sessions')
          .update({
            'meeting_link': meetLink,
            'calendar_event_id': calendarEventId,
            'meet_link_generated_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);

      LogService.success('Meet link generated for individual session: $sessionId');
      return meetLink;
    } catch (e) {
      LogService.error('Error generating individual session Meet link: $e');
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
      LogService.error('Error checking Meet link access: $e');
      return false;
    }
  }
}