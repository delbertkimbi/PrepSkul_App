import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:prepskul/core/services/google_calendar_auth_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';

/// Calendar Event Model
class CalendarEvent {
  final String id;
  final String meetLink;
  final String htmlLink;

  CalendarEvent({
    required this.id,
    required this.meetLink,
    required this.htmlLink,
  });
}

/// Google Calendar Service
///
/// Handles calendar event creation and Meet link generation
/// Documentation: docs/PHASE_1.2_IMPLEMENTATION_PLAN.md

class GoogleCalendarService {
  static cal.CalendarApi? _calendarApi;

  /// Initialize Google Calendar API client
  ///
  /// Uses OAuth2 authentication via GoogleCalendarAuthService
  static Future<void> _initializeApi() async {
    if (_calendarApi != null) return;

    try {
      // Check if user is authenticated
      final isAuth = await GoogleCalendarAuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception(
          'Google Calendar not authenticated. Please sign in first using GoogleCalendarAuthService.signIn()',
        );
      }

      // Get authenticated HTTP client
      final client = await GoogleCalendarAuthService.getAuthenticatedClient();
      if (client == null) {
        throw Exception('Failed to get authenticated client for Google Calendar');
      }

      // Initialize Calendar API with authenticated client
      _calendarApi = cal.CalendarApi(client);

      LogService.success('Google Calendar API initialized successfully');
    } catch (e) {
      LogService.error('Error initializing Google Calendar API: $e');
      rethrow;
    }
  }

  /// Create calendar event with Meet link
  ///
  /// Creates a Google Calendar event and auto-generates a Meet link
  /// Adds PrepSkul VA as attendee to trigger Fathom auto-join
  ///
  /// Parameters:
  /// - [title]: Event title (e.g., "Trial Session: Mathematics")
  /// - [startTime]: Session start time
  /// - [durationMinutes]: Session duration
  /// - [attendeeEmails]: List of attendee emails (tutor, student, prepskul-va)
  /// - [description]: Optional event description
  static Future<CalendarEvent> createSessionEvent({
    required String title,
    required DateTime startTime,
    required int durationMinutes,
    required List<String> attendeeEmails,
    String? description,
  }) async {
    try {
      await _initializeApi();
      if (_calendarApi == null) {
        throw Exception('Calendar API not initialized');
      }

      // Get PrepSkul VA email from AppConfig
      final prepskulVAEmail = AppConfig.prepskulVAEmail;

      // Ensure PrepSkul VA is in attendees
      final allAttendees = <String>[...attendeeEmails];
      if (!allAttendees.contains(prepskulVAEmail)) {
        allAttendees.add(prepskulVAEmail);
      }

      // Calculate end time
      final endTime = startTime.add(Duration(minutes: durationMinutes));

      // Create event start/end times
      final startDateTime = cal.EventDateTime()
        ..dateTime = startTime
        ..timeZone = 'Africa/Douala';

      final endDateTime = cal.EventDateTime()
        ..dateTime = endTime
        ..timeZone = 'Africa/Douala';

      // Create attendees list
      final attendees = allAttendees
          .map(
            (email) => cal.EventAttendee()
              ..email = email
              ..responseStatus = 'needsAction',
          )
          .toList();

      // Create conference solution key
      final solutionKey = cal.ConferenceSolutionKey()..type = 'hangoutsMeet';

      // Create conference request for Meet link
      final conferenceRequest = cal.CreateConferenceRequest()
        ..requestId = 'prepskul-${DateTime.now().millisecondsSinceEpoch}'
        ..conferenceSolutionKey = solutionKey;

      // Create conference data
      final conferenceData = cal.ConferenceData()
        ..createRequest = conferenceRequest;

      // Create event
      final event = cal.Event()
        ..summary = title
        ..description = description ?? 'PrepSkul tutoring session'
        ..start = startDateTime
        ..end = endDateTime
        ..attendees = attendees
        ..conferenceData = conferenceData;

      // Insert event
      final createdEvent = await _calendarApi!.events.insert(
        event,
        'primary', // Calendar ID (primary = user's main calendar)
        conferenceDataVersion: 1, // Required for Meet link generation
      );

      // Extract Meet link
      final meetLink =
          createdEvent.conferenceData?.entryPoints
              ?.firstWhere(
                (ep) => ep.entryPointType == 'video',
                orElse: () => cal.EntryPoint(),
              )
              .uri ??
          createdEvent.hangoutLink ??
          '';

      if (meetLink.isEmpty) {
        LogService.debug(
          '⚠️ Warning: Meet link not generated for event ${createdEvent.id}',
        );
      }

      LogService.success('Calendar event created: ${createdEvent.id}');
      LogService.success('Meet link: $meetLink');

      return CalendarEvent(
        id: createdEvent.id ?? '',
        meetLink: meetLink,
        htmlLink: createdEvent.htmlLink ?? '',
      );
    } catch (e) {
      LogService.error('Error creating calendar event: $e');
      rethrow;
    }
  }

  /// Cancel calendar event
  ///
  /// Cancels a scheduled calendar event
  ///
  /// Parameters:
  /// - [eventId]: Calendar event ID
  static Future<void> cancelEvent(String eventId) async {
    try {
      await _initializeApi();
      if (_calendarApi == null) {
        throw Exception('Calendar API not initialized');
      }

      await _calendarApi!.events.delete('primary', eventId);
      LogService.success('Calendar event cancelled: $eventId');
    } catch (e) {
      LogService.error('Error cancelling calendar event: $e');
      rethrow;
    }
  }

  /// Get calendar event by ID
  ///
  /// Retrieves a calendar event
  ///
  /// Parameters:
  /// - [eventId]: Calendar event ID
  static Future<cal.Event?> getEvent(String eventId) async {
    try {
      await _initializeApi();
      if (_calendarApi == null) {
        throw Exception('Calendar API not initialized');
      }

      final event = await _calendarApi!.events.get('primary', eventId);
      return event;
    } catch (e) {
      LogService.error('Error getting calendar event: $e');
      return null;
    }
  }
}


