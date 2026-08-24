import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/learner.dart';
import '../domain/misconception.dart';
import '../domain/policy.dart';
import '../domain/skill.dart';
import '../domain/subjects.dart';

/// Lightweight learner signals persisted locally for tutor ranking and prompts.
class LearnerTraits {
  const LearnerTraits({
    this.strugglingSkillIds = const [],
    this.recentMissTags = const [],
    this.masteryFrontierSkillId,
    this.preferredLocale = 'en',
  });

  final List<String> strugglingSkillIds;
  final List<String> recentMissTags;
  final String? masteryFrontierSkillId;
  final String preferredLocale;

  Map<String, dynamic> toJson() => {
        'struggling': strugglingSkillIds,
        'misses': recentMissTags,
        'frontier': masteryFrontierSkillId,
        'locale': preferredLocale,
      };

  factory LearnerTraits.fromJson(Map<String, dynamic> j) => LearnerTraits(
        strugglingSkillIds:
            (j['struggling'] as List?)?.whereType<String>().toList() ?? const [],
        recentMissTags:
            (j['misses'] as List?)?.whereType<String>().toList() ?? const [],
        masteryFrontierSkillId: j['frontier'] as String?,
        preferredLocale: j['locale'] as String? ?? 'en',
      );
}

/// Derives and stores traits from the evidence log after each attempt.
class LearnerTraitsStore {
  LearnerTraitsStore._();

  static final LearnerTraitsStore instance = LearnerTraitsStore._();

  static const _key = 'primar_traits_v1';

  LearnerTraits? _cache;

  Future<LearnerTraits> load() async {
    if (_cache != null) return _cache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return _cache = const LearnerTraits();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return _cache = const LearnerTraits();
      return _cache = LearnerTraits.fromJson(decoded);
    } catch (_) {
      return _cache = const LearnerTraits();
    }
  }

  Future<LearnerTraits> recomputeFrom(
    List<Evidence> log, {
    String locale = 'en',
    Subject subject = Subject.reading,
  }) async {
    final learner = learnerFrom(log, locale: locale);
    final struggling = learner.skills.values
        .where((s) =>
            s.state == MasteryState.learning &&
            skillsById[s.skillId]?.subject == subject)
        .toList()
      ..sort((a, b) => a.recentAccuracy.compareTo(b.recentAccuracy));

    final missTags = <String>[];
    for (var i = log.length - 1; i >= 0 && missTags.length < 5; i--) {
      final e = log[i];
      if (e.correct || e.misconception == Misconception.unclear) continue;
      final tag = e.misconception.name;
      if (!missTags.contains(tag)) missTags.add(tag);
    }

    final decision = nextSkill(learner, subject: subject);
    final traits = LearnerTraits(
      strugglingSkillIds: struggling
          .take(3)
          .map((s) => s.skillId)
          .toList(),
      recentMissTags: missTags,
      masteryFrontierSkillId: decision.skillId,
      preferredLocale: locale,
    );
    _cache = traits;
    unawaited(_persist(traits));
    return traits;
  }

  Future<void> recordEvidence(
    List<Evidence> log, {
    String locale = 'en',
    Subject subject = Subject.reading,
  }) async {
    await recomputeFrom(log, locale: locale, subject: subject);
  }

  Future<void> _persist(LearnerTraits traits) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(traits.toJson()));
    } catch (e) {
      debugPrint('[LearnerTraitsStore] could not save: $e');
    }
  }

  @visibleForTesting
  Future<void> clear() async {
    _cache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  @visibleForTesting
  void seed(LearnerTraits traits) => _cache = traits;
}
