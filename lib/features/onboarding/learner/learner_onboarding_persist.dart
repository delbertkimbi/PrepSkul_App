import 'package:flutter/material.dart';
import 'package:prepskul/core/localization/language_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_answers.dart';
import 'package:prepskul/features/onboarding/region/region_packs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Maps the tutor onboarding into the same profile rows booking still reads.
class LearnerOnboardingPersist {
  static Map<String, dynamic> toSurveyMap(LearnerOnboardingAnswers a) {
    final pack = packById(a.countryId);
    final system = systemById(pack, a.systemId);
    RegionLevel? level;
    for (final item in system.levels) {
      if (item.id == a.levelId) level = item;
    }
    RegionOption? exam;
    for (final item in system.exams) {
      if (item.id == a.examId) exam = item;
    }
    RegionOption? subject;
    for (final item in system.subjects) {
      if (item.id == a.subjectId) subject = item;
    }
    RegionOption? city;
    for (final item in pack.cities) {
      if (item.id == a.cityId) city = item;
    }
    final locale = a.locale;
    final educationLevel = level?.educationLevel ?? 'Secondary School';
    final examLabel =
        exam == null || exam.id == 'none' ? null : exam.label.t(locale);
    final examType = _examType(exam?.id, pack.id);
    final goal = _goal(a.examWhenId, examLabel, locale);

    return {
      'preferred_language': locale,
      'language_preference': locale,
      'student_name': a.name,
      'country': pack.id,
      'city': city?.id,
      'preferred_city': city?.label.t(locale),
      'curriculum': system.id,
      'school_system': system.id,
      'student_grade': educationLevel,
      'education_level': educationLevel,
      'class_level': level?.label.t(locale) ?? a.levelId,
      'exam': exam?.id,
      'exam_type': examType,
      'specific_exam': examLabel,
      'target_exam': examLabel,
      'exam_when': a.examWhenId,
      'subjects': subject == null ? <String>[] : [subject.label.t(locale)],
      'subject_preferences': subject == null ? <String>[] : [subject.id],
      'learning_goals': goal == null ? <String>[] : [goal],
      'learning_style': a.paceId,
      'learning_styles': [a.channelId, if (a.examFeelId != null) a.examFeelId],
      'pace': a.paceId,
      'channel': a.channelId,
      'interests': a.interestIds,
      'account_role': a.accountRole,
    };
  }

  static Future<void> save(LearnerOnboardingAnswers answers) async {
    await LanguageService.setLanguage(Locale(answers.locale));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('survey_completed', true);
    await prefs.setBool('survey_intro_seen', true);
    await prefs.setString('preferred_language', answers.locale);
    if (answers.superChoice != null) {
      await prefs.setString('skulmate.super', answers.superChoice!);
    }

    final data = toSurveyMap(answers);
    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String?;
      if (userId == null || userId.isEmpty) return;
      if (answers.accountRole == 'parent') {
        await SurveyRepository.saveParentSurvey(userId, data);
      } else {
        await SurveyRepository.saveStudentSurvey(userId, data);
      }
    } catch (e) {
      LogService.warning('Learner onboarding save deferred: $e');
    }
  }

  static String? _examType(String? examId, String countryId) {
    if (examId == null || examId == 'none') return null;
    if (examId == 'sat' || examId == 'ap' || examId == 'ielts') {
      return 'International Exams';
    }
    if (examId == 'concours' || examId == 'jamb') return 'Concours';
    if (countryId == 'us' || countryId == 'gb') return 'International Exams';
    return 'Regional Exams';
  }

  static String? _goal(String? whenId, String? examLabel, String locale) {
    if (examLabel == null) {
      return locale == 'fr' ? 'Comprendre vraiment' : 'Understand it for real';
    }
    if (whenId == 'soon') {
      return locale == 'fr' ? 'Préparer $examLabel' : 'Prepare for $examLabel';
    }
    return locale == 'fr'
        ? 'Progresser vers $examLabel'
        : 'Build toward $examLabel';
  }
}
