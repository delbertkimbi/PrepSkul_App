import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Optional parent/learner "Confirm start" / "Confirm end" for onsite sessions.
/// Session validity and payment do not depend on this; tutor check-in remains primary.
class OnsiteConfirmationService {
  static var _supabase = SupabaseService.client;

  /// Confirm that the tutor has arrived and the session has started.
  /// Caller must be parent or learner for this session; session must be onsite and in_progress.
  /// Idempotent.
  static Future<void> confirmSessionStarted(String sessionId) async {
    try {
      await _supabase.rpc('confirm_onsite_session_started', params: {'p_session_id': sessionId});
      LogService.success('Confirmed session started: $sessionId');
    } catch (e) {
      LogService.warning('OnsiteConfirmationService.confirmSessionStarted: $e');
      rethrow;
    }
  }

  /// Confirm that the session ended as expected.
  /// Caller must be parent or learner for this session; session must be onsite and completed.
  /// Idempotent.
  static Future<void> confirmSessionEnded(String sessionId) async {
    try {
      await _supabase.rpc('confirm_onsite_session_ended', params: {'p_session_id': sessionId});
      LogService.success('Confirmed session ended: $sessionId');
    } catch (e) {
      LogService.warning('OnsiteConfirmationService.confirmSessionEnded: $e');
      rethrow;
    }
  }
}
