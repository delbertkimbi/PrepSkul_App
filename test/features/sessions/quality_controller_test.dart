import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/domain/quality_controller.dart';

void main() {
  group('QualityController', () {
    test('sets initial tier immediately on first sample', () {
      final qc = QualityController();
      final d = qc.onSample(
        network: QualityType.qualityGood,
        at: DateTime(2026, 1, 1, 10, 0, 0),
      );
      expect(d, isNotNull);
      expect(d!.tier, VideoQualityTier.high720p);
    });

    test('does not oscillate on noisy short spikes', () {
      final qc = QualityController();
      final base = DateTime(2026, 1, 1, 10, 0, 0);

      qc.onSample(network: QualityType.qualityGood, at: base);

      final d1 = qc.onSample(
        network: QualityType.qualityPoor,
        at: base.add(const Duration(seconds: 1)),
      );
      final d2 = qc.onSample(
        network: QualityType.qualityGood,
        at: base.add(const Duration(seconds: 2)),
      );
      final d3 = qc.onSample(
        network: QualityType.qualityPoor,
        at: base.add(const Duration(seconds: 3)),
      );

      expect(d1, isNull);
      expect(d2, isNull);
      expect(d3, isNull);
      expect(qc.currentTier, VideoQualityTier.high720p);
    });

    test('downgrades only after sustained poor samples and dwell time', () {
      final qc = QualityController();
      final base = DateTime(2026, 1, 1, 10, 0, 0);
      qc.onSample(network: QualityType.qualityGood, at: base);

      // Poor streak before dwell window expires -> no downgrade.
      for (int i = 1; i <= 3; i++) {
        final d = qc.onSample(
          network: QualityType.qualityPoor,
          at: base.add(Duration(seconds: i)),
        );
        expect(d, isNull);
      }

      // After [minDwellDown] (8s) and sustained poor, downgrade should happen.
      final d4 = qc.onSample(
        network: QualityType.qualityPoor,
        at: base.add(const Duration(seconds: 8)),
      );
      expect(d4, isNotNull);
      expect(d4!.tier, VideoQualityTier.medium480p);
    });

    test('upgrade requires longer dwell than downgrade (asymmetric)', () {
      final qc = QualityController(
        poorThreshold: 2,
        goodThreshold: 2,
        minDwellDown: const Duration(seconds: 2),
        minDwellUp: const Duration(seconds: 6),
      );
      final base = DateTime(2026, 1, 1, 10, 0, 0);
      qc.onSample(network: QualityType.qualityGood, at: base);
      qc.onSample(
        network: QualityType.qualityPoor,
        at: base.add(const Duration(seconds: 1)),
      );
      final down = qc.onSample(
        network: QualityType.qualityPoor,
        at: base.add(const Duration(seconds: 2)),
      );
      expect(down, isNotNull);
      expect(down!.tier, VideoQualityTier.medium480p);

      // Sustained good streak, but still inside minDwellUp window from downgrade.
      qc.onSample(network: QualityType.qualityGood, at: base.add(const Duration(seconds: 3)));
      qc.onSample(network: QualityType.qualityGood, at: base.add(const Duration(seconds: 4)));
      final earlyUp = qc.onSample(
        network: QualityType.qualityGood,
        at: base.add(const Duration(seconds: 7)),
      );
      expect(earlyUp, isNull);

      final up = qc.onSample(
        network: QualityType.qualityGood,
        at: base.add(const Duration(seconds: 8)),
      );
      expect(up, isNotNull);
      expect(up!.tier, VideoQualityTier.high720p);
    });
  });
}

