import 'device_readiness_service_stub.dart'
    if (dart.library.html) 'device_readiness_service_web.dart';

class DeviceReadinessSnapshot {
  const DeviceReadinessSnapshot({
    required this.cameraInputs,
    required this.microphoneInputs,
    required this.speakerOutputs,
    this.error,
  });

  final int cameraInputs;
  final int microphoneInputs;
  final int speakerOutputs;
  final String? error;

  bool get hasCamera => cameraInputs > 0;
  bool get hasMicrophone => microphoneInputs > 0;
  bool get hasSpeakers => speakerOutputs > 0;
}

class DeviceReadinessService {
  static Future<DeviceReadinessSnapshot> probe() =>
      DeviceReadinessImplementation.probe();
}
