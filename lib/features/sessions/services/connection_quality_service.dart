import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Connection Quality Service
///
/// Monitors and assesses connection quality for online sessions
/// Provides quality ratings: 'good', 'fair', 'poor'
class ConnectionQualityService {
  static final ConnectionQualityService _instance =
      ConnectionQualityService._internal();
  factory ConnectionQualityService() => _instance;
  ConnectionQualityService._internal();

  final Connectivity _connectivity = Connectivity();
  Timer? _monitoringTimer;
  final List<bool> _connectivityChecks = [];
  static const int _maxChecks = 10; // Store last 10 checks
  static const Duration _checkInterval = Duration(seconds: 30);

  /// Assess current connection quality
  ///
  /// Returns: 'good', 'fair', or 'poor'
  /// Based on:
  /// - Network type (WiFi vs Mobile)
  /// - Connectivity stability
  /// - Latency test (optional)
  static Future<String> assessConnectionQuality() async {
    try {
      final service = ConnectionQualityService();
      return await service._assessQuality();
    } catch (e) {
      print('⚠️ Error assessing connection quality: $e');
      return 'fair'; // Default to fair on error
    }
  }

  /// Start monitoring connection quality during a session
  ///
  /// Periodically checks connection and updates quality assessment
  static Future<void> startMonitoring(String sessionId) async {
    try {
      final service = ConnectionQualityService();
      await service._startMonitoring(sessionId);
    } catch (e) {
      print('⚠️ Error starting connection monitoring: $e');
    }
  }

  /// Stop monitoring connection quality
  static void stopMonitoring() {
    final service = ConnectionQualityService();
    service._stopMonitoring();
  }

  /// Get the best quality assessment from monitoring period
  static String getBestQuality() {
    final service = ConnectionQualityService();
    return service._getBestQuality();
  }

  // ========================================
  // PRIVATE METHODS
  // ========================================

  Future<String> _assessQuality() async {
    try {
      // Check connectivity type
      final connectivityResult = await _connectivity.checkConnectivity();
      
      // Check if we have any connection
      if (connectivityResult == ConnectivityResult.none) {
        return 'poor';
      }

      // Perform a quick latency test
      final latency = await _testLatency();
      
      // Assess based on connection type and latency
      bool isWifi = connectivityResult == ConnectivityResult.wifi ||
          connectivityResult == ConnectivityResult.ethernet;
      
      if (isWifi) {
        // WiFi connection
        if (latency < 100) {
          return 'good';
        } else if (latency < 300) {
          return 'fair';
        } else {
          return 'poor';
        }
      } else {
        // Mobile data connection
        if (latency < 200) {
          return 'good';
        } else if (latency < 500) {
          return 'fair';
        } else {
          return 'poor';
        }
      }
    } catch (e) {
      print('⚠️ Error in quality assessment: $e');
      // Default assessment based on connectivity only
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return 'poor';
      }
      final isWifi = connectivityResult == ConnectivityResult.wifi ||
          connectivityResult == ConnectivityResult.ethernet;
      return isWifi ? 'fair' : 'fair'; // Default to fair if we can't assess
    }
  }

  /// Test latency by making a quick HTTP request
  Future<int> _testLatency() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Try to reach a reliable endpoint (Google's DNS)
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      
      stopwatch.stop();
      
      if (response.statusCode == 200) {
        return stopwatch.elapsedMilliseconds;
      } else {
        return 1000; // High latency if request failed
      }
    } catch (e) {
      // Timeout or error - assume poor connection
      return 2000;
    }
  }

  Future<void> _startMonitoring(String sessionId) async {
    _stopMonitoring(); // Stop any existing monitoring
    
    // Clear previous checks
    _connectivityChecks.clear();
    
    // Initial check
    final initialQuality = await _assessQuality();
    _connectivityChecks.add(initialQuality == 'good');
    
    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(_checkInterval, (timer) async {
      try {
        final quality = await _assessQuality();
        final isGood = quality == 'good';
        
        _connectivityChecks.add(isGood);
        
        // Keep only last N checks
        if (_connectivityChecks.length > _maxChecks) {
          _connectivityChecks.removeAt(0);
        }
        
        print('📊 Connection quality check: $quality');
      } catch (e) {
        print('⚠️ Error in periodic quality check: $e');
      }
    });
    
    print('📊 Started connection quality monitoring for session: $sessionId');
  }

  void _stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    print('📊 Stopped connection quality monitoring');
  }

  String _getBestQuality() {
    if (_connectivityChecks.isEmpty) {
      return 'fair'; // Default
    }
    
    // Calculate percentage of good checks
    final goodChecks = _connectivityChecks.where((check) => check).length;
    final percentage = goodChecks / _connectivityChecks.length;
    
    if (percentage >= 0.8) {
      return 'good';
    } else if (percentage >= 0.5) {
      return 'fair';
    } else {
      return 'poor';
    }
  }
}

