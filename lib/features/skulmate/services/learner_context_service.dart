import 'package:prepskul/core/localization/language_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';

/// Builds learner context for generation — curriculum is background-only.
class LearnerContextService {
  /// Always set; API must never block off-syllabus content (e.g. YouTube ML).
  static const enrichmentModeBackground = 'background';

  static Future<Map<String, dynamic>?> build({String? childId}) async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return null;

      final context = <String, dynamic>{
        'enrichmentMode': enrichmentModeBackground,
        'language': LanguageService.languageCode,
      };

      final survey = await SurveyRepository.getParentSurvey(user.id);
      if (survey != null) {
        const keys = [
          'student_grade',
          'class_level',
          'curriculum',
          'exam',
          'exam_type',
          'target_exam',
          'subjects',
          'subject_preferences',
          'learning_goals',
          'learning_style',
          'learning_styles',
          'preferred_language',
          'language_preference',
          'student_age_group',
        ];
        for (final key in keys) {
          final value = survey[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            context[key] = value;
          }
        }
      }

      if (childId != null && childId.isNotEmpty) {
        context['childId'] = childId;
        final userId = user.id;
        try {
          final childRow = await SupabaseService.client
              .from('parent_learners')
              .select(
                'class_level, education_level, exam_type, specific_exam, learning_path, subjects',
              )
              .eq('id', childId)
              .eq('parent_id', userId)
              .maybeSingle();
          if (childRow != null) {
            final row = Map<String, dynamic>.from(childRow);
            if (row['class_level'] != null) {
              context['class_level'] = row['class_level'];
            }
            if (row['education_level'] != null) {
              context['student_grade'] = row['education_level'];
            }
            if (row['exam_type'] != null) {
              context['exam_type'] = row['exam_type'];
            }
            if (row['specific_exam'] != null) {
              context['target_exam'] = row['specific_exam'];
            }
            if (row['learning_path'] != null) {
              context['learning_goals'] = row['learning_path'];
            }
            if (row['subjects'] != null) {
              context['subjects'] = row['subjects'];
            }
          }
        } catch (_) {}
      }

      return context;
    } catch (e) {
      LogService.warning('LearnerContextService.build failed: $e');
      return {
        'enrichmentMode': enrichmentModeBackground,
        'language': LanguageService.languageCode,
      };
    }
  }
}
