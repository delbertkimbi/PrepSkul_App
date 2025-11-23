import 'web_splash_service_stub.dart'
    if (dart.library.js) 'web_splash_service_web.dart';

class WebSplashService {
  static void removeSplash() => SplashServiceImplementation.removeSplash();
}
