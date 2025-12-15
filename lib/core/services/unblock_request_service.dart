import 'package:http/http.dart' as http;
import 'package:prepskul/core/services/log_service.dart';
import 'dart:convert';
import 'package:prepskul/core/services/supabase_service.dart';

/// Service for handling tutor unblock/unhide requests
class UnblockRequestService {
  static const String _baseUrl = 'https://www.prepskul.com'; // Change to your production URL

  /// Submit an unblock/unhide request
  /// 
  /// Parameters:
  /// - [tutorId]: Tutor profile ID
  /// - [requestType]: 'unblock' or 'unhide'
  /// - [reason]: Optional reason for the request
  /// 
  /// Returns: Request ID if successful
  static Future<String> submitRequest({
    required String tutorId,
    required String requestType,
    String? reason,
  }) async {
    try {
      // Get current user session token
      final session = SupabaseService.client.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated');
      }

      final url = Uri.parse('$_baseUrl/api/admin/tutors/$tutorId/unblock-request');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'requestType': requestType,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['request']['id'] as String;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to submit request');
      }
    } catch (e) {
      LogService.error('Error submitting unblock request: $e');
      rethrow;
    }
  }

  /// Get status of an unblock request
  static Future<Map<String, dynamic>?> getRequestStatus(String requestId) async {
    try {
      final session = SupabaseService.client.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated');
      }

      // Query from database directly
      final response = await SupabaseService.client
          .from('tutor_unblock_requests')
          .select()
          .eq('id', requestId)
          .maybeSingle();

      return response;
    } catch (e) {
      LogService.error('Error getting request status: $e');
      return null;
    }
  }
}






