import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/log_service.dart';

class MobileAnalyticsIngestService {
  static String get _endpoint =>
      '${AppConfig.effectiveApiBaseUrl}/analytics/mobile-events/ingest';

  static String get _platform {
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'android';
  }

  static Future<void> trackEvent({
    required String eventType,
    String? userId,
    String? userRole,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final payload = {
        'app': 'flutter_native',
        'events': [
          {
            'eventType': eventType,
            if (userId != null && userId.isNotEmpty) 'userId': userId,
            if (userRole != null && userRole.isNotEmpty) 'userRole': userRole,
            'platform': _platform,
            'eventTimestamp': DateTime.now().toUtc().toIso8601String(),
            'metadata': metadata ?? <String, dynamic>{},
          },
        ],
      };

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-mobile-analytics-key': AppConfig.mobileAnalyticsIngestKey,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        LogService.warning(
          '[MOBILE_INGEST] Failed ($eventType): ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      LogService.warning('[MOBILE_INGEST] Error tracking $eventType: $e');
    }
  }
}
