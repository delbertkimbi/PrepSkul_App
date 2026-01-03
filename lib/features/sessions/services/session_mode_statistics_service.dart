import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Session Mode Statistics Service
///
/// Calculates statistics about online vs onsite usage for flexible sessions
class SessionModeStatisticsService {
  static final _supabase = SupabaseService.client;

  /// Get mode statistics for a recurring session
  ///
  /// Returns a map with:
  /// - 'online_count': Number of online sessions
  /// - 'onsite_count': Number of onsite sessions
  /// - 'total_count': Total number of sessions
  static Future<Map<String, dynamic>> getModeStatistics(String recurringSessionId) async {
    try {
      final sessions = await _supabase
          .from('individual_sessions')
          .select('location')
          .eq('recurring_session_id', recurringSessionId);

      int onlineCount = 0;
      int onsiteCount = 0;

      for (final session in sessions) {
        final location = session['location'] as String?;
        if (location == 'online') {
          onlineCount++;
        } else if (location == 'onsite') {
          onsiteCount++;
        }
      }

      return {
        'online_count': onlineCount,
        'onsite_count': onsiteCount,
        'total_count': onlineCount + onsiteCount,
      };
    } catch (e) {
      LogService.error('Error getting mode statistics: $e');
      return {
        'online_count': 0,
        'onsite_count': 0,
        'total_count': 0,
      };
    }
  }
}

