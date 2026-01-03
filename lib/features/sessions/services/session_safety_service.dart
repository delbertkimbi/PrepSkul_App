import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/features/sessions/services/location_sharing_service.dart';

/// Session Safety Service
///
/// Handles safety features for onsite sessions:
/// - Share location with emergency contact
/// - Trigger panic button alerts
class SessionSafetyService {
  static final _supabase = SupabaseService.client;

  /// Share location with emergency contact
  ///
  /// Parameters:
  /// - [sessionId]: The session ID
  /// - [userId]: The user ID (tutor or student)
  /// - [userType]: 'tutor' or 'student'
  ///
  /// Returns: true if successful, false otherwise
  static Future<bool> shareWithEmergencyContact({
    required String sessionId,
    required String userId,
    required String userType,
  }) async {
    try {
      return await LocationSharingService.shareWithEmergencyContact(
        sessionId: sessionId,
        userId: userId,
        userType: userType,
      );
    } catch (e) {
      LogService.error('Error sharing location with emergency contact: $e');
      return false;
    }
  }

  /// Trigger panic button alert
  ///
  /// Parameters:
  /// - [sessionId]: The session ID
  /// - [userId]: The user ID (tutor or student)
  /// - [userType]: 'tutor' or 'student'
  /// - [reason]: Reason for triggering panic button
  ///
  /// Returns: true if successful, false otherwise
  static Future<bool> triggerPanicButton({
    required String sessionId,
    required String userId,
    required String userType,
    required String reason,
  }) async {
    try {
      // Record panic button event
      await _supabase.from('session_safety_records').insert({
        'session_id': sessionId,
        'user_id': userId,
        'user_type': userType,
        'event_type': 'panic_button',
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Share location with emergency contact
      await LocationSharingService.shareWithEmergencyContact(
        sessionId: sessionId,
        userId: userId,
        userType: userType,
      );

      // TODO: Send emergency notification to emergency contact
      // This should trigger an immediate notification to the user's emergency contact

      LogService.info('Panic button triggered for session: $sessionId');
      return true;
    } catch (e) {
      LogService.error('Error triggering panic button: $e');
      return false;
    }
  }
}

