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
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Base URL for recording API (matches rest of app: localhost in dev, production otherwise)
  static String get _apiBaseUrl => AppConfig.effectiveApiBaseUrl;

  /// Start Agora Cloud Recording for a session
  ///
  /// [sessionId] Individual session ID
  /// Returns recording metadata: { resourceId, sid }
  static Future<Map<String, dynamic>?> startRecording(String sessionId) async {
    try {
      // Get Supabase session token for authentication
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated');
      }

      final url = '$_apiBaseUrl/agora/recording/start';
      LogService.info('🎙️ [Recording] POST $url (sessionId=$sessionId)');

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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        LogService.success('Agora recording started: ${data['resourceId']}');
        return data;
      } else {
        // Don't assume backend always returns JSON (avoid crashing on html/text errors)
        try {
          final errorBody = jsonDecode(response.body);
          LogService.warning(
            '⚠️ [Recording] start failed (${response.statusCode}): ${errorBody is Map ? errorBody['error'] : errorBody}',
          );
        } catch (_) {
          final bodyPreview = response.body.length > 500 ? '${response.body.substring(0, 500)}…' : response.body;
          LogService.warning('⚠️ [Recording] start failed (${response.statusCode}). Body: $bodyPreview');
        }
        return null; // Don't fail session start if recording fails
      }
    } catch (e) {
      LogService.warning('Error starting Agora recording: $e');
      return null; // Don't fail session start if recording fails
    }
  }

  /// Stop Agora Cloud Recording for a session
  ///
  /// [sessionId] Individual session ID
  static Future<void> stopRecording(String sessionId) async {
    try {
      // Get Supabase session token for authentication
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated');
      }

      final url = '$_apiBaseUrl/agora/recording/stop';
      LogService.info('🛑 [Recording] POST $url (sessionId=$sessionId)');

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

      if (response.statusCode == 200) {
        LogService.success('Agora recording stopped for session: $sessionId');
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          LogService.warning(
            '⚠️ [Recording] stop failed (${response.statusCode}): ${errorBody is Map ? errorBody['error'] : errorBody}',
          );
        } catch (_) {
          final bodyPreview = response.body.length > 500 ? '${response.body.substring(0, 500)}…' : response.body;
          LogService.warning('⚠️ [Recording] stop failed (${response.statusCode}). Body: $bodyPreview');
        }
        // Don't throw - recording stop failure shouldn't block session end
      }
    } catch (e) {
      LogService.warning('Error stopping Agora recording: $e');
      // Don't throw - recording stop failure shouldn't block session end
    }
  }
}

