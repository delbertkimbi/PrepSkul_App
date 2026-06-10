import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Shared SkulMate surfaces: weekly-hero gradient, soft neumorphic cards, app bar.
class SkulMateSurfaceStyles {
  SkulMateSurfaceStyles._();

  /// Same gradient language as the leaderboard weekly hero (multi-stop blue).
  static BoxDecoration heroGradient({
    double radius = 22,
    List<Color>? colors,
  }) {
    final c = colors ??
        <Color>[
          AppTheme.primaryDark,
          AppTheme.primaryColor,
          AppTheme.primaryLight.withValues(alpha: 0.95),
        ];
    return BoxDecoration(
      gradient: LinearGradient(
        colors: c,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: AppTheme.primaryColor.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Hero strip with neumorphic lift (no heavy drop shadow).
  static BoxDecoration heroNeumorphic({
    double radius = 22,
    List<Color>? colors,
  }) {
    final c = colors ??
        <Color>[
          AppTheme.primaryDark,
          AppTheme.primaryColor,
          AppTheme.primaryLight.withValues(alpha: 0.95),
        ];
    return BoxDecoration(
      gradient: LinearGradient(
        colors: c,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: neumorphicSoft(),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    );
  }

  static List<BoxShadow> neumorphicSoft() => [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.95),
          blurRadius: 8,
          offset: const Offset(-4, -4),
        ),
        BoxShadow(
          color: AppTheme.textDark.withValues(alpha: 0.07),
          blurRadius: 14,
          offset: const Offset(6, 6),
        ),
      ];

  static BoxDecoration neumorphicCard({
    Color? color,
    double radius = 16,
    bool border = true,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: neumorphicSoft(),
      border: border
          ? Border.all(
              color: AppTheme.softBorder.withValues(alpha: 0.55),
            )
          : null,
    );
  }

  /// Subtle strip under the SkulMate dashboard app bar.
  static List<BoxShadow> appBarSoftLift() => [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.85),
          blurRadius: 4,
          offset: const Offset(0, -1),
        ),
        BoxShadow(
          color: AppTheme.textDark.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}
