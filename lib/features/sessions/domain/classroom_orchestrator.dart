import 'dart:async';

import 'package:prepskul/features/sessions/rtc/agora_adapter.dart';

enum ClassroomLifecycleState {
  idle,
  prejoinCheck,
  joining,
  connected,
  degraded,
  reconnecting,
  resumed,
  ending,
  ended,
  failed,
}

class ClassroomState {
  const ClassroomState({
    required this.lifecycle,
    this.lastError,
  });

  final ClassroomLifecycleState lifecycle;
  final String? lastError;

  ClassroomState copyWith({
    ClassroomLifecycleState? lifecycle,
    String? lastError,
  }) {
    return ClassroomState(
      lifecycle: lifecycle ?? this.lifecycle,
      lastError: lastError ?? this.lastError,
    );
  }
}

abstract class ClassroomCommand {
  const ClassroomCommand();
}

class StartJoinFlow extends ClassroomCommand {
  const StartJoinFlow();
}

class MarkConnected extends ClassroomCommand {
  const MarkConnected();
}

class MarkNetworkDegraded extends ClassroomCommand {
  const MarkNetworkDegraded();
}

class MarkReconnecting extends ClassroomCommand {
  const MarkReconnecting();
}

class MarkResumed extends ClassroomCommand {
  const MarkResumed();
}

class StartEndingFlow extends ClassroomCommand {
  const StartEndingFlow();
}

class MarkEnded extends ClassroomCommand {
  const MarkEnded();
}

class MarkFailed extends ClassroomCommand {
  const MarkFailed(this.error);
  final String error;
}

/// Deterministic reducer-style orchestrator for classroom lifecycle state.
class ClassroomOrchestrator {
  ClassroomOrchestrator() : _state = const ClassroomState(lifecycle: ClassroomLifecycleState.idle);

  final StreamController<ClassroomState> _stateController =
      StreamController<ClassroomState>.broadcast();

  ClassroomState _state;
  ClassroomState get state => _state;
  Stream<ClassroomState> get stateStream => _stateController.stream;

  ClassroomState dispatch(ClassroomCommand command) {
    _state = _reduce(_state, command);
    _stateController.add(_state);
    return _state;
  }

  /// Maps normalized RTC events to lifecycle transitions.
  ClassroomState onRtcEvent(RtcEvent event) {
    if (event is RtcJoinSuccess) {
      return dispatch(const MarkConnected());
    }
    if (event is RtcConnectionStateChanged) {
      final s = event.state.name.toLowerCase();
      if (s.contains('reconnect')) {
        return dispatch(const MarkReconnecting());
      }
      if (s.contains('connected')) {
        return dispatch(const MarkResumed());
      }
    }
    if (event is RtcErrorEvent) {
      return dispatch(MarkFailed(event.message));
    }
    return _state;
  }

  ClassroomState _reduce(ClassroomState current, ClassroomCommand command) {
    if (command is StartJoinFlow) {
      return current.copyWith(lifecycle: ClassroomLifecycleState.joining);
    }
    if (command is MarkConnected) {
      return current.copyWith(lifecycle: ClassroomLifecycleState.connected);
    }
    if (command is MarkNetworkDegraded) {
      return current.copyWith(lifecycle: ClassroomLifecycleState.degraded);
    }
    if (command is MarkReconnecting) {
      return current.copyWith(lifecycle: ClassroomLifecycleState.reconnecting);
    }
    if (command is MarkResumed) {
      return current.copyWith(lifecycle: ClassroomLifecycleState.resumed);
    }
    if (command is StartEndingFlow) {
      return current.copyWith(lifecycle: ClassroomLifecycleState.ending);
    }
    if (command is MarkEnded) {
      return current.copyWith(lifecycle: ClassroomLifecycleState.ended);
    }
    if (command is MarkFailed) {
      return current.copyWith(
        lifecycle: ClassroomLifecycleState.failed,
        lastError: command.error,
      );
    }
    return current;
  }

  Future<void> dispose() async {
    await _stateController.close();
  }
}

