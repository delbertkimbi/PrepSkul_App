import 'dart:async';
import 'dart:convert'; // For UTF-8 encoding/decoding of emojis
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/sessions/services/agora_token_service.dart';
import 'package:prepskul/features/sessions/models/agora_session_state.dart';
import 'package:prepskul/features/sessions/domain/quality_controller.dart';
import 'package:prepskul/features/sessions/domain/speaking_uid_debouncer.dart';
import 'package:prepskul/features/sessions/domain/reconnect_grace_policy.dart';
import 'package:prepskul/features/sessions/domain/stream_priority_policy.dart';
import 'package:prepskul/features/sessions/domain/network_quality_combine.dart';
import 'package:prepskul/features/sessions/services/qoe_telemetry_service.dart';
import 'package:prepskul/features/sessions/services/session_mode_statistics_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  DateTime? _lastEnsureVideoUnmutedAt;
  static const Duration _ensureVideoUnmutedCooldown = Duration(seconds: 2);
  int? _dataStreamId; // Data stream ID for sending screen sharing notifications
  RealtimeChannel?
  _reactionChannel; // Supabase Realtime fallback for reactions (web / when Agora data stream fails)

  // Network quality adaptation state
  /// Latest TX quality from [RtcEngineEventHandler.onNetworkQuality] (remoteUid == 0).
  QualityType? _lastObservedTxQuality;

  bool _tokenRenewInFlight = false;
  final QualityController _qualityController = QualityController();
  final SpeakingUidDebouncer _speakingDebouncer = SpeakingUidDebouncer();
  final ReconnectGracePolicy _reconnectGracePolicy =
      const ReconnectGracePolicy();
  final StreamPriorityPolicy _streamPriorityPolicy =
      const StreamPriorityPolicy();
  final Set<int> _remoteParticipantUids = <int>{};
  int? _spotlightRemoteUid;

  /// Gallery-only: pinned tile requests HIGH dual-stream alongside speaker spotlight.
  int? _dualStreamPinnedRemoteUid;

  /// Last effective visible-remote set for gallery paging (`muteRemoteVideoStream`).
  Set<int>? _galleryPagingLastEffectiveVisible;
  String?
  _currentQualityTier; // Track current quality tier: '1080p', '720p', '480p'
  String? _qoeCorrelationId;
  final SessionModeStatisticsService _talkStats =
      SessionModeStatisticsService();

  /// Live speaking-time estimates from volume indication (best-effort, tutor UX).
  SessionTalkTimeSnapshot get talkTimeSnapshot => _talkStats.snapshot();

  bool _reconnectTelemetryActive = false;
  final Map<int, DateTime> _freezeStartedAt = <int, DateTime>{};
  final Map<int, VideoStreamType> _lastAppliedRemoteStreamType =
      <int, VideoStreamType>{};

  // Video recovery state - reduced aggressiveness to prevent flickering
  final Map<int, int> _videoRecoveryAttempts = {}; // remoteUid -> attempt count
  static const _maxRecoveryAttempts =
      2; // Reduced from 3 to prevent excessive recovery attempts
  final Map<int, DateTime> _lastRecoveryAttempt =
      {}; // remoteUid -> last attempt time
  static const _recoveryCooldown = Duration(
    seconds: 20,
  ); // Plan: reduce aggressive recovery, prevent blackouts

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
  bool _joinInProgress = false;
  bool _supportsDualStreamMode = true;
  bool _supportsRemoteStreamTypeControl = true;
  bool _supportsRemoteDefaultStreamTypeControl = true;
  DateTime? _lastRemoteStreamPriorityAppliedAt;
  String? _lastSessionId;
  String? _lastUserId;
  String? _lastUserRole;
  bool _lastInitialCameraEnabled = false;
  bool _lastInitialMicEnabled = false;

  // Screen sharing state (so we don't double-start and can reset UI on cancel)
  bool _isPublishingScreen = false;
  int? _screenShareOwnerUid;
  DateTime _screenShareOwnerLockUntil = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _kScreenShareStopGuard = Duration(milliseconds: 900);
  bool get isPublishingScreen => _isPublishingScreen;
  int? get screenShareOwnerUid => _screenShareOwnerUid;

  // Health check state - increased interval to reduce resource usage
  Timer? _videoHealthCheckTimer;
  static const _healthCheckInterval = Duration(
    seconds: 30,
  ); // Reduced polling for phone heating
  DateTime? _lastRemoteVideoActivity; // Track last time remote video was active
  int? _lastActiveRemoteUid;

  // Event streams
  final _stateController = StreamController<AgoraSessionState>.broadcast();
  final _userJoinedController = StreamController<int>.broadcast();
  final _userOfflineController = StreamController<int>.broadcast();
  final _connectionStateController =
      StreamController<ConnectionStateType>.broadcast();

  /// Latest value from [onConnectionStateChanged] (for UI that opens before the next stream tick).
  ConnectionStateType? _lastRtcConnectionState;
  final _errorController = StreamController<String>.broadcast();

  // Remote state tracking streams
  final _remoteVideoMutedController =
      StreamController<
        Map<String, dynamic>
      >.broadcast(); // {uid: int, muted: bool}
  final _remoteVideoFrameController =
      StreamController<
        Map<String, dynamic>
      >.broadcast(); // {uid: int, ready: bool}
  final _remoteAudioMutedController =
      StreamController<
        Map<String, dynamic>
      >.broadcast(); // {uid: int, muted: bool}
  final _screenSharingController =
      StreamController<
        Map<String, dynamic>
      >.broadcast(); // {uid: int, sharing: bool}
  final _userLeftController =
      StreamController<int>.broadcast(); // uid of user who left
  final _remoteNetworkQualityController =
      StreamController<
        Map<String, dynamic>
      >.broadcast(); // {uid: int, quality: QualityType, isUnstable: bool}
  final _reactionController =
      StreamController<
        Map<String, dynamic>
      >.broadcast(); // {uid: int, emoji: String}

  bool _isValidRemoteUid(int uid) {
    // Agora uses 0 for local in some callbacks; never treat it as a remote participant.
    // Also guard against accidentally treating ourselves as remote (can happen on some web SDK edge-cases).
    final selfUid = _currentUID;
    if (uid <= 0) return false;
    if (selfUid != null && uid == selfUid) return false;
    return true;
  }

  final _remoteScreenOffController =
      StreamController<
        Map<String, dynamic>
      >.broadcast(); // {uid: int, screenOff: bool}
  /// UIDs currently speaking (volume above threshold). Used for talking indicator UI.
  final _speakingController = StreamController<Set<int>>.broadcast();
  final _preJoinMicLevelController = StreamController<double>.broadcast();

  Stream<Set<int>> get speakingStream => _speakingController.stream;

  /// Normalized approximate level (0–1) for **pre-channel** microphone feedback UI.
  Stream<double> get preJoinMicLevelStream => _preJoinMicLevelController.stream;

  /// Smoothed 0–1 level for **in-channel** local mic UI (dock wave without full `setState` storms).
  final _inCallLocalMicLevelController = StreamController<double>.broadcast();

  Stream<double> get inCallLocalMicLevelStream =>
      _inCallLocalMicLevelController.stream;

  double _smoothedInCallLocalMicLevel = 0;
  static const double _kInCallMicLevelSmooth = 0.38;

  /// Web browsers often report lower peak volumes; tune separately from native.
  int get _effectiveSpeakingVolumeThreshold => kIsWeb ? 10 : 25;
  static const int _mutedMicHintVolumeThreshold = 58;
  static const int _mutedMicHintRequiredSamples = 3;

  /// Volume briefly crosses threshold while [isAudioEnabled] is false (mic muted in PrepSkul).
  DateTime? _lastMutedMicSpeechHintAt;
  static const Duration _mutedMicSpeechHintCooldown = Duration(seconds: 24);
  int _mutedMicHotSampleCount = 0;
  DateTime? _lastMutedMicHotSampleAt;
  final _mutedMicSpeechHintController = StreamController<void>.broadcast();

  /// Hint when Agora reports local speech energy but the mic is muted (single listener shows SnackBar).
  Stream<void> get mutedMicSpeechHintStream =>
      _mutedMicSpeechHintController.stream;

  /// First capturing/encoding signal for the **camera** stream this session (not screen share).
  final _localCameraPublishingSignalController =
      StreamController<void>.broadcast();

  /// Stream emits once when Agora reports local camera capturing or encoding.
  Stream<void> get localCameraPublishingSignalStream =>
      _localCameraPublishingSignalController.stream;

  bool _localCameraPublishingSignalReceived = false;

  bool get localCameraPublishingSignalReceived =>
      _localCameraPublishingSignalReceived;

  void _markLocalCameraPublishingSignal() {
    if (_localCameraPublishingSignalReceived) return;
    _localCameraPublishingSignalReceived = true;
    if (!_localCameraPublishingSignalController.isClosed) {
      _localCameraPublishingSignalController.add(null);
    }
  }

  void _resetLocalCameraPublishingSignal() {
    _localCameraPublishingSignalReceived = false;
  }

  void _resetCallMediaPolicyState() {
    _qualityController.reset();
    _speakingDebouncer.reset();
    _lastMutedMicSpeechHintAt = null;
    _mutedMicHotSampleCount = 0;
    _lastMutedMicHotSampleAt = null;
    _dualStreamPinnedRemoteUid = null;
    _smoothedInCallLocalMicLevel = 0;
    if (_inCallLocalMicLevelController.hasListener) {
      _inCallLocalMicLevelController.add(0);
    }
    unawaited(clearGalleryPagingVideoSubscriptions());
    if (_speakingController.hasListener) {
      _speakingController.add(<int>{});
    }
  }

  /// PrepSkul multi-page gallery: subscribe remote video only for visible tiles (+ pin + spotlight).
  Future<void> syncGalleryVisibleRemoteVideoSubscriptions(
    Set<int> visibleRemoteUidsOnPage,
  ) async {
    if (_engine == null || !_isInChannel) return;
    if (_remoteParticipantUids.isEmpty) return;

    final effective = Set<int>.from(visibleRemoteUidsOnPage);
    final pin = _dualStreamPinnedRemoteUid;
    if (pin != null && _remoteParticipantUids.contains(pin)) {
      effective.add(pin);
    }
    final spot = _spotlightRemoteUid;
    if (spot != null && _remoteParticipantUids.contains(spot)) {
      effective.add(spot);
    }

    if (_galleryPagingLastEffectiveVisible != null &&
        _galleryPagingLastEffectiveVisible!.length == effective.length &&
        _galleryPagingLastEffectiveVisible!.containsAll(effective) &&
        effective.containsAll(_galleryPagingLastEffectiveVisible!)) {
      return;
    }
    _galleryPagingLastEffectiveVisible = Set<int>.from(effective);

    for (final uid in List<int>.from(_remoteParticipantUids)) {
      final mute = !effective.contains(uid);
      try {
        await _engine!.muteRemoteVideoStream(uid: uid, mute: mute);
      } catch (e) {
        LogService.debug(
          '[GALLERY_PAGE] muteRemoteVideoStream uid=$uid mute=$mute: $e',
        );
      }
    }
  }

  /// Undo gallery paging video mutes (spotlight/side-by-side or below paging threshold).
  Future<void> clearGalleryPagingVideoSubscriptions() async {
    _galleryPagingLastEffectiveVisible = null;
    final engine = _engine;
    if (engine == null || !_isInChannel) return;
    for (final uid in List<int>.from(_remoteParticipantUids)) {
      try {
        await engine.muteRemoteVideoStream(uid: uid, mute: false);
      } catch (e) {
        LogService.debug('[GALLERY_PAGE] unmute paging uid=$uid: $e');
      }
    }
  }

  /// Sync pinned gallery participant into dual-stream priority (native multi-party only).
  void setDualStreamPinnedRemoteUid(int? uid) {
    if (_dualStreamPinnedRemoteUid == uid) return;
    _dualStreamPinnedRemoteUid = uid;
    _lastRemoteStreamPriorityAppliedAt = null;
    unawaited(_applyRemoteStreamPriority());
  }

  void _considerMutedMicSpeechHint(List<AudioVolumeInfo> speakers) {
    if (!_isInChannel || _isAudioEnabled || _currentUID == null) return;
    final self = _currentUID!;
    final now = DateTime.now();
    final recentWindow =
        _lastMutedMicHotSampleAt != null &&
        now.difference(_lastMutedMicHotSampleAt!) < const Duration(seconds: 2);
    if (!recentWindow) {
      _mutedMicHotSampleCount = 0;
    }
    for (final s in speakers) {
      final uid = s.uid ?? 0;
      final vol = s.volume ?? 0;
      if (vol <= _mutedMicHintVolumeThreshold) continue;
      if (uid != 0 && uid != self) continue;
      _lastMutedMicHotSampleAt = now;
      _mutedMicHotSampleCount += 1;
      if (_mutedMicHotSampleCount < _mutedMicHintRequiredSamples) {
        return;
      }
      _mutedMicHotSampleCount = 0;
      if (_lastMutedMicSpeechHintAt != null &&
          now.difference(_lastMutedMicSpeechHintAt!) <
              _mutedMicSpeechHintCooldown) {
        return;
      }
      _lastMutedMicSpeechHintAt = now;
      if (_mutedMicSpeechHintController.hasListener) {
        _mutedMicSpeechHintController.add(null);
      }
      return;
    }
  }

  // Remote network quality tracking
  final Map<int, QualityType> _remoteNetworkQualities =
      {}; // remoteUid -> quality
  final Map<int, DateTime> _remoteNetworkQualityTimestamps =
      {}; // remoteUid -> last update time
  final Map<int, int> _remotePoorQualityCount =
      {}; // remoteUid -> consecutive poor quality counts

  // Connection state tracking for accurate user left detection
  final Map<int, DateTime> _userOfflineTimestamps =
      {}; // remoteUid -> when they went offline
  final Map<int, Timer?> _userLeftGracePeriodTimers =
      {}; // remoteUid -> grace period timer
  final Map<int, bool> _userConfirmedLeft =
      {}; // remoteUid -> confirmed left (not just poor connection)
  final Map<int, int> _userOfflineCount =
      {}; // remoteUid -> consecutive offline events
  static const _userLeftGracePeriod = Duration(
    seconds: 15,
  ); // Backward-compat fallback
  static const _maxOfflineEvents =
      3; // Number of offline events before confirming left
  DateTime?
  _lastLocalVideoMuteTime; // On web, Agora can fire spurious userOffline when local mutes - ignore if within window
  static const _webMuteOfflineIgnoreWindow = Duration(seconds: 5);

  /// On web for Quit, keep a slightly longer grace to absorb transient mobile-web
  /// reconnect glitches that can otherwise look like a hard leave.
  static const _webQuitGracePeriod = Duration(seconds: 12);

  /// True if local user muted video within the short ignore window. Used by UI to suppress "remote left" on mobile web when Agora fires spurious Quit.
  bool get didLocalUserMuteVideoRecently {
    if (_lastLocalVideoMuteTime == null) return false;
    return DateTime.now().difference(_lastLocalVideoMuteTime!) <
        _webMuteOfflineIgnoreWindow;
  }

  // Screen-off detection state
  final Map<int, DateTime> _remoteVideoStoppedTimestamps =
      {}; // remoteUid -> when video stopped
  final Map<int, Timer?> _screenOffDetectionTimers =
      {}; // remoteUid -> screen-off detection timer
  final Map<int, bool> _remoteScreenOff = {}; // remoteUid -> screen is off
  final Map<int, bool> _remoteAudioActive =
      {}; // remoteUid -> audio is still active (helps detect screen-off)
  static const _screenOffDetectionDelay = Duration(
    seconds: 5,
  ); // Wait 5 seconds before detecting screen-off

  // Provisional "stopped" handling: avoid immediate ready=false on transient renegotiation (e.g. web)
  final Map<int, Timer?> _remoteVideoStoppedProvisionalTimers = {};
  static const _remoteVideoStoppedProvisionalDelay = Duration(
    milliseconds: 800,
  );

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

  /// Extremely resilient tier for very poor networks – favors continuity over sharpness.
  static const _quality360pVeryLow = VideoEncoderConfiguration(
    dimensions: VideoDimensions(width: 480, height: 360),
    frameRate: 15,
    bitrate: 450,
    minBitrate: 300,
    orientationMode: OrientationMode.orientationModeAdaptive,
    degradationPreference: DegradationPreference.maintainFramerate,
    mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
  );

  // Getters
  Stream<AgoraSessionState> get stateStream => _stateController.stream;
  Stream<int> get userJoinedStream => _userJoinedController.stream;
  Stream<int> get userOfflineStream => _userOfflineController.stream;
  Stream<ConnectionStateType> get connectionStateStream =>
      _connectionStateController.stream;

  ConnectionStateType? get lastRtcConnectionState => _lastRtcConnectionState;
  Stream<String> get errorStream => _errorController.stream;
  Stream<Map<String, dynamic>> get remoteVideoMutedStream =>
      _remoteVideoMutedController.stream;
  Stream<Map<String, dynamic>> get remoteVideoFrameStream =>
      _remoteVideoFrameController.stream;
  Stream<Map<String, dynamic>> get remoteAudioMutedStream =>
      _remoteAudioMutedController.stream;
  Stream<Map<String, dynamic>> get screenSharingStream =>
      _screenSharingController.stream;
  Stream<int> get userLeftStream => _userLeftController.stream;
  Stream<Map<String, dynamic>> get remoteNetworkQualityStream =>
      _remoteNetworkQualityController.stream;
  Stream<Map<String, dynamic>> get reactionStream => _reactionController.stream;
  Stream<Map<String, dynamic>> get remoteScreenOffStream =>
      _remoteScreenOffController.stream;

  AgoraSessionState get state => _state;
  bool get isInitialized => _isInitialized;
  bool get isInChannel => _isInChannel;
  String? get currentChannelName => _currentChannelName;
  int? get currentUID => _currentUID;
  RtcConnection? get currentConnection => _currentConnection;

  /// Latest uplink (TX) sample from `onNetworkQuality` when `remoteUid == 0`.
  QualityType? get lastObservedUplinkQuality => _lastObservedTxQuality;

  /// Snapshot of per-remote uplink quality for diagnostics surfaces.
  Map<int, QualityType> get snapshotRemoteNetworkQuality =>
      Map<int, QualityType>.unmodifiable(
        Map<int, QualityType>.from(_remoteNetworkQualities),
      );

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
        if (kIsWeb &&
            (e.toString().contains('createIrisApiEngine') ||
                e.toString().contains('undefined'))) {
          throw Exception(
            'Agora iris-web-rtc SDK not loaded. '
            'Please ensure iris-web-rtc.js script is included in index.html and loads before Flutter initializes. '
            'Error: $e',
          );
        }
        rethrow;
      }

      // Get App ID from environment or token (will be set properly in joinChannel)
      // For now, initialize with empty - will be updated when we get token
      await _engine!
          .initialize(
            RtcEngineContext(
              appId: '', // Will be set from token response
              channelProfile: ChannelProfileType.channelProfileCommunication,
              // Add area code for better connection (optional)
              // areaCode: AreaCode.areaCodeGlob,
            ),
          )
          // In unit/widget tests (and some bad device states) engine init can hang.
          // Keep a hard timeout so the app can recover gracefully.
          .timeout(const Duration(seconds: 5));

      // Configure video quality: 480p on mobile (reduce heating), 720p on web/desktop
      final isMobile =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android);
      final initialConfig = isMobile
          ? _quality480p
          : const VideoEncoderConfiguration(
              dimensions: VideoDimensions(width: 1280, height: 720),
              frameRate: 30,
              bitrate: 2000,
              minBitrate: 1000,
              orientationMode: OrientationMode.orientationModeAdaptive,
              degradationPreference: DegradationPreference.maintainQuality,
              mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
            );
      try {
        await _engine!
            .setVideoEncoderConfiguration(initialConfig)
            .timeout(const Duration(seconds: 3));
        LogService.success(
          '✅ Video encoder configured: ${isMobile ? "480p (mobile)" : "720p"}',
        );
      } catch (e) {
        LogService.warning('Could not set video encoder configuration: $e');
      }

      await _applyTutoringAudioProfile();

      // CRITICAL: Configure for low-latency real-time communication
      // This prevents buffering and catch-up playback when network recovers
      try {
        // Disable smooth streaming to prevent catch-up playback
        await _engine!.setParameters('{"rtc.video.playout_delay_max": 0}');
        await _engine!.setParameters('{"rtc.audio.playout_delay_max": 0}');

        // Minimize jitter buffer for real-time experience
        await _engine!.setParameters('{"che.video.jitterBuffer": 50}');
        await _engine!.setParameters('{"che.audio.jitterBuffer": 50}');

        // Configure low‑bitrate stream defaults for dual‑stream and fallback.
        await _engine!.setParameters(
          '{"che.video.lowBitRateStreamParameter":{"width":480,"height":360,"frameRate":15,"bitRate":400}}',
        );

        LogService.success(
          '✅ Low-latency mode configured (no catch-up playback)',
        );
      } catch (e) {
        LogService.warning('Could not configure low-latency parameters: $e');
      }

      // Enable dual‑stream so we can dynamically switch remote quality.
      if (AppConfig.enableClassroomDualStream &&
          !kIsWeb &&
          _supportsDualStreamMode) {
        try {
          await _engine!.enableDualStreamMode(enabled: true);
          LogService.success('✅ Dual stream mode enabled');
        } catch (e) {
          if (_isAgoraNotSupported(e)) {
            _supportsDualStreamMode = false;
            LogService.info(
              '[NET] Dual stream mode not supported on this platform; disabling further dual-stream attempts.',
            );
          } else {
            LogService.warning('Could not enable dual stream mode: $e');
          }
        }
      } else {
        LogService.info('[NET] Dual stream disabled by feature flag');
      }

      // Register event handlers
      _registerEventHandlers();

      _isInitialized = true;
      _updateState(AgoraSessionState.disconnected);
      LogService.success('Agora RTC engine initialized');
    } catch (e, stackTrace) {
      LogService.error('Failed to initialize Agora engine: $e');
      LogService.error('Stack trace: $stackTrace');

      // If init fails, do NOT keep a half-created engine around. It can cause
      // later calls (switchCamera/toggleAudio/dispose) to hang in tests/devices.
      await _safeReleaseEngine(reason: 'initialize() failed');

      // Provide helpful error message
      String errorMessage = 'Failed to initialize: $e';
      if (kIsWeb) {
        if (e.toString().contains('createIrisApiEngine') ||
            e.toString().contains('undefined') ||
            e.toString().contains('iris-web-rtc')) {
          errorMessage =
              'Agora iris-web-rtc SDK not loaded. '
              'Please ensure iris-web-rtc.js script is included in index.html. Error: $e';
        } else {
          errorMessage =
              'Failed to initialize video service on web. '
              'Please ensure your browser supports WebRTC and has necessary permissions. Error: $e';
        }
      }

      _errorController.add(errorMessage);
      rethrow;
    }
  }

  Future<void> _safeReleaseEngine({required String reason}) async {
    final engine = _engine;
    _engine = null;
    _isInitialized = false;

    if (engine == null) return;

    try {
      await engine.release().timeout(const Duration(seconds: 2));
      LogService.info('Agora engine released ($reason)');
    } catch (e) {
      LogService.warning('Agora engine release failed/timeout ($reason): $e');
    }
  }

  /// Release the engine after the user leaves the call.
  /// Call this after leaveChannel() so the call does not run in the background (fixes hot phone).
  /// Next join will re-create the engine (joinChannel handles _engine == null).
  Future<void> releaseEngineAfterLeave() async {
    await _safeReleaseEngine(reason: 'user left');
  }

  /// Web hot-restart safety: aggressively stop camera/mic capture and release stale engine/session.
  /// Non-throwing by design so startup/retry flows stay resilient.
  Future<void> forceWebCleanupOnStartup() async {
    if (!kIsWeb) return;
    try {
      await _forceStopMediaAndReset(reason: 'web startup/hot-restart cleanup');
    } catch (e) {
      LogService.warning('forceWebCleanupOnStartup failed: $e');
    }
  }

  /// Ensure a fresh RTC state before a new join attempt.
  Future<void> prepareFreshJoinState() async {
    try {
      await _forceStopMediaAndReset(reason: 'prepare fresh join');
    } catch (e) {
      LogService.warning('prepareFreshJoinState failed: $e');
    }
  }

  Future<void> _forceStopMediaAndReset({required String reason}) async {
    _emitTalkTimeSummary();
    final engine = _engine;
    if (engine != null) {
      try {
        await engine
            .muteLocalAudioStream(true)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await engine
            .muteLocalVideoStream(true)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await engine.stopPreview().timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await engine.disableVideo().timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await engine.disableAudio().timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        if (_isInChannel) {
          await engine.leaveChannel().timeout(const Duration(seconds: 3));
        }
      } catch (_) {}
    }

    _isInChannel = false;
    _currentChannelName = null;
    _currentUID = null;
    _currentConnection = null;
    _spotlightRemoteUid = null;
    _isPublishingScreen = false;
    _screenShareOwnerUid = null;
    _isReconnecting = false;
    _joinInProgress = false;
    _reconnectionAttempts = 0;
    _lastSessionId = null;
    _lastUserId = null;
    _lastUserRole = null;
    _talkStats.reset();
    _resetLocalCameraPublishingSignal();
    _lastInitialCameraEnabled = false;
    _lastInitialMicEnabled = false;
    _isVideoEnabled = false;
    _isAudioEnabled = false;
    _lastObservedTxQuality = null;

    await _safeReleaseEngine(reason: reason);
    _updateState(AgoraSessionState.disconnected);
    LogService.info('Agora fresh-state reset complete ($reason)');
  }

  bool _preJoinInitInProgress = false;

  /// Start local camera preview only (for pre-join screen). Does not join a channel.
  /// Fetches token to get appId, initializes engine, enables video and starts preview.
  /// Call releasePreviewIfNotInChannel() when user cancels pre-join.
  /// Serialized so concurrent calls do not create two engines.
  Future<void> startLocalPreviewForPreJoin(String sessionId) async {
    if (_isInChannel) {
      LogService.warning('Already in channel - cannot start pre-join preview');
      return;
    }
    // Wait for any in-progress init so we don't create a second engine
    for (int i = 0; i < 50 && _preJoinInitInProgress; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (_isInitialized && _engine != null) {
      try {
        await _engine!.enableVideo();
        await _engine!.enableAudio();
        await _engine!.muteLocalVideoStream(false);
        if (kIsWeb) {
          await _engine!.setupLocalVideo(
            const VideoCanvas(
              uid: 0,
              sourceType: VideoSourceType.videoSourceCamera,
            ),
          );
          await _engine!.startPreview();
          await Future.delayed(const Duration(milliseconds: 300));
        }
        try {
          await _engine!.enableAudioVolumeIndication(
            interval: 500,
            smooth: 3,
            reportVad: true,
          );
        } catch (e) {
          LogService.warning('Pre-join enableAudioVolumeIndication(reuse): $e');
        }
        // On Android/iOS, do NOT call startPreview here — let _PreJoinVideoHost call
        // startPreJoinPreviewCapture() after the view is in the tree to avoid black preview.
        _isVideoEnabled = true;
        LogService.info('Pre-join local preview started (reuse engine)');
      } catch (e) {
        LogService.warning('Pre-join reuse engine failed: $e');
        rethrow;
      }
      return;
    }
    _preJoinInitInProgress = true;
    try {
      final tokenData = await AgoraTokenService.fetchToken(sessionId);
      final appId = tokenData['appId'] as String?;
      if (appId == null || appId.isEmpty) {
        LogService.warning('No appId in token - cannot start pre-join preview');
        return;
      }
      if (_engine != null) {
        try {
          await _engine!.release().timeout(const Duration(seconds: 2));
        } catch (e) {
          LogService.warning('Error releasing engine: $e');
        }
        _engine = null;
        _isInitialized = false;
      }
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      _registerEventHandlers();
      _isInitialized = true;
      LogService.info('Engine initialized for pre-join preview');
      await _engine!.enableVideo();
      await _engine!.enableAudio();
      await _engine!.muteLocalVideoStream(false);
      // Enable volume indication so pre-join and in-call can show talking indicator
      try {
        await _engine!.enableAudioVolumeIndication(
          interval: 500,
          smooth: 3,
          reportVad: true,
        );
      } catch (e) {
        LogService.warning('Pre-join enableAudioVolumeIndication: $e');
      }
      if (kIsWeb) {
        await _engine!.setupLocalVideo(
          const VideoCanvas(
            uid: 0,
            sourceType: VideoSourceType.videoSourceCamera,
          ),
        );
        await _engine!.startPreview();
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        // On Android/iOS, do NOT call startPreview here. The pre-join screen will call
        // startPreJoinPreviewCapture() after the AgoraVideoView is built so the view exists first.
      }
      _isVideoEnabled = true;
      LogService.info('Pre-join local preview started');
    } catch (e) {
      LogService.warning('Failed to start pre-join preview: $e');
      rethrow;
    } finally {
      _preJoinInitInProgress = false;
    }
  }

  /// Audio-engine-only lobby path (voice-only lessons or mic check with camera off).
  /// Enables Agora mic capture locally without joining — drives [preJoinMicLevelStream].
  Future<void> startPreJoinAudioMeterOnly(String sessionId) async {
    if (_isInChannel) return;
    for (var i = 0; i < 50 && _preJoinInitInProgress; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (_isInitialized && _engine != null) {
      try {
        await _engine!.stopPreview();
        await _engine!.muteLocalVideoStream(true);
        await _engine!.disableVideo();
        await _engine!.enableAudio();
        try {
          await _engine!.enableAudioVolumeIndication(
            interval: 500,
            smooth: 3,
            reportVad: true,
          );
        } catch (e) {
          LogService.warning('Pre-join audio meter indication(reuse): $e');
        }
        await _engine!.muteLocalAudioStream(false);
        _isVideoEnabled = false;
        LogService.info('Pre-join audio meter started (reuse engine)');
      } catch (e) {
        LogService.warning('Pre-join audio meter(reuse engine) failed: $e');
        rethrow;
      }
      return;
    }
    _preJoinInitInProgress = true;
    try {
      final tokenData = await AgoraTokenService.fetchToken(sessionId);
      final appId = tokenData['appId'] as String?;
      if (appId == null || appId.isEmpty) {
        LogService.warning(
          'No appId in token - cannot start lobby audio meter',
        );
        return;
      }
      if (_engine != null) {
        try {
          await _engine!.release().timeout(const Duration(seconds: 2));
        } catch (e) {
          LogService.warning('Error releasing engine: $e');
        }
        _engine = null;
        _isInitialized = false;
      }
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      _registerEventHandlers();
      _isInitialized = true;
      LogService.info('Engine initialized for pre-join audio meter');
      await _engine!.muteLocalVideoStream(true);
      await _engine!.disableVideo();
      await _engine!.enableAudio();
      await _engine!.muteLocalAudioStream(false);
      try {
        await _engine!.enableAudioVolumeIndication(
          interval: 400,
          smooth: 3,
          reportVad: true,
        );
      } catch (e) {
        LogService.warning('Pre-join enableAudioVolumeIndication(audio): $e');
      }
      _isVideoEnabled = false;
      LogService.info('Lobby audio meter path ready');
    } catch (e) {
      LogService.warning('Failed to start lobby audio meter: $e');
      rethrow;
    } finally {
      _preJoinInitInProgress = false;
    }
  }

  /// On Android, the platform view must exist before startPreview() or the preview stays black.
  /// Call this from the pre-join screen after the AgoraVideoView has been built (e.g. in a post-frame callback).
  Future<void> startPreJoinPreviewCapture() async {
    if (kIsWeb || _engine == null || _isInChannel) return;
    try {
      await _engine!.startPreview();
      LogService.info(
        'Pre-join preview capture started (view already in tree)',
      );
    } catch (e) {
      LogService.warning('startPreJoinPreviewCapture failed: $e');
    }
  }

  /// Update pre-join camera state (start/stop preview) when not in channel.
  Future<void> setPreJoinCameraEnabled(bool enabled) async {
    if (_engine == null || _isInChannel) return;
    try {
      _isVideoEnabled = enabled;
      if (enabled) {
        // Re-enable camera capture and preview.
        await _engine!.enableVideo();
        // Web must bind preview to HtmlElementView. On Android/iOS, [setupLocalVideo] without
        // the plugin's canvas breaks [AgoraVideoView]'s binding and freezes preview after toggle.
        if (kIsWeb) {
          await _engine!.setupLocalVideo(
            const VideoCanvas(
              uid: 0,
              sourceType: VideoSourceType.videoSourceCamera,
            ),
          );
        }
        await _engine!.muteLocalVideoStream(false);
        await _engine!.startPreview();
      } else {
        // Explicitly stop capture so browser webcam indicator/light turns off.
        await _engine!.muteLocalVideoStream(true);
        await _engine!.stopPreview();
        await _engine!.disableVideo();
      }
    } catch (e) {
      LogService.warning('setPreJoinCameraEnabled failed: $e');
    }
  }

  /// Update pre-join mic state while not in a channel.
  Future<void> setPreJoinMicEnabled(bool enabled) async {
    if (_engine == null || _isInChannel) return;
    try {
      _isAudioEnabled = enabled;
      await _engine!.muteLocalAudioStream(!enabled);
    } catch (e) {
      LogService.warning('setPreJoinMicEnabled failed: $e');
    }
  }

  /// Release engine if not in a channel (e.g. user cancelled pre-join).
  Future<void> releasePreviewIfNotInChannel() async {
    if (_isInChannel) return;
    if (_joinInProgress) {
      LogService.info(
        'Skipping pre-join engine release: join already in progress',
      );
      return;
    }
    if (_state == AgoraSessionState.joining ||
        _state == AgoraSessionState.reconnecting) {
      LogService.info(
        'Skipping pre-join engine release: session state is $_state',
      );
      return;
    }
    await _safeReleaseEngine(reason: 'pre-join cancelled');
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
    _qoeCorrelationId = QoeTelemetryService.buildCorrelationId(sessionId);
    _lastUserId = userId;
    _lastUserRole = userRole;
    _lastInitialCameraEnabled = initialCameraEnabled;
    _lastInitialMicEnabled = initialMicEnabled;
    _talkStats.reset();
    _resetLocalCameraPublishingSignal();

    // Reset reconnection attempts on new join
    _reconnectionAttempts = 0;
    if (_isInChannel) {
      LogService.warning('Already in channel: $_currentChannelName');
      return;
    }
    if (_joinInProgress) {
      LogService.warning(
        'Join already in progress, skipping duplicate join request',
      );
      return;
    }

    try {
      _joinInProgress = true;
      _resetCallMediaPolicyState();
      _updateState(AgoraSessionState.joining);

      // Fetch token from backend FIRST to get appId
      final tokenData = await AgoraTokenService.fetchToken(sessionId);

      _currentChannelName = tokenData['channelName'] as String;
      _currentUID = tokenData['uid'] as int;
      final token = tokenData['token'] as String;
      final appId = tokenData['appId'] as String?;

      LogService.info(
        '📊 Channel Info: channelName=$_currentChannelName, UID=$_currentUID, role=$userRole',
      );

      // CRITICAL: If appId is provided and engine not initialized or initialized with empty appId, reinitialize
      if (appId != null && appId.isNotEmpty) {
        // Check if we need to reinitialize with proper appId
        if (!_isInitialized || _engine == null) {
          LogService.info('Initializing engine with App ID from token');
          // Dispose existing engine if any
          if (_engine != null) {
            try {
              await _engine!.release().timeout(const Duration(seconds: 2));
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

        // Ensure dual‑stream is active inside the channel as well (some platforms
        // require calling this after join).
        if (AppConfig.enableClassroomDualStream &&
            !kIsWeb &&
            _supportsDualStreamMode) {
          try {
            await _engine!.enableDualStreamMode(enabled: true);
            LogService.info('[NET] Dual stream mode confirmed in joinChannel');
          } catch (e) {
            if (_isAgoraNotSupported(e)) {
              _supportsDualStreamMode = false;
              LogService.info(
                '[NET] Dual stream mode not supported in join flow; disabling further attempts.',
              );
            } else {
              LogService.warning(
                '[NET] enableDualStreamMode in joinChannel failed: $e',
              );
            }
          }
        }

        // Set initial camera and mic state from pre-join screen
        _isVideoEnabled = initialCameraEnabled;
        _isAudioEnabled = initialMicEnabled;

        // Apply initial states
        await _engine!.muteLocalVideoStream(!initialCameraEnabled);
        await _engine!.muteLocalAudioStream(!initialMicEnabled);

        LogService.info(
          '📹 Initial state: Camera=${initialCameraEnabled ? "ON" : "OFF"}, Mic=${initialMicEnabled ? "ON" : "OFF"}',
        );

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
              await Future.delayed(const Duration(milliseconds: 90));
              // Match [toggleVideo] web path — joinChannel previously skipped preview,
              // which can leave "camera on" without a visible self-view until toggle.
              await _engine!.startPreview();
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

      // CRITICAL: Configure low-latency after joining channel
      // This ensures real-time communication without buffering missed content
      try {
        // Default to high stream; we will dynamically switch to low when we
        // detect sustained poor network quality.
        await _engine!.setRemoteDefaultVideoStreamType(
          VideoStreamType.videoStreamHigh,
        );

        // Disable automatic catch-up of missed frames
        await _engine!.setParameters('{"rtc.video.playout_delay_max": 0}');
        await _engine!.setParameters('{"rtc.audio.playout_delay_max": 0}');

        // Set minimal buffer for real-time experience
        await _engine!.setParameters('{"che.video.render.fps": 30}');

        LogService.info('✅ Channel low-latency settings applied');
      } catch (e) {
        LogService.warning('Could not apply channel low-latency settings: $e');
      }

      // Don't set connected state here - wait for onJoinChannelSuccess callback
      // The event handler will update the state when connection is actually established
      LogService.info('Join channel request sent, waiting for connection...');
    } catch (e) {
      _joinInProgress = false;
      LogService.error('Failed to join channel: $e');

      // Check for permission errors specifically
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('notallowederror') ||
          errorStr.contains('notallowed') ||
          errorStr.contains('permission denied') ||
          (errorStr.contains('permission') && errorStr.contains('denied'))) {
        LogService.error('❌ Permission denied when joining channel');
        LogService.error('💡 Camera/microphone access was blocked by browser');
        LogService.error(
          '💡 To fix: Click camera/mic icon in address bar → Set to "Allow" → Refresh page',
        );
        _errorController.add(
          'Camera and Microphone Permission Required\n\n'
          'Your browser is blocking camera and microphone access.\n\n'
          'To fix:\n'
          '1. Click the camera/microphone icon in the address bar\n'
          '2. Set both "Camera" and "Microphone" to "Allow"\n'
          '3. Refresh this page and try again',
        );
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
    _videoCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isInChannel || _engine == null || !_isVideoEnabled) {
        timer.cancel();
        _videoCheckTimer = null;
        return;
      }
      // Avoid periodic unmute chatter when user is alone in-room.
      if (_remoteParticipantUids.isEmpty) {
        return;
      }

      // Periodically ensure video is unmuted (rate-limited to avoid thrash).
      _ensureVideoUnmuted(reason: 'periodic_check');
    });
  }

  Future<void> _ensureVideoUnmuted({
    required String reason,
    bool force = false,
    bool logOnSuccess = false,
  }) async {
    if (_engine == null || !_isInChannel || !_isVideoEnabled) return;
    // While screen sharing is active, avoid repeatedly forcing camera unmute.
    if (_isPublishingScreen) return;
    final now = DateTime.now();
    if (!force &&
        _lastEnsureVideoUnmutedAt != null &&
        now.difference(_lastEnsureVideoUnmutedAt!) <
            _ensureVideoUnmutedCooldown) {
      return;
    }
    _lastEnsureVideoUnmutedAt = now;
    try {
      await _engine!.muteLocalVideoStream(false);
      if (logOnSuccess) {
        LogService.info('✅ Ensured local video unmuted ($reason)');
      }
    } catch (e) {
      LogService.warning('Could not ensure video unmuted ($reason): $e');
    }
  }

  /// Stop periodic video check
  void _stopVideoCheckTimer() {
    _videoCheckTimer?.cancel();
    _videoCheckTimer = null;
  }

  /// Set up Supabase Realtime channel for emoji reactions (fallback when Agora data stream is unavailable, e.g. on web).
  /// Both peers subscribe so web can send/receive and mobile can receive reactions from web.
  void _setupReactionRealtimeChannel() {
    final sessionId = _lastSessionId;
    if (sessionId == null || sessionId.isEmpty || _currentUID == null) return;
    try {
      _reactionChannel?.unsubscribe();
      _reactionChannel = SupabaseService.client.channel(
        'session_reactions_$sessionId',
      );
      _reactionChannel!.onBroadcast(
        event: 'reaction',
        callback: (payload, [ref]) {
          final fromUid = payload['fromUid'] as int?;
          final emoji = payload['emoji'] as String?;
          if (fromUid == null || emoji == null || emoji.isEmpty) return;
          if (fromUid == _currentUID) return; // don't show own reaction again
          LogService.info(
            '🎭 [EMOJI] Received reaction via Realtime: fromUid=$fromUid, emoji="$emoji"',
          );
          _reactionController.add({'uid': fromUid, 'emoji': emoji});
        },
      );
      _reactionChannel!.onBroadcast(
        event: 'screen_share',
        callback: (payload, [ref]) {
          final fromUid = payload['fromUid'] as int?;
          final sharing = payload['sharing'] as bool?;
          if (fromUid == null || sharing == null) return;
          if (!_isValidRemoteUid(fromUid)) return;
          _applyScreenShareSignal(
            uid: fromUid,
            sharing: sharing,
            source: 'realtime_broadcast',
          );
          LogService.info(
            '📺 [Realtime] screen_share fromUid=$fromUid sharing=$sharing',
          );
        },
      );
      _reactionChannel!.onBroadcast(
        event: 'camera_state',
        callback: (payload, [ref]) {
          final fromUid = payload['fromUid'] as int?;
          final enabled = payload['enabled'] as bool?;
          if (fromUid == null || enabled == null) return;
          if (fromUid == _currentUID) return;
          if (!_isValidRemoteUid(fromUid)) return;
          LogService.info(
            '📹 [Realtime] camera_state fromUid=$fromUid enabled=$enabled',
          );
          _remoteVideoMutedController.add({
            'uid': fromUid,
            'muted': !enabled,
          });
          _remoteVideoFrameController.add({
            'uid': fromUid,
            'ready': enabled,
          });
        },
      );
      _reactionChannel!.subscribe();
      LogService.success(
        '✅ Reaction Realtime channel subscribed: session_reactions_$sessionId',
      );
    } catch (e) {
      LogService.warning('Could not set up reaction Realtime channel: $e');
      _reactionChannel = null;
    }
  }

  /// Leave Agora channel
  Future<void> leaveChannel() async {
    _emitTalkTimeSummary();
    if (_engine == null) {
      // Engine already disposed or not initialized
      _isInChannel = false;
      _currentChannelName = null;
      _currentUID = null;
      _currentConnection = null;
      _dataStreamId = null;
      _reactionChannel?.unsubscribe();
      _reactionChannel = null;
      _qoeCorrelationId = null;
      _talkStats.reset();
      _resetLocalCameraPublishingSignal();
      _resetCallMediaPolicyState();
      _updateState(AgoraSessionState.disconnected);
      return;
    }

    if (!_isInChannel) {
      // Already left
      _qoeCorrelationId = null;
      _talkStats.reset();
      _resetLocalCameraPublishingSignal();
      _resetCallMediaPolicyState();
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
      _joinInProgress = false;
      _qoeCorrelationId = null;
      _talkStats.reset();
      _resetLocalCameraPublishingSignal();
      _videoRecoveryAttempts.clear();
      _lastRecoveryAttempt.clear();
      _cameraRecoveryAttempts = 0;
      _isRecoveringCamera = false;
      _lastObservedTxQuality = null;
      _currentQualityTier = null;
      _resetCallMediaPolicyState();
      _reconnectTelemetryActive = false;
      _freezeStartedAt.clear();
      _lastAppliedRemoteStreamType.clear();
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
      for (var t in _remoteVideoStoppedProvisionalTimers.values) {
        t?.cancel();
      }
      _remoteVideoStoppedProvisionalTimers.clear();

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
            _engine!
                .muteLocalVideoStream(true)
                .timeout(
                  const Duration(
                    seconds: 1,
                  ), // Shorter timeout for immediate response
                  onTimeout: () {
                    LogService.warning('Mute video timeout - continuing');
                  },
                )
                .catchError((e) {
                  LogService.warning('Mute video error (continuing): $e');
                }),
          if (wasAudioEnabled)
            _engine!
                .muteLocalAudioStream(true)
                .timeout(
                  const Duration(
                    seconds: 1,
                  ), // Shorter timeout for immediate response
                  onTimeout: () {
                    LogService.warning('Mute audio timeout - continuing');
                  },
                )
                .catchError((e) {
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
          LogService.warning(
            'Channel already left or mutex error (this is okay): $e',
          );
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

        // Desktop/mobile: disable capabilities + stop preview in one parallel batch.
        // Web: we still must stopPreview + tear down capability — muteLocalVideoStream alone often
        // leaves the browser camera indicator on until tracks are stopped or the engine is released.
        if (!kIsWeb) {
          await Future.wait([
            _engine!
                .disableVideo()
                .timeout(
                  const Duration(seconds: 2),
                  onTimeout: () {
                    LogService.warning('Disable video timeout - continuing');
                  },
                )
                .catchError((e) {
                  LogService.warning('Disable video error (continuing): $e');
                }),
            _engine!
                .disableAudio()
                .timeout(
                  const Duration(seconds: 2),
                  onTimeout: () {
                    LogService.warning('Disable audio timeout - continuing');
                  },
                )
                .catchError((e) {
                  LogService.warning('Disable audio error (continuing): $e');
                }),
          ], eagerError: false);

          try {
            await _engine!
                .stopPreview()
                .timeout(
                  const Duration(seconds: 1),
                  onTimeout: () {
                    LogService.warning('Stop preview timeout - continuing');
                  },
                )
                .catchError((e) {
                  LogService.debug('Preview not active: $e');
                });
          } catch (e) {
            LogService.warning(
              'Error stopping preview (continuing anyway): $e',
            );
          }
        } else {
          try {
            await _engine!
                .stopPreview()
                .timeout(
                  const Duration(seconds: 2),
                  onTimeout: () {
                    LogService.warning('Web stop preview timeout - continuing');
                  },
                )
                .catchError((e) {
                  LogService.debug('Web preview stop: $e');
                });
          } catch (e) {
            LogService.debug('Web stopPreview: $e');
          }
          try {
            await _engine!
                .disableVideo()
                .timeout(const Duration(seconds: 2))
                .catchError((e) {
                  LogService.debug('Web disableVideo (ignored): $e');
                });
          } catch (e) {
            LogService.debug('Web disableVideo: $e');
          }
          try {
            await _engine!
                .disableAudio()
                .timeout(const Duration(seconds: 2))
                .catchError((e) {
                  LogService.debug('Web disableAudio (ignored): $e');
                });
          } catch (e) {
            LogService.debug('Web disableAudio: $e');
          }
        }

        LogService.info('✅ All media tracks stopped and capabilities disabled');
      } catch (e) {
        LogService.warning(
          'Error disabling capabilities (continuing anyway): $e',
        );
      }

      // Always update state even if leaveChannel throws
      _isInChannel = false;
      _currentChannelName = null;
      _currentUID = null;
      _currentConnection = null; // Clear connection
      _dataStreamId = null; // Data stream is destroyed when leaving channel
      _reactionChannel?.unsubscribe();
      _reactionChannel = null;
      _updateState(AgoraSessionState.disconnected);

      LogService.success('Left Agora channel');
    } catch (e) {
      // Even if there's an error, mark as disconnected
      LogService.warning(
        'Error during leave channel (marking as disconnected): $e',
      );
      _isInChannel = false;
      _currentChannelName = null;
      _currentUID = null;
      _currentConnection = null;
      _dataStreamId = null;
      _reactionChannel?.unsubscribe();
      _reactionChannel = null;
      _stopVideoHealthCheck();
      _resetCallMediaPolicyState();
      _updateState(AgoraSessionState.disconnected);
      // Don't add to error controller - user is leaving anyway
    }
  }

  /// Toggle local video (camera on/off)
  Future<void> toggleVideo() async {
    if (_engine == null || !_isInitialized) return;

    try {
      _isVideoEnabled = !_isVideoEnabled;

      if (_isVideoEnabled) {
        // Enabling camera - set up local video view and unmute
        LogService.info('📹 Enabling camera...');

        // Set up local video view (required for web to access camera)
        if (kIsWeb) {
          try {
            await _engine!.enableVideo();
            LogService.info('📹 Video capability enabled');
            if (!_isPublishingScreen) {
              await _engine!.setupLocalVideo(
                const VideoCanvas(
                  uid: 0,
                  sourceType: VideoSourceType.videoSourceCamera,
                ),
              );
            }
            await _engine!.startPreview();
            LogService.info('✅ Local video view set up (camera source)');
            await Future.delayed(const Duration(milliseconds: 300));
          } catch (e) {
            LogService.warning('Could not set up local video view: $e');
          }
        } else {
          // Mobile: never call setupLocalVideo here — Flutter AgoraVideoView owns the
          // native surface; only ensure capture is running after unmute.
          try {
            await _engine!.enableVideo();
          } catch (e) {
            LogService.warning('enableVideo on toggle: $e');
          }
          try {
            await _engine!.startPreview();
            LogService.info('✅ Local video preview started');
          } catch (e) {
            LogService.warning('Could not start preview: $e');
          }
        }

        // Unmute video stream and explicitly enable publishing.
        await _ensureVideoUnmuted(reason: 'toggle_video_on', force: true);
        if (_isInChannel) {
          try {
            await _engine!.updateChannelMediaOptions(
              ChannelMediaOptions(
                publishCameraTrack: true,
                publishScreenTrack: _isPublishingScreen,
                publishScreenCaptureVideo: _isPublishingScreen,
                publishScreenCaptureAudio: _isPublishingScreen && kIsWeb,
                publishMicrophoneTrack: _isAudioEnabled,
              ),
            );
            LogService.info(
              '📹 Channel media options updated: publishCameraTrack=true',
            );
          } catch (e) {
            LogService.warning(
              'Could not update channel media options on unmute: $e',
            );
          }
        }
        LogService.info('✅ Video enabled - should be visible to remote users');

        // Avoid aggressive verify loops on web; they can cause publish/mute churn.
        if (!kIsWeb) {
          await _ensureVideoUnmuted(
            reason: 'toggle_video_on_verify',
            force: true,
            logOnSuccess: true,
          );
        }

        if (kIsWeb) {
          _lastLocalVideoMuteTime = null;
          LogService.info(
            '[VIDEO_MUTE] local video muted=false, _lastLocalVideoMuteTime cleared',
          );
          debugPrint(
            '[VIDEO_MUTE] local video muted=false, _lastLocalVideoMuteTime cleared',
          );
        }
        // Restart periodic check
        if (_isInChannel) {
          _startVideoCheckTimer();
        }

        // Also schedule a check after a delay to ensure it stays unmuted.
        if (!kIsWeb) {
          Future.delayed(const Duration(seconds: 2), () async {
            if (_engine != null && _isInChannel && _isVideoEnabled) {
              await _ensureVideoUnmuted(
                reason: 'toggle_video_on_final_check',
                logOnSuccess: true,
              );
            }
          });
        }
      } else {
        // Disabling camera - mute video stream and explicitly stop publishing
        if (kIsWeb) {
          _lastLocalVideoMuteTime = DateTime.now();
          LogService.info(
            '[VIDEO_MUTE] local video muted=true, _lastLocalVideoMuteTime set to $_lastLocalVideoMuteTime',
          );
          debugPrint(
            '[VIDEO_MUTE] local video muted=true, _lastLocalVideoMuteTime set',
          );
        }
        await _engine!.muteLocalVideoStream(true);
        // Explicitly stop publishing camera track so remote reliably sees camera off
        if (_isInChannel) {
          try {
            await _engine!.updateChannelMediaOptions(
              ChannelMediaOptions(
                publishCameraTrack: false,
                publishScreenTrack: _isPublishingScreen,
                publishScreenCaptureVideo: _isPublishingScreen,
                publishScreenCaptureAudio: _isPublishingScreen && kIsWeb,
                publishMicrophoneTrack: _isAudioEnabled,
              ),
            );
            LogService.info(
              '📹 Channel media options updated: publishCameraTrack=false',
            );
          } catch (e) {
            LogService.warning(
              'Could not update channel media options on mute: $e',
            );
          }
          // Send camera state on every mute so remote UI updates even if Agora callbacks are delayed
          await sendCameraState(false);
        }
        LogService.info('📹 Video disabled - not visible to remote users');
        // On web, also stop local capture so browser webcam indicator/light turns off.
        if (kIsWeb) {
          try {
            await _engine!.stopPreview();
            await _engine!.disableVideo();
            LogService.info(
              '📹 Web capture stopped (preview + video disabled)',
            );
          } catch (e) {
            LogService.warning('Could not fully stop web camera capture: $e');
          }
        }
        // Stop periodic check when video is disabled
        _stopVideoCheckTimer();
        // On web, retry mute after short delay so second toggle reliably applies (desktop mute reliability)
        if (kIsWeb && _isInChannel) {
          Future.delayed(const Duration(milliseconds: 400), () async {
            if (_engine == null || !_isInChannel || _isVideoEnabled) return;
            try {
              await _engine!.muteLocalVideoStream(true);
              await _engine!.updateChannelMediaOptions(
                ChannelMediaOptions(
                  publishCameraTrack: false,
                  publishScreenTrack: _isPublishingScreen,
                  publishScreenCaptureVideo: _isPublishingScreen,
                  publishScreenCaptureAudio: _isPublishingScreen && kIsWeb,
                  publishMicrophoneTrack: _isAudioEnabled,
                ),
              );
              await sendCameraState(false);
              LogService.info(
                '📹 Mute retry applied: publishCameraTrack=false',
              );
            } catch (e) {
              LogService.warning('Mute retry failed: $e');
            }
          });
        }
      }
    } catch (e) {
      LogService.error('Failed to toggle video: $e');
      _errorController.add('Failed to toggle video: $e');
      _isVideoEnabled = !_isVideoEnabled; // Revert on error
    }
  }

  /// Preview-only camera enable/disable while screen sharing is active.
  ///
  /// Does *not* call `updateChannelMediaOptions`, so we don't fight the
  /// single-publish screen-share mode (camera publishing can conflict on
  /// certain platforms / browsers).
  Future<void> setLocalVideoPreviewEnabledDuringScreenShare(
    bool enabled,
  ) async {
    if (_engine == null || !_isInitialized) return;

    _isVideoEnabled = enabled;
    try {
      if (enabled) {
        if (kIsWeb) {
          await _engine!.enableVideo();
        }
        await _engine!.startPreview();
        await _engine!.muteLocalVideoStream(false);
      } else {
        await _engine!.muteLocalVideoStream(true);
      }
    } catch (e) {
      LogService.warning(
        'setLocalVideoPreviewEnabledDuringScreenShare failed: $e',
      );
    }
  }

  /// Toggle local audio (microphone mute/unmute)
  /// On web, Agora can take longer to apply mute/unmute; use a longer timeout to avoid TimeoutException.
  Future<void> toggleAudio() async {
    if (_engine == null || !_isInitialized) return;

    try {
      _isAudioEnabled = !_isAudioEnabled;
      final timeoutSeconds = kIsWeb ? 8 : 2;
      await _engine!
          .muteLocalAudioStream(!_isAudioEnabled)
          .timeout(Duration(seconds: timeoutSeconds));
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

  /// Configure local camera canvas after channel join.
  /// **Web only:** `setupLocalVideo` without a platform view handle must not run on
  /// Android/iOS — it clears the binding that [AgoraVideoView] establishes and freezes
  /// the preview after camera toggles (see `agora_video_view.dart`).
  Future<void> setupLocalVideoAfterJoin() async {
    if (_engine == null) return;
    if (!kIsWeb) return;
    if (_isPublishingScreen) return;
    try {
      await _engine!.setupLocalVideo(
        const VideoCanvas(
          uid: 0,
          sourceType: VideoSourceType.videoSourceCamera,
        ),
      );
    } catch (e) {
      LogService.warning('setupLocalVideoAfterJoin failed: $e');
      rethrow;
    }
  }

  /// Ensure local video track is actively published and preview is started when needed.
  /// Keeps engine details out of screen widgets.
  Future<void> ensureLocalVideoPublishing({
    bool startPreviewOnWeb = true,
  }) async {
    if (_engine == null || !_isInChannel || !_isVideoEnabled) return;
    if (_isPublishingScreen) return;
    try {
      if (kIsWeb && startPreviewOnWeb) {
        await _engine!.startPreview();
      }
      await _engine!.muteLocalVideoStream(false);
    } catch (e) {
      LogService.warning('ensureLocalVideoPublishing failed: $e');
      rethrow;
    }
  }

  /// Start screen sharing (engine primitive; UI hides learner start unless [AppConfig.enableLearnerScreenShare]).
  /// Tracks state so double-sharing is avoided and cancel resets UI.
  Future<void> startScreenSharing() async {
    if (_engine == null || !_isInChannel) {
      throw Exception('Engine not initialized or not in channel');
    }
    if (_isPublishingScreen) {
      LogService.info('Already sharing screen - ignoring duplicate start');
      return;
    }

    try {
      // CRITICAL: Start screen capture FIRST, then mute camera. This avoids the ~0.4s blackout
      // the remote user would see if we muted camera before capture was ready.
      // For web (including mobile web), use startScreenCapture.
      // Use 1280x720 for better responsiveness on mobile viewers and faster start.
      if (kIsWeb) {
        await _engine!.startScreenCapture(
          const ScreenCaptureParameters2(
            captureVideo: true,
            captureAudio: true,
            videoParams: ScreenVideoParameters(
              dimensions: VideoDimensions(width: 1280, height: 720),
              frameRate: 15,
              bitrate: 1500,
            ),
          ),
        );
      } else {
        // For native mobile (Android/iOS), use startScreenCapture with appropriate parameters
        // Note: Mobile screen sharing may have limitations compared to desktop
        await _engine!.startScreenCapture(
          const ScreenCaptureParameters2(
            captureVideo: true,
            captureAudio:
                false, // Audio may not be supported on all mobile platforms
            videoParams: ScreenVideoParameters(
              dimensions: VideoDimensions(
                width: 1280,
                height: 720,
              ), // Lower resolution for mobile
              frameRate: 15,
              bitrate: 1000, // Lower bitrate for mobile networks
            ),
          ),
        );
      }

      // CRITICAL: Set up local video view with screen source
      // This ensures the screen sharing stream is properly published
      await _engine!.setupLocalVideo(
        VideoCanvas(uid: 0, sourceType: VideoSourceType.videoSourceScreen),
      );

      // CRITICAL: Update channel media options to publish screen track
      // Without this, the screen sharing stream may not be published correctly
      try {
        if (!_isInChannel) {
          LogService.warning('Cannot update media options: not in channel');
        } else {
          await _engine!.updateChannelMediaOptions(
            ChannelMediaOptions(
              publishCameraTrack: false, // Disable camera track
              publishScreenTrack: true, // Enable screen track
              publishScreenCaptureVideo: true,
              publishScreenCaptureAudio: kIsWeb, // Audio capture only on web
              publishMicrophoneTrack: _isAudioEnabled, // Keep mic state
            ),
          );
          LogService.success(
            '✅ Channel media options updated for screen sharing (publishScreenTrack=true, publishCameraTrack=false)',
          );
        }
      } catch (e) {
        LogService.warning(
          'Could not update channel media options for screen sharing: $e',
        );
        // Continue anyway - some SDK versions may handle this automatically
      }

      _isPublishingScreen = true;
      LogService.success('✅ Screen sharing started');
      LogService.info(
        '📺 Screen sharing stream is now active - remote users should see your screen',
      );
      _applyScreenShareSignal(
        uid: _currentUID ?? 0,
        sharing: true,
        source: 'local_start',
      );

      // Mute camera AFTER screen capture is ready - avoids blackout on remote
      if (_isVideoEnabled && _engine != null) {
        LogService.info('📹 Muting camera now that screen capture is active');
        await _engine!.muteLocalVideoStream(true);
      }

      // Notify remote users via data stream
      _notifyRemoteUsersScreenSharing(true);
    } catch (e) {
      // Check if user cancelled the browser/device prompt (avoid error dialog and frozen "connecting" state)
      final errorStr = e.toString().toLowerCase();
      final isUserCancel =
          errorStr.contains('user') &&
              (errorStr.contains('cancel') || errorStr.contains('canceled')) ||
          errorStr.contains('canceled') ||
          errorStr.contains('cancelled') ||
          errorStr.contains('abort');
      final isPermissionDenied =
          errorStr.contains('notallowed') ||
          errorStr.contains('not allowed') ||
          errorStr.contains('permission') ||
          errorStr.contains('denied');
      if (isUserCancel || isPermissionDenied) {
        LogService.info('Screen sharing cancelled or denied by user');
        _applyScreenShareSignal(
          uid: _currentUID ?? 0,
          sharing: false,
          source: 'local_start_cancel',
          forceStopOwner: true,
        );
        return;
      }

      LogService.warning('Screen sharing error (not showing to user): $e');
      _applyScreenShareSignal(
        uid: _currentUID ?? 0,
        sharing: false,
        source: 'local_start_error',
        forceStopOwner: true,
      );
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
              publishCameraTrack: _isVideoEnabled, // Restore camera track
              publishScreenTrack: false, // Disable screen track
              publishScreenCaptureVideo: false,
              publishScreenCaptureAudio: false,
              publishMicrophoneTrack: _isAudioEnabled, // Keep mic state
            ),
          );
          LogService.success(
            '✅ Channel media options updated to stop screen sharing (publishScreenTrack=false, publishCameraTrack=$_isVideoEnabled)',
          );
        }
      } catch (e) {
        LogService.warning(
          'Could not update channel media options to stop screen sharing: $e',
        );
        // Continue anyway - some SDK versions may handle this automatically
      }

      // CRITICAL: Restore camera video stream when screen sharing stops
      // Switch back to camera source
      if (_isVideoEnabled) {
        LogService.info(
          '📹 Restoring camera video stream after screen sharing',
        );
        await _engine!.setupLocalVideo(
          VideoCanvas(uid: 0, sourceType: VideoSourceType.videoSourceCamera),
        );
        await _engine!.muteLocalVideoStream(false);
        LogService.info('✅ Camera video stream restored');
      }

      _isPublishingScreen = false;
      LogService.success('[SCREEN_SHARE] ✅ Screen sharing stopped');
      _applyScreenShareSignal(
        uid: _currentUID ?? 0,
        sharing: false,
        source: 'local_stop',
        forceStopOwner: true,
      );
      // CRITICAL: Notify remote so learner receives screen_share_stop and shows tutor camera again
      await _notifyRemoteUsersScreenSharing(false);
    } catch (e) {
      _isPublishingScreen = false;
      _applyScreenShareSignal(
        uid: _currentUID ?? 0,
        sharing: false,
        source: 'local_stop_error',
        forceStopOwner: true,
      );
      LogService.error('Failed to stop screen sharing: $e');
      _errorController.add('Failed to stop screen sharing: $e');
    }
  }

  void _applyScreenShareSignal({
    required int uid,
    required bool sharing,
    required String source,
    bool forceStopOwner = false,
  }) {
    if (uid <= 0) return;
    final selfUid = _currentUID;
    final isSelf = selfUid != null && uid == selfUid;
    if (!isSelf && !_isValidRemoteUid(uid)) return;

    final now = DateTime.now();
    if (sharing) {
      _screenShareOwnerUid = uid;
      _screenShareOwnerLockUntil = now.add(_kScreenShareStopGuard);
    } else if (_screenShareOwnerUid == uid) {
      final guardActive = now.isBefore(_screenShareOwnerLockUntil);
      if (!forceStopOwner && guardActive) {
        LogService.debug(
          '📺 [SCREEN_SHARE] Ignored early stop during guard: uid=$uid source=$source',
        );
      } else {
        _screenShareOwnerUid = null;
      }
    }

    _screenSharingController.add(<String, dynamic>{
      'uid': uid,
      'sharing': sharing,
      'ownerUid': _screenShareOwnerUid,
    });
  }

  /// Notify remote users about screen sharing state via Supabase Realtime (works when
  /// Agora data stream is missing on web) and via Agora data stream when available.
  Future<void> _notifyRemoteUsersScreenSharing(bool isSharing) async {
    final message = isSharing ? 'screen_share_start' : 'screen_share_stop';

    if (_reactionChannel != null && _currentUID != null) {
      try {
        await _reactionChannel!.sendBroadcastMessage(
          event: 'screen_share',
          payload: <String, dynamic>{
            'fromUid': _currentUID,
            'sharing': isSharing,
          },
        );
        LogService.success('✅ Screen share signalled via Realtime: $message');
      } catch (e) {
        LogService.warning('Realtime screen_share broadcast failed: $e');
      }
    }

    if (_dataStreamId == null || _engine == null || !_isInChannel) {
      if (_dataStreamId == null) {
        LogService.info(
          'Screen share: Agora data stream unavailable — using Realtime only',
        );
      } else if (!_isInChannel || _engine == null) {
        LogService.warning(
          'Cannot send screen sharing data stream: dataStreamId=$_dataStreamId, engine=${_engine != null}, inChannel=$_isInChannel',
        );
      }
      return;
    }

    try {
      final data = Uint8List.fromList(utf8.encode(message));
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

  /// Send emoji reaction to remote users via Agora data stream and/or Supabase Realtime (Realtime works on web when data stream is unavailable).
  Future<void> sendReaction(String emoji) async {
    LogService.info(
      '🎭 [EMOJI] sendReaction called: emoji="$emoji", dataStreamId=$_dataStreamId, inChannel=$_isInChannel, hasRealtimeChannel=${_reactionChannel != null}',
    );
    if (!_isInChannel || _engine == null) {
      LogService.warning(
        'Cannot send reaction: not in channel or engine null. emoji="$emoji"',
      );
      return;
    }

    // 1) Send via Agora data stream when available (mobile / when web SDK returns valid stream id)
    if (_dataStreamId != null) {
      try {
        final message = 'reaction:$emoji';
        final messageBytes = utf8.encode(message);
        final data = Uint8List.fromList(messageBytes);
        LogService.info(
          '📤 Sending reaction via Agora: emoji="$emoji", streamId=$_dataStreamId',
        );
        await _engine!.sendStreamMessage(
          streamId: _dataStreamId!,
          data: data,
          length: data.length,
        );
        LogService.success('✅ Sent reaction via data stream: $emoji');
      } catch (e) {
        LogService.error('❌ Failed to send reaction via Agora: $e');
      }
    } else {
      LogService.info(
        '📤 Agora data stream not available (e.g. web); using Realtime fallback if available.',
      );
    }

    // 2) Send via Realtime fallback so web can send and mobile can receive from web
    if (_reactionChannel != null && _currentUID != null) {
      try {
        _reactionChannel!.sendBroadcastMessage(
          event: 'reaction',
          payload: {'fromUid': _currentUID, 'emoji': emoji},
        );
        LogService.success(
          '✅ [EMOJI] Sent reaction via Realtime fallback: $emoji',
        );
      } catch (e) {
        LogService.warning('Failed to send reaction via Realtime: $e');
      }
    } else if (_dataStreamId == null) {
      LogService.warning(
        'Cannot send reaction (other user will not see it): dataStreamId=null and Realtime channel not set. '
        'emoji="$emoji", platform=${kIsWeb ? "WEB" : "MOBILE"}',
      );
    }
  }

  /// Send camera state via Agora data stream when available, with Realtime fallback
  /// when [createDataStream] is unavailable (common on web).
  Future<void> sendCameraState(bool isEnabled) async {
    var sentViaStream = false;
    if (_dataStreamId != null && _engine != null && _isInChannel) {
      try {
        final message = isEnabled ? 'camera_on' : 'camera_off';
        final messageBytes = message.codeUnits;
        final data = Uint8List.fromList(messageBytes);

        await _engine!.sendStreamMessage(
          streamId: _dataStreamId!,
          data: data,
          length: data.length,
        );
        LogService.info('📹 Sent camera state via data stream: $message');
        sentViaStream = true;
      } catch (e) {
        LogService.warning('📹 Failed to send camera state via data stream: $e');
      }
    }

    if (sentViaStream) {
      return;
    }

    if (_reactionChannel != null &&
        _currentUID != null) {
      try {
        await _reactionChannel!.sendBroadcastMessage(
          event: 'camera_state',
          payload: <String, dynamic>{
            'fromUid': _currentUID,
            'enabled': isEnabled,
          },
        );
        LogService.info(
          '📹 Sent camera state via Realtime: enabled=$isEnabled',
        );
        return;
      } catch (e) {
        LogService.warning('📹 Failed to send camera state via Realtime: $e');
      }
    }

    LogService.warning(
      '📹 Cannot send camera state: dataStreamId=$_dataStreamId, '
      'reactionChannel=${_reactionChannel != null}, engine=${_engine != null}, inChannel=$_isInChannel',
    );
  }

  bool _videoSourceLooksLikeRemoteScreenCapture(VideoSourceType sourceType) {
    return sourceType == VideoSourceType.videoSourceScreen ||
        sourceType == VideoSourceType.videoSourceScreenPrimary ||
        sourceType == VideoSourceType.videoSourceScreenSecondary;
  }

  /// When [createDataStream] fails (common on web: id 0), `screen_share_start`
  /// datagrams never arrive and the learner keeps rendering camera while the tutor
  /// publishes only screen. [onVideoSizeChanged] carries [VideoSourceType], so use
  /// it as a telemetry fallback aligned with datagram signaling.
  void _applyRemoteScreenShareHintFromVideoSize({
    required int uid,
    required VideoSourceType sourceType,
    required int width,
    required int height,
  }) {
    if (!_isValidRemoteUid(uid)) return;

    final isScreen = _videoSourceLooksLikeRemoteScreenCapture(sourceType);
    final hasDims = width > 0 && height > 0;

    if (isScreen && hasDims) {
      if (_screenShareOwnerUid == uid) return;
      LogService.info(
        '📺 [SCREEN_TELEM] Remote screen via onVideoSizeChanged: uid=$uid ${width}x$height',
      );
      _applyScreenShareSignal(
        uid: uid,
        sharing: true,
        source: 'video_size_hint_start',
      );
      return;
    }

    if (isScreen && !hasDims && _screenShareOwnerUid == uid) {
      LogService.info(
        '📺 [SCREEN_TELEM] Remote screen zero-sized — treating as stopped: uid=$uid',
      );
      _applyScreenShareSignal(
        uid: uid,
        sharing: false,
        source: 'video_size_hint_zero',
      );
      return;
    }

    if (!isScreen && hasDims && _screenShareOwnerUid == uid) {
      LogService.info(
        '📺 [SCREEN_TELEM] Remote camera track after screen share: uid=$uid',
      );
      _applyScreenShareSignal(
        uid: uid,
        sharing: false,
        source: 'video_size_hint_camera_restore',
      );
    }
  }

  /// Manually detect remote screen sharing
  /// Call this when setting up remote video view with VideoSourceType.videoSourceScreen
  /// Since onUserPublished is not available in this SDK version, we use manual detection
  void detectRemoteScreenSharing(int remoteUid, bool isSharing) {
    LogService.info(
      '📺 Manual screen sharing detection: UID=$remoteUid, sharing=$isSharing',
    );
    _applyScreenShareSignal(
      uid: remoteUid,
      sharing: isSharing,
      source: 'manual_detect',
    );
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_engine == null || !_isInitialized) return;

    try {
      await _engine!.switchCamera().timeout(const Duration(seconds: 2));
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
        await _safeReleaseEngine(reason: 'dispose()');
      }

      _isInitialized = false;
      _updateState(AgoraSessionState.disconnected);

      await _stateController.close();
      await _userJoinedController.close();
      await _userOfflineController.close();
      await _connectionStateController.close();
      await _errorController.close();
      await _remoteVideoMutedController.close();
      await _remoteVideoFrameController.close();
      await _remoteAudioMutedController.close();
      await _screenSharingController.close();
      await _userLeftController.close();
      await _remoteNetworkQualityController.close();
      _reactionChannel?.unsubscribe();
      _reactionChannel = null;
      await _reactionController.close();

      LogService.success('Agora engine disposed');
    } catch (e) {
      LogService.error('Error disposing Agora engine: $e');
    }
  }

  /// Adapt video (encoder + remote stream type) based on network conditions.
  Future<void> _adaptVideoQuality(QualityType quality) async {
    if (_engine == null || !_isInChannel) return;
    if (!_isVideoEnabled || _isPublishingScreen) return;

    final decision = _qualityController.onSample(
      network: quality,
      at: DateTime.now(),
    );
    if (decision == null) return;

    VideoEncoderConfiguration targetConfig;
    String targetTier;
    switch (decision.tier) {
      case VideoQualityTier.high720p:
        targetConfig = _quality720p;
        targetTier = 'high-720p';
        break;
      case VideoQualityTier.medium480p:
        targetConfig = _quality480p;
        targetTier = 'medium-480p';
        break;
      case VideoQualityTier.low360p:
        targetConfig = _quality360pVeryLow;
        targetTier = 'low-360p';
        break;
    }

    final previousTier = _currentQualityTier;
    try {
      await _engine!.setVideoEncoderConfiguration(targetConfig);

      // Pair encoder tier with appropriate remote stream type so we do not
      // waste bandwidth on extremely poor networks.
      if (!kIsWeb && _supportsRemoteDefaultStreamTypeControl) {
        try {
          if (targetTier == 'high-720p') {
            await _engine!.setRemoteDefaultVideoStreamType(
              VideoStreamType.videoStreamHigh,
            );
          } else {
            await _engine!.setRemoteDefaultVideoStreamType(
              VideoStreamType.videoStreamLow,
            );
          }
        } catch (e) {
          if (_isAgoraNotSupported(e)) {
            _supportsRemoteDefaultStreamTypeControl = false;
            LogService.warning(
              '[NET] Remote default stream type control unsupported; disabling further default-stream API calls.',
            );
          } else {
            LogService.warning(
              '[NET] Failed to update remote default stream type: $e',
            );
          }
        }
      }

      _currentQualityTier = targetTier;
      LogService.info(
        '[NET] Video quality adapted to $targetTier (network: $quality)',
      );
      if (previousTier != targetTier) {
        _emitQoe('quality_tier_changed', <String, dynamic>{
          'from_tier': previousTier,
          'to_tier': targetTier,
          'network_quality': quality.name,
        });
      }
      final dims = targetConfig.dimensions;
      if (dims != null) {
        LogService.info(
          '📊 Quality config: ${dims.width}x${dims.height} @ ${targetConfig.frameRate}fps, ${targetConfig.bitrate}kbps',
        );
      } else {
        LogService.info(
          '📊 Quality config: @ ${targetConfig.frameRate}fps, ${targetConfig.bitrate}kbps',
        );
      }
    } catch (e) {
      LogService.warning('Failed to adapt video quality: $e');
    }
  }

  Future<void> _applyRemoteStreamPriority({
    Set<int> speakingUids = const <int>{},
  }) async {
    if (_engine == null || !_isInChannel) return;
    if (!AppConfig.enableClassroomDualStream) return;
    if (kIsWeb || !_supportsRemoteStreamTypeControl) return;
    // For 1:1 calls, always keep the single remote at default/high quality and
    // avoid stream-type thrash. Prioritization is only needed for multi-user rooms.
    if (_remoteParticipantUids.length <= 1) return;
    final now = DateTime.now();
    if (_lastRemoteStreamPriorityAppliedAt != null &&
        now.difference(_lastRemoteStreamPriorityAppliedAt!) <
            const Duration(seconds: 2)) {
      return;
    }
    _lastRemoteStreamPriorityAppliedAt = now;
    final decision = _streamPriorityPolicy.decide(
      remoteUids: _remoteParticipantUids,
      speakingUids: speakingUids,
      currentSpotlightUid: _spotlightRemoteUid,
      pinnedRemoteUid: _dualStreamPinnedRemoteUid,
    );
    _spotlightRemoteUid = decision.spotlightUid;

    for (final uid in decision.highPriorityUids) {
      try {
        final previous = _lastAppliedRemoteStreamType[uid];
        if (previous == VideoStreamType.videoStreamHigh) continue;
        await _engine!.setRemoteVideoStreamType(
          uid: uid,
          streamType: VideoStreamType.videoStreamHigh,
        );
        if (previous != VideoStreamType.videoStreamHigh) {
          _lastAppliedRemoteStreamType[uid] = VideoStreamType.videoStreamHigh;
          _emitQoe('remote_stream_type_changed', <String, dynamic>{
            'uid': uid,
            'stream_type': 'high',
            'spotlight_uid': _spotlightRemoteUid,
          });
        }
      } catch (e) {
        if (_isAgoraNotSupported(e)) {
          _supportsRemoteStreamTypeControl = false;
          LogService.warning(
            '[NET] Remote stream type control not supported on this platform; disabling further stream-priority API calls.',
          );
          break;
        }
        LogService.warning('[NET] Failed to set HIGH stream for uid=$uid: $e');
      }
    }
    for (final uid in decision.lowPriorityUids) {
      try {
        final previous = _lastAppliedRemoteStreamType[uid];
        if (previous == VideoStreamType.videoStreamLow) continue;
        await _engine!.setRemoteVideoStreamType(
          uid: uid,
          streamType: VideoStreamType.videoStreamLow,
        );
        if (previous != VideoStreamType.videoStreamLow) {
          _lastAppliedRemoteStreamType[uid] = VideoStreamType.videoStreamLow;
          _emitQoe('remote_stream_type_changed', <String, dynamic>{
            'uid': uid,
            'stream_type': 'low',
            'spotlight_uid': _spotlightRemoteUid,
          });
        }
      } catch (e) {
        if (_isAgoraNotSupported(e)) {
          _supportsRemoteStreamTypeControl = false;
          LogService.warning(
            '[NET] Remote stream type control not supported on this platform; disabling further stream-priority API calls.',
          );
          break;
        }
        LogService.warning('[NET] Failed to set LOW stream for uid=$uid: $e');
      }
    }
  }

  bool _isAgoraNotSupported(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('not supported') || value.contains('(-4');
  }

  /// Attempt to recover remote video stream
  Future<void> _attemptVideoRecovery(
    int remoteUid,
    RtcConnection connection,
  ) async {
    if (_engine == null || !_isInChannel) return;

    final owner = _screenShareOwnerUid;
    if (owner != null && owner == remoteUid) {
      LogService.debug(
        '[RECOVERY] Skipping video recovery — UID=$remoteUid is the active screen-share publisher',
      );
      return;
    }

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
      LogService.warning(
        '⚠️ Max video recovery attempts reached for UID=$remoteUid',
      );
      return;
    }

    _videoRecoveryAttempts[remoteUid] = attempts + 1;
    _lastRecoveryAttempt[remoteUid] = DateTime.now();

    try {
      LogService.info(
        '[RECOVERY] Attempting video recovery for UID=$remoteUid (attempt ${attempts + 1}/$_maxRecoveryAttempts)',
      );

      // Note: Agora SDK automatically handles video subscription
      // Video recovery is primarily handled by the SDK's automatic reconnection
      // We log the recovery attempt and let the SDK handle the actual resubscription
      // The onRemoteVideoStateChanged event will fire when video becomes active again

      // Wait a bit to allow SDK to recover
      await Future.delayed(const Duration(milliseconds: 1000));

      LogService.info('✅ Video recovery attempt completed for UID=$remoteUid');
      LogService.info(
        '💡 Video stream should recover automatically via Agora SDK',
      );

      // Reset attempts on successful recovery (will be reset when video becomes active)
    } catch (e) {
      LogService.warning(
        'Video recovery attempt failed for UID=$remoteUid: $e',
      );
    }
  }

  /// Public entry to trigger camera recovery (e.g. after user taps Retry on error).
  Future<void> tryRecoverCamera() async {
    await _recoverCamera();
  }

  /// Recover local camera after interruption
  Future<void> _recoverCamera() async {
    if (_engine == null || !_isInChannel || !_isVideoEnabled) return;
    if (_isRecoveringCamera) return;

    // Check cooldown
    if (_lastCameraRecoveryAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(
        _lastCameraRecoveryAttempt!,
      );
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
      LogService.info(
        '🔄 Attempting camera recovery (attempt $_cameraRecoveryAttempts/$_maxCameraRecoveryAttempts)',
      );

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
    if (_joinInProgress) return;
    if (!_isInChannel && _lastSessionId == null)
      return; // No session to reconnect to

    // Check cooldown
    if (_lastReconnectionAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(
        _lastReconnectionAttempt!,
      );
      if (timeSinceLastAttempt < _reconnectionCooldown) {
        return;
      }
    }

    // Check max attempts
    if (_reconnectionAttempts >= _maxReconnectionAttempts) {
      LogService.error('❌ Max reconnection attempts reached');
      _errorController.add(
        'Connection lost. Please refresh the page to reconnect.',
      );
      _emitQoe('reconnect_exhausted', <String, dynamic>{
        'max_attempts': _maxReconnectionAttempts,
      });
      return;
    }

    _isReconnecting = true;
    _reconnectionAttempts++;
    _lastReconnectionAttempt = DateTime.now();

    try {
      LogService.info(
        '🔄 Attempting to reconnect (attempt $_reconnectionAttempts/$_maxReconnectionAttempts)',
      );

      if (_lastSessionId != null &&
          _lastUserId != null &&
          _lastUserRole != null) {
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
      _emitQoe('reconnect_attempt_error', <String, dynamic>{
        'attempt_count': _reconnectionAttempts,
        'error': e.toString(),
      });
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
    final isUnstable =
        quality == QualityType.qualityPoor ||
        quality == QualityType.qualityBad ||
        quality == QualityType.qualityDown;

    // Track consecutive poor quality reports
    if (isUnstable) {
      _remotePoorQualityCount[remoteUid] =
          (_remotePoorQualityCount[remoteUid] ?? 0) + 1;
    } else {
      // Reset count on good quality
      _remotePoorQualityCount[remoteUid] = 0;
    }

    // Emit unstable sooner: 1–2 consecutive poor reports (faster "Poor connection" / "Reconnecting" feedback)
    final consecutivePoorCount = _remotePoorQualityCount[remoteUid] ?? 0;
    final shouldWarn = isUnstable && consecutivePoorCount >= 1;

    // Emit network quality event
    _remoteNetworkQualityController.add({
      'uid': remoteUid,
      'quality': quality,
      'isUnstable': shouldWarn,
    });

    if (shouldWarn) {
      LogService.warning(
        '⚠️ Remote user UID=$remoteUid has unstable connection (quality: $quality, consecutive poor: $consecutivePoorCount)',
      );
    }
    // Avoid logging "stable" on every callback - reduces log spam and CPU
  }

  /// Calculate optimal buffer size based on network quality
  int _calculateBufferSize(QualityType quality) {
    // Buffer size in milliseconds
    // Note: QualityType enum: excellent(0), good(1), poor(2), bad(3), veryBad(4), down(5), unsupported(6)
    if (quality == QualityType.qualityExcellent ||
        quality == QualityType.qualityGood) {
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
      final timeSinceLastActivity = DateTime.now().difference(
        _lastRemoteVideoActivity!,
      );
      if (timeSinceLastActivity > const Duration(seconds: 30)) {
        LogService.warning(
          '⚠️ Remote video inactive for ${timeSinceLastActivity.inSeconds}s',
        );

        // Attempt recovery if video should be active
        if (_lastActiveRemoteUid != null && _currentConnection != null) {
          await _attemptVideoRecovery(
            _lastActiveRemoteUid!,
            _currentConnection!,
          );
        }
      }
    }

    // Verify local video is still publishing if enabled
    if (_isVideoEnabled && _remoteParticipantUids.isNotEmpty) {
      try {
        // Ensure video is unmuted only when peers are present.
        await _ensureVideoUnmuted(reason: 'health_check');
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

  /// Fetch a fresh token and call [RtcEngine.renewToken] (single-flight).
  Future<void> _renewRtcToken({required String trigger}) async {
    if (_tokenRenewInFlight) {
      LogService.debug('[CALL] Token renew already in progress ($trigger)');
      return;
    }
    _tokenRenewInFlight = true;
    try {
      final sessionId = _lastSessionId;
      if (sessionId == null ||
          sessionId.isEmpty ||
          _engine == null ||
          !_isInChannel) {
        LogService.warning(
          '[CALL] Cannot refresh token ($trigger): no session or not in channel',
        );
        return;
      }
      LogService.info('[CALL] Refreshing RTC token ($trigger)');
      final tokenData = await AgoraTokenService.fetchToken(sessionId);
      final newToken = tokenData['token'] as String?;
      if (newToken == null || newToken.isEmpty) {
        LogService.warning(
          '[CALL] Token refresh returned empty token ($trigger)',
        );
        _emitQoe('token_renew_failed', <String, dynamic>{
          'trigger': trigger,
          'reason': 'empty_token',
        });
        return;
      }
      await _engine!.renewToken(newToken);
      LogService.info('[CALL] Token renewed successfully ($trigger)');
      _emitQoe('token_renewed', <String, dynamic>{'trigger': trigger});
    } catch (e) {
      LogService.warning('[CALL] Token refresh failed ($trigger): $e');
      _emitQoe('token_renew_failed', <String, dynamic>{
        'trigger': trigger,
        'error': e.toString(),
      });
    } finally {
      _tokenRenewInFlight = false;
    }
  }

  /// Register event handlers
  void _registerEventHandlers() {
    if (_engine == null) return;

    // User joined channel
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
          LogService.success(
            'Successfully joined channel (elapsed: ${elapsed}ms)',
          );
          LogService.info(
            'Channel: ${connection.channelId}, Local UID: ${connection.localUid}',
          );
          LogService.info('Current UID in channel: ${_currentUID}');
          LogService.info(
            '📹 Storing connection for video views: channelId=${connection.channelId}, localUid=${connection.localUid}',
          );
          _isInChannel = true;
          _joinInProgress = false;
          _currentConnection = connection; // Store connection for video views
          LogService.info(
            '✅ Connection stored - remote video views can now use this connection',
          );

          // Reset reconnection attempts on successful join
          _reconnectionAttempts = 0;

          // Start video health check
          _startVideoHealthCheck();

          // Enable volume indication for talking indicator (interval 300ms, smooth 3)
          try {
            await _engine!.enableAudioVolumeIndication(
              interval: 500,
              smooth: 3,
              reportVad: true,
            );
          } catch (e) {
            LogService.warning('enableAudioVolumeIndication failed: $e');
          }

          // Realtime fallback for reactions (works on web when Agora data stream returns 0; both peers subscribe so delivery works)
          _setupReactionRealtimeChannel();

          // CRITICAL: Create data stream for reactions, screen share notifications, camera state
          // Retry up to 2 times (helps on web where first attempt can fail)
          // On web, defer creation to avoid callback timing issues (emoji reactions regression)
          Future<void> tryCreateDataStream() async {
            for (var attempt = 1; attempt <= 2; attempt++) {
              try {
                final streamId = await _engine!.createDataStream(
                  const DataStreamConfig(ordered: true),
                );
                if (streamId > 0) {
                  _dataStreamId = streamId;
                  LogService.success(
                    'Data stream created: streamId=$_dataStreamId (reactions, camera state, screen share sync) [attempt $attempt]',
                  );
                  return;
                }
                LogService.warning(
                  'createDataStream attempt $attempt returned invalid id: $streamId',
                );
              } catch (e) {
                LogService.warning(
                  'createDataStream attempt $attempt failed: $e',
                );
              }
              if (attempt < 2 && _engine != null && _isInChannel) {
                await Future<void>.delayed(const Duration(milliseconds: 800));
              }
            }
            _dataStreamId = null;
            LogService.warning(
              'Data stream creation failed after retries - emoji reactions and screen-share sync will not work. '
              'On web this is a known SDK limitation (createDataStream returns 0).',
            );
          }

          if (kIsWeb) {
            Future<void>.delayed(const Duration(milliseconds: 400), () async {
              if (_engine != null && _isInChannel) await tryCreateDataStream();
            });
          } else {
            await tryCreateDataStream();
          }

          _updateState(AgoraSessionState.connected);

          // CRITICAL: Ensure video is publishing after joining (especially important for web)
          // Try multiple times with delays to ensure video publishes
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (_engine != null && _isInChannel && _isVideoEnabled) {
              try {
                // Explicitly unmute video stream
                await _engine!.muteLocalVideoStream(false);
                LogService.info(
                  '✅ Verified local video stream is unmuted (publishing) after join',
                );
                LogService.info(
                  '📹 Your video should now be visible to remote users',
                );

                // Try again after a short delay to ensure it sticks
                Future.delayed(const Duration(milliseconds: 1000), () async {
                  if (_engine != null && _isInChannel && _isVideoEnabled) {
                    try {
                      await _engine!.muteLocalVideoStream(false);
                      LogService.info(
                        '✅ Double-checked: Video stream is unmuted',
                      );
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
              LogService.warning(
                '⚠️ Cannot verify video publishing: engine=${_engine != null}, inChannel=$_isInChannel, videoEnabled=$_isVideoEnabled',
              );
            }
          });

          // After joining, check for existing remote users
          // Note: onUserJoined only fires for users who join AFTER you
          // If both users join simultaneously, we need to wait for video events
          LogService.info(
            'Waiting for remote user detection via video events...',
          );
          LogService.info(
            '💡 TIP: Make sure BOTH users (tutor AND learner) have joined the session',
          );
          LogService.info(
            '💡 TIP: Check that both users have different UIDs in their logs',
          );
          LogService.info(
            '💡 TIP: Remote user will be detected when they publish video/audio',
          );

          // Schedule a check after a delay to provide diagnostic info
          Future.delayed(const Duration(seconds: 5), () {
            if (_isInChannel) {
              LogService.info('📊 Status check after 5 seconds:');
              LogService.info('   - In channel: $_isInChannel');
              LogService.info('   - Current UID: $_currentUID');
              LogService.info('   - Channel: $_currentChannelName');
              LogService.info('   - Video enabled: $_isVideoEnabled');
              LogService.info(
                '   - Connection stored: ${_currentConnection != null}',
              );
              LogService.info('💡 If no remote user detected, verify:');
              LogService.info(
                '   1. Both users have joined (check both browser logs)',
              );
              LogService.info('   2. Both users have different UIDs');
              LogService.info(
                '   3. Both users granted camera/mic permissions',
              );
              LogService.info('   4. Both users are in the same channel');
              LogService.info('   5. Both users have cameras enabled');
            }
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          LogService.info(
            '[CALL] Remote user joined: UID=$remoteUid (elapsed: ${elapsed}ms)',
          );
          LogService.info(
            'Connection details: channelId=${connection.channelId}, localUid=${connection.localUid}',
          );
          LogService.info(
            '💡 Remote video is automatically subscribed by default',
          );
          LogService.info(
            '📹 Current stored connection: channelId=${_currentConnection?.channelId}, localUid=${_currentConnection?.localUid}',
          );
          if (!_isValidRemoteUid(remoteUid)) {
            LogService.debug(
              'Ignoring onUserJoined for non-remote uid=$remoteUid (self=$_currentUID)',
            );
            return;
          }
          // Ensure connection is stored (in case onJoinChannelSuccess didn't fire yet)
          if (_currentConnection == null && connection.channelId != null) {
            _currentConnection = connection;
            LogService.info('✅ Connection stored from onUserJoined event');
          }

          // CRITICAL: Reset offline tracking when user rejoins
          _resetUserOfflineTracking(remoteUid);
          _remoteParticipantUids.add(remoteUid);
          unawaited(_applyRemoteStreamPriority());

          _userJoinedController.add(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          LogService.info('User offline: $remoteUid, reason: $reason');
          debugPrint(
            '[userOffline] remoteUid=$remoteUid reason=$reason kIsWeb=$kIsWeb _lastLocalVideoMuteTime=$_lastLocalVideoMuteTime',
          );
          if (!_isValidRemoteUid(remoteUid)) {
            LogService.debug(
              'Ignoring onUserOffline for non-remote uid=$remoteUid (self=$_currentUID)',
            );
            return;
          }
          // On web (desktop and mobile), Agora can fire spurious userOffline(Quit) when LOCAL user mutes video.
          // Ignore Quit only within 5s of our own mute; after that treat refresh/close as "user left".
          if (kIsWeb &&
              reason == UserOfflineReasonType.userOfflineQuit &&
              _lastLocalVideoMuteTime != null) {
            final sinceMute = DateTime.now().difference(
              _lastLocalVideoMuteTime!,
            );
            if (sinceMute < _webMuteOfflineIgnoreWindow) {
              LogService.warning(
                '⚠️ [WEB] IGNORED (within 5s of local mute) userOffline(Quit) UID=$remoteUid',
              );
              return;
            }
          }

          // Handle different offline reasons using central grace policy.
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

          final graceDecision = _reconnectGracePolicy.onUserOffline(
            reason: reason,
            isWeb: kIsWeb,
          );

          LogService.info(
            '📤 Remote user offline: UID=$remoteUid ($reasonText, definitive: ${graceDecision.confirmLeaveImmediately}, grace=${graceDecision.graceDuration.inSeconds}s)',
          );

          // Track offline timestamp
          _userOfflineTimestamps[remoteUid] = DateTime.now();
          _userOfflineCount[remoteUid] =
              (_userOfflineCount[remoteUid] ?? 0) + 1;

          // Cancel any existing grace period timer for this user
          _userLeftGracePeriodTimers[remoteUid]?.cancel();

          // If user explicitly quit (and not on web), confirm immediately
          if (graceDecision.confirmLeaveImmediately) {
            LogService.info(
              '[userOffline] CONFIRMED user left (definitive) remoteUid=$remoteUid reason=$reasonText',
            );
            _confirmUserLeft(remoteUid);
          } else {
            // For transient disconnects use grace period before confirming leave.
            final graceDuration = graceDecision.graceDuration == Duration.zero
                ? _userLeftGracePeriod
                : graceDecision.graceDuration;
            debugPrint(
              '[userOffline] GRACE started ${graceDuration.inSeconds}s for remoteUid=$remoteUid',
            );
            LogService.info(
              '[userOffline] GRACE started (${graceDuration.inSeconds}s) for remoteUid=$remoteUid',
            );
            _userLeftGracePeriodTimers[remoteUid] = Timer(graceDuration, () {
              final offlineTime = _userOfflineTimestamps[remoteUid];
              if (offlineTime != null) {
                final timeSinceOffline = DateTime.now().difference(offlineTime);
                if (timeSinceOffline >= graceDuration &&
                    (_userOfflineCount[remoteUid] ?? 0) >=
                        (kIsWeb &&
                                reason == UserOfflineReasonType.userOfflineQuit
                            ? 1
                            : _maxOfflineEvents)) {
                  LogService.info(
                    '[userOffline] CONFIRMED user left after grace remoteUid=$remoteUid reason=$reasonText',
                  );
                  _confirmUserLeft(remoteUid);
                } else {
                  LogService.info(
                    '⏳ User $remoteUid still offline but may be reconnecting...',
                  );
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
        onFirstRemoteVideoDecoded:
            (
              RtcConnection connection,
              int remoteUid,
              int width,
              int height,
              int elapsed,
            ) {
              LogService.info(
                '[MEDIA] Remote video decoded: UID=$remoteUid (${width}x${height}, elapsed: ${elapsed}ms)',
              );
              LogService.info(
                'This indicates a remote user is in the channel and publishing video',
              );
              LogService.info(
                '💡 Video stream is automatically subscribed - video should display now',
              );
              LogService.info(
                '📹 Connection for video view: channelId=${connection.channelId}, localUid=${connection.localUid}',
              );
              if (!_isValidRemoteUid(remoteUid)) {
                LogService.debug(
                  'Ignoring onFirstRemoteVideoDecoded for non-remote uid=$remoteUid (self=$_currentUID)',
                );
                return;
              }
              // Ensure connection is stored
              if (_currentConnection == null && connection.channelId != null) {
                _currentConnection = connection;
                LogService.info(
                  '✅ Connection stored from onFirstRemoteVideoDecoded event',
                );
              }

              // CRITICAL: Reset offline tracking when video is decoded (user is active)
              _resetUserOfflineTracking(remoteUid);
              _cancelRemoteVideoStoppedProvisional(remoteUid);

              _remoteVideoMutedController.add({
                'uid': remoteUid,
                'muted': false,
              });
              _remoteVideoFrameController.add({
                'uid': remoteUid,
                'ready': true,
              });
            },
        // Carries VideoSourceType (unlike onRemoteVideoStateChanged) — fallback when
        // data-stream screen_share_* signals are unavailable on web.
        onVideoSizeChanged:
            (
              RtcConnection connection,
              VideoSourceType sourceType,
              int uid,
              int width,
              int height,
              int rotation,
            ) {
              _applyRemoteScreenShareHintFromVideoSize(
                uid: uid,
                sourceType: sourceType,
                width: width,
                height: height,
              );
            },
        // Also detect when remote audio is first decoded (do not emit userJoined - join is from onUserJoined only)
        onFirstRemoteAudioDecoded:
            (RtcConnection connection, int remoteUid, int elapsed) {
              LogService.success(
                '✅ Remote audio decoded: UID=$remoteUid (elapsed: ${elapsed}ms)',
              );
              LogService.info(
                'This indicates a remote user is in the channel and publishing audio',
              );
              if (!_isValidRemoteUid(remoteUid)) {
                LogService.debug(
                  'Ignoring onFirstRemoteAudioDecoded for non-remote uid=$remoteUid (self=$_currentUID)',
                );
              }
            },
        // Who is speaking (for talking indicator UI)
        onAudioVolumeIndication:
            (
              RtcConnection connection,
              List<AudioVolumeInfo> speakers,
              int speakerNumber,
              int totalVolume,
            ) {
              try {
                _talkStats.ingestVolumeSample(
                  at: DateTime.now(),
                  speakers: speakers,
                  volumeThreshold: _effectiveSpeakingVolumeThreshold,
                );
                final speaking = <int>{};
                if (!_isInChannel) {
                  var bestLobby = 0;
                  for (final s in speakers) {
                    bestLobby = math.max(bestLobby, s.volume ?? 0);
                  }
                  final normLobby = math.min(1.0, bestLobby / 255.0);
                  if (_preJoinMicLevelController.hasListener) {
                    _preJoinMicLevelController.add(normLobby);
                  }
                  if (bestLobby > _effectiveSpeakingVolumeThreshold) {
                    speaking.add(0);
                  }
                } else {
                  var localPeak = 0;
                  final selfUid = _currentUID;
                  for (final s in speakers) {
                    final vol = s.volume ?? 0;
                    final uid = s.uid ?? 0;
                    if (selfUid != null && (uid == selfUid || uid == 0)) {
                      if (vol > localPeak) localPeak = vol;
                    }
                  }
                  final rawNorm = (localPeak / 255.0).clamp(0.0, 1.0);
                  _smoothedInCallLocalMicLevel +=
                      _kInCallMicLevelSmooth *
                      (rawNorm - _smoothedInCallLocalMicLevel);
                  if (_inCallLocalMicLevelController.hasListener) {
                    _inCallLocalMicLevelController.add(
                      _smoothedInCallLocalMicLevel.clamp(0.0, 1.0),
                    );
                  }
                  for (final s in speakers) {
                    final vol = s.volume ?? 0;
                    if (vol <= _effectiveSpeakingVolumeThreshold) continue;
                    final uid = s.uid ?? 0;
                    final self = _currentUID;
                    // Web/native volume indication often reports the local user as uid 0;
                    // only matching [self] misses local speech and breaks the mic wave UI.
                    if (self != null && (uid == self || uid == 0)) {
                      speaking.add(self);
                    } else if (uid != 0 && _isValidRemoteUid(uid)) {
                      speaking.add(uid);
                    }
                  }
                }
                _speakingDebouncer.applyRaw(speaking, (debounced) {
                  if (_speakingController.hasListener) {
                    _speakingController.add(debounced);
                  }
                  unawaited(
                    _applyRemoteStreamPriority(speakingUids: debounced),
                  );
                });
                _considerMutedMicSpeechHint(speakers);
              } catch (e) {
                LogService.warning('onAudioVolumeIndication error: $e');
              }
            },
        // Detect remote video state changes
        onRemoteVideoStateChanged:
            (
              RtcConnection connection,
              int remoteUid,
              RemoteVideoState state,
              RemoteVideoStateReason reason,
              int elapsed,
            ) {
              LogService.info(
                'Remote video state changed: UID=$remoteUid, state=$state, reason=$reason',
              );
              if (!_isValidRemoteUid(remoteUid)) {
                LogService.debug(
                  'Ignoring onRemoteVideoStateChanged for non-remote uid=$remoteUid (self=$_currentUID)',
                );
                return;
              }
              if (state == RemoteVideoState.remoteVideoStateStarting ||
                  state == RemoteVideoState.remoteVideoStateDecoding) {
                // Video is starting/decoding - user is active and camera is ON
                LogService.info('✅ Remote video is active for UID=$remoteUid');
                LogService.info(
                  '💡 Video stream is automatically subscribed - video should display',
                );

                // Track video activity for health check
                _lastRemoteVideoActivity = DateTime.now();
                _lastActiveRemoteUid = remoteUid;

                // Reset recovery attempts on successful video activity
                _videoRecoveryAttempts.remove(remoteUid);
                _lastRecoveryAttempt.remove(remoteUid);

                // Reset screen-off detection when video becomes active
                _resetScreenOffDetection(remoteUid);
                _cancelRemoteVideoStoppedProvisional(remoteUid);

                _remoteVideoMutedController.add({
                  'uid': remoteUid,
                  'muted': false,
                });
                _remoteVideoFrameController.add({
                  'uid': remoteUid,
                  'ready': true,
                });
                final freezeStartedAt = _freezeStartedAt.remove(remoteUid);
                if (freezeStartedAt != null) {
                  _emitQoe('remote_freeze_end', <String, dynamic>{
                    'uid': remoteUid,
                    'freeze_duration_ms': DateTime.now()
                        .difference(freezeStartedAt)
                        .inMilliseconds,
                  });
                }
              } else if (state == RemoteVideoState.remoteVideoStateStopped) {
                LogService.info(
                  'Remote video stopped for UID=$remoteUid (reason: $reason)',
                );
                _remoteVideoMutedController.add({
                  'uid': remoteUid,
                  'muted': true,
                });

                if (reason ==
                    RemoteVideoStateReason.remoteVideoStateReasonRemoteMuted) {
                  LogService.info(
                    '📹 Remote camera OFF (remote muted): UID=$remoteUid',
                  );
                  _resetScreenOffDetection(remoteUid);
                  _remoteVideoFrameController.add({
                    'uid': remoteUid,
                    'ready': false,
                  });
                } else {
                  _freezeStartedAt.putIfAbsent(remoteUid, () => DateTime.now());
                  _emitQoe('remote_freeze_start', <String, dynamic>{
                    'uid': remoteUid,
                    'reason': reason.name,
                  });
                  // Provisional: avoid immediate ready=false on transient renegotiation (e.g. web)
                  _cancelRemoteVideoStoppedProvisional(remoteUid);
                  _remoteVideoStoppedProvisionalTimers[remoteUid] = Timer(
                    _remoteVideoStoppedProvisionalDelay,
                    () {
                      _remoteVideoStoppedProvisionalTimers.remove(remoteUid);
                      _remoteVideoFrameController.add({
                        'uid': remoteUid,
                        'ready': false,
                      });
                      LogService.info(
                        'Provisional stopped confirmed for UID=$remoteUid (no decode recovery)',
                      );
                    },
                  );

                  _remoteVideoStoppedTimestamps[remoteUid] = DateTime.now();
                  final audioActive = _remoteAudioActive[remoteUid] ?? false;
                  if (audioActive) {
                    LogService.info(
                      '📱 Remote video stopped but audio active - possible screen-off detected',
                    );
                    _startScreenOffDetection(remoteUid);
                  } else if (_screenShareOwnerUid == remoteUid &&
                      reason !=
                          RemoteVideoStateReason
                              .remoteVideoStateReasonRemoteMuted) {
                    LogService.debug(
                      '📺 Skipping video recovery — UID=$remoteUid is screen-share presenter '
                      '(camera track idle while screen is active, reason=$reason)',
                    );
                  } else {
                    LogService.warning(
                      '⚠️ Remote video stopped and audio inactive - attempting recovery',
                    );
                    _attemptVideoRecovery(remoteUid, connection);
                  }
                }
              }
            },
        // Detect remote audio state changes
        onRemoteAudioStateChanged:
            (
              RtcConnection connection,
              int remoteUid,
              RemoteAudioState state,
              RemoteAudioStateReason reason,
              int elapsed,
            ) {
              LogService.info(
                'Remote audio state changed: UID=$remoteUid, state=$state, reason=$reason',
              );
              if (!_isValidRemoteUid(remoteUid)) {
                LogService.debug(
                  'Ignoring onRemoteAudioStateChanged for non-remote uid=$remoteUid (self=$_currentUID)',
                );
                return;
              }
              if (state == RemoteAudioState.remoteAudioStateStarting ||
                  state == RemoteAudioState.remoteAudioStateDecoding) {
                LogService.info('Remote audio is active for UID=$remoteUid');
                _remoteAudioActive[remoteUid] = true;
                _remoteAudioMutedController.add({
                  'uid': remoteUid,
                  'muted': false,
                });

                // If video is stopped but audio is active, check for screen-off
                if (_remoteVideoStoppedTimestamps.containsKey(remoteUid)) {
                  final videoStoppedTime =
                      _remoteVideoStoppedTimestamps[remoteUid]!;
                  final timeSinceVideoStopped = DateTime.now().difference(
                    videoStoppedTime,
                  );
                  if (timeSinceVideoStopped < _screenOffDetectionDelay) {
                    // Video just stopped but audio is active - likely screen-off
                    LogService.info(
                      '📱 Audio active but video stopped - possible screen-off for UID=$remoteUid',
                    );
                    _startScreenOffDetection(remoteUid);
                  }
                }
              } else if (state == RemoteAudioState.remoteAudioStateStopped) {
                _remoteAudioActive[remoteUid] = false;
                if (reason ==
                    RemoteAudioStateReason.remoteAudioReasonRemoteMuted) {
                  LogService.info(
                    'Remote user mic is muted for UID=$remoteUid',
                  );
                  // Emit audio muted event
                  _remoteAudioMutedController.add({
                    'uid': remoteUid,
                    'muted': true,
                  });
                }
                // Reset screen-off detection if audio also stopped
                _resetScreenOffDetection(remoteUid);
              }
            },
        // Track local video publishing state (important for debugging)
        onLocalVideoStateChanged:
            (
              VideoSourceType sourceType,
              LocalVideoStreamState state,
              LocalVideoStreamReason reason,
            ) {
              LogService.info(
                '📹 Local video state changed: sourceType=$sourceType, state=$state, reason=$reason',
              );
              final isScreenSource =
                  sourceType == VideoSourceType.videoSourceScreen ||
                  sourceType == VideoSourceType.videoSourceScreenPrimary ||
                  sourceType.toString().toLowerCase().contains('screen');
              if (state ==
                  LocalVideoStreamState.localVideoStreamStateCapturing) {
                if (!isScreenSource) {
                  _markLocalCameraPublishingSignal();
                }
                LogService.success(
                  '✅ Local video is capturing (camera active)',
                );
                // Only force-unmute when user expects camera ON. Respect explicit camera mute.
                if (!isScreenSource &&
                    _engine != null &&
                    _isInChannel &&
                    _isVideoEnabled) {
                  _ensureVideoUnmuted(reason: 'capturing');
                }
              } else if (state ==
                  LocalVideoStreamState.localVideoStreamStateEncoding) {
                if (!isScreenSource) {
                  _markLocalCameraPublishingSignal();
                }
                LogService.success(
                  '✅ Local video is encoding (publishing to remote users)',
                );
                // Only force-unmute when user expects camera ON. Respect explicit camera mute.
                if (!isScreenSource &&
                    _engine != null &&
                    _isInChannel &&
                    _isVideoEnabled) {
                  _ensureVideoUnmuted(reason: 'encoding');
                }
              } else if (state ==
                  LocalVideoStreamState.localVideoStreamStateFailed) {
                LogService.info(
                  '📹 [VIDEO] Local video failed: sourceType=$sourceType, reason=$reason, isPublishingScreen=$_isPublishingScreen',
                );
                final isScreenSource =
                    sourceType == VideoSourceType.videoSourceScreen ||
                    sourceType == VideoSourceType.videoSourceScreenPrimary ||
                    sourceType.toString().toLowerCase().contains('screen');
                // Only treat this as screen-share cancel/deny when the failing stream is
                // actually the screen source. Camera "deviceInterrupt" is expected while
                // screen sharing is active and should not force-stop screen share.
                if (_isPublishingScreen && isScreenSource) {
                  LogService.info(
                    '📹 [SCREEN_SHARE] Cancel/deny – restoring camera (no error dialog)',
                  );
                  _isPublishingScreen = false;
                  _applyScreenShareSignal(
                    uid: _currentUID ?? 0,
                    sharing: false,
                    source: 'screen_cancel_restore',
                    forceStopOwner: true,
                  );
                  Future.microtask(() async {
                    if (_engine == null) return;
                    try {
                      await _engine!.stopScreenCapture();
                    } catch (_) {
                      /* ignore – capture may never have started */
                    }
                    try {
                      if (_isInChannel) {
                        await _engine!.updateChannelMediaOptions(
                          ChannelMediaOptions(
                            publishCameraTrack: _isVideoEnabled,
                            publishScreenTrack: false,
                            publishScreenCaptureVideo: false,
                            publishScreenCaptureAudio: false,
                            publishMicrophoneTrack: _isAudioEnabled,
                          ),
                        );
                      }
                      if (_isVideoEnabled) {
                        await _engine!.setupLocalVideo(
                          VideoCanvas(
                            uid: 0,
                            sourceType: VideoSourceType.videoSourceCamera,
                          ),
                        );
                        await _ensureVideoUnmuted(
                          reason: 'screen_share_cancel_restore_camera',
                          force: true,
                        );
                        LogService.info(
                          '📹 [SCREEN_SHARE] Camera restored after cancel',
                        );
                      }
                    } catch (e) {
                      LogService.warning(
                        'Restore camera after screen cancel: $e',
                      );
                    }
                  });
                  return;
                }
                if (_isPublishingScreen && !isScreenSource) {
                  LogService.info(
                    '📹 [SCREEN_SHARE] Ignoring camera failure while screen share is active (expected interrupt).',
                  );
                  return;
                }
                final reasonStr = reason.toString().toLowerCase();
                if (reasonStr.contains('permission') ||
                    reasonStr.contains('denied') ||
                    reasonStr.contains('notallowed')) {
                  LogService.error('❌ Camera permission denied or not granted');
                  _errorController.add(
                    kIsWeb
                        ? 'Camera permission denied. Please allow camera access in browser settings and refresh.'
                        : 'Camera permission denied. Please allow camera access for this app in your device Settings.',
                  );
                  _updateState(AgoraSessionState.error);
                } else {
                  if (!_isRecoveringCamera &&
                      _isVideoEnabled &&
                      !_isPublishingScreen) {
                    LogService.warning(
                      '⚠️ Camera failed (reason: $reason) - attempting recovery',
                    );
                    _recoverCamera();
                  }
                }
              } else if (state ==
                  LocalVideoStreamState.localVideoStreamStateStopped) {
                final isScreenSource =
                    sourceType == VideoSourceType.videoSourceScreen ||
                    sourceType == VideoSourceType.videoSourceScreenPrimary ||
                    sourceType.toString().toLowerCase().contains('screen');
                if (isScreenSource && _isPublishingScreen) {
                  // User stopped screen sharing (e.g. from browser "Stop sharing" button)
                  LogService.info(
                    '📹 [SCREEN_SHARE] Local screen stream stopped – restoring camera',
                  );
                  _isPublishingScreen = false;
                  _applyScreenShareSignal(
                    uid: _currentUID ?? 0,
                    sharing: false,
                    source: 'screen_stopped_restore',
                    forceStopOwner: true,
                  );
                  Future.microtask(() async {
                    if (_engine == null) return;
                    try {
                      if (_isInChannel) {
                        await _engine!.updateChannelMediaOptions(
                          ChannelMediaOptions(
                            publishCameraTrack: _isVideoEnabled,
                            publishScreenTrack: false,
                            publishScreenCaptureVideo: false,
                            publishScreenCaptureAudio: false,
                            publishMicrophoneTrack: _isAudioEnabled,
                          ),
                        );
                      }
                      if (_isVideoEnabled) {
                        await _engine!.setupLocalVideo(
                          VideoCanvas(
                            uid: 0,
                            sourceType: VideoSourceType.videoSourceCamera,
                          ),
                        );
                        await _ensureVideoUnmuted(
                          reason: 'screen_share_stopped_restore_camera',
                          force: true,
                        );
                        LogService.info(
                          '📹 [SCREEN_SHARE] Camera restored after screen stopped',
                        );
                      }
                      await _notifyRemoteUsersScreenSharing(false);
                    } catch (e) {
                      LogService.warning(
                        'Restore camera after screen stopped: $e',
                      );
                    }
                  });
                  return;
                }
                if (!isScreenSource) {
                  LogService.warning(
                    '⚠️ Local video stopped - not publishing to remote users',
                  );
                  if (_isVideoEnabled &&
                      !_isPublishingScreen &&
                      _engine != null &&
                      _isInChannel) {
                    Future.delayed(const Duration(milliseconds: 500), () async {
                      if (_engine != null &&
                          _isInChannel &&
                          _isVideoEnabled &&
                          !_isPublishingScreen) {
                        await _ensureVideoUnmuted(
                          reason: 'video_stopped_recovery',
                          force: true,
                          logOnSuccess: true,
                        );
                      }
                    });
                  }
                }
              } else {
                LogService.info(
                  '📹 Local video state: $state (reason: $reason)',
                );
              }
            },
        onConnectionStateChanged:
            (
              RtcConnection connection,
              ConnectionStateType state,
              ConnectionChangedReasonType reason,
            ) {
              LogService.info(
                '[VIDEO] Connection state: $state, reason: $reason',
              );
              LogService.info(
                '[VIDEO] Connection details: channelId=${connection.channelId}, localUid=${connection.localUid}',
              );
              _lastRtcConnectionState = state;
              _connectionStateController.add(state);

              // Update connection when we have valid channelId
              if (connection.channelId != null) {
                _currentConnection = connection;
              }

              // Handle banned by server - this is critical
              if (reason ==
                  ConnectionChangedReasonType.connectionChangedBannedByServer) {
                LogService.error(
                  '❌ Connection banned by server! This may indicate:',
                );
                LogService.error('   - Duplicate UID in channel');
                LogService.error('   - Invalid token');
                LogService.error('   - Network/firewall issues');
                LogService.error('   - Agora service restrictions');
                _errorController.add(
                  'Connection was rejected by server. Please try again.',
                );
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
                if (connection.channelId != null &&
                    _currentConnection == null) {
                  _currentConnection = connection;
                }
                // Only update if we're not already connected (onJoinChannelSuccess handles this)
                if (_state != AgoraSessionState.connected) {
                  _updateState(AgoraSessionState.connected);
                }
                if (_reconnectTelemetryActive) {
                  _emitQoe('reconnect_success', <String, dynamic>{
                    'attempt_count': _reconnectionAttempts,
                  });
                  _reconnectTelemetryActive = false;
                }
                LogService.info(
                  '[VIDEO] ✅ Connection established - waiting for remote user...',
                );
              } else if (state ==
                  ConnectionStateType.connectionStateDisconnected) {
                _joinInProgress = false;
                _isInChannel = false;
                _currentConnection = null; // Clear connection on disconnect
                _stopVideoHealthCheck();
                // Don't set disconnected if we were banned (error state already set)
                if (reason !=
                    ConnectionChangedReasonType
                        .connectionChangedBannedByServer) {
                  _updateState(AgoraSessionState.disconnected);
                  // Do NOT reconnect when user intentionally left - fixes audio continuing after leave
                  if (reason !=
                      ConnectionChangedReasonType
                          .connectionChangedLeaveChannel) {
                    if (_reconnectTelemetryActive) {
                      _emitQoe('reconnect_failed', <String, dynamic>{
                        'reason': reason.name,
                        'attempt_count': _reconnectionAttempts,
                      });
                      _reconnectTelemetryActive = false;
                    }
                    _attemptReconnection();
                  } else {
                    LogService.info(
                      '[VIDEO] User left channel - skipping reconnection',
                    );
                  }
                }
              } else if (state ==
                  ConnectionStateType.connectionStateReconnecting) {
                _updateState(AgoraSessionState.reconnecting);
                LogService.info('[VIDEO] 🔄 Reconnecting to channel...');
                _reconnectTelemetryActive = true;
                _emitQoe('reconnect_attempt', <String, dynamic>{
                  'reason': reason.name,
                  'attempt_count': _reconnectionAttempts + 1,
                });
                _handleReconnection(connection);
              } else if (state ==
                  ConnectionStateType.connectionStateConnecting) {
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
            LogService.error(
              '   1. Click the camera/mic icon in the browser address bar',
            );
            LogService.error('   2. Set camera and microphone to "Allow"');
            LogService.error('   3. Refresh the page and try again');
            _errorController.add(
              kIsWeb
                  ? 'Camera/microphone permission denied. Please allow access in browser settings (click camera icon in address bar) and refresh the page.'
                  : 'Camera/microphone permission denied. Please allow access for this app in your device Settings.',
            );
            _updateState(AgoraSessionState.error);
            return;
          }

          if (err != ErrorCodeType.errJoinChannelRejected) {
            _errorController.add('Error $err: $msg');
          }

          // Don't set error state for join channel rejected if we're still trying
          // The connection state handler will manage state transitions
          if (err == ErrorCodeType.errJoinChannelRejected) {
            LogService.error('❌ Join channel rejected: $msg');
            _joinInProgress = false;
            String errorMsg = 'Session is resyncing. Reconnecting...';

            // Provide specific error messages
            if (msg.contains('appid') ||
                msg.contains('Invalid appid') ||
                msg.contains('appId')) {
              errorMsg =
                  'Invalid Agora App ID. Please check server configuration.';
            } else if (msg.contains('token') || msg.contains('Token')) {
              errorMsg = 'Invalid or expired token. Please try again.';
            } else if (msg.contains('channel') || msg.contains('Channel')) {
              errorMsg =
                  'Invalid channel name. Please check session configuration.';
            } else if (msg.contains('uid') || msg.contains('UID')) {
              errorMsg = 'Invalid user ID. Please try again.';
            }

            _errorController.add(errorMsg);
            _updateState(AgoraSessionState.reconnecting);
            _attemptReconnection();
          } else {
            _joinInProgress = false;
            _updateState(AgoraSessionState.error);
          }
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          LogService.info(
            '[CALL] Token privilege will expire soon — refreshing',
          );
          unawaited(_renewRtcToken(trigger: 'privilege_will_expire'));
        },
        onRequestToken: (RtcConnection connection) {
          LogService.warning(
            '[CALL] onRequestToken — privilege expired or invalid; renewing',
          );
          unawaited(_renewRtcToken(trigger: 'request_token'));
        },
        // Network quality monitoring for adaptive bitrate
        onNetworkQuality:
            (
              RtcConnection connection,
              int remoteUid,
              QualityType txQuality,
              QualityType rxQuality,
            ) {
              // Adjust video quality based on network conditions
              // QualityType: excellent(0), good(1), poor(2), bad(3), veryBad(4), down(5), unsupported(6)
              if (remoteUid == 0) {
                _lastObservedTxQuality = txQuality;
                final combinedLocal = worstLocalNetworkQuality(
                  txQuality,
                  rxQuality,
                );
                _adaptVideoQuality(combinedLocal);

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
        onStreamMessage:
            (
              RtcConnection connection,
              int remoteUid,
              int streamId,
              Uint8List data,
              int length,
              int sentTs,
            ) {
              try {
                // CRITICAL: Use UTF-8 decoding to properly handle emoji characters
                // String.fromCharCodes only works for ASCII - emojis need UTF-8 decoding
                final message = utf8.decode(data, allowMalformed: true);
                LogService.debug(
                  '📨 Received data stream: UID=$remoteUid: "$message"',
                );

                if (message == 'screen_share_start') {
                  LogService.success(
                    '✅ Remote user started screen sharing: UID=$remoteUid',
                  );

                  // Note: Agora SDK automatically handles video subscription for screen sharing
                  // The VideoViewController.remote in AgoraVideoViewWidget will handle
                  // the source type configuration when the widget rebuilds with sourceType=videoSourceScreen
                  // The UI will rebuild when _screenSharingController emits the event
                  // No need to explicitly call muteRemoteVideoStream - SDK handles subscription automatically
                  LogService.info(
                    '💡 UI will rebuild to show screen sharing stream',
                  );

                  _applyScreenShareSignal(
                    uid: remoteUid,
                    sharing: true,
                    source: 'agora_stream_message',
                  );
                } else if (message == 'screen_share_stop') {
                  LogService.info(
                    '📺 Remote user stopped screen sharing: UID=$remoteUid',
                  );

                  // Note: The VideoViewController.remote in AgoraVideoViewWidget will handle
                  // switching back to camera source when the widget rebuilds with sourceType=videoSourceCamera
                  // The UI will rebuild when _screenSharingController emits the event
                  LogService.info('💡 UI will rebuild to show camera stream');

                  _applyScreenShareSignal(
                    uid: remoteUid,
                    sharing: false,
                    source: 'agora_stream_message',
                  );
                } else if (message == 'camera_on') {
                  LogService.info(
                    '📹 Remote user turned camera ON: UID=$remoteUid',
                  );
                  _remoteVideoMutedController.add({
                    'uid': remoteUid,
                    'muted': false,
                  });
                  _remoteVideoFrameController.add({
                    'uid': remoteUid,
                    'ready': true,
                  });
                } else if (message == 'camera_off') {
                  LogService.info(
                    '📹 Remote user turned camera OFF: UID=$remoteUid',
                  );
                  _remoteVideoMutedController.add({
                    'uid': remoteUid,
                    'muted': true,
                  });
                  _remoteVideoFrameController.add({
                    'uid': remoteUid,
                    'ready': false,
                  });
                } else if (message.startsWith('reaction:')) {
                  final emoji = message.substring(
                    9,
                  ); // Extract emoji after "reaction:"
                  LogService.info(
                    '🎭 [EMOJI] Received reaction: remoteUid=$remoteUid, emoji="$emoji", streamId=$streamId – pushing to UI',
                  );
                  LogService.success(
                    '🎉 Received reaction from UID=$remoteUid: emoji="$emoji"',
                  );

                  // Verify emoji is not empty
                  if (emoji.isNotEmpty) {
                    _reactionController.add({'uid': remoteUid, 'emoji': emoji});
                    LogService.info(
                      '✅ Reaction added to stream: UID=$remoteUid, emoji="$emoji"',
                    );
                  } else {
                    LogService.warning(
                      '⚠️ Received reaction with empty emoji from UID=$remoteUid',
                    );
                  }
                } else {
                  LogService.debug(
                    'Unknown data stream message format: "$message"',
                  );
                }
              } catch (e) {
                LogService.error('❌ Error parsing data stream message: $e');
                LogService.debug(
                  'Data stream details: remoteUid=$remoteUid, streamId=$streamId, length=$length, data=${data.length} bytes',
                );
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
    if (_screenShareOwnerUid == remoteUid) {
      _applyScreenShareSignal(
        uid: remoteUid,
        sharing: false,
        source: 'confirm_user_left',
        forceStopOwner: true,
      );
    }
    _remoteParticipantUids.remove(remoteUid);
    if (_spotlightRemoteUid == remoteUid) {
      _spotlightRemoteUid = _remoteParticipantUids.isNotEmpty
          ? _remoteParticipantUids.first
          : null;
    }
    unawaited(_applyRemoteStreamPriority());
    LogService.info(
      'CONFIRMED user left remoteUid=$remoteUid (will emit userLeftStream)',
    );
    debugPrint('CONFIRMED user left remoteUid=$remoteUid');

    // Cancel grace period timer
    _userLeftGracePeriodTimers[remoteUid]?.cancel();
    _userLeftGracePeriodTimers.remove(remoteUid);

    // Emit user left event - this will trigger UI to show "user left" message
    _userLeftController.add(remoteUid);
  }

  void _cancelRemoteVideoStoppedProvisional(int remoteUid) {
    _remoteVideoStoppedProvisionalTimers[remoteUid]?.cancel();
    _remoteVideoStoppedProvisionalTimers.remove(remoteUid);
  }

  /// Reset offline tracking when user rejoins or becomes active
  void _resetUserOfflineTracking(int remoteUid) {
    _userLeftGracePeriodTimers[remoteUid]?.cancel();
    _userLeftGracePeriodTimers.remove(remoteUid);
    _cancelRemoteVideoStoppedProvisional(remoteUid);

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

    LogService.info(
      '✅ Reset offline tracking for user $remoteUid - user is active',
    );
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
        final timeSinceVideoStopped = DateTime.now().difference(
          videoStoppedTime,
        );
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
    _cancelRemoteVideoStoppedProvisional(remoteUid);
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

  void _emitQoe(String eventName, Map<String, dynamic> payload) {
    final sessionId = _lastSessionId;
    final correlationId = _qoeCorrelationId;
    if (sessionId == null || correlationId == null) return;
    unawaited(
      QoeTelemetryService.emit(
        sessionId: sessionId,
        correlationId: correlationId,
        eventName: eventName,
        payload: payload,
      ),
    );
  }

  Future<void> _applyTutoringAudioProfile() async {
    final mode = AppConfig.classroomAudioProfileMode;
    final selected = _resolveAudioProfilePreset(mode: mode);
    try {
      await _engine!
          .setAudioProfile(
            profile: selected.profile,
            scenario: selected.scenario,
          )
          .timeout(const Duration(seconds: 3));
      LogService.success(
        '✅ Audio profile configured: ${selected.label} '
        '(mode=$mode, profile=${selected.profile.name}, scenario=${selected.scenario.name})',
      );
      _emitQoe('audio_profile_selected', <String, dynamic>{
        'mode': mode,
        'variant': selected.variant,
        'profile': selected.profile.name,
        'scenario': selected.scenario.name,
        if (_lastSessionId != null) 'session_id': _lastSessionId,
      });
    } catch (e) {
      LogService.warning(
        'Could not set tutoring audio profile (mode=$mode, '
        'profile=${selected.profile.name}, scenario=${selected.scenario.name}): $e',
      );
    }
  }

  _AudioProfilePreset _resolveAudioProfilePreset({required String mode}) {
    switch (mode) {
      case 'music':
        return const _AudioProfilePreset(
          label: 'music clarity / instrument-friendly',
          variant: 'music',
          profile: AudioProfileType.audioProfileMusicStandard,
          scenario: AudioScenarioType.audioScenarioGameStreaming,
        );
      case 'balanced':
        return const _AudioProfilePreset(
          label: 'balanced voice fidelity',
          variant: 'balanced',
          profile: AudioProfileType.audioProfileSpeechStandard,
          scenario: AudioScenarioType.audioScenarioMeeting,
        );
      case 'ab':
        final bucket = _stableSessionBucket(
          _lastSessionId ?? _currentChannelName,
        );
        if (bucket == 0) {
          return const _AudioProfilePreset(
            label: 'A/B A speech focus',
            variant: 'a_speech',
            profile: AudioProfileType.audioProfileSpeechStandard,
            scenario: AudioScenarioType.audioScenarioChatroom,
          );
        }
        return const _AudioProfilePreset(
          label: 'A/B B balanced voice fidelity',
          variant: 'b_balanced',
          profile: AudioProfileType.audioProfileSpeechStandard,
          scenario: AudioScenarioType.audioScenarioMeeting,
        );
      case 'speech':
      default:
        return const _AudioProfilePreset(
          label: 'speech clarity / tutoring default',
          variant: 'speech',
          profile: AudioProfileType.audioProfileSpeechStandard,
          scenario: AudioScenarioType.audioScenarioChatroom,
        );
    }
  }

  int _stableSessionBucket(String? seed) {
    if (seed == null || seed.isEmpty) return 0;
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return hash % 2;
  }

  void _emitTalkTimeSummary() {
    final snapshot = _talkStats.snapshot();
    if (snapshot.totalMs < 1000) return; // Ignore near-empty sessions.
    final role = _lastUserRole ?? 'unknown';
    _emitQoe('talk_time_summary', <String, dynamic>{
      ...snapshot.toJson(),
      'local_user_role': role,
      'session_type': _lastSessionId == null ? 'unknown' : 'live',
    });
  }
}

class _AudioProfilePreset {
  const _AudioProfilePreset({
    required this.label,
    required this.variant,
    required this.profile,
    required this.scenario,
  });

  final String label;
  final String variant;
  final AudioProfileType profile;
  final AudioScenarioType scenario;
}
