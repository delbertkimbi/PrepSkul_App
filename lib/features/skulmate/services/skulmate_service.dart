import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import '../models/game_model.dart';

/// Service for interacting with skulMate API and database
class SkulMateService {
  static String get _apiBaseUrl {
    // Use app base URL for API calls (Next.js app)
    // For local development, use localhost if available
    if (kDebugMode) {
      // Try localhost first for development
      return 'http://localhost:3000';
    }
    return AppConfig.appBaseUrl;
  }
  static const String _generateEndpoint = '/api/skulmate/generate';

  /// Generate game from file URL or text
  static Future<GameModel> generateGame({
    String? fileUrl,
    String? text,
    String? childId,
    String gameType = 'auto',
  }) async {
    try {
      LogService.info('🎮 [skulMate] Generating game...');

      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final requestBody = {
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (text != null) 'text': text,
        'userId': userId,
        if (childId != null) 'childId': childId,
        'gameType': gameType,
      };

      LogService.debug('🎮 [skulMate] Request: ${jsonEncode(requestBody)}');

      final response = await SupabaseService.client.functions.invoke(
        'skulmate-generate',
        body: requestBody,
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Unknown error';
        throw Exception('Failed to generate game: $error');
      }

      final data = response.data as Map<String, dynamic>;
      final gameData = data['game'] as Map<String, dynamic>;

      // Convert API response to GameModel
      final game = GameModel(
        id: gameData['id'] as String? ?? '',
        userId: userId,
        childId: childId,
        title: gameData['title'] as String,
        gameType: GameType.fromString(gameData['gameType'] as String),
        documentUrl: fileUrl,
        sourceType: fileUrl != null
            ? (fileUrl.endsWith('.pdf') ? 'pdf' : 'image')
            : 'text',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: (gameData['items'] as List<dynamic>?)
                ?.map((item) =>
                    GameItem.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [],
        metadata: GameMetadata.fromJson(
          gameData['metadata'] as Map<String, dynamic>? ?? {},
        ),
      );

      LogService.success('🎮 [skulMate] Game generated: ${game.title}');
      return game;
    } catch (e) {
      LogService.error('🎮 [skulMate] Error generating game: $e');
      rethrow;
    }
  }

  /// Generate game using HTTP directly (fallback if Supabase Functions not available)
  static Future<GameModel> generateGameHttp({
    String? fileUrl,
    String? text,
    String? childId,
    String gameType = 'auto',
  }) async {
    try {
      LogService.info('🎮 [skulMate] Generating game via HTTP...');

      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final requestBody = {
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (text != null) 'text': text,
        'userId': userId,
        if (childId != null) 'childId': childId,
        'gameType': gameType,
      };

      final session = SupabaseService.client.auth.currentSession;
      final token = session?.accessToken;

      // Use HTTP client directly
      final url = '$_apiBaseUrl$_generateEndpoint';
      LogService.debug('🎮 [skulMate] Calling API: $url');
      
      try {
        final httpResponse = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(requestBody),
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw Exception('Request timeout - API server may not be running');
          },
        );

        if (httpResponse.statusCode != 200) {
          final responseBody = jsonDecode(httpResponse.body) as Map<String, dynamic>?;
          final error = responseBody?['error'] ?? 'Unknown error';
          throw Exception('Failed to generate game: $error');
        }

        final data = jsonDecode(httpResponse.body) as Map<String, dynamic>;
        final gameData = data['game'] as Map<String, dynamic>? ?? data;

        // Convert API response to GameModel
        final game = GameModel(
          id: gameData['id'] as String? ?? '',
          userId: userId,
          childId: childId,
          title: gameData['title'] as String,
          gameType: GameType.fromString(gameData['gameType'] as String),
          documentUrl: fileUrl,
          sourceType: fileUrl != null
              ? (fileUrl.endsWith('.pdf') ? 'pdf' : 'image')
              : 'text',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          items: (gameData['items'] as List<dynamic>?)
                  ?.map((item) =>
                      GameItem.fromJson(item as Map<String, dynamic>))
                  .toList() ??
              [],
          metadata: GameMetadata.fromJson(
            gameData['metadata'] as Map<String, dynamic>? ?? {},
          ),
        );

        LogService.success('🎮 [skulMate] Game generated: ${game.title}');
        return game;
      } catch (e) {
        // Provide helpful error message
        String errorMessage = e.toString();
        if (errorMessage.contains('Failed to fetch') || 
            errorMessage.contains('Connection refused') ||
            errorMessage.contains('Network is unreachable')) {
          errorMessage = 
            'Cannot connect to API server.\n\n'
            'Please ensure:\n'
            '1. Next.js server is running (cd PrepSkul_Web && npm run dev)\n'
            '2. Server is accessible at $_apiBaseUrl\n'
            '3. CORS is properly configured\n\n'
            'For local development, the server should run on http://localhost:3000';
        } else if (errorMessage.contains('timeout')) {
          errorMessage = 
            'Request timed out. The API server may be slow or not responding.\n\n'
            'Please check:\n'
            '1. API server is running\n'
            '2. Network connection is stable\n'
            '3. Try again in a moment';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      LogService.error('🎮 [skulMate] Error generating game: $e');
      rethrow;
    }
  }

  /// Fetch all games for current user
  static Future<List<GameModel>> getGames({String? childId}) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      var query = SupabaseService.client
          .from('skulmate_games')
          .select('''
            *,
            skulmate_game_data (
              game_content,
              metadata
            )
          ''')
          .eq('user_id', userId)
          .eq('is_deleted', false);

      if (childId != null) {
        query = query.eq('child_id', childId);
      }

      // Apply ordering and execute - chain order() directly
      final response = await query.order('created_at', ascending: false);

      final games = <GameModel>[];
      for (final gameData in response) {
        final gameContent = gameData['skulmate_game_data'] as List<dynamic>?;
        final List<GameItem> items = gameContent?.isNotEmpty == true
            ? ((gameContent![0]['game_content'] as List<dynamic>?)
                    ?.map((item) =>
                        GameItem.fromJson(item as Map<String, dynamic>))
                    .toList() ??
                <GameItem>[])
            : <GameItem>[];

        final metadata = gameContent?.isNotEmpty == true
            ? GameMetadata.fromJson(
                gameContent![0]['metadata'] as Map<String, dynamic>? ?? {},
              )
            : GameMetadata(
                source: 'document',
                generatedAt: DateTime.now().toIso8601String(),
                difficulty: 'medium',
                totalItems: 0,
              );

        games.add(GameModel(
          id: gameData['id'] as String,
          userId: gameData['user_id'] as String,
          childId: gameData['child_id'] as String?,
          title: gameData['title'] as String,
          gameType: GameType.fromString(gameData['game_type'] as String),
          documentUrl: gameData['document_url'] as String?,
          sourceType: gameData['source_type'] as String?,
          createdAt: DateTime.parse(gameData['created_at'] as String),
          updatedAt: DateTime.parse(gameData['updated_at'] as String),
          isDeleted: gameData['is_deleted'] as bool? ?? false,
          items: items,
          metadata: metadata,
        ));
      }

      return games;
    } catch (e) {
      LogService.error('🎮 [skulMate] Error fetching games: $e');
      rethrow;
    }
  }

  /// Save game session result
  static Future<void> saveGameSession({
    required String gameId,
    required int score,
    required int totalQuestions,
    required int correctAnswers,
    int? timeTakenSeconds,
    Map<String, dynamic>? answers,
  }) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await SupabaseService.client.from('skulmate_game_sessions').insert({
        'game_id': gameId,
        'user_id': userId,
        'score': score,
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
        'time_taken_seconds': timeTakenSeconds,
        'answers': answers,
        'completed_at': DateTime.now().toIso8601String(),
      });

      LogService.success('🎮 [skulMate] Game session saved');
    } catch (e) {
      LogService.error('🎮 [skulMate] Error saving game session: $e');
      rethrow;
    }
  }

  /// Delete game (soft delete)
  static Future<void> deleteGame(String gameId) async {
    try {
      await SupabaseService.client
          .from('skulmate_games')
          .update({'is_deleted': true})
          .eq('id', gameId);

      LogService.success('🎮 [skulMate] Game deleted');
    } catch (e) {
      LogService.error('🎮 [skulMate] Error deleting game: $e');
      rethrow;
    }
  }
}

