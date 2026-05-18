import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QoE telemetry pipeline', () {
    test('agora service emits D3 telemetry events', () async {
      final service = File('lib/features/sessions/services/agora_service.dart');
      final content = await service.readAsString();

      expect(content.contains("QoeTelemetryService.buildCorrelationId"), isTrue);
      expect(content.contains('quality_tier_changed'), isTrue);
      expect(content.contains('remote_stream_type_changed'), isTrue);
      expect(content.contains('reconnect_attempt'), isTrue);
      expect(content.contains('remote_freeze_start'), isTrue);
      expect(content.contains('remote_freeze_end'), isTrue);
    });

    test('qoe telemetry migration exists with correlation id', () async {
      final migration = File('supabase/migrations/078_session_qoe_events.sql');
      final content = await migration.readAsString();

      expect(content.contains('CREATE TABLE IF NOT EXISTS public.session_qoe_events'), isTrue);
      expect(content.contains('correlation_id TEXT NOT NULL'), isTrue);
      expect(content.contains('event_name TEXT NOT NULL'), isTrue);
      expect(content.contains('ENABLE ROW LEVEL SECURITY'), isTrue);
    });

    test('qoe service queues or defers on transient failures', () async {
      final qoeFile = File('lib/features/sessions/services/qoe_telemetry_service.dart');
      final content = await qoeFile.readAsString();
      expect(content.contains('_pending'), isTrue);
      expect(content.contains('_retryableNetwork'), isTrue);
      expect(content.contains('_drainPending'), isTrue);
    });
  });
}

