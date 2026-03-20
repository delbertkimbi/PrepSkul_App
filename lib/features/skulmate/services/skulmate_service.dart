import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/localization/language_service.dart';
import '../models/game_model.dart';

// Conditional import for web-specific HTTP client
// On web (dart.library.html available): use http_client_web.dart with dart:html
// On mobile (dart.library.html not available): use http_client_stub.dart
import 'http_client_stub.dart' if (dart.library.html) 'http_client_web.dart';

/// Result from explain flashcard API
class ExplainResult {
  final String explanation;
  final List<ExplainVideo> videos;

  ExplainResult({required this.explanation, required this.videos});
}

/// Video recommendation from explain API
class ExplainVideo {
  final String videoId;
  final String title;
  final String thumbnailUrl;

  ExplainVideo({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
  });

  factory ExplainVideo.fromJson(Map<String, dynamic> json) {
    return ExplainVideo(
      videoId: json['videoId'] as String? ?? '',
      title: json['title'] as String? ?? 'Video',
      thumbnailUrl:
          json['thumbnailUrl'] as String? ??
          'https://img.youtube.com/vi/${json['videoId'] ?? 'dQw4w9WgXcQ'}/hqdefault.jpg',
    );
  }
}

/// Service for interacting with skulMate API and database
class SkulMateService {
  static const String _gamesCachePrefix = 'skulmate_games_cache_v1_';
  static const String _gamesCacheUpdatedPrefix =
      'skulmate_games_cache_updated_v1_';

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
  static const String _challengeFromSessionEndpoint =
      '/skulmate/challenge/from-session';
  static const String _explainEndpoint = '/skulmate/explain';
  static const String _pricingUsageEndpoint = '/skulmate/pricing-usage';

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
      return await http.post(Uri.parse(url), headers: headers, body: body);
    }
  }

  static Future<Map<String, dynamic>> fetchPricingUsage() async {
    final session = SupabaseService.client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final url = '$_apiBaseUrl$_pricingUsageEndpoint';
    final httpResponse = await _makePostRequest(
      url,
      {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      jsonEncode({}),
    ).timeout(const Duration(seconds: 20), onTimeout: () {
      throw Exception('Request timeout. Please try again.');
    });

    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
      final decoded = jsonDecode(httpResponse.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    }

    try {
      final decoded = jsonDecode(httpResponse.body);
      final msg = (decoded is Map && decoded['error'] is String)
          ? decoded['error'] as String
          : 'Failed to load pricing';
      throw Exception(msg);
    } catch (_) {
      throw Exception('Failed to load pricing');
    }
  }

  /// Generate revision challenge from session (session_summary + transcript)
  /// For normal recurring sessions only. Returns quiz game.
  static Future<GameModel> generateChallengeFromSession(
    String sessionId,
  ) async {
    try {
      LogService.info(
        '🎮 [skulMate] Generating challenge from session: $sessionId',
      );

      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final requestBody = {
        'sessionId': sessionId,
        'language': LanguageService.languageCode,
      };
      final session = SupabaseService.client.auth.currentSession;
      final token = session?.accessToken;

      final url = '$_apiBaseUrl$_challengeFromSessionEndpoint';
      final httpResponse =
          await _makePostRequest(url, {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          }, jsonEncode(requestBody)).timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception('Request timeout. Please try again.');
            },
          );

      if (httpResponse.statusCode != 200) {
        final responseBody = httpResponse.body.trim();
        final jsonBody = jsonDecode(responseBody) as Map<String, dynamic>?;
        final errorMsg =
            jsonBody?['error'] as String? ?? 'Failed to generate challenge';
        throw Exception(errorMsg);
      }

      final data = jsonDecode(httpResponse.body) as Map<String, dynamic>;
      final gameData = data['game'] as Map<String, dynamic>? ?? data;

      final gameId = gameData['id'] as String? ?? '';
      final items =
          (gameData['items'] as List<dynamic>?)
              ?.map((item) => GameItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];

      final game = GameModel(
        id: gameId,
        userId: userId,
        childId: null,
        title: gameData['title'] as String? ?? 'Session Challenge',
        gameType: GameType.quiz,
        documentUrl: null,
        sourceType: 'session',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: items,
        metadata: GameMetadata.fromJson(
          gameData['metadata'] as Map<String, dynamic>? ?? {},
        ),
      );

      LogService.success('🎮 [skulMate] Challenge generated: ${game.title}');
      return game;
    } catch (e) {
      LogService.error(
        '🎮 [skulMate] Error generating challenge from session: $e',
      );
      rethrow;
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
    Map<String, dynamic>? learnerContext,
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
      learnerContext: learnerContext,
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
    Map<String, dynamic>? learnerContext,
  }) async {
    bool _isOcrExtractionError(String value) {
      final s = value.toLowerCase();
      return s.contains('failed to extract text') ||
          s.contains('failed to extract meaningful text') ||
          s.contains('couldn\'t read text') ||
          s.contains('could not read text') ||
          s.contains('cannot read properties of undefined') ||
          s.contains('reading \'0\'') ||
          s.contains('reading "0"') ||
          s.contains('ocr') ||
          s.contains('tesseract') ||
          s.contains('openrouter api error');
    }

    try {
      LogService.info('🎮 [skulMate] Generating game via HTTP...');

      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // API expects fileUrl or text, so send imageUrl as fileUrl if no fileUrl provided
      final requestBody = {
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (imageUrl != null && fileUrl == null)
          'fileUrl': imageUrl, // Send imageUrl as fileUrl
        if (text != null) 'text': text,
        'userId': userId,
        'language': LanguageService.languageCode,
        if (childId != null) 'childId': childId,
        'gameType': gameType,
        if (difficulty != null) 'difficulty': difficulty,
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        if (numQuestions != null) 'numQuestions': numQuestions,
        if (learnerContext != null && learnerContext.isNotEmpty)
          'learnerContext': learnerContext,
      };

      final session = SupabaseService.client.auth.currentSession;
      final token = session?.accessToken;

      // Use production API URL directly (no localhost fallback in production)
      final url = '$_apiBaseUrl$_generateEndpoint';

      LogService.info('🎮 [skulMate] Calling API: $url');
      LogService.debug(
        '🎮 [skulMate] Request body: ${jsonEncode(requestBody)}',
      );

      // Make the API request
      final httpResponse =
          await _makePostRequest(url, {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          }, jsonEncode(requestBody)).timeout(
            const Duration(
              seconds: 120,
            ), // 2 minutes for production (image processing can be slow)
            onTimeout: () {
              throw Exception(
                'Request timeout - The request took too long to complete.\n\nPlease check your internet connection and try again. If this continues, contact support.',
              );
            },
          );

      if (httpResponse.statusCode != 200) {
        String errorMessage = 'Unknown error';
        String errorDetails = '';

        // Check if response is HTML (error page) instead of JSON
        final responseBody = httpResponse.body.trim();
        final isHtmlResponse =
            responseBody.startsWith('<!DOCTYPE') ||
            responseBody.startsWith('<html') ||
            responseBody.startsWith('<!');

        LogService.error(
          '🎮 [skulMate] API returned error status: ${httpResponse.statusCode}',
        );
        LogService.error(
          '🎮 [skulMate] Response body: ${responseBody.length > 500 ? responseBody.substring(0, 500) + '...' : responseBody}',
        );

        if (isHtmlResponse) {
          LogService.error(
            '🎮 [skulMate] API returned HTML instead of JSON (likely 404 or error page)',
          );

          if (httpResponse.statusCode == 404) {
            errorMessage = 'API endpoint not found';
            errorDetails =
                'The game generation service may not be available. Please check your connection and try again.';
          } else if (httpResponse.statusCode >= 500) {
            errorMessage = 'Server error';
            errorDetails =
                'Our servers are experiencing issues. Please try again in a few moments.';
          } else {
            errorMessage = 'Service unavailable';
            errorDetails =
                'The game generation service is temporarily unavailable. Please try again later.';
          }
        } else {
          // Try to parse as JSON
          try {
            final jsonBody = jsonDecode(responseBody) as Map<String, dynamic>?;
            errorMessage =
                jsonBody?['error'] as String? ??
                jsonBody?['message'] as String? ??
                'Unknown error';
            errorDetails =
                jsonBody?['details'] as String? ??
                jsonBody?['message'] as String? ??
                '';

            // Log the actual API error for debugging
            LogService.error('🎮 [skulMate] API error message: $errorMessage');
            if (errorDetails.isNotEmpty) {
              LogService.error(
                '🎮 [skulMate] API error details: $errorDetails',
              );
            }
          } catch (e) {
            LogService.error(
              '🎮 [skulMate] Failed to parse error response: $e',
            );
            errorMessage = 'Invalid response from server';
            errorDetails =
                'The server returned an unexpected response. Status: ${httpResponse.statusCode}';
          }
        }

        // Provide user-friendly error message
        final combinedError =
            '$errorMessage ${errorDetails.isNotEmpty ? errorDetails : ''}'
                .toLowerCase();
        if (httpResponse.statusCode == 400) {
          if (combinedError.contains('provider is temporarily unavailable') ||
              combinedError.contains('temporarily unavailable right now')) {
            throw Exception(
              'Image processing is temporarily unavailable right now.\n\n'
              'Please try again shortly, use "Enter text manually", or upload a DOCX/TXT/PDF file.',
            );
          }
          // Hide technical OCR/parser failures from users.
          if (_isOcrExtractionError(combinedError)) {
            throw Exception(
              'We couldn\'t read text from this file.\n\n'
              'We can still continue: tap "Enter text manually", or upload a clearer image, or a DOCX/TXT/PDF file with readable text. If this keeps happening, contact support.',
            );
          }
          if (combinedError.contains('insufficient_quota') ||
              combinedError.contains('quota') ||
              combinedError.contains('credit')) {
            throw Exception(
              'Game generation service is temporarily limited.\n\n'
              'Please try again shortly. If this continues, contact support so we can check service credits.',
            );
          }
          // Bad request - likely missing or invalid parameters
          throw Exception(
            'Invalid request.\n\n'
            'Please make sure your file is valid and contains readable content. '
            'You can also use "Enter text manually".',
          );
        } else if (httpResponse.statusCode == 401 ||
            httpResponse.statusCode == 403) {
          throw Exception('Authentication error: Please log in and try again.');
        } else if (httpResponse.statusCode == 402) {
          throw Exception(
            errorMessage.isNotEmpty
                ? errorMessage
                : 'Free limit reached for this action. Please choose a SkulMate plan to continue.',
          );
        } else if (httpResponse.statusCode == 503) {
          if (combinedError.contains('image processing provider is temporarily unavailable') ||
              combinedError.contains('temporarily unavailable right now')) {
            throw Exception(
              'Image processing is temporarily unavailable right now.\n\n'
              'Please try again shortly, use "Enter text manually", or upload a DOCX/TXT/PDF file.',
            );
          }
          throw Exception(
            'Server error: Our servers are experiencing issues. Please try again in a few moments.',
          );
        } else if (httpResponse.statusCode >= 500) {
          throw Exception(
            'Server error: Our servers are experiencing issues. Please try again in a few moments.',
          );
        } else {
          throw Exception(
            '$errorMessage${errorDetails.isNotEmpty ? '\n\n$errorDetails' : ''}',
          );
        }
      }

      // Check if response is HTML before parsing as JSON
      final responseBody = httpResponse.body.trim();
      final contentType = httpResponse.headers['content-type'] ?? '';

      // Check content-type header first
      if (!contentType.contains('application/json') &&
          (contentType.contains('text/html') ||
              contentType.contains('text/plain'))) {
        LogService.error(
          '🎮 [skulMate] API returned non-JSON content-type: $contentType',
        );
        LogService.error(
          '🎮 [skulMate] Response preview: ${responseBody.length > 500 ? responseBody.substring(0, 500) : responseBody}',
        );
        throw Exception(
          'Invalid response format.\n\nThe server returned an unexpected response format. Please try again or contact support.',
        );
      }

      // Also check response body for HTML
      if (responseBody.startsWith('<!DOCTYPE') ||
          responseBody.startsWith('<html') ||
          responseBody.startsWith('<!')) {
        LogService.error(
          '🎮 [skulMate] API returned HTML instead of JSON despite 200 status',
        );
        LogService.error('🎮 [skulMate] Content-Type: $contentType');
        LogService.error(
          '🎮 [skulMate] Response preview: ${responseBody.length > 500 ? responseBody.substring(0, 500) : responseBody}',
        );
        throw Exception(
          'Invalid response format.\n\nThe server returned an HTML page instead of game data. This usually means the API endpoint is not available. Please try again later or contact support.',
        );
      }

      // Try to parse as JSON
      Map<String, dynamic> data;
      try {
        data = jsonDecode(responseBody) as Map<String, dynamic>;
      } catch (e) {
        LogService.error('🎮 [skulMate] Failed to parse JSON response: $e');
        LogService.error(
          '🎮 [skulMate] Response preview: ${responseBody.length > 500 ? responseBody.substring(0, 500) : responseBody}',
        );
        throw Exception(
          'Invalid response format.\n\nThe server returned data in an unexpected format. Please try again or contact support.',
        );
      }
      final gameData = data['game'] as Map<String, dynamic>? ?? data;

      // Extract game ID - log if missing
      final gameId = gameData['id'] as String?;
      if (gameId == null || gameId.isEmpty) {
        LogService.warning(
          '🎮 [skulMate] Game generated but no ID returned from API - game may not be saved to database',
        );
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
            ? (fileUrl.endsWith('.pdf')
                  ? 'pdf'
                  : (fileUrl.endsWith('.docx')
                        ? 'docx'
                        : (fileUrl.endsWith('.txt') ? 'text' : 'image')))
            : (imageUrl != null ? 'image' : 'text'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items:
            (gameData['items'] as List<dynamic>?)
                ?.map((item) => GameItem.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [],
        metadata: GameMetadata.fromJson(
          gameData['metadata'] as Map<String, dynamic>? ?? {},
        ),
      );

      LogService.success(
        '🎮 [skulMate] Game generated: ${game.title}${gameId != null && gameId.isNotEmpty ? " (ID: $gameId)" : " (No ID - not saved to DB)"}',
      );
      return game;
    } catch (e) {
      // Log the full error for debugging
      LogService.error('🎮 [skulMate] Full error details: ${e.toString()}');
      LogService.error('🎮 [skulMate] Error type: ${e.runtimeType}');
      if (e is Exception) {
        LogService.error('🎮 [skulMate] Exception message: ${e.toString()}');
      }

      // Preserve API error messages (e.g. "Text must be at least 50 characters long")
      final errorMessage = e.toString();
      final errorStr = errorMessage.toLowerCase();
      if (errorStr.contains('invalid request:') ||
          errorStr.contains('invalid request.') ||
          errorStr.contains('we couldn\'t read text from this file') ||
          errorStr.contains('we could not read text from this file') ||
          errorStr.contains('failed to extract meaningful text') ||
          errorStr.contains('failed to extract text from your file') ||
          errorStr.contains('failed to extract text from image') ||
          errorStr.contains('cannot read properties of undefined') ||
          errorStr.contains('enter text manually') ||
          errorStr.contains('text must be') ||
          errorStr.contains('50 characters') ||
          errorStr.contains('authentication error') ||
          errorStr.contains('insufficient credits') ||
          errorStr.contains('daily free limit reached') ||
          errorStr.contains('free image limit reached') ||
          errorStr.contains('free document/text limit reached') ||
          errorStr.contains('free limit reached') ||
          errorStr.contains('plan to continue') ||
          errorStr.contains('server error:') ||
          errorStr.contains('image processing is temporarily unavailable') ||
          errorStr.contains('temporarily limited') ||
          errorStr.contains('service credits')) {
        rethrow;
      }

      // Provide helpful error message based on error type
      String mappedMessage = errorMessage;
      if (errorStr.contains('[cors]') || errorStr.contains('cors blocked')) {
        mappedMessage =
            'Unable to connect to the game generation service.\n\n'
            'This may be a browser security restriction. Please try:\n'
            '• Refreshing the page\n'
            '• Checking if the API server is running\n'
            '• Contacting support if the problem persists';
      } else if (errorStr.contains('[network]') ||
          errorStr.contains('failed to fetch') ||
          errorStr.contains('connection refused') ||
          errorStr.contains('network is unreachable')) {
        mappedMessage =
            'Unable to generate game at this time.\n\n'
            'Please check your internet connection and try again. '
            'If the problem persists, please contact support.';
      } else if (errorStr.contains('timeout') ||
          errorStr.contains('request timeout') ||
          errorStr.contains('connection timeout') ||
          errorStr.contains('connect timeout') ||
          errorStr.contains('took too long') ||
          errorStr.contains('timeout after')) {
        mappedMessage =
            'The request took too long to complete.\n\n'
            'This can happen with large files or slow connections. '
            'Please check your internet connection and try again. '
            'If this continues, try a smaller file or contact support.';
      } else if (errorStr.contains('[server]') ||
          errorStr.contains('http 5') ||
          errorStr.contains('internal server error')) {
        mappedMessage =
            'The game generation service is temporarily unavailable.\n\n'
            'Please try again in a few moments. '
            'If this continues, contact support.';
      } else if (errorStr.contains('[client]') ||
          errorStr.contains('http 4') ||
          errorStr.contains('bad request') ||
          errorStr.contains('unauthorized')) {
        mappedMessage =
            'There was an issue with your request.\n\n'
            'Please check your input and try again. '
            'If this continues, contact support.';
      } else if (errorStr.contains('invalid fileurl format') ||
          errorStr.contains('failed to download file') ||
          errorStr.contains('connection timeout')) {
        mappedMessage =
            'There was an issue processing your file.\n\n'
            'The file may be too large, corrupted, or the connection timed out. '
            'Please try uploading a smaller file or contact support if the problem continues.';
      } else if (_isOcrExtractionError(errorStr)) {
        mappedMessage =
            'We couldn\'t read text from this file.\n\n'
            'We can still continue: tap "Enter text manually", or upload a clearer image, or a DOCX/TXT/PDF file with readable text. '
            'If this keeps happening, contact support.';
      } else if (errorStr.contains('failed to generate game')) {
        // Extract the actual error from the API response
        final apiError = mappedMessage.replaceAll(
          'Exception: Failed to generate game: ',
          '',
        );
        // Hide technical details
        if (apiError.contains('localhost') ||
            apiError.contains('cors') ||
            apiError.contains('next.js')) {
          mappedMessage =
              'We couldn\'t create your game right now.\n\n'
              'Please try again or contact support if this continues.';
        } else {
          mappedMessage =
              'We couldn\'t create your game right now.\n\n'
              '${apiError.isNotEmpty && apiError.length < 100 ? apiError : "Please try again or contact support if this continues."}';
        }
      } else {
        // Generic fallback
        mappedMessage =
            'Unable to generate game right now.\n\n'
            'Please try again. If this keeps happening, contact support and include what you uploaded.';
      }
      throw Exception(mappedMessage);
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

      dynamic decodeIfJsonString(dynamic value) {
        if (value is! String) return value;
        final trimmed = value.trim();
        if (trimmed.isEmpty) return value;
        if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) return value;
        try {
          return jsonDecode(trimmed);
        } catch (_) {
          return value;
        }
      }

      Map<String, dynamic>? asMap(dynamic value) {
        final decoded = decodeIfJsonString(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return decoded.cast<String, dynamic>();
        return null;
      }

      List<dynamic>? asList(dynamic value) {
        final decoded = decodeIfJsonString(value);
        if (decoded is List<dynamic>) return decoded;
        if (decoded is List) return decoded.cast<dynamic>();
        return null;
      }

      final games = <GameModel>[];
      for (final gameData in response) {
        final relation = gameData['skulmate_game_data'];
        final relationList = asList(relation);
        final relationMap = asMap(relation);
        final firstDataRow =
            relationList != null && relationList.isNotEmpty
            ? asMap(relationList.first)
            : relationMap;

        final rawItems = asList(firstDataRow?['game_content']);
        final items = <GameItem>[];
        if (rawItems != null) {
          for (final item in rawItems) {
            final itemMap = asMap(item);
            if (itemMap != null) {
              items.add(GameItem.fromJson(itemMap));
            }
          }
        }

        final metadataMap = asMap(firstDataRow?['metadata']) ?? const <String, dynamic>{};
        final metadata = GameMetadata.fromJson(metadataMap);

        games.add(
          GameModel(
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
          ),
        );
      }

      // Check if there are more games
      final hasMore = response.length == limit;

      await _mergeGamesIntoCache(
        userId: userId,
        childId: childId,
        offset: offset,
        pageGames: games,
      );

      return {'games': games, 'hasMore': hasMore, 'fromCache': false};
    } catch (e) {
      LogService.error('🎮 [skulMate] Error fetching games: $e');
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        final cached = await _readCachedGames(userId: userId, childId: childId);
        if (cached.isNotEmpty) {
          final start = offset.clamp(0, cached.length);
          final end = (start + limit).clamp(0, cached.length);
          final page = cached.sublist(start, end);
          final hasMore = end < cached.length;
          LogService.info(
            '🎮 [skulMate] Serving ${page.length} cached games (offline fallback)',
          );
          return {'games': page, 'hasMore': hasMore, 'fromCache': true};
        }
      }
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

  /// Result from explainFlashcard API
  static Future<ExplainResult> explainFlashcard({
    required String term,
    required String definition,
  }) async {
    try {
      final session = SupabaseService.client.auth.currentSession;
      final token = session?.accessToken;

      final url = '$_apiBaseUrl$_explainEndpoint';
      final httpResponse =
          await _makePostRequest(
            url,
            {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            jsonEncode({
              'term': term,
              'definition': definition,
              'language': LanguageService.languageCode,
            }),
          ).timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              throw Exception('Request timeout. Please try again.');
            },
          );

      if (httpResponse.statusCode != 200) {
        final responseBody = httpResponse.body.trim();
        String errorMsg = 'Failed to get explanation';
        if (responseBody.isNotEmpty) {
          try {
            final jsonBody = jsonDecode(responseBody) as Map<String, dynamic>?;
            errorMsg = jsonBody?['error'] as String? ?? errorMsg;
          } catch (_) {
            errorMsg = responseBody.length > 80
                ? '${responseBody.substring(0, 80)}...'
                : responseBody;
          }
        }
        throw Exception(errorMsg);
      }

      final responseBody = httpResponse.body.trim();
      if (responseBody.isEmpty) {
        throw Exception('Empty response from server. Please try again.');
      }
      Map<String, dynamic> data;
      try {
        data = jsonDecode(responseBody) as Map<String, dynamic>;
      } on FormatException catch (_) {
        LogService.error(
          '🎮 [skulMate] Explain API returned invalid JSON: ${responseBody.isEmpty ? "(empty)" : responseBody.substring(0, 200)}',
        );
        throw Exception(
          'Could not read explanation (invalid response). Please try again.',
        );
      }
      final explanation = data['explanation'] as String? ?? '';
      final videosRaw = data['videos'] as List<dynamic>? ?? [];
      final videos = videosRaw
          .map((v) => ExplainVideo.fromJson(v as Map<String, dynamic>))
          .toList();

      return ExplainResult(explanation: explanation, videos: videos);
    } catch (e) {
      LogService.error('🎮 [skulMate] Error explaining flashcard: $e');
      final error = e.toString().toLowerCase();
      final isTransientWebFailure =
          error.contains('cors') ||
          error.contains('failed to fetch') ||
          error.contains('network error') ||
          error.contains('status: 0');
      if (isTransientWebFailure) {
        // Keep "Learn more" usable even when explain API is blocked by browser CORS/network.
        return ExplainResult(
          explanation: _buildLocalExplainFallback(
            term: term,
            definition: definition,
          ),
          videos: const [],
        );
      }
      rethrow;
    }
  }

  static String _buildLocalExplainFallback({
    required String term,
    required String definition,
  }) {
    final cleanTerm = term.trim().isEmpty ? 'This concept' : term.trim();
    final cleanDefinition = definition.trim();
    if (cleanDefinition.isEmpty) {
      return '$cleanTerm is an important concept in this lesson. '
          'Review the question context and compare it with related options to understand why this is the correct answer.';
    }
    return '$cleanTerm: $cleanDefinition\n\n'
        'In simple terms, focus on what makes this answer the best fit for the question. '
        'Look for keywords, contrast it with incorrect options, and connect it to the lesson idea.';
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
        LogService.debug(
          '🎮 [skulMate] Skipping session save - game ID is empty (game not saved to DB yet)',
        );
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

      final bestScore = scores.isNotEmpty
          ? scores.reduce((a, b) => a > b ? a : b)
          : 0;
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

  /// Get activity counts by date (for activity calendar)
  /// Returns map of date (normalized to midnight) -> number of sessions that day
  static Future<Map<DateTime, int>> getActivityByDate({String? childId}) async {
    try {
      final userId = childId ?? SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return {};

      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      final sessions = await SupabaseService.client
          .from('skulmate_game_sessions')
          .select('completed_at, created_at')
          .eq('user_id', userId)
          .gte('created_at', oneYearAgo.toIso8601String());

      final activityByDate = <DateTime, int>{};
      for (final s in sessions) {
        final timestamp = s['completed_at'] ?? s['created_at'];
        if (timestamp == null) continue;
        final dt = DateTime.parse(timestamp as String);
        final date = DateTime(dt.year, dt.month, dt.day);
        activityByDate[date] = (activityByDate[date] ?? 0) + 1;
      }
      return activityByDate;
    } catch (e) {
      LogService.error('🎮 [skulMate] Error fetching activity by date: $e');
      return {};
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

  static String _gamesCacheKey(String userId, String? childId) {
    final suffix = childId ?? 'me';
    return '$_gamesCachePrefix${userId}_$suffix';
  }

  static String _gamesCacheUpdatedKey(String userId, String? childId) {
    final suffix = childId ?? 'me';
    return '$_gamesCacheUpdatedPrefix${userId}_$suffix';
  }

  static Future<void> _mergeGamesIntoCache({
    required String userId,
    required String? childId,
    required int offset,
    required List<GameModel> pageGames,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _readCachedGames(userId: userId, childId: childId);
      final merged = List<GameModel>.from(existing);
      if (offset <= 0) {
        merged
          ..clear()
          ..addAll(pageGames);
      } else {
        if (merged.length < offset) {
          // If cache is shorter, append best-effort.
          merged.addAll(pageGames);
        } else {
          for (var i = 0; i < pageGames.length; i++) {
            final idx = offset + i;
            if (idx < merged.length) {
              merged[idx] = pageGames[i];
            } else {
              merged.add(pageGames[i]);
            }
          }
        }
      }

      final encoded = jsonEncode(merged.map((g) => g.toJson()).toList());
      await prefs.setString(_gamesCacheKey(userId, childId), encoded);
      await prefs.setString(
        _gamesCacheUpdatedKey(userId, childId),
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      LogService.warning('🎮 [skulMate] Could not cache games locally: $e');
    }
  }

  static Future<List<GameModel>> _readCachedGames({
    required String userId,
    required String? childId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_gamesCacheKey(userId, childId));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final result = <GameModel>[];
      for (final entry in decoded) {
        Map<String, dynamic>? mapEntry;
        if (entry is Map<String, dynamic>) {
          mapEntry = entry;
        } else if (entry is Map) {
          mapEntry = entry.cast<String, dynamic>();
        } else if (entry is String) {
          try {
            final parsed = jsonDecode(entry);
            if (parsed is Map<String, dynamic>) {
              mapEntry = parsed;
            } else if (parsed is Map) {
              mapEntry = parsed.cast<String, dynamic>();
            }
          } catch (_) {}
        }
        if (mapEntry != null) {
          try {
            result.add(GameModel.fromJson(mapEntry));
          } catch (_) {
            // Skip malformed cached rows and keep loading usable ones.
          }
        }
      }
      return result;
    } catch (e) {
      LogService.warning('🎮 [skulMate] Could not read cached games: $e');
      return const [];
    }
  }
}
