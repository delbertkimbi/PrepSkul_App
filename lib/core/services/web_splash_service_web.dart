// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:prepskul/core/services/log_service.dart';

class SplashServiceImplementation {
  static void removeSplash() {
    try {
      js.context.callMethod('removeSplash');
    } catch (e) {
      LogService.debug('Error removing splash: $e');
    }
  }
}
