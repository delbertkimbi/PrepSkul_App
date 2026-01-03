import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status Bar Utils
///
/// Utility class for managing status bar appearance
class StatusBarUtils {
  /// Wrap widget with light status bar (dark text on light background)
  static Widget withLightStatusBar(Widget child) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: child,
    );
  }

  /// Wrap widget with dark status bar (light text on dark background)
  static Widget withDarkStatusBar(Widget child) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: child,
    );
  }
}
