// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'device_readiness_service.dart';

class DeviceReadinessImplementation {
  static Future<DeviceReadinessSnapshot> probe() async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        return const DeviceReadinessSnapshot(
          cameraInputs: 0,
          microphoneInputs: 0,
          speakerOutputs: 0,
          error: 'Media devices API unavailable in this browser.',
        );
      }

      final devices = await mediaDevices.enumerateDevices();
      var cams = 0;
      var mics = 0;
      var speakers = 0;

      for (final d in devices) {
        switch (d.kind) {
          case 'videoinput':
            cams += 1;
            break;
          case 'audioinput':
            mics += 1;
            break;
          case 'audiooutput':
            speakers += 1;
            break;
          default:
            break;
        }
      }

      return DeviceReadinessSnapshot(
        cameraInputs: cams,
        microphoneInputs: mics,
        speakerOutputs: speakers,
      );
    } catch (e) {
      return DeviceReadinessSnapshot(
        cameraInputs: 0,
        microphoneInputs: 0,
        speakerOutputs: 0,
        error: 'Device probe failed: $e',
      );
    }
  }
}
