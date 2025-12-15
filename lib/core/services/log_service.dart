import 'package:flutter/foundation.dart';

/// Centralized logging service to replace print() statements
/// 
/// Provides structured logging with different levels and categories.
/// Debug messages are only shown in debug mode to reduce production noise.
/// 
/// Usage:
/// ```dart
/// import 'package:prepskul/core/services/log_service.dart';
/// 
/// LogService.debug('Debug message');
/// LogService.info('Info message');
/// LogService.warning('Warning message');
/// LogService.error('Error message', error);
/// LogService.success('Operation completed');
/// ```
class LogService {
  /// Log debug messages (only in debug mode)
  /// Use for detailed debugging information
  static void debug(String message, [Object? data]) {
    if (kDebugMode) {
      print('🐛 [DEBUG] $message${data != null ? ': $data' : ''}');
    }
  }

  /// Log informational messages
  /// Use for general information about app flow
  static void info(String message, [Object? data]) {
    print('ℹ️ [INFO] $message${data != null ? ': $data' : ''}');
  }

  /// Log warning messages
  /// Use for non-critical issues that should be investigated
  static void warning(String message, [Object? data]) {
    print('⚠️ [WARN] $message${data != null ? ': $data' : ''}');
  }

  /// Log error messages
  /// Use for errors that need attention
  /// 
  /// [error] - The error object (Exception, etc.)
  /// [stackTrace] - Optional stack trace for debugging
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('❌ [ERROR] $message');
    if (error != null) {
      print('   Error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      print('   Stack: $stackTrace');
    }
  }

  /// Log success messages
  /// Use for successful operations
  static void success(String message, [Object? data]) {
    print('✅ [SUCCESS] $message${data != null ? ': $data' : ''}');
  }

  /// Log navigation events (debug mode only)
  /// Use for tracking route changes
  static void navigation(String message) {
    if (kDebugMode) {
      print('📍 [NAV] $message');
    }
  }

  /// Log API/network calls (debug mode only)
  /// Use for tracking HTTP requests
  static void api(String method, String endpoint, [Object? data]) {
    if (kDebugMode) {
      print('🌐 [API] $method $endpoint${data != null ? ': $data' : ''}');
    }
  }

  /// Log database operations (debug mode only)
  /// Use for tracking database queries
  static void database(String operation, [Object? data]) {
    if (kDebugMode) {
      print('💾 [DB] $operation${data != null ? ': $data' : ''}');
    }
  }

  /// Log authentication events
  /// Use for tracking login/logout/signup
  static void auth(String message, [Object? data]) {
    if (kDebugMode) {
      print('🔐 [AUTH] $message${data != null ? ': $data' : ''}');
    }
  }
}
