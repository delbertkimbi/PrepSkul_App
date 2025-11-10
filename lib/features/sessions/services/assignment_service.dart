import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/notification_service.dart';

/// Assignment Service
/// 
/// Handles action items extracted from Fathom summaries
/// Creates assignments for students based on meeting action items
/// Documentation: docs/PHASE_1.2_IMPLEMENTATION_PLAN.md

class AssignmentService {
  static final _supabase = SupabaseService.client;

  /// Create assignments from Fathom action items
  /// 
  /// Extracts action items from Fathom summary and creates assignments
  /// 
  /// Parameters:
  /// - [sessionId]: Session ID
  /// - [sessionType]: 'trial' or 'recurring'
  /// - [actionItems]: List of action items from Fathom
  static Future<void> createFromFathomActionItems({
    required String sessionId,
    required String sessionType,
    required List<Map<String, dynamic>> actionItems,
  }) async {
    try {
      // Get session details
      final session = await _getSessionDetails(sessionId, sessionType);
      if (session == null) {
        throw Exception('Session not found');
      }

      final tutorId = session['tutor_id'] as String;
      final studentId = session['learner_id'] as String? ?? 
                       session['student_id'] as String?;

      if (studentId == null) {
        throw Exception('Student ID not found');
      }

      // Create assignments for each action item
      for (final item in actionItems) {
        final title = item['title'] as String? ?? 'Action Item';
        final description = item['description'] as String? ?? 
                           item['text'] as String? ?? '';
        final dueDate = item['due_date'] != null
            ? DateTime.parse(item['due_date'] as String)
            : _calculateDefaultDueDate();

        // Create assignment
        await _supabase.from('assignments').insert({
          'session_id': sessionId,
          'session_type': sessionType,
          'student_id': studentId,
          'tutor_id': tutorId,
          'title': title,
          'description': description,
          'due_date': dueDate.toIso8601String(),
          'status': 'pending',
          'fathom_timestamp': item['timestamp'] as String?,
          'fathom_playback_url': item['playback_url'] as String?,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Notify student about new assignment
        await NotificationService.createNotification(
          userId: studentId,
          type: 'new_assignment',
          title: 'New Assignment',
          message: 'You have a new assignment: $title',
          data: {
            'session_id': sessionId,
            'assignment_title': title,
          },
        );
      }

      print('✅ Created ${actionItems.length} assignments from action items');
    } catch (e) {
      print('❌ Error creating assignments: $e');
      rethrow;
    }
  }

  /// Get assignments for a student
  /// 
  /// Retrieves all assignments for a specific student
  /// 
  /// Parameters:
  /// - [studentId]: Student user ID
  /// - [status]: Optional filter by status ('pending', 'completed', 'overdue')
  static Future<List<Map<String, dynamic>>> getStudentAssignments({
    required String studentId,
    String? status,
  }) async {
    try {
      var query = _supabase
          .from('assignments')
          .select()
          .eq('student_id', studentId);

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('due_date', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error getting student assignments: $e');
      return [];
    }
  }

  /// Get assignments for a tutor
  /// 
  /// Retrieves all assignments created by a tutor
  /// 
  /// Parameters:
  /// - [tutorId]: Tutor user ID
  static Future<List<Map<String, dynamic>>> getTutorAssignments({
    required String tutorId,
  }) async {
    try {
      final response = await _supabase
          .from('assignments')
          .select()
          .eq('tutor_id', tutorId)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error getting tutor assignments: $e');
      return [];
    }
  }

  /// Mark assignment as completed
  /// 
  /// Updates assignment status to completed
  /// 
  /// Parameters:
  /// - [assignmentId]: Assignment ID
  static Future<void> markAsCompleted(String assignmentId) async {
    try {
      await _supabase
          .from('assignments')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', assignmentId);

      // Get assignment to notify tutor
      final assignment = await _supabase
          .from('assignments')
          .select('tutor_id, title, student_id')
          .eq('id', assignmentId)
          .maybeSingle();

      if (assignment != null) {
        await NotificationService.createNotification(
          userId: assignment['tutor_id'] as String,
          type: 'assignment_completed',
          title: 'Assignment Completed',
          message: '${assignment['title']} has been completed',
          data: {
            'assignment_id': assignmentId,
            'student_id': assignment['student_id'],
          },
        );
      }

      print('✅ Assignment marked as completed: $assignmentId');
    } catch (e) {
      print('❌ Error marking assignment as completed: $e');
      rethrow;
    }
  }

  /// Update assignment due date
  /// 
  /// Updates the due date for an assignment
  /// 
  /// Parameters:
  /// - [assignmentId]: Assignment ID
  /// - [newDueDate]: New due date
  static Future<void> updateDueDate({
    required String assignmentId,
    required DateTime newDueDate,
  }) async {
    try {
      await _supabase
          .from('assignments')
          .update({
            'due_date': newDueDate.toIso8601String(),
          })
          .eq('id', assignmentId);

      print('✅ Assignment due date updated: $assignmentId');
    } catch (e) {
      print('❌ Error updating assignment due date: $e');
      rethrow;
    }
  }

  /// Get session details for assignment creation
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

  /// Calculate default due date (7 days from now)
  static DateTime _calculateDefaultDueDate() {
    return DateTime.now().add(const Duration(days: 7));
  }
}

