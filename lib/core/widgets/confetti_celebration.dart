import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

/// Confetti Celebration Widget
///
/// A reusable widget that displays confetti animation for celebrations
/// Use this for onboarding completions, survey completions, profile completions, etc.
class ConfettiCelebration extends StatefulWidget {
  /// The child widget to display
  final Widget child;

  /// Whether to start the confetti animation immediately
  final bool autoStart;

  /// Duration of the confetti animation
  final Duration duration;

  /// Number of confetti particles
  final int particleCount;

  /// Colors for the confetti particles
  final List<Color> colors;

  const ConfettiCelebration({
    Key? key,
    required this.child,
    this.autoStart = true,
    this.duration = const Duration(seconds: 3),
    this.particleCount = 50,
    this.colors = const [
      Colors.green,
      Colors.blue,
      Colors.pink,
      Colors.orange,
      Colors.purple,
    ],
  }) : super(key: key);

  @override
  State<ConfettiCelebration> createState() => _ConfettiCelebrationState();
}

class _ConfettiCelebrationState extends State<ConfettiCelebration> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: widget.duration);

    if (widget.autoStart) {
      // Start confetti after widget is built and a short delay for dialog animation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _controller.play();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Manually trigger confetti
  void play() {
    _controller.play();
  }

  /// Stop confetti
  void stop() {
    _controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Top confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirection: pi / 2, // Downward
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: widget.particleCount,
            gravity: 0.1,
            shouldLoop: false,
            colors: widget.colors,
          ),
        ),
        // Left confetti
        Align(
          alignment: Alignment.centerLeft,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirection: 0, // Rightward
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: widget.particleCount ~/ 2,
            gravity: 0.1,
            shouldLoop: false,
            colors: widget.colors,
          ),
        ),
        // Right confetti
        Align(
          alignment: Alignment.centerRight,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirection: pi, // Leftward
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: widget.particleCount ~/ 2,
            gravity: 0.1,
            shouldLoop: false,
            colors: widget.colors,
          ),
        ),
      ],
    );
  }
}

/// Helper function to show confetti celebration overlay
///
/// Wraps a widget with confetti celebration
Widget withConfettiCelebration({
  required Widget child,
  bool autoStart = true,
  Duration duration = const Duration(seconds: 3),
  int particleCount = 50,
  List<Color>? colors,
}) {
  return ConfettiCelebration(
    autoStart: autoStart,
    duration: duration,
    particleCount: particleCount,
    colors:
        colors ??
        const [
          Colors.green,
          Colors.blue,
          Colors.pink,
          Colors.orange,
          Colors.purple,
        ],
    child: child,
  );
}
