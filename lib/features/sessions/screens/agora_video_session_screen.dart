import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/camera_mic_permission_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/utils/status_bar_utils.dart';
import 'package:prepskul/features/sessions/services/agora_service.dart';
import 'package:prepskul/features/sessions/services/session_profile_service.dart';
import 'package:prepskul/features/sessions/services/connection_quality_service.dart';
import 'package:prepskul/features/sessions/models/agora_session_state.dart';
import 'package:prepskul/features/sessions/widgets/agora_video_view.dart' as agora_widget;
import 'package:prepskul/features/sessions/widgets/profile_card_overlay.dart';
import 'package:prepskul/features/sessions/widgets/session_state_message.dart';
import 'package:prepskul/features/sessions/widgets/local_video_pip.dart';
import 'package:prepskul/features/sessions/widgets/call_status_banner.dart';
import 'package:prepskul/features/sessions/widgets/reactions_panel.dart';
import 'package:prepskul/features/sessions/widgets/reaction_animation.dart';
import 'package:prepskul/features/sessions/widgets/prepskul_va_avatar.dart';
import 'package:prepskul/features/booking/services/session_lifecycle_service.dart';
import 'package:prepskul/features/sessions/services/agora_recording_service.dart';
import 'package:prepskul/features/sessions/services/session_timer_service.dart';
import 'package:prepskul/features/sessions/services/call_pip_controller.dart';
import 'package:prepskul/features/sessions/services/session_heartbeat_service.dart';
import 'package:prepskul/features/sessions/domain/participant_state.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora_rtc_engine;
import 'package:prepskul/core/utils/platform_utils_stub.dart'
    if (dart.library.html) 'package:prepskul/core/utils/platform_utils_web.dart' as platform_utils;
import 'dart:async';
import 'dart:ui' as ui;

/// Deep blue for video/connecting/leaving/waiting – consistent with app theme.
const Color _kSoftDark = Color(0xFF0F1A2E); // AppTheme.primaryDark
const Color _kGlassFill = Color(0x33141F36);
const Color _kGlassBorder = Color(0x66FFFFFF);

/// Layout mode for video call: spotlight (main + PIP) or side-by-side (two panels).
enum VideoLayout { spotlight, sideBySide }

/// Agora Video Session Screen
///
/// Full-screen video session interface with controls for mute, camera, and end call.
class AgoraVideoSessionScreen extends StatefulWidget {
  final String sessionId;
  final String userRole; // 'tutor' or 'learner'
  final bool initialCameraEnabled; // Initial camera state from pre-join
  final bool initialMicEnabled; // Initial mic state from pre-join

  const AgoraVideoSessionScreen({
    Key? key,
    required this.sessionId,
    required this.userRole,
    this.initialCameraEnabled = false, // Default to OFF
    this.initialMicEnabled = false, // Default to OFF
  }) : super(key: key);

  @override
  State<AgoraVideoSessionScreen> createState() => _AgoraVideoSessionScreenState();
}

class _AgoraVideoSessionScreenState extends State<AgoraVideoSessionScreen>
    with WidgetsBindingObserver {
  final AgoraService _agoraService = AgoraService();
  final _supabase = SupabaseService.client;
  final SessionProfileService _profileService = SessionProfileService();

  AgoraSessionState _sessionState = AgoraSessionState.disconnected;
  bool _isVideoEnabled = false; // Will be set from initial state
  bool _isAudioEnabled = false; // Will be set from initial state
  int? _remoteUID;
  final Map<int, ParticipantState> _participants = <int, ParticipantState>{};
  String? _errorMessage;
  
  // Remote state tracking
  bool _remoteVideoMuted = false;
  bool _remoteAudioMuted = false;
  bool _remoteVideoReady = false;
  bool? _lastRemoteVideoMutedState;
  bool? _lastRemoteAudioMutedState;
  DateTime? _remoteJoinedAt;
  String? _transientStateMessage;
  Timer? _transientStateMessageTimer;
  DateTime? _transientStateMessageShownAt;
  Timer? _queuedTransientMessageTimer;
  static const Duration _minTransientMessageDisplay = Duration(seconds: 2);
  bool _isScreenSharing = false;
  bool _remoteIsScreenSharing = false;
  int? _screenShareOwnerUid;
  bool _remoteUserLeft = false;
  /// Cached remote UID for mobile web main-area lock when we force remote view (never clear on mobile web when ignoring "user left").
  int? _lastRemoteUID;

  // Profile data
  Map<String, dynamic>? _localProfile;
  Map<String, dynamic>? _remoteProfile;
  
  // Reactions
  bool _showReactionsPanel = false;
  final List<Widget> _reactionAnimations = [];

  // Layout: spotlight (one main + PIP) vs side-by-side (two panels)
  VideoLayout _layout = VideoLayout.spotlight;

  // PrepSkul VA (Virtual Assistant) - UI-only monitoring indicator
  bool _showVaAvatar = false;
  bool _vaJoinNotificationShown = false;
  /// Mobile web: show VA joined banner in overlay (above controls) so it's visible
  bool _vaBannerVisible = false;
  Timer? _vaBannerHideTimer;
  
  // Stream subscriptions
  StreamSubscription<AgoraSessionState>? _stateSubscription;
  StreamSubscription<int>? _userJoinedSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<Map<String, dynamic>>? _remoteVideoMutedSubscription;
  StreamSubscription<Map<String, dynamic>>? _remoteVideoFrameSubscription;
  StreamSubscription<Map<String, dynamic>>? _remoteAudioMutedSubscription;
  StreamSubscription<Map<String, dynamic>>? _screenSharingSubscription;
  StreamSubscription<int>? _userLeftSubscription;
  StreamSubscription<Map<String, dynamic>>? _remoteNetworkQualitySubscription;
  StreamSubscription<Map<String, dynamic>>? _reactionSubscription;
  StreamSubscription<Map<String, dynamic>>? _remoteScreenOffSubscription;
  StreamSubscription<Set<int>>? _speakingSubscription;
  StreamSubscription<agora_rtc_engine.ConnectionStateType>? _connectionStateSubscription;
  StreamSubscription<String>? _recordingFailedSubscription;
  
  /// UIDs currently speaking (from Agora volume indication) for talking indicator.
  Set<int> _speakingUids = {};
  
  // Network instability tracking
  bool _remoteConnectionUnstable = false;
  bool _localConnectionReconnecting = false;
  DateTime? _localReconnectingShownAt;
  Timer? _localReconnectClearTimer;
  static const Duration _minReconnectIndicatorDisplay = Duration(seconds: 2);
  /// When non-null, show "Connection restored" in status bar until this time + a few seconds.
  DateTime? _connectionRestoredAt;
  static const Duration _connectionRestoredDisplayDuration = Duration(seconds: 4);
  
  // Screen-off tracking
  bool _remoteScreenOff = false;
  DateTime? _remoteUnstableStickyUntil;
  Timer? _remoteUnstableTimer;
  
  // Session timer
  final SessionTimerService _timerService = SessionTimerService();
  Duration? _timeRemaining;
  StreamSubscription<Duration>? _timeRemainingSubscription;
  StreamSubscription<String>? _sessionEndedSubscription;
  bool _timerStarted = false; // Ensure timer starts only once (when both users are in)
  bool _isEndingCall = false;
  /// When true, body is plain black so nothing (no profile, no "Waiting for tutor...") shows behind the "Leaving..." dialog.
  bool _showLeavingScreen = false;

  /// True when control buttons (mic, camera, etc.) should respond. Use this so controls don't get
  /// stuck inactive on web after first camera toggle or if session state is slow to update.
  bool get _controlsEnabled =>
      _sessionState != AgoraSessionState.joining &&
      _sessionState != AgoraSessionState.error &&
      (!kIsWeb || _agoraService.engine != null);
  
  // Local video ready flag - ensures video is set up before rendering
  bool _localVideoReady = false;
  
  // Debounce timer for video state changes (prevents flickering)
  Timer? _videoStateDebounceTimer;
  /// When frame-ready (ready=true) last received; used to ignore stale debounced muted callbacks.
  DateTime? _lastRemoteVideoReadyAt;

  // Watchdog timer to re-ensure local preview is running shortly after join.
  // This helps fix cases where the bottom-right self-view stays blank on first join
  // until the user toggles the camera.
  Timer? _localPreviewWatchdogTimer;
  DateTime? _lastLocalPreviewEnsureAt;
  bool _localPreviewEnsureInProgress = false;

  /// On mobile web, status/control bar is rendered via Overlay so it stays above Agora platform view after mute.
  OverlayEntry? _mobileWebOverlayEntry;

  /// Mobile web: last time we received any activity from remote (video/audio/join); used to detect "user left" when they close tab.
  DateTime? _lastRemoteActivityAt;
  Timer? _remoteLeftCheckTimer;
  static const Duration _remoteLeftInactivityThreshold = Duration(seconds: 60);
  static const Duration _remoteLeftCheckInterval = Duration(seconds: 15);

  // UI state scheduler: coalesce multiple Agora callbacks into a single
  // frame update so the main area does not "shake" when several events
  // (video state, audio state, quality, etc.) arrive at once.
  Timer? _uiUpdateDebounceTimer;
  final List<VoidCallback> _pendingUiMutations = [];

  void _scheduleUiUpdate(VoidCallback mutation) {
    _pendingUiMutations.add(mutation);
    _uiUpdateDebounceTimer ??= Timer(const Duration(milliseconds: 180), () {
      _uiUpdateDebounceTimer = null;
      if (!mounted) {
        _pendingUiMutations.clear();
        return;
      }
      // Apply all queued mutations in a single setState so the widget tree
      // only rebuilds once for a burst of Agora events.
      safeSetState(() {
        for (final m in _pendingUiMutations) {
          m();
        }
        _pendingUiMutations.clear();
      });
    });
  }

  ParticipantState? get _currentRemoteParticipant {
    final uid = _remoteUID;
    if (uid == null) return null;
    return _participants[uid];
  }

  void _upsertParticipant(
    int uid, {
    bool? videoMuted,
    bool? audioMuted,
    bool? videoReady,
    bool? screenSharing,
    bool? userLeft,
    bool? connectionUnstable,
    bool? screenOff,
    DateTime? lastActivityAt,
  }) {
    final existing = _participants[uid] ?? ParticipantState(uid: uid);
    _participants[uid] = existing.copyWith(
      videoMuted: videoMuted,
      audioMuted: audioMuted,
      videoReady: videoReady,
      screenSharing: screenSharing,
      userLeft: userLeft,
      connectionUnstable: connectionUnstable,
      screenOff: screenOff,
      lastActivityAt: lastActivityAt,
    );
  }

  void _removeParticipant(int uid) {
    _participants.remove(uid);
  }

  void _syncLegacyRemoteStateFromRegistry() {
    final p = _currentRemoteParticipant;
    if (p == null) {
      _remoteVideoMuted = false;
      _remoteAudioMuted = false;
      _remoteVideoReady = false;
      _remoteIsScreenSharing = false;
      _remoteUserLeft = false;
      _remoteConnectionUnstable = false;
      _remoteScreenOff = false;
      return;
    }
    _remoteVideoMuted = p.videoMuted;
    _remoteAudioMuted = p.audioMuted;
    _remoteVideoReady = p.videoReady;
    _remoteIsScreenSharing = p.screenSharing;
    _remoteUserLeft = p.userLeft;
    _remoteConnectionUnstable = p.connectionUnstable;
    _remoteScreenOff = p.screenOff;
    _lastRemoteActivityAt = p.lastActivityAt ?? _lastRemoteActivityAt;
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleMobileWebOverlayRefresh();
  }

  void _scheduleMobileWebOverlayRefresh() {
    if (_mobileWebOverlayEntry != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mobileWebOverlayEntry?.markNeedsBuild();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CallPipController().attachToLifecycle();
    _initializeSession();
    _setupListeners();
    _setupTimer();
    // Mobile web: status/control bar are rendered in the main Stack (not OverlayEntry) so they stay visible.
    // WidgetsBinding.instance.addPostFrameCallback((_) => _insertMobileWebOverlayIfNeeded());
  }

  @override
  void dispose() {
    // Safety net: if route was popped without going through _endCall (e.g. error nav), try to leave and release
    Future.microtask(() async {
      try {
        await _agoraService.leaveChannel();
        await _agoraService.releaseEngineAfterLeave();
      } catch (e) {
        LogService.warning('Dispose safety net leave/release: $e');
      }
    });
    
    _stateSubscription?.cancel();
    _userJoinedSubscription?.cancel();
    _errorSubscription?.cancel();
    _remoteVideoMutedSubscription?.cancel();
    _remoteVideoFrameSubscription?.cancel();
    _remoteAudioMutedSubscription?.cancel();
    _screenSharingSubscription?.cancel();
    _userLeftSubscription?.cancel();
    _remoteNetworkQualitySubscription?.cancel();
    _reactionSubscription?.cancel();
    _remoteScreenOffSubscription?.cancel();
    _speakingSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _recordingFailedSubscription?.cancel();
    _timeRemainingSubscription?.cancel();
    _sessionEndedSubscription?.cancel();
    
    // Cancel debounce timer
    _videoStateDebounceTimer?.cancel();
    _localPreviewWatchdogTimer?.cancel();
    _uiUpdateDebounceTimer?.cancel();
    _remoteUnstableTimer?.cancel();
    _transientStateMessageTimer?.cancel();
    _queuedTransientMessageTimer?.cancel();
    _localReconnectClearTimer?.cancel();

    _remoteLeftCheckTimer?.cancel();
    _remoteLeftCheckTimer = null;
    _removeMobileWebOverlay();

    // Stop timer
    _timerService.stopSession();
    WidgetsBinding.instance.removeObserver(this);
    SessionHeartbeatService().stop();
    CallPipController().detachFromLifecycle();
    // Don't dispose AgoraService here - it's a singleton
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When the user backgrounds the app while the call is active, rely on the
    // CallPipController to request OS-level PiP so the call keeps running.
    if (state == AppLifecycleState.paused && _sessionState.isActive) {
      CallPipController().enterPipMode();
    }
  }

  void _insertMobileWebOverlayIfNeeded() {
    if (!mounted || !kIsWeb || !platform_utils.PlatformUtils.isMobileWeb) return;
    if (_mobileWebOverlayEntry != null) return;
    _mobileWebOverlayEntry = OverlayEntry(
      builder: (context) => SizedBox.expand(
        child: RepaintBoundary(
          child: Material(
            type: MaterialType.transparency,
            elevation: 32,
            child: IgnorePointer(
              ignoring: false,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildStatusBar(),
                  _buildControlBar(),
                  // When joining, show "Connecting..." in overlay so user never sees blank screen
                  if (_sessionState == AgoraSessionState.joining)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 120),
                        child: Text(
                          'Connecting...',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  // VA joined banner - above controls so clearly visible on mobile web
                  if (_vaBannerVisible)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 56,
                      left: 16,
                      right: 16,
                      child: Center(
                        child: Material(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                          elevation: 8,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Text(
                              "PrepSkul VA has joined the session.",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_mobileWebOverlayEntry!);
    LogService.info('[MOBILE_WEB] In-call overlay inserted into Overlay layer (state=$_sessionState)');
    debugPrint('[MOBILE_WEB] Overlay inserted state=$_sessionState');
  }

  void _removeMobileWebOverlay() {
    _vaBannerHideTimer?.cancel();
    _vaBannerHideTimer = null;
    _mobileWebOverlayEntry?.remove();
    _mobileWebOverlayEntry = null;
  }

  /// On mobile web, we ignore onUserOffline (to avoid spurious "left" when local mutes).
  /// Use a timeout: if no remote activity for [_remoteLeftInactivityThreshold], treat as left.
  void _startRemoteLeftCheckTimerIfNeeded() {
    if (!kIsWeb || !platform_utils.PlatformUtils.isMobileWeb) return;
    _remoteLeftCheckTimer?.cancel();
    _remoteLeftCheckTimer = Timer.periodic(_remoteLeftCheckInterval, (_) {
      if (!mounted || _remoteUID == null || _lastRemoteActivityAt == null) return;
      if (_sessionState != AgoraSessionState.connected) return;
      final elapsed = DateTime.now().difference(_lastRemoteActivityAt!);
      if (elapsed >= _remoteLeftInactivityThreshold) {
        _remoteLeftCheckTimer?.cancel();
        _remoteLeftCheckTimer = null;
        final leftUid = _remoteUID;
        safeSetState(() {
          _remoteUserLeft = true;
          _remoteUID = null;
          _remoteConnectionUnstable = false;
          _layout = VideoLayout.spotlight;
        });
        LogService.info('Mobile web: remote marked left after ${elapsed.inSeconds}s inactivity (uid=$leftUid)');
        // Keep UX minimal: top status banner already communicates this state.
      }
    });
  }

  /// Initialize Agora session
  Future<void> _initializeSession() async {
    try {
      LogService.info('[SESSION] 🎥 Initializing - Session ID: ${widget.sessionId}, User Role: ${widget.userRole}');
      
      safeSetState(() {
        _sessionState = AgoraSessionState.joining;
        _errorMessage = null;
      });

      // Get current user ID
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Load profile data
      _loadProfileData(user.id);

      // Start heartbeat so the peer can detect if we disappear unexpectedly
      // (refresh, force close, crash). Best-effort only; failures are logged.
      try {
        await SessionHeartbeatService().start(
          sessionId: widget.sessionId,
          userId: user.id,
        );
        // On web, hook into page unload so we can send a \"left\" signal before
        // the tab closes or refreshes.
        if (kIsWeb) {
          platform_utils.PlatformUtils.registerCallUnloadHandler(() {
            SessionHeartbeatService().sendLeftSignal();
          });
        }
        // Listen for peer \"left\" signals and immediately reflect that in UI.
        SessionHeartbeatService().peerLeftStream.listen((peerId) {
          if (!mounted) return;
          _scheduleUiUpdate(() {
            _remoteUserLeft = true;
            _remoteConnectionUnstable = false;
          });
        });
      } catch (e) {
        LogService.warning('[HEARTBEAT] Failed to start heartbeat: $e');
      }

      // Set initial camera/mic state from pre-join screen
      _isVideoEnabled = widget.initialCameraEnabled;
      _isAudioEnabled = widget.initialMicEnabled;

      // Join channel with initial camera/mic state
      await _agoraService.joinChannel(
        sessionId: widget.sessionId,
        userId: user.id,
        userRole: widget.userRole,
        initialCameraEnabled: widget.initialCameraEnabled,
        initialMicEnabled: widget.initialMicEnabled,
      );

      // Update state to reflect actual camera/mic state
      safeSetState(() {
        _isVideoEnabled = _agoraService.isVideoEnabled();
        _isAudioEnabled = _agoraService.isAudioEnabled();
      });
      
      // CRITICAL: Explicitly set up local video IMMEDIATELY after joining
      // This ensures the user sees their own video right away (not just after toggle)
      if (widget.initialCameraEnabled) {
        try {
          LogService.info('[SESSION] Setting up local video immediately after join...');

          await _agoraService.setupLocalVideoAfterJoin();

          // Small delay to allow video to initialize
          await Future.delayed(const Duration(milliseconds: 300));

          // Ensure video stream is unmuted (publishing)
          await _agoraService.ensureLocalVideoPublishing();

          LogService.info('[SESSION] Local video set up successfully - should be visible now');
          
          safeSetState(() {
            _localVideoReady = true;
          });

          // Small watchdog: if some platforms still fail to render the first
          // preview frame, try to restart preview once more a few seconds later.
          _scheduleLocalPreviewWatchdog();
        } catch (e) {
          LogService.warning('[SESSION] Error setting up local video: $e');
          // Still mark as ready to allow UI to render
          safeSetState(() {
            _localVideoReady = true;
          });
          _scheduleLocalPreviewWatchdog();
        }
      } else {
        // Camera not enabled, mark as ready anyway
        safeSetState(() {
          _localVideoReady = true;
        });
      }

      // If tutor, start the session in the lifecycle service
      if (widget.userRole == 'tutor') {
        try {
          await SessionLifecycleService.startSession(
            widget.sessionId,
            isOnline: true,
            skipCloudRecording: kIsWeb && platform_utils.PlatformUtils.isMobileWeb,
          );
        } catch (e) {
          LogService.warning('Failed to start session in lifecycle: $e');
        }
      }
    } catch (e) {
      LogService.error('[SESSION] Error initializing: $e');
      
      // Format error message for user
      String userMessage = e.toString();
      
      // Remove "Exception: " prefix if present
      if (userMessage.startsWith('Exception: ')) {
        userMessage = userMessage.substring(11);
      }
      
      // Provide user-friendly error messages (no technical details)
      if (userMessage.contains('timeout') || userMessage.contains('unreachable') || userMessage.contains('slow to respond')) {
        userMessage = 'Poor network connection. Please check your internet and try again.';
      } else if (userMessage.contains('CORS') || userMessage.contains('cors') || userMessage.contains('Cross-Origin') ||
          userMessage.contains('API URL') || userMessage.contains('origin')) {
        userMessage = 'Poor network connection. Please check your internet and try again.';
      } else if (userMessage.contains('Unauthorized') || userMessage.contains('401')) {
        userMessage = 'Session expired. Please log in again.';
      } else if (userMessage.contains('Access denied') || userMessage.contains('403')) {
        userMessage = 'You do not have access to this session.';
      } else if (userMessage.contains('createIrisApiEngine') || 
          userMessage.contains('undefined') ||
          userMessage.contains('iris-web-rtc')) {
        userMessage = 'Unable to start video session. Please refresh the page and try again.';
      } else if (userMessage.contains('Failed to initialize')) {
        userMessage = 'Unable to start video session. Please check your internet connection and try again.';
      } else if (userMessage.contains('permission') || 
                 userMessage.contains('Permission') ||
                 userMessage.contains('NotAllowedError') ||
                 userMessage.contains('NotAllowed') ||
                 userMessage.contains('Permission denied')) {
        userMessage = 'Camera and Microphone Permission Required\n\n'
            'Your browser is blocking camera and microphone access.\n\n'
            'To fix this:\n'
            '1. Look at the address bar (top-left of your browser)\n'
            '2. Click the camera/microphone icon (🔒 or 🎥 or 🎤)\n'
            '3. Set both "Camera" and "Microphone" to "Allow"\n'
            '4. Refresh this page (press F5 or click refresh)\n'
            '5. Try joining the session again\n\n'
            'If you don\'t see the icon:\n'
            '• Chrome/Edge: Click the padlock icon → Site settings → Allow camera and microphone\n'
            '• Firefox: Click the padlock icon → More Information → Permissions → Allow\n\n'
            'After allowing permissions, refresh the page and try again.';
      } else if (userMessage.contains('localhost:3000') || userMessage.contains('API URL') || userMessage.contains('Check:')) {
        userMessage = 'Poor network connection. Please check your internet and try again.';
      } else if (userMessage.contains('Something went wrong on our end')) {
        userMessage = 'Something went wrong on our end. Please try again later.';
      } else if (userMessage.contains('Connection failed') || userMessage.contains('Unable to connect') ||
          userMessage.contains('Connection timed out') || userMessage.contains('Connection error')) {
        // Already user-friendly from token service
      } else if (userMessage.contains('Failed to') || userMessage.contains('Error') ||
          userMessage.contains('Exception') || userMessage.contains('http')) {
        userMessage = 'Connection failed. Please check your internet and try again.';
      }
      
      safeSetState(() {
        _sessionState = AgoraSessionState.error;
        _errorMessage = userMessage;
      });
    }
  }

  /// Load profile data for local and remote users
  Future<void> _loadProfileData(String localUserId) async {
    try {
      // Load local profile
      _localProfile = await _profileService.getUserProfile(localUserId);
      
      // Load session participants
      final participants = await _profileService.getSessionParticipants(widget.sessionId);
      if (widget.userRole == 'tutor') {
        _remoteProfile = participants['learner'];
      } else {
        _remoteProfile = participants['tutor'];
      }
      
      safeSetState(() {});
    } catch (e) {
      LogService.warning('Error loading profile data: $e');
    }
  }

  /// Setup Agora event listeners
  void _setupListeners() {
    _stateSubscription = _agoraService.stateStream.listen((state) {
      _scheduleUiUpdate(() {
        _sessionState = state;
      });
    });

    _userJoinedSubscription = _agoraService.userJoinedStream.listen((uid) {
      LogService.info('👤 Remote user joined: UID=$uid');
      _remoteUnstableTimer?.cancel();
      _videoStateDebounceTimer?.cancel();
      _scheduleUiUpdate(() {
        _remoteUID = uid;
        _lastRemoteUID = uid; // Keep for mobile web main-area lock when forcing remote view
        _remoteJoinedAt = DateTime.now();
        _lastRemoteActivityAt = DateTime.now(); // For mobile web "user left" timeout
        // Clear stale overlay flags so rejoin doesn't keep old screen-off/unstable state
        _remoteUnstableStickyUntil = null;
        _lastRemoteVideoReadyAt = null;
        _upsertParticipant(
          uid,
          userLeft: false,
          videoMuted: false,
          audioMuted: false,
          videoReady: false,
          screenSharing: false,
          connectionUnstable: false,
          screenOff: false,
          lastActivityAt: DateTime.now(),
        );
        _syncLegacyRemoteStateFromRegistry();
        _showVaAvatar = true; // PrepSkul VA "joins" when both participants are in the call
      });
      if (_isVideoEnabled && !_localVideoReady) {
        _ensureLocalPreviewActiveNow();
      }
      _startRemoteLeftCheckTimerIfNeeded();
      
      // Send our current camera state to the remote user via data channel
      // This ensures they know if we have our camera off already
      _sendCameraStateToRemote();

      // Start session timer the first time we detect a remote participant.
      // This ensures both tutor and learner are in the call before time starts counting.
      if (!_timerStarted) {
        LogService.info('⏱️ Remote participant joined – starting shared session timer');
        _timerStarted = true;
        _startSessionTimer();
      }

      // One-time on-screen banner: "PrepSkul VA has joined" at top for both mobile and desktop web
      if (!_vaJoinNotificationShown && mounted) {
        _vaJoinNotificationShown = true;
        if (kIsWeb) {
          safeSetState(() => _vaBannerVisible = true);
          _vaBannerHideTimer?.cancel();
          _vaBannerHideTimer = Timer(const Duration(seconds: 6), () {
            if (mounted) safeSetState(() => _vaBannerVisible = false);
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "PrepSkul VA has joined the session.",
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  duration: const Duration(seconds: 6),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                ),
              );
            }
          });
        }
      }
    });

    _errorSubscription = _agoraService.errorStream.listen((error) {
      final userMessage = _toUserFriendlyError(error);
      final lowered = userMessage.toLowerCase();
      final isRecoverableConnectionIssue =
          lowered.contains('connection') ||
          lowered.contains('network') ||
          lowered.contains('internet') ||
          lowered.contains('timeout');

      if (_sessionState == AgoraSessionState.connected && isRecoverableConnectionIssue) {
        _showTopStateMessage(userMessage);
        return;
      }

      safeSetState(() {
        _errorMessage = userMessage;
        _sessionState = AgoraSessionState.error;
      });
    });

    // Remote video muted state - DEBOUNCED to prevent flickering; frame-ready is authoritative.
    _remoteVideoMutedSubscription = _agoraService.remoteVideoMutedStream.listen((data) {
      final uid = data['uid'] as int;
      final muted = data['muted'] as bool;
      if (uid == _remoteUID) {
        final previous = _lastRemoteVideoMutedState;
        _lastRemoteVideoMutedState = muted;
        final debounceScheduledAt = DateTime.now();
        _scheduleUiUpdate(() {
          _upsertParticipant(uid, lastActivityAt: DateTime.now());
          _syncLegacyRemoteStateFromRegistry();
          _videoStateDebounceTimer?.cancel();
          _videoStateDebounceTimer =
              Timer(const Duration(milliseconds: 250), () {
            if (!mounted || uid != _remoteUID) return;
            _scheduleUiUpdate(() {
              _upsertParticipant(uid, videoMuted: muted);
              // Only set ready=false if no frame-ready arrived after we scheduled this debounce
              if (muted) {
                final lastReady = _lastRemoteVideoReadyAt;
                if (lastReady == null || lastReady.isBefore(debounceScheduledAt)) {
                  _upsertParticipant(uid, videoReady: false);
                }
              }
              _syncLegacyRemoteStateFromRegistry();
            });
          });
        });
        final joinedRecently = _remoteJoinedAt != null &&
            DateTime.now().difference(_remoteJoinedAt!) < const Duration(seconds: 6);
        if (previous == true &&
            muted == false &&
            !joinedRecently &&
            !_remoteUserLeft &&
            !_remoteConnectionUnstable &&
            _sessionState == AgoraSessionState.connected) {
          _showTopStateMessage(widget.userRole == 'tutor'
              ? 'Learner camera is back on'
              : 'Tutor camera is back on');
        }
      }
    });

    _remoteVideoFrameSubscription = _agoraService.remoteVideoFrameStream.listen((data) {
      final uid = data['uid'] as int;
      final ready = data['ready'] as bool? ?? false;
      if (uid == _remoteUID) {
        if (ready) {
          _videoStateDebounceTimer?.cancel();
          _lastRemoteVideoReadyAt = DateTime.now();
        }
        _scheduleUiUpdate(() {
          _upsertParticipant(
            uid,
            videoReady: ready,
            videoMuted: ready ? false : null,
            lastActivityAt: DateTime.now(),
          );
          if (ready) {
            _upsertParticipant(uid, videoMuted: false);
          }
          _syncLegacyRemoteStateFromRegistry();
        });
      }
    });

    // Remote audio muted state
    _remoteAudioMutedSubscription =
        _agoraService.remoteAudioMutedStream.listen((data) {
      final uid = data['uid'] as int;
      final muted = data['muted'] as bool;
      if (uid == _remoteUID) {
        final previous = _lastRemoteAudioMutedState;
        _lastRemoteAudioMutedState = muted;
        _scheduleUiUpdate(() {
          _upsertParticipant(uid, audioMuted: muted, lastActivityAt: DateTime.now());
          _syncLegacyRemoteStateFromRegistry();
        });
        final joinedRecently = _remoteJoinedAt != null &&
            DateTime.now().difference(_remoteJoinedAt!) < const Duration(seconds: 6);
        if (previous == true &&
            muted == false &&
            !joinedRecently &&
            !_remoteUserLeft &&
            !_remoteConnectionUnstable &&
            _sessionState == AgoraSessionState.connected) {
          _showTopStateMessage(widget.userRole == 'tutor'
              ? 'Learner microphone unmuted'
              : 'Tutor microphone unmuted');
        }
      }
    });

    // Screen sharing state
    _screenSharingSubscription =
        _agoraService.screenSharingStream.listen((data) {
      final uid = data['uid'] as int;
      final sharing = data['sharing'] as bool;
      final ownerUid = data['ownerUid'] as int?;
      if (uid == _remoteUID) {
        _scheduleUiUpdate(() {
          _upsertParticipant(uid, screenSharing: sharing);
          _screenShareOwnerUid = ownerUid;
          if (_screenShareOwnerUid != null) {
            _remoteIsScreenSharing = _screenShareOwnerUid == _remoteUID;
            _isScreenSharing =
                _screenShareOwnerUid == _agoraService.currentUID;
          } else {
            _remoteIsScreenSharing = false;
            _isScreenSharing = false;
          }
          _syncLegacyRemoteStateFromRegistry();
        });
      } else if (uid == _agoraService.currentUID) {
        _scheduleUiUpdate(() {
          _screenShareOwnerUid = ownerUid;
          if (_screenShareOwnerUid != null) {
            _isScreenSharing = _screenShareOwnerUid == _agoraService.currentUID;
            _remoteIsScreenSharing = _screenShareOwnerUid == _remoteUID;
          } else {
            _isScreenSharing = false;
            _remoteIsScreenSharing = false;
          }
        });
      }
    });

    // User left (after grace period + reconnection checks in AgoraService)
    _userLeftSubscription = _agoraService.userLeftStream.listen((uid) {
      // Treat a confirmed \"left\" for either the current or last-seen remote UID
      // as the remote participant having left the call. This is important on web
      // where a fast browser refresh can cause:
      // 1) old UID -> userLeftStream(uid_old)
      // 2) new UID -> userJoinedStream(uid_new)
      // If we only compare against _remoteUID, we can miss the old leave event
      // and end up with a blank main area until the new video fully starts.
      final matchesCurrent = uid == _remoteUID;
      final matchesLast = uid == _lastRemoteUID;
      if (!matchesCurrent && !matchesLast) {
        LogService.info(
          'userLeftStream uid=$uid does not match current/last remote (current=$_remoteUID, last=$_lastRemoteUID) – ignoring.',
        );
        return;
      }

      final leftUid = uid;
      _remoteLeftCheckTimer?.cancel();
      _remoteLeftCheckTimer = null;

      _scheduleUiUpdate(() {
        _upsertParticipant(leftUid, userLeft: true);
        _remoteJoinedAt = null;
        // Keep track of who left for UI, but clear active remote so main area
        // switches to local/profile instead of rendering a blank remote view.
        _lastRemoteUID = leftUid;
        _removeParticipant(leftUid);
        _remoteUID = null;
        _syncLegacyRemoteStateFromRegistry();
        _layout = VideoLayout.spotlight;
      });

      LogService.info('Remote marked left – source: userLeftStream (remoteUid=$leftUid)');
      // Keep UX minimal: top status banner already communicates this state.
    });
    
    // Remote network quality (for instability detection)
    _remoteNetworkQualitySubscription =
        _agoraService.remoteNetworkQualityStream.listen((data) {
      final uid = data['uid'] as int;
      final isUnstable = data['isUnstable'] as bool? ?? false;

      if (uid == _remoteUID) {
        final now = DateTime.now();
        // Keep instability UI sticky for a short period to avoid rapid
        // unstable/stable flip-flop rendering on short network jitters.
        _remoteUnstableStickyUntil =
            isUnstable ? now.add(const Duration(seconds: 3)) : now.add(const Duration(seconds: 2));
        _remoteUnstableTimer?.cancel();
        _remoteUnstableTimer = Timer(const Duration(seconds: 3), () {
          if (!mounted) return;
          _scheduleUiUpdate(() {
            if (_remoteUnstableStickyUntil != null &&
                DateTime.now().isAfter(_remoteUnstableStickyUntil!)) {
              _remoteUnstableStickyUntil = null;
              _remoteConnectionUnstable = false;
            }
          });
        });

        _scheduleUiUpdate(() {
          _upsertParticipant(
            uid,
            connectionUnstable: isUnstable,
            lastActivityAt: DateTime.now(),
          );
          _syncLegacyRemoteStateFromRegistry();
        });
        
        if (isUnstable) {
          LogService.warning('⚠️ Remote user connection is unstable');
        } else {
          LogService.info('✅ Remote user connection is stable');
        }
      }
    });
    
    // Remote reactions
    _reactionSubscription =
        _agoraService.reactionStream.listen((data) {
      final uid = data['uid'] as int;
      final emoji = data['emoji'] as String;
      final myUid = _agoraService.currentUID ?? -1;
      // In 1:1 call, any reaction not from self is from the remote user - always show
      if (uid == myUid) return;
      // If _remoteUID not set (e.g. remote joined with camera/mic off), set it now
      if (_remoteUID == null) {
        safeSetState(() {
          _remoteUID = uid;
          _upsertParticipant(uid, userLeft: false, lastActivityAt: DateTime.now());
          _syncLegacyRemoteStateFromRegistry();
        });
      }
      LogService.info('🎉 Displaying remote reaction: $emoji from UID=$uid');
      _addReactionAnimation(emoji);
    });
    
    // Remote screen-off detection
    _remoteScreenOffSubscription = _agoraService.remoteScreenOffStream.listen((data) {
      final uid = data['uid'] as int;
      final screenOff = data['screenOff'] as bool? ?? false;
      
      if (uid == _remoteUID) {
        safeSetState(() {
          _upsertParticipant(uid, screenOff: screenOff);
          _syncLegacyRemoteStateFromRegistry();
        });
        
        if (screenOff) {
          LogService.info('📱 Remote user screen is off: UID=$uid');
        } else {
          LogService.info('✅ Remote user screen is back on: UID=$uid');
        }
      }
    });
    // Speaking indicator (who is talking)
    _speakingSubscription = _agoraService.speakingStream.listen((uids) {
      _scheduleUiUpdate(() {
        _speakingUids = uids;
      });
    });

    // Recording failed - show non-blocking snackbar (skip on mobile web; we don't start recording there)
    if (!(kIsWeb && platform_utils.PlatformUtils.isMobileWeb)) {
      _recordingFailedSubscription = AgoraRecordingService.onRecordingFailed.listen((message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppTheme.warning,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    }

    // Local connection state: Reconnecting… in status bar; brief "Connection restored" after rejoin
    _connectionStateSubscription =
        _agoraService.connectionStateStream.listen((state) {
      final reconnecting = state == agora_rtc_engine.ConnectionStateType.connectionStateReconnecting ||
          state == agora_rtc_engine.ConnectionStateType.connectionStateConnecting;
      final connected = state == agora_rtc_engine.ConnectionStateType.connectionStateConnected;
      _scheduleUiUpdate(() {
        final now = DateTime.now();
        if (connected && _localConnectionReconnecting) {
          _connectionRestoredAt = now;
          if (_isVideoEnabled && !_localVideoReady) {
            _ensureLocalPreviewActiveNow();
          }
          // Clear "Connection restored" after a few seconds
          Future.delayed(_connectionRestoredDisplayDuration, () {
            if (mounted) {
              _scheduleUiUpdate(() {
                _connectionRestoredAt = null;
              });
            }
          });
        }

        if (reconnecting) {
          _localReconnectClearTimer?.cancel();
          _localConnectionReconnecting = true;
          _localReconnectingShownAt ??= now;
          return;
        }

        if (_localConnectionReconnecting) {
          final shownAt = _localReconnectingShownAt ?? now;
          final elapsed = now.difference(shownAt);
          if (elapsed < _minReconnectIndicatorDisplay) {
            _localReconnectClearTimer?.cancel();
            _localReconnectClearTimer = Timer(
              _minReconnectIndicatorDisplay - elapsed,
              () {
                if (!mounted) return;
                _scheduleUiUpdate(() {
                  _localConnectionReconnecting = false;
                  _localReconnectingShownAt = null;
                });
              },
            );
            return;
          }
        }

        _localConnectionReconnecting = false;
        _localReconnectingShownAt = null;
      });
    });
  }
  
  /// Setup session timer
  void _setupTimer() {
    // Listen to time remaining updates
    _timeRemainingSubscription = _timerService.timeRemainingStream.listen((remaining) {
      safeSetState(() {
        _timeRemaining = remaining;
      });
    });
    
    // Listen to session ended events (auto-termination)
    _sessionEndedSubscription = _timerService.sessionEndedStream.listen((sessionId) {
      if (sessionId == widget.sessionId) {
        LogService.info('⏱️ Session time expired - auto-terminating');
        // Show end-of-class message and auto-leave (no OK/Cancel)
        _endCall(isSessionEndedByTime: true);
      }
    });
  }
  
  /// Start session timer
  ///
  /// Duration logic:
  /// - 30-minute trial sessions always use 30 minutes (constant)
  /// - All other sessions use AppConfig.sessionDurationMinutes
  ///
  /// Timer sync on rejoin: use call_timer_started_at from DB when present so that
  /// when a user refreshes and rejoins, they see the same remaining time as the other peer.
  Future<void> _startSessionTimer() async {
    try {
      // Get duration from database (call_timer_started_at is read via RPC below)
      final session = await _supabase
          .from('individual_sessions')
          .select('duration_minutes')
          .eq('id', widget.sessionId)
          .maybeSingle();

      int durationMinutes = AppConfig.sessionDurationMinutes;
      if (session != null) {
        final dbDuration = session['duration_minutes'] as int?;
        if (dbDuration == 30) {
          durationMinutes = 30;
          LogService.info('⏱️ 30-minute trial session detected - using fixed 30 minute duration');
        } else {
          LogService.info('⏱️ Regular session - using config duration: ${AppConfig.sessionDurationMinutes} minutes');
        }
      }

      // Resolve start time: use stored call_timer_started_at if set (sync on rejoin), else set and use now
      DateTime startTime = DateTime.now();
      try {
        final result = await _supabase.rpc('ensure_call_timer_started', params: {'p_session_id': widget.sessionId});
        if (result != null && result is String) {
          final parsed = DateTime.tryParse(result);
          if (parsed != null && parsed.isBefore(DateTime.now()) && parsed.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
            startTime = parsed;
            LogService.info('⏱️ Session timer synced to call_timer_started_at: $startTime');
          }
        }
      } catch (rpcError) {
        LogService.warning('ensure_call_timer_started RPC failed (using now): $rpcError');
      }

      await _timerService.startSession(
        widget.sessionId,
        startTime: startTime,
        durationMinutes: durationMinutes,
      );
      LogService.info('⏱️ Session timer started with duration: $durationMinutes minutes, startTime: $startTime');
    } catch (e) {
      LogService.warning('Error starting session timer: $e');
      try {
        await _timerService.startSession(
          widget.sessionId,
          startTime: DateTime.now(),
          durationMinutes: AppConfig.sessionDurationMinutes,
        );
        LogService.info('⏱️ Session timer started with fallback duration: ${AppConfig.sessionDurationMinutes} minutes');
      } catch (e2) {
        LogService.error('Failed to start session timer even with fallback: $e2');
      }
    }
  }

  /// After join, run a one-shot watchdog that re-applies startPreview/muteLocalVideoStream.
  /// This is safe to call multiple times and helps ensure the self-view becomes visible
  /// on platforms where the very first preview call is flaky.
  void _scheduleLocalPreviewWatchdog() {
    _localPreviewWatchdogTimer?.cancel();
    _localPreviewWatchdogTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (!_isVideoEnabled) return;
      if (_agoraService.engine == null) return;

      LogService.info('[SESSION] Local preview watchdog running – ensuring preview is active');
      // Run asynchronously so we do not block the timer callback.
      Future.microtask(() async {
        try {
          if (!_localVideoReady) {
            await _agoraService.ensureLocalVideoPublishing(
              startPreviewOnWeb: !platform_utils.PlatformUtils.isMobileWeb,
            );
            _scheduleUiUpdate(() {
              _localVideoReady = true;
            });
          }
          LogService.info('[SESSION] Local preview watchdog reapplied preview successfully');
        } catch (e) {
          LogService.warning('[SESSION] Local preview watchdog failed: $e');
        }
      });
    });
  }

  Future<void> _ensureLocalPreviewActiveNow({bool force = false}) async {
    if (_agoraService.engine == null || !_isVideoEnabled) return;
    if (_localPreviewEnsureInProgress) return;
    final now = DateTime.now();
    final isMobileWeb = kIsWeb && platform_utils.PlatformUtils.isMobileWeb;
    if (!force &&
        _localVideoReady &&
        _lastLocalPreviewEnsureAt != null &&
        now.difference(_lastLocalPreviewEnsureAt!) < const Duration(seconds: 8)) {
      return;
    }
    _localPreviewEnsureInProgress = true;
    try {
      await _agoraService.setupLocalVideoAfterJoin();
      await _agoraService.ensureLocalVideoPublishing(
        startPreviewOnWeb: !isMobileWeb || force || !_localVideoReady,
      );
      _lastLocalPreviewEnsureAt = now;
      _scheduleUiUpdate(() {
        _localVideoReady = true;
      });
    } catch (e) {
      LogService.warning('ensureLocalPreviewActiveNow failed: $e');
    } finally {
      _localPreviewEnsureInProgress = false;
    }
  }

  /// Toggle video (camera)
  /// Defers setState to next frame to avoid UI disappearing on mobile web when tapping control.
  /// Sends camera state after toggle so remote gets the new value (use service state, not widget state).
  /// On web, shows a diagnostic SnackBar to help trace video-mute UI issues.
  Future<void> _toggleVideo() async {
    String? toggleError;
    try {
      await _agoraService.toggleVideo();
      // Send the new state (from service) so remote sees camera on/off
      _agoraService.sendCameraState(_agoraService.isVideoEnabled());
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            safeSetState(() {
              _isVideoEnabled = _agoraService.isVideoEnabled();
            });
            if (_isVideoEnabled) {
              _ensureLocalPreviewActiveNow(force: true);
              _showTopStateMessage('Camera is back on');
            }
            if (kIsWeb) _showVideoMuteDiagnostic(toggleError);
          }
        });
      }
    } catch (e) {
      toggleError = e.toString();
      LogService.error('Error toggling video: $e');
      _showError('Failed to toggle camera');
      if (mounted && kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showVideoMuteDiagnostic(toggleError);
        });
      }
    }
  }

  /// Diagnostic overlay when video is toggled on web - helps trace spurious "remote left" / UI issues.
  void _showVideoMuteDiagnostic(String? error) {
    // Only show this diagnostic in debug builds; never surface raw backend details in production.
    if (!mounted || !kIsWeb || !kDebugMode) return;
    final msg = error != null
        ? 'Video mute error: $error'
        : 'Video ${_isVideoEnabled ? "on" : "off"}. remoteUID=$_remoteUID, remoteLeft=$_remoteUserLeft';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 12)),
        backgroundColor: error != null ? AppTheme.error : AppTheme.primaryDark,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  /// Send current camera state to remote user via data channel
  /// This is a fallback for when onRemoteVideoStateChanged doesn't fire reliably
  void _sendCameraStateToRemote() {
    _agoraService.sendCameraState(_isVideoEnabled);
  }

  /// Toggle audio (microphone)
  /// Defers setState to next frame to avoid UI disappearing on mobile web when tapping control.
  Future<void> _toggleAudio() async {
    try {
      await _agoraService.toggleAudio();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            safeSetState(() {
              _isAudioEnabled = _agoraService.isAudioEnabled();
            });
            if (_isAudioEnabled) {
              _showTopStateMessage('Microphone unmuted');
            }
          }
        });
      }
    } catch (e) {
      LogService.error('Error toggling audio: $e');
      _showError('Failed to toggle microphone');
    }
  }

  /// Toggle screen sharing. Guards against double-start; on user cancel, resets state so video doesn't freeze on "connecting".
  /// iOS Safari does not support getDisplayMedia - show clear message when it fails.
  Future<void> _toggleScreenSharing() async {
    try {
      if (_isScreenSharing || _agoraService.isPublishingScreen) {
        await _agoraService.stopScreenSharing();
        return;
      }
      await _agoraService.startScreenSharing();
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      final isUserCancel = (errorStr.contains('user') && (errorStr.contains('cancel') || errorStr.contains('canceled'))) ||
          errorStr.contains('canceled') || errorStr.contains('cancelled') || errorStr.contains('abort');
      final isPermissionDenied = errorStr.contains('notallowed') ||
          errorStr.contains('not allowed') ||
          errorStr.contains('permission') ||
          errorStr.contains('denied');
      final isNotSupported = errorStr.contains('notsupported') || 
          errorStr.contains('not supported') ||
          errorStr.contains('getdisplaymedia');

      if (isUserCancel && !isPermissionDenied) {
        LogService.info('Screen sharing cancelled by user');
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) safeSetState(() => _isScreenSharing = false);
          });
        }
        return;
      }

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) safeSetState(() => _isScreenSharing = false);
      });

      // iOS Safari does not support screen capture - show specific message
      if (kIsWeb && platform_utils.PlatformUtils.isIosWeb) {
        _showIosScreenShareUnsupportedMessage();
        return;
      }

      if (isPermissionDenied || isUserCancel || isNotSupported) {
        _showScreenSharePermissionDialog();
        return;
      }

      LogService.warning('[SESSION] Screen sharing error: $e');
    }
  }

  /// Show message when screen share is not supported (iOS Safari)
  void _showIosScreenShareUnsupportedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Screen sharing is not supported on iOS Safari. Please use the PrepSkul app or a desktop browser to share your screen.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        backgroundColor: AppTheme.warning,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show dialog when screen share fails due to permission; offer Open Settings / Cancel.
  void _showScreenSharePermissionDialog() {
    final isWeb = kIsWeb;
    final message = isWeb
        ? 'Screen sharing requires permission. If you denied the browser prompt, '
          'reset the permission in your browser settings and reload the page.'
        : 'Screen sharing requires permission. On this device you need to allow '
          'screen capture or display recording in Settings.';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Screen sharing',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          if (!isWeb)
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await CameraMicPermissionService().openAppSettings();
              },
              child: Text('Open Settings', style: GoogleFonts.poppins()),
            ),
        ],
      ),
    );
  }

  /// Handle reaction emoji selection
  void _handleReaction(String emoji) {
    // Add local reaction animation
    _addReactionAnimation(emoji);
    
    // Send reaction to remote users via Agora data stream
    try {
      _agoraService.sendReaction(emoji);
    } catch (e) {
      LogService.warning('Failed to send reaction: $e');
    }
  }

  /// Helper method to add reaction animation (can be reused for local and remote)
  void _addReactionAnimation(String emoji) {
    final screenSize = MediaQuery.of(context).size;
    final reactionKey = UniqueKey();
    
    final reactionWidget = ReactionAnimation(
      key: reactionKey,
      emoji: emoji,
      startPosition: Offset(screenSize.width / 2, screenSize.height / 2),
      onComplete: () {
        safeSetState(() {
          _reactionAnimations.removeWhere((w) {
            if (w is ReactionAnimation) {
              return w.key == reactionKey;
            }
            return false;
          });
        });
      },
    );
    
    safeSetState(() {
      _reactionAnimations.add(reactionWidget);
    });
  }

  /// End call and leave session.
  /// When [isSessionEndedByTime] is true (timer expired), show a friendly
  /// end-of-class message and automatically leave without asking OK/Cancel.
  Future<void> _endCall({bool isSessionEndedByTime = false}) async {
    if (_isEndingCall) return;
    _isEndingCall = true;
    if (isSessionEndedByTime) {
      // End of class: show message then auto-leave (no OK/Cancel - no user action required)
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(
              'End of class',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'You have come to the end of the class. Hope you had a great lesson!',
              style: GoogleFonts.poppins(fontSize: 15),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        // Brief display then auto-close dialog and proceed to cleanup
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.pop(context); // close the dialog
      }
    } else {
      // User tapped Leave: confirm first
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Leave session?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text(
            'Are you sure you want to leave this session?',
            style: GoogleFonts.poppins(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Leave', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        _isEndingCall = false;
        return;
      }
    }

    // Full-screen "Leaving..." overlay – fully opaque so no profile or "Waiting for..." shows behind
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: _kSoftDark,
        builder: (context) => Dialog(
          backgroundColor: _kSoftDark,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: _kSoftDark,
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white70),
                    const SizedBox(height: 24),
                    Text(
                      'Leaving...',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    try {
      // CRITICAL: Step 1 - Leave Agora channel and ensure all media tracks stop
      bool channelLeft = false;
      try {
        await _agoraService.leaveChannel();
        channelLeft = true;
        LogService.info('✅ Agora channel left successfully');
        await SessionHeartbeatService().sendLeftSignal();
      } catch (e) {
        // Handle mutex and other leave errors gracefully
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('mutex') || 
            errorStr.contains('already') || 
            errorStr.contains('not in channel')) {
          LogService.info('Channel already left (this is okay)');
          channelLeft = true;
        } else {
          LogService.warning('Error leaving channel: $e');
          // Still try to continue - may have partially left
        }
      }

      // CRITICAL: Step 2 - Verify state is disconnected before proceeding
      // Keep wait minimal to avoid sluggish leave UX.
      await Future.delayed(const Duration(milliseconds: 120));
      
      // Check if we're actually disconnected
      final currentState = _agoraService.state;
      if (currentState != AgoraSessionState.disconnected && channelLeft) {
        LogService.warning('State not yet disconnected, waiting...');
        // One short re-check only.
        await Future.delayed(const Duration(milliseconds: 120));
      }

      // CRITICAL: Step 3 - If tutor, end the session in lifecycle service
      // This must complete before navigation
      if (widget.userRole == 'tutor') {
        try {
          await SessionLifecycleService.endSession(widget.sessionId)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  LogService.warning('Session end timeout - continuing anyway');
                },
              );
          LogService.info('✅ Session ended in lifecycle service');
        } catch (e) {
          LogService.warning('Failed to end session in lifecycle: $e');
          // Continue anyway - user wants to leave
        }
      }

      // CRITICAL: Step 4 - Keep cleanup delay short for responsive UX.
      await Future.delayed(const Duration(milliseconds: 80));

      // CRITICAL: Step 5 - Verify media tracks are stopped
      // Check that video and audio are disabled
      if (_agoraService.isVideoEnabled() || _agoraService.isAudioEnabled()) {
        LogService.warning('Media tracks still enabled, forcing disable...');
        // Force disable if still enabled
        try {
          if (_agoraService.isVideoEnabled()) {
            await _agoraService.toggleVideo();
          }
          if (_agoraService.isAudioEnabled()) {
            await _agoraService.toggleAudio();
          }
          await Future.delayed(const Duration(milliseconds: 80));
        } catch (e) {
          LogService.warning('Error forcing media disable: $e');
        }
      }

      // CRITICAL: Step 5b - Release engine so call does not run in background (fixes hot phone)
      try {
        await _agoraService.releaseEngineAfterLeave();
        LogService.info('✅ Agora engine released after leave');
      } catch (e) {
        LogService.warning('Error releasing engine (continuing): $e');
      }

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      // CRITICAL: Step 6 - Stop timer before navigation
      await _timerService.stopSession();
      
      // CRITICAL: Step 7 - Navigate back only after all cleanup is complete
      if (mounted) {
        // On web, ensure we navigate to a proper screen instead of just popping
        // This prevents dark screen issues when the previous screen is not available
        if (kIsWeb) {
          // Navigate to the appropriate sessions screen based on user role
          if (widget.userRole == 'tutor') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/tutor-nav',
              (route) => route.isFirst,
              arguments: {'initialTab': 2}, // Sessions tab
            );
          } else {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/my-sessions',
              (route) => route.isFirst,
            );
          }
        } else {
          // On mobile, pop back to previous screen
          Navigator.pop(context);
        }
      }
    } catch (e) {
      LogService.error('Error ending call: $e');
      
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
      
      // Even if there's an error, try to navigate back
      if (mounted) {
        // On web, navigate to proper screen; on mobile, just pop
        if (kIsWeb) {
          if (widget.userRole == 'tutor') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/tutor-nav',
              (route) => route.isFirst,
              arguments: {'initialTab': 2}, // Sessions tab
            );
          } else {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/my-sessions',
              (route) => route.isFirst,
            );
          }
        } else {
          Navigator.pop(context);
        }
      }
    } finally {
      _isEndingCall = false;
      if (mounted) safeSetState(() => _showLeavingScreen = false);
    }
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _showTopStateMessage(String message) {
    final now = DateTime.now();
    final current = _transientStateMessage;
    final shownAt = _transientStateMessageShownAt;
    final normalizedIncoming = message.trim().toLowerCase();

    // Keep each message visible for a minimum window to avoid rapid flicker.
    if (current != null &&
        shownAt != null &&
        now.difference(shownAt) < _minTransientMessageDisplay) {
      // If same message is already visible, don't queue duplicate noise.
      if (current.trim().toLowerCase() == normalizedIncoming) {
        return;
      }
      final remaining = _minTransientMessageDisplay - now.difference(shownAt);
      _queuedTransientMessageTimer?.cancel();
      _queuedTransientMessageTimer = Timer(remaining, () {
        if (!mounted) return;
        _showTopStateMessage(message);
      });
      return;
    }

    // If the same message is already shown and we're outside minimum window,
    // avoid re-triggering animation jitter.
    if (current != null && current.trim().toLowerCase() == normalizedIncoming) {
      return;
    }

    _queuedTransientMessageTimer?.cancel();
    _transientStateMessageTimer?.cancel();
    _scheduleUiUpdate(() {
      _transientStateMessage = message;
      _transientStateMessageShownAt = DateTime.now();
    });
    _transientStateMessageTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _scheduleUiUpdate(() {
        if (_transientStateMessage == message) {
          _transientStateMessage = null;
          _transientStateMessageShownAt = null;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StatusBarUtils.withDarkStatusBar(
      WillPopScope(
        onWillPop: () async {
          await _endCall();
          return false;
        },
        child: Scaffold(
          backgroundColor: _kSoftDark,
          body: _showLeavingScreen
              ? const ColoredBox(color: _kSoftDark)
              : SafeArea(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildMainVideoArea(),
                      if (_layout == VideoLayout.spotlight &&
                          _isVideoEnabled &&
                          _sessionState == AgoraSessionState.connected &&
                          _remoteUID != null &&
                          !_remoteUserLeft)
              _buildLocalVideoPIP(),
                      _buildStateMessages(),
                      _buildConnectionOverlay(),
                      ..._reactionAnimations,
                      if (_showVaAvatar && _sessionState == AgoraSessionState.connected)
                        Positioned(
                          top: MediaQuery.of(context).padding.top +
                              // Mobile web: keep lower for safe separation from status bar.
                              // Desktop web: well below header for better view; native mobile: similar to mobile web.
                              (kIsWeb && platform_utils.PlatformUtils.isMobileWeb
                                  ? 88
                                  : kIsWeb
                                      ? 72
                                      : 80),
                          right: 12,
                          child: const PrepSkulVAAvatar(size: 48),
                        ),
                      // Status/control bar: on mobile web render IN the Stack so they stay visible.
                      // Listener with opaque ensures this overlay is in the hit-test path on web (platform view
                      // can steal focus otherwise; opaque makes overlay receive taps so buttons work).
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: Listener(
                            behavior: HitTestBehavior.deferToChild,
                            child: Material(
                              type: MaterialType.transparency,
                              elevation: 32,
                              child: IgnorePointer(
                                ignoring: false,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildStatusBar(),
                                    _buildControlBar(),
                                  if (_vaBannerVisible && kIsWeb)
                                    Positioned(
                                      top: MediaQuery.of(context).padding.top + 56,
                                      left: 16,
                                      right: 16,
                                      child: Center(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: BackdropFilter(
                                            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: _kGlassFill,
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(color: _kGlassBorder, width: 1),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.25),
                                                    blurRadius: 16,
                                                    offset: const Offset(0, 6),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                "PrepSkul VA has joined the session.",
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Keep global blocking overlays ABOVE status/control layer so
                      // their buttons (e.g. Retry) always receive taps.
                      if (_errorMessage != null) _buildErrorOverlay(),
                      if (_sessionState == AgoraSessionState.joining) _buildLoadingOverlay(),
                      if (_showReactionsPanel) _buildReactionsPanel(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// Build main video area - covers almost entire screen (no pure black; use soft neutral + placeholders).
  /// When joining, only a dark container is shown; the single "Connecting..." is in the overlay.
  Widget _buildMainVideoArea() {
    final engine = _agoraService.engine;
    final bool isMobileWeb = kIsWeb && platform_utils.PlatformUtils.isMobileWeb;
    final isJoining = _sessionState == AgoraSessionState.joining;
    // Debug: log main-area branch for mobile web to diagnose blank screen on join
    if (isMobileWeb && (isJoining || _sessionState.isActive)) {
      LogService.info(
        '📺 [MAIN_AREA] state=$_sessionState remoteUID=$_remoteUID remoteLeft=$_remoteUserLeft '
        'videoMuted=$_remoteVideoMuted isVideoEnabled=$_isVideoEnabled localVideoReady=$_localVideoReady '
        'engine=${engine != null} isJoining=$isJoining',
      );
      debugPrint(
        '[MAIN_AREA] state=$_sessionState remoteUID=$_remoteUID remoteLeft=$_remoteUserLeft '
        'videoMuted=$_remoteVideoMuted isVideoEnabled=$_isVideoEnabled localVideoReady=$_localVideoReady',
      );
    }
    if (engine == null || isJoining) {
      return Container(color: _kSoftDark);
    }

    // Side-by-side layout: portrait = top/bottom, landscape = left/right
    if (_layout == VideoLayout.sideBySide) {
      final size = MediaQuery.of(context).size;
      final isPortrait = size.height > size.width;
      if (isPortrait) {
        return Column(
          children: [
            Expanded(child: _buildRemotePanel()),
            Expanded(child: _buildLocalPanel()),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: _buildRemotePanel()),
          Expanded(child: _buildLocalPanel()),
        ],
      );
    }

    // CRITICAL: Check if remote user left FIRST before showing screen sharing
    // This ensures we show profile card instead of blank screen after user leaves during screen share
    if (_remoteUserLeft && (_isScreenSharing || _remoteIsScreenSharing)) {
      return Container(
        color: _kSoftDark,
        child: _buildWaitingPlaceholder(),
      );
    }

    // If screen sharing is active, show screen share (not camera video)
    if (_isScreenSharing || _remoteIsScreenSharing) {
      final sharingUid = _remoteIsScreenSharing ? _remoteUID : _agoraService.currentUID;
      final isLocalSharing = sharingUid == _agoraService.currentUID;
      if (sharingUid != null && !(_remoteIsScreenSharing && _remoteUserLeft)) {
        LogService.info('📺 [ScreenShare] Showing screen share view: UID=$sharingUid, isLocal=$isLocalSharing, platform=${kIsWeb ? "web" : "mobile"}');
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1280,
              height: 720,
              child: agora_widget.AgoraVideoViewWidget(
                engine: engine,
                uid: sharingUid,
                isLocal: isLocalSharing,
                connection: _agoraService.currentConnection,
                sourceType: agora_rtc_engine.VideoSourceType.videoSourceScreen,
              ),
            ),
          ),
        );
      } else if (_remoteUID != null && !_remoteUserLeft) {
        // Fallback: If screen share UID is invalid but remote user exists, show camera instead
        LogService.warning('⚠️ Screen sharing UID is null, falling back to camera view');
        final connection = _agoraService.currentConnection;
        return SizedBox.expand(
          key: ValueKey('remote_camera_fallback_$_remoteUID'),
          child: agora_widget.AgoraVideoViewWidget(
            engine: engine,
            uid: _remoteUID,
            isLocal: false,
            connection: connection,
            sourceType: agora_rtc_engine.VideoSourceType.videoSourceCamera,
          ),
        );
      }
    }

    // If remote user joined: show their video only when unmuted; when muted show only their profile (no black video behind)
    // CRITICAL: When _remoteUID != null && !_remoteUserLeft, main area must show REMOTE only (never local).
    // Key is stable and does not depend on local _isVideoEnabled so toggling own camera on web does not swap views.
    // On mobile web: always keep main area on remote (or profile) when remote is present so that turning off
    // local camera never produces a blank screen or full-screen local view; overlay (timer, controls) stays visible.
    if (_remoteUID != null && !_remoteUserLeft) {
      final connection = _agoraService.currentConnection;
      // Overlay when frame not ready, camera off, or poor network so we never show a frozen/black video surface.
      final showRemoteOverlay = _remoteVideoMuted ||
          !_remoteVideoReady ||
          _remoteScreenOff ||
          connection == null ||
          _remoteConnectionUnstable;

      // Keep a stable structure (base video + fading overlay) to reduce
      // flicker/shakes when Agora emits rapid state transitions.
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (connection != null)
              _wrapWithSpeakingIndicator(
                SizedBox.expand(
                  key: ValueKey('remote_video_main_${_remoteUID}_camera'),
                  child: agora_widget.AgoraVideoViewWidget(
                    engine: engine,
                    uid: _remoteUID,
                    isLocal: false,
                    connection: connection,
                  ),
                ),
                _remoteUID,
              )
            else
              Container(color: _kSoftDark),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              opacity: showRemoteOverlay ? 1 : 0,
              child: IgnorePointer(
                ignoring: !showRemoteOverlay,
                child: Container(
                  color: _kSoftDark,
                  child: Center(child: _buildRemoteProfileCard()),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // If remote user left: always show only the remote profile card ("left the call"),
    // never keep local profile/video in the main area behind it.
    if (_remoteUserLeft) {
      final effectiveRemoteUid = _remoteUID ?? _lastRemoteUID;
      if (effectiveRemoteUid != null) {
        final connection = _agoraService.currentConnection;
        LogService.info(
          '📺 [UI] Main area REMOTE_LEFT: showing only remote profile card (uid=$effectiveRemoteUid)',
        );
        return _buildStableRemoteSurface(
          engine: engine,
          remoteUid: effectiveRemoteUid,
          connection: _remoteUID == effectiveRemoteUid ? connection : null,
          forceOverlay: true,
        );
      }
      if (_remoteProfile != null) {
        return _buildStableRemoteSurface(
          engine: engine,
          remoteUid: _lastRemoteUID ?? 0,
          connection: null,
          forceOverlay: true,
        );
      }
      return Container(color: _kSoftDark);
    }

    // When alone: show self (video or profile) WITH "waiting for" overlay
    if (_remoteUID == null && _sessionState == AgoraSessionState.connected) {
      LogService.info(
        '📺 [UI] Main area showing LOCAL (waiting for remote): remoteUID=null, remoteUserLeft=$_remoteUserLeft, isVideoEnabled=$_isVideoEnabled',
      );
      if (_agoraService.currentUID != null) {
        return _buildStableLocalSurface(
          engine: engine,
          localUid: _agoraService.currentUID!,
          showWaiting: true,
        );
      }
      return Container(color: _kSoftDark, child: _buildWaitingPlaceholder());
    }

    // Waiting state (joining uses overlay for single "Connecting..."; no duplicate here)
      return Container(
      color: _kSoftDark,
      child: _buildWaitingPlaceholder(),
    );
  }

  /// Optional subtle speaking indicator: only a thin border, no badge. Local user: only when mic is ON.
  Widget _wrapWithSpeakingIndicator(Widget child, int? uid) {
    final isLocal = uid == _agoraService.currentUID;
    final isSpeaking = uid != null &&
        _speakingUids.contains(uid) &&
        (isLocal ? _isAudioEnabled : true); // Don't show "you're speaking" when muted
    if (!isSpeaking) return child;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white38, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  /// Stable remote surface: keeps the same widget structure and fades overlay
  /// in/out instead of replacing entire branches on transient state changes.
  Widget _buildStableRemoteSurface({
    required agora_rtc_engine.RtcEngine engine,
    required int remoteUid,
    required agora_rtc_engine.RtcConnection? connection,
    bool forceShowAsPresent = false,
    bool forceOverlay = false,
  }) {
    final showOverlay = forceOverlay ||
        _remoteUserLeft ||
        !_remoteVideoReady ||
        _remoteVideoMuted ||
        _remoteScreenOff ||
        connection == null;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (connection != null && !_remoteUserLeft)
            _wrapWithSpeakingIndicator(
              SizedBox.expand(
                key: ValueKey('stable_remote_video_$remoteUid'),
                child: agora_widget.AgoraVideoViewWidget(
                  engine: engine,
                  uid: remoteUid,
                  isLocal: false,
                  connection: connection,
                ),
              ),
              remoteUid,
            )
          else
            Container(color: _kSoftDark),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            opacity: showOverlay ? 1 : 0,
            child: IgnorePointer(
              ignoring: !showOverlay,
              child: Container(
                color: _kSoftDark,
                child: Center(
                  child: _buildRemoteProfileCard(
                    forceShowAsPresent: forceShowAsPresent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Stable local surface for alone/waiting and side-by-side branches.
  Widget _buildStableLocalSurface({
    required agora_rtc_engine.RtcEngine engine,
    required int localUid,
    bool showWaiting = false,
  }) {
    final hasReadyVideo = _isVideoEnabled && _localVideoReady;
    final showLoading = _isVideoEnabled && !_localVideoReady;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasReadyVideo)
          _wrapWithSpeakingIndicator(
            SizedBox.expand(
              key: ValueKey('stable_local_video_$localUid'),
              child: agora_widget.AgoraVideoViewWidget(
                engine: engine,
                uid: localUid,
                isLocal: true,
                connection: _agoraService.currentConnection,
              ),
            ),
            localUid,
          )
        else if (showLoading)
          Container(
            color: _kSoftDark,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          )
        else
          Container(
            color: _kSoftDark,
            child: Center(child: _buildLocalProfileCard()),
          ),
        // Waiting state is communicated by the top status banner only
        // to avoid duplicate/distracting messaging.
      ],
    );
  }

  /// One panel in side-by-side layout: remote (or screen share) or placeholder.
  Widget _buildRemotePanel() {
    final engine = _agoraService.engine;
    if (engine == null) {
      return Container(
        color: _kSoftDark,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white70),
              const SizedBox(height: 12),
              Text(
                'Connecting...',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    if (_remoteUserLeft && (_isScreenSharing || _remoteIsScreenSharing)) {
      return Container(color: _kSoftDark, child: _buildWaitingPlaceholder());
    }
    if (_isScreenSharing || _remoteIsScreenSharing) {
      final sharingUid = _remoteIsScreenSharing ? _remoteUID : _agoraService.currentUID;
      final isLocalSharing = sharingUid == _agoraService.currentUID;
      if (sharingUid != null && !(_remoteIsScreenSharing && _remoteUserLeft)) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1280,
              height: 720,
              child: agora_widget.AgoraVideoViewWidget(
                engine: engine,
                uid: sharingUid,
                isLocal: isLocalSharing,
                connection: _agoraService.currentConnection,
                sourceType: agora_rtc_engine.VideoSourceType.videoSourceScreen,
              ),
            ),
          ),
        );
      }
      if (_remoteUID != null && !_remoteUserLeft) {
        final connection = _agoraService.currentConnection;
        return SizedBox.expand(
          key: ValueKey('remote_camera_sidebyside_${_remoteUID}_camera'),
          child: agora_widget.AgoraVideoViewWidget(
            engine: engine,
            uid: _remoteUID,
            isLocal: false,
            connection: connection,
            sourceType: agora_rtc_engine.VideoSourceType.videoSourceCamera,
          ),
        );
      }
    }
    if (_remoteUID != null && !_remoteUserLeft) {
      final connection = _agoraService.currentConnection;
      return _buildStableRemoteSurface(
        engine: engine,
        remoteUid: _remoteUID!,
        connection: connection,
      );
    }
    return Container(color: _kSoftDark, child: _buildWaitingPlaceholder());
  }

  /// Other panel in side-by-side layout: local video or placeholder.
  Widget _buildLocalPanel() {
    final engine = _agoraService.engine;
    if (engine == null || _agoraService.currentUID == null) {
      return Container(
        color: _kSoftDark,
        child: Center(
          child: Text(
            'You',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }
    return _buildStableLocalSurface(
      engine: engine,
      localUid: _agoraService.currentUID!,
    );
  }

  /// Build local video PIP
  Widget _buildLocalVideoPIP() {
    final engine = _agoraService.engine;
    if (engine == null || _agoraService.currentUID == null) {
      return const SizedBox.shrink();
    }

    final localUid = _agoraService.currentUID;
    return LocalVideoPIP(
      engine: engine,
      localUid: localUid,
      isVideoEnabled: _isVideoEnabled,
      isAudioEnabled: _isAudioEnabled,
      isSpeaking: localUid != null && _isAudioEnabled && _speakingUids.contains(localUid),
    );
  }

  /// Build local profile card (when camera is off)
  Widget _buildLocalProfileCard() {
    String name = widget.userRole == 'tutor' ? 'Tutor' : 'Learner';
    if (_localProfile != null) {
      final profileName = _localProfile!['full_name'] as String?;
      if (profileName != null && profileName.isNotEmpty && profileName != 'User') {
        name = profileName;
      }
    }
    final avatarUrl = _localProfile?['avatar_url'] as String?;

    return ProfileCardOverlay(
      avatarUrl: avatarUrl,
      name: name,
      role: widget.userRole,
      isLocal: true,
    );
  }

  /// Build remote profile card (when remote camera is off, screen is off, or user left).
  /// [forceShowAsPresent] when true (e.g. mobile web main-area lock) shows "Camera is off" instead of "Left".
  Widget _buildRemoteProfileCard({bool forceShowAsPresent = false}) {
    // Show if remote user left OR remote video is muted (camera off) OR screen is off OR force
    if (!forceShowAsPresent &&
        !_remoteUserLeft &&
        _remoteVideoReady &&
        !_remoteVideoMuted &&
        !_remoteScreenOff) {
      return const SizedBox.shrink();
    }

    String name = widget.userRole == 'tutor' ? 'Learner' : 'Tutor';
    if (_remoteProfile != null) {
      final profileName = _remoteProfile!['full_name'] as String?;
      if (profileName != null && profileName.isNotEmpty && profileName != 'User') {
        name = profileName;
      }
    }
    final avatarUrl = _remoteProfile?['avatar_url'] as String?;
    final role = widget.userRole == 'tutor' ? 'learner' : 'tutor';

    return ProfileCardOverlay(
      avatarUrl: avatarUrl,
      name: name,
      role: role,
      isLocal: false,
      userLeft: forceShowAsPresent ? false : _remoteUserLeft,
      screenOff: _remoteScreenOff,
      cameraOff: _remoteVideoMuted,
      reconnecting: _remoteConnectionUnstable,
    );
  }

  /// Placeholder when waiting for remote (no video yet): avatar (or initials) + name + "Waiting for [Tutor/Learner]..."
  Widget _buildWaitingPlaceholder() {
    String name = widget.userRole == 'tutor' ? 'Learner' : 'Tutor';
    if (_remoteProfile != null) {
      final profileName = _remoteProfile!['full_name'] as String?;
      if (profileName != null && profileName.isNotEmpty && profileName != 'User') {
        name = profileName;
      }
    }
    final waitingFor = widget.userRole == 'tutor' ? 'learner' : 'tutor';
    final roleColor = widget.userRole == 'tutor' ? AppTheme.accentGreen : AppTheme.accentBlue;
    String initials = name.isNotEmpty ? name.trim().split(' ').length >= 2
        ? '${name.trim().split(' ')[0][0]}${name.trim().split(' ')[1][0]}'.toUpperCase()
        : name[0].toUpperCase()
        : '?';
    final avatarUrl = _remoteProfile?['avatar_url'] as String?;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: roleColor.withOpacity(0.2),
              border: Border.all(color: roleColor.withOpacity(0.5), width: 2),
            ),
            child: hasAvatar
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                      placeholder: (_, __) => Center(
                        child: CircularProgressIndicator(color: roleColor),
                      ),
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.poppins(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.poppins(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: roleColor,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          // Keep placeholder clean; top banner already shows waiting status.
        ],
      ),
    );
  }

  /// Connection quality overlay: same visual style as "Waiting for tutor/learner" –
  /// pulsing pill with animated dots for consistency.
  Widget _buildConnectionOverlay() {
    // Per latest UX: remove the full-screen "connection unstable – reconnecting" animation.
    // We still surface connection quality via the status pills in the header and the
    // subtle text in ProfileCardOverlay, but avoid the blocking overlay.
    return const SizedBox.shrink();
  }

  /// Build state messages (non-intrusive)
  Widget _buildStateMessages() {
    if (_sessionState != AgoraSessionState.connected) {
      return const SizedBox.shrink();
    }

    Widget? message;
    String messageKey = 'none';
    // Persistent states (left/reconnecting/waiting/connected) are handled by CallStatusBanner.
    // Keep this layer only for short, event-like notifications.
    if (_transientStateMessage != null) {
      messageKey = 'transient';
      message = SessionStateMessage(
        message: _transientStateMessage!,
        icon: Icons.info_outline,
        color: AppTheme.primaryColor,
        duration: const Duration(seconds: 3),
      );
    }

    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: message == null
              ? const SizedBox.shrink(key: ValueKey('state_none'))
              : KeyedSubtree(
                  key: ValueKey('state_$messageKey'),
                  child: message,
                ),
        ),
      ),
    );
  }

  /// Build status bar (Meet/Zoom-style: clean gradient, connection pill, timer, quality)
  Widget _buildStatusBar() {
    final isAloneWaiting =
        _sessionState.isActive && !_remoteUserLeft && _remoteUID == null;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Stack(
        children: [
          CallStatusBanner(
            sessionState: _sessionState,
            remoteConnectionUnstable: _remoteConnectionUnstable,
            localReconnecting: _localConnectionReconnecting,
            remoteUserLeft: _remoteUserLeft,
            isAloneWaiting: isAloneWaiting,
            timeRemaining: _timeRemaining,
          ),
          if (_sessionState.isActive && _remoteUID != null)
            Positioned(
              top: 8,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _layout = _layout == VideoLayout.spotlight
                          ? VideoLayout.sideBySide
                          : VideoLayout.spotlight;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kGlassFill,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kGlassBorder.withOpacity(0.7)),
                    ),
                    child: Icon(
                      _layout == VideoLayout.spotlight
                          ? Icons.grid_view
                          : Icons.crop_free,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build control bar (bottom, Google Meet style)
  Widget _buildControlBar() {
    if (kIsWeb) {
      debugPrint('[ControlBar] build remoteUserLeft=$_remoteUserLeft remoteUID=$_remoteUID');
    }
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              // Keep high contrast while using restrained glass treatment.
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.88),
                  const Color(0xE6141F36),
                  const Color(0x99141F36),
                ],
              ),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.14), width: 1)),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildControlButton(
                    icon: _isAudioEnabled ? Icons.mic : Icons.mic_off,
                    label: _isAudioEnabled ? 'Mute' : 'Unmute',
                    onPressed: _controlsEnabled ? _toggleAudio : () {},
                    isActive: _isAudioEnabled,
                    showMutedIndicator: !_isAudioEnabled,
                    showSpeakingWave: _isAudioEnabled &&
                        _agoraService.currentUID != null &&
                        _speakingUids.contains(_agoraService.currentUID),
                    enabled: _controlsEnabled,
                  ),
                  const SizedBox(width: 12),
                  _buildControlButton(
                    icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                    label: _isVideoEnabled ? 'Camera Off' : 'Camera On',
                    onPressed: _controlsEnabled ? _toggleVideo : () {},
                    isActive: _isVideoEnabled,
                    showMutedIndicator: !_isVideoEnabled,
                    enabled: _controlsEnabled,
                  ),
                  const SizedBox(width: 12),
                  _buildControlButton(
                    icon: Icons.emoji_emotions,
                    label: 'Reactions',
                    onPressed: _controlsEnabled
                        ? () {
                            if (mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) safeSetState(() {
                                  _showReactionsPanel = !_showReactionsPanel;
                                });
                              });
                            }
                          }
                        : () {},
                    isActive: _showReactionsPanel,
                    enabled: _controlsEnabled,
                  ),
                  const SizedBox(width: 12),
                  (kIsWeb && platform_utils.PlatformUtils.isMobileWeb)
                      ? const SizedBox.shrink()
                      : _buildScreenShareButton(),
                  const SizedBox(width: 12),
                  _buildControlButton(
                    icon: Icons.call_end,
                    label: 'Leave',
                    onPressed: _endCall,
                    isActive: false,
                    isDanger: true,
                    enabled: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build screen share button (hidden on mobile web via caller).
  /// Android web supports getDisplayMedia; iOS Safari does not.
  Widget _buildScreenShareButton() {
    return _buildControlButton(
      icon: Icons.screen_share,
      label: _isScreenSharing ? 'Stop Sharing' : 'Share Screen',
      onPressed: _controlsEnabled ? _toggleScreenSharing : () {},
      isActive: _isScreenSharing,
      enabled: _controlsEnabled,
    );
  }

  /// Build reactions panel
  Widget _buildReactionsPanel() {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: ReactionsPanel(
          onEmojiSelected: _handleReaction,
          onClose: () {
            safeSetState(() {
              _showReactionsPanel = false;
            });
          },
        ),
      ),
    );
  }

  /// Build control button: clean neutral style; muted = subtle grey (not red); Leave = red.
  /// Optional [showSpeakingWave] shows a small wave at bottom of button (e.g. for mic when speaking).
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
    String? semanticLabel,
    bool isDanger = false,
    bool showMutedIndicator = false,
    bool showSpeakingWave = false,
    bool enabled = true,
  }) {
    final content = Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: isDanger
                    ? Colors.red
                    : showMutedIndicator
                        ? Colors.white.withOpacity(0.06)
                    : (isActive 
                            ? Colors.white.withOpacity(0.18)
                            : Colors.white.withOpacity(0.08)),
                shape: BoxShape.circle,
                border: showMutedIndicator
                    ? Border.all(color: Colors.white24, width: 1)
                    : (isActive && !isDanger ? Border.all(color: Colors.white38, width: 1) : null),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDanger ? 0.35 : 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    color: isDanger
                        ? Colors.white
                        : (showMutedIndicator
                            ? Colors.white54
                            : (isActive ? Colors.white : Colors.white70)),
                    size: 26,
                  ),
                  if (showMutedIndicator)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 12,
                        height: 1.5,
                        decoration: BoxDecoration(
                          color: Colors.white38,
                          borderRadius: BorderRadius.circular(1),
                        ),
                        transform: Matrix4.rotationZ(-0.785398),
                      ),
                    ),
                  if (showSpeakingWave) _buildSpeakingWave(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!enabled) {
      return IgnorePointer(
        ignoring: true,
        child: Opacity(opacity: 0.45, child: content),
      );
    }
    return content;
  }

  /// Small wave bars (audio level) for speaking indicator next to mic icon.
  Widget _buildSpeakingWave() {
    return Positioned(
      bottom: 10,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (i) {
          return Container(
            width: 2,
            height: 4 + (i % 2) * 4.0,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: Colors.white70,
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
    );
  }

  /// Convert technical error messages to user-friendly ones
  String _toUserFriendlyError(String error) {
    String msg = error;
    if (msg.startsWith('Failed to join: ')) msg = msg.substring(15);
    if (msg.startsWith('Exception: ')) msg = msg.substring(11);
    if (msg.contains('permission') ||
        msg.contains('Permission') ||
        msg.contains('NotAllowedError') ||
        msg.contains('NotAllowed')) {
      return 'Camera and microphone are blocked. Allow access in browser/app settings, refresh, then rejoin.';
    }
    if (msg.contains('CORS') || msg.contains('cors') || msg.contains('API URL') || msg.contains('origin') || msg.contains('Check:')) {
      return 'Poor network connection. Please check your internet and try again.';
    }
    if (msg.contains('timeout') || msg.contains('unreachable') || msg.contains('slow to respond')) {
      return 'Connection timed out. Please check your connection and try again.';
    }
    if (msg.contains('Unauthorized') || msg.contains('401')) return 'Session expired. Please log in again.';
    if (msg.contains('Access denied') || msg.contains('403')) return 'You do not have access to this session.';
    if (msg.contains('Something went wrong on our end')) return msg;
    if (msg.contains('Connection failed') || msg.contains('Unable to connect') || msg.contains('Connection timed out') || msg.contains('Connection error') || msg.contains('Poor network')) {
      return msg;
    }
    return 'Connection failed. Please check your internet and try again.';
  }

  Future<void> _retryFromError() async {
    _scheduleUiUpdate(() {
      _errorMessage = null;
      if (_sessionState == AgoraSessionState.error) {
        _sessionState = AgoraSessionState.joining;
      }
      _remoteVideoReady = false;
      _remoteVideoMuted = true;
    });

    try {
      if (_agoraService.isInChannel) {
        await _agoraService.tryRecoverCamera();
        _scheduleUiUpdate(() {
          _sessionState = AgoraSessionState.connected;
        });
      } else {
        await _initializeSession();
      }
    } catch (e) {
      LogService.error('Retry from error failed: $e');
      if (!mounted) return;
      _scheduleUiUpdate(() {
        _sessionState = AgoraSessionState.error;
        _errorMessage = _toUserFriendlyError(e.toString());
      });
    }
  }

  /// Build error overlay
  Widget _buildErrorOverlay() {
    final message = _errorMessage ?? 'Something went wrong. Please try again.';
    final lowerMessage = message.toLowerCase();
    final isSessionExpired = message.contains('Session expired');
    final isNetworkIssue = lowerMessage.contains('network') ||
        lowerMessage.contains('connection') ||
        lowerMessage.contains('internet') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('poor');
    final isPermissionBlocked = lowerMessage.contains('camera and microphone are blocked') ||
        (lowerMessage.contains('camera') && lowerMessage.contains('allow access'));
    final iconColor = isSessionExpired
        ? AppTheme.warning
        : isNetworkIssue
            ? AppTheme.softYellow
            : AppTheme.error;
    final title = isSessionExpired
        ? 'Session Expired'
        : isNetworkIssue
            ? 'Connection Issue'
            : isPermissionBlocked
                ? 'Permissions Required'
                : 'Error';

    return Positioned.fill(
      child: Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNetworkIssue
                    ? Icons.wifi_off_rounded
                    : isPermissionBlocked
                        ? Icons.videocam_off_rounded
                    : Icons.error_outline,
                color: iconColor,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.neutral700,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _retryFromError,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  isPermissionBlocked ? 'Retry after allowing' : 'Retry',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  /// Build loading overlay (branded, soft background – no pure black)
  Widget _buildLoadingOverlay() {
    return Container(
      color: _kSoftDark,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white70),
            const SizedBox(height: 24),
            Text(
              'Connecting...',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated "Waiting for tutor/learner to join..." text with pulsing dots
class _AnimatedWaitingText extends StatefulWidget {
  // Keep optional parameter for hot-reload compatibility across constructor changes.
  final String? waitingFor;
  const _AnimatedWaitingText({this.waitingFor});
  
  @override
  State<_AnimatedWaitingText> createState() => _AnimatedWaitingTextState();
}

class _AnimatedWaitingTextState extends State<_AnimatedWaitingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 0;
  Timer? _dotTimer;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    // Animate dots: cycle through 1, 2, 3 dots
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _dotTimer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final dots = '.' * (_dotCount == 0 ? 3 : _dotCount);
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5 + (_controller.value * 0.2)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            'Waiting for participant$dots',
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.8 + (_controller.value * 0.2)),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}

