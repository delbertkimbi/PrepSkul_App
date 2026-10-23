import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Local learning events, separate from legacy game scores and server mastery.
class LearningActivityStore {
  static String? get _key {
    final user = SupabaseService.currentUser;
    return user == null ? null : 'mate_learning_events_v1_${user.id}';
  }

  static Future<void> record(
    String kind, {
    String? concept,
    bool? correct,
  }) async {
    final key = _key;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    final rows = await read();
    rows.add({
      'at': DateTime.now().toIso8601String(),
      'kind': kind,
      if (concept != null) 'concept': concept,
      if (correct != null) 'correct': correct,
    });
    await prefs.setString(key, jsonEncode(rows));
  }

  static Future<List<Map<String, dynamic>>> read() async {
    final key = _key;
    if (key == null) return [];
    try {
      final p = await SharedPreferences.getInstance();
      return (jsonDecode(p.getString(key) ?? '[]') as List)
          .whereType<Map>()
          .map((v) => Map<String, dynamic>.from(v))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static int streak(List<Map<String, dynamic>> rows, DateTime now) {
    final dates = rows
        .map((r) => DateTime.tryParse(r['at']?.toString() ?? ''))
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    var day = DateTime(now.year, now.month, now.day);
    if (!dates.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
    var count = 0;
    while (dates.contains(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }
}
