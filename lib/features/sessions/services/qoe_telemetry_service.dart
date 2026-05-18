import 'dart:math';

import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

enum _QoeEmitResult { inserted, skipped, failedRetryable, failedPermanent }

class _PendingQoeRow {
  const _PendingQoeRow({
    required this.sessionId,
    required this.correlationId,
    required this.eventName,
    required this.payload,
    required this.eventSource,
  });

  final String sessionId;
  final String correlationId;
  final String eventName;
  final Map<String, dynamic> payload;
  final String eventSource;
}

class QoeTelemetryService {
  QoeTelemetryService._();
  static final Map<String, _QoeSessionTarget> _sessionTargetCache = {};
  static final List<_PendingQoeRow> _pending = <_PendingQoeRow>[];
  static const int _maxPending = 48;

  static String buildCorrelationId(String sessionId) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(1 << 20).toRadixString(16);
    return 'qoe_$sessionId\_$ts\_$rand';
  }

  static bool get isEnabled {
    return AppConfig.enableClassroomQoeTelemetry;
  }

  static bool _retryableNetwork(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('clientexception') ||
        s.contains('handshakeexception') ||
        s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('network is unreachable') ||
        s.contains('timed out') ||
        s.contains('timeout') ||
        s.contains('no address associated with hostname') ||
        s.contains('host lookup failed');
  }

  static void _enqueuePending({
    required String sessionId,
    required String correlationId,
    required String eventName,
    required Map<String, dynamic> payload,
    required String eventSource,
  }) {
    if (_pending.length >= _maxPending) {
      _pending.removeAt(0);
    }
    _pending.add(
      _PendingQoeRow(
        sessionId: sessionId,
        correlationId: correlationId,
        eventName: eventName,
        payload: payload,
        eventSource: eventSource,
      ),
    );
  }

  static Future<_QoeEmitResult> _emitOne({
    required String sessionId,
    required String correlationId,
    required String eventName,
    required Map<String, dynamic> payload,
    required String eventSource,
  }) async {
    try {
      final target = await _resolveSessionTarget(sessionId);
      if (target == null) return _QoeEmitResult.skipped;
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
      return _QoeEmitResult.inserted;
    } catch (e) {
      if (_retryableNetwork(e)) {
        LogService.debug(
          '[QOE] Deferred "$eventName" (transient network): $e',
        );
        return _QoeEmitResult.failedRetryable;
      }
      LogService.warning('[QOE] Failed to emit "$eventName": $e');
      return _QoeEmitResult.failedPermanent;
    }
  }

  static Future<void> _drainPending() async {
    while (_pending.isNotEmpty) {
      final row = _pending.first;
      final result = await _emitOne(
        sessionId: row.sessionId,
        correlationId: row.correlationId,
        eventName: row.eventName,
        payload: row.payload,
        eventSource: row.eventSource,
      );
      switch (result) {
        case _QoeEmitResult.inserted:
        case _QoeEmitResult.skipped:
          _pending.removeAt(0);
          continue;
        case _QoeEmitResult.failedPermanent:
          _pending.removeAt(0);
          continue;
        case _QoeEmitResult.failedRetryable:
          return;
      }
    }
  }

  static Future<void> emit({
    required String sessionId,
    required String correlationId,
    required String eventName,
    required Map<String, dynamic> payload,
    String eventSource = 'agora_service',
  }) async {
    if (!isEnabled || sessionId.isEmpty || correlationId.isEmpty) return;

    final result = await _emitOne(
      sessionId: sessionId,
      correlationId: correlationId,
      eventName: eventName,
      payload: payload,
      eventSource: eventSource,
    );

    if (result == _QoeEmitResult.inserted) {
      await _drainPending();
      return;
    }
    if (result == _QoeEmitResult.failedRetryable) {
      _enqueuePending(
        sessionId: sessionId,
        correlationId: correlationId,
        eventName: eventName,
        payload: payload,
        eventSource: eventSource,
      );
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
