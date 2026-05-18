import 'device_readiness_service.dart';

class DeviceReadinessImplementation {
  static Future<DeviceReadinessSnapshot> probe() async {
    // Mobile permissions + OS routing are handled elsewhere in prejoin.
    return const DeviceReadinessSnapshot(
      cameraInputs: 1,
      microphoneInputs: 1,
      speakerOutputs: 1,
    );
  }
}
