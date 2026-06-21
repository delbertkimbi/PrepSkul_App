import 'dart:convert';

import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/localization/language_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

import '../models/lesson_plan_model.dart';
import 'learner_context_service.dart';
import 'skulmate_service.dart';

/// Phase D1 — lesson path API + progress persistence.
class LessonPlanService {
  LessonPlanService._();

  static const String _endpoint = '/skulmate/lesson-plan';

  static String get _apiBaseUrl => AppConfig.skulMateHttpApiBase;

  /// Generate a new lesson plan via API and return the persisted row.
  static Future<LessonPlan> createLessonPlan({
    String? topic,
    String? text,
    String? gameId,
    String? childId,
  }) async {
    final session = SupabaseService.client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null) {
      throw Exception('Please log in to start a path.');
    }

    final learnerContext = await LearnerContextService.build(childId: childId);
    final body = <String, dynamic>{
      if (topic != null && topic.trim().isNotEmpty) 'topic': topic.trim(),
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      if (gameId != null && gameId.isNotEmpty) 'gameId': gameId,
      if (childId != null && childId.isNotEmpty) 'childId': childId,
      'locale': LanguageService.languageCode,
      if (learnerContext != null) 'learnerContext': learnerContext,
    };

    final url = '$_apiBaseUrl$_endpoint';
    LogService.info('🗺️ [Path] Creating lesson plan: $url');

    final response = await SkulMateService.postJson(
      url: url,
      token: token,
      body: body,
    );

    if (response.statusCode != 200) {
      final decoded = _decodeJson(response.body);
      final message =
          decoded?['error']?.toString() ?? 'Failed to create lesson path';
      throw Exception(message);
    }

    final decoded = _decodeJson(response.body);
    final lessonJson = decoded?['lesson'];
    if (lessonJson is! Map<String, dynamic>) {
      throw Exception('Invalid lesson plan response');
    }

    return LessonPlan.fromJson(lessonJson);
  }

  /// Mark step complete and advance current_step in Supabase.
  static Future<LessonPlan> completeStep({
    required LessonPlan lesson,
    required int stepIndex,
  }) async {
    if (stepIndex < 0 || stepIndex >= lesson.steps.length) return lesson;

    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return lesson;

    final updatedSteps = lesson.steps
        .asMap()
        .entries
        .map((e) => e.key == stepIndex
            ? e.value.copyWith(status: 'completed')
            : e.value)
        .toList();

    var nextStep = stepIndex + 1;
    if (nextStep >= updatedSteps.length) {
      nextStep = updatedSteps.length - 1;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await SupabaseService.client.from('skulmate_lessons').update({
      'steps': updatedSteps.map((s) => s.toJson()).toList(),
      'current_step': nextStep,
      'updated_at': now,
    }).eq('id', lesson.id).eq('user_id', userId);

    return lesson.copyWith(steps: updatedSteps, currentStep: nextStep);
  }

  static Future<LessonPlan?> fetchLesson(String lessonId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null || lessonId.isEmpty) return null;

    try {
      final row = await SupabaseService.client
          .from('skulmate_lessons')
          .select()
          .eq('id', lessonId)
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return LessonPlan.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      LogService.debug('LessonPlanService.fetchLesson: $e');
      return null;
    }
  }

  static Map<String, dynamic>? _decodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
