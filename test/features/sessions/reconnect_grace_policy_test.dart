import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/domain/reconnect_grace_policy.dart';

void main() {
  group('ReconnectGracePolicy', () {
    const policy = ReconnectGracePolicy();

    test('confirms leave immediately for become-audience', () {
      final d = policy.onUserOffline(
        reason: UserOfflineReasonType.userOfflineBecomeAudience,
        isWeb: false,
      );
      expect(d.confirmLeaveImmediately, isTrue);
      expect(d.graceDuration, Duration.zero);
    });

    test('web quit uses grace window (transient-safe)', () {
      final d = policy.onUserOffline(
        reason: UserOfflineReasonType.userOfflineQuit,
        isWeb: true,
      );
      expect(d.confirmLeaveImmediately, isFalse);
      expect(d.graceDuration.inSeconds, greaterThan(0));
    });

    test('non-web quit confirms immediately', () {
      final d = policy.onUserOffline(
        reason: UserOfflineReasonType.userOfflineQuit,
        isWeb: false,
      );
      expect(d.confirmLeaveImmediately, isTrue);
      expect(d.graceDuration, Duration.zero);
    });

    test('dropped uses grace window', () {
      final d = policy.onUserOffline(
        reason: UserOfflineReasonType.userOfflineDropped,
        isWeb: false,
      );
      expect(d.confirmLeaveImmediately, isFalse);
      expect(d.graceDuration.inSeconds, greaterThan(0));
    });
  });
}

