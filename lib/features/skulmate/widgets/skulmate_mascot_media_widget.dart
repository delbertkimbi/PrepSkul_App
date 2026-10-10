import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prepskul/core/widgets/alive_mate.dart';

enum SkulMateMascotState {
  neutral,
  thinking,
  encouraging,
  celebration,
  speaking,
  listening,
  success,
  tryAgain,
  idea,
  reading,
  teaching,
}

MascotState? poseForMascotState(SkulMateMascotState state) => switch (state) {
  SkulMateMascotState.neutral => MascotState.idle,
  SkulMateMascotState.thinking => MascotState.thinking,
  SkulMateMascotState.encouraging => MascotState.encourage,
  SkulMateMascotState.celebration => MascotState.celebrate,
  SkulMateMascotState.speaking => null,
  SkulMateMascotState.listening => MascotState.listening,
  SkulMateMascotState.success => MascotState.success,
  SkulMateMascotState.tryAgain => MascotState.tryAgain,
  SkulMateMascotState.idea => MascotState.idea,
  SkulMateMascotState.reading => MascotState.reading,
  SkulMateMascotState.teaching => MascotState.teaching,
};

Mood moodForMascotState(SkulMateMascotState state) {
  return switch (state) {
    SkulMateMascotState.neutral => Mood.idle,
    SkulMateMascotState.thinking => Mood.thinking,
    SkulMateMascotState.encouraging => Mood.encourage,
    SkulMateMascotState.celebration => Mood.cheer,
    SkulMateMascotState.speaking => Mood.talk,
    _ => Mood.idle,
  };
}

/// Shared PrepSkul Mate art for every SkulMate state. Mood changes are drawn
/// by the same vector rig used on the website, in onboarding, and in Primar.
/// Legacy video options remain accepted so existing call sites stay compatible.
class SkulMateMascotMediaWidget extends StatelessWidget {
  final SkulMateMascotState state;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool autoplay;
  final bool loop;
  final bool useLandscapeFrame;
  final double videoVolume;
  final bool preferStaticImage;
  final bool showFrame;
  final Color frameBackgroundColor;

  const SkulMateMascotMediaWidget({
    super.key,
    required this.state,
    this.width,
    this.height,
    this.borderRadius = 16,
    this.autoplay = true,
    this.loop = false,
    this.useLandscapeFrame = false,
    this.videoVolume = 0.0,
    this.preferStaticImage = false,
    this.showFrame = false,
    this.frameBackgroundColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    final boxWidth = width ?? height ?? 96;
    final boxHeight = height ?? width ?? 96;
    final mateSize = math.min(boxWidth, boxHeight) * 0.82;
    Widget content = SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: Center(
        child: AliveMate(
          mood: moodForMascotState(state),
          state: poseForMascotState(state),
          size: mateSize,
        ),
      ),
    );

    if (useLandscapeFrame) {
      content = AspectRatio(aspectRatio: 16 / 9, child: content);
    }
    if (!showFrame) return content;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: frameBackgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: content,
    );
  }
}
