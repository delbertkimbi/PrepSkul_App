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
import 'package:prepskul/features/sessions/widgets/reactions_panel.dart';
import 'package:prepskul/features/sessions/widgets/reaction_animation.dart';
import 'package:prepskul/features/sessions/widgets/prepskul_va_avatar.dart';
import 'package:prepskul/features/booking/services/session_lifecycle_service.dart';
import 'package:prepskul/features/sessions/services/agora_recording_service.dart';
import 'package:prepskul/features/sessions/services/session_timer_service.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora_rtc_engine;
import 'package:prepskul/core/utils/platform_utils_stub.dart'
    if (dart.library.html) 'package:prepskul/core/utils/platform_utils_web.dart' as platform_utils;
import 'dart:async';

/// Deep blue for video/connecting/leaving/waiting – consistent with app theme.
const Color _kSoftDark = Color(0xFF0F1A2E); // AppTheme.primaryDark

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

class _AgoraVideoSessionScreenState extends State<AgoraVideoSessionScreen> {
  final AgoraService _agoraService = AgoraService();
  final _supabase = SupabaseService.client;
  final SessionProfileService _profileService = SessionProfileService();

  AgoraSessionState _sessionState = AgoraSessionState.disconnected;
  bool _isVideoEnabled = false; // Will be set from initial state
  bool _isAudioEnabled = false; // Will be set from initial state
  int? _remoteUID;
  String? _errorMessage;
  
  // Remote state tracking
  bool _remoteVideoMuted = false;
  bool _remoteAudioMuted = false;
  bool _isScreenSharing = false;
  bool _remoteIsScreenSharing = false;
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
  /// When non-null, show "Connection restored" in status bar until this time + a few seconds.
  DateTime? _connectionRestoredAt;
  static const Duration _connectionRestoredDisplayDuration = Duration(seconds: 4);
  
  // Screen-off tracking
  bool _remoteScreenOff = false;
  
  // Session timer
  final SessionTimerService _timerService = SessionTimerService();
  Duration? _timeRemaining;
  StreamSubscription<Duration>? _timeRemainingSubscription;
  StreamSubscription<String>? _sessionEndedSubscription;
  bool _timerStarted = false; // Ensure timer starts only once (when both users are in)
  bool _isEndingCall = false;
  /// When true, body is plain black so nothing (no profile, no "Waiting for tutor...") shows behind the "Leaving..." dialog.
  bool _showLeavingScreen = false;
  
  // Local video ready flag - ensures video is set up before rendering
  bool _localVideoReady = false;
  
  // Debounce timer for video state changes (prevents flickering)
  Timer? _videoStateDebounceTimer;

  /// On mobile web, status/control bar is rendered via Overlay so it stays above Agora platform view after mute.
  OverlayEntry? _mobileWebOverlayEntry;

  /// Mobile web: last time we received any activity from remote (video/audio/join); used to detect "user left" when they close tab.
  DateTime? _lastRemoteActivityAt;
  Timer? _remoteLeftCheckTimer;
  static const Duration _remoteLeftInactivityThreshold = Duration(seconds: 60);
  static const Duration _remoteLeftCheckInterval = Duration(seconds: 15);

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
    _initializeSession();
    _setupListeners();
    _setupTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _insertMobileWebOverlayIfNeeded());
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

    _remoteLeftCheckTimer?.cancel();
    _remoteLeftCheckTimer = null;
    _removeMobileWebOverlay();

    // Stop timer
    _timerService.stopSession();
    // Don't dispose AgoraService here - it's a singleton
    super.dispose();
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
    LogService.info('[MOBILE_WEB] In-call overlay inserted into Overlay layer');
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Remote participant left', style: GoogleFonts.poppins(fontSize: 12)),
              backgroundColor: Colors.blueGrey.shade800,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
      if (widget.initialCameraEnabled && _agoraService.engine != null) {
        try {
          LogService.info('[SESSION] Setting up local video immediately after join...');
          
          // Set up local video canvas with camera source
          await _agoraService.engine!.setupLocalVideo(
            const agora_rtc_engine.VideoCanvas(
              uid: 0,
              sourceType: agora_rtc_engine.VideoSourceType.videoSourceCamera,
            ),
          );
          
          // On web, start preview explicitly
          if (kIsWeb) {
            await _agoraService.engine!.startPreview();
          }
          
          // Small delay to allow video to initialize
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Ensure video stream is unmuted (publishing)
          await _agoraService.engine!.muteLocalVideoStream(false);
          
          LogService.info('[SESSION] Local video set up successfully - should be visible now');
          
          safeSetState(() {
            _localVideoReady = true;
          });
        } catch (e) {
          LogService.warning('[SESSION] Error setting up local video: $e');
          // Still mark as ready to allow UI to render
          safeSetState(() {
            _localVideoReady = true;
          });
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
      safeSetState(() {
        _sessionState = state;
      });
    });

    _userJoinedSubscription = _agoraService.userJoinedStream.listen((uid) {
      LogService.info('👤 Remote user joined: UID=$uid');
      safeSetState(() {
        _remoteUID = uid;
        _lastRemoteUID = uid; // Keep for mobile web main-area lock when forcing remote view
        _remoteUserLeft = false; // User joined, reset left state
        _lastRemoteActivityAt = DateTime.now(); // For mobile web "user left" timeout
        // Reset video muted state - assume camera is ON initially
        // The actual state will be updated via onRemoteVideoStateChanged callback
        _remoteVideoMuted = false;
        _remoteAudioMuted = false;
        _showVaAvatar = true; // PrepSkul VA "joins" when both participants are in the call
      });
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

      // One-time on-screen banner: "PrepSkul VA has joined" visible 5–8s for both users
      if (!_vaJoinNotificationShown && mounted) {
        _vaJoinNotificationShown = true;
        final isMobileWeb = kIsWeb && platform_utils.PlatformUtils.isMobileWeb;
        if (isMobileWeb) {
          // On mobile web, show banner in overlay (above controls) so it's clearly visible
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
      safeSetState(() {
        _errorMessage = _toUserFriendlyError(error);
        _sessionState = AgoraSessionState.error;
      });
    });

    // Remote video muted state - DEBOUNCED to prevent flickering, but short enough for responsive mute sync
    _remoteVideoMutedSubscription = _agoraService.remoteVideoMutedStream.listen((data) {
      final uid = data['uid'] as int;
      final muted = data['muted'] as bool;
      if (uid == _remoteUID) {
        safeSetState(() => _lastRemoteActivityAt = DateTime.now());
        // 250ms debounce: responsive to user mute/unmute, prevents rapid flicker from SDK events
        _videoStateDebounceTimer?.cancel();
        _videoStateDebounceTimer = Timer(const Duration(milliseconds: 250), () {
          if (mounted && uid == _remoteUID) {
            safeSetState(() {
              _remoteVideoMuted = muted;
            });
          }
        });
      }
    });

    // Remote audio muted state
    _remoteAudioMutedSubscription = _agoraService.remoteAudioMutedStream.listen((data) {
      final uid = data['uid'] as int;
      final muted = data['muted'] as bool;
      if (uid == _remoteUID) {
        safeSetState(() {
          _lastRemoteActivityAt = DateTime.now();
          _remoteAudioMuted = muted;
        });
      }
    });

    // Screen sharing state
    _screenSharingSubscription = _agoraService.screenSharingStream.listen((data) {
      final uid = data['uid'] as int;
      final sharing = data['sharing'] as bool;
      if (uid == _remoteUID) {
        safeSetState(() {
          _remoteIsScreenSharing = sharing;
        });
      } else if (uid == _agoraService.currentUID) {
        safeSetState(() {
          _isScreenSharing = sharing;
        });
      }
    });

    // User left
    _userLeftSubscription = _agoraService.userLeftStream.listen((uid) {
      if (uid == _remoteUID) {
        // On mobile web, never update state from userLeftStream (AgoraService already does not emit for mobile web; this is a second line of defense).
        if (kIsWeb && platform_utils.PlatformUtils.isMobileWeb) {
          LogService.info('Mobile web: ignoring userLeftStream (no-op) remoteUid=$uid');
          return;
        }
        final leftUid = _remoteUID;
        _remoteLeftCheckTimer?.cancel();
        _remoteLeftCheckTimer = null;
        safeSetState(() {
          _remoteUserLeft = true;
          _remoteUID = null;
          _remoteConnectionUnstable = false;
          _layout = VideoLayout.spotlight;
        });
        LogService.info('Remote marked left – source: userLeftStream (remoteUid=$leftUid)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Remote participant left (uid=$leftUid)', style: GoogleFonts.poppins(fontSize: 12)),
              backgroundColor: Colors.blueGrey.shade800,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
    
    // Remote network quality (for instability detection)
    _remoteNetworkQualitySubscription = _agoraService.remoteNetworkQualityStream.listen((data) {
      final uid = data['uid'] as int;
      final isUnstable = data['isUnstable'] as bool? ?? false;

      if (uid == _remoteUID) {
        safeSetState(() {
          _lastRemoteActivityAt = DateTime.now();
          _remoteConnectionUnstable = isUnstable;
        });
        
        if (isUnstable) {
          LogService.warning('⚠️ Remote user connection is unstable');
        } else {
          LogService.info('✅ Remote user connection is stable');
        }
      }
    });
    
    // Remote reactions
    _reactionSubscription = _agoraService.reactionStream.listen((data) {
      final uid = data['uid'] as int;
      final emoji = data['emoji'] as String;
      final myUid = _agoraService.currentUID ?? -1;
      // In 1:1 call, any reaction not from self is from the remote user - always show
      if (uid == myUid) return;
      // If _remoteUID not set (e.g. remote joined with camera/mic off), set it now
      if (_remoteUID == null) {
        safeSetState(() => _remoteUID = uid);
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
          _remoteScreenOff = screenOff;
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
      safeSetState(() {
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
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    }

    // Local connection state: Reconnecting… in status bar; brief "Connection restored" after rejoin
    _connectionStateSubscription = _agoraService.connectionStateStream.listen((state) {
      final reconnecting = state == agora_rtc_engine.ConnectionStateType.connectionStateReconnecting ||
          state == agora_rtc_engine.ConnectionStateType.connectionStateConnecting;
      final connected = state == agora_rtc_engine.ConnectionStateType.connectionStateConnected;
      safeSetState(() {
        if (connected && _localConnectionReconnecting) {
          _connectionRestoredAt = DateTime.now();
          // Clear "Connection restored" after a few seconds
          Future.delayed(_connectionRestoredDisplayDuration, () {
            if (mounted) safeSetState(() => _connectionRestoredAt = null);
          });
        }
        _localConnectionReconnecting = reconnecting;
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
  /// - All other sessions (regular, 1-hour trial) use AppConfig.sessionDurationMinutes
  /// 
  /// CRITICAL: Timer always starts from NOW (when both users join),
  /// not from any database start time. This ensures the timer shows
  /// exactly AppConfig.sessionDurationMinutes (e.g., 10 minutes).
  Future<void> _startSessionTimer() async {
    try {
      // Get duration from database ONLY to detect 30-minute trial sessions
      final session = await _supabase
          .from('individual_sessions')
          .select('duration_minutes')
          .eq('id', widget.sessionId)
          .maybeSingle();
      
      // Default to config duration (e.g., 10 minutes)
      int durationMinutes = AppConfig.sessionDurationMinutes;
      
      if (session != null) {
        // Check if this is a 30-minute trial session
        final dbDuration = session['duration_minutes'] as int?;
        if (dbDuration == 30) {
          // 30-minute trial sessions always use 30 minutes (constant)
          durationMinutes = 30;
          LogService.info('⏱️ 30-minute trial session detected - using fixed 30 minute duration');
        } else {
          // All other sessions use AppConfig.sessionDurationMinutes
          LogService.info('⏱️ Regular session - using config duration: ${AppConfig.sessionDurationMinutes} minutes');
        }
      }
      
      // CRITICAL: Always use DateTime.now() as start time
      // Timer starts NOW when both users have joined, not from database value
      // This ensures the timer shows exactly the configured duration
      await _timerService.startSession(
        widget.sessionId,
        startTime: DateTime.now(), // ALWAYS use current time
        durationMinutes: durationMinutes,
      );
      LogService.info('⏱️ Session timer started NOW with duration: $durationMinutes minutes');
    } catch (e) {
      LogService.warning('Error starting session timer: $e');
      // Even on error, try to start timer with defaults
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
        backgroundColor: error != null ? Colors.red.shade700 : Colors.blueGrey.shade800,
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
        backgroundColor: Colors.orange.shade700,
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
        await Future.delayed(const Duration(milliseconds: 2200));
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
      // Wait a moment for state to update
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check if we're actually disconnected
      final currentState = _agoraService.state;
      if (currentState != AgoraSessionState.disconnected && channelLeft) {
        LogService.warning('State not yet disconnected, waiting...');
        // Wait a bit more for state to update
        await Future.delayed(const Duration(milliseconds: 500));
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

      // CRITICAL: Step 4 - Final cleanup delay to ensure all resources are released
      // This gives time for any background cleanup to complete
      await Future.delayed(const Duration(milliseconds: 300));

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
          await Future.delayed(const Duration(milliseconds: 200));
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
              '/tutor-sessions',
              (route) => route.isFirst,
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
        backgroundColor: Colors.red,
      ),
    );
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
                      if (_layout == VideoLayout.spotlight && _sessionState == AgoraSessionState.connected) ...[
                        if (_remoteUserLeft) ...[
                _buildLocalProfileCard(),
                          _buildRemoteProfileCard(),
                        ],
                      ],
                      _buildStateMessages(),
                      _buildConnectionOverlay(),
                      ..._reactionAnimations,
                      if (_showReactionsPanel) _buildReactionsPanel(),
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
                      if (_errorMessage != null) _buildErrorOverlay(),
                      if (_sessionState == AgoraSessionState.joining) _buildLoadingOverlay(),
                      // On mobile web, status/control bar are rendered via OverlayEntry so they stay above Agora platform view.
                      // On other platforms, keep overlay as last child in Stack.
                      if (!kIsWeb || !platform_utils.PlatformUtils.isMobileWeb)
                        Positioned.fill(
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
                                  ],
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
    );
  }

  /// Build main video area - covers almost entire screen (no pure black; use soft neutral + placeholders).
  /// When joining, only a dark container is shown; the single "Connecting..." is in the overlay.
  Widget _buildMainVideoArea() {
    final engine = _agoraService.engine;
    final bool isMobileWeb = kIsWeb && platform_utils.PlatformUtils.isMobileWeb;
    final isJoining = _sessionState == AgoraSessionState.joining;
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
    // On mobile web specifically, we *always* keep the main area dedicated to the remote when a remote UID exists
    // so that tapping the local mute button never swaps the main canvas to the local preview.
    if (_remoteUID != null && !_remoteUserLeft) {
      if (_remoteVideoMuted || _remoteScreenOff) {
        return RepaintBoundary(
          child: Container(
            color: _kSoftDark,
            child: Center(child: _buildRemoteProfileCard()),
          ),
        );
      }
      final connection = _agoraService.currentConnection;
      return RepaintBoundary(
        child: _wrapWithSpeakingIndicator(
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
        ),
      );
    }

    // If remote user left: show just me (profile or video), no "waiting for" layer
    // Mobile web + local video muted recently: never show local in main; show remote (or profile) so overlay is never lost
    if (_remoteUserLeft) {
      final mobileWebLock = kIsWeb &&
          platform_utils.PlatformUtils.isMobileWeb &&
          _agoraService.didLocalUserMuteVideoRecently;
      final effectiveRemoteUid = _remoteUID ?? _lastRemoteUID;
      if (mobileWebLock && effectiveRemoteUid != null) {
        LogService.info(
          '📺 [UI] Main area MOBILE_WEB_LOCK: showing remote (uid=$effectiveRemoteUid) instead of local',
        );
        if (_remoteUID == effectiveRemoteUid && !_remoteVideoMuted && !_remoteScreenOff) {
          final connection = _agoraService.currentConnection;
          return RepaintBoundary(
            child: _wrapWithSpeakingIndicator(
              SizedBox.expand(
                key: ValueKey('remote_video_main_mobile_web_lock_$effectiveRemoteUid'),
                child: agora_widget.AgoraVideoViewWidget(
                  engine: engine,
                  uid: effectiveRemoteUid,
                  isLocal: false,
                  connection: connection,
                ),
              ),
              effectiveRemoteUid,
            ),
          );
        }
        return RepaintBoundary(
          child: Container(
            color: _kSoftDark,
            child: Center(child: _buildRemoteProfileCard(forceShowAsPresent: true)),
          ),
        );
      }
      LogService.info(
        '📺 [UI] Main area showing LOCAL (remote left): remoteUID=$_remoteUID, remoteUserLeft=$_remoteUserLeft, isVideoEnabled=$_isVideoEnabled',
      );
      if (_isVideoEnabled && _agoraService.currentUID != null && _localVideoReady) {
        return _wrapWithSpeakingIndicator(
          SizedBox.expand(
            key: ValueKey('local_video_alone_${_agoraService.currentUID}'),
            child: agora_widget.AgoraVideoViewWidget(
              engine: engine,
              uid: _agoraService.currentUID!,
              isLocal: true,
              connection: _agoraService.currentConnection,
            ),
          ),
          _agoraService.currentUID,
        );
      }
      return Container(
        color: _kSoftDark,
        child: Center(child: _buildLocalProfileCard()),
      );
    }

    // When alone: show self (video or profile) WITH "waiting for" overlay
    if (_remoteUID == null && _sessionState == AgoraSessionState.connected) {
      LogService.info(
        '📺 [UI] Main area showing LOCAL (waiting for remote): remoteUID=null, remoteUserLeft=$_remoteUserLeft, isVideoEnabled=$_isVideoEnabled',
      );
      final waitingFor = widget.userRole == 'tutor' ? 'learner' : 'tutor';
      
      if (_isVideoEnabled && _agoraService.currentUID != null && _localVideoReady) {
        // Show local video with waiting overlay
        return Stack(
          fit: StackFit.expand,
          children: [
            // Local video as background - use stable key to prevent recreation
            _wrapWithSpeakingIndicator(
              SizedBox.expand(
                key: ValueKey('local_video_waiting_${_agoraService.currentUID}'),
                child: agora_widget.AgoraVideoViewWidget(
                  engine: engine,
                  uid: _agoraService.currentUID!,
                  isLocal: true,
                  connection: _agoraService.currentConnection,
                ),
              ),
              _agoraService.currentUID,
            ),
            // Waiting overlay at bottom
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: _AnimatedWaitingText(waitingFor: waitingFor),
              ),
            ),
          ],
        );
      } else if (_isVideoEnabled && !_localVideoReady) {
        // Video enabled but not ready yet - show loading
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: _kSoftDark,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            ),
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: _AnimatedWaitingText(waitingFor: waitingFor),
              ),
            ),
          ],
        );
      }
      // Camera off - show profile card with waiting message
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: _kSoftDark,
            child: Center(child: _buildLocalProfileCard()),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: _AnimatedWaitingText(waitingFor: waitingFor),
            ),
          ),
        ],
      );
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
      if (_remoteVideoMuted || _remoteScreenOff) {
        return Container(
          color: _kSoftDark,
          child: Center(child: _buildRemoteProfileCard()),
        );
      }
      final connection = _agoraService.currentConnection;
      return _wrapWithSpeakingIndicator(
        SizedBox.expand(
          key: ValueKey('remote_video_sidebyside_${_remoteUID}_camera'),
          child: agora_widget.AgoraVideoViewWidget(
            engine: engine,
            uid: _remoteUID,
            isLocal: false,
            connection: connection,
          ),
        ),
        _remoteUID,
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
    if (_isVideoEnabled) {
      return _wrapWithSpeakingIndicator(
        SizedBox.expand(
          child: agora_widget.AgoraVideoViewWidget(
            engine: engine,
            uid: _agoraService.currentUID!,
            isLocal: true,
            connection: _agoraService.currentConnection,
          ),
        ),
        _agoraService.currentUID,
      );
    }
    return Container(
      color: _kSoftDark,
      child: Center(
        child: _buildLocalProfileCard(),
      ),
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
    if (!forceShowAsPresent && !_remoteUserLeft && !_remoteVideoMuted && !_remoteScreenOff) {
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
          const SizedBox(height: 8),
          Text(
            'Waiting for $waitingFor...',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
          ),
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

    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Remote video muted
          if (_remoteVideoMuted && _remoteUID != null)
            widget.userRole == 'tutor'
                ? SessionStateMessages.learnerCameraOff()
                : SessionStateMessages.tutorCameraOff(),
          // Remote audio muted
          if (_remoteAudioMuted && _remoteUID != null)
            widget.userRole == 'tutor'
                ? SessionStateMessages.learnerMicMuted()
                : SessionStateMessages.tutorMicMuted(),
          // Remote connection issues (show before user left confirmation)
          // Show "reconnecting" or "poor connection" when unstable but user hasn't left yet
          if (_remoteConnectionUnstable && _remoteUID != null && !_remoteUserLeft)
            widget.userRole == 'tutor'
                ? SessionStateMessages.learnerReconnecting()
                : SessionStateMessages.tutorReconnecting(),
          // Remote user left (only show after grace period confirms they're gone)
          if (_remoteUserLeft)
            widget.userRole == 'tutor' 
                ? SessionStateMessages.learnerLeft()
                : SessionStateMessages.tutorLeft(),
        ],
      ),
    );
  }

  /// Build status bar (Meet/Zoom-style: clean gradient, connection pill, timer, quality)
  Widget _buildStatusBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.55),
              Colors.black.withOpacity(0.2),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left side: Connection status and timer
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Connection status: Reconnecting… / Connection restored / Connected
                if (_sessionState.isActive) _buildConnectionStatusPill(),
                // Connection quality (Good / Fair / Poor)
                if (_sessionState.isActive) ...[
                  const SizedBox(width: 12),
                  _buildConnectionQualityChip(),
                ],
                // Session timer
                if (_sessionState.isActive && _timeRemaining != null) ...[
                  const SizedBox(width: 12),
                  _buildTimerDisplay(),
                ],
              ],
            ),
            // Right side: Layout toggle only when there is a remote user (no split when alone)
            if (_sessionState.isActive && _remoteUID != null)
            Material(
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
          ],
        ),
      ),
    );
  }

  /// Status bar pill: "Reconnecting…", "Connection restored", or "Connected"
  Widget _buildConnectionStatusPill() {
    final showRestored = _connectionRestoredAt != null &&
        DateTime.now().difference(_connectionRestoredAt!) < _connectionRestoredDisplayDuration;
    final String label;
    final Color bgColor;
    if (_localConnectionReconnecting) {
      label = 'Reconnecting…';
      bgColor = Colors.orange.shade700;
    } else if (showRestored) {
      label = 'Connection restored';
      bgColor = Colors.green.shade700;
    } else {
      label = 'Connected';
      bgColor = AppTheme.primaryColor;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor, bgColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_localConnectionReconnecting)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          if (!_localConnectionReconnecting) const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Connection quality chip (Good / Fair / Poor) in status bar
  Widget _buildConnectionQualityChip() {
    final quality = _remoteConnectionUnstable
        ? 'Poor'
        : _capitalize(ConnectionQualityService.getBestQuality());
    final color = quality == 'Good'
        ? Colors.green
        : quality == 'Fair'
            ? Colors.orange
            : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.signal_cellular_alt, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            quality,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
  
  /// Build timer display widget
  Widget _buildTimerDisplay() {
    if (_timeRemaining == null) {
      return const SizedBox.shrink();
    }
    
    final remaining = _timeRemaining!;
    final isLowTime = remaining.inMinutes < 5; // Show warning when less than 5 minutes
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLowTime 
              ? [
                  AppTheme.accentOrange,
                  AppTheme.accentOrange.withOpacity(0.8),
                ]
              : [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.8),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isLowTime ? AppTheme.accentOrange : AppTheme.primaryColor).withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            SessionTimerService.formatDuration(remaining),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          // Opaque bottom ensures controls stay visible on mobile web (no transparency)
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.95),
              Colors.black.withOpacity(0.85),
              Colors.black.withOpacity(0.5),
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: _isAudioEnabled ? Icons.mic : Icons.mic_off,
                label: _isAudioEnabled ? 'Mute' : 'Unmute',
                onPressed: _sessionState == AgoraSessionState.joining ? () {} : _toggleAudio,
                isActive: _isAudioEnabled,
                showMutedIndicator: !_isAudioEnabled,
                showSpeakingWave: _isAudioEnabled &&
                    _agoraService.currentUID != null &&
                    _speakingUids.contains(_agoraService.currentUID),
                enabled: _sessionState != AgoraSessionState.joining,
              ),
              const SizedBox(width: 12),
              _buildControlButton(
                icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                label: _isVideoEnabled ? 'Camera Off' : 'Camera On',
                onPressed: _sessionState == AgoraSessionState.joining ? () {} : _toggleVideo,
                isActive: _isVideoEnabled,
                showMutedIndicator: !_isVideoEnabled,
                enabled: _sessionState != AgoraSessionState.joining,
              ),
              const SizedBox(width: 12),
              _buildControlButton(
                icon: Icons.emoji_emotions,
                label: 'Reactions',
                onPressed: _sessionState == AgoraSessionState.joining
                    ? () {}
                    : () {
                        if (mounted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) safeSetState(() {
                              _showReactionsPanel = !_showReactionsPanel;
                            });
                          });
                        }
                      },
                isActive: _showReactionsPanel,
                enabled: _sessionState != AgoraSessionState.joining,
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
    );
  }

  /// Build screen share button (hidden on mobile web via caller).
  /// Android web supports getDisplayMedia; iOS Safari does not.
  Widget _buildScreenShareButton() {
    return _buildControlButton(
      icon: Icons.screen_share,
      label: _isScreenSharing ? 'Stop Sharing' : 'Share Screen',
      onPressed: _sessionState == AgoraSessionState.joining ? () {} : _toggleScreenSharing,
      isActive: _isScreenSharing,
      enabled: _sessionState != AgoraSessionState.joining,
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
    bool isDanger = false,
    bool showMutedIndicator = false,
    bool showSpeakingWave = false,
    bool enabled = true,
  }) {
    final content = Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
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
    if (msg.contains('permission') || msg.contains('Permission') || msg.contains('NotAllowedError') || msg.contains('NotAllowed')) {
      return 'Camera and microphone access is required. Please allow access in your browser settings and refresh the page.';
    }
    return 'Connection failed. Please check your internet and try again.';
  }

  /// Build error overlay
  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _errorMessage != null && (_errorMessage!.contains('network') || _errorMessage!.contains('connection') || _errorMessage!.contains('internet'))
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline,
                color: _errorMessage != null && _errorMessage!.contains('Session expired')
                    ? Colors.orange
                    : Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage != null && _errorMessage!.contains('Session expired')
                    ? 'Session Expired'
                    : _errorMessage != null && (_errorMessage!.contains('network') || _errorMessage!.contains('connection') || _errorMessage!.contains('internet') || _errorMessage!.contains('Poor'))
                        ? 'Connection Issue'
                        : 'Error',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Something went wrong. Please try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  safeSetState(() {
                    _errorMessage = null;
                    if (_sessionState == AgoraSessionState.error) {
                      _sessionState = AgoraSessionState.connected;
                    }
                  });
                  _agoraService.tryRecoverCamera();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
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
  final String waitingFor;
  
  const _AnimatedWaitingText({required this.waitingFor});
  
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
            'Waiting for ${widget.waitingFor} to join$dots',
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

/// Animated "Reconnecting..." overlay – same style as _AnimatedWaitingText (pulsing pill)
class _AnimatedReconnectingOverlay extends StatefulWidget {
  const _AnimatedReconnectingOverlay();

  @override
  State<_AnimatedReconnectingOverlay> createState() => _AnimatedReconnectingOverlayState();
}

class _AnimatedReconnectingOverlayState extends State<_AnimatedReconnectingOverlay>
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5 + (_controller.value * 0.2)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orange.shade300,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Connection unstable – reconnecting$dots',
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.8 + (_controller.value * 0.2)),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

