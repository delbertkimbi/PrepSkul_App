import 'dart:async';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/features/booking/services/session_lifecycle_service.dart';

/// Session Timer Service
///
/// Manages session timing, countdown, and automatic termination.
/// Tracks session duration and automatically ends sessions when time expires.
class SessionTimerService {
  static final SessionTimerService _instance = SessionTimerService._internal();
  factory SessionTimerService() => _instance;
  SessionTimerService._internal();

  // Active session tracking
  String? _activeSessionId;
  DateTime? _sessionStartTime;
  Timer? _countdownTimer;
  Timer? _autoTerminationTimer;
  
  // Streams for UI updates
  final _timeRemainingController = StreamController<Duration>.broadcast();
  final _sessionEndedController = StreamController<String>.broadcast();
  
  // Getters
  Stream<Duration> get timeRemainingStream => _timeRemainingController.stream;
  Stream<String> get sessionEndedStream => _sessionEndedController.stream;
  
  /// Get session duration in minutes from config
  int get sessionDurationMinutes => AppConfig.sessionDurationMinutes;
  
  /// Get session duration as Duration
  Duration get sessionDuration => Duration(minutes: sessionDurationMinutes);
  
  /// Start tracking a session
  ///
  /// [sessionId] - The session ID to track
  /// [startTime] - When the session started (defaults to now)
  Future<void> startSession(String sessionId, {DateTime? startTime}) async {
    try {
      // Stop any existing session
      await stopSession();
      
      _activeSessionId = sessionId;
      _sessionStartTime = startTime ?? DateTime.now();
      
      LogService.info('⏱️ Started session timer: $sessionId (duration: ${sessionDurationMinutes} minutes)');
      
      // Start countdown timer (updates every second)
      _startCountdownTimer();
      
      // Start auto-termination timer
      _startAutoTerminationTimer();
    } catch (e) {
      LogService.error('Error starting session timer: $e');
      rethrow;
    }
  }
  
  /// Stop tracking the current session
  Future<void> stopSession() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _autoTerminationTimer?.cancel();
    _autoTerminationTimer = null;
    
    if (_activeSessionId != null) {
      LogService.info('⏱️ Stopped session timer: $_activeSessionId');
    }
    
    _activeSessionId = null;
    _sessionStartTime = null;
  }
  
  /// Get remaining time for the current session
  Duration? getRemainingTime() {
    if (_activeSessionId == null || _sessionStartTime == null) {
      return null;
    }
    
    final elapsed = DateTime.now().difference(_sessionStartTime!);
    final remaining = sessionDuration - elapsed;
    
    // Return null if time has expired
    if (remaining.isNegative) {
      return null;
    }
    
    return remaining;
  }
  
  /// Check if session time has expired
  bool get isExpired {
    final remaining = getRemainingTime();
    return remaining == null || remaining.isNegative;
  }
  
  /// Start countdown timer (updates every second)
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = getRemainingTime();
      
      if (remaining == null || remaining.isNegative) {
        // Time expired
        timer.cancel();
        _countdownTimer = null;
        _timeRemainingController.add(Duration.zero);
        return;
      }
      
      // Emit remaining time
      _timeRemainingController.add(remaining);
    });
  }
  
  /// Start auto-termination timer
  void _startAutoTerminationTimer() {
    _autoTerminationTimer?.cancel();
    
    // Calculate when to terminate
    if (_sessionStartTime == null) return;
    
    final terminationTime = _sessionStartTime!.add(sessionDuration);
    final delay = terminationTime.difference(DateTime.now());
    
    if (delay.isNegative) {
      // Already expired - terminate immediately
      _terminateSession();
      return;
    }
    
    _autoTerminationTimer = Timer(delay, () {
      _terminateSession();
    });
    
    LogService.info('⏱️ Auto-termination scheduled for ${terminationTime.toIso8601String()}');
  }
  
  /// Terminate the session automatically
  Future<void> _terminateSession() async {
    if (_activeSessionId == null) return;
    
    final sessionId = _activeSessionId!;
    LogService.info('⏱️ Auto-terminating session: $sessionId');
    
    try {
      // End the session via lifecycle service
      await SessionLifecycleService.endSession(sessionId);
      
      // Emit session ended event
      _sessionEndedController.add(sessionId);
      
      LogService.success('✅ Session auto-terminated: $sessionId');
    } catch (e) {
      LogService.error('❌ Error auto-terminating session: $e');
      // Still emit event so UI can handle it
      _sessionEndedController.add(sessionId);
    } finally {
      // Clean up
      await stopSession();
    }
  }
  
  /// Format duration as MM:SS
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Format duration as human-readable string
  static String formatDurationHuman(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
  
  /// Dispose resources
  void dispose() {
    stopSession();
    _timeRemainingController.close();
    _sessionEndedController.close();
  }
}
