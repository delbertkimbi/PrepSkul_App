import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/primar/presentation/mascot.dart';

enum SkulMateMascotState { neutral, thinking, encouraging, celebration }

/// Cartoon Mate — same egg rig as onboarding.
/// Photoreal PNG/mp4 clips are not used; they read as still photos.
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
    this.showFrame = true,
    this.frameBackgroundColor = AppTheme.neutral100,
  });

  Mood get _mood => switch (state) {
        SkulMateMascotState.neutral => Mood.idle,
        SkulMateMascotState.thinking => Mood.thinking,
        SkulMateMascotState.encouraging => Mood.encourage,
        SkulMateMascotState.celebration => Mood.cheer,
      };

  /// Call-site flags from the old video/PNG widget. Cartoon Mate always animates.
  bool get _legacyVideoFlags =>
      autoplay || loop || preferStaticImage || videoVolume >= 0 || frameBackgroundColor.alpha >= 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = width ??
            (constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 96.0);
        final maxH = height ??
            (constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 96.0);
        final size = math.min(maxW, maxH).clamp(28.0, _legacyVideoFlags ? 220.0 : 220.0);

        final mate = Mate(
          mood: _mood,
          size: size,
          ink: AppTheme.primaryColor,
          body: AppTheme.skyBlue,
          belly: AppTheme.skyBlueLight,
          accent: AppTheme.softYellow,
        );

        Widget child = SizedBox(
          width: width ?? (useLandscapeFrame ? null : size),
          height: height ?? (useLandscapeFrame ? null : size),
          child: Center(child: mate),
        );

        if (showFrame) {
          child = Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.skyBlueLight.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: AppTheme.softBorder.withValues(alpha: 0.6),
              ),
            ),
            child: mate,
          );
        }

        if (!useLandscapeFrame) return child;
        return AspectRatio(aspectRatio: 1, child: child);
      },
    );
  }
}
