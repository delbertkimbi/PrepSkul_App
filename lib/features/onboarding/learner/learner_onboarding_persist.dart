import 'dart:convert';

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
  static const _draftKey = 'learner_onboarding_draft';
  static const _draftStepKey = 'learner_onboarding_draft_step';

  /// Keep a learner's answers on this device until they create an account.
  static Future<void> saveDraft(
    LearnerOnboardingAnswers answers, {
    int? step,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(answers.toJson()));
    await prefs.setString('preferred_language', answers.locale);
    await prefs.setString('skulmate.voiceOut', answers.voiceOut ? 'on' : 'off');
    if (step != null) await prefs.setInt(_draftStepKey, step);
  }

  static Future<int> loadDraftStep({int fallback = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_draftStepKey) ?? fallback;
  }

  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
  }

  static Future<LearnerOnboardingAnswers?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_draftKey);
    if (value == null || value.isEmpty) return null;
    try {
      return LearnerOnboardingAnswers.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } catch (e) {
      LogService.warning('Could not restore learner onboarding draft: $e');
      await prefs.remove(_draftKey);
      await prefs.remove(_draftStepKey);
      return null;
    }
  }

  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    await prefs.remove(_draftStepKey);
  }

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
    final cityName = city?.id == 'other' || city == null
        ? a.cityOther?.trim()
        : city.label.t(a.locale);
    final locale = a.locale;
    final educationLevel = level?.educationLevel ?? 'Secondary School';
    final examLabel = exam == null || exam.id == 'none'
        ? null
        : exam.label.t(locale);
    final examType = _examType(exam?.id, pack.id);
    final goals = _goal(a.learningGoalId, a.examWhenId, examLabel, locale);
    final subjectName = subject?.id == 'other'
        ? a.subjectOther?.trim()
        : subject?.label.t(locale);

    return {
      'preferred_language': locale,
      'language_preference': locale,
      if (a.accountRole == 'parent') 'child_name': a.name,
      'country_code': pack.countryCode,
      'city': cityName,
      'school_system': system.id,
      'education_level': educationLevel,
      'class_level': level?.label.t(locale) ?? a.levelId,
      'exam_type': examType,
      'specific_exam': examLabel,
      'subjects': subjectName == null || subjectName.isEmpty
          ? <String>[]
          : [subjectName],
      'learning_path': a.learningGoalId == 'exam-prep'
          ? 'Exam Preparation'
          : 'Academic Tutoring',
      'learning_goals': goals,
      'learning_style': a.paceId,
      'learning_styles': [a.channelId],
      'confidence_level': a.examFeelId,
      'preferred_location': switch (a.tutorModeId) {
        'in-person' => 'onsite',
        'flexible' => 'online_or_onsite',
        'online' => 'online',
        _ => null,
      },
      // The relational columns above power current tutor matching. This
      // versioned JSONB keeps every answer, including custom/region-specific
      // values, available for future recommendations.
      'onboarding_context': a.toJson(),
    };
  }

  static Future<bool> save(LearnerOnboardingAnswers answers) async {
    await LanguageService.setLanguage(Locale(answers.locale));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_language', answers.locale);
    if (answers.superChoice != null) {
      await prefs.setString('skulmate.super', answers.superChoice!);
    }
    await prefs.setString('skulmate.voiceOut', answers.voiceOut ? 'on' : 'off');

    final data = toSurveyMap(answers);
    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String?;
      if (userId == null || userId.isEmpty) return false;
      if (answers.accountRole == 'parent') {
        await SurveyRepository.saveParentSurvey(userId, data);
      } else {
        await SurveyRepository.saveStudentSurvey(userId, data);
      }
      await prefs.setBool('survey_completed', true);
      await prefs.setBool('survey_intro_seen', true);
      await prefs.remove(_draftKey);
      await prefs.remove(_draftStepKey);
      return true;
    } catch (e) {
      LogService.warning('Learner onboarding save deferred: $e');
      return false;
    }
  }

  static String? _examType(String? examId, String countryId) {
    if (examId == null || examId == 'none' || examId == 'unsure') return null;
    if (examId == 'sat' || examId == 'ap' || examId == 'ielts') {
      return 'International Exams';
    }
    if (examId == 'concours' || examId == 'jamb') return 'Concours';
    if (countryId == 'us' || countryId == 'gb') return 'International Exams';
    return 'Regional Exams';
  }

  static List<String> _goal(
    String? goalId,
    String? whenId,
    String? examLabel,
    String locale,
  ) {
    if (goalId == 'exam-prep') {
      if (examLabel == null) {
        return [locale == 'fr' ? 'Préparer un examen' : 'Prepare for an exam'];
      }
      return [
        if (whenId == 'soon')
          locale == 'fr' ? 'Préparer $examLabel' : 'Prepare for $examLabel'
        else
          locale == 'fr'
              ? 'Progresser vers $examLabel'
              : 'Build toward $examLabel',
      ];
    }
    if (goalId == 'catch-up') {
      return [locale == 'fr' ? 'Rattraper les leçons' : 'Catch up on lessons'];
    }
    return [
      locale == 'fr'
          ? 'Comprendre les leçons et les devoirs'
          : 'Understand lessons and homework',
    ];
  }
}
