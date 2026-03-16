import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/sessions/models/agora_session_state.dart';

/// Centralized call status banner used across video session layouts.
///
/// This widget is intentionally dumb: it renders a single, harmonized banner
/// based on high-level flags computed by the screen.
class CallStatusBanner extends StatelessWidget {
  final AgoraSessionState sessionState;
  final bool remoteConnectionUnstable;
  final bool localReconnecting;
  final bool remoteUserLeft;
  final bool isAloneWaiting;
  final Duration? timeRemaining;

  const CallStatusBanner({
    Key? key,
    required this.sessionState,
    required this.remoteConnectionUnstable,
    required this.localReconnecting,
    required this.remoteUserLeft,
    required this.isAloneWaiting,
    this.timeRemaining,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!sessionState.isActive) {
      return const SizedBox.shrink();
    }

    String? label;
    Color? pillColor;

    if (remoteUserLeft) {
      label = 'Participant left the call';
      pillColor = Colors.red.shade700;
    } else if (localReconnecting) {
      label = 'Reconnecting…';
      pillColor = Colors.orange.shade700;
    } else if (remoteConnectionUnstable) {
      label = 'Connection is unstable';
      pillColor = Colors.orange.shade700;
    } else if (isAloneWaiting) {
      label = 'Waiting for other participant…';
      pillColor = Colors.blueGrey.shade700;
    } else {
      label = 'Connected';
      pillColor = AppTheme.accentGreen;
    }

    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.55),
            Colors.black.withOpacity(0.2),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              if (timeRemaining != null) ...[
                const SizedBox(width: 12),
                _TimerChip(timeRemaining: timeRemaining!),
              ],
            ],
          ),
        ],
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
    final text = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

