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

      // Use effectiveApiBaseUrl so production (app.prepskul.com) always hits www.prepskul.com/api,
      // and local dev (localhost) hits localhost:3000. Never force localhost when host is app.prepskul.com.
      final apiBaseUrl = AppConfig.effectiveApiBaseUrl;
      final url = '$apiBaseUrl/agora/token';
      LogService.info('🎥 Fetching Agora token from: $url');
      LogService.debug('🎥 Session ID: $sessionId');
      LogService.debug('🎥 User ID: ${session.user.id}');
      LogService.debug('🎥 Platform: ${kIsWeb ? 'Web' : 'Mobile'}');

      // Make request to Next.js backend
      // On web, use web-specific HTTP client for proper CORS handling
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      };
      final body = jsonEncode({
        'sessionId': sessionId,
      });
      
      LogService.debug('🎥 Request headers: ${headers.keys.join(', ')}');
      LogService.debug('🎥 Request body: $body');
      
      // Retry logic with exponential backoff
      int maxRetries = 3;
      Duration timeout = const Duration(seconds: 30); // Increased from 10 to 30 seconds
      http.Response? response;
      Exception? lastError;

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          LogService.info('🎥 Attempt $attempt/$maxRetries: Fetching token from $url');
          final requestStartTime = DateTime.now();
          
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
          
          final requestDuration = DateTime.now().difference(requestStartTime);
          LogService.debug('🎥 Request completed in ${requestDuration.inMilliseconds}ms');
          LogService.debug('🎥 Response status: ${response.statusCode}');
          
          // If we got a response, break out of retry loop
          break;
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          LogService.warning('⚠️ Attempt $attempt/$maxRetries failed');
          LogService.error('   Error type: ${e.runtimeType}');
          LogService.error('   Error message: ${e.toString()}');
          
          // Log more details about the error
          if (e.toString().contains('ClientException')) {
            LogService.error('   This is a network/client exception. Possible causes:');
            LogService.error('   - CORS configuration issue');
            LogService.error('   - Network connectivity problem');
            LogService.error('   - Server not responding');
          } else if (e.toString().contains('timeout')) {
            LogService.error('   Request timed out. Possible causes:');
            LogService.error('   - Server is slow to respond');
            LogService.error('   - Network latency issues');
            LogService.error('   - Server is down or unreachable');
          } else if (e.toString().contains('[server]')) {
            LogService.error('   Server returned an error. Check server logs.');
          }
          
          // If this is the last attempt, rethrow
          if (attempt == maxRetries) {
            LogService.error('❌ All $maxRetries attempts failed. Giving up.');
            rethrow;
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
      LogService.debug('🎥 Response headers: ${response.headers}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        LogService.success('✅ Agora token fetched successfully');
        return data;
      } else {
        // Log the full response for debugging
        LogService.error('❌ Server returned error status: ${response.statusCode}');
        LogService.error('❌ Response body: ${response.body}');
        LogService.error('❌ Response headers: ${response.headers}');
        
        // Try to parse error response
        String? serverErrorMessage;
        Map<String, dynamic>? errorBody;
        
        if (response.body.isNotEmpty) {
          try {
            errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
            serverErrorMessage = errorBody?['error'] as String? 
                ?? errorBody?['message'] as String?
                ?? errorBody?['details'] as String?
                ?? errorBody?.toString();
            
            if (serverErrorMessage != null) {
              LogService.error('❌ Server error message: $serverErrorMessage');
            }
          } catch (parseError) {
            LogService.warning('⚠️ Could not parse error response as JSON: $parseError');
            LogService.warning('⚠️ Raw response body: ${response.body}');
            serverErrorMessage = response.body;
          }
        }
        
        // Provide specific error messages based on status code
        if (response.statusCode == 401) {
          final message = serverErrorMessage ?? 'Unauthorized. Please log in again.';
          throw Exception(message);
        } else if (response.statusCode == 403) {
          final message = serverErrorMessage ?? 'Access denied. You are not a participant in this session.';
          throw Exception(message);
        } else if (response.statusCode == 404) {
          final message = serverErrorMessage ?? 'API endpoint not found. Please check server configuration.';
          throw Exception(message);
        } else if (response.statusCode == 500) {
          // HTTP 500 - Server error - show actual server error message
          final message = serverErrorMessage ?? 'Server error occurred. Please check server logs.';
          throw Exception('Server Error (500): $message\n\nThis is a server-side issue. Please check:\n1. Next.js API route logs\n2. Environment variables (AGORA_APP_ID, AGORA_APP_CERTIFICATE)\n3. Database connection\n4. Server deployment status');
        } else if (response.statusCode >= 500) {
          final message = serverErrorMessage ?? 'Server error occurred.';
          throw Exception('Server Error (${response.statusCode}): $message');
        } else {
          // Other 4xx errors
          final message = serverErrorMessage ?? 'Failed to fetch token (Status: ${response.statusCode})';
          throw Exception('Client Error (${response.statusCode}): $message');
        }
      }
    } catch (e) {
      // Get the actual URL that was used
      String apiBaseUrl = AppConfig.effectiveApiBaseUrl;
      if (apiBaseUrl.contains('app.prepskul.com')) {
        apiBaseUrl = 'https://www.prepskul.com/api';
      }
      final errorUrl = '$apiBaseUrl/agora/token';
      
      // Log comprehensive error information
      LogService.error('❌ ========== AGORA TOKEN FETCH ERROR ==========');
      LogService.error('❌ Error type: ${e.runtimeType}');
      LogService.error('❌ Error message: ${e.toString()}');
      LogService.error('❌ API URL: $errorUrl');
      LogService.error('❌ Session ID: $sessionId');
      LogService.error('❌ Platform: ${kIsWeb ? 'Web' : 'Mobile'}');
      LogService.error('❌ ============================================');
      
      // If the error already contains a detailed message (from server response), use it
      if (e.toString().contains('Server Error') || 
          e.toString().contains('Client Error') ||
          e.toString().contains('Unauthorized') ||
          e.toString().contains('Access denied')) {
        // This is already a detailed error message from the server
        LogService.error('❌ Server-provided error message (already detailed)');
        rethrow;
      }
      
      // Check if this is already a server error message (from 500 handler above)
      // If so, rethrow it as-is without converting to network error
      if (e.toString().contains('Server Error (500)') || 
          e.toString().contains('Server Error (')) {
        // This is already a properly formatted server error, rethrow it
        LogService.error('❌ Final error message to user: $e');
        rethrow;
      }
      
      // Check if ClientException contains [server] - this indicates a server error
      // even though it's wrapped in ClientException
      if (e.toString().contains('[server]') && 
          (e.toString().contains('HTTP 500') || e.toString().contains('500'))) {
        // Extract the actual server error message if available
        String serverErrorMsg = 'Server Error (500): Internal server error occurred.\n\n'
            'API URL: $errorUrl\n\n'
            'This is a server-side issue. Please check:\n'
            '1. Next.js API route logs (Vercel Functions logs)\n'
            '2. Environment variables (AGORA_APP_ID, AGORA_APP_CERTIFICATE)\n'
            '3. Database connection\n'
            '4. Server deployment status\n\n'
            'See AGORA_500_ERROR_DIAGNOSTIC.md for detailed troubleshooting steps.';
        
        LogService.error('❌ Final error message to user: $serverErrorMsg');
        throw Exception(serverErrorMsg);
      }
      
      // Otherwise, provide helpful error message based on error type
      String errorMessage;
      
      // Check for CORS errors (from web client)
      if (e.toString().contains('[cors]') || 
          e.toString().contains('CORS blocked') ||
          e.toString().contains('status: 0')) {
        errorMessage = 'CORS Error: The API server is not allowing requests from this origin.\n\n'
            'API URL: $errorUrl\n\n'
            'This usually means:\n'
            '1. CORS headers are missing in Next.js API route\n'
            '2. The origin (${Uri.base.origin}) is not whitelisted\n\n'
            'Check: PrepSkul_Web/app/api/agora/token/route.ts';
      } else if (e.toString().contains('Failed to fetch') || 
                 (e.toString().contains('ClientException') && !e.toString().contains('[server]')) ||
                 (e.toString().contains('[network]') && !e.toString().contains('[server]'))) {
        // Network/client exception (but not server errors)
        errorMessage = 'Network Error: Unable to connect to video service API.\n\n'
            'API URL: $errorUrl\n\n'
            'Possible causes:\n'
            '1. Server is down or unreachable\n'
            '2. Network connectivity issue\n'
            '3. CORS configuration problem\n'
            '4. Firewall blocking the request\n\n'
            'Check server logs and network connectivity.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request Timeout: The API server did not respond in time.\n\n'
            'API URL: $errorUrl\n\n'
            'This usually means:\n'
            '1. Server is slow to respond\n'
            '2. Server is overloaded\n'
            '3. Network latency is high\n'
            '4. Server is down\n\n'
            'Check server status and response times.';
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Network') ||
                 e.toString().contains('Connection')) {
        errorMessage = 'Connection Error: Unable to establish connection to server.\n\n'
            'API URL: $errorUrl\n\n'
            'Check your internet connection and server status.';
      } else {
        // Generic error - show the actual error message
        errorMessage = 'Error fetching Agora token:\n\n$e\n\n'
            'API URL: $errorUrl\n\n'
            'Please check:\n'
            '1. Server logs for detailed error information\n'
            '2. Network connectivity\n'
            '3. Server deployment status';
      }
      
      LogService.error('❌ Final error message to user: $errorMessage');
      throw Exception(errorMessage);
    }
  }
}

