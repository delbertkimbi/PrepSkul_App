import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:prepskul/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/figure.dart';
import '../domain/home_copy.dart';
import '../domain/literacy.dart';
import '../domain/micro_lesson.dart';
import '../domain/misconception.dart';
import '../domain/parent_phrases.dart';
import '../domain/policy.dart';
import '../domain/skill.dart';
import '../domain/tutor_feedback.dart';
import 'learner_traits.dart';

/// When the tutor speaks — home vs in-session beats.
enum TutorMoment {
  homeNext,
  correct,
  miss,
  retry,
  speak,
  reteach,
  microLesson,
  waiting,
}

extension TutorMomentApi on TutorMoment {
  String get apiName => switch (this) {
        TutorMoment.homeNext => 'home_next',
        TutorMoment.correct => 'correct',
        TutorMoment.miss => 'miss',
        TutorMoment.retry => 'retry',
        TutorMoment.speak => 'speak',
        TutorMoment.reteach => 'reteach',
        TutorMoment.microLesson => 'micro_lesson',
        TutorMoment.waiting => 'waiting',
      };
}

/// Everything the tutor needs to say something specific.
class TutorContext {
  const TutorContext({
    required this.moment,
    required this.locale,
    this.childName,
    this.skillId,
    this.reason,
    this.item,
    this.chosenIndex = -1,
    this.retryCount = 0,
    this.streak = 0,
    this.misconception,
    this.heard,
    this.speakTarget,
    this.speakMatched = false,
    this.letter,
    this.sound,
    this.traits,
  });

  final TutorMoment moment;
  final String locale;
  final String? childName;
  final String? skillId;
  final Reason? reason;
  final PrimarItem? item;
  final int chosenIndex;
  final int retryCount;
  final int streak;
  final Misconception? misconception;
  final String? heard;
  final String? speakTarget;
  final bool speakMatched;
  final String? letter;
  final String? sound;
  final LearnerTraits? traits;

  String get _skillLabel =>
      skillId == null ? '' : (skillsById[skillId!]?.label ?? skillId!);

  String cacheFingerprint() {
    final itemId = item?.id ?? speakTarget ?? letter ?? skillId ?? moment.name;
    final miss = misconception?.name ?? '';
    final chosen = chosenIndex >= 0 ? '_c$chosenIndex' : '';
    return '${moment.apiName}_${locale}_${skillId ?? 'x'}_${itemId}_$miss$chosen';
  }
}

/// Result of [TutorBrain.lineFor] — always safe to speak.
class TutorLineResult {
  const TutorLineResult({
    required this.feedback,
    required this.source,
  });

  final TutorFeedback feedback;

  /// `ai`, `cache`, or `local`.
  final String source;
}

/// AI when available; structured local feedback otherwise. Never blocks a session
/// longer than [_aiTimeout] and never returns empty.
class TutorBrain {
  TutorBrain._();

  static final TutorBrain instance = TutorBrain._();

  static const _cacheKey = 'primar_tutor_lines_v1';
  static const _aiTimeout = Duration(milliseconds: 2500);

  Map<String, String>? _lineCache;
  final Set<String> _aiUnavailable = {};

  /// Primary entry: try cache → AI (short timeout) → local [TutorFeedback].
  Future<TutorLineResult> lineFor(TutorContext ctx) async {
    // Authored on device so the second-miss teach cannot go vague or stall.
    if (ctx.moment == TutorMoment.microLesson) {
      return TutorLineResult(
        feedback: _localFeedback(ctx),
        source: 'local',
      );
    }

    final fp = ctx.cacheFingerprint();
    final cached = await _cachedLine(fp);
    if (cached != null) {
      return TutorLineResult(
        feedback: _feedbackFromText(cached, ctx, idSuffix: 'cache'),
        source: 'cache',
      );
    }

    if (!await _isOnline && !_aiUnavailable.contains(fp)) {
      return TutorLineResult(
        feedback: _localFeedback(ctx),
        source: 'local',
      );
    }

    if (!_aiUnavailable.contains(fp)) {
      try {
        final ai = await _fetchAi(ctx).timeout(_aiTimeout);
        if (ai != null && ai.isNotEmpty) {
          await _putCache(fp, ai);
          return TutorLineResult(
            feedback: _feedbackFromText(ai, ctx, idSuffix: 'ai'),
            source: 'ai',
          );
        }
      } catch (e) {
        debugPrint('[TutorBrain] AI fallback: $e');
      }
      _aiUnavailable.add(fp);
    }

    return TutorLineResult(
      feedback: _localFeedback(ctx),
      source: 'local',
    );
  }

  TutorFeedback _localFeedback(TutorContext ctx) {
    final item = ctx.item;
    final locale = ctx.locale;
    final skillId = ctx.skillId;
    final miss = ctx.misconception;

    switch (ctx.moment) {
      case TutorMoment.homeNext:
        final reason = ctx.reason ?? Reason.advance;
        final label = ctx._skillLabel.isEmpty ? 'your next game' : ctx._skillLabel;
        final text = homeNextVoiceLine(
          locale: locale,
          childName: ctx.childName ?? '',
          skillLabel: label,
          reason: reason,
        );
        assert(!isSessionIntroCopy(text));
        return TutorFeedback(
          text: text,
          parentMoment: ParentMoment.none,
          id: 'tutor_home_${skillId ?? 'x'}_${reason.name}',
        );
      case TutorMoment.correct:
        return TutorFeedback.correct(
          item: item!,
          locale: locale,
          skillId: skillId,
          streak: ctx.streak,
          retryCount: ctx.retryCount,
          misconception: miss,
        );
      case TutorMoment.miss:
        final base = TutorFeedback.incorrect(
          item: item!,
          locale: locale,
          chosenIndex: ctx.chosenIndex,
          skillId: skillId,
          retryCount: ctx.retryCount,
          misconception: miss,
        );
        return _withTraitMissHint(base, ctx);
      case TutorMoment.retry:
        return TutorFeedback.retryCue(
          item: item!,
          locale: locale,
          skillId: skillId,
        );
      case TutorMoment.waiting:
        return TutorFeedback.waiting(
          item: item!,
          locale: locale,
          skillId: skillId,
        );
      case TutorMoment.speak:
        final target = ctx.speakTarget ?? '';
        if (ctx.speakMatched) {
          return TutorFeedback.speakMatched(
            target: target,
            locale: locale,
            heard: ctx.heard,
          );
        }
        final heard = ctx.heard?.trim();
        if (heard != null && heard.isNotEmpty) {
          return TutorFeedback.speakCorrective(
            target: target,
            locale: locale,
            heard: heard,
          );
        }
        return TutorFeedback.speakWarm(
          target: target,
          locale: locale,
        );
      case TutorMoment.reteach:
        final base = TutorFeedback.reteach(
          locale: locale,
          letter: ctx.letter,
          sound: ctx.sound,
          misconception: miss,
        );
        return _withTraitMissHint(base, ctx);
      case TutorMoment.microLesson:
        final lesson = MicroLesson.build(
          item: item!,
          locale: locale,
          chosenIndex: ctx.chosenIndex,
          skillId: skillId,
          misconception: miss,
        );
        return TutorFeedback.microLesson(lesson);
    }
  }

  /// When the same error pattern keeps recurring offline, name it out loud.
  TutorFeedback _withTraitMissHint(TutorFeedback base, TutorContext ctx) {
    final traits = ctx.traits;
    if (traits == null) return base;
    final miss = ctx.misconception;
    final fr = ctx.locale == 'fr';

    String? hint;
    if (miss != null &&
        miss != Misconception.unclear &&
        traits.recentMissTags.contains(miss.name)) {
      hint = _recurringMissHint(miss, fr);
    } else if (ctx.skillId != null &&
        traits.strugglingSkillIds.contains(ctx.skillId)) {
      final label = ctx._skillLabel;
      if (label.isNotEmpty) {
        hint = fr
            ? 'On travaille encore $label — regarde bien.'
            : 'We are still working on $label — look carefully.';
      }
    }
    if (hint == null) return base;
    return TutorFeedback(
      text: '${base.text} $hint',
      parentMoment: base.parentMoment,
      parentBridgeId: base.parentBridgeId,
      id: '${base.id}_trait',
    );
  }

  String _recurringMissHint(Misconception miss, bool fr) {
    return fr
        ? switch (miss) {
            Misconception.letterReversal =>
              'Même miroir qu\'avant — regarde de quel côté va la lettre.',
            Misconception.letterShape =>
              'Même forme qu\'avant — regarde bien les traits.',
            Misconception.letterSound =>
              'Même son qu\'avant — écoute bien avant de choisir.',
            Misconception.offByOne =>
              'Encore presque — recompte un par un.',
            Misconception.operandEcho =>
              'Tu as repris un chiffre de la question. Cherche le total.',
            Misconception.wrongOperation =>
              'Écoute le signe — plus ou moins ?',
            Misconception.countingUnstable =>
              'Compte à voix haute, un par un.',
            Misconception.unclear => '',
          }
        : switch (miss) {
            Misconception.letterReversal =>
              'Same mirror mix-up — watch which way the letter faces.',
            Misconception.letterShape =>
              'Same shape mix-up — look at the strokes carefully.',
            Misconception.letterSound =>
              'Same sound mix-up — listen before you tap.',
            Misconception.offByOne =>
              'Almost again — count one by one.',
            Misconception.operandEcho =>
              'You echoed a number from the question. Find the total.',
            Misconception.wrongOperation =>
              'Listen for the sign — plus or minus?',
            Misconception.countingUnstable =>
              'Count out loud, one by one.',
            Misconception.unclear => '',
          };
  }

  TutorFeedback _feedbackFromText(
    String text,
    TutorContext ctx, {
    required String idSuffix,
  }) {
    final parent = switch (ctx.moment) {
      TutorMoment.correct || TutorMoment.speak when ctx.speakMatched =>
        ParentMoment.appreciation,
      TutorMoment.miss ||
      TutorMoment.retry ||
      TutorMoment.reteach ||
      TutorMoment.microLesson =>
        ParentMoment.encouragement,
      TutorMoment.waiting => ParentMoment.patience,
      _ => ParentMoment.none,
    };
    final bridge = switch (ctx.moment) {
      TutorMoment.correct => 'yes',
      TutorMoment.miss => 'look_again',
      TutorMoment.retry => 'now_you_try',
      TutorMoment.waiting => 'take_your_time',
      TutorMoment.reteach || TutorMoment.microLesson => 'have_a_look',
      TutorMoment.speak when ctx.speakMatched => 'i_heard_you',
      _ => null,
    };
    return TutorFeedback(
      text: text,
      parentMoment: parent,
      parentBridgeId: bridge,
      id: 'tutor_${ctx.cacheFingerprint()}_$idSuffix',
    );
  }

  Future<String?> _fetchAi(TutorContext ctx) async {
    final base = AppConfig.effectiveApiBaseUrl;
    final body = {
      'moment': ctx.moment.apiName,
      'locale': ctx.locale,
      if (ctx.childName != null) 'childName': ctx.childName,
      if (ctx.skillId != null) 'skillId': ctx.skillId,
      if (ctx._skillLabel.isNotEmpty) 'skillLabel': ctx._skillLabel,
      if (ctx.item != null) ..._itemPayload(ctx.item!, ctx.locale),
      if (ctx.chosenIndex >= 0 && ctx.item != null)
        'chosen': _label(ctx.item!.options[ctx.chosenIndex], ctx.locale),
      if (ctx.heard != null) 'heard': ctx.heard,
      if (ctx.misconception != null) 'misconception': ctx.misconception!.name,
      'retryCount': ctx.retryCount,
      if (ctx.streak > 0) 'streak': ctx.streak,
      if (ctx.traits != null) ...{
        'strugglingSkills': ctx.traits!.strugglingSkillIds,
        'recentMissTags': ctx.traits!.recentMissTags,
      },
    };

    final response = await http.post(
      Uri.parse('$base/primar/tutor'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    final line = decoded['line'];
    if (line is! String || line.trim().isEmpty) return null;
    if (_isUnsafe(line)) return null;
    if (ctx.moment == TutorMoment.homeNext && isSessionIntroCopy(line)) {
      return null;
    }
    return line.trim();
  }

  Map<String, String> _itemPayload(PrimarItem item, String locale) {
    String? prompt;
    for (final f in item.prompt) {
      if (f is WordFigure) prompt = f.word;
      if (f is PictureFigure) prompt = f.word;
    }
    String? answer;
    if (item.answerIndex >= 0 && item.answerIndex < item.options.length) {
      answer = _label(item.options[item.answerIndex], locale);
    }
    return {
      if (prompt != null) 'itemPrompt': prompt,
      if (answer != null) 'itemAnswer': answer,
    };
  }

  String? _label(Figure f, String locale) => switch (f) {
        LetterFigure(:final letter) => letter,
        WordFigure(:final word) => word,
        PictureFigure(:final word) => word,
        NumeralFigure(:final value) => '$value',
        _ => null,
      };

  bool _isUnsafe(String line) {
    final l = line.toLowerCase();
    for (final w in bannedPrimaryFeedback) {
      if (l.contains(w)) return true;
    }
    return false;
  }

  Future<bool> get _isOnline async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r != ConnectivityResult.none;
    } catch (_) {
      return true;
    }
  }

  Future<Map<String, String>> _loadCache() async {
    if (_lineCache != null) return _lineCache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return _lineCache = {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _lineCache = {};
      return _lineCache = {
        for (final e in decoded.entries)
          e.key as String: e.value as String,
      };
    } catch (_) {
      return _lineCache = {};
    }
  }

  Future<String?> _cachedLine(String fp) async {
    final cache = await _loadCache();
    return cache[fp];
  }

  Future<void> _putCache(String fp, String line) async {
    final cache = await _loadCache();
    cache[fp] = line;
    _lineCache = cache;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(cache));
    } catch (e) {
      debugPrint('[TutorBrain] cache write failed: $e');
    }
  }

  @visibleForTesting
  Future<void> clearCache() async {
    _lineCache = null;
    _aiUnavailable.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  @visibleForTesting
  void markAiUnavailable(String fingerprint) => _aiUnavailable.add(fingerprint);
}
