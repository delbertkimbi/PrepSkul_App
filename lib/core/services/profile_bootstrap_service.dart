import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:postgrest/postgrest.dart';

/// Server-side profile upsert when client RLS blocks onboarding writes.
class ProfileBootstrapService {
  static bool _isRlsError(Object error) {
    if (error is PostgrestException && error.code == '42501') {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('42501') ||
        text.contains('row-level security') ||
        text.contains('violates row-level security');
  }

  static Future<void> upsertProfileViaApi({
    required String fullName,
    String? email,
    String? phoneNumber,
    String? userType,
    bool surveyCompleted = false,
  }) async {
    final session = SupabaseService.client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Your session expired. Please sign in again.');
    }

    final url = Uri.parse(
      '${AppConfig.effectiveApiBaseUrl}/mobile/auth/bootstrap-profile',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'fullName': fullName,
        if (email != null && email.isNotEmpty) 'email': email,
        'phoneNumber': phoneNumber,
        if (userType != null && userType.isNotEmpty) 'userType': userType,
        'surveyCompleted': surveyCompleted,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(
      'Could not save your profile (${response.statusCode}). Please try again.',
    );
  }

  static Future<void> upsertProfile({
    required String userId,
    required String fullName,
    String? email,
    String? phoneNumber,
    String? userType,
    bool surveyCompleted = false,
  }) async {
    final payload = <String, dynamic>{
      'id': userId,
      'email': email ?? '',
      'full_name': fullName,
      'phone_number': phoneNumber,
      'user_type': userType,
      'survey_completed': surveyCompleted,
      'is_admin': false,
      'updated_at': DateTime.now().toIso8601String(),
    };
    payload.removeWhere((_, value) => value == null);

    try {
      await SupabaseService.client.from('profiles').upsert(
        payload,
        onConflict: 'id',
      );
    } catch (e) {
      if (!_isRlsError(e)) {
        rethrow;
      }
      LogService.warning(
        '[PROFILE] Client upsert blocked by RLS — using bootstrap API',
      );
      await upsertProfileViaApi(
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        userType: userType,
        surveyCompleted: surveyCompleted,
      );
    }
  }
}
