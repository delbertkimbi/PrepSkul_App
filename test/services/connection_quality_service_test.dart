import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/services/connection_quality_service.dart';

/// Unit tests for ConnectionQualityService
void main() {
  group('ConnectionQualityService', () {
    test('startMonitoring accepts sessionId', () {
      expect(
        () => ConnectionQualityService.startMonitoring('test-session-123'),
        returnsNormally,
      );
    });

    test('stopMonitoring completes without error', () {
      expect(
        () => ConnectionQualityService.stopMonitoring(),
        returnsNormally,
      );
    });

    test('getBestQuality returns quality string', () {
      final quality = ConnectionQualityService.getBestQuality();
      expect(quality, isA<String>());
      expect(['good', 'fair', 'poor'], contains(quality));
    });
  });
}
