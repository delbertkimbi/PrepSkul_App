import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../models/game_model.dart';

/// Service for local storage of games (for offline play)
class GameStorageService {
  static const String _gamesKeyPrefix = 'skulmate_games_';
  static const String _sessionsKeyPrefix = 'skulmate_sessions_';

  /// Save game locally
  static Future<void> saveGameLocally(GameModel game) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_gamesKeyPrefix${game.id}';
      await prefs.setString(key, jsonEncode(game.toJson()));
      LogService.debug('🎮 [skulMate] Game saved locally: ${game.id}');
    } catch (e) {
      LogService.error('🎮 [skulMate] Error saving game locally: $e');
    }
  }

  /// Get game from local storage
  static Future<GameModel?> getGameLocally(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_gamesKeyPrefix$gameId';
      final gameJson = prefs.getString(key);
      if (gameJson != null) {
        final gameData = jsonDecode(gameJson) as Map<String, dynamic>;
        return GameModel.fromJson(gameData);
      }
      return null;
    } catch (e) {
      LogService.error('🎮 [skulMate] Error getting game locally: $e');
      return null;
    }
  }

  /// Get all locally saved games
  static Future<List<GameModel>> getAllLocalGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_gamesKeyPrefix));
      final games = <GameModel>[];

      for (final key in keys) {
        final gameJson = prefs.getString(key);
        if (gameJson != null) {
          try {
            final gameData = jsonDecode(gameJson) as Map<String, dynamic>;
            games.add(GameModel.fromJson(gameData));
          } catch (e) {
            LogService.warning('🎮 [skulMate] Error parsing game: $e');
          }
        }
      }

      return games;
    } catch (e) {
      LogService.error('🎮 [skulMate] Error getting all local games: $e');
      return [];
    }
  }

  /// Delete game from local storage
  static Future<void> deleteGameLocally(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_gamesKeyPrefix$gameId';
      await prefs.remove(key);
      LogService.debug('🎮 [skulMate] Game deleted locally: $gameId');
    } catch (e) {
      LogService.error('🎮 [skulMate] Error deleting game locally: $e');
    }
  }

  /// Save game session locally
  static Future<void> saveSessionLocally(GameSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_sessionsKeyPrefix${session.id}';
      await prefs.setString(key, jsonEncode(session.toJson()));
      LogService.debug('🎮 [skulMate] Session saved locally: ${session.id}');
    } catch (e) {
      LogService.error('🎮 [skulMate] Error saving session locally: $e');
    }
  }

  /// Get game sessions from local storage
  static Future<List<GameSession>> getLocalSessions(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_sessionsKeyPrefix));
      final sessions = <GameSession>[];

      for (final key in keys) {
        final sessionJson = prefs.getString(key);
        if (sessionJson != null) {
          try {
            final sessionData = jsonDecode(sessionJson) as Map<String, dynamic>;
            final session = GameSession.fromJson(sessionData);
            if (session.gameId == gameId) {
              sessions.add(session);
            }
          } catch (e) {
            LogService.warning('🎮 [skulMate] Error parsing session: $e');
          }
        }
      }

      return sessions;
    } catch (e) {
      LogService.error('🎮 [skulMate] Error getting local sessions: $e');
      return [];
    }
  }
}



