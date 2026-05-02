import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/domain/classroom_orchestrator.dart';
import 'package:prepskul/features/sessions/rtc/agora_adapter.dart';

void main() {
  group('ClassroomOrchestrator reducer', () {
    test('starts at idle', () {
      final orchestrator = ClassroomOrchestrator();
      expect(orchestrator.state.lifecycle, ClassroomLifecycleState.idle);
    });

    test('supports deterministic command-driven transitions', () {
      final orchestrator = ClassroomOrchestrator();

      expect(
        orchestrator.dispatch(const StartJoinFlow()).lifecycle,
        ClassroomLifecycleState.joining,
      );
      expect(
        orchestrator.dispatch(const MarkConnected()).lifecycle,
        ClassroomLifecycleState.connected,
      );
      expect(
        orchestrator.dispatch(const MarkNetworkDegraded()).lifecycle,
        ClassroomLifecycleState.degraded,
      );
      expect(
        orchestrator.dispatch(const MarkReconnecting()).lifecycle,
        ClassroomLifecycleState.reconnecting,
      );
      expect(
        orchestrator.dispatch(const MarkResumed()).lifecycle,
        ClassroomLifecycleState.resumed,
      );
      expect(
        orchestrator.dispatch(const StartEndingFlow()).lifecycle,
        ClassroomLifecycleState.ending,
      );
      expect(
        orchestrator.dispatch(const MarkEnded()).lifecycle,
        ClassroomLifecycleState.ended,
      );
    });

    test('maps rtc events to lifecycle updates', () {
      final orchestrator = ClassroomOrchestrator();

      orchestrator.onRtcEvent(const RtcJoinSuccess(uid: 1, channelId: 'abc'));
      expect(orchestrator.state.lifecycle, ClassroomLifecycleState.connected);

      orchestrator.onRtcEvent(
        const RtcConnectionStateChanged(ConnectionStateType.connectionStateReconnecting),
      );
      expect(orchestrator.state.lifecycle, ClassroomLifecycleState.reconnecting);

      orchestrator.onRtcEvent(
        const RtcConnectionStateChanged(ConnectionStateType.connectionStateConnected),
      );
      expect(orchestrator.state.lifecycle, ClassroomLifecycleState.resumed);

      orchestrator.onRtcEvent(const RtcErrorEvent('network-failure'));
      expect(orchestrator.state.lifecycle, ClassroomLifecycleState.failed);
      expect(orchestrator.state.lastError, 'network-failure');
    });
  });
}

