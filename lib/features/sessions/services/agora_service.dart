import 'dart:async';
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
  int? _dataStreamId; // Data stream ID for sending screen sharing notifications
  
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
              await _engine!.setupLocalVideo(const VideoCanvas(uid: 0));
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

      // Create data stream for screen sharing notifications
      try {
        _dataStreamId = await _engine!.createDataStream(
          const DataStreamConfig(
            syncWithAudio: false,
            ordered: true,
          ),
        );
        LogService.success('✅ Data stream created for screen sharing notifications: $_dataStreamId');
      } catch (e) {
        LogService.warning('Could not create data stream: $e');
        // Continue without data stream - screen sharing detection will be manual
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
      
      // Try to leave channel with timeout and error handling
      try {
        await _engine!.leaveChannel().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            LogService.warning('Leave channel timeout - forcing disconnect');
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
            
            // Force camera access by setting up local video view
            await _engine!.setupLocalVideo(const VideoCanvas(uid: 0));
            LogService.info('✅ Local video view set up');
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
      if (kIsWeb) {
        // For web, use startScreenCapture
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
        LogService.success('✅ Screen sharing started');
        _screenSharingController.add({'uid': _currentUID, 'sharing': true});
        
        // Notify remote users via data stream
        _notifyRemoteUsersScreenSharing(true);
      } else {
        // For mobile, screen sharing may require different implementation
        LogService.warning('Screen sharing on mobile may require platform-specific implementation');
        throw Exception('Screen sharing not fully supported on mobile yet');
      }
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
      LogService.success('✅ Screen sharing stopped');
      _screenSharingController.add({'uid': _currentUID, 'sharing': false});
      
      // Notify remote users via data stream
      _notifyRemoteUsersScreenSharing(false);
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
      
      await _engine!.sendStreamMessage(
        streamId: _dataStreamId!,
        data: Uint8List.fromList(messageBytes),
      );
      LogService.success('✅ Sent screen sharing notification: $message');
    } catch (e) {
      LogService.warning('Failed to send screen sharing notification: $e');
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
      
      LogService.success('Agora engine disposed');
    } catch (e) {
      LogService.error('Error disposing Agora engine: $e');
    }
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
          _userJoinedController.add(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          LogService.info('User offline: $remoteUid, reason: $reason');
          
          // Handle different offline reasons
          String reasonText = 'Unknown';
          switch (reason) {
            case UserOfflineReasonType.userOfflineQuit:
              reasonText = 'User left normally';
              break;
            case UserOfflineReasonType.userOfflineDropped:
              reasonText = 'User connection dropped (network issue)';
              break;
            case UserOfflineReasonType.userOfflineBecomeAudience:
              reasonText = 'User became audience';
              break;
            default:
              reasonText = 'User went offline';
          }
          
          LogService.info('📤 Remote user left: UID=$remoteUid ($reasonText)');
          
          _userOfflineController.add(remoteUid);
          // Emit user left event - this will trigger UI to show profile card
          _userLeftController.add(remoteUid);
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
            }
            // Still add user to stream so UI can render (will show black screen)
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
            _userJoinedController.add(remoteUid);
            // Emit audio unmuted event
            _remoteAudioMutedController.add({'uid': remoteUid, 'muted': false});
          } else if (state == RemoteAudioState.remoteAudioStateStopped) {
            if (reason == RemoteAudioStateReason.remoteAudioReasonRemoteMuted) {
              LogService.info('Remote user mic is muted for UID=$remoteUid');
              // Emit audio muted event
              _remoteAudioMutedController.add({'uid': remoteUid, 'muted': true});
            }
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
            // Don't set disconnected if we were banned (error state already set)
            if (reason != ConnectionChangedReasonType.connectionChangedBannedByServer) {
              _updateState(AgoraSessionState.disconnected);
            }
          } else if (state == ConnectionStateType.connectionStateReconnecting) {
            _updateState(AgoraSessionState.reconnecting);
            LogService.info('🔄 Reconnecting to channel...');
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
            // Local network quality
            if (rxQuality == QualityType.qualityExcellent || rxQuality == QualityType.qualityGood) {
              // Good network - can use higher quality (1080p)
              // Video encoder is already configured with adaptive settings
            } else if (rxQuality == QualityType.qualityPoor || rxQuality == QualityType.qualityBad) {
              // Poor network - may need to reduce quality
              // Agora SDK handles this automatically with degradationPreference
              LogService.warning('⚠️ Network quality is poor - video quality may be reduced automatically');
            }
          }
        },
        // Receive data stream messages for screen sharing notifications
        onStreamMessage: (RtcConnection connection, int remoteUid, int streamId, Uint8List data, int length, int sentTs) {
          try {
            final message = String.fromCharCodes(data);
            LogService.info('📨 Received data stream message from UID=$remoteUid: $message');
            
            if (message == 'screen_share_start') {
              LogService.success('✅ Remote user started screen sharing: UID=$remoteUid');
              _screenSharingController.add({'uid': remoteUid, 'sharing': true});
            } else if (message == 'screen_share_stop') {
              LogService.info('📺 Remote user stopped screen sharing: UID=$remoteUid');
              _screenSharingController.add({'uid': remoteUid, 'sharing': false});
            }
          } catch (e) {
            LogService.warning('Error parsing data stream message: $e');
          }
        },
      ),
    );
  }

  /// Update state and notify listeners
  void _updateState(AgoraSessionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }
}

