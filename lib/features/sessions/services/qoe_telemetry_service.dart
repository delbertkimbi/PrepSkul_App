import 'dart:math';

import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

class QoeTelemetryService {
  QoeTelemetryService._();
  static final Map<String, _QoeSessionTarget> _sessionTargetCache = {};

  static String buildCorrelationId(String sessionId) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(1 << 20).toRadixString(16);
    return 'qoe_$sessionId\_$ts\_$rand';
  }

  static bool get isEnabled {
    return AppConfig.enableClassroomQoeTelemetry;
  }

  static Future<void> emit({
    required String sessionId,
    required String correlationId,
    required String eventName,
    required Map<String, dynamic> payload,
    String eventSource = 'agora_service',
  }) async {
    if (!isEnabled || sessionId.isEmpty || correlationId.isEmpty) return;

    try {
      final target = await _resolveSessionTarget(sessionId);
      if (target == null) return;
      final userId = SupabaseService.client.auth.currentUser?.id;
      await SupabaseService.client.from('session_qoe_events').insert({
        'individual_session_id':
            target == _QoeSessionTarget.individual ? sessionId : null,
        'trial_session_id': target == _QoeSessionTarget.trial ? sessionId : null,
        'correlation_id': correlationId,
        'event_name': eventName,
        'event_source': eventSource,
        'user_id': userId,
        'event_at': DateTime.now().toIso8601String(),
        'payload': payload,
      });
    } catch (e) {
      LogService.warning('[QOE] Failed to emit "$eventName": $e');
    }
  }

  static Future<_QoeSessionTarget?> _resolveSessionTarget(String sessionId) async {
    final cached = _sessionTargetCache[sessionId];
    if (cached != null) return cached;

    final client = SupabaseService.client;
    try {
      final individual = await client
          .from('individual_sessions')
          .select('id')
          .eq('id', sessionId)
          .maybeSingle();
      if (individual != null) {
        _sessionTargetCache[sessionId] = _QoeSessionTarget.individual;
        return _QoeSessionTarget.individual;
      }
    } catch (_) {}

    try {
      final trial = await client
          .from('trial_sessions')
          .select('id')
          .eq('id', sessionId)
          .maybeSingle();
      if (trial != null) {
        _sessionTargetCache[sessionId] = _QoeSessionTarget.trial;
        return _QoeSessionTarget.trial;
      }
    } catch (_) {}
    return null;
  }
}

enum _QoeSessionTarget { individual, trial }
