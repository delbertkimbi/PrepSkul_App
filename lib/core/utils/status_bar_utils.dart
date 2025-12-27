import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utility class for managing status bar appearance
class StatusBarUtils {
  /// Wraps a widget with light status bar (dark icons on light background)
  static Widget withLightStatusBar(Widget child) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: child,
    );
  }

  /// Wraps a widget with dark status bar (light icons on dark background)
  static Widget withDarkStatusBar(Widget child) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: child,
    );
  }
}

