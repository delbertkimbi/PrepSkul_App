import 'package:flutter/material.dart';
import 'mascot_state.dart';
export 'mascot_state.dart';
import 'mascot_view.dart';
import 'package:prepskul/features/primar/presentation/mascot.dart';

export 'package:prepskul/features/primar/presentation/mascot.dart'
    show Mate, Mood;

/// Shared Blender character with context-specific clips and accessible motion.
class AliveMate extends StatelessWidget {
  const AliveMate({
    super.key,
    required this.mood,
    this.size = 96,
    this.flip = false,
    this.state,
  });

  final Mood mood;
  final MascotState? state;
  final double size;
  final bool flip;

  /// Shared PrepSkul site palette. Keep app Mate identical to the website.
  @override
  Widget build(BuildContext context) {
    final pose =
        state ??
        switch (mood) {
          Mood.wave => MascotState.wave,
          Mood.encourage => MascotState.encourage,
          Mood.talk => MascotState.teaching,
          Mood.thinking => MascotState.thinking,
          Mood.happy => MascotState.happy,
          Mood.cheer => MascotState.celebrate,
          Mood.point => MascotState.pointing,
          _ => MascotState.idle,
        };
    final clip = mood == Mood.talk && state == null
        ? '33_talk'
        : switch (pose) {
            MascotState.idle => '01_idle',
            MascotState.wave => '02_wave',
            MascotState.happy => '03_happy',
            MascotState.thumbsUp => '04_thumbs_up',
            MascotState.celebrate => '06_celebrate',
            MascotState.thinking => '09_thinking',
            MascotState.confused => '10_confused',
            MascotState.idea => '11_idea',
            MascotState.reading => '12_reading',
            MascotState.studying => '13_studying',
            MascotState.success => '17_success',
            MascotState.tryAgain => '18_try_again',
            MascotState.encourage => '19_encourage',
            MascotState.pointing => '20_pointing',
            MascotState.teaching => '21_explaining',
            MascotState.sad => '25_sad',
            MascotState.sleeping => '27_sleeping',
            MascotState.graduation => '29_graduation',
            MascotState.calm => '30_meditation',
            MascotState.running => '31_running',
            MascotState.listening => '16_listening',
          };
    return Transform.flip(
      flipX: flip,
      child: MascotView(clip: clip, size: size),
    );
  }
}
