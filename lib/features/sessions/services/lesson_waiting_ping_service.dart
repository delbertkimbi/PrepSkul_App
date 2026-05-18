import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

import 'http_client_stub.dart'
    if (dart.library.html) 'package:prepskul/features/skulmate/services/http_client_web.dart';

enum LessonWaitingPingOutcome { success, cooldown, failure }

class LessonWaitingPingService {
  static String get _url =>
      '${AppConfig.effectiveApiBaseUrl}/classroom/ping-waiting';

  /// Notifies the other session participant via email + push (server-side cooldown).
  static Future<LessonWaitingPingOutcome> ping({required String sessionId}) async {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) {
      LogService.warning('[PING_WAITING] No auth session — cannot ping');
      return LessonWaitingPingOutcome.failure;
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${session.accessToken}',
    };

    try {
      final body = jsonEncode({'sessionId': sessionId});

      late final http.Response response;
      if (kIsWeb) {
        response = await postWeb(_url, headers, body).timeout(
          const Duration(seconds: 22),
          onTimeout: () =>
              http.Response('', 598, reasonPhrase: 'Request timeout'),
        );
      } else {
        response = await http
            .post(Uri.parse(_url), headers: headers, body: body)
            .timeout(const Duration(seconds: 22));
      }

      if (response.statusCode == 200) {
        return LessonWaitingPingOutcome.success;
      }
      if (response.statusCode == 429) {
        return LessonWaitingPingOutcome.cooldown;
      }

      LogService.warning(
        '[PING_WAITING] API ${response.statusCode}: ${response.body}',
      );
      return LessonWaitingPingOutcome.failure;
    } catch (e) {
      LogService.warning('[PING_WAITING] Request failed: $e');
      return LessonWaitingPingOutcome.failure;
    }
  }
}
