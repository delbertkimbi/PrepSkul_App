// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation - detects iOS Safari and Android mobile for screen share / recording
/// iOS Safari does not support getDisplayMedia(); Android Chrome mobile web does
class PlatformUtils {
  static bool? _isIosWebCached;
  static bool? _isMobileWebCached;

  static bool get isIosWeb {
    _isIosWebCached ??= _detectIos();
    return _isIosWebCached!;
  }

  /// True when running in a mobile browser (iOS or Android phone), not desktop web.
  static bool get isMobileWeb {
    _isMobileWebCached ??= _detectMobileWeb();
    return _isMobileWebCached!;
  }

  static bool _detectIos() {
    try {
      final ua = html.window.navigator.userAgent.toLowerCase();
      return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
    } catch (_) {
      return false;
    }
  }

  static bool _detectMobileWeb() {
    try {
      final ua = html.window.navigator.userAgent.toLowerCase();
      if (_detectIos()) return true;
      return ua.contains('android') && ua.contains('mobile');
    } catch (_) {
      return false;
    }
  }
}
