import 'package:flutter/material.dart';

/// Temporary no-op PiP controller.
///
/// The full OS-level PiP integration relies on native APIs that are not yet
/// wired for all platforms. For now, we keep this wrapper so the rest of the
/// call code can invoke it safely, while the visible PiP experience is handled
/// by the existing in-call mini video (`LocalVideoPIP`) which works on all
/// platforms including web.
class CallPipController with WidgetsBindingObserver {
  static final CallPipController _instance = CallPipController._internal();

  factory CallPipController() => _instance;

  CallPipController._internal();

  bool get isPipActive => false;

  bool get isPipSupported => false;

  Future<void> enterPipMode() async {
    // no-op for now
  }

  Future<void> exitPipMode() async {
    // no-op for now
  }

  void attachToLifecycle() {
    // no-op, we don't need lifecycle hooks while OS PiP is disabled.
  }

  void detachFromLifecycle() {
    // no-op
  }
}

