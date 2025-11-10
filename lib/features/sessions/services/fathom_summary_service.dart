import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/notification_service.dart';
import 'package:prepskul/features/sessions/services/fathom_service.dart';

/// Fathom Summary Distribution Service
/// 
/// Handles fetching and distributing Fathom meeting summaries to participants
/// Documentation: docs/PHASE_1.2_IMPLEMENTATION_PLAN.md

class FathomSummaryService {
  static final _supabase = SupabaseService.client;

  /// Fetch and store summary for a session
  /// 
  /// Fetches summary from Fathom API and stores in database
  /// 
  /// Parameters:
  /// - [recordingId]: Fathom recording ID
  /// - [sessionId]: Trial or recurring session ID
  /// - [sessionType]: 'trial' or 'recurring'
  static Future<void> fetchAndStoreSummary({
    required int recordingId,
    required String sessionId,
    required String sessionType,
  }) async {
    try {
      // Fetch summary from Fathom
      final summary = await FathomService.getSummary(recordingId);
      
      // Store in database
      await _supabase
          .from('session_summaries')
          .upsert({
            'session_id': sessionId,
            'session_type': sessionType,
            'fathom_recording_id': recordingId,
            'summary_data': summary,
            'created_at': DateTime.now().toIso8601String(),
          }, onConflict: 'session_id,session_type');

      print('✅ Summary stored for session: $sessionId');
    } catch (e) {
      print('❌ Error fetching/storing summary: $e');
      rethrow;
    }
  }

  /// Send summary to all participants
  /// 
  /// Sends meeting summary via in-app notifications to tutor, student, and parent
  /// 
  /// Parameters:
  /// - [sessionId]: Session ID
  /// - [sessionType]: 'trial' or 'recurring'
  /// - [summaryText]: Summary text to send
  /// - [meetingTitle]: Meeting title
  static Future<void> sendSummaryToParticipants({
    required String sessionId,
    required String sessionType,
    required String summaryText,
    required String meetingTitle,
  }) async {
    try {
      // Get session details
      final session = await _getSessionDetails(sessionId, sessionType);
      if (session == null) {
        throw Exception('Session not found');
      }

      final tutorId = session['tutor_id'] as String;
      final studentId = session['learner_id'] as String? ?? session['student_id'] as String?;
      final parentId = session['parent_id'] as String?;

      // Send notification to tutor
      await NotificationService.createNotification(
        userId: tutorId,
        type: 'session_summary_ready',
        title: 'Session Summary Available',
        message: 'Summary for "$meetingTitle" is now available.',
        data: {
          'session_id': sessionId,
          'session_type': sessionType,
          'summary_preview': _getSummaryPreview(summaryText),
        },
      );

      // Send notification to student
      if (studentId != null) {
        await NotificationService.createNotification(
          userId: studentId,
          type: 'session_summary_ready',
          title: 'Session Summary Available',
          message: 'Summary for "$meetingTitle" is now available.',
          data: {
            'session_id': sessionId,
            'session_type': sessionType,
            'summary_preview': _getSummaryPreview(summaryText),
          },
        );
      }

      // Send notification to parent (if applicable)
      if (parentId != null) {
        await NotificationService.createNotification(
          userId: parentId,
          type: 'session_summary_ready',
          title: 'Session Summary Available',
          message: 'Summary for your child\'s session "$meetingTitle" is now available.',
          data: {
            'session_id': sessionId,
            'session_type': sessionType,
            'summary_preview': _getSummaryPreview(summaryText),
          },
        );
      }

      print('✅ Summary notifications sent to all participants');
    } catch (e) {
      print('❌ Error sending summary notifications: $e');
      rethrow;
    }
  }

  /// Get summary for a session
  /// 
  /// Retrieves stored summary from database
  /// 
  /// Parameters:
  /// - [sessionId]: Session ID
  /// - [sessionType]: 'trial' or 'recurring'
  static Future<Map<String, dynamic>?> getSessionSummary({
    required String sessionId,
    required String sessionType,
  }) async {
    try {
      final response = await _supabase
          .from('session_summaries')
          .select()
          .eq('session_id', sessionId)
          .eq('session_type', sessionType)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Error getting session summary: $e');
      return null;
    }
  }

  /// Get session details for summary distribution
  static Future<Map<String, dynamic>?> _getSessionDetails(
    String sessionId,
    String sessionType,
  ) async {
    try {
      if (sessionType == 'trial') {
        final response = await _supabase
            .from('trial_sessions')
            .select('tutor_id, learner_id, parent_id')
            .eq('id', sessionId)
            .maybeSingle();
        return response;
      } else if (sessionType == 'recurring') {
        final response = await _supabase
            .from('recurring_sessions')
            .select('tutor_id, student_id, learner_id')
            .eq('id', sessionId)
            .maybeSingle();
        return response;
      }
      return null;
    } catch (e) {
      print('❌ Error getting session details: $e');
      return null;
    }
  }

  /// Get summary preview (first 100 characters)
  static String _getSummaryPreview(String summary) {
    if (summary.length <= 100) return summary;
    return '${summary.substring(0, 100)}...';
  }
}

