import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Agora Recording Service
///
/// Handles starting and stopping Agora Cloud Recording via Next.js backend API.
/// Uses [AppConfig.effectiveApiBaseUrl] so recording hits the same API as the rest
/// of the app (e.g. localhost in dev), ensuring session_recordings gets populated.
class AgoraRecordingService {
  static final _recordingFailedController = StreamController<String>.broadcast();
  static Stream<String> get onRecordingFailed => _recordingFailedController.stream;

  static SupabaseClient get _supabase => SupabaseService.client;

  /// Base URL for recording API (matches rest of app: localhost in dev, production otherwise)
  static String get _apiBaseUrl => AppConfig.effectiveApiBaseUrl;

  /// Start Agora Cloud Recording for a session
  ///
  /// [sessionId] Individual session ID
  /// Returns recording metadata: { resourceId, sid }
  static Future<Map<String, dynamic>?> startRecording(String sessionId) async {
    LogService.info('🎙️🎙️🎙️ [Recording] startRecording() called for session: $sessionId');
    LogService.info('🎙️ [Recording] Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
    LogService.info('🎙️ [Recording] API Base URL: $_apiBaseUrl');
    
    try {
      // Get Supabase session token for authentication
      final session = _supabase.auth.currentSession;
      if (session == null) {
        LogService.error('🎙️ [Recording] FAILED: User not authenticated (no session)');
        throw Exception('User not authenticated');
      }
      
      LogService.info('🎙️ [Recording] User authenticated: ${session.user.id}');

      final url = '$_apiBaseUrl/agora/recording/start';
      LogService.info('🎙️ [Recording] Making POST request to: $url');
      LogService.info('🎙️ [Recording] Request body: {"sessionId": "$sessionId"}');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'sessionId': sessionId,
        }),
      );

      LogService.info('🎙️ [Recording] Response status: ${response.statusCode}');
      LogService.info('🎙️ [Recording] Response headers: ${response.headers}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        LogService.success('🎙️ [Recording] SUCCESS! Recording started');
        LogService.success('🎙️ [Recording] resourceId: ${data['resourceId']}');
        LogService.success('🎙️ [Recording] sid: ${data['sid']}');
        LogService.success('🎙️ [Recording] channelName: ${data['channelName']}');
        return data;
      } else {
        // Don't assume backend always returns JSON (avoid crashing on html/text errors)
        LogService.error('🎙️ [Recording] FAILED with status: ${response.statusCode}');

        String userMessage = 'Recording could not start';

        try {
          final errorBody = jsonDecode(response.body);
          final errorMsg = errorBody is Map ? errorBody['error'] : errorBody;
          LogService.error('🎙️ [Recording] Error from backend: $errorMsg');
          LogService.error('🎙️ [Recording] Full response: ${response.body}');

          if (errorMsg != null && errorMsg.toString().isNotEmpty) {
            userMessage = 'Recording could not start: ${errorMsg.toString()}';
          }
        } catch (_) {
          final bodyPreview = response.body.length > 500 ? '${response.body.substring(0, 500)}…' : response.body;
          LogService.error('🎙️ [Recording] Non-JSON response body (preview): $bodyPreview');
          userMessage = 'Recording could not start (HTTP ${response.statusCode})';
        }

        LogService.warning('🎙️ [Recording] Emitting failure message to UI: $userMessage');
        _recordingFailedController.add(userMessage);
        return null; // Don't fail session start if recording fails
      }
    } catch (e, stackTrace) {
      LogService.error('🎙️ [Recording] EXCEPTION: $e');
      LogService.error('🎙️ [Recording] Stack trace: $stackTrace');
      final message = 'Recording could not start: ${e.toString()}';
      LogService.warning('🎙️ [Recording] Emitting failure message to UI after exception: $message');
      _recordingFailedController.add(message);
      return null; // Don't fail session start if recording fails
    }
  }

  /// Stop Agora Cloud Recording for a session
  ///
  /// [sessionId] Individual session ID
  static Future<void> stopRecording(String sessionId) async {
    LogService.info('🛑 [Recording] stopRecording() called sessionId=$sessionId apiBaseUrl=$_apiBaseUrl');
    debugPrint('[Recording] stopRecording sessionId=$sessionId');
    
    try {
      // Get Supabase session token for authentication
      final session = _supabase.auth.currentSession;
      if (session == null) {
        LogService.error('🛑 [Recording] FAILED to stop: User not authenticated');
        throw Exception('User not authenticated');
      }

      final url = '$_apiBaseUrl/agora/recording/stop';
      LogService.info('🛑 [Recording] POST $url body: sessionId=$sessionId');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'sessionId': sessionId,
        }),
      );

      final bodyPreview = response.body.length > 300 ? '${response.body.substring(0, 300)}…' : response.body;
      LogService.info('🛑 [Recording] Response status=${response.statusCode} body=$bodyPreview');
      debugPrint('[Recording] stop response status=${response.statusCode}');
      
      if (response.statusCode == 200) {
        LogService.success('🛑 [Recording] SUCCESS recording stopped sessionId=$sessionId');
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          final errorMsg = errorBody is Map ? errorBody['error'] : errorBody;
          LogService.error('🛑 [Recording] Stop FAILED status=${response.statusCode} error=$errorMsg');
        } catch (_) {
          LogService.error('🛑 [Recording] Stop FAILED (${response.statusCode}) body=$bodyPreview');
        }
        // Don't throw - recording stop failure shouldn't block session end
      }
    } catch (e, stackTrace) {
      LogService.error('🛑 [Recording] EXCEPTION stopping recording: $e');
      LogService.error('🛑 [Recording] Stack trace: $stackTrace');
      // Don't throw - recording stop failure shouldn't block session end
    }
  }
}

