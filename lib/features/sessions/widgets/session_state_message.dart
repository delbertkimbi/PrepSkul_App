import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

/// User-friendly state message widget
/// Displays non-technical messages about session state
/// Auto-dismisses after 3 seconds
class SessionStateMessage extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final Duration duration;

  const SessionStateMessage({
    Key? key,
    required this.message,
    required this.icon,
    this.color = Colors.blue,
    this.duration = const Duration(seconds: 3),
  }) : super(key: key);

  @override
  State<SessionStateMessage> createState() => _SessionStateMessageState();
}

class _SessionStateMessageState extends State<SessionStateMessage>
    with SingleTickerProviderStateMixin {
  Timer? _dismissTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    // Auto-dismiss after duration
    _dismissTimer = Timer(widget.duration, () {
      if (mounted) {
        _animationController.reverse().then((_) {
          if (mounted) {
            // Widget will be removed by parent
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                widget.message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper class to create common state messages
class SessionStateMessages {
  static Widget tutorMicMuted() {
    return SessionStateMessage(
      message: "Tutor's mic is muted",
      icon: Icons.mic_off,
      color: Colors.orange,
    );
  }

  static Widget learnerMicMuted() {
    return SessionStateMessage(
      message: "Learner's mic is muted",
      icon: Icons.mic_off,
      color: Colors.orange,
    );
  }

  static Widget tutorCameraOff() {
    return SessionStateMessage(
      message: "Tutor's camera is off",
      icon: Icons.videocam_off,
      color: Colors.orange,
    );
  }

  static Widget learnerCameraOff() {
    return SessionStateMessage(
      message: "Learner's camera is off",
      icon: Icons.videocam_off,
      color: Colors.orange,
    );
  }

  static Widget tutorLeft() {
    return SessionStateMessage(
      message: "Tutor left the call",
      icon: Icons.person_off,
      color: Colors.red,
      duration: const Duration(seconds: 5),
    );
  }

  static Widget learnerLeft() {
    return SessionStateMessage(
      message: "Learner left the call",
      icon: Icons.person_off,
      color: Colors.red,
      duration: const Duration(seconds: 5),
    );
  }

  static Widget connecting() {
    return SessionStateMessage(
      message: "Connecting to session...",
      icon: Icons.wifi,
      color: Colors.blue,
    );
  }

  static Widget waitingForTutor() {
    return SessionStateMessage(
      message: "Waiting for tutor to join...",
      icon: Icons.hourglass_empty,
      color: Colors.blue,
    );
  }

  static Widget waitingForLearner() {
    return SessionStateMessage(
      message: "Waiting for learner to join...",
      icon: Icons.hourglass_empty,
      color: Colors.blue,
    );
  }
}

