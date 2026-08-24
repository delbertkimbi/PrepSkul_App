import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:prepskul/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/misconception.dart';

/// Alternative ways to explain a thing, fetched once and kept forever.
///
/// Saying the same words a fourth time to a child who has missed the same
/// concept three times is insistence, not teaching. These are the other angles:
/// a physical action, a comparison, something they already know.
///
/// ## Why this is a bank and not a call
///
/// The model authors; the device replays. A variant set is fetched once per
/// concept, written to disk, and read from disk forever after — so the adaptive
/// behaviour survives an internet shutdown exactly as it survives wifi, and a
/// lesson never stalls waiting on inference.
///
/// Every path through this class has a working answer without the network. If
/// nothing has ever been fetched, the caller uses the built-in teaching lines
/// and the child notices nothing missing.
class ExplanationBank {
  ExplanationBank._();

  static final ExplanationBank instance = ExplanationBank._();

  static const _key = 'primar.explanations';

  /// In-memory copy, so a mid-session lookup never touches disk.
  Map<String, List<String>>? _memory;

  /// Concepts already attempted this run, so a failing network is not retried
  /// on every single miss.
  final Set<String> _attempted = {};

  static String _cacheKey(Misconception m, String locale) => '${m.name}.$locale';

  /// The concept name the server knows this misconception by.
  static String? conceptFor(Misconception m) => switch (m) {
        Misconception.letterReversal => 'letter-reversal',
        Misconception.letterShape => 'letter-shape',
        Misconception.letterSound => 'letter-sound',
        Misconception.offByOne => 'off-by-one',
        Misconception.operandEcho => 'operand-echo',
        Misconception.wrongOperation => 'wrong-operation',
        Misconception.countingUnstable => 'counting-unstable',
        Misconception.unclear => null,
      };

  Future<Map<String, List<String>>> _load() async {
    if (_memory != null) return _memory!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return _memory = {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _memory = {};
      return _memory = {
        for (final e in decoded.entries)
          e.key as String: (e.value as List).whereType<String>().toList(),
      };
    } catch (e) {
      // Corrupt storage is treated as empty rather than crashing a session.
      debugPrint('[ExplanationBank] unreadable, starting empty: $e');
      return _memory = {};
    }
  }

  /// A different way of putting it, or null if none has been banked yet.
  ///
  /// [attempt] rotates through the variants, so a child who keeps missing hears
  /// a genuinely new angle each time rather than the same alternative.
  Future<String?> variantFor(
    Misconception m, {
    required int attempt,
    String locale = 'en',
  }) async {
    final bank = await _load();
    final lines = bank[_cacheKey(m, locale)];
    if (lines == null || lines.isEmpty) return null;
    return lines[attempt % lines.length];
  }

  /// Fetches and banks the variants for a concept. Safe to call whenever — it
  /// does nothing if already banked, already tried, or offline.
  Future<void> ensure(Misconception m, {String locale = 'en'}) async {
    final concept = conceptFor(m);
    if (concept == null) return;

    final key = _cacheKey(m, locale);
    final bank = await _load();
    if (bank.containsKey(key) || _attempted.contains(key)) return;
    _attempted.add(key);

    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.effectiveApiBaseUrl}/primar/explain'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'concept': concept, 'locale': locale, 'count': 4}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      final lines = (decoded['lines'] as List?)?.whereType<String>().toList() ?? const [];
      if (lines.isEmpty) return;

      bank[key] = lines;
      _memory = bank;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(bank));
    } catch (e) {
      // Silent by design. The built-in teaching is already a complete lesson;
      // these variants only ever make it better.
      debugPrint('[ExplanationBank] could not bank $concept: $e');
    }
  }

  /// Banks everything ahead of time, so the variety is already on the device
  /// before a child ever needs it. Called when the app has a connection.
  Future<void> prewarm({String locale = 'en'}) async {
    for (final m in Misconception.values) {
      if (conceptFor(m) == null) continue;
      await ensure(m, locale: locale);
    }
  }

  @visibleForTesting
  Future<void> clear() async {
    _memory = null;
    _attempted.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  @visibleForTesting
  Future<void> seed(Misconception m, List<String> lines, {String locale = 'en'}) async {
    final bank = await _load();
    bank[_cacheKey(m, locale)] = lines;
    _memory = bank;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(bank));
  }
}
