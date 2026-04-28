import 'package:agora_rtc_engine/agora_rtc_engine.dart';

enum VideoQualityTier { high720p, medium480p, low360p }

class QualityDecision {
  const QualityDecision({
    required this.tier,
    required this.previousTier,
    required this.networkSample,
  });

  final VideoQualityTier tier;
  final VideoQualityTier? previousTier;
  final QualityType networkSample;
}

/// Policy-driven quality controller with hysteresis and minimum dwell windows.
class QualityController {
  QualityController({
    this.poorThreshold = 3,
    this.goodThreshold = 4,
    this.minDwell = const Duration(seconds: 10),
  });

  final int poorThreshold;
  final int goodThreshold;
  final Duration minDwell;

  int _consecutivePoor = 0;
  int _consecutiveGood = 0;
  DateTime? _lastTierChangeAt;
  VideoQualityTier? _currentTier;

  VideoQualityTier? get currentTier => _currentTier;

  QualityDecision? onSample({
    required QualityType network,
    required DateTime at,
  }) {
    final isGood =
        network == QualityType.qualityExcellent || network == QualityType.qualityGood;
    final isPoor = network == QualityType.qualityPoor ||
        network == QualityType.qualityBad ||
        network == QualityType.qualityDown;

    if (isGood) {
      _consecutiveGood++;
      _consecutivePoor = 0;
    } else if (isPoor) {
      _consecutivePoor++;
      _consecutiveGood = 0;
    } else {
      _consecutiveGood = 0;
      _consecutivePoor = 0;
      return null;
    }

    final target = _targetTierFor(network);
    if (_currentTier == null) {
      final previous = _currentTier;
      _currentTier = target;
      _lastTierChangeAt = at;
      _resetStreaks();
      return QualityDecision(
        tier: target,
        previousTier: previous,
        networkSample: network,
      );
    }

    if (_currentTier == target) {
      return null;
    }

    if (_lastTierChangeAt != null && at.difference(_lastTierChangeAt!) < minDwell) {
      return null;
    }

    final isDowngrade = _rank(target) < _rank(_currentTier!);
    if (isDowngrade && _consecutivePoor < poorThreshold) return null;
    if (!isDowngrade && _consecutiveGood < goodThreshold) return null;

    final previous = _currentTier;
    _currentTier = target;
    _lastTierChangeAt = at;
    _resetStreaks();
    return QualityDecision(
      tier: target,
      previousTier: previous,
      networkSample: network,
    );
  }

  VideoQualityTier _targetTierFor(QualityType q) {
    if (q == QualityType.qualityExcellent || q == QualityType.qualityGood) {
      return VideoQualityTier.high720p;
    }
    if (q == QualityType.qualityPoor || q == QualityType.qualityBad) {
      return VideoQualityTier.medium480p;
    }
    return VideoQualityTier.low360p;
  }

  int _rank(VideoQualityTier tier) {
    switch (tier) {
      case VideoQualityTier.low360p:
        return 0;
      case VideoQualityTier.medium480p:
        return 1;
      case VideoQualityTier.high720p:
        return 2;
    }
  }

  void _resetStreaks() {
    _consecutiveGood = 0;
    _consecutivePoor = 0;
  }
}

