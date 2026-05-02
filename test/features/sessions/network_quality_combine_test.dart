import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/domain/network_quality_combine.dart';

void main() {
  group('worstLocalNetworkQuality', () {
    test('prefers worse leg when both known', () {
      expect(
        worstLocalNetworkQuality(
          QualityType.qualityExcellent,
          QualityType.qualityPoor,
        ),
        QualityType.qualityPoor,
      );
      expect(
        worstLocalNetworkQuality(
          QualityType.qualityPoor,
          QualityType.qualityExcellent,
        ),
        QualityType.qualityPoor,
      );
    });

    test('uses known sample when other is unknown', () {
      expect(
        worstLocalNetworkQuality(
          QualityType.qualityUnknown,
          QualityType.qualityGood,
        ),
        QualityType.qualityGood,
      );
      expect(
        worstLocalNetworkQuality(
          QualityType.qualityBad,
          QualityType.qualityUnsupported,
        ),
        QualityType.qualityBad,
      );
    });

    test('unknown when neither side is measurable', () {
      expect(
        worstLocalNetworkQuality(
          QualityType.qualityUnknown,
          QualityType.qualityDetecting,
        ),
        QualityType.qualityUnknown,
      );
    });
  });
}
