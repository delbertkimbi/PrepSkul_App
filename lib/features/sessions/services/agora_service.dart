import 'dart:async';
import 'dart:convert'; // For UTF-8 encoding/decoding of emojis
import 'dart:typed_data';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/features/sessions/services/agora_token_service.dart';
import 'package:prepskul/features/sessions/models/agora_session_state.dart';

/// Agora RTC Service
///
/// Manages Agora RTC engine initialization, channel joining/leaving,
/// and video/audio state management for live tutoring sessions.
class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  RtcEngine? _engine;
  RtcEngine? get engine => _engine; // Expose engine for video views
  bool _isInitialized = false;
  bool _isInChannel = false;
  String? _currentChannelName;
  int? _currentUID;
  RtcConnection? _currentConnection; // Store connection for video views
  AgoraSessionState _state = AgoraSessionState.disconnected;
  bool _isVideoEnabled = false; // Track video state manually - starts OFF
  bool _isAudioEnabled = false; // Track audio state manually - starts OFF
  Timer? _videoCheckTimer; // Periodic check to ensure video stays unmuted
  int? _dataStreamId; // Data stream ID for sending screen sharing notifications
  
  // Network quality adaptation state
  QualityType? _lastNetworkQuality;
  DateTime? _lastQualityChange;
  static const _qualityChangeCooldown = Duration(seconds: 5);
  String? _currentQualityTier; // Track current quality tier: '1080p', '720p', '480p'
  
  // Video recovery state
  final Map<int, int> _videoRecoveryAttempts = {}; // remoteUid -> attempt count
  static const _maxRecoveryAttempts = 3;
  final Map<int, DateTime> _lastRecoveryAttempt = {}; // remoteUid -> last attempt time
  static const _recoveryCooldown = Duration(seconds: 10);
  
  // Camera recovery state
  bool _isRecoveringCamera = false;
  int _cameraRecoveryAttempts = 0;
  static const _maxCameraRecoveryAttempts = 3;
  DateTime? _lastCameraRecoveryAttempt;
  
  // Connection resilience state
  bool _isReconnecting = false;
  int _reconnectionAttempts = 0;
  static const _maxReconnectionAttempts = 5;
  DateTime? _lastReconnectionAttempt;
  static const _reconnectionCooldown = Duration(seconds: 3);
  String? _lastSessionId;
  String? _lastUserId;
  String? _lastUserRole;
  bool _lastInitialCameraEnabled = false;
  bool _lastInitialMicEnabled = false;
  
  // Health check state
  Timer? _videoHealthCheckTimer;
  static const _healthCheckInterval = Duration(seconds: 10);
  DateTime? _lastRemoteVideoActivity; // Track last time remote video was active
  int? _lastActiveRemoteUid;
  
  // Event streams
  final _stateController = StreamController<AgoraSessionState>.broadcast();
  final _userJoinedController = StreamController<int>.broadcast();
  final _userOfflineController = StreamController<int>.broadcast();
  final _connectionStateController = StreamController<ConnectionStateType>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  
  // Remote state tracking streams
  final _remoteVideoMutedController = StreamController<Map<String, dynamic>>.broadcast(); // {uid: int, muted: bool}
  final _remoteAudioMutedController = StreamController<Map<String, dynamic>>.broadcast(); // {uid: int, muted: bool}
  final _screenSharingController = StreamController<Map<String, dynamic>>.broadcast(); // {uid: int, sharing: bool}
  final _userLeftController = StreamController<int>.broadcast(); // uid of user who left
  final _remoteNetworkQualityController = StreamController<Map<String, dynamic>>.broadcast(); // {uid: int, quality: QualityType, isUnstable: bool}
  final _reactionController = StreamController<Map<String, dynamic>>.broadcast(); // {uid: int, emoji: String}
  final _remoteScreenOffController = StreamController<Map<String, dynamic>>.broadcast(); // {uid: int, screenOff: bool}
  
  // Remote network quality tracking
  final Map<int, QualityType> _remoteNetworkQualities = {}; // remoteUid -> quality
  final Map<int, DateTime> _remoteNetworkQualityTimestamps = {}; // remoteUid -> last update time
  final Map<int, int> _remotePoorQualityCount = {}; // remoteUid -> consecutive poor quality counts
  
  // Connection state tracking for accurate user left detection
  final Map<int, DateTime> _userOfflineTimestamps = {}; // remoteUid -> when they went offline
  final Map<int, Timer?> _userLeftGracePeriodTimers = {}; // remoteUid -> grace period timer
  final Map<int, bool> _userConfirmedLeft = {}; // remoteUid -> confirmed left (not just poor connection)
  final Map<int, int> _userOfflineCount = {}; // remoteUid -> consecutive offline events
  static const _userLeftGracePeriod = Duration(seconds: 15); // Wait 15 seconds before confirming user left
  static const _maxOfflineEvents = 3; // Number of offline events before confirming left
  
  // Screen-off detection state
  final Map<int, DateTime> _remoteVideoStoppedTimestamps = {}; // remoteUid -> when video stopped
  final Map<int, Timer?> _screenOffDetectionTimers = {}; // remoteUid -> screen-off detection timer
  final Map<int, bool> _remoteScreenOff = {}; // remoteUid -> screen is off
  final Map<int, bool> _remoteAudioActive = {}; // remoteUid -> audio is still active (helps detect screen-off)
  static const _screenOffDetectionDelay = Duration(seconds: 5); // Wait 5 seconds before detecting screen-off

  // Quality tier configurations
  static const _quality1080p = VideoEncoderConfiguration(
    dimensions: VideoDimensions(width: 1920, height: 1080),
    frameRate: 30,
    bitrate: 3000,
    minBitrate: 2000,
    orientationMode: OrientationMode.orientationModeAdaptive,
    degradationPreference: DegradationPreference.maintainQuality,
    mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
  );
  
  static const _quality720p = VideoEncoderConfiguration(
    dimensions: VideoDimensions(width: 1280, height: 720),
    frameRate: 30,
    bitrate: 2000,
    minBitrate: 1500,
    orientationMode: OrientationMode.orientationModeAdaptive,
    degradationPreference: DegradationPreference.maintainQuality,
    mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
  );
  
  static const _quality720pLowFps = VideoEncoderConfiguration(
    dimensions: VideoDimensions(width: 1280, height: 720),
    frameRate: 15,
    bitrate: 1500,
    minBitrate: 1000,
    orientationMode: OrientationMode.orientationModeAdaptive,
    degradationPreference: DegradationPreference.maintainFramerate,
    mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
  );
  
  static const _quality480p = VideoEncoderConfiguration(
    dimensions: VideoDimensions(width: 640, height: 480),
    frameRate: 15,
    bitrate: 1000,
    minBitrate: 800,
    orientationMode: OrientationMode.orientationModeAdaptive,
    degradationPreference: DegradationPreference.maintainFramerate,
    mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
  );

  // Getters
  Stream<AgoraSessionState> get stateStream => _stateController.stream;
  Stream<int> get userJoinedStream => _userJoinedController.stream;
  Stream<int> get userOfflineStream => _userOfflineController.stream;
  Stream<ConnectionStateType> get connectionStateStream => _connectionStateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<Map<String, dynamic>> get remoteVideoMutedStream => _remoteVideoMutedController.stream;
  Stream<Map<String, dynamic>> get remoteAudioMutedStream => _remoteAudioMutedController.stream;
  Stream<Map<String, dynamic>> get screenSharingStream => _screenSharingController.stream;
  Stream<int> get userLeftStream => _userLeftController.stream;
  Stream<Map<String, dynamic>> get remoteNetworkQualityStream => _remoteNetworkQualityController.stream;
  Stream<Map<String, dynamic>> get reactionStream => _reactionController.stream;
  Stream<Map<String, dynamic>> get remoteScreenOffStream => _remoteScreenOffController.stream;
  
  AgoraSessionState get state => _state;
  bool get isInitialized => _isInitialized;
  bool get isInChannel => _isInChannel;
  String? get currentChannelName => _currentChannelName;
  int? get currentUID => _currentUID;
  RtcConnection? get currentConnection => _currentConnection;

  /// Initialize Agora RTC Engine
  ///
  /// Should be called once when app starts or before first session.
  /// Can be called multiple times safely (idempotent).
  Future<void> initialize() async {
    if (_isInitialized && _engine != null) {
      LogService.info('Agora engine already initialized');
      return;
    }

    try {
      // Check if running on web
      if (kIsWeb) {
        LogService.info('Initializing Agora engine for web platform');
        // For web, iris-web-rtc.js script must be loaded before this point
        // The script is loaded in index.html before flutter_bootstrap.js
      }

      // Create engine instance
      // Note: On web, requires iris-web-rtc.js script in index.html (not AgoraRTC_N.js)
      // The Flutter package uses iris_web which requires the iris-web-rtc script
      try {
        _engine = createAgoraRtcEngine();
      } catch (e) {
        // If engine creation fails on web, it's likely SDK not loaded
        if (kIsWeb && (e.toString().contains('createIrisApiEngine') || 
                       e.toString().contains('undefined'))) {
          throw Exception(
            'Agora iris-web-rtc SDK not loaded. '
            'Please ensure iris-web-rtc.js script is included in index.html and loads before Flutter initializes. '
            'Error: $e'
          );
        }
        rethrow;
      }
      
      // Get App ID from environment or token (will be set properly in joinChannel)
      // For now, initialize with empty - will be updated when we get token
      await _engine!.initialize(
        RtcEngineContext(
          appId: '', // Will be set from token response
          channelProfile: ChannelProfileType.channelProfileCommunication,
          // Add area code for better connection (optional)
          // areaCode: AreaCode.areaCodeGlob,
        ),
      );

      // Configure video quality: Adaptive (720p-1080p based on network)
      // Start at 720p, scale up to 1080p when network is good
      try {
        await _engine!.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 1280, height: 720), // Start at 720p
            frameRate: 30, // 30 fps
            bitrate: 2000, // Base bitrate (2000 kbps for 720p)
            minBitrate: 1000, // Minimum for poor networks
            orientationMode: OrientationMode.orientationModeAdaptive,
            degradationPreference: DegradationPreference.maintainQuality, // Prefer quality over frame rate
            mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
            // Note: Agora SDK will automatically adjust resolution based on network quality
            // When network is excellent, it may scale up to 1080p
          ),
        );
        LogService.success('✅ Video encoder configured: Adaptive 720p-1080p (starts at 720p, scales based on network)');
      } catch (e) {
        LogService.warning('Could not set video encoder configuration: $e');
      }

      // Configure audio for optimal clarity
      try {
        await _engine!.setAudioProfile(
          profile: AudioProfileType.audioProfileDefault,
          scenario: AudioScenarioType.audioScenarioGameStreaming, // High quality for education
        );
        LogService.success('✅ Audio profile configured for high quality');
      } catch (e) {
        LogService.warning('Could not set audio profile: $e');
      }

      // Register event handlers
      _registerEventHandlers();

      _isInitialized = true;
      _updateState(AgoraSessionState.disconnected);
      LogService.success('Agora RTC engine initialized');
    } catch (e, stackTrace) {
      LogService.error('Failed to initialize Agora engine: $e');
      LogService.error('Stack trace: $stackTrace');
      
      // Provide helpful error message
      String errorMessage = 'Failed to initialize: $e';
      if (kIsWeb) {
        if (e.toString().contains('createIrisApiEngine') || 
            e.toString().contains('undefined') ||
            e.toString().contains('iris-web-rtc')) {
          errorMessage = 'Agora iris-web-rtc SDK not loaded. '
              'Please ensure iris-web-rtc.js script is included in index.html. Error: $e';
        } else {
          errorMessage = 'Failed to initialize video service on web. '
              'Please ensure your browser supports WebRTC and has necessary permissions. Error: $e';
        }
      }
      
      _errorController.add(errorMessage);
      rethrow;
    }
  }

  /// Join Agora channel for a session
  ///
  /// Fetches token from backend and joins the channel.
  ///
  /// [sessionId] Individual session ID
  /// [userId] Current user ID
  /// [userRole] User role ('tutor' or 'learner')
  /// [initialCameraEnabled] Initial camera state (from pre-join screen)
  /// [initialMicEnabled] Initial mic state (from pre-join screen)
  Future<void> joinChannel({
    required String sessionId,
    required String userId,
    required String userRole,
    bool initialCameraEnabled = false,
    bool initialMicEnabled = false,
  }) async {
    // Store session info for reconnection
    _lastSessionId = sessionId;
    _lastUserId = userId;
    _lastUserRole = userRole;
    _lastInitialCameraEnabled = initialCameraEnabled;
    _lastInitialMicEnabled = initialMicEnabled;
    
    // Reset reconnection attempts on new join
    _reconnectionAttempts = 0;
    if (_isInChannel) {
      LogService.warning('Already in channel: $_currentChannelName');
      return;
    }

    try {
      _updateState(AgoraSessionState.joining);

      // Fetch token from backend FIRST to get appId
      final tokenData = await AgoraTokenService.fetchToken(sessionId);
      
      _currentChannelName = tokenData['channelName'] as String;
      _currentUID = tokenData['uid'] as int;
      final token = tokenData['token'] as String;
      final appId = tokenData['appId'] as String?;
      
      LogService.info('📊 Channel Info: channelName=$_currentChannelName, UID=$_currentUID, role=$userRole');

      // CRITICAL: If appId is provided and engine not initialized or initialized with empty appId, reinitialize
      if (appId != null && appId.isNotEmpty) {
        // Check if we need to reinitialize with proper appId
        if (!_isInitialized || _engine == null) {
          LogService.info('Initializing engine with App ID from token');
          // Dispose existing engine if any
          if (_engine != null) {
            try {
              await _engine!.release();
            } catch (e) {
              LogService.warning('Error releasing engine: $e');
            }
            _engine = null;
            _isInitialized = false;
          }
          
          // Create new engine with proper appId
          _engine = createAgoraRtcEngine();
          await _engine!.initialize(
            RtcEngineContext(
              appId: appId,
              channelProfile: ChannelProfileType.channelProfileCommunication,
            ),
          );
          
          // Re-register event handlers
          _registerEventHandlers();
          _isInitialized = true;
          LogService.success('Engine reinitialized with App ID');
        } else {
          LogService.info('Using existing engine (App ID should be set)');
        }
      } else {
        LogService.warning('No appId in token response - connection may fail');
        // Try to initialize if not already done
        if (!_isInitialized) {
          await initialize();
        }
      }

      // Enable video and audio capabilities
      try {
        LogService.info('Enabling video and audio capabilities...');
        await _engine!.enableVideo();
        await _engine!.enableAudio();
        LogService.success('✅ Video and audio capabilities enabled');
        
        // Set initial camera and mic state from pre-join screen
        _isVideoEnabled = initialCameraEnabled;
        _isAudioEnabled = initialMicEnabled;
        
        // Apply initial states
        await _engine!.muteLocalVideoStream(!initialCameraEnabled);
        await _engine!.muteLocalAudioStream(!initialMicEnabled);
        
        LogService.info('📹 Initial state: Camera=${initialCameraEnabled ? "ON" : "OFF"}, Mic=${initialMicEnabled ? "ON" : "OFF"}');
        
        // If camera is enabled, set up local video view
        if (initialCameraEnabled) {
          if (kIsWeb) {
            try {
              // CRITICAL: Explicitly set up local video with camera source type
              // This ensures the camera feed is properly captured and displayed
              await _engine!.setupLocalVideo(
                const VideoCanvas(
                  uid: 0,
                  sourceType: VideoSourceType.videoSourceCamera,
                ),
              );
              await Future.delayed(const Duration(milliseconds: 300));
              await _engine!.muteLocalVideoStream(false);
              LogService.info('✅ Local video set up (camera enabled)');
            } catch (e) {
              LogService.warning('Could not set up local video: $e');
            }
          } else {
            try {
              await _engine!.startPreview();
              LogService.info('✅ Local video preview started');
            } catch (e) {
              LogService.warning('Could not start preview: $e');
            }
          }
        }
      } catch (e) {
        LogService.warning('Error enabling video/audio capabilities: $e');
        // Continue anyway - some platforms might handle this differently
        _isVideoEnabled = initialCameraEnabled;
        _isAudioEnabled = initialMicEnabled;
      }

      // Join channel
      // Note: Don't set state to connected here - wait for onJoinChannelSuccess event
      await _engine!.joinChannel(
        token: token,
        channelId: _currentChannelName!,
        uid: _currentUID!,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      // Don't set connected state here - wait for onJoinChannelSuccess callback
      // The event handler will update the state when connection is actually established
      LogService.info('Join channel request sent, waiting for connection...');
    } catch (e) {
      LogService.error('Failed to join channel: $e');
      
      // Check for permission errors specifically
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('notallowederror') ||
          errorStr.contains('notallowed') ||
          errorStr.contains('permission denied') ||
          (errorStr.contains('permission') && errorStr.contains('denied'))) {
        LogService.error('❌ Permission denied when joining channel');
        LogService.error('💡 Camera/microphone access was blocked by browser');
        LogService.error('💡 To fix: Click camera/mic icon in address bar → Set to "Allow" → Refresh page');
        _errorController.add('Camera and Microphone Permission Required\n\n'
            'Your browser is blocking camera and microphone access.\n\n'
            'To fix:\n'
            '1. Click the camera/microphone icon in the address bar\n'
            '2. Set both "Camera" and "Microphone" to "Allow"\n'
            '3. Refresh this page and try again');
        _updateState(AgoraSessionState.error);
        rethrow;
      }
      
      _updateState(AgoraSessionState.error);
      _errorController.add('Failed to join: $e');
      rethrow;
    }
  }

  /// Start periodic check to ensure video stays unmuted
  void _startVideoCheckTimer() {
    _videoCheckTimer?.cancel();
    _videoCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isInChannel || _engine == null || !_isVideoEnabled) {
        timer.cancel();
        _videoCheckTimer = null;
        return;
      }
      
      // Periodically ensure video is unmuted (silently - don't log every time)
      _engine!.muteLocalVideoStream(false).catchError((e) {
        // Silently fail - video might already be unmuted
      });
    });
  }

  /// Stop periodic video check
  void _stopVideoCheckTimer() {
    _videoCheckTimer?.cancel();
    _videoCheckTimer = null;
  }

  /// Leave Agora channel
  Future<void> leaveChannel() async {
    if (_engine == null) {
      // Engine already disposed or not initialized
      _isInChannel = false;
      _currentChannelName = null;
      _currentUID = null;
      _currentConnection = null;
      _updateState(AgoraSessionState.disconnected);
      return;
    }

    if (!_isInChannel) {
      // Already left
      _updateState(AgoraSessionState.disconnected);
      return;
    }

    try {
      _updateState(AgoraSessionState.leaving);
      
      // Stop periodic checks
      _stopVideoCheckTimer();
      
      // Stop video health check
      _stopVideoHealthCheck();
      
      // Reset optimization state
      _reconnectionAttempts = 0;
      _isReconnecting = false;
      _videoRecoveryAttempts.clear();
      _lastRecoveryAttempt.clear();
      _cameraRecoveryAttempts = 0;
      _isRecoveringCamera = false;
      _lastNetworkQuality = null;
      _currentQualityTier = null;
      _lastRemoteVideoActivity = null;
      _lastActiveRemoteUid = null;
      _remoteNetworkQualities.clear();
      _remoteNetworkQualityTimestamps.clear();
      _remotePoorQualityCount.clear();
      
      // Clean up connection state tracking
      for (var timer in _userLeftGracePeriodTimers.values) {
        timer?.cancel();
      }
      _userLeftGracePeriodTimers.clear();
      _userOfflineTimestamps.clear();
      _userOfflineCount.clear();
      _userConfirmedLeft.clear();
      
      // Clean up screen-off detection
      for (var timer in _screenOffDetectionTimers.values) {
        timer?.cancel();
      }
      _screenOffDetectionTimers.clear();
      _remoteVideoStoppedTimestamps.clear();
      _remoteScreenOff.clear();
      _remoteAudioActive.clear();
      
      // CRITICAL: IMMEDIATELY update state flags BEFORE any async operations
      // This ensures UI and other parts of the app know tracks are off right away
      final wasVideoEnabled = _isVideoEnabled;
      final wasAudioEnabled = _isAudioEnabled;
      _isVideoEnabled = false; // Update immediately (synchronously)
      _isAudioEnabled = false; // Update immediately (synchronously)
      
      // CRITICAL: Mute audio and video IMMEDIATELY (in parallel) before leaving
      // This ensures the call stops immediately even if network is poor
      try {
        // Fire both mute operations in parallel for faster shutdown
        await Future.wait([
          if (wasVideoEnabled)
            _engine!.muteLocalVideoStream(true).timeout(
              const Duration(seconds: 1), // Shorter timeout for immediate response
              onTimeout: () {
                LogService.warning('Mute video timeout - continuing');
              },
            ).catchError((e) {
              LogService.warning('Mute video error (continuing): $e');
            }),
          if (wasAudioEnabled)
            _engine!.muteLocalAudioStream(true).timeout(
              const Duration(seconds: 1), // Shorter timeout for immediate response
              onTimeout: () {
                LogService.warning('Mute audio timeout - continuing');
              },
            ).catchError((e) {
              LogService.warning('Mute audio error (continuing): $e');
            }),
        ], eagerError: false); // Don't fail if one times out
        LogService.info('✅ Audio and video muted before leaving channel');
      } catch (e) {
        LogService.warning('Error muting before leave (continuing anyway): $e');
      }
      
      // Try to leave channel with timeout and error handling
      try {
        await _engine!.leaveChannel().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            LogService.warning('Leave channel timeout - forcing disconnect');
            // Force disconnect state even on timeout
            _isInChannel = false;
            _currentChannelName = null;
            _currentUID = null;
            _currentConnection = null;
          },
        );
      } catch (e) {
        // Handle mutex errors and other leave channel errors gracefully
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('mutex') || 
            errorStr.contains('already') || 
            errorStr.contains('not in channel')) {
          LogService.warning('Channel already left or mutex error (this is okay): $e');
        } else {
          LogService.warning('Error leaving channel (continuing anyway): $e');
        }
      }
      
      // CRITICAL: Force stop all media tracks to ensure call ends completely
      // This is especially important for poor network conditions and mobile devices
      try {
        // Stop screen capture if active (must be done before disabling capabilities)
        try {
          await _engine!.stopScreenCapture().timeout(
            const Duration(seconds: 1),
            onTimeout: () {
              LogService.warning('Stop screen capture timeout - continuing');
            },
          );
        } catch (e) {
          // Screen capture might not be active - this is okay
          LogService.debug('Screen capture not active or already stopped: $e');
        }
        
        // Disable video and audio capabilities to stop all media tracks
        // Do these in parallel for faster shutdown
        await Future.wait([
          _engine!.disableVideo().timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              LogService.warning('Disable video timeout - continuing');
            },
          ).catchError((e) {
            LogService.warning('Disable video error (continuing): $e');
          }),
          _engine!.disableAudio().timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              LogService.warning('Disable audio timeout - continuing');
            },
          ).catchError((e) {
            LogService.warning('Disable audio error (continuing): $e');
          }),
        ], eagerError: false); // Don't fail if one times out
        
        // CRITICAL: On mobile, also stop preview if it was started
        try {
          if (!kIsWeb) {
            // On mobile, stop preview if it was started
            await _engine!.stopPreview().timeout(
              const Duration(seconds: 1),
              onTimeout: () {
                LogService.warning('Stop preview timeout - continuing');
              },
            ).catchError((e) {
              // Preview might not be active - this is okay
              LogService.debug('Preview not active: $e');
            });
          }
        } catch (e) {
          LogService.warning('Error stopping preview (continuing anyway): $e');
        }
        
        LogService.info('✅ All media tracks stopped and capabilities disabled');
      } catch (e) {
        LogService.warning('Error disabling capabilities (continuing anyway): $e');
      }
      
      // Always update state even if leaveChannel throws
      _isInChannel = false;
      _currentChannelName = null;
      _currentUID = null;
      _currentConnection = null; // Clear connection
      _updateState(AgoraSessionState.disconnected);
      
      LogService.success('Left Agora channel');
    } catch (e) {
      // Even if there's an error, mark as disconnected
      LogService.warning('Error during leave channel (marking as disconnected): $e');
      _isInChannel = false;
      _currentChannelName = null;
      _currentUID = null;
      _currentConnection = null;
      _stopVideoHealthCheck();
      _updateState(AgoraSessionState.disconnected);
      // Don't add to error controller - user is leaving anyway
    }
  }

  /// Toggle local video (camera on/off)
  Future<void> toggleVideo() async {
    if (_engine == null) return;

    try {
      _isVideoEnabled = !_isVideoEnabled;
      
      if (_isVideoEnabled) {
        // Enabling camera - set up local video view and unmute
        LogService.info('📹 Enabling camera...');
        
        // Set up local video view (required for web to access camera)
        if (kIsWeb) {
          try {
            // First, enable video capability
            await _engine!.enableVideo();
            LogService.info('📹 Video capability enabled');
            
            // Force camera access by setting up local video view with camera source
            await _engine!.setupLocalVideo(
              const VideoCanvas(
                uid: 0,
                sourceType: VideoSourceType.videoSourceCamera,
              ),
            );
            LogService.info('✅ Local video view set up (camera source)');
            // Wait for camera to start
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            LogService.warning('Could not set up local video view: $e');
          }
        } else {
          // On mobile, start preview
          try {
            await _engine!.startPreview();
            LogService.info('✅ Local video preview started');
          } catch (e) {
            LogService.warning('Could not start preview: $e');
          }
        }
        
        // Unmute video stream
        await _engine!.muteLocalVideoStream(false);
        LogService.info('✅ Video enabled - should be visible to remote users');
        
        // CRITICAL: Aggressively ensure video is unmuted (try multiple times)
        for (int i = 0; i < 3; i++) {
          try {
            await _engine!.muteLocalVideoStream(false);
            LogService.info('✅ Verified video stream is unmuted (publishing) - attempt ${i + 1}');
            // Small delay between attempts
            if (i < 2) {
              await Future.delayed(const Duration(milliseconds: 200));
            }
          } catch (e) {
            LogService.warning('Could not verify video is unmuted (attempt ${i + 1}): $e');
          }
        }
        
        // On web, also try setupLocalVideo again after unmuting
        if (kIsWeb) {
          try {
            await Future.delayed(const Duration(milliseconds: 500));
            await _engine!.setupLocalVideo(const VideoCanvas(uid: 0));
            LogService.info('📹 Re-setup local video after unmuting');
          } catch (e) {
            LogService.warning('Could not re-setup local video: $e');
          }
        }
        
        // Restart periodic check
        if (_isInChannel) {
          _startVideoCheckTimer();
        }
        
        // Also schedule a check after a delay to ensure it stays unmuted
        Future.delayed(const Duration(seconds: 2), () async {
          if (_engine != null && _isInChannel && _isVideoEnabled) {
            try {
              await _engine!.muteLocalVideoStream(false);
              LogService.info('✅ Final check: Video stream is unmuted');
            } catch (e) {
              LogService.warning('Final check failed: $e');
            }
          }
        });
      } else {
        // Disabling camera - mute video stream
        await _engine!.muteLocalVideoStream(true);
        LogService.info('📹 Video disabled - not visible to remote users');
        // Stop periodic check when video is disabled
        _stopVideoCheckTimer();
      }
    } catch (e) {
      LogService.error('Failed to toggle video: $e');
      _errorController.add('Failed to toggle video: $e');
      _isVideoEnabled = !_isVideoEnabled; // Revert on error
    }
  }

  /// Toggle local audio (microphone mute/unmute)
  Future<void> toggleAudio() async {
    if (_engine == null) return;

    try {
      _isAudioEnabled = !_isAudioEnabled;
      await _engine!.muteLocalAudioStream(!_isAudioEnabled);
      LogService.info('Audio ${_isAudioEnabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      LogService.error('Failed to toggle audio: $e');
      _errorController.add('Failed to toggle audio: $e');
      _isAudioEnabled = !_isAudioEnabled; // Revert on error
    }
  }

  /// Check if video is enabled
  bool isVideoEnabled() {
    return _isVideoEnabled;
  }

  /// Check if audio is enabled
  bool isAudioEnabled() {
    return _isAudioEnabled;
  }

  /// Start screen sharing
  /// Both tutor and learner can share their screen
  Future<void> startScreenSharing() async {
    if (_engine == null || !_isInChannel) {
      throw Exception('Engine not initialized or not in channel');
    }

    try {
      // CRITICAL: Mute camera video stream when screen sharing starts
      // This ensures only screen content is published, not camera
      if (_isVideoEnabled) {
        LogService.info('📹 Muting camera video stream for screen sharing');
        await _engine!.muteLocalVideoStream(true);
      }
      
      // For web (including mobile web browsers), use startScreenCapture
      // Mobile web browsers support screen sharing via the Screen Capture API
      if (kIsWeb) {
        await _engine!.startScreenCapture(
          const ScreenCaptureParameters2(
            captureVideo: true,
            captureAudio: true,
            videoParams: ScreenVideoParameters(
              dimensions: VideoDimensions(width: 1920, height: 1080),
              frameRate: 15,
              bitrate: 2000,
            ),
          ),
        );
      } else {
        // For native mobile (Android/iOS), use startScreenCapture with appropriate parameters
        // Note: Mobile screen sharing may have limitations compared to desktop
        await _engine!.startScreenCapture(
          const ScreenCaptureParameters2(
            captureVideo: true,
            captureAudio: false, // Audio may not be supported on all mobile platforms
            videoParams: ScreenVideoParameters(
              dimensions: VideoDimensions(width: 1280, height: 720), // Lower resolution for mobile
              frameRate: 15,
              bitrate: 1000, // Lower bitrate for mobile networks
            ),
          ),
        );
      }
      
      // CRITICAL: Set up local video view with screen source
      // This ensures the screen sharing stream is properly published
      await _engine!.setupLocalVideo(
        VideoCanvas(
          uid: 0,
          sourceType: VideoSourceType.videoSourceScreen,
        ),
      );
      
      // CRITICAL: Update channel media options to publish screen track
      // Without this, the screen sharing stream may not be published correctly
      try {
        if (!_isInChannel) {
          LogService.warning('Cannot update media options: not in channel');
        } else {
          await _engine!.updateChannelMediaOptions(
            ChannelMediaOptions(
              publishCameraTrack: false,  // Disable camera track
              publishScreenTrack: true,   // Enable screen track
              publishScreenCaptureVideo: true,
              publishScreenCaptureAudio: kIsWeb, // Audio capture only on web
              publishMicrophoneTrack: _isAudioEnabled,  // Keep mic state
            ),
          );
          LogService.success('✅ Channel media options updated for screen sharing (publishScreenTrack=true, publishCameraTrack=false)');
        }
      } catch (e) {
        LogService.warning('Could not update channel media options for screen sharing: $e');
        // Continue anyway - some SDK versions may handle this automatically
      }
      
      LogService.success('✅ Screen sharing started');
      LogService.info('📺 Screen sharing stream is now active - remote users should see your screen');
      _screenSharingController.add({'uid': _currentUID, 'sharing': true});
      
      // Notify remote users via data stream
      _notifyRemoteUsersScreenSharing(true);
    } catch (e) {
      // Check if user cancelled the browser prompt
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('notallowed') || 
          errorStr.contains('not allowed') ||
          errorStr.contains('permission') ||
          errorStr.contains('denied') ||
          errorStr.contains('user') && errorStr.contains('cancel')) {
        // User cancelled - don't show error, just log it
        LogService.info('Screen sharing cancelled by user');
        // Don't add to error controller - user intentionally cancelled
        return; // Silently return without error
      }
      
      // For other errors, log but don't show to user (they're usually technical)
      LogService.warning('Screen sharing error (not showing to user): $e');
      // Don't add to error controller - avoid showing technical errors
    }
  }

  /// Stop screen sharing
  Future<void> stopScreenSharing() async {
    if (_engine == null) return;

    try {
      await _engine!.stopScreenCapture();
      
      // CRITICAL: Update channel media options to disable screen track
      // This ensures the screen sharing stream is properly stopped
      try {
        if (!_isInChannel) {
          LogService.warning('Cannot update media options: not in channel');
        } else {
          await _engine!.updateChannelMediaOptions(
            ChannelMediaOptions(
              publishCameraTrack: _isVideoEnabled,  // Restore camera track
              publishScreenTrack: false,            // Disable screen track
              publishScreenCaptureVideo: false,
              publishScreenCaptureAudio: false,
              publishMicrophoneTrack: _isAudioEnabled,  // Keep mic state
            ),
          );
          LogService.success('✅ Channel media options updated to stop screen sharing (publishScreenTrack=false, publishCameraTrack=$_isVideoEnabled)');
        }
      } catch (e) {
        LogService.warning('Could not update channel media options to stop screen sharing: $e');
        // Continue anyway - some SDK versions may handle this automatically
      }
      
      // CRITICAL: Restore camera video stream when screen sharing stops
      // Switch back to camera source
      if (_isVideoEnabled) {
        LogService.info('📹 Restoring camera video stream after screen sharing');
        await _engine!.setupLocalVideo(
          VideoCanvas(
            uid: 0,
            sourceType: VideoSourceType.videoSourceCamera,
          ),
        );
        await _engine!.muteLocalVideoStream(false);
        LogService.info('✅ Camera video stream restored');
      }
      
      LogService.success('✅ Screen sharing stopped');
      _screenSharingController.add({'uid': _currentUID, 'sharing': false});
    } catch (e) {
      LogService.error('Failed to stop screen sharing: $e');
      _errorController.add('Failed to stop screen sharing: $e');
    }
  }

  /// Notify remote users about screen sharing state via data stream
  Future<void> _notifyRemoteUsersScreenSharing(bool isSharing) async {
    if (_dataStreamId == null || _engine == null || !_isInChannel) {
      LogService.warning('Cannot send screen sharing notification: dataStreamId=$_dataStreamId, engine=${_engine != null}, inChannel=$_isInChannel');
      return;
    }

    try {
      final message = isSharing ? 'screen_share_start' : 'screen_share_stop';
      final messageBytes = message.codeUnits;
      final data = Uint8List.fromList(messageBytes);
      
      await _engine!.sendStreamMessage(
        streamId: _dataStreamId!,
        data: data,
        length: data.length,
      );
      LogService.success('✅ Sent screen sharing notification: $message');
    } catch (e) {
      LogService.warning('Failed to send screen sharing notification: $e');
    }
  }

  /// Send emoji reaction to remote users via data stream
  Future<void> sendReaction(String emoji) async {
    if (_dataStreamId == null || _engine == null || !_isInChannel) {
      LogService.warning('Cannot send reaction: dataStreamId=$_dataStreamId, engine=${_engine != null}, inChannel=$_isInChannel');
      return;
    }

    try {
      // CRITICAL: Use UTF-8 encoding for emojis to handle multi-byte characters correctly
      // codeUnits only works for ASCII - emojis need proper UTF-8 encoding
      final message = 'reaction:$emoji'; // Format: "reaction:👍"
      final messageBytes = utf8.encode(message); // Use UTF-8 encoding for emojis
      final data = Uint8List.fromList(messageBytes);
      
      LogService.info('📤 Sending reaction: emoji="$emoji", message="$message", bytes=${data.length}');
      
      await _engine!.sendStreamMessage(
        streamId: _dataStreamId!,
        data: data,
        length: data.length,
      );
      LogService.success('✅ Sent reaction via data stream: $emoji (streamId=$_dataStreamId, length=${data.length})');
    } catch (e) {
      LogService.error('❌ Failed to send reaction: $e');
      // Log detailed error for debugging
      LogService.warning('Reaction send details: dataStreamId=$_dataStreamId, inChannel=$_isInChannel, engine=${_engine != null}');
    }
  }

  /// Manually detect remote screen sharing
  /// Call this when setting up remote video view with VideoSourceType.videoSourceScreen
  /// Since onUserPublished is not available in this SDK version, we use manual detection
  void detectRemoteScreenSharing(int remoteUid, bool isSharing) {
    LogService.info('📺 Manual screen sharing detection: UID=$remoteUid, sharing=$isSharing');
    _screenSharingController.add({'uid': remoteUid, 'sharing': isSharing});
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_engine == null) return;

    try {
      await _engine!.switchCamera();
      LogService.info('Camera switched');
    } catch (e) {
      LogService.error('Failed to switch camera: $e');
      _errorController.add('Failed to switch camera: $e');
    }
  }

  /// Dispose Agora engine
  ///
  /// Should be called when app closes or when no longer needed.
  Future<void> dispose() async {
    try {
      await leaveChannel();
      
      if (_engine != null) {
        await _engine!.release();
        _engine = null;
      }

      _isInitialized = false;
      _updateState(AgoraSessionState.disconnected);
      
      await _stateController.close();
      await _userJoinedController.close();
      await _userOfflineController.close();
      await _connectionStateController.close();
      await _errorController.close();
      await _remoteVideoMutedController.close();
      await _remoteAudioMutedController.close();
      await _screenSharingController.close();
      await _userLeftController.close();
      await _remoteNetworkQualityController.close();
      await _reactionController.close();
      
      LogService.success('Agora engine disposed');
    } catch (e) {
      LogService.error('Error disposing Agora engine: $e');
    }
  }

  /// Adapt video quality based on network conditions
  Future<void> _adaptVideoQuality(QualityType quality) async {
    if (_engine == null || !_isInChannel) return;
    
    // Check cooldown to prevent rapid quality changes
    if (_lastQualityChange != null) {
      final timeSinceLastChange = DateTime.now().difference(_lastQualityChange!);
      if (timeSinceLastChange < _qualityChangeCooldown) {
        return; // Too soon to change quality again
      }
    }
    
    // Skip if quality hasn't changed significantly
    if (_lastNetworkQuality == quality && _currentQualityTier != null) {
      return;
    }
    
    _lastNetworkQuality = quality;
    
    VideoEncoderConfiguration targetConfig;
    String targetTier;
    
    // Determine target quality based on network conditions
    // Note: QualityType enum: excellent(0), good(1), poor(2), bad(3), veryBad(4), down(5), unsupported(6)
    if (quality == QualityType.qualityExcellent || quality == QualityType.qualityGood) {
      targetConfig = _quality1080p;
      targetTier = '1080p';
    } else if (quality == QualityType.qualityPoor) {
      targetConfig = _quality720pLowFps;
      targetTier = '720p-low';
    } else {
      // qualityBad, qualityVeryBad, qualityDown, or qualityUnsupported
      targetConfig = _quality480p;
      targetTier = '480p';
    }
    
    // Only change if different from current tier
    if (_currentQualityTier == targetTier) {
      return;
    }
    
    try {
      await _engine!.setVideoEncoderConfiguration(targetConfig);
      _currentQualityTier = targetTier;
      _lastQualityChange = DateTime.now();
      LogService.success('✅ Video quality adapted to $targetTier (network: $quality)');
      final dims = targetConfig.dimensions;
      if (dims != null) {
        LogService.info('📊 Quality config: ${dims.width}x${dims.height} @ ${targetConfig.frameRate}fps, ${targetConfig.bitrate}kbps');
      } else {
        LogService.info('📊 Quality config: @ ${targetConfig.frameRate}fps, ${targetConfig.bitrate}kbps');
      }
    } catch (e) {
      LogService.warning('Failed to adapt video quality: $e');
    }
  }
  
  /// Attempt to recover remote video stream
  Future<void> _attemptVideoRecovery(int remoteUid, RtcConnection connection) async {
    if (_engine == null || !_isInChannel) return;
    
    // Check cooldown
    final lastAttempt = _lastRecoveryAttempt[remoteUid];
    if (lastAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
      if (timeSinceLastAttempt < _recoveryCooldown) {
        return; // Too soon to retry
      }
    }
    
    // Check max attempts
    final attempts = _videoRecoveryAttempts[remoteUid] ?? 0;
    if (attempts >= _maxRecoveryAttempts) {
      LogService.warning('⚠️ Max video recovery attempts reached for UID=$remoteUid');
      return;
    }
    
    _videoRecoveryAttempts[remoteUid] = attempts + 1;
    _lastRecoveryAttempt[remoteUid] = DateTime.now();
    
    try {
      LogService.info('🔄 Attempting video recovery for UID=$remoteUid (attempt ${attempts + 1}/$_maxRecoveryAttempts)');
      
      // Note: Agora SDK automatically handles video subscription
      // Video recovery is primarily handled by the SDK's automatic reconnection
      // We log the recovery attempt and let the SDK handle the actual resubscription
      // The onRemoteVideoStateChanged event will fire when video becomes active again
      
      // Wait a bit to allow SDK to recover
      await Future.delayed(const Duration(milliseconds: 1000));
      
      LogService.info('✅ Video recovery attempt completed for UID=$remoteUid');
      LogService.info('💡 Video stream should recover automatically via Agora SDK');
      
      // Reset attempts on successful recovery (will be reset when video becomes active)
    } catch (e) {
      LogService.warning('Video recovery attempt failed for UID=$remoteUid: $e');
    }
  }
  
  /// Recover local camera after interruption
  Future<void> _recoverCamera() async {
    if (_engine == null || !_isInChannel || !_isVideoEnabled) return;
    if (_isRecoveringCamera) return;
    
    // Check cooldown
    if (_lastCameraRecoveryAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastCameraRecoveryAttempt!);
      if (timeSinceLastAttempt < _recoveryCooldown) {
        return;
      }
    }
    
    // Check max attempts
    if (_cameraRecoveryAttempts >= _maxCameraRecoveryAttempts) {
      LogService.warning('⚠️ Max camera recovery attempts reached');
      return;
    }
    
    _isRecoveringCamera = true;
    _cameraRecoveryAttempts++;
    _lastCameraRecoveryAttempt = DateTime.now();
    
    try {
      LogService.info('🔄 Attempting camera recovery (attempt $_cameraRecoveryAttempts/$_maxCameraRecoveryAttempts)');
      
      if (kIsWeb) {
        // Reinitialize local video with camera source
        await _engine!.setupLocalVideo(
          const VideoCanvas(
            uid: 0,
            sourceType: VideoSourceType.videoSourceCamera,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        await _engine!.muteLocalVideoStream(false);
      } else {
        // On mobile, restart preview
        await _engine!.startPreview();
      }
      
      LogService.success('✅ Camera recovery completed');
      _cameraRecoveryAttempts = 0; // Reset on success
    } catch (e) {
      LogService.warning('Camera recovery attempt failed: $e');
    } finally {
      _isRecoveringCamera = false;
    }
  }
  
  /// Handle reconnection logic
  Future<void> _handleReconnection(RtcConnection connection) async {
    if (_isReconnecting) return;
    
    _isReconnecting = true;
    LogService.info('🔄 Handling reconnection...');
    
    // Update connection if valid
    if (connection.channelId != null) {
      _currentConnection = connection;
    }
    
    _isReconnecting = false;
  }
  
  /// Attempt to rejoin channel after disconnection
  Future<void> _attemptReconnection() async {
    if (_isReconnecting) return;
    if (!_isInChannel && _lastSessionId == null) return; // No session to reconnect to
    
    // Check cooldown
    if (_lastReconnectionAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastReconnectionAttempt!);
      if (timeSinceLastAttempt < _reconnectionCooldown) {
        return;
      }
    }
    
    // Check max attempts
    if (_reconnectionAttempts >= _maxReconnectionAttempts) {
      LogService.error('❌ Max reconnection attempts reached');
      _errorController.add('Connection lost. Please refresh the page to reconnect.');
      return;
    }
    
    _isReconnecting = true;
    _reconnectionAttempts++;
    _lastReconnectionAttempt = DateTime.now();
    
    try {
      LogService.info('🔄 Attempting to reconnect (attempt $_reconnectionAttempts/$_maxReconnectionAttempts)');
      
      if (_lastSessionId != null && _lastUserId != null && _lastUserRole != null) {
        await joinChannel(
          sessionId: _lastSessionId!,
          userId: _lastUserId!,
          userRole: _lastUserRole!,
          initialCameraEnabled: _lastInitialCameraEnabled,
          initialMicEnabled: _lastInitialMicEnabled,
        );
        
        LogService.success('✅ Reconnection attempt completed');
        _reconnectionAttempts = 0; // Reset on success
      }
    } catch (e) {
      LogService.warning('Reconnection attempt failed: $e');
    } finally {
      _isReconnecting = false;
    }
  }
  
  /// Track remote user's network quality and detect instability
  void _trackRemoteNetworkQuality(int remoteUid, QualityType quality) {
    _remoteNetworkQualities[remoteUid] = quality;
    _remoteNetworkQualityTimestamps[remoteUid] = DateTime.now();
    
    // Determine if connection is unstable
    // Unstable = poor, bad, or down quality
    // Note: QualityType enum values: qualityExcellent(0), qualityGood(1), qualityPoor(2), qualityBad(3), qualityDown(5), qualityUnsupported(6)
    // Note: Some SDK versions may not have qualityVeryBad, so we only check for the standard values
    final isUnstable = quality == QualityType.qualityPoor ||
        quality == QualityType.qualityBad ||
        quality == QualityType.qualityDown;
    
    // Track consecutive poor quality reports
    if (isUnstable) {
      _remotePoorQualityCount[remoteUid] = (_remotePoorQualityCount[remoteUid] ?? 0) + 1;
    } else {
      // Reset count on good quality
      _remotePoorQualityCount[remoteUid] = 0;
    }
    
    // Only emit warning if we have multiple consecutive poor quality reports (to avoid flickering)
    // Require at least 2 consecutive poor reports to consider it unstable
    final consecutivePoorCount = _remotePoorQualityCount[remoteUid] ?? 0;
    final shouldWarn = isUnstable && consecutivePoorCount >= 2;
    
    // Emit network quality event
    _remoteNetworkQualityController.add({
      'uid': remoteUid,
      'quality': quality,
      'isUnstable': shouldWarn,
    });
    
    if (shouldWarn) {
      LogService.warning('⚠️ Remote user UID=$remoteUid has unstable connection (quality: $quality, consecutive poor: $consecutivePoorCount)');
    } else if (!isUnstable && consecutivePoorCount == 0) {
      LogService.info('✅ Remote user UID=$remoteUid connection is stable (quality: $quality)');
    }
  }
  
  /// Calculate optimal buffer size based on network quality
  int _calculateBufferSize(QualityType quality) {
    // Buffer size in milliseconds
    // Note: QualityType enum: excellent(0), good(1), poor(2), bad(3), veryBad(4), down(5), unsupported(6)
    if (quality == QualityType.qualityExcellent || quality == QualityType.qualityGood) {
      return 1000; // 1 second buffer for good networks
    } else if (quality == QualityType.qualityPoor) {
      return 1500; // 1.5 seconds for poor networks
    } else {
      return 2000; // 2 seconds for bad/very bad networks
    }
  }
  
  /// Perform video stream health check
  Future<void> _performVideoHealthCheck() async {
    if (_engine == null || !_isInChannel) return;
    
    // Check if remote video has been inactive for too long
    if (_lastRemoteVideoActivity != null && _lastActiveRemoteUid != null) {
      final timeSinceLastActivity = DateTime.now().difference(_lastRemoteVideoActivity!);
      if (timeSinceLastActivity > const Duration(seconds: 30)) {
        LogService.warning('⚠️ Remote video inactive for ${timeSinceLastActivity.inSeconds}s');
        
        // Attempt recovery if video should be active
        if (_lastActiveRemoteUid != null && _currentConnection != null) {
          await _attemptVideoRecovery(_lastActiveRemoteUid!, _currentConnection!);
        }
      }
    }
    
    // Verify local video is still publishing if enabled
    if (_isVideoEnabled) {
      try {
        // Ensure video is unmuted
        await _engine!.muteLocalVideoStream(false);
      } catch (e) {
        LogService.warning('Health check: Could not verify local video: $e');
      }
    }
  }
  
  /// Start video health check timer
  void _startVideoHealthCheck() {
    _stopVideoHealthCheck();
    _videoHealthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) {
      _performVideoHealthCheck();
    });
    LogService.info('✅ Video health check started');
  }
  
  /// Stop video health check timer
  void _stopVideoHealthCheck() {
    _videoHealthCheckTimer?.cancel();
    _videoHealthCheckTimer = null;
  }

  /// Register event handlers
  void _registerEventHandlers() {
    if (_engine == null) return;

    // User joined channel
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          LogService.success('Successfully joined channel (elapsed: ${elapsed}ms)');
          LogService.info('Channel: ${connection.channelId}, Local UID: ${connection.localUid}');
          LogService.info('Current UID in channel: ${_currentUID}');
          LogService.info('📹 Storing connection for video views: channelId=${connection.channelId}, localUid=${connection.localUid}');
          _isInChannel = true;
          _currentConnection = connection; // Store connection for video views
          LogService.info('✅ Connection stored - remote video views can now use this connection');
          
          // Reset reconnection attempts on successful join
          _reconnectionAttempts = 0;
          
          // Start video health check
          _startVideoHealthCheck();
          
          _updateState(AgoraSessionState.connected);
          
          // CRITICAL: Ensure video is publishing after joining (especially important for web)
          // Try multiple times with delays to ensure video publishes
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (_engine != null && _isInChannel && _isVideoEnabled) {
              try {
                // Explicitly unmute video stream
                await _engine!.muteLocalVideoStream(false);
                LogService.info('✅ Verified local video stream is unmuted (publishing) after join');
                LogService.info('📹 Your video should now be visible to remote users');
                
                // Try again after a short delay to ensure it sticks
                Future.delayed(const Duration(milliseconds: 1000), () async {
                  if (_engine != null && _isInChannel && _isVideoEnabled) {
                    try {
                      await _engine!.muteLocalVideoStream(false);
                      LogService.info('✅ Double-checked: Video stream is unmuted');
                    } catch (e) {
                      LogService.warning('Could not double-check video: $e');
                    }
                  }
                });
                
                // Start periodic check to ensure video stays unmuted
                _startVideoCheckTimer();
              } catch (e) {
                LogService.warning('Could not verify video publishing: $e');
              }
            } else {
              LogService.warning('⚠️ Cannot verify video publishing: engine=${_engine != null}, inChannel=$_isInChannel, videoEnabled=$_isVideoEnabled');
            }
          });
          
          // After joining, check for existing remote users
          // Note: onUserJoined only fires for users who join AFTER you
          // If both users join simultaneously, we need to wait for video events
          LogService.info('Waiting for remote user detection via video events...');
          LogService.info('💡 TIP: Make sure BOTH users (tutor AND learner) have joined the session');
          LogService.info('💡 TIP: Check that both users have different UIDs in their logs');
          LogService.info('💡 TIP: Remote user will be detected when they publish video/audio');
          
          // Schedule a check after a delay to provide diagnostic info
          Future.delayed(const Duration(seconds: 5), () {
            if (_isInChannel) {
              LogService.info('📊 Status check after 5 seconds:');
              LogService.info('   - In channel: $_isInChannel');
              LogService.info('   - Current UID: $_currentUID');
              LogService.info('   - Channel: $_currentChannelName');
              LogService.info('   - Video enabled: $_isVideoEnabled');
              LogService.info('   - Connection stored: ${_currentConnection != null}');
              LogService.info('💡 If no remote user detected, verify:');
              LogService.info('   1. Both users have joined (check both browser logs)');
              LogService.info('   2. Both users have different UIDs');
              LogService.info('   3. Both users granted camera/mic permissions');
              LogService.info('   4. Both users are in the same channel');
              LogService.info('   5. Both users have cameras enabled');
            }
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          LogService.success('✅ Remote user joined channel: UID=$remoteUid (elapsed: ${elapsed}ms)');
          LogService.info('Connection details: channelId=${connection.channelId}, localUid=${connection.localUid}');
          LogService.info('💡 Remote video is automatically subscribed by default');
          LogService.info('📹 Current stored connection: channelId=${_currentConnection?.channelId}, localUid=${_currentConnection?.localUid}');
          // Ensure connection is stored (in case onJoinChannelSuccess didn't fire yet)
          if (_currentConnection == null && connection.channelId != null) {
            _currentConnection = connection;
            LogService.info('✅ Connection stored from onUserJoined event');
          }
          
          // CRITICAL: Reset offline tracking when user rejoins
          _resetUserOfflineTracking(remoteUid);
          
          _userJoinedController.add(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          LogService.info('User offline: $remoteUid, reason: $reason');
          
          // Handle different offline reasons
          String reasonText = 'Unknown';
          bool isDefinitiveLeave = false;
          switch (reason) {
            case UserOfflineReasonType.userOfflineQuit:
              reasonText = 'User left normally';
              isDefinitiveLeave = true; // User explicitly quit - no grace period needed
              break;
            case UserOfflineReasonType.userOfflineDropped:
              reasonText = 'User connection dropped (network issue)';
              isDefinitiveLeave = false; // Could be temporary - use grace period
              break;
            case UserOfflineReasonType.userOfflineBecomeAudience:
              reasonText = 'User became audience';
              isDefinitiveLeave = true;
              break;
            default:
              reasonText = 'User went offline';
              isDefinitiveLeave = false; // Unknown reason - use grace period
          }
          
          LogService.info('📤 Remote user offline: UID=$remoteUid ($reasonText, definitive: $isDefinitiveLeave)');
          
          // Track offline timestamp
          _userOfflineTimestamps[remoteUid] = DateTime.now();
          _userOfflineCount[remoteUid] = (_userOfflineCount[remoteUid] ?? 0) + 1;
          
          // Cancel any existing grace period timer for this user
          _userLeftGracePeriodTimers[remoteUid]?.cancel();
          
          // If user explicitly quit, confirm immediately
          if (isDefinitiveLeave) {
            _confirmUserLeft(remoteUid);
          } else {
            // For network drops, use grace period to distinguish from temporary connectivity issues
            // Start grace period timer
            _userLeftGracePeriodTimers[remoteUid] = Timer(_userLeftGracePeriod, () {
              // After grace period, check if user has come back
              final offlineTime = _userOfflineTimestamps[remoteUid];
              if (offlineTime != null) {
                final timeSinceOffline = DateTime.now().difference(offlineTime);
                // If still offline after grace period and multiple offline events, confirm left
                if (timeSinceOffline >= _userLeftGracePeriod && 
                    (_userOfflineCount[remoteUid] ?? 0) >= _maxOfflineEvents) {
                  _confirmUserLeft(remoteUid);
                } else {
                  // User might be reconnecting - don't confirm left yet
                  LogService.info('⏳ User $remoteUid still offline but may be reconnecting...');
                }
              }
            });
            
            // Emit connection unstable event instead of user left
            _remoteNetworkQualityController.add({
              'uid': remoteUid,
              'quality': QualityType.qualityDown,
              'isUnstable': true,
              'message': 'Connection dropped - reconnecting...',
            });
          }
          
          _userOfflineController.add(remoteUid);
        },
        // Detect when remote video is first decoded (user might already be in channel)
        // This is CRITICAL for detecting users who joined before you
        onFirstRemoteVideoDecoded: (RtcConnection connection, int remoteUid, int width, int height, int elapsed) {
          LogService.success('✅ Remote video decoded: UID=$remoteUid (${width}x${height}, elapsed: ${elapsed}ms)');
          LogService.info('This indicates a remote user is in the channel and publishing video');
          LogService.info('💡 Video stream is automatically subscribed - video should display now');
          LogService.info('📹 Connection for video view: channelId=${connection.channelId}, localUid=${connection.localUid}');
          // Ensure connection is stored
          if (_currentConnection == null && connection.channelId != null) {
            _currentConnection = connection;
            LogService.info('✅ Connection stored from onFirstRemoteVideoDecoded event');
          }
          
          // CRITICAL: Reset offline tracking when video is decoded (user is active)
          _resetUserOfflineTracking(remoteUid);
          
          // If we haven't detected this user yet, add them
          _userJoinedController.add(remoteUid);
        },
        // Also detect when remote audio is first decoded
        onFirstRemoteAudioDecoded: (RtcConnection connection, int remoteUid, int elapsed) {
          LogService.success('✅ Remote audio decoded: UID=$remoteUid (elapsed: ${elapsed}ms)');
          LogService.info('This indicates a remote user is in the channel and publishing audio');
          // Add user if not already detected
          _userJoinedController.add(remoteUid);
        },
        // Detect remote video state changes
        onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid, RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
          LogService.info('Remote video state changed: UID=$remoteUid, state=$state, reason=$reason');
          if (state == RemoteVideoState.remoteVideoStateStarting || 
              state == RemoteVideoState.remoteVideoStateDecoding) {
            // Video is starting/decoding - user is active and camera is ON
            LogService.info('✅ Remote video is active for UID=$remoteUid');
            LogService.info('💡 Video stream is automatically subscribed - video should display');
            
            // Track video activity for health check
            _lastRemoteVideoActivity = DateTime.now();
            _lastActiveRemoteUid = remoteUid;
            
            // Reset recovery attempts on successful video activity
            _videoRecoveryAttempts.remove(remoteUid);
            _lastRecoveryAttempt.remove(remoteUid);
            
            // Reset screen-off detection when video becomes active
            _resetScreenOffDetection(remoteUid);
            
            _userJoinedController.add(remoteUid);
            // Emit video unmuted event
            _remoteVideoMutedController.add({'uid': remoteUid, 'muted': false});
          } else if (state == RemoteVideoState.remoteVideoStateStopped) {
            LogService.info('Remote video stopped for UID=$remoteUid (reason: $reason)');
            if (reason == RemoteVideoStateReason.remoteVideoStateReasonRemoteMuted) {
              LogService.warning('⚠️ Remote user has camera OFF - video will not display');
              LogService.warning('💡 Ask the remote user to enable their camera');
              // Emit video muted event
              _remoteVideoMutedController.add({'uid': remoteUid, 'muted': true});
              // Reset screen-off detection (camera is intentionally off)
              _resetScreenOffDetection(remoteUid);
            } else {
              // Video stopped for non-mute reason - could be screen-off or network issue
              LogService.warning('⚠️ Remote video stopped unexpectedly (reason: $reason)');
              
              // Track when video stopped
              _remoteVideoStoppedTimestamps[remoteUid] = DateTime.now();
              
              // Check if audio is still active - if yes, likely screen-off
              final audioActive = _remoteAudioActive[remoteUid] ?? false;
              if (audioActive) {
                // Audio is active but video stopped - likely screen-off
                LogService.info('📱 Remote video stopped but audio active - possible screen-off detected');
                _startScreenOffDetection(remoteUid);
              } else {
                // Both video and audio stopped - likely network issue or user left
                LogService.warning('⚠️ Remote video stopped unexpectedly (reason: $reason) - attempting recovery');
                _attemptVideoRecovery(remoteUid, connection);
              }
            }
            // Still add user to stream so UI can render (will show black screen or profile)
            _userJoinedController.add(remoteUid);
          }
        },
        // Detect remote audio state changes
        onRemoteAudioStateChanged: (RtcConnection connection, int remoteUid, RemoteAudioState state, RemoteAudioStateReason reason, int elapsed) {
          LogService.info('Remote audio state changed: UID=$remoteUid, state=$state, reason=$reason');
          if (state == RemoteAudioState.remoteAudioStateStarting ||
              state == RemoteAudioState.remoteAudioStateDecoding) {
            // Audio is active - user is in channel and mic is ON
            LogService.info('Remote audio is active for UID=$remoteUid');
            _remoteAudioActive[remoteUid] = true;
            _userJoinedController.add(remoteUid);
            // Emit audio unmuted event
            _remoteAudioMutedController.add({'uid': remoteUid, 'muted': false});
            
            // If video is stopped but audio is active, check for screen-off
            if (_remoteVideoStoppedTimestamps.containsKey(remoteUid)) {
              final videoStoppedTime = _remoteVideoStoppedTimestamps[remoteUid]!;
              final timeSinceVideoStopped = DateTime.now().difference(videoStoppedTime);
              if (timeSinceVideoStopped < _screenOffDetectionDelay) {
                // Video just stopped but audio is active - likely screen-off
                LogService.info('📱 Audio active but video stopped - possible screen-off for UID=$remoteUid');
                _startScreenOffDetection(remoteUid);
              }
            }
          } else if (state == RemoteAudioState.remoteAudioStateStopped) {
            _remoteAudioActive[remoteUid] = false;
            if (reason == RemoteAudioStateReason.remoteAudioReasonRemoteMuted) {
              LogService.info('Remote user mic is muted for UID=$remoteUid');
              // Emit audio muted event
              _remoteAudioMutedController.add({'uid': remoteUid, 'muted': true});
            }
            // Reset screen-off detection if audio also stopped
            _resetScreenOffDetection(remoteUid);
          }
        },
        // Track local video publishing state (important for debugging)
        onLocalVideoStateChanged: (VideoSourceType sourceType, LocalVideoStreamState state, LocalVideoStreamReason reason) {
          LogService.info('📹 Local video state changed: sourceType=$sourceType, state=$state, reason=$reason');
          if (state == LocalVideoStreamState.localVideoStreamStateCapturing) {
            LogService.success('✅ Local video is capturing (camera active)');
            // When capturing starts, ensure it's not muted so it publishes
            if (_engine != null && _isInChannel) {
              _engine!.muteLocalVideoStream(false).catchError((e) {
                LogService.warning('Could not unmute video after capturing: $e');
              });
            }
          } else if (state == LocalVideoStreamState.localVideoStreamStateEncoding) {
            LogService.success('✅ Local video is encoding (publishing to remote users)');
            LogService.info('📹 REMOTE USERS CAN NOW SEE YOUR VIDEO');
            // Ensure it's not muted
            if (_engine != null) {
              _engine!.muteLocalVideoStream(false).catchError((e) {
                LogService.warning('Could not ensure video is unmuted: $e');
              });
            }
          } else if (state == LocalVideoStreamState.localVideoStreamStateFailed) {
            LogService.error('❌ Local video failed: reason=$reason');
            
            // Check if it's a permission-related failure
            final reasonStr = reason.toString().toLowerCase();
            if (reasonStr.contains('permission') || 
                reasonStr.contains('denied') || 
                reasonStr.contains('notallowed')) {
              LogService.error('❌ Camera permission denied or not granted');
              LogService.error('💡 To fix:');
              LogService.error('   1. Click the camera/mic icon in the browser address bar');
              LogService.error('   2. Set camera and microphone to "Allow"');
              LogService.error('   3. Refresh the page and try again');
              _errorController.add('Camera permission denied. Please allow camera access in browser settings and refresh.');
              _updateState(AgoraSessionState.error);
            } else {
              // Camera failure for non-permission reasons - attempt recovery
              LogService.warning('⚠️ Camera failed (reason: $reason) - attempting recovery');
              if (!_isRecoveringCamera && _isVideoEnabled) {
                _recoverCamera();
              }
              LogService.error('💡 Check camera permissions and ensure camera is not in use by another app');
              LogService.error('💡 If testing on same device with two browsers, only one can access camera at a time');
              LogService.error('💡 Try closing the other browser and refreshing');
            }
          } else if (state == LocalVideoStreamState.localVideoStreamStateStopped) {
            LogService.warning('⚠️ Local video stopped - not publishing to remote users');
            LogService.warning('💡 Your video will not be visible to others');
            LogService.warning('💡 Check if camera is enabled and permissions are granted');
            
            // CRITICAL: If video stopped but we think it should be enabled, try to unmute
            if (_isVideoEnabled && _engine != null && _isInChannel) {
              LogService.warning('⚠️ Video stopped but videoEnabled=true - attempting to unmute...');
              Future.delayed(const Duration(milliseconds: 500), () async {
                if (_engine != null && _isInChannel && _isVideoEnabled) {
                  try {
                    await _engine!.muteLocalVideoStream(false);
                    LogService.info('✅ Attempted to unmute video after it stopped');
                  } catch (e) {
                    LogService.warning('Could not unmute video after stop: $e');
                  }
                }
              });
            }
          } else {
            LogService.info('📹 Local video state: $state (reason: $reason)');
          }
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          LogService.info('Connection state: $state, reason: $reason');
          LogService.info('Connection details: channelId=${connection.channelId}, localUid=${connection.localUid}');
          _connectionStateController.add(state);
          
          // Update connection when we have valid channelId
          if (connection.channelId != null) {
            _currentConnection = connection;
          }
          
            // Handle banned by server - this is critical
            if (reason == ConnectionChangedReasonType.connectionChangedBannedByServer) {
              LogService.error('❌ Connection banned by server! This may indicate:');
              LogService.error('   - Duplicate UID in channel');
              LogService.error('   - Invalid token');
              LogService.error('   - Network/firewall issues');
              LogService.error('   - Agora service restrictions');
              _errorController.add('Connection was rejected by server. Please try again.');
              _isInChannel = false;
              _currentConnection = null; // Clear connection on ban
              _stopVideoHealthCheck();
              _updateState(AgoraSessionState.error);
              return;
            }
          
          // Update session state based on connection state
          // Note: onJoinChannelSuccess is the primary indicator of successful join
          if (state == ConnectionStateType.connectionStateConnected) {
            // Update connection when state changes to connected (if channelId is set)
            if (connection.channelId != null && _currentConnection == null) {
              _currentConnection = connection;
            }
            // Only update if we're not already connected (onJoinChannelSuccess handles this)
            if (_state != AgoraSessionState.connected) {
              _updateState(AgoraSessionState.connected);
            }
            LogService.info('✅ Connection established - waiting for remote user...');
          } else if (state == ConnectionStateType.connectionStateDisconnected) {
            _isInChannel = false;
            _currentConnection = null; // Clear connection on disconnect
            _stopVideoHealthCheck();
            // Don't set disconnected if we were banned (error state already set)
            if (reason != ConnectionChangedReasonType.connectionChangedBannedByServer) {
              _updateState(AgoraSessionState.disconnected);
              // Attempt automatic reconnection
              _attemptReconnection();
            }
          } else if (state == ConnectionStateType.connectionStateReconnecting) {
            _updateState(AgoraSessionState.reconnecting);
            LogService.info('🔄 Reconnecting to channel...');
            _handleReconnection(connection);
          } else if (state == ConnectionStateType.connectionStateConnecting) {
            _updateState(AgoraSessionState.joining);
          }
        },
        onError: (ErrorCodeType err, String msg) {
          LogService.error('Agora error: $err, $msg');
          
          // Check for permission-related errors
          final errorMsg = msg.toLowerCase();
          if (errorMsg.contains('permission') || 
              errorMsg.contains('denied') || 
              errorMsg.contains('notallowed') ||
              errorMsg.contains('not allowed') ||
              errorMsg.contains('getusermedia')) {
            LogService.error('❌ Permission error detected: $msg');
            LogService.error('💡 Camera/microphone permission was denied');
            LogService.error('💡 To fix:');
            LogService.error('   1. Click the camera/mic icon in the browser address bar');
            LogService.error('   2. Set camera and microphone to "Allow"');
            LogService.error('   3. Refresh the page and try again');
            _errorController.add('Camera/microphone permission denied. Please allow access in browser settings (click camera icon in address bar) and refresh the page.');
            _updateState(AgoraSessionState.error);
            return;
          }
          
          _errorController.add('Error $err: $msg');
          
          // Don't set error state for join channel rejected if we're still trying
          // The connection state handler will manage state transitions
          if (err == ErrorCodeType.errJoinChannelRejected) {
            LogService.error('❌ Join channel rejected: $msg');
            String errorMsg = 'Failed to join video session. ';
            
            // Provide specific error messages
            if (msg.contains('appid') || msg.contains('Invalid appid') || msg.contains('appId')) {
              errorMsg = 'Invalid Agora App ID. Please check server configuration.';
            } else if (msg.contains('token') || msg.contains('Token')) {
              errorMsg = 'Invalid or expired token. Please try again.';
            } else if (msg.contains('channel') || msg.contains('Channel')) {
              errorMsg = 'Invalid channel name. Please check session configuration.';
            } else if (msg.contains('uid') || msg.contains('UID')) {
              errorMsg = 'Invalid user ID. Please try again.';
            } else {
              errorMsg = 'Unable to join video session. This may be due to:\n'
                  '• Invalid session configuration\n'
                  '• Network connectivity issues\n'
                  '• Server authentication problems\n\n'
                  'Please try again or contact support.';
            }
            
            _errorController.add(errorMsg);
            _updateState(AgoraSessionState.error);
          } else {
            _updateState(AgoraSessionState.error);
          }
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          LogService.warning('Token will expire soon, should refresh');
          // TODO: Implement token refresh
        },
        // Network quality monitoring for adaptive bitrate
        onNetworkQuality: (RtcConnection connection, int remoteUid, QualityType txQuality, QualityType rxQuality) {
          // Adjust video quality based on network conditions
          // QualityType: excellent(0), good(1), poor(2), bad(3), veryBad(4), down(5), unsupported(6)
          if (remoteUid == 0) {
            // Local network quality - adapt video quality proactively
            _adaptVideoQuality(rxQuality);
            
            // Update buffer settings based on network quality
            try {
              if (_engine != null) {
                final bufferSize = _calculateBufferSize(rxQuality);
                // Note: setBufferSettings may not be available in all SDK versions
                // This is a best-effort optimization
              }
            } catch (e) {
              // Silently fail if buffer settings not supported
            }
          } else {
            // Remote user's network quality - track and detect instability
            _trackRemoteNetworkQuality(remoteUid, rxQuality);
          }
        },
        // Receive data stream messages for screen sharing notifications and reactions
        onStreamMessage: (RtcConnection connection, int remoteUid, int streamId, Uint8List data, int length, int sentTs) {
          try {
            // CRITICAL: Use UTF-8 decoding to properly handle emoji characters
            // String.fromCharCodes only works for ASCII - emojis need UTF-8 decoding
            final message = utf8.decode(data, allowMalformed: true);
            LogService.info('📨 Received data stream message from UID=$remoteUid, streamId=$streamId, length=$length: "$message"');
            
            if (message == 'screen_share_start') {
              LogService.success('✅ Remote user started screen sharing: UID=$remoteUid');
              
              // Note: Agora SDK automatically handles video subscription for screen sharing
              // The VideoViewController.remote in AgoraVideoViewWidget will handle
              // the source type configuration when the widget rebuilds with sourceType=videoSourceScreen
              // The UI will rebuild when _screenSharingController emits the event
              // No need to explicitly call muteRemoteVideoStream - SDK handles subscription automatically
              LogService.info('💡 UI will rebuild to show screen sharing stream');
              
              _screenSharingController.add({'uid': remoteUid, 'sharing': true});
            } else if (message == 'screen_share_stop') {
              LogService.info('📺 Remote user stopped screen sharing: UID=$remoteUid');
              
              // Note: The VideoViewController.remote in AgoraVideoViewWidget will handle
              // switching back to camera source when the widget rebuilds with sourceType=videoSourceCamera
              // The UI will rebuild when _screenSharingController emits the event
              LogService.info('💡 UI will rebuild to show camera stream');
              
              _screenSharingController.add({'uid': remoteUid, 'sharing': false});
            } else if (message.startsWith('reaction:')) {
              final emoji = message.substring(9); // Extract emoji after "reaction:"
              LogService.success('🎉 Received reaction from UID=$remoteUid: emoji="$emoji"');
              
              // Verify emoji is not empty
              if (emoji.isNotEmpty) {
                _reactionController.add({'uid': remoteUid, 'emoji': emoji});
                LogService.info('✅ Reaction added to stream: UID=$remoteUid, emoji="$emoji"');
              } else {
                LogService.warning('⚠️ Received reaction with empty emoji from UID=$remoteUid');
              }
            } else {
              LogService.debug('Unknown data stream message format: "$message"');
            }
          } catch (e) {
            LogService.error('❌ Error parsing data stream message: $e');
            LogService.debug('Data stream details: remoteUid=$remoteUid, streamId=$streamId, length=$length, data=${data.length} bytes');
          }
        },
      ),
    );
  }

  /// Confirm that a user has actually left (not just poor connection)
  void _confirmUserLeft(int remoteUid) {
    if (_userConfirmedLeft[remoteUid] == true) {
      return; // Already confirmed
    }
    
    _userConfirmedLeft[remoteUid] = true;
    LogService.info('✅ Confirmed user $remoteUid has left the session');
    
    // Cancel grace period timer
    _userLeftGracePeriodTimers[remoteUid]?.cancel();
    _userLeftGracePeriodTimers.remove(remoteUid);
    
    // Emit user left event - this will trigger UI to show "user left" message
    _userLeftController.add(remoteUid);
  }
  
  /// Reset offline tracking when user rejoins or becomes active
  void _resetUserOfflineTracking(int remoteUid) {
    // Cancel grace period timer if user rejoins
    _userLeftGracePeriodTimers[remoteUid]?.cancel();
    _userLeftGracePeriodTimers.remove(remoteUid);
    
    // Reset offline tracking
    _userOfflineTimestamps.remove(remoteUid);
    _userOfflineCount.remove(remoteUid);
    _userConfirmedLeft[remoteUid] = false;
    
    // Emit connection stable event
    _remoteNetworkQualityController.add({
      'uid': remoteUid,
      'quality': _remoteNetworkQualities[remoteUid] ?? QualityType.qualityGood,
      'isUnstable': false,
      'message': 'Connection restored',
    });
    
    LogService.info('✅ Reset offline tracking for user $remoteUid - user is active');
  }
  
  /// Start screen-off detection timer
  void _startScreenOffDetection(int remoteUid) {
    // Cancel existing timer
    _screenOffDetectionTimers[remoteUid]?.cancel();
    
    // Start new timer
    _screenOffDetectionTimers[remoteUid] = Timer(_screenOffDetectionDelay, () {
      // Check if video is still stopped and audio is still active
      final videoStoppedTime = _remoteVideoStoppedTimestamps[remoteUid];
      final audioActive = _remoteAudioActive[remoteUid] ?? false;
      
      if (videoStoppedTime != null && audioActive) {
        final timeSinceVideoStopped = DateTime.now().difference(videoStoppedTime);
        if (timeSinceVideoStopped >= _screenOffDetectionDelay) {
          // Video stopped for delay period but audio is active - likely screen-off
          _remoteScreenOff[remoteUid] = true;
          _remoteScreenOffController.add({'uid': remoteUid, 'screenOff': true});
          LogService.info('📱 Confirmed screen-off for user $remoteUid');
        }
      }
    });
  }
  
  /// Reset screen-off detection
  void _resetScreenOffDetection(int remoteUid) {
    _screenOffDetectionTimers[remoteUid]?.cancel();
    _screenOffDetectionTimers.remove(remoteUid);
    _remoteVideoStoppedTimestamps.remove(remoteUid);
    
    if (_remoteScreenOff[remoteUid] == true) {
      _remoteScreenOff[remoteUid] = false;
      _remoteScreenOffController.add({'uid': remoteUid, 'screenOff': false});
      LogService.info('✅ Screen back on for user $remoteUid');
    }
  }

  /// Update state and notify listeners
  void _updateState(AgoraSessionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }
}

