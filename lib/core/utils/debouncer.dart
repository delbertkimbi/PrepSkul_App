import 'dart:async';
import 'package:flutter/material.dart';

/// Debouncer utility for delaying function execution
/// 
/// Useful for search inputs, API calls, and other operations that should
/// wait for user to finish typing before executing.
/// 
/// Example:
/// ```dart
/// final debouncer = Debouncer(milliseconds: 500);
/// 
/// TextField(
///   onChanged: (value) {
///     debouncer.run(() {
///       performSearch(value);
///     });
///   },
/// )
/// ```
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({this.milliseconds = 500});

  /// Run a function after the debounce delay
  /// 
  /// If called again before the delay expires, the previous call is cancelled
  /// and a new timer starts.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  /// Cancel any pending debounced calls
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose the debouncer
  /// 
  /// Call this in dispose() to prevent memory leaks
  void dispose() {
    cancel();
  }
}
