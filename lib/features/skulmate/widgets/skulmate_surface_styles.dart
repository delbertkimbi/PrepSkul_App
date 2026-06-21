import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Shared SkulMate home card surfaces.
class SkulMateSurfaceStyles {
  SkulMateSurfaceStyles._();

  static const double pillRadius = 999;
  static const double intentCardRadius = 20;
  static const double sectionGap = 20;

  static List<BoxShadow> _softShadow({bool compact = false}) => [
        BoxShadow(
          color: AppTheme.textDark.withValues(alpha: compact ? 0.04 : 0.05),
          blurRadius: compact ? 4 : 6,
          offset: Offset(0, compact ? 1 : 2),
        ),
      ];

  /// Standard card — white, hairline border, gentle lift (matches game cards).
  static BoxDecoration homeCard({
    double radius = 14,
    bool compact = false,
  }) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppTheme.softBorder.withValues(alpha: 0.9),
      ),
      boxShadow: _softShadow(compact: compact),
    );
  }

  /// Import tool chips — same border/shadow as game cards, compact lift.
  static BoxDecoration chipCard({double radius = pillRadius}) =>
      homeCard(radius: radius, compact: true);

  static BoxDecoration neumorphicCard({
    Color? color,
    double radius = 14,
    bool compact = false,
  }) =>
      homeCard(radius: radius, compact: compact);

  static Color get surfaceFill => AppTheme.surfaceColor;

  static List<BoxShadow> neumorphicSoft() => _softShadow();

  static List<BoxShadow> homeCardShadow({bool compact = false}) =>
      _softShadow(compact: compact);

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
    );
  }

  /// Soft blue wash for credits / plans screens.
  static BoxDecoration softScreenGradient() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.primaryColor.withValues(alpha: 0.07),
          AppTheme.softBackground,
          AppTheme.softBackground,
        ],
        stops: const [0.0, 0.35, 1.0],
      ),
    );
  }

  /// Plan card — accent fades top & bottom, white center.
  static BoxDecoration planCardGradient({
    required Color accent,
    double radius = 14,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0.14),
          Colors.white,
          Colors.white,
          accent.withValues(alpha: 0.1),
        ],
        stops: const [0.0, 0.38, 0.62, 1.0],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: 0.35)),
      boxShadow: homeCardShadow(),
    );
  }

  static BoxDecoration softStatusCard({double radius = 14}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppTheme.primaryColor.withValues(alpha: 0.12),
      ),
      boxShadow: homeCardShadow(),
    );
  }

  static BoxDecoration heroNeumorphic({
    double radius = 22,
    List<Color>? colors,
  }) =>
      heroGradient(radius: radius, colors: colors);

  static List<BoxShadow> appBarSoftLift() => _softShadow(compact: true);

  static SystemUiOverlayStyle get lightStatusBarOverlay =>
      const SystemUiOverlayStyle(
        statusBarColor: AppTheme.softBackground,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.softBackground,
        systemNavigationBarIconBrightness: Brightness.dark,
      );

  /// PrepSkul blue pill primary button for bottom sheets.
  static ButtonStyle sheetPrimaryButton({bool enabled = true}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppTheme.neutral200,
      disabledForegroundColor: AppTheme.textMedium,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(pillRadius),
      ),
    );
  }

  static ButtonStyle sheetSecondaryButton() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppTheme.textDark,
      side: BorderSide(color: AppTheme.softBorder.withValues(alpha: 0.95)),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(pillRadius),
      ),
    );
  }
}
