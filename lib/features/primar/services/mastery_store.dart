import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/mastery.dart';

/// Where a session's result actually goes.
///
/// Local first, always. A session finishes on the device, writes its result to
/// the device, and shows the parent their number — none of that may depend on a
/// network that regularly is not there. Syncing is a background nicety layered
/// on top, never a step in the child's path.
///
/// The outbox is the part that matters in this market. A result recorded during
/// an internet shutdown is not lost; it waits, and goes up whenever the phone
/// next has a connection and a signed-in user. Anonymous sessions simply stay
/// local forever, which is exactly right while the product is still being
/// tested with children who have no account.
class MasteryStore {
  MasteryStore._();

  static final MasteryStore instance = MasteryStore._();

  static const _historyKey = 'primar.mastery.history';
  static const _outboxKey = 'primar.mastery.outbox';

  /// Enough to show a parent a trend without letting storage grow forever.
  static const _historyLimit = 120;

  /// One session's result, as kept on the device.
  static const String table = 'skulmate_concept_mastery';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Records a finished session. Never throws — a storage failure must not
  /// swallow the result the child just earned.
  Future<void> record({
    required String topicId,
    required Placement placement,
    String? childId,
  }) async {
    final entry = <String, dynamic>{
      'topic_id': topicId,
      'child_id': childId,
      'level': placement.level,
      'mastery_score': double.parse(placement.masteryScore.toStringAsFixed(4)),
      'correct': placement.correct,
      'total': placement.total,
      'accuracy': double.parse(placement.accuracy.toStringAsFixed(4)),
      'median_ms': placement.medianMs,
      'provisional': placement.provisional,
      'at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final prefs = await _prefs;

      final history = _decode(prefs.getString(_historyKey))..add(entry);
      if (history.length > _historyLimit) {
        history.removeRange(0, history.length - _historyLimit);
      }
      await prefs.setString(_historyKey, jsonEncode(history));

      // A provisional placement is a guess, and syncing guesses would poison
      // the very signal the routing later depends on.
      if (!placement.provisional) {
        final outbox = _decode(prefs.getString(_outboxKey))..add(entry);
        await prefs.setString(_outboxKey, jsonEncode(outbox));
      }
    } catch (e) {
      debugPrint('[MasteryStore] could not record locally: $e');
    }

    // Fire and forget. The result is already safe on the device.
    unawaited(sync());
  }

  /// Every session recorded on this device for a topic, oldest first.
  Future<List<Map<String, dynamic>>> historyFor(String topicId, {String? childId}) async {
    try {
      final prefs = await _prefs;
      return _decode(prefs.getString(_historyKey))
          .where((e) => e['topic_id'] == topicId)
          .where((e) => childId == null || e['child_id'] == childId)
          .toList();
    } catch (e) {
      debugPrint('[MasteryStore] could not read history: $e');
      return const [];
    }
  }

  /// The level a returning child should open on, or null if they are new.
  ///
  /// Reads the most recent settled placement. Provisional ones are skipped —
  /// a session that never converged is not evidence of where a child is, and
  /// opening them on a guess is how a returning child meets a wall.
  Future<double?> lastSettledLevel(String topicId, {String? childId}) async {
    final history = await historyFor(topicId, childId: childId);
    for (final entry in history.reversed) {
      if (entry['provisional'] == true) continue;
      final level = (entry['level'] as num?)?.toDouble();
      if (level != null) return level;
    }
    return null;
  }

  /// True once there is any history for this topic, which is what decides
  /// whether a child sees the full teaching demo again.
  Future<bool> hasPlayed(String topicId, {String? childId}) async =>
      (await historyFor(topicId, childId: childId)).isNotEmpty;

  /// Pushes anything waiting in the outbox. Safe to call at any time; does
  /// nothing when there is no signed-in user or no connection.
  Future<void> sync() async {
    List<Map<String, dynamic>> pending;
    SharedPreferences prefs;

    try {
      prefs = await _prefs;
      pending = _decode(prefs.getString(_outboxKey));
    } catch (e) {
      debugPrint('[MasteryStore] outbox unreadable: $e');
      return;
    }
    if (pending.isEmpty) return;

    // Supabase.instance throws outright if the SDK was never initialised — in
    // a test, in the standalone preview, or if start-up failed. Reaching it
    // outside a guard meant a storage call could take a finished session down
    // with it, which is the one thing this class exists to prevent.
    final SupabaseClient client;
    final User? user;
    try {
      client = Supabase.instance.client;
      user = client.auth.currentUser;
    } catch (e) {
      debugPrint('[MasteryStore] no Supabase available, keeping results local: $e');
      return;
    }

    if (user == null) {
      // Anonymous testing. The rows stay queued rather than being dropped, so
      // an account created later still inherits the history.
      return;
    }

    final sent = <Map<String, dynamic>>[];
    for (final entry in pending) {
      try {
        // Aggregates are recomputed from the whole local history for this
        // topic, so a row that syncs late still lands with correct totals
        // rather than double-counting whatever arrived before it.
        final history = await historyFor(
          entry['topic_id'] as String,
          childId: entry['child_id'] as String?,
        );

        final row = {
          'user_id': user.id,
          if (entry['child_id'] != null) 'child_id': entry['child_id'],
          'topic_id': entry['topic_id'],
          'mastery_score': entry['mastery_score'],
          'attempts': history.length,
          'correct_total': history.fold<int>(0, (s, e) => s + (e['correct'] as int? ?? 0)),
          'question_total': history.fold<int>(0, (s, e) => s + (e['total'] as int? ?? 0)),
          'weak_streak': _weakStreak(history),
          'last_session_accuracy': entry['accuracy'],
          'last_seen_at': entry['at'],
        };

        await client.from(table).upsert(
              row,
              onConflict: entry['child_id'] == null
                  ? 'user_id,topic_id'
                  : 'user_id,child_id,topic_id',
            );
        sent.add(entry);
      } catch (e) {
        // Stop on the first failure and keep the rest queued; a partial drain
        // is fine, silently discarding a result is not.
        debugPrint('[MasteryStore] sync stopped: $e');
        break;
      }
    }

    if (sent.isEmpty) return;
    try {
      final remaining = pending.where((e) => !sent.contains(e)).toList();
      await prefs.setString(_outboxKey, jsonEncode(remaining));
    } catch (e) {
      debugPrint('[MasteryStore] could not trim outbox: $e');
    }
  }

  /// How many sessions in a row have come in below the weak threshold. This is
  /// what a "keeps struggling here" signal is built from.
  static int _weakStreak(List<Map<String, dynamic>> history) {
    var streak = 0;
    for (final e in history.reversed) {
      final score = (e['mastery_score'] as num?)?.toDouble() ?? 0;
      if (score < weakThreshold) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  static List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      // Corrupt storage is treated as empty rather than crashing a child's
      // session on launch.
      return [];
    }
  }

  /// Test seam.
  @visibleForTesting
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_historyKey);
    await prefs.remove(_outboxKey);
  }
}
