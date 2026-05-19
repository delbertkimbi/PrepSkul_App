import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:prepskul/core/services/log_service.dart';

class AnalyticsService {
  static Mixpanel? _mixpanel;
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static Future<void> init() async {
    try {
      _mixpanel = await Mixpanel.init(
        "3aedc52e18443b07c09205411a534aa7",
        optOutTrackingDefault: false,
        trackAutomaticEvents: true,
      );
      _isInitialized = _mixpanel != null;
      LogService.info('[ANALYTICS] Mixpanel initialized: $_isInitialized');
    } catch (e) {
      _isInitialized = false;
      LogService.error('[ANALYTICS] Mixpanel init failed: $e');
      rethrow;
    }
  }

  static void trackEvent(String eventName, [Map<String, dynamic>? props]) {
    if (!_isInitialized || _mixpanel == null) {
      LogService.warning(
        '[ANALYTICS] trackEvent skipped (not initialized): $eventName',
      );
      return;
    }
    _mixpanel?.track(eventName, properties: props);
    LogService.debug('[ANALYTICS] Event tracked: $eventName');
  }

  static void identifyUser(String userId) {
    _mixpanel?.identify(userId);
  }

  static void setUserProperties(Map<String, dynamic> properties) {
    final people = _mixpanel?.getPeople();
    if (people == null) return;
    properties.forEach((key, value) {
      if (value != null) {
        people.set(key, value);
      }
    });
  }

  static void reset() {
    _mixpanel?.reset();
  }
}