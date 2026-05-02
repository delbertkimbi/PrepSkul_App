import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Startup schema checks for critical runtime flows.
///
/// This is non-blocking and diagnostic-only.
class StartupSchemaService {
  static bool _hasRun = false;

  static Future<void> runChecks() async {
    if (_hasRun) return;
    _hasRun = true;

    try {
      await _checkSessionFeedbackSchema();
      await _checkSessionParticipantsSchema();
    } catch (e) {
      LogService.warning('⚠️ Startup schema checks failed: $e');
    }
  }

  static Future<void> _checkSessionFeedbackSchema() async {
    const requiredColumns = <String>[
      'id',
      'session_id',
      'student_rating',
      'student_review',
      'location_type',
      'session_type',
      'learning_objectives_met',
      'student_progress_rating',
      'would_continue_lessons',
      'session_took_place',
      'session_took_place_notes',
    ];

    final selectExpr = requiredColumns.join(', ');

    try {
      await SupabaseService.client
          .from('session_feedback')
          .select(selectExpr)
          .limit(1);
      LogService.success('✅ Startup schema check: session_feedback OK');
    } catch (e) {
      if (_isMissingRelation(e)) {
        LogService.error(
          '❌ Startup schema check: table public.session_feedback is missing. '
          'Run migrations 022 and 067.',
        );
        return;
      }
      if (_isMissingColumn(e)) {
        LogService.error(
          '❌ Startup schema check: session_feedback is missing one or more required columns. '
          'Run migration 067_add_session_feedback_enhanced_columns.sql.',
        );
        return;
      }
      LogService.warning('⚠️ Startup schema check (session_feedback) error: $e');
    }
  }

  static bool _isMissingRelation(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == 'PGRST205' || code == '42P01') return true;
      final msg = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
          .toLowerCase();
      return msg.contains('could not find the table') &&
          msg.contains('session_feedback');
    }
    final s = error.toString().toLowerCase();
    return (s.contains('pgrst205') || s.contains('42p01')) &&
        s.contains('session_feedback');
  }

  static bool _isMissingColumn(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == 'PGRST204' || code == '42703') return true;
      final msg = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
          .toLowerCase();
      return msg.contains('column') &&
          msg.contains('session_feedback') &&
          msg.contains('does not exist');
    }
    final s = error.toString().toLowerCase();
    return (s.contains('pgrst204') || s.contains('42703')) &&
        s.contains('session_feedback');
  }

  static Future<void> _checkSessionParticipantsSchema() async {
    try {
      await SupabaseService.client
          .from('session_participants')
          .select('individual_session_id')
          .limit(1);
      LogService.success(
        '✅ Startup schema check: session_participants.individual_session_id OK',
      );
    } catch (e) {
      if (_isMissingRelationForTable(e, 'session_participants')) {
        LogService.warning(
          '⚠️ Startup schema check: table public.session_participants is missing. '
          'Run migrations 076 and 077.',
        );
        return;
      }
      if (_isMissingColumnForTable(
        e,
        table: 'session_participants',
        column: 'individual_session_id',
      )) {
        LogService.warning(
          '⚠️ Startup schema check: session_participants.individual_session_id missing '
          '(legacy schema detected). Apply migrations 076_classroom_session_participants.sql '
          'and 077_backfill_session_participants.sql.',
        );
        return;
      }
      LogService.warning(
        '⚠️ Startup schema check (session_participants) error: $e',
      );
    }
  }

  static bool _isMissingRelationForTable(Object error, String tableName) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == 'PGRST205' || code == '42P01') return true;
      final msg = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
          .toLowerCase();
      return msg.contains('could not find the table') &&
          msg.contains(tableName.toLowerCase());
    }
    final s = error.toString().toLowerCase();
    return (s.contains('pgrst205') || s.contains('42p01')) &&
        s.contains(tableName.toLowerCase());
  }

  static bool _isMissingColumnForTable(
    Object error, {
    required String table,
    required String column,
  }) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == 'PGRST204' || code == '42703') return true;
      final msg = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
          .toLowerCase();
      return msg.contains('column') &&
          msg.contains(table.toLowerCase()) &&
          msg.contains(column.toLowerCase()) &&
          msg.contains('does not exist');
    }
    final s = error.toString().toLowerCase();
    return (s.contains('pgrst204') || s.contains('42703')) &&
        s.contains(table.toLowerCase()) &&
        s.contains(column.toLowerCase());
  }
}
