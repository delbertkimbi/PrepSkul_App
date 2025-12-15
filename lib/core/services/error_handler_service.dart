import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Centralized error handling service
/// 
/// Provides consistent error message formatting and user-friendly error dialogs.
/// Replaces duplicate error handling patterns throughout the codebase.
/// 
/// Usage:
/// ```dart
/// import 'package:prepskul/core/services/error_handler_service.dart';
/// 
/// try {
///   await someOperation();
/// } catch (e) {
///   ErrorHandlerService.showError(context, e, 'Failed to perform operation');
/// }
/// ```
class ErrorHandlerService {
  /// Get a user-friendly error message from an exception
  static String getUserMessage(dynamic error, [String? defaultMessage]) {
    if (error == null) {
      return defaultMessage ?? 'An unexpected error occurred. Please try again.';
    }

    final errorString = error.toString().toLowerCase();
    final defaultMsg = defaultMessage ?? 'Something went wrong. Please try again.';

    // Network errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('failed to fetch') ||
        errorString.contains('socketexception') ||
        errorString.contains('timeout')) {
      return 'Network error. Please check your internet connection and try again.';
    }

    // Authentication errors
    if (errorString.contains('not authenticated') ||
        errorString.contains('unauthorized') ||
        errorString.contains('invalid login') ||
        errorString.contains('session expired')) {
      return 'You are not logged in. Please sign in and try again.';
    }

    // Database constraint errors
    if (errorString.contains('constraint') ||
        errorString.contains('duplicate key') ||
        errorString.contains('unique constraint')) {
      if (errorString.contains('email') || errorString.contains('user')) {
        return 'This email is already registered. Please sign in instead.';
      }
      return 'This record already exists. Please refresh and try again.';
    }

    // Schedule conflict errors
    if (errorString.contains('schedule conflict') ||
        errorString.contains('already have') ||
        errorString.contains('conflict')) {
      final match = RegExp(r'Schedule Conflict: (.+)', caseSensitive: false)
          .firstMatch(error.toString());
      if (match != null) {
        return match.group(1) ?? defaultMsg;
      }
      return 'You have a scheduling conflict. Please choose a different time.';
    }

    // Trial session errors
    if (errorString.contains('trial session') ||
        errorString.contains('already have a pending') ||
        errorString.contains('already have an approved')) {
      final match = RegExp(r'Exception: (.+)').firstMatch(error.toString());
      if (match != null) {
        final message = match.group(1)!;
        if (!message.toLowerCase().contains('exception') &&
            !message.toLowerCase().contains('error code')) {
          return message;
        }
      }
      return 'You already have an active trial session with this tutor.';
    }

    // Payment errors
    if (errorString.contains('payment') || errorString.contains('fapshi')) {
      if (errorString.contains('failed') || errorString.contains('error')) {
        return 'Payment failed. Please check your payment method and try again.';
      }
      if (errorString.contains('already completed') ||
          errorString.contains('already paid')) {
        return 'This payment has already been completed.';
      }
    }

    // Try to extract friendly message from Exception format
    if (errorString.startsWith('exception: ')) {
      final message = error.toString().substring(11).trim();
      final lowerMessage = message.toLowerCase();
      final isTechnical = lowerMessage.contains('exception') ||
          lowerMessage.contains('error code') ||
          lowerMessage.contains('statuscode') ||
          lowerMessage.contains('pgrst');

      if (!isTechnical && message.length < 200) {
        return message;
      }
    }

    return defaultMsg;
  }

  /// Show a standardized error dialog
  static Future<void> showError(
    BuildContext context,
    dynamic error, [
    String? defaultMessage,
  ]) async {
    if (!context.mounted) return;

    final message = getUserMessage(error, defaultMessage);
    LogService.error('Showing error to user', error);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Error',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show a standardized error snackbar
  static void showErrorSnackbar(
    BuildContext context,
    dynamic error, [
    String? defaultMessage,
  ]) {
    if (!context.mounted) return;

    final message = getUserMessage(error, defaultMessage);
    LogService.error('Showing error snackbar', error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show a success message
  static void showSuccess(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
