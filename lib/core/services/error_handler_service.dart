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

    // Trial session errors - check these FIRST before generic conflict errors
    // This ensures specific trial session messages are preserved
    if (errorString.contains('trial session') ||
        errorString.contains('already have a pending') ||
        errorString.contains('already have an approved') ||
        errorString.contains('already have a scheduled') ||
        errorString.contains('already have an active trial')) {
      final match = RegExp(r'Exception: (.+)').firstMatch(error.toString());
      if (match != null) {
        final message = match.group(1)!;
        if (!message.toLowerCase().contains('exception') &&
            !message.toLowerCase().contains('error code')) {
          return message;
        }
      }
      // Fallback message
      if (errorString.contains('this tutor')) {
        return 'You already have an active trial session with this tutor. Please complete it before creating a regular booking.';
      }
      return 'You already have an active trial session. Please complete it before creating a regular booking.';
    }

    // Schedule conflict errors (time slot conflicts with other tutors)
    if (errorString.contains('schedule conflict') ||
        errorString.contains('conflict')) {
      final match = RegExp(r'Schedule Conflict: (.+)', caseSensitive: false)
          .firstMatch(error.toString());
      if (match != null) {
        return match.group(1) ?? defaultMsg;
      }
      // Check if it's a time conflict with another tutor
      if (errorString.contains('another tutor') || 
          errorString.contains('same time')) {
        return 'You already have a session scheduled at the same time with another tutor. Please choose a different time slot.';
      }
      return 'You have a scheduling conflict. Please choose a different time.';
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
      if (errorString.contains('phone') && (errorString.contains('valid') || 
          errorString.contains('mtn') || errorString.contains('orange'))) {
        return 'Please enter a valid phone number.\n\nFormat: 67XXXXXXX (MTN) or 69XXXXXXX (Orange)\n\nExample: 670000000 or 690000000';
      }
    }

    // File upload errors
    if (errorString.contains('file') || errorString.contains('upload')) {
      if (errorString.contains('too large') || errorString.contains('size')) {
        return 'File is too large. Please choose a smaller file (max 10MB).';
      }
      if (errorString.contains('format') || errorString.contains('type') ||
          errorString.contains('not supported')) {
        return 'File format not supported. Please use PDF, JPG, or PNG.';
      }
      if (errorString.contains('failed to upload') || 
          errorString.contains('upload error')) {
        return 'Failed to upload file. Please check your connection and try again.';
      }
    }

    // API errors
    if (errorString.contains('api') || errorString.contains('server')) {
      if (errorString.contains('500') || errorString.contains('internal')) {
        return 'Server error. Our team has been notified. Please try again later.';
      }
      if (errorString.contains('503') || errorString.contains('unavailable')) {
        return 'Service temporarily unavailable. Please try again in a few moments.';
      }
      if (errorString.contains('429') || errorString.contains('rate limit')) {
        return 'Too many requests. Please wait a moment and try again.';
      }
      if (errorString.contains('404') || errorString.contains('not found')) {
        return 'The requested resource was not found. Please refresh and try again.';
      }
    }

    // Session errors
    if (errorString.contains('session')) {
      if (errorString.contains('not found') || errorString.contains('does not exist')) {
        return 'Session not found. It may have been cancelled or deleted.';
      }
      if (errorString.contains('already started') || errorString.contains('in progress')) {
        return 'This session has already started.';
      }
      if (errorString.contains('already ended') || errorString.contains('completed')) {
        return 'This session has already ended.';
      }
      if (errorString.contains('cannot start') || errorString.contains('cannot join')) {
        return 'You cannot start or join this session at this time.';
      }
    }

    // Game generation errors (skulMate)
    if (errorString.contains('game') || errorString.contains('generation') ||
        errorString.contains('skulmate')) {
      if (errorString.contains('failed to generate') || 
          errorString.contains('generation error')) {
        return 'Failed to generate game. Please check your document and try again.';
      }
      if (errorString.contains('api') && errorString.contains('down')) {
        return 'Game generation service is temporarily unavailable. Please try again later.';
      }
      if (errorString.contains('invalid') || errorString.contains('format')) {
        return 'Invalid document format. Please upload a PDF, image, or text file.';
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

  /// Check if an error is retryable (network, timeout, server errors)
  static bool isRetryable(dynamic error) {
    if (error == null) return false;
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('failed to fetch') ||
        errorString.contains('socketexception') ||
        errorString.contains('503') ||
        errorString.contains('unavailable') ||
        errorString.contains('429') ||
        errorString.contains('rate limit');
  }

  /// Show a standardized error dialog with optional retry
  static Future<void> showError(
    BuildContext context,
    dynamic error, [
    String? defaultMessage,
    VoidCallback? onRetry,
  ]) async {
    if (!context.mounted) return;

    final message = getUserMessage(error, defaultMessage);
    final canRetry = onRetry != null && isRetryable(error);
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
          if (canRetry)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: canRetry ? Colors.grey[700] : AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show a standardized error snackbar with optional retry
  static void showErrorSnackbar(
    BuildContext context,
    dynamic error, [
    String? defaultMessage,
    VoidCallback? onRetry,
  ]) {
    if (!context.mounted) return;

    final message = getUserMessage(error, defaultMessage);
    final canRetry = onRetry != null && isRetryable(error);
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
            if (canRetry)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onRetry();
                },
                child: Text(
                  'RETRY',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: canRetry ? 6 : 4),
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