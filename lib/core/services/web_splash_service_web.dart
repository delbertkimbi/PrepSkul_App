// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class SplashServiceImplementation {
  static void removeSplash() {
    try {
      js.context.callMethod('removeSplash');
    } catch (e) {
      print('Error removing splash: $e');
    }
  }
}







