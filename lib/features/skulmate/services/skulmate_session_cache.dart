import 'dart:convert';

import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/skulmate/models/tutor_session_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device cache of the current tutor thread so a drop still feels continuous.
class SkulMateSessionCache {
  SkulMateSessionCache._();

  static String _key(String sessionId) => 'skulmate_tutor_thread_$sessionId';

  static Future<void> saveTurns({
    required String sessionId,
    required List<TutorTurn> turns,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      turns
          .map(
            (t) => {
              'id': t.id,
              'isUser': t.isUser,
              'text': t.text,
              'speak': t.speak,
              'escalate': t.escalate,
              'move': t.move,
              'surface': t.surface?.toJson(),
            },
          )
          .toList(),
    );
    await prefs.setString(_key(sessionId), encoded);
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        await prefs.setString('skulmate_tutor_active_$userId', sessionId);
      }
    } catch (_) {}
  }

  static Future<void> appendTurn({
    required String sessionId,
    required TutorTurn turn,
  }) async {
    final turns = await loadTurns(sessionId);
    turns.add(turn);
    await saveTurns(sessionId: sessionId, turns: turns);
  }

  static Future<List<TutorTurn>> loadTurns(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(sessionId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<Map>().map((row) {
        final map = Map<String, dynamic>.from(row);
        return TutorTurn(
          id: map['id'] as String?,
          isUser: map['isUser'] as bool? ?? false,
          text: map['text'] as String? ?? '',
          speak: map['speak'] as bool? ?? false,
          escalate: map['escalate'] as bool? ?? false,
          move: map['move'] as String?,
          surface: map['surface'] is Map
              ? PracticeSurface.fromJson(
                  Map<String, dynamic>.from(map['surface'] as Map),
                )
              : null,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> activeSessionId() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return null;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('skulmate_tutor_active_$userId');
    } catch (_) {
      return null;
    }
  }
}
