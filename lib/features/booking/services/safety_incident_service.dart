import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Service for creating and listing safety incidents tied to individual_sessions.
/// Used by tutors, parents, and learners to report "Something is wrong" during or after a session.
class SafetyIncidentService {
  static var _supabase = SupabaseService.client;

  /// Incident types for the report form
  static const List<Map<String, String>> incidentTypes = [
    {'value': 'tutor_no_show', 'label': 'Tutor did not show'},
    {'value': 'learner_absent', 'label': 'Learner was absent'},
    {'value': 'felt_unsafe', 'label': 'Felt unsafe'},
    {'value': 'location_issue', 'label': 'Location or access issue'},
    {'value': 'other', 'label': 'Other'},
  ];

  /// Create a safety incident for a session.
  /// [sessionId] must be an individual_sessions.id the current user is part of.
  /// [role] must be 'tutor', 'parent', or 'learner' (matches current user's role in that session).
  /// [severity] 'info' | 'warning' | 'critical'.
  /// [type] e.g. 'tutor_no_show', 'learner_absent', 'felt_unsafe', 'location_issue', 'other'.
  /// [message] required description.
  /// [location] optional GPS or address at time of report.
  static Future<String> createIncident({
    required String sessionId,
    required String role,
    required String severity,
    required String type,
    required String message,
    String? location,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final res = await _supabase.from('safety_incidents').insert({
      'session_id': sessionId,
      'reported_by': userId,
      'role': role,
      'severity': severity,
      'type': type,
      'message': message.trim(),
      if (location != null && location.trim().isNotEmpty) 'location': location.trim(),
    }).select('id').maybeSingle();

    if (res == null) throw Exception('Failed to create safety incident');
    final id = res['id'] as String;
    LogService.success('Safety incident created: $id for session $sessionId');
    return id;
  }

  /// List safety incidents for a session (for participants and admins).
  static Future<List<Map<String, dynamic>>> listForSession(String sessionId) async {
    final res = await _supabase
        .from('safety_incidents')
        .select('id, reported_by, role, severity, type, message, location, created_at, resolved, resolved_at, resolution_notes')
        .eq('session_id', sessionId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }
}
