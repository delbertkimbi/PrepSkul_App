import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Agora Recording Service
///
/// Handles starting and stopping Agora Cloud Recording via Next.js backend API.
class AgoraRecordingService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Get Next.js API URL from environment or use default
  static String _getApiUrl() {
    const apiUrl = String.fromEnvironment(
      'NEXTJS_API_URL',
      defaultValue: 'https://www.prepskul.com',
    );
    return apiUrl;
  }

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

      final apiUrl = _getApiUrl();
      final url = '$apiUrl/api/agora/recording/start';

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
        final errorBody = jsonDecode(response.body);
        LogService.warning('Failed to start recording: ${errorBody['error']}');
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

      final apiUrl = _getApiUrl();
      final url = '$apiUrl/api/agora/recording/stop';

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
        final errorBody = jsonDecode(response.body);
        LogService.warning('Failed to stop recording: ${errorBody['error']}');
        // Don't throw - recording stop failure shouldn't block session end
      }
    } catch (e) {
      LogService.warning('Error stopping Agora recording: $e');
      // Don't throw - recording stop failure shouldn't block session end
    }
  }
}

