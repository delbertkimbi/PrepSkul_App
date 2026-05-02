import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class ReconnectGraceDecision {
  const ReconnectGraceDecision({
    required this.confirmLeaveImmediately,
    required this.graceDuration,
  });

  final bool confirmLeaveImmediately;
  final Duration graceDuration;
}

/// Central policy for transient disconnect vs definitive leave handling.
class ReconnectGracePolicy {
  const ReconnectGracePolicy({
    this.defaultGrace = const Duration(seconds: 15),
    this.webQuitGrace = const Duration(seconds: 12),
  });

  final Duration defaultGrace;
  final Duration webQuitGrace;

  ReconnectGraceDecision onUserOffline({
    required UserOfflineReasonType reason,
    required bool isWeb,
  }) {
    switch (reason) {
      case UserOfflineReasonType.userOfflineBecomeAudience:
        return const ReconnectGraceDecision(
          confirmLeaveImmediately: true,
          graceDuration: Duration.zero,
        );
      case UserOfflineReasonType.userOfflineQuit:
        if (isWeb) {
          return ReconnectGraceDecision(
            confirmLeaveImmediately: false,
            graceDuration: webQuitGrace,
          );
        }
        return const ReconnectGraceDecision(
          confirmLeaveImmediately: true,
          graceDuration: Duration.zero,
        );
      case UserOfflineReasonType.userOfflineDropped:
      default:
        return ReconnectGraceDecision(
          confirmLeaveImmediately: false,
          graceDuration: defaultGrace,
        );
    }
  }
}

