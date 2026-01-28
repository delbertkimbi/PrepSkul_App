import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import '../models/game_model.dart';

// Conditional import for web-specific HTTP client
// On web (dart.library.html available): use http_client_web.dart with dart:html
// On mobile (dart.library.html not available): use http_client_stub.dart
import 'http_client_stub.dart' if (dart.library.html) 'http_client_web.dart';

/// Service for interacting with skulMate API and database
class SkulMateService {
  /// Get API base URL with smart fallback
  /// Get API base URL (with localhost detection for local development)
  /// Uses AppConfig.effectiveApiBaseUrl which automatically detects local development
  static String get _apiBaseUrl {
    return AppConfig.effectiveApiBaseUrl;
  }

  /// Production API base URL (fallback)
  /// Uses AppConfig for consistency with environment variables
  static String get _productionApiBaseUrl {
    return AppConfig.apiBaseUrl;
  }

  // Endpoint is relative to apiBaseUrl (which already includes /api)
  static const String _generateEndpoint = '/skulmate/generate';

  /// Make HTTP POST request (web-aware)
  /// On web, uses dart:html for proper CORS handling with credentials
  /// On other platforms, uses standard http package
  static Future<http.Response> _makePostRequest(
    String url,
    Map<String, String> headers,
    String body,
  ) async {
    if (kIsWeb) {
      // Use web-specific request for proper CORS handling
      // This uses dart:html HttpRequest with withCredentials: true
      return await postWeb(url, headers, body);
    } else {
      // Use standard http package for mobile
      return await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
    }
  }

  /// Generate game from file URL or text
  /// Uses HTTP API endpoint (Next.js API route)
  static Future<GameModel> generateGame({
    String? fileUrl,
    String? imageUrl,
    String? text,
    String? childId,
    String gameType = 'auto',
    String? difficulty,
    String? topic,
    int? numQuestions,
  }) async {
    // Use HTTP endpoint directly (Supabase function doesn't exist)
    return await generateGameHttp(
      fileUrl: fileUrl,
      imageUrl: imageUrl,
      text: text,
      childId: childId,
      gameType: gameType,
      difficulty: difficulty,
      topic: topic,
      numQuestions: numQuestions,
    );
  }

  /// Generate game using HTTP directly (primary method)
  static Future<GameModel> generateGameHttp({
    String? fileUrl,
    String? imageUrl,
    String? text,
    String? childId,
    String gameType = 'auto',
    String? difficulty,
    String? topic,
    int? numQuestions,
  }) async {
    try {
      LogService.info('🎮 [skulMate] Generating game via HTTP...');

      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // API expects fileUrl or text, so send imageUrl as fileUrl if no fileUrl provided
      final requestBody = {
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (imageUrl != null && fileUrl == null) 'fileUrl': imageUrl, // Send imageUrl as fileUrl
        if (text != null) 'text': text,
        'userId': userId,
        if (childId != null) 'childId': childId,
        'gameType': gameType,
        if (difficulty != null) 'difficulty': difficulty,
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        if (numQuestions != null) 'numQuestions': numQuestions,
      };

      final session = SupabaseService.client.auth.currentSession;
      final token = session?.accessToken;

      // Use production API URL directly (no localhost fallback in production)
      final url = '$_apiBaseUrl$_generateEndpoint';
      
      LogService.info('🎮 [skulMate] Calling API: $url');
      LogService.debug('🎮 [skulMate] Request body: ${jsonEncode(requestBody)}');
      
      // Make the API request
      final httpResponse = await _makePostRequest(
        url,
        {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 120), // 2 minutes for production (image processing can be slow)
        onTimeout: () {
          throw Exception('Request timeout - The request took too long to complete.\n\nPlease check your internet connection and try again. If this continues, contact support.');
        },
      );

        if (httpResponse.statusCode != 200) {
          String errorMessage = 'Unknown error';
          String errorDetails = '';
          
          // Check if response is HTML (error page) instead of JSON
          final responseBody = httpResponse.body.trim();
          final isHtmlResponse = responseBody.startsWith('<!DOCTYPE') || 
                                 responseBody.startsWith('<html') ||
                                 responseBody.startsWith('<!');
          
          LogService.error('🎮 [skulMate] API returned error status: ${httpResponse.statusCode}');
          LogService.error('🎮 [skulMate] Response body: ${responseBody.length > 500 ? responseBody.substring(0, 500) + '...' : responseBody}');
          
          if (isHtmlResponse) {
            LogService.error('🎮 [skulMate] API returned HTML instead of JSON (likely 404 or error page)');
            
            if (httpResponse.statusCode == 404) {
              errorMessage = 'API endpoint not found';
              errorDetails = 'The game generation service may not be available. Please check your connection and try again.';
            } else if (httpResponse.statusCode >= 500) {
              errorMessage = 'Server error';
              errorDetails = 'Our servers are experiencing issues. Please try again in a few moments.';
            } else {
              errorMessage = 'Service unavailable';
              errorDetails = 'The game generation service is temporarily unavailable. Please try again later.';
            }
          } else {
            // Try to parse as JSON
            try {
              final jsonBody = jsonDecode(responseBody) as Map<String, dynamic>?;
              errorMessage = jsonBody?['error'] as String? ?? 
                jsonBody?['message'] as String? ??
                'Unknown error';
              errorDetails = jsonBody?['details'] as String? ?? jsonBody?['message'] as String? ?? '';
              
              // Log the actual API error for debugging
              LogService.error('🎮 [skulMate] API error message: $errorMessage');
              if (errorDetails.isNotEmpty) {
                LogService.error('🎮 [skulMate] API error details: $errorDetails');
              }
            } catch (e) {
              LogService.error('🎮 [skulMate] Failed to parse error response: $e');
              errorMessage = 'Invalid response from server';
              errorDetails = 'The server returned an unexpected response. Status: ${httpResponse.statusCode}';
            }
          }
          
          // Provide user-friendly error message
          if (httpResponse.statusCode == 400) {
            // Bad request - likely missing or invalid parameters
            throw Exception('Invalid request: $errorMessage${errorDetails.isNotEmpty ? '\n\n$errorDetails' : '\n\nPlease check that you have selected a file or entered text.'}');
          } else if (httpResponse.statusCode == 401 || httpResponse.statusCode == 403) {
            throw Exception('Authentication error: Please log in and try again.');
          } else if (httpResponse.statusCode >= 500) {
            throw Exception('Server error: Our servers are experiencing issues. Please try again in a few moments.');
          } else {
            throw Exception('$errorMessage${errorDetails.isNotEmpty ? '\n\n$errorDetails' : ''}');
          }
        }

        // Check if response is HTML before parsing as JSON
        final responseBody = httpResponse.body.trim();
        final contentType = httpResponse.headers['content-type'] ?? '';
        
        // Check content-type header first
        if (!contentType.contains('application/json') && 
            (contentType.contains('text/html') || contentType.contains('text/plain'))) {
          LogService.error('🎮 [skulMate] API returned non-JSON content-type: $contentType');
          LogService.error('🎮 [skulMate] Response preview: ${responseBody.length > 500 ? responseBody.substring(0, 500) : responseBody}');
          throw Exception('Invalid response format.\n\nThe server returned an unexpected response format. Please try again or contact support.');
        }
        
        // Also check response body for HTML
        if (responseBody.startsWith('<!DOCTYPE') || 
            responseBody.startsWith('<html') ||
            responseBody.startsWith('<!')) {
          LogService.error('🎮 [skulMate] API returned HTML instead of JSON despite 200 status');
          LogService.error('🎮 [skulMate] Content-Type: $contentType');
          LogService.error('🎮 [skulMate] Response preview: ${responseBody.length > 500 ? responseBody.substring(0, 500) : responseBody}');
          throw Exception('Invalid response format.\n\nThe server returned an HTML page instead of game data. This usually means the API endpoint is not available. Please try again later or contact support.');
        }

        // Try to parse as JSON
        Map<String, dynamic> data;
        try {
          data = jsonDecode(responseBody) as Map<String, dynamic>;
        } catch (e) {
          LogService.error('🎮 [skulMate] Failed to parse JSON response: $e');
          LogService.error('🎮 [skulMate] Response preview: ${responseBody.length > 500 ? responseBody.substring(0, 500) : responseBody}');
          throw Exception('Invalid response format.\n\nThe server returned data in an unexpected format. Please try again or contact support.');
        }
        final gameData = data['game'] as Map<String, dynamic>? ?? data;

        // Extract game ID - log if missing
        final gameId = gameData['id'] as String?;
        if (gameId == null || gameId.isEmpty) {
          LogService.warning('🎮 [skulMate] Game generated but no ID returned from API - game may not be saved to database');
          LogService.debug('🎮 [skulMate] API response: ${jsonEncode(data)}');
        } else {
          LogService.debug('🎮 [skulMate] Game ID from API: $gameId');
        }

        // Convert API response to GameModel
        final game = GameModel(
          id: gameId ?? '',
          userId: userId,
          childId: childId,
          title: gameData['title'] as String,
          gameType: GameType.fromString(gameData['gameType'] as String),
          documentUrl: fileUrl ?? imageUrl,
          sourceType: fileUrl != null
              ? (fileUrl.endsWith('.pdf') ? 'pdf' : 'image')
              : (imageUrl != null ? 'image' : 'text'),
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

        LogService.success('🎮 [skulMate] Game generated: ${game.title}${gameId != null && gameId.isNotEmpty ? " (ID: $gameId)" : " (No ID - not saved to DB)"}');
        return game;
      } catch (e) {
        // Log the full error for debugging
        LogService.error('🎮 [skulMate] Full error details: ${e.toString()}');
        LogService.error('🎮 [skulMate] Error type: ${e.runtimeType}');
        if (e is Exception) {
          LogService.error('🎮 [skulMate] Exception message: ${e.toString()}');
        }
        
        // Provide helpful error message based on error type
        String errorMessage = e.toString();
        final errorStr = errorMessage.toLowerCase();
        
        // Classify error for user-friendly message
        if (errorStr.contains('[cors]') || errorStr.contains('cors blocked')) {
          errorMessage = 
            'Unable to connect to the game generation service.\n\n'
            'This may be a browser security restriction. Please try:\n'
            '• Refreshing the page\n'
            '• Checking if the API server is running\n'
            '• Contacting support if the problem persists';
        } else if (errorStr.contains('[network]') || 
                   errorStr.contains('failed to fetch') ||
                   errorStr.contains('connection refused') ||
                   errorStr.contains('network is unreachable')) {
          errorMessage = 
            'Unable to generate game at this time.\n\n'
            'Please check your internet connection and try again. '
            'If the problem persists, please contact support.';
        } else if (errorStr.contains('timeout') ||
                   errorStr.contains('request timeout') ||
                   errorStr.contains('connection timeout') ||
                   errorStr.contains('connect timeout') ||
                   errorStr.contains('took too long') ||
                   errorStr.contains('timeout after')) {
          errorMessage = 
            'The request took too long to complete.\n\n'
            'This can happen with large files or slow connections. '
            'Please check your internet connection and try again. '
            'If this continues, try a smaller file or contact support.';
        } else if (errorStr.contains('[server]') || 
                   errorStr.contains('http 5') ||
                   errorStr.contains('internal server error')) {
          errorMessage = 
            'The game generation service is temporarily unavailable.\n\n'
            'Please try again in a few moments. '
            'If this continues, contact support.';
        } else if (errorStr.contains('[client]') || 
                   errorStr.contains('http 4') ||
                   errorStr.contains('bad request') ||
                   errorStr.contains('unauthorized')) {
          errorMessage = 
            'There was an issue with your request.\n\n'
            'Please check your input and try again. '
            'If this continues, contact support.';
        } else if (errorStr.contains('invalid fileurl format') ||
                   errorStr.contains('failed to download file') ||
                   errorStr.contains('connection timeout')) {
          errorMessage = 
            'There was an issue processing your file.\n\n'
            'The file may be too large, corrupted, or the connection timed out. '
            'Please try uploading a smaller file or contact support if the problem continues.';
        } else if (errorStr.contains('failed to generate game')) {
          // Extract the actual error from the API response
          final apiError = errorMessage.replaceAll('Exception: Failed to generate game: ', '');
          // Hide technical details
          if (apiError.contains('localhost') || apiError.contains('cors') || apiError.contains('next.js')) {
            errorMessage = 
              'We couldn\'t create your game right now.\n\n'
              'Please try again or contact support if this continues.';
          } else {
            errorMessage = 
              'We couldn\'t create your game right now.\n\n'
              '${apiError.isNotEmpty && apiError.length < 100 ? apiError : "Please try again or contact support if this continues."}';
          }
        } else {
          // Generic fallback
          errorMessage = 
            'Unable to generate game at this time.\n\n'
            'Please check your internet connection and try again. '
            'If the problem persists, please contact support.';
        }
        throw Exception(errorMessage);
      }
  }

  /// Fetch games for current user with pagination
  /// 
  /// [childId] - Optional child ID to filter games
  /// [limit] - Number of games to fetch (default: 20)
  /// [offset] - Number of games to skip (default: 0)
  /// 
  /// Returns a map with 'games' list and 'hasMore' boolean
  static Future<Map<String, dynamic>> getGamesPaginated({
    String? childId,
    int limit = 20,
    int offset = 0,
  }) async {
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

      // Apply ordering, limit, and offset
      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

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

      // Check if there are more games
      final hasMore = response.length == limit;

      return {
        'games': games,
        'hasMore': hasMore,
      };
    } catch (e) {
      LogService.error('🎮 [skulMate] Error fetching games: $e');
      rethrow;
    }
  }

  /// Fetch all games for current user (backward compatibility)
  /// 
  /// Note: For better performance with large lists, use getGamesPaginated() instead
  static Future<List<GameModel>> getGames({String? childId}) async {
    try {
      final result = await getGamesPaginated(childId: childId, limit: 1000);
      return result['games'] as List<GameModel>;
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
      // Skip saving if game ID is empty (game not saved to database yet)
      if (gameId.isEmpty) {
        LogService.debug('🎮 [skulMate] Skipping session save - game ID is empty (game not saved to DB yet)');
        return;
      }

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

  /// Get game statistics (best score, times played, last played)
  static Future<Map<String, dynamic>> getGameStats(String gameId) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final sessions = await SupabaseService.client
          .from('skulmate_game_sessions')
          .select()
          .eq('game_id', gameId)
          .eq('user_id', userId)
          .order('completed_at', ascending: false);

      if (sessions.isEmpty) {
        return {
          'timesPlayed': 0,
          'bestScore': 0,
          'bestScorePercentage': 0.0,
          'lastPlayed': null,
          'averageScore': 0.0,
        };
      }

      final scores = sessions
          .map((s) => (s['score'] as int? ?? 0))
          .where((s) => s > 0)
          .toList();
      final totalQuestions = sessions.first['total_questions'] as int? ?? 0;

      final bestScore = scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : 0;
      final bestScorePercentage = totalQuestions > 0
          ? (bestScore / totalQuestions * 100)
          : 0.0;
      final averageScore = scores.isNotEmpty
          ? scores.reduce((a, b) => a + b) / scores.length
          : 0.0;
      final lastPlayed = sessions.first['completed_at'] != null
          ? DateTime.parse(sessions.first['completed_at'] as String)
          : null;

      return {
        'timesPlayed': sessions.length,
        'bestScore': bestScore,
        'bestScorePercentage': bestScorePercentage,
        'lastPlayed': lastPlayed,
        'averageScore': averageScore,
      };
    } catch (e) {
      LogService.error('🎮 [skulMate] Error fetching game stats: $e');
      return {
        'timesPlayed': 0,
        'bestScore': 0,
        'bestScorePercentage': 0.0,
        'lastPlayed': null,
        'averageScore': 0.0,
      };
    }
  }

  /// Toggle favorite status for a game (using SharedPreferences for now)
  static Future<bool> toggleFavorite(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesKey = 'skulmate_favorites';
      final favorites = prefs.getStringList(favoritesKey) ?? [];
      
      if (favorites.contains(gameId)) {
        favorites.remove(gameId);
      } else {
        favorites.add(gameId);
      }
      
      await prefs.setStringList(favoritesKey, favorites);
      return favorites.contains(gameId);
    } catch (e) {
      LogService.error('🎮 [skulMate] Error toggling favorite: $e');
      return false;
    }
  }

  /// Check if a game is favorited
  static Future<bool> isFavorite(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesKey = 'skulmate_favorites';
      final favorites = prefs.getStringList(favoritesKey) ?? [];
      return favorites.contains(gameId);
    } catch (e) {
      return false;
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


