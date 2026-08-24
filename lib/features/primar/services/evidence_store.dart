import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/learner.dart';
import '../domain/misconception.dart';
import 'learner_traits.dart';

/// The child's history, kept.
///
/// ## What was missing
///
/// The learner model was a pure fold over an evidence log, which is the right
/// shape — but the log only existed in memory. Closing the app forgot the child
/// completely: every skill back to `notStarted`, every misconception forgotten,
/// every spaced review that was due next Tuesday gone.
///
/// A product whose promise is "grows with your learner" cannot start again
/// every morning. This is the file that makes the promise true.
///
/// ## Why the log and not the model
///
/// The obvious thing to store is the answer — nine skills, each with a state
/// and a percentage. It is smaller and it loads faster.
///
/// It is also a trap. The moment the mastery rule changes — and it will, because
/// "is this child ready" is exactly the kind of judgement that gets better with
/// evidence — every stored model is frozen under the old rule, and there is no
/// way to recompute it because the evidence it came from is gone.
///
/// Storing the log means a change to how mastery is judged re-judges every
/// child's whole history the next time the app opens. The model is a view. The
/// log is the truth.
///
/// ## Why it is bounded
///
/// A child playing daily for a year would accumulate tens of thousands of
/// rows, on a phone with 2GB of RAM. The store keeps the most recent
/// [_perSkillCap] attempts per skill, which is well beyond anything the
/// estimator looks at — it reads the last six — while keeping enough history
/// for the day-count that drives spacing.
///
/// Trimming per skill rather than globally matters: a global cap would quietly
/// erase a skill a child mastered months ago and has not touched since, which
/// is precisely the skill whose review is most valuable.
class EvidenceStore {
  EvidenceStore._();

  static final EvidenceStore instance = EvidenceStore._();

  static const String _key = 'primar_evidence_v1';

  /// How many attempts to keep per skill. Six is what the estimator reads;
  /// forty leaves room for the spacing day-count and for any future rule that
  /// wants a longer view.
  static const int _perSkillCap = 40;

  /// Held in memory so a session never waits on disk between questions.
  List<Evidence>? _cache;

  /// Everything recorded for this child, oldest first.
  ///
  /// Returns an empty log rather than throwing if storage is unavailable or
  /// corrupt. A child whose phone lost the file should get a fresh start, not
  /// a crash — the cost is one re-placement, and the alternative is an app that
  /// will not open.
  Future<List<Evidence>> load() async {
    if (_cache != null) return _cache!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return _cache = [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return _cache = [];

      _cache = decoded
          .whereType<Map<String, dynamic>>()
          .map(_fromJson)
          .whereType<Evidence>()
          .toList();
      return _cache!;
    } catch (e) {
      // Corrupt storage is survived, not fatal.
      debugPrint('[EvidenceStore] unreadable, starting fresh: $e');
      return _cache = [];
    }
  }

  /// The learner, rebuilt from everything on disk.
  Future<Learner> learner({String locale = 'en'}) async =>
      learnerFrom(await load(), locale: locale);

  /// Records one answered item.
  ///
  /// The in-memory log is updated first and returned to the caller immediately,
  /// so the next question never waits for a write. The write itself is allowed
  /// to fail quietly: losing one attempt is a rounding error against the
  /// session, and an exception here would take down a child mid-question.
  Future<List<Evidence>> add(Evidence e) async {
    final log = [...await load(), e];
    _cache = log;
    unawaited(_persist(log));
    unawaited(LearnerTraitsStore.instance.recordEvidence(log));
    return log;
  }

  /// Records several answers as one write.
  ///
  /// The warm-up produces three at once, and adding them one at a time meant
  /// three separate awaits between the child's last tap and the session
  /// reading the log — a window the first question could open inside, seeing
  /// some of the evidence or none of it.
  Future<List<Evidence>> addAll(List<Evidence> items) async {
    if (items.isEmpty) return load();
    final log = [...await load(), ...items];
    _cache = log;
    unawaited(_persist(log));
    unawaited(LearnerTraitsStore.instance.recordEvidence(log));
    return log;
  }

  Future<void> _persist(List<Evidence> log) async {
    try {
      final trimmed = _trim(log);
      _cache = trimmed;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(trimmed.map(_toJson).toList()));
    } catch (e) {
      debugPrint('[EvidenceStore] could not save: $e');
    }
  }

  /// Keeps the most recent [_perSkillCap] attempts per skill, in original order.
  static List<Evidence> _trim(List<Evidence> log) {
    final counts = <String, int>{};
    for (final e in log) {
      counts[e.skillId] = (counts[e.skillId] ?? 0) + 1;
    }
    if (counts.values.every((n) => n <= _perSkillCap)) return log;

    // Walk backwards keeping the newest, then restore chronological order.
    final kept = <Evidence>[];
    final seen = <String, int>{};
    for (var i = log.length - 1; i >= 0; i--) {
      final e = log[i];
      final n = (seen[e.skillId] ?? 0) + 1;
      seen[e.skillId] = n;
      if (n <= _perSkillCap) kept.add(e);
    }
    return kept.reversed.toList();
  }

  /// Forgets everything. Only for a parent explicitly starting a new child on
  /// the same phone — never called automatically.
  Future<void> clear() async {
    _cache = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('[EvidenceStore] could not clear: $e');
    }
  }

  /// Replaces the in-memory log without touching disk.
  ///
  /// Used by tests and by the preview harness, which renders the path and the
  /// profile for a learner partway up the graph. Those screens are only worth
  /// looking at with a history behind them, and seeding one here beats
  /// answering forty questions by hand every time a colour changes.
  void seed(List<Evidence> log) => _cache = log;

  /// Test seam. Drops the cache so the next [load] reads storage for real —
  /// which is the only way to test what a cold start actually sees.
  @visibleForTesting
  void resetCache() => _cache = null;

  static Map<String, dynamic> _toJson(Evidence e) => {
        's': e.skillId,
        'c': e.correct,
        'ms': e.elapsedMs,
        't': e.at.toIso8601String(),
        'h': e.neededTeaching,
        'm': e.misconception.name,
        'x': e.isTransfer,
      };

  static Evidence? _fromJson(Map<String, dynamic> j) {
    try {
      final at = DateTime.tryParse(j['t'] as String? ?? '');
      if (at == null || j['s'] is! String) return null;

      return Evidence(
        skillId: j['s'] as String,
        correct: j['c'] == true,
        elapsedMs: (j['ms'] as num?)?.toInt() ?? 0,
        at: at,
        neededTeaching: j['h'] == true,
        // An unknown name is read as "unclear" rather than dropping the row.
        // The attempt still happened; only our reading of the mistake is lost.
        misconception: Misconception.values.firstWhere(
          (m) => m.name == j['m'],
          orElse: () => Misconception.unclear,
        ),
        isTransfer: j['x'] == true,
      );
    } catch (_) {
      // One bad row must not cost a child the rest of their history.
      return null;
    }
  }
}
