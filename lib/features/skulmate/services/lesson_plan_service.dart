import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<List<LessonPlan>> readCached() async {
    try {
      final uid = SupabaseService.client.auth.currentUser?.id;
      if (uid == null) return [];
      final prefs = await SharedPreferences.getInstance();
      final rows =
          jsonDecode(prefs.getString('learning_paths_v1_$uid') ?? '[]') as List;
      return rows
          .map((row) => LessonPlan.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Only the signed-in learner's saved paths; errors must remain visible.
  static Future<List<LessonPlan>> listSaved() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Please sign in to see your learning path.');
    }
    final rows = await SupabaseService.client
        .from('skulmate_lessons')
        .select('id, topic, steps, current_step, source_game_id, child_id')
        .eq('user_id', userId)
        .isFilter('child_id', null)
        .order('updated_at', ascending: false)
        .limit(8)
        .timeout(const Duration(seconds: 12));
    final plans = rows.map((row) => LessonPlan.fromJson(row)).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('learning_paths_v1_$userId', jsonEncode(rows));
    } catch (_) {
      /* Storage failure must not discard a successful server read. */
    }
    return plans;
  }

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
      throw Exception(
        _decodeJson(response.body)?['error']?.toString() ??
            'Could not save your learning path. Please try again.',
      );
    }
    final lessonJson = _decodeJson(response.body)?['lesson'];
    if (lessonJson is! Map<String, dynamic> || lessonJson['id'] == null) {
      throw StateError('The learning path was not saved. Please try again.');
    }
    return LessonPlan.fromJson(lessonJson);
  }

  /// Mark step complete and advance current_step in Supabase.
  static Future<LessonPlan> completeStep({
    required LessonPlan lesson,
    required int stepIndex,
    String? sessionId,
    String? turnId,
  }) async {
    final token = SupabaseService.client.auth.currentSession?.accessToken;
    if (token == null) throw StateError('Sign in to save your path.');
    final response = await SkulMateService.postJson(
      url: '$_apiBaseUrl/skulmate/lesson-progress',
      token: token,
      body: {
        'lessonId': lesson.id,
        'stepIndex': stepIndex,
        if (sessionId != null) 'sessionId': sessionId,
        if (turnId != null) 'turnId': turnId,
        'acknowledged': lesson.steps[stepIndex].isContentOnly,
      },
    );
    final json = _decodeJson(response.body);
    if (response.statusCode != 200 ||
        json?['lesson'] is! Map<String, dynamic>) {
      throw StateError(
        json?['error']?.toString() ??
            'Your path could not be saved. Please retry.',
      );
    }
    return LessonPlan.fromJson(json!['lesson'] as Map<String, dynamic>);
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
