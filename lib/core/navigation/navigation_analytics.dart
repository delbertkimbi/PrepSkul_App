/// Navigation Analytics & Error Tracking
/// 
/// Tracks navigation events, errors, and provides analytics insights
import 'dart:async';
import 'package:prepskul/core/services/log_service.dart';

/// Navigation event types
enum NavigationEventType {
  routeDetermined,
  routeNavigated,
  routeGuardBlocked,
  deepLinkQueued,
  deepLinkProcessed,
  navigationError,
  navigationTimeout,
  backNavigation,
}

/// Navigation event data
class NavigationEvent {
  final NavigationEventType type;
  final String route;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final String? errorMessage;
  final String? stackTrace;

  NavigationEvent({
    required this.type,
    required this.route,
    required this.timestamp,
    this.metadata,
    this.errorMessage,
    this.stackTrace,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'route': route,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
      'error_message': errorMessage,
      'stack_trace': stackTrace,
    };
  }
}

/// Navigation Analytics Service
class NavigationAnalytics {
  static final NavigationAnalytics _instance = NavigationAnalytics._internal();
  factory NavigationAnalytics() => _instance;
  NavigationAnalytics._internal();

  final List<NavigationEvent> _events = [];
  final Map<String, int> _routeVisitCounts = {};
  final Map<String, int> _errorCounts = {};
  final Map<String, Duration> _routeLoadTimes = {};
  DateTime? _appStartTime;
  String? _currentRoute;

  /// Maximum number of events to keep in memory
  static const int maxEvents = 1000;

  /// Initialize analytics
  void initialize() {
    _appStartTime = DateTime.now();
    _logEvent(
      NavigationEventType.routeDetermined,
      '/',
      metadata: {'action': 'app_start'},
    );
    LogService.info('[NAV_ANALYTICS] Analytics initialized');
  }

  /// Track route determination
  void trackRouteDetermined(String route, {Map<String, dynamic>? metadata}) {
    _logEvent(
      NavigationEventType.routeDetermined,
      route,
      metadata: metadata,
    );
    LogService.info('[NAV_ANALYTICS] Route determined: $route');
  }

  /// Track route navigation
  void trackRouteNavigated(String route, {Map<String, dynamic>? metadata}) {
    _currentRoute = route;
    
    _logEvent(
      NavigationEventType.routeNavigated,
      route,
      metadata: metadata,
    );
    
    // Track route visit count
    _routeVisitCounts[route] = (_routeVisitCounts[route] ?? 0) + 1;
    
    // Track load time (if available from metadata)
    if (metadata != null && metadata.containsKey('load_time_ms')) {
      final loadTime = Duration(milliseconds: metadata['load_time_ms'] as int);
      _routeLoadTimes[route] = loadTime;
    }
    
    LogService.info('[NAV_ANALYTICS] Navigated to: $route (visit #${_routeVisitCounts[route]})');
  }

  /// Track route guard blocking
  void trackRouteGuardBlocked(
    String route,
    String redirectRoute, {
    Map<String, dynamic>? metadata,
  }) {
    _logEvent(
      NavigationEventType.routeGuardBlocked,
      route,
      metadata: {
        ...?metadata,
        'redirect_route': redirectRoute,
      },
    );
    LogService.info('[NAV_ANALYTICS] Route guard blocked: $route → $redirectRoute');
  }

  /// Track deep link queued
  void trackDeepLinkQueued(String path, {Map<String, dynamic>? metadata}) {
    _logEvent(
      NavigationEventType.deepLinkQueued,
      path,
      metadata: metadata,
    );
    LogService.info('[NAV_ANALYTICS] Deep link queued: $path');
  }

  /// Track deep link processed
  void trackDeepLinkProcessed(String path, {Map<String, dynamic>? metadata}) {
    _logEvent(
      NavigationEventType.deepLinkProcessed,
      path,
      metadata: metadata,
    );
    LogService.info('[NAV_ANALYTICS] Deep link processed: $path');
  }

  /// Track navigation error
  void trackNavigationError(
    String route,
    String errorMessage, {
    String? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    _logEvent(
      NavigationEventType.navigationError,
      route,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      metadata: metadata,
    );
    
    // Track error count
    _errorCounts[route] = (_errorCounts[route] ?? 0) + 1;
    
    LogService.error('[NAV_ANALYTICS] Navigation error on $route: $errorMessage');
    
    // Optionally send to error tracking service
    _sendErrorToTracking(route, errorMessage, stackTrace);
  }

  /// Track navigation timeout
  void trackNavigationTimeout(String route, {Map<String, dynamic>? metadata}) {
    _logEvent(
      NavigationEventType.navigationTimeout,
      route,
      metadata: metadata,
    );
    LogService.debug('⏰ [NAV_ANALYTICS] Navigation timeout on: $route');
  }

  /// Track back navigation
  void trackBackNavigation(String fromRoute, String? toRoute) {
    _logEvent(
      NavigationEventType.backNavigation,
      fromRoute,
      metadata: {'to_route': toRoute},
    );
    LogService.info('[NAV_ANALYTICS] Back navigation: $fromRoute → ${toRoute ?? "unknown"}');
  }

  /// Get analytics summary
  Map<String, dynamic> getAnalyticsSummary() {
    final now = DateTime.now();
    final sessionDuration = _appStartTime != null
        ? now.difference(_appStartTime!)
        : Duration.zero;

    return {
      'session_duration_seconds': sessionDuration.inSeconds,
      'total_events': _events.length,
      'current_route': _currentRoute,
      'route_visit_counts': Map<String, int>.from(_routeVisitCounts),
      'error_counts': Map<String, int>.from(_errorCounts),
      'route_load_times': _routeLoadTimes.map(
        (route, duration) => MapEntry(route, duration.inMilliseconds),
      ),
      'most_visited_routes': _getMostVisitedRoutes(5),
      'error_rate': _calculateErrorRate(),
      'average_route_load_time_ms': _calculateAverageLoadTime(),
    };
  }

  /// Get most visited routes
  List<Map<String, dynamic>> _getMostVisitedRoutes(int limit) {
    final sorted = _routeVisitCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(limit).map((entry) {
      return {
        'route': entry.key,
        'visit_count': entry.value,
      };
    }).toList();
  }

  /// Calculate error rate
  double _calculateErrorRate() {
    if (_events.isEmpty) return 0.0;
    final errorCount = _events.where(
      (e) => e.type == NavigationEventType.navigationError,
    ).length;
    return (errorCount / _events.length) * 100;
  }

  /// Calculate average load time
  double _calculateAverageLoadTime() {
    if (_routeLoadTimes.isEmpty) return 0.0;
    final totalMs = _routeLoadTimes.values
        .map((d) => d.inMilliseconds)
        .fold(0, (a, b) => a + b);
    return totalMs / _routeLoadTimes.length;
  }

  /// Get events for a specific route
  List<NavigationEvent> getEventsForRoute(String route) {
    return _events.where((e) => e.route == route).toList();
  }

  /// Get error events
  List<NavigationEvent> getErrorEvents() {
    return _events.where(
      (e) => e.type == NavigationEventType.navigationError,
    ).toList();
  }

  /// Get recent events
  List<NavigationEvent> getRecentEvents({int limit = 50}) {
    final sorted = List<NavigationEvent>.from(_events)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  /// Clear analytics data
  void clear() {
    _events.clear();
    _routeVisitCounts.clear();
    _errorCounts.clear();
    _routeLoadTimes.clear();
    _appStartTime = null;
    _currentRoute = null;
    LogService.debug('🔄 [NAV_ANALYTICS] Analytics data cleared');
  }

  /// Export analytics data
  Map<String, dynamic> exportData() {
    return {
      'events': _events.map((e) => e.toMap()).toList(),
      'summary': getAnalyticsSummary(),
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  /// Log event internally
  void _logEvent(
    NavigationEventType type,
    String route, {
    Map<String, dynamic>? metadata,
    String? errorMessage,
    String? stackTrace,
  }) {
    final event = NavigationEvent(
      type: type,
      route: route,
      timestamp: DateTime.now(),
      metadata: metadata,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
    );

    _events.add(event);

    // Limit events to prevent memory issues
    if (_events.length > maxEvents) {
      _events.removeAt(0);
    }
  }

  /// Send error to tracking service (Supabase or external service)
  Future<void> _sendErrorToTracking(
    String route,
    String errorMessage,
    String? stackTrace,
  ) async {
    try {
      // Optionally log to Supabase for analysis
      // final userId = SupabaseService.currentUser?.id;
      // await SupabaseService.client.from('navigation_errors').insert({
      //   'user_id': userId,
      //   'route': route,
      //   'error_message': errorMessage,
      //   'stack_trace': stackTrace,
      //   'timestamp': DateTime.now().toIso8601String(),
      // });
      
      // For now, just print (can be extended to send to Sentry, Firebase, etc.)
      LogService.debug('📤 [NAV_ANALYTICS] Error logged for tracking');
    } catch (e) {
      LogService.error('[NAV_ANALYTICS] Failed to send error to tracking: $e');
    }
  }
}
