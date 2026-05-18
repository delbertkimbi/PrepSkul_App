import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/services/session_mode_statistics_service.dart';

void main() {
  test('accumulates local and remote speaking time', () {
    final stats = SessionModeStatisticsService();
    final t0 = DateTime(2026, 1, 1, 10, 0, 0, 0, 0);

    stats.ingestVolumeSample(
      at: t0,
      speakers: const <AudioVolumeInfo>[
        AudioVolumeInfo(uid: 0, volume: 55),
      ],
      volumeThreshold: 25,
    );

    stats.ingestVolumeSample(
      at: t0.add(const Duration(seconds: 2)),
      speakers: const <AudioVolumeInfo>[
        AudioVolumeInfo(uid: 11, volume: 60),
      ],
      volumeThreshold: 25,
    );

    final snapshot = stats.snapshot(at: t0.add(const Duration(seconds: 5)));
    expect(snapshot.localMs, greaterThanOrEqualTo(1900));
    expect(snapshot.remoteMs, greaterThanOrEqualTo(2900));
    expect(snapshot.totalMs, greaterThan(0));
    expect(snapshot.samples, 2);
  });
}
