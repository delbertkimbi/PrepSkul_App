import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum PermissionState {
  granted,
  denied,
  deniedPermanently,
  unknown,
}

class CameraMicPermissionStatus {
  final PermissionState camera;
  final PermissionState microphone;

  const CameraMicPermissionStatus({
    required this.camera,
    required this.microphone,
  });

  bool get allGranted =>
      camera == PermissionState.granted && microphone == PermissionState.granted;

  bool get anyDeniedPermanently =>
      camera == PermissionState.deniedPermanently ||
      microphone == PermissionState.deniedPermanently;
}

class CameraMicPermissionService {
  static const MethodChannel _channel =
      MethodChannel('com.prepskul.prepskul/permissions');

  PermissionState _parseState(Object? raw) {
    final s = raw?.toString();
    switch (s) {
      case 'granted':
        return PermissionState.granted;
      case 'denied':
        return PermissionState.denied;
      case 'deniedPermanently':
        return PermissionState.deniedPermanently;
      default:
        return PermissionState.unknown;
    }
  }

  /// Android: checks runtime permission state (camera + mic).
  /// Web/iOS/others: returns unknown (we rely on platform prompts).
  Future<CameraMicPermissionStatus> getStatus() async {
    if (kIsWeb) {
      return const CameraMicPermissionStatus(
        camera: PermissionState.unknown,
        microphone: PermissionState.unknown,
      );
    }

    try {
      final result = await _channel.invokeMethod<dynamic>('getCameraMicStatus');
      if (result is Map) {
        return CameraMicPermissionStatus(
          camera: _parseState(result['camera']),
          microphone: _parseState(result['microphone']),
        );
      }
    } catch (_) {
      // Ignore – some platforms/tests won't have the plugin registered.
    }

    return const CameraMicPermissionStatus(
      camera: PermissionState.unknown,
      microphone: PermissionState.unknown,
    );
  }

  /// Android: triggers runtime permission prompt for camera + mic.
  /// Returns post-request status.
  Future<CameraMicPermissionStatus> request() async {
    if (kIsWeb) {
      return const CameraMicPermissionStatus(
        camera: PermissionState.unknown,
        microphone: PermissionState.unknown,
      );
    }

    try {
      final result = await _channel.invokeMethod<dynamic>('requestCameraMic');
      if (result is Map) {
        return CameraMicPermissionStatus(
          camera: _parseState(result['camera']),
          microphone: _parseState(result['microphone']),
        );
      }
    } catch (_) {
      // Fall through to status check.
    }

    return getStatus();
  }

  Future<void> openAppSettings() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {
      // Ignore.
    }
  }
}

