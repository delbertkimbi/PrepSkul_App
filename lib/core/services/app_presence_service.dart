import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Keeps the user's mobile presence fresh for the admin Active Users dashboard.
class AppPresenceService {
  AppPresenceService._();
  static final AppPresenceService instance = AppPresenceService._();

  Timer? _timer;
  bool _running = false;

  void start() {
    if (_running || kIsWeb) return;
    _running = true;
    ping();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => ping());
    LogService.debug('[PRESENCE] Started mobile presence pings');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    LogService.debug('[PRESENCE] Stopped mobile presence pings');
  }

  Future<void> ping() async {
    if (!SupabaseService.isAuthenticated) return;

    try {
      await SupabaseService.updateLastSeen();
    } catch (e) {
      LogService.debug('[PRESENCE] last_seen update failed: $e');
    }

    try {
      final session = SupabaseService.client.auth.currentSession;
      final token = session?.accessToken;
      if (token == null) return;

      final platform = _platformLabel();
      final response = await http
          .post(
            Uri.parse('${AppConfig.effectiveApiBaseUrl}/mobile/presence/ping'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'platform': platform}),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 400) {
        LogService.debug('[PRESENCE] API ping ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      LogService.debug('[PRESENCE] API ping failed: $e');
    }
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
    } catch (_) {}
    return 'android';
  }
}
