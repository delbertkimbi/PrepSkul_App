import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:prepskul/core/services/log_service.dart';
import '../models/game_model.dart';

/// Saved mid-game state for resume.
class GameProgress {
  final String gameId;
  final GameType gameType;
  final int currentIndex;
  final int score;
  final Map<String, dynamic> stateData;
  final DateTime savedAt;

  const GameProgress({
    required this.gameId,
    required this.gameType,
    required this.currentIndex,
    this.score = 0,
    this.stateData = const {},
    required this.savedAt,
  });

  factory GameProgress.fromJson(Map<String, dynamic> json) {
    return GameProgress(
      gameId: json['gameId'] as String,
      gameType: GameType.values.firstWhere(
        (t) => t.name == json['gameType'],
        orElse: () => GameType.quiz,
      ),
      currentIndex: json['currentIndex'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      stateData: Map<String, dynamic>.from(
        json['stateData'] as Map? ?? {},
      ),
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'gameType': gameType.name,
        'currentIndex': currentIndex,
        'score': score,
        'stateData': stateData,
        'savedAt': savedAt.toIso8601String(),
      };
}

/// Persists in-progress game state locally (SharedPreferences).
class GameProgressService {
  GameProgressService._();

  static const _prefix = 'skulmate_game_progress_';

  static Future<void> saveProgress(GameProgress progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefix${progress.gameId}',
        jsonEncode(progress.toJson()),
      );
    } catch (e) {
      LogService.error('🎮 [Progress] save failed: $e');
    }
  }

  static Future<GameProgress?> loadProgress(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$gameId');
      if (raw == null) return null;
      return GameProgress.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      LogService.error('🎮 [Progress] load failed: $e');
      return null;
    }
  }

  static Future<void> clearProgress(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$gameId');
      await prefs.remove('skulmate_next_stop_continue_fp_$gameId');
    } catch (e) {
      LogService.error('🎮 [Progress] clear failed: $e');
    }
  }

  static Future<Set<String>> gameIdsWithProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs
          .getKeys()
          .where((k) => k.startsWith(_prefix))
          .map((k) => k.substring(_prefix.length))
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// True when the learner left mid-game — not at start or already finished.
  static bool isResumable(GameProgress progress, int totalItems) {
    if (totalItems <= 0) return false;
    if (progress.stateData['completed'] == true) return false;
    if (progress.currentIndex <= 0) return false;
    if (progress.currentIndex >= totalItems) return false;
    return true;
  }

  static int progressPercent(GameProgress progress, int totalItems) {
    if (totalItems <= 0) return 0;
    return ((progress.currentIndex / totalItems) * 100).round().clamp(0, 99);
  }

  static Future<bool> hasResumableProgress(
    String gameId,
    int totalItems,
  ) async {
    final progress = await loadProgress(gameId);
    if (progress == null) return false;
    return isResumable(progress, totalItems);
  }

  static String progressFingerprint(GameProgress progress) =>
      progress.savedAt.toIso8601String();
}
