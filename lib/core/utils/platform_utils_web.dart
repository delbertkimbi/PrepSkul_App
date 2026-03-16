// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation - detects iOS Safari and Android mobile for screen share / recording
/// iOS Safari does not support getDisplayMedia(); Android Chrome mobile web does
class PlatformUtils {
  static bool? _isIosWebCached;
  static bool? _isMobileWebCached;
  static bool _unloadHandlerRegistered = false;

  static bool get isIosWeb {
    _isIosWebCached ??= _detectIos();
    return _isIosWebCached!;
  }

  /// True when running in a mobile browser (iOS or Android phone), not desktop web.
  static bool get isMobileWeb {
    _isMobileWebCached ??= _detectMobileWeb();
    return _isMobileWebCached!;
  }

  /// Register a single global handler that fires when the page is being
  /// unloaded (refresh, tab close, navigation). Used to send a best-effort
  /// \"left\" heartbeat before the connection is torn down.
  static void registerCallUnloadHandler(void Function() onLeave) {
    if (_unloadHandlerRegistered) return;
    _unloadHandlerRegistered = true;
    try {
      html.window.addEventListener('beforeunload', (event) {
        onLeave();
      });
      html.window.addEventListener('pagehide', (event) {
        onLeave();
      });
    } catch (_) {
      // If anything goes wrong we simply skip the optimization.
    }
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
