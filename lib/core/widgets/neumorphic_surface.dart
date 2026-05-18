import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Shared soft neumorphic surfaces for booking, KYC, and payment flows.
class NeumorphicSurface {
  NeumorphicSurface._();

  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0xFFFFFFFF),
      offset: Offset(-3, -3),
      blurRadius: 8,
    ),
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(4, 4),
      blurRadius: 10,
    ),
  ];

  static const List<BoxShadow> inset = [
    BoxShadow(
      color: Color(0x12000000),
      offset: Offset(2, 2),
      blurRadius: 5,
    ),
    BoxShadow(
      color: Color(0xCCFFFFFF),
      offset: Offset(-2, -2),
      blurRadius: 5,
    ),
  ];

  static BoxDecoration card({
    Color? color,
    double radius = 18,
    bool border = true,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: raised,
      border: border
          ? Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.14),
            )
          : null,
    );
  }

  static Widget wrap({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? color,
    double radius = 18,
  }) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: card(color: color, radius: radius),
      child: child,
    );
  }
}
