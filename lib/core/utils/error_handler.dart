import 'package:supabase_flutter/supabase_flutter.dart';

/// Error Handler Utility
/// 
/// Provides user-friendly error messages, preserving messages from services
/// that already provide user-friendly content (like FapshiService)
class ErrorHandler {
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';
    
    final errorString = error.toString();
    final lowerError = errorString.toLowerCase();
    
    // If error already contains user-friendly guidance (from FapshiService, etc.),
    // preserve it by extracting the message after "Exception: "
    if (errorString.contains('Exception: ')) {
      final message = errorString.split('Exception: ').last.trim();
      // Check if it's already user-friendly (contains helpful guidance, not technical jargon)
      final isUserFriendly = message.contains('Please') || 
                            message.contains('check') ||
                            message.contains('try again') ||
                            message.contains('contact') ||
                            (!message.contains('error code') && 
                             !message.contains('statuscode') &&
                             !message.contains('pgrst') &&
                             !message.contains('exception'));
      
      if (isUserFriendly && message.length < 300) {
        return message;
      }
    }
    
    // Network errors
    if (lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('failed to fetch') ||
        lowerError.contains('timeout')) {
      return 'Connection issue detected. Please check your internet connection and try again.';
    }
    
    // Authentication errors
    if (lowerError.contains('authentication') || 
        lowerError.contains('session expired') ||
        lowerError.contains('unauthorized')) {
      return 'Your session has expired. Please sign in again to continue.';
    }
    
    // Database errors
    if (error is PostgrestException) {
      return 'We\'re having trouble processing your request. Please try again in a moment.';
    }
    
    // Default user-friendly message
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
