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
///
/// [minDwellDown] / [minDwellUp] asymmetry: quicker tier step-down on sustained poor
/// on sustained bad network, slower step-up so brief recovery does not thrash the encoder.
class QualityController {
  QualityController({
    this.poorThreshold = 3,
    this.goodThreshold = 4,
    this.minDwellDown = const Duration(seconds: 8),
    this.minDwellUp = const Duration(seconds: 12),
  });

  final int poorThreshold;
  final int goodThreshold;
  final Duration minDwellDown;
  final Duration minDwellUp;

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

    final isDowngrade = _rank(target) < _rank(_currentTier!);
    final dwell = _dwellForChange(isDowngrade: isDowngrade);
    if (_lastTierChangeAt != null && at.difference(_lastTierChangeAt!) < dwell) {
      return null;
    }
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

  /// Clear tier memory (e.g. after leaving a channel) so the next call starts fresh.
  void reset() {
    _consecutivePoor = 0;
    _consecutiveGood = 0;
    _lastTierChangeAt = null;
    _currentTier = null;
  }

  Duration _dwellForChange({required bool isDowngrade}) =>
      isDowngrade ? minDwellDown : minDwellUp;
}
