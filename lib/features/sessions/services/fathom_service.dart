import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';

/// Fathom AI Service
/// 
/// Handles Fathom API interactions for meeting data
/// Documentation: docs/FATHOM_API_DOCUMENTATION.md
/// 
/// Environment is controlled by AppConfig.isProduction

class FathomService {
  static const String _baseUrl = 'https://api.fathom.ai/external/v1';

  /// Get API key from AppConfig
  static String? get _apiKey {
    // Fathom uses OAuth, so API key may not be needed
    // But if available, use it
    return AppConfig.fathomClientId.isNotEmpty ? AppConfig.fathomClientId : null;
  }

  /// Get PrepSkul VA email from AppConfig
  static String get _prepskulVAEmail => AppConfig.prepskulVAEmail;

  /// Make authenticated API request
  static Future<Map<String, dynamic>> _makeRequest(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      final apiKey = _apiKey;
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Fathom API key not configured');
      }

      final uri = Uri.parse('$_baseUrl$endpoint').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'X-Api-Key': apiKey,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception('Fathom API Error: ${errorBody['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      LogService.error('Fathom API request error: $e');
      rethrow;
    }
  }

  /// List meetings for PrepSkul VA
  /// 
  /// Retrieves all meetings where PrepSkul VA was an attendee
  /// 
  /// Parameters:
  /// - [createdAfter]: Filter meetings created after this date
  /// - [createdBefore]: Filter meetings created before this date
  /// - [includeTranscript]: Include transcript in response
  /// - [includeSummary]: Include summary in response
  /// - [includeActionItems]: Include action items in response
  static Future<List<Map<String, dynamic>>> getPrepSkulSessions({
    DateTime? createdAfter,
    DateTime? createdBefore,
    bool includeTranscript = false,
    bool includeSummary = false,
    bool includeActionItems = false,
  }) async {
    try {
      final queryParams = <String, String>{
        'calendar_invitees[]': _prepskulVAEmail,
        if (includeTranscript) 'include_transcript': 'true',
        if (includeSummary) 'include_summary': 'true',
        if (includeActionItems) 'include_action_items': 'true',
        if (createdAfter != null)
          'created_after': createdAfter.toIso8601String(),
        if (createdBefore != null)
          'created_before': createdBefore.toIso8601String(),
      };

      final response = await _makeRequest('/meetings', queryParams: queryParams);
      final items = response['items'] as List<dynamic>? ?? [];
      
      return items.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      LogService.error('Error fetching PrepSkul sessions: $e');
      rethrow;
    }
  }

  /// Get meeting by recording ID
  /// 
  /// Retrieves a specific meeting with all details
  /// 
  /// Parameters:
  /// - [recordingId]: Fathom recording ID
  /// - [includeTranscript]: Include transcript
  /// - [includeSummary]: Include summary
  /// - [includeActionItems]: Include action items
  static Future<Map<String, dynamic>> getMeeting(
    int recordingId, {
    bool includeTranscript = false,
    bool includeSummary = false,
    bool includeActionItems = false,
  }) async {
    try {
      // First, get from meetings list filtered by recording_id
      final sessions = await getPrepSkulSessions(
        includeTranscript: includeTranscript,
        includeSummary: includeSummary,
        includeActionItems: includeActionItems,
      );

      // Find matching recording
      final meeting = sessions.firstWhere(
        (m) => m['recording_id'] == recordingId,
        orElse: () => throw Exception('Meeting not found'),
      );

      return meeting;
    } catch (e) {
      LogService.error('Error fetching meeting: $e');
      rethrow;
    }
  }

  /// Get meeting summary
  /// 
  /// Retrieves AI-generated summary for a recording
  /// 
  /// Parameters:
  /// - [recordingId]: Fathom recording ID
  static Future<Map<String, dynamic>> getSummary(int recordingId) async {
    try {
      final response = await _makeRequest('/recordings/$recordingId/summary');
      return response['summary'] as Map<String, dynamic>;
    } catch (e) {
      LogService.error('Error fetching summary: $e');
      rethrow;
    }
  }

  /// Get meeting transcript
  /// 
  /// Retrieves full transcript with speaker identification
  /// 
  /// Parameters:
  /// - [recordingId]: Fathom recording ID
  static Future<List<Map<String, dynamic>>> getTranscript(int recordingId) async {
    try {
      final response = await _makeRequest('/recordings/$recordingId/transcript');
      return (response['transcript'] as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      LogService.error('Error fetching transcript: $e');
      rethrow;
    }
  }
}
