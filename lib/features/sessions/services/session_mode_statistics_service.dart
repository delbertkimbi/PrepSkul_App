import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class SessionTalkTimeSnapshot {
  const SessionTalkTimeSnapshot({
    required this.localMs,
    required this.remoteMs,
    required this.totalMs,
    required this.localShare,
    required this.remoteShare,
    required this.samples,
  });

  final int localMs;
  final int remoteMs;
  final int totalMs;
  final double localShare;
  final double remoteShare;
  final int samples;

  Map<String, dynamic> toJson() => {
        'local_ms': localMs,
        'remote_ms': remoteMs,
        'total_ms': totalMs,
        'local_share': localShare,
        'remote_share': remoteShare,
        'samples': samples,
      };
}

/// Tracks talking duration from Agora volume indication samples.
class SessionModeStatisticsService {
  DateTime? _localSpeakingSince;
  DateTime? _remoteSpeakingSince;
  int _localAccumMs = 0;
  int _remoteAccumMs = 0;
  int _samples = 0;

  void reset() {
    _localSpeakingSince = null;
    _remoteSpeakingSince = null;
    _localAccumMs = 0;
    _remoteAccumMs = 0;
    _samples = 0;
  }

  void ingestVolumeSample({
    required DateTime at,
    required List<AudioVolumeInfo> speakers,
    required int volumeThreshold,
  }) {
    _samples += 1;
    var localActive = false;
    var remoteActive = false;
    for (final s in speakers) {
      final volume = s.volume ?? 0;
      if (volume <= volumeThreshold) continue;
      final uid = s.uid ?? 0;
      if (uid == 0) {
        localActive = true;
      } else {
        remoteActive = true;
      }
    }
    _consumeStateTransition(
      at: at,
      isLocalActive: localActive,
      isRemoteActive: remoteActive,
    );
  }

  SessionTalkTimeSnapshot snapshot({DateTime? at}) {
    final now = at ?? DateTime.now();
    var localMs = _localAccumMs;
    var remoteMs = _remoteAccumMs;
    if (_localSpeakingSince != null) {
      localMs += now.difference(_localSpeakingSince!).inMilliseconds;
    }
    if (_remoteSpeakingSince != null) {
      remoteMs += now.difference(_remoteSpeakingSince!).inMilliseconds;
    }
    final total = localMs + remoteMs;
    final localShare = total > 0 ? localMs / total : 0.0;
    final remoteShare = total > 0 ? remoteMs / total : 0.0;
    return SessionTalkTimeSnapshot(
      localMs: localMs,
      remoteMs: remoteMs,
      totalMs: total,
      localShare: localShare,
      remoteShare: remoteShare,
      samples: _samples,
    );
  }

  void _consumeStateTransition({
    required DateTime at,
    required bool isLocalActive,
    required bool isRemoteActive,
  }) {
    if (isLocalActive) {
      _localSpeakingSince ??= at;
    } else if (_localSpeakingSince != null) {
      _localAccumMs += at.difference(_localSpeakingSince!).inMilliseconds;
      _localSpeakingSince = null;
    }

    if (isRemoteActive) {
      _remoteSpeakingSince ??= at;
    } else if (_remoteSpeakingSince != null) {
      _remoteAccumMs += at.difference(_remoteSpeakingSince!).inMilliseconds;
      _remoteSpeakingSince = null;
    }
  }
}
