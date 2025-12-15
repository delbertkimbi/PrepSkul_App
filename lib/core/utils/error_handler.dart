import 'package:supabase_flutter/supabase_flutter.dart';

/// Error Handler Utility
class ErrorHandler {
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('failed to fetch')) {
      return 'Network error: Please check your internet connection and try again.';
    }
    if (errorString.contains('authentication') || errorString.contains('session expired')) {
      return 'Your session has expired. Please sign in again to continue.';
    }
    if (error is PostgrestException) {
      return 'Database error: Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
  
  static String getErrorTitle(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('network')) return 'Connection Error';
    if (errorString.contains('payment')) return 'Payment Error';
    return 'Error';
  }
  
  static bool isRetryable(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') || errorString.contains('timeout');
  }
}
