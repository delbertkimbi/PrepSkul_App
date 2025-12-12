import 'package:flutter/material.dart';

/// Extension to safely call setState only when widget is mounted
/// 
/// This prevents "setState() called after dispose()" errors that occur
/// when async operations complete after a widget has been removed from the tree.
/// 
/// Usage:
/// ```dart
/// import 'package:prepskul/core/utils/safe_set_state.dart';
/// 
/// safeSetState(() {
///   _value = newValue;
///   _isLoading = false;
/// });
/// ```
extension SafeSetState on State {
  /// Safely calls setState only if the widget is still mounted
  /// 
  /// Returns true if setState was called, false if widget was not mounted
  bool safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
      return true;
    }
    return false;
  }
}
