// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class SplashServiceImplementation {
  static void removeSplash() {
    try {
      if (js.context.hasProperty('removeSplash')) {
        js.context.callMethod('removeSplash');
      }
    } catch (e) {
      // Silently fail - splash will be removed by fallback timeout anyway
    }
  }
}
