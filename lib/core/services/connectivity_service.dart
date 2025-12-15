import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Connectivity Service
///
/// Monitors network connectivity and provides offline/online status
/// Works on mobile and web
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectivityController;
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _isOnline = true; // Default to online
  bool _isInitialized = false;

  /// Get current online status
  bool get isOnline => _isOnline;

  /// Stream of connectivity changes
  Stream<bool> get connectivityStream {
    _connectivityController ??= StreamController<bool>.broadcast();
    return _connectivityController!.stream;
  }

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _isOnline = _hasConnection(result);
      _isInitialized = true;

      LogService.debug('🌐 Connectivity initialized: ${_isOnline ? "Online" : "Offline"}');

      // Listen for connectivity changes
      _subscription = _connectivity.onConnectivityChanged.listen(
        (ConnectivityResult result) async {
          final wasOnline = _isOnline;
          final newOnlineStatus = _hasConnection(result);
          
          // Always update internal state
          _isOnline = newOnlineStatus;

          // Always notify listeners of the change (even if it seems the same)
          // This ensures UI updates when connectivity is restored
          if (wasOnline != newOnlineStatus) {
            LogService.debug(
              '🌐 Connectivity changed: ${_isOnline ? "Online" : "Offline"}',
            );
            _connectivityController?.add(_isOnline);
          } else if (!wasOnline && newOnlineStatus) {
            // Special case: if we were offline and now online, always notify
            // This handles edge cases where state might not have updated
            LogService.debug('🌐 Connection restored - notifying listeners');
            _connectivityController?.add(true);
          }
        },
        onError: (error) {
          LogService.error('Connectivity monitoring error: $error');
          // Assume offline on error
          if (_isOnline) {
            _isOnline = false;
            _connectivityController?.add(false);
          }
        },
      );
    } catch (e) {
      LogService.error('Error initializing connectivity: $e');
      // Default to offline on error
      _isOnline = false;
      _isInitialized = true;
    }
  }

  /// Check if connectivity result indicates online status
  bool _hasConnection(ConnectivityResult result) {
    // Check if we have any active connection (not none)
    return result != ConnectivityResult.none;
  }

  /// Check connectivity status (one-time check)
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = _hasConnection(result);
      return _isOnline;
    } catch (e) {
      LogService.error('Error checking connectivity: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _connectivityController?.close();
    _connectivityController = null;
    _isInitialized = false;
  }
}
