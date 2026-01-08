import 'dart:async';
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
  AgoraSessionState _state = AgoraSessionState.disconnected;
  bool _isVideoEnabled = true; // Track video state manually
  bool _isAudioEnabled = true; // Track audio state manually
  
  // Event streams
  final _stateController = StreamController<AgoraSessionState>.broadcast();
  final _userJoinedController = StreamController<int>.broadcast();
  final _userOfflineController = StreamController<int>.broadcast();
  final _connectionStateController = StreamController<ConnectionStateType>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Getters
  Stream<AgoraSessionState> get stateStream => _stateController.stream;
  Stream<int> get userJoinedStream => _userJoinedController.stream;
  Stream<int> get userOfflineStream => _userOfflineController.stream;
  Stream<ConnectionStateType> get connectionStateStream => _connectionStateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  
  AgoraSessionState get state => _state;
  bool get isInitialized => _isInitialized;
  bool get isInChannel => _isInChannel;
  String? get currentChannelName => _currentChannelName;
  int? get currentUID => _currentUID;

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
      
      // Initialize with proper context
      // For web, we might need to handle permissions differently
      await _engine!.initialize(
        RtcEngineContext(
          appId: '', // Will be set from token
          channelProfile: ChannelProfileType.channelProfileCommunication,
          // Add area code for better connection (optional)
          // areaCode: AreaCode.areaCodeGlob,
        ),
      );

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
  Future<void> joinChannel({
    required String sessionId,
    required String userId,
    required String userRole,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isInChannel) {
      LogService.warning('Already in channel: $_currentChannelName');
      return;
    }

    try {
      _updateState(AgoraSessionState.joining);

      // Fetch token from backend
      final tokenData = await AgoraTokenService.fetchToken(sessionId);
      
      _currentChannelName = tokenData['channelName'] as String;
      _currentUID = tokenData['uid'] as int;
      final token = tokenData['token'] as String;

      // Enable video and audio
      // On web, some methods might not be available or work differently
      try {
        await _engine!.enableVideo();
        await _engine!.enableAudio();
        
        // startPreview might not be available on web
        if (!kIsWeb) {
          await _engine!.startPreview();
        }
        
        _isVideoEnabled = true;
        _isAudioEnabled = true;
      } catch (e) {
        LogService.warning('Error enabling video/audio (may be web-specific): $e');
        // Continue anyway - some platforms might handle this differently
        _isVideoEnabled = true;
        _isAudioEnabled = true;
      }

      // Join channel
      await _engine!.joinChannel(
        token: token,
        channelId: _currentChannelName!,
        uid: _currentUID!,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      _isInChannel = true;
      _updateState(AgoraSessionState.connected);
      LogService.success('Joined Agora channel: $_currentChannelName');
    } catch (e) {
      LogService.error('Failed to join channel: $e');
      _updateState(AgoraSessionState.error);
      _errorController.add('Failed to join: $e');
      rethrow;
    }
  }

  /// Leave Agora channel
  Future<void> leaveChannel() async {
    if (!_isInChannel || _engine == null) {
      return;
    }

    try {
      _updateState(AgoraSessionState.leaving);
      
      await _engine!.leaveChannel();
      
      _isInChannel = false;
      _currentChannelName = null;
      _currentUID = null;
      _updateState(AgoraSessionState.disconnected);
      
      LogService.success('Left Agora channel');
    } catch (e) {
      LogService.error('Failed to leave channel: $e');
      _errorController.add('Failed to leave: $e');
      rethrow;
    }
  }

  /// Toggle local video (camera on/off)
  Future<void> toggleVideo() async {
    if (_engine == null) return;

    try {
      _isVideoEnabled = !_isVideoEnabled;
      await _engine!.muteLocalVideoStream(!_isVideoEnabled);
      LogService.info('Video ${_isVideoEnabled ? 'enabled' : 'disabled'}');
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
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          LogService.info('User joined: $remoteUid');
          _userJoinedController.add(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          LogService.info('User offline: $remoteUid, reason: $reason');
          _userOfflineController.add(remoteUid);
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          LogService.info('Connection state: $state, reason: $reason');
          _connectionStateController.add(state);
          
          // Update session state based on connection state
          if (state == ConnectionStateType.connectionStateConnected) {
            _updateState(AgoraSessionState.connected);
          } else if (state == ConnectionStateType.connectionStateDisconnected) {
            _updateState(AgoraSessionState.disconnected);
          } else if (state == ConnectionStateType.connectionStateReconnecting) {
            _updateState(AgoraSessionState.reconnecting);
          }
        },
        onError: (ErrorCodeType err, String msg) {
          LogService.error('Agora error: $err, $msg');
          _errorController.add('Error $err: $msg');
          _updateState(AgoraSessionState.error);
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          LogService.warning('Token will expire soon, should refresh');
          // TODO: Implement token refresh
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

