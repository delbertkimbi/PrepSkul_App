import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/screener.dart';

/// Parent screener + first-run flags that must survive app restart.
///
/// Without this, every cold start re-opens onboarding and the handoff → demo →
/// warm-up ceremony — which is exactly "the same start every time for everyone"
/// even when [EvidenceStore] already knows the child.
class LearnerProfile {
  const LearnerProfile({
    required this.answers,
    this.seenDemo = false,
  });

  final ScreenerAnswers answers;
  final bool seenDemo;

  LearnerProfile copyWith({
    ScreenerAnswers? answers,
    bool? seenDemo,
  }) =>
      LearnerProfile(
        answers: answers ?? this.answers,
        seenDemo: seenDemo ?? this.seenDemo,
      );

  Map<String, dynamic> toJson() => {
        'answers': answers.toJson(),
        'seenDemo': seenDemo,
      };

  factory LearnerProfile.fromJson(Map<String, dynamic> j) {
    final raw = j['answers'];
    final answers = raw is Map<String, dynamic>
        ? ScreenerAnswers.fromJson(raw)
        : const ScreenerAnswers();
    return LearnerProfile(
      answers: answers,
      seenDemo: j['seenDemo'] == true,
    );
  }
}

class LearnerProfileStore {
  LearnerProfileStore._();

  static final LearnerProfileStore instance = LearnerProfileStore._();

  static const String _key = 'primar_learner_profile_v1';

  LearnerProfile? _cache;

  Future<LearnerProfile?> load() async {
    if (_cache != null) return _cache;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      return _cache = LearnerProfile.fromJson(decoded);
    } catch (e) {
      debugPrint('[LearnerProfileStore] unreadable: $e');
      return null;
    }
  }

  Future<void> save(LearnerProfile profile) async {
    _cache = profile;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(profile.toJson()));
    } catch (e) {
      debugPrint('[LearnerProfileStore] could not save: $e');
    }
  }

  Future<void> saveAnswers(ScreenerAnswers answers, {bool? seenDemo}) async {
    final existing = await load();
    await save(
      LearnerProfile(
        answers: answers,
        seenDemo: seenDemo ?? existing?.seenDemo ?? false,
      ),
    );
  }

  Future<void> markSeenDemo() async {
    final existing = await load();
    if (existing == null) return;
    await save(existing.copyWith(seenDemo: true));
  }

  Future<void> clear() async {
    _cache = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('[LearnerProfileStore] could not clear: $e');
    }
  }

  @visibleForTesting
  void seed(LearnerProfile? profile) => _cache = profile;

  @visibleForTesting
  void resetCache() => _cache = null;
}

/// Stable prefs suffix for a child name (siblings on one phone).
String childEvidenceSlug(String name) {
  final cleaned = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (cleaned.isEmpty) return '';
  return cleaned.length > 32 ? cleaned.substring(0, 32) : cleaned;
}
