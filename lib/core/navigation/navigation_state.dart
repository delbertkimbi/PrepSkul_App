import 'package:prepskul/core/services/log_service.dart';

/// Navigation State Management
/// 
/// Tracks current route, navigation history, and prevents duplicate navigations
class NavigationState {
  static final NavigationState _instance = NavigationState._internal();
  factory NavigationState() => _instance;
  NavigationState._internal();

  String? _currentRoute;
  final List<String> _navigationHistory = [];
  bool _isNavigating = false;
  DateTime? _lastNavigationTime;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  /// Get current route
  String? get currentRoute => _currentRoute;

  /// Get navigation history (last 10 routes)
  List<String> get navigationHistory => List.unmodifiable(_navigationHistory);

  /// Check if navigation is in progress
  bool get isNavigating => _isNavigating;

  /// Set current route
  void setCurrentRoute(String route) {
    if (_currentRoute != route) {
      _currentRoute = route;
      _lastNavigationTime = DateTime.now();
      
      // Add to history (keep last 10)
      _navigationHistory.add(route);
      if (_navigationHistory.length > 10) {
        _navigationHistory.removeAt(0);
      }
      
      LogService.debug('📍 [NAV_STATE] Current route: $route');
    }
  }

  /// Mark navigation as started
  void startNavigation() {
    _isNavigating = true;
  }

  /// Mark navigation as completed
  void completeNavigation() {
    _isNavigating = false;
  }

  /// Check if we can navigate (debounce check)
  bool canNavigate() {
    if (_isNavigating) {
      LogService.warning('[NAV_STATE] Navigation already in progress');
      return false;
    }

    if (_lastNavigationTime != null) {
      final timeSinceLastNav = DateTime.now().difference(_lastNavigationTime!);
      if (timeSinceLastNav < _debounceDuration) {
        LogService.warning('[NAV_STATE] Navigation debounced (${timeSinceLastNav.inMilliseconds}ms ago)');
        return false;
      }
    }

    return true;
  }

  /// Reset navigation state
  void reset() {
    _currentRoute = null;
    _navigationHistory.clear();
    _isNavigating = false;
    _lastNavigationTime = null;
    LogService.debug('🔄 [NAV_STATE] Navigation state reset');
  }

  /// Check if route is in history
  bool hasVisited(String route) {
    return _navigationHistory.contains(route);
  }

  /// Get last route (excluding current)
  String? getLastRoute() {
    if (_navigationHistory.length > 1) {
      return _navigationHistory[_navigationHistory.length - 2];
    }
    return null;
  }
}


