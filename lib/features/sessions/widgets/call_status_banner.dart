import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/sessions/models/agora_session_state.dart';

/// Minimal top status for active calls: timer-first, no “Connected” noise.
/// Transient reconnect/jitter is silent; [showSustainedDegradation] is only set
/// by the screen after issues persist (see agora video session).
class CallStatusBanner extends StatelessWidget {
  final AgoraSessionState sessionState;
  final bool showSustainedDegradation;
  final bool remoteUserLeft;
  final bool isAloneWaiting;
  final Duration? timeRemaining;

  const CallStatusBanner({
    Key? key,
    required this.sessionState,
    required this.showSustainedDegradation,
    required this.remoteUserLeft,
    required this.isAloneWaiting,
    this.timeRemaining,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!sessionState.isActive) {
      return const SizedBox.shrink();
    }

    String? statusText;
    Color? statusColor;

    if (remoteUserLeft) {
      statusText = 'Participant left';
      statusColor = AppTheme.error;
    } else if (isAloneWaiting) {
      statusText = 'Waiting…';
      statusColor = AppTheme.primaryColor;
    } else if (showSustainedDegradation) {
      statusText = 'Reconnecting…';
      statusColor = AppTheme.softYellow;
    }

    final showTimer = timeRemaining != null;

    if (statusText == null && !showTimer) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Container(
        key: ValueKey<String>(
          '${statusText ?? 't'}_${showTimer}_${timeRemaining?.inSeconds ?? 0}',
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.45),
              Colors.black.withOpacity(0.1),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (statusText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              const Spacer(),
              if (showTimer) _TimerChip(timeRemaining: timeRemaining!),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  final Duration timeRemaining;

  const _TimerChip({Key? key, required this.timeRemaining}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final minutes = timeRemaining.inMinutes;
    final seconds = timeRemaining.inSeconds.remainder(60);
    final text =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}
