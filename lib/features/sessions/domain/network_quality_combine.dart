import 'package:agora_rtc_engine/agora_rtc_engine.dart';

/// Higher rank = worse network for PrepSkul encoder/stream adaptation.
int networkQualityStressRank(QualityType q) {
  switch (q) {
    case QualityType.qualityDown:
      return 6;
    case QualityType.qualityVbad:
      return 5;
    case QualityType.qualityBad:
      return 4;
    case QualityType.qualityPoor:
      return 3;
    case QualityType.qualityGood:
      return 2;
    case QualityType.qualityExcellent:
      return 1;
    case QualityType.qualityUnknown:
    case QualityType.qualityUnsupported:
    case QualityType.qualityDetecting:
      return -1;
  }
}

/// Prefer the weaker leg so uplink-only issues affect tier (matches Agora TX/RX semantics).
QualityType worstLocalNetworkQuality(QualityType tx, QualityType rx) {
  final rt = networkQualityStressRank(tx);
  final rr = networkQualityStressRank(rx);
  if (rt < 0 && rr < 0) return QualityType.qualityUnknown;
  if (rt < 0) return rx;
  if (rr < 0) return tx;
  return rt >= rr ? tx : rx;
}
