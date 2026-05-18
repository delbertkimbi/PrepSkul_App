import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/feedback/feedback_severity.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/branded_snackbar.dart';

/// Single entry point for transient PrepSkul toasts (and snackbars with actions).
///
/// Prefer this over ad-hoc [SnackBar] / [ScaffoldMessenger] so colors, margins,
/// and durations stay consistent. Blocking errors use [showPrepSkulAlert].
class AppFeedback {
  AppFeedback._();

  static const EdgeInsets _floatingMargin = EdgeInsets.all(16);

  static Duration _defaultDuration(FeedbackSeverity severity) {
    switch (severity) {
      case FeedbackSeverity.success:
      case FeedbackSeverity.info:
        return const Duration(seconds: 3);
      case FeedbackSeverity.warning:
        return const Duration(seconds: 4);
      case FeedbackSeverity.error:
        return const Duration(seconds: 5);
    }
  }

  static (Color background, IconData icon, Color iconColor) _toastStyle(
    FeedbackSeverity severity,
  ) {
    switch (severity) {
      case FeedbackSeverity.success:
        return (
          AppTheme.accentGreen,
          Icons.check_circle_rounded,
          Colors.white,
        );
      case FeedbackSeverity.info:
        return (
          AppTheme.primaryColor,
          Icons.info_outline_rounded,
          Colors.white,
        );
      case FeedbackSeverity.warning:
        return (
          AppTheme.warning,
          Icons.warning_amber_rounded,
          Colors.white,
        );
      case FeedbackSeverity.error:
        return (
          AppTheme.primaryDark,
          Icons.error_outline_rounded,
          Colors.white,
        );
    }
  }

  /// Non-blocking toast using branded floating snack bar styling.
  static void showToast(
    BuildContext context,
    FeedbackSeverity severity,
    String message, {
    Duration? duration,
  }) {
    if (!context.mounted) return;
    final (background, icon, iconColor) = _toastStyle(severity);
    BrandedSnackBar.show(
      context,
      message: message,
      backgroundColor: background,
      icon: icon,
      iconColor: iconColor,
      duration: duration ?? _defaultDuration(severity),
    );
  }

  static void showSuccess(BuildContext context, String message) =>
      showToast(context, FeedbackSeverity.success, message);

  static void showInfo(BuildContext context, String message) =>
      showToast(context, FeedbackSeverity.info, message);

  static void showWarning(BuildContext context, String message) =>
      showToast(context, FeedbackSeverity.warning, message);

  static void showErrorToast(BuildContext context, String message) =>
      showToast(context, FeedbackSeverity.error, message);

  /// Toast with optional inline action (e.g. retry) — same chrome as brand toasts.
  static void showToastWithAction(
    BuildContext context,
    FeedbackSeverity severity,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Duration? duration,
  }) {
    if (!context.mounted) return;
    final (background, icon, iconColor) = _toastStyle(severity);
    final totalDuration = duration ?? _defaultDuration(severity);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                onAction();
              },
              child: Text(
                actionLabel.toUpperCase(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        margin: _floatingMargin,
        duration: totalDuration,
      ),
    );
  }
}
