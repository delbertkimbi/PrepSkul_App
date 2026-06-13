import 'package:prepskul/core/services/supabase_service.dart';

/// Loads completed VS sessions with summaries for From-class intake.
class SkulMateSessionIntakeService {
  static Future<List<Map<String, dynamic>>> loadRecordedSessions({
    String? childId,
    int limit = 50,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];

    final queryUserId = childId ?? userId;

    final response = await SupabaseService.client
        .from('individual_sessions')
        .select('''
          id,
          scheduled_date,
          scheduled_time,
          session_summary,
          recurring_sessions!inner(
            id,
            tutor_name,
            tutor_avatar_url,
            subject
          )
        ''')
        .or('learner_id.eq.$queryUserId,parent_id.eq.$queryUserId')
        .eq('status', 'completed')
        .not('session_summary', 'is', null)
        .neq('session_summary', '')
        .not('recurring_session_id', 'is', null)
        .order('scheduled_date', ascending: false)
        .order('scheduled_time', ascending: false)
        .limit(limit);

    return (response as List).cast<Map<String, dynamic>>();
  }
}
