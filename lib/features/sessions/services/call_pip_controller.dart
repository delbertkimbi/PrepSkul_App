import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android OS picture-in-picture for active calls (Meet-style).
///
/// iOS/web/desktop: [isPipSupported] is false; [enterPipMode] is a no-op.
/// The in-call mini video ([LocalVideoPIP]) remains the cross-platform fallback.
class CallPipController {
  static final CallPipController _instance = CallPipController._internal();

  factory CallPipController() => _instance;

  CallPipController._internal();

  static const MethodChannel _channel =
      MethodChannel('com.prepskul.prepskul/call_pip');

  bool _pipActive = false;
  bool _nativeSupportResolved = false;
  bool _nativeSupported = false;

  bool get isPipActive => _pipActive;

  bool get isPipSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && _nativeSupported;

  Future<void> _ensureNativeSupportResolved() async {
    if (_nativeSupportResolved) return;
    _nativeSupportResolved = true;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _nativeSupported = false;
      return;
    }
    try {
      final v = await _channel.invokeMethod<bool>('isSupported');
      _nativeSupported = v ?? false;
    } catch (_) {
      _nativeSupported = false;
    }
  }

  Future<void> enterPipMode() async {
    await _ensureNativeSupportResolved();
    if (!isPipSupported) return;
    try {
      final ok = await _channel.invokeMethod<bool>('enterPip');
      if (ok != true) {
        debugPrint('[CallPip] enterPip returned false or null');
      }
    } on PlatformException catch (e) {
      // Common while the activity is paused (e.g. Android screen capture sheet) — don’t spam logs.
      if (e.code == 'PIP_ENTER_FAILED') return;
      debugPrint('[CallPip] enterPip failed: $e');
    } catch (e, st) {
      debugPrint('[CallPip] enterPip failed: $e\n$st');
    }
  }

  Future<void> exitPipMode() async {
    // Exiting PiP is normally user-driven (expand window). No stable public API.
    _pipActive = false;
  }

  void attachToLifecycle() {
    _channel.setMethodCallHandler(_onPlatformCall);
    unawaited(_ensureNativeSupportResolved());
  }

  void detachFromLifecycle() {
    _channel.setMethodCallHandler(null);
  }

  Future<dynamic> _onPlatformCall(MethodCall call) async {
    if (call.method == 'pipModeChanged') {
      final args = call.arguments;
      if (args is Map) {
        _pipActive = args['active'] == true;
      }
    }
  }
}
