import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

// Import web-specific HTTP client for proper CORS handling
// Use conditional import: stub for mobile, web client for web
import 'http_client_stub.dart' if (dart.library.html) 'package:prepskul/features/skulmate/services/http_client_web.dart';

/// Agora Token Service
///
/// Fetches Agora RTC tokens from the Next.js backend API.
class AgoraTokenService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Fetch Agora token from backend
  ///
  /// [sessionId] Individual session ID
  /// Returns token data: { token, channelName, uid, expiresAt, role }
  static Future<Map<String, dynamic>> fetchToken(String sessionId) async {
    try {
      // Get Supabase session token for authentication
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated');
      }

      // Use AppConfig for API URL (handles dev/prod automatically)
      // For local testing, use localhost if available
      String apiBaseUrl = AppConfig.apiBaseUrl; // Already includes /api
      
      // If running locally (web in debug mode), try localhost first
      if (kIsWeb && !AppConfig.isProd) {
        // Check if API_BASE_URL_DEV is set to localhost in .env
        // Otherwise, try localhost for local Next.js dev server
        const localhostUrl = 'http://localhost:3000/api';
        
        // If the configured URL is not localhost, and we're in debug mode,
        // try localhost first (you can override by setting API_BASE_URL_DEV=http://localhost:3000/api in .env)
        if (!apiBaseUrl.contains('localhost') && !apiBaseUrl.contains('127.0.0.1')) {
          LogService.info('🎥 Local testing detected. Using localhost for Next.js API.');
          LogService.info('🎥 To use a different URL, set API_BASE_URL_DEV in .env file');
          apiBaseUrl = localhostUrl;
        }
      }
      
      final url = '$apiBaseUrl/agora/token';
      LogService.info('🎥 Fetching Agora token from: $url');

      // Make request to Next.js backend
      // On web, use web-specific HTTP client for proper CORS handling
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      };
      final body = jsonEncode({
        'sessionId': sessionId,
      });
      
      // Retry logic with exponential backoff
      int maxRetries = 3;
      Duration timeout = const Duration(seconds: 30); // Increased from 10 to 30 seconds
      http.Response? response;
      Exception? lastError;

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          LogService.info('🎥 Attempt $attempt/$maxRetries: Fetching token from $url');
          
          response = kIsWeb
              ? await postWeb(url, headers, body).timeout(
                  timeout,
                  onTimeout: () {
                    throw Exception('Request timeout after ${timeout.inSeconds}s. The API server may be unreachable or slow to respond.');
                  },
                )
              : await http.post(
                  Uri.parse(url),
                  headers: headers,
                  body: body,
                ).timeout(
                  timeout,
                  onTimeout: () {
                    throw Exception('Request timeout after ${timeout.inSeconds}s. The API server may be unreachable or slow to respond.');
                  },
                );
          
          // If we got a response, break out of retry loop
          break;
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          LogService.warning('⚠️ Attempt $attempt failed: $lastError');
          
          // If this is the last attempt, rethrow
          if (attempt == maxRetries) {
            throw lastError!;
          }
          
          // Wait before retrying (exponential backoff: 1s, 2s, 4s)
          final delay = Duration(seconds: 1 << (attempt - 1));
          LogService.info('⏳ Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        }
      }

      if (response == null) {
        throw lastError ?? Exception('Failed to get response after $maxRetries attempts');
      }

      LogService.info('🎥 Agora token response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        LogService.success('✅ Agora token fetched successfully');
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. You are not a participant in this session.');
      } else {
        final errorBody = response.body.isNotEmpty 
            ? jsonDecode(response.body) as Map<String, dynamic>?
            : null;
        final errorMessage = errorBody?['error'] as String? 
            ?? errorBody?['message'] as String?
            ?? 'Failed to fetch token (Status: ${response.statusCode})';
        throw Exception(errorMessage);
      }
    } catch (e) {
      LogService.error('❌ Error fetching Agora token: $e');
      
      // Get the actual URL that was used (from earlier in the function)
      // Reconstruct it the same way it was built
      String apiBaseUrl = AppConfig.apiBaseUrl;
      if (kIsWeb && !AppConfig.isProd) {
        if (!apiBaseUrl.contains('localhost') && !apiBaseUrl.contains('127.0.0.1')) {
          apiBaseUrl = 'http://localhost:3000/api';
        }
      }
      final errorUrl = '$apiBaseUrl/agora/token';
      
      // Provide more helpful error message based on error type
      String errorMessage = 'Unable to connect to video service.';
      
      // Check for CORS errors (from web client)
      if (e.toString().contains('[cors]') || 
          e.toString().contains('CORS blocked') ||
          e.toString().contains('status: 0')) {
        errorMessage = 'CORS error: The API server is not allowing requests from this origin. '
            'Please check that the Next.js API route has proper CORS headers configured. '
            'API URL: $errorUrl\n\n'
            'To fix: Add CORS headers to your Next.js API route at PrepSkul_Web/app/api/agora/token/route.ts';
      } else if (e.toString().contains('Failed to fetch') || 
                 e.toString().contains('ClientException') ||
                 e.toString().contains('[network]')) {
        // This is typically a CORS issue or network problem
        errorMessage = 'Unable to connect to video service API. '
            'This may be a CORS (Cross-Origin) issue or network problem. Please check:\n'
            '1. The Next.js API server is running at $errorUrl\n'
            '2. CORS is properly configured in Next.js API route\n'
            '3. Your internet connection is working';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timeout. The API server may be unreachable or slow to respond. '
            'API URL: $errorUrl';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Error: $e';
      }
      
      throw Exception(errorMessage);
    }
  }
}

