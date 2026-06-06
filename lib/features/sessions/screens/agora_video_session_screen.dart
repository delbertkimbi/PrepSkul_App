import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, kDebugMode, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/camera_mic_permission_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/whatsapp_support_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/utils/status_bar_utils.dart';
import 'package:prepskul/core/services/connectivity_service.dart';
import 'package:prepskul/core/widgets/offline_dialog.dart';
import 'package:prepskul/features/sessions/services/agora_service.dart';
import 'package:prepskul/features/sessions/services/session_profile_service.dart';
import 'package:prepskul/features/sessions/services/incall_chat_realtime.dart';
import 'package:prepskul/features/sessions/services/lesson_waiting_ping_service.dart';
import 'package:prepskul/features/sessions/models/agora_session_state.dart';
import 'package:prepskul/features/sessions/widgets/agora_video_view.dart'
    as agora_widget;
import 'package:prepskul/features/sessions/widgets/local_video_pip.dart';
import 'package:prepskul/features/sessions/widgets/classroom_workspace_indexed_stack.dart';
import 'package:prepskul/features/sessions/widgets/session_connection_help_sheet.dart';
import 'package:prepskul/features/sessions/widgets/session_in_call_info_sheet.dart';
import 'package:prepskul/features/sessions/widgets/call_status_banner.dart';
import 'package:prepskul/features/sessions/widgets/prepskul_va_avatar.dart';
import 'package:prepskul/features/sessions/widgets/classroom_offline_banner.dart';
import 'package:prepskul/features/sessions/widgets/reactions_panel.dart';
import 'package:prepskul/features/sessions/widgets/reaction_animation.dart';
import 'package:prepskul/features/sessions/widgets/incall_chat_panel.dart';
import 'package:prepskul/features/booking/services/session_lifecycle_service.dart';
import 'package:prepskul/features/sessions/services/agora_recording_service.dart';
import 'package:prepskul/features/sessions/services/session_timer_service.dart';
import 'package:prepskul/features/sessions/services/call_pip_controller.dart';
import 'package:prepskul/features/sessions/services/session_heartbeat_service.dart';
import 'package:prepskul/features/sessions/services/workspace_realtime_sync.dart';
import 'package:prepskul/features/sessions/services/qoe_telemetry_service.dart';
import 'package:prepskul/features/sessions/domain/workspace_sync_state.dart';
import 'package:prepskul/features/sessions/domain/participant_state.dart';
import 'package:prepskul/features/sessions/domain/gallery_grid_layout.dart';
import 'package:prepskul/features/sessions/domain/agora_session_uid.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora_rtc_engine;
import 'package:prepskul/core/utils/platform_utils_stub.dart'
    if (dart.library.html) 'package:prepskul/core/utils/platform_utils_web.dart'
    as platform_utils;
import 'dart:math' show max, min;
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'package:url_launcher/url_launcher.dart';

/// Deep blue for video/connecting/leaving/waiting – consistent with app theme.
const Color _kSoftDark = Color(0xFF0F1A2E); // AppTheme.primaryDark

/// Stable saturated fills for gallery “camera off” tiles (Discord-style variety).
const List<Color> _kGalleryDiscordBackdrops = <Color>[
  Color(0xFFE91E63),
  Color(0xFF00C853),
  Color(0xFF7E57C2),
  Color(0xFF039BE5),
  Color(0xFFFF6D00),
  Color(0xFF546E7A),
  Color(0xFFD81B60),
  Color(0xFF00897B),
  Color(0xFF5C6BC0),
  Color(0xFFFDD835),
  Color(0xFF8D6E63),
  Color(0xFFE040FB),
];

Color _galleryDiscordBackdropForUid(int uid) =>
    _kGalleryDiscordBackdrops[uid.abs() % _kGalleryDiscordBackdrops.length];

String _galleryAvatarInitials(String name) {
  if (name.isEmpty) return '?';
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return parts[0][0].toUpperCase();
}

const Color _kGlassFill = Color(0x33141F36);
const Color _kGlassBorder = Color(0x66FFFFFF);

/// Meet-like chrome for solo-waiting card + local PiP (shared radius / border weight).
const double _kClassroomTileBorderRadius = 18;
Color get _kClassroomChromeBorder => Colors.white.withOpacity(0.14);

/// Reserve space for the bottom glass control bar so overlays (e.g. in-call chat) sit above it.
double _kCallControlBarReserveHeight(MediaQueryData mq) {
  final isShort = mq.size.height < 760;
  final isNarrow = mq.size.width < 390;
  final verticalPadding = isShort ? 8.0 : 14.0;
  final buttonSize = isNarrow ? 52.0 : 56.0;
  return verticalPadding * 2 + buttonSize + mq.padding.bottom;
}

/// Show draggable participant strip below this width (phones / narrow layouts).
const double _kParticipantStripBreakpointWidth = 600;

/// Layout mode for video call.
/// - spotlight: main speaker + local PIP
/// - sideBySide: split 1:1 view
/// - gallery: scrollable adaptive grid for multi-user rooms
enum VideoLayout { spotlight, sideBySide, gallery }

/// Preply-style presenter geometry while screen share dominates the RTC stage — v1: one split preset.
///
/// Narrow lanes use a slimmer companion rail width; [_kScreenShareCompanionSidebarBreakpoint]
/// only affects sidebar width fraction (not whether a rail is shown).
/// otherwise **cameras beside share** collapses to a **corner bubble** overlay.
enum ScreenShareLayoutPreset { stageOnly, shareWithCompanionCameras }

/// Enable sideways gallery pages when tile count (you + remotes) reaches this.
const int _kGalleryPagingMinTiles = 13;

/// Maximum tiles per gallery page before swiping horizontally.
const int _kGalleryTilesPerPage = 12;

/// Side-by-side **video lane + teaching workspace** when width allows; below this
/// threshold the shell stacks video above workspace (still dual-pane, not overlapping).
const double _kClassroomDualPaneMinWidth = 840;

/// Fixed width of the learner in-call chat column (Meet-style); keep in sync with layout offsets.
const double _kLearnerIncallChatRailWidth = 340;

/// Floating in-call chat overlay on wide viewports: keep video visible at the sides.
const double _kIncallChatOverlayMaxWidth = 520;

/// Space below system inset for timer/status strip + top-right action cluster.
double _kCallTopChromeReserveHeight(MediaQueryData mq) => mq.padding.top + 64;

/// Tutor lane: icon-only tool switches below this width; labeled **Board / Materials / Notes** at or above.
const double _kWorkspaceTutorToolLabelBreakWidth = 420;

/// **Share + companion cameras**: use a sidebar rail vs corner bubble breakpoint (video lane width).
const double _kScreenShareCompanionSidebarBreakpoint = 560;
const double _kScreenShareSidebarWidthCap = 280;
const double _kScreenShareSidebarWidthFractionOfLane = 0.30;

/// Below this width, put screen share in More. Keep this moderate so laptops/tablets still
/// get Share inline next to Camera (users expect it on dual-pane desktops).
const double _kControlBarCompactWidth = 460;

/// Use a Meet-style modal bottom sheet for in-call "More" (vs anchored popup) on phone-sized viewports.
const double _kMeetStyleMoreSheetMaxShortestSide = 600;

const String _kInCallMoreTeachingTools = 'more_teaching_tools';
const String _kInCallMoreReactions = 'more_reactions';
const String _kInCallMoreScreenShare = 'more_screen_share';
const String _kInCallMoreConnectionHelp = 'more_connection_help';
const String _kInCallMoreInCallMessages = 'more_incall_messages';
const String _kInCallMoreLessonInfo = 'more_lesson_info';
const String _kInCallMoreInviteLearner = 'more_invite_learner';
const String _kInCallMoreTalkTime = 'more_talk_time';
const String _kInCallMoreReportIssue = 'more_report_issue';
const String _kInCallMorePrepSkulAssist = 'more_prepskul_assist';
const String _kInCallMoreConnectionQuality = 'more_connection_quality';
const String _kHandRaiseOnSignal = '__hand_raise_on__';
const String _kHandRaiseOffSignal = '__hand_raise_off__';

List<List<int>> _chunkGalleryTiles(List<int> tiles, int pageSize) {
  if (tiles.isEmpty) return <List<int>>[];
  final pages = <List<int>>[];
  for (var i = 0; i < tiles.length; i += pageSize) {
    pages.add(tiles.sublist(i, min(i + pageSize, tiles.length)));
  }
  return pages;
}

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
  State<AgoraVideoSessionScreen> createState() =>
      _AgoraVideoSessionScreenState();
}

class _AgoraVideoSessionScreenState extends State<AgoraVideoSessionScreen>
    with WidgetsBindingObserver {
  final AgoraService _agoraService = AgoraService();
  final _supabase = SupabaseService.client;
  final SessionProfileService _profileService = SessionProfileService();

  /// Start [joining] so the first frames never paint the full in-call chrome as if connected.
  /// Spurious stream [disconnected] events during bootstrap are ignored while still joining.
  AgoraSessionState _sessionState = AgoraSessionState.joining;
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

  /// Show at most one subtle degradation hint after connection issues persist this long.
  static const Duration _kSustainedDegradationThreshold = Duration(seconds: 5);
  Timer? _degradationSustainTimer;
  DateTime? _degradationStartedAt;
  bool _sustainedCallDegradation = false;
  bool _isScreenSharing = false;
  bool _remoteIsScreenSharing = false;
  int? _screenShareOwnerUid;
  bool _remoteUserLeft = false;

  /// True when a non-local participant owns the screen track.
  bool get _activeRemoteScreenShare {
    final owner = _screenShareOwnerUid ?? _agoraService.screenShareOwnerUid;
    final me = _agoraService.currentUID;
    return owner != null && me != null && owner != me;
  }

  /// Local presenter OR any remote screen capture — use for layout and main stage.
  /// Includes [AgoraService.isPublishingScreen] so UI tracks capture during signal/engine races.
  bool get _anyScreenShareActive =>
      _activeRemoteScreenShare ||
      _isScreenSharing ||
      _agoraService.isPublishingScreen;

  /// This device is actively capturing or publishing a screen track (toolbar / dock / chrome).
  bool get _localScreenShareCapturing =>
      _isScreenSharing || _agoraService.isPublishingScreen;

  bool _screenShareSharerMarkedGone(int sharingUid) {
    final p = _participants[sharingUid];
    if (p != null) return p.userLeft;
    return sharingUid == _remoteUID && _remoteUserLeft;
  }

  /// On Flutter web, [RtcEngine.setupLocalVideo] only binds one surface. The
  /// screen-share stage uses `videoSourceScreen`; any other local widget that
  /// calls `setupLocalVideo` with the camera overwrites it and the main share
  /// view stays empty (soft-dark background).
  bool get _webSecondLocalCameraPreviewBreaksScreenShare =>
      kIsWeb && _localScreenShareCapturing;

  /// Cached remote UID for mobile web main-area lock when we force remote view (never clear on mobile web when ignoring "user left").
  int? _lastRemoteUID;

  // Profile data
  Map<String, dynamic>? _localProfile;
  Map<String, dynamic>? _remoteProfile;
  SessionBookingSummary? _sessionBookingSummary;
  SessionParticipantBundle? _sessionParticipantBundle;
  String? _sessionLocalSupabaseUserId;

  // Reactions
  bool _showReactionsPanel = false;
  final List<Widget> _reactionAnimations = [];
  final Set<int> _raisedHandUids = <int>{};
  bool _localHandRaised = false;
  bool _remoteHandRaised = false;

  IncallChatRealtime? _incallChat;
  bool _inCallChatOpen = false;
  bool _lessonWaitingPingSending = false;
  DateTime? _lastLessonWaitingPingAt;

  /// Drives live countdown text after a waiting-room reminder ping.
  Timer? _lessonPingCooldownTicker;

  /// Solo spotlight waiting: PiP "expand" shows local video full-bleed until dismissed.
  bool _soloWaitingSelfExpanded = false;

  /// Draggable in-call participant chip (narrow layouts).
  Offset _participantStripDrag = Offset.zero;
  String _joinOverlayDetail = 'Securing access and connecting to the lesson…';
  static const Duration _lessonPingClientCooldown = Duration(minutes: 4);

  // Layout mode for call surface.
  VideoLayout _layout = VideoLayout.spotlight;
  ScreenShareLayoutPreset _screenShareLayoutPreset =
      ScreenShareLayoutPreset.shareWithCompanionCameras;
  int? _pinnedParticipantUid;
  int _lastAppliedRemoteCountForLayout = -1;

  final PageController _galleryPageController = PageController();

  VideoLayout _previousLayoutForPaging = VideoLayout.spotlight;

  int _galleryPageIndex = 0;

  // PrepSkul VA (Virtual Assistant) - UI-only monitoring indicator
  bool _vaJoinNotificationShown = false;

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
  StreamSubscription<void>? _mutedMicSpeechHintSubscription;
  double _inCallMicWaveVisualLevel = 0;
  DateTime _inCallMicWaveHoldUntil = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription<agora_rtc_engine.ConnectionStateType>?
  _connectionStateSubscription;
  StreamSubscription<String>? _recordingFailedSubscription;
  StreamSubscription<WorkspaceViewState>? _workspaceStateSubscription;
  StreamSubscription<WorkspaceSyncIssueKind>? _workspaceSyncIssueSubscription;
  DateTime? _lastWorkspaceSyncReconnectAt;
  StreamSubscription<String>? _peerLeftHeartbeatSubscription;
  StreamSubscription<String>? _peerBeatHeartbeatSubscription;
  StreamSubscription<void>? _localCameraPublishingSubscription;

  /// One-time “audio only” offer if the local camera never reaches Agora capturing/encoding.
  Timer? _audioOnlyFallbackTimer;
  bool _audioOnlyFallbackOffered = false;
  static const Duration _kAudioOnlyFallbackGrace = Duration(seconds: 18);

  /// Tutor ↔ learner workspace packets (PDF/board tool indices, scroll hints).
  WorkspaceRealtimeSync? _workspaceRealtime;

  /// UIDs currently speaking (from Agora volume indication) for talking indicator.
  Set<int> _speakingUids = {};

  // Network instability tracking
  bool _remoteConnectionUnstable = false;
  bool _localConnectionReconnecting = false;
  DateTime? _localReconnectingShownAt;
  Timer? _localReconnectClearTimer;
  static const Duration _minReconnectIndicatorDisplay = Duration(seconds: 2);

  /// In-call offline UX: surfaced after connectivity loss or stuck reconnect (~no network).
  final ConnectivityService _connectivity = ConnectivityService();
  StreamSubscription<bool>? _callConnectivitySubscription;
  Timer? _connectivityOfflineDebounce;
  Timer? _joinStuckOfflineProbeTimer;
  Timer? _reconnectStuckOfflineProbeTimer;
  bool _inCallOfflineDialogOpen = false;
  bool _inCallOfflineCardOpen = false;
  bool _callConnectivityOnline = true;
  DateTime? _lastLifecycleResumedAt;
  bool _soloPipDragHintShown = false;
  bool _isTearingDownUi = false;
  bool _explicitCallCleanupDone = false;
  static const Duration _kConnectivityOfflineDebounce = Duration(
    milliseconds: 900,
  );
  static const Duration _kJoinStuckProbe = Duration(seconds: 22);
  static const Duration _kReconnectStuckProbe = Duration(seconds: 10);
  static const Duration _kResumeReconnectGrace = Duration(seconds: 8);

  // Screen-off tracking
  bool _remoteScreenOff = false;
  DateTime? _remoteUnstableStickyUntil;
  Timer? _remoteUnstableTimer;

  // Session timer
  final SessionTimerService _timerService = SessionTimerService();
  Duration? _timeRemaining;
  StreamSubscription<Duration>? _timeRemainingSubscription;
  StreamSubscription<String>? _sessionEndedSubscription;
  bool _timerStarted =
      false; // Ensure timer starts only once (when both users are in)
  bool _isEndingCall = false;

  /// When true, body is plain black so nothing (no profile, no "Waiting for tutor...") shows behind the "Leaving..." dialog.
  bool _showLeavingScreen = false;

  /// True when mic/camera/share and similar should respond — only once the channel is up.
  bool get _controlsEnabled =>
      (_sessionState == AgoraSessionState.connected ||
          _sessionState == AgoraSessionState.reconnecting) &&
      (!kIsWeb || _agoraService.engine != null);

  /// Local screen capture (dock / overflow). Tutors always; learners only if explicitly enabled.
  bool get _canStartScreenShareFromThisDevice =>
      widget.userRole == 'tutor' || AppConfig.enableLearnerScreenShare;

  // Local video ready flag - ensures video is set up before rendering
  bool _localVideoReady = false;

  // Debounce timer for video state changes (prevents flickering)
  Timer? _videoStateDebounceTimer;

  /// When frame-ready (ready=true) last received; used to ignore stale debounced muted callbacks.
  DateTime? _lastRemoteVideoReadyAt;
  DateTime? _lastMainAreaDiagnosticAt;
  DateTime? _lastWaitingLocalMainAreaLogAt;
  DateTime? _lastMutedMicHintUiAt;
  static const Duration _mutedMicHintUiCooldown = Duration(seconds: 28);

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
  Timer? _recoveryHealthTimer;
  DateTime? _lastWorkspacePacketAt;
  bool _showRecoveryBanner = false;
  String _recoveryReason = '';
  DateTime? _recoveryUnstableObservedAt;
  bool _recoveryActionsOpenedOnce = false;
  DateTime? _recoveryModeEnteredAt;
  String? _recoveryQoeCorrelationId;

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
      _syncDualStreamPinWithLayout();
      _onLayoutTransitionGalleryPagingAfterBatch();
      _syncGalleryPagingVideoAfterMutationBatch();
      _syncDegradationTrackingAfterMutation();
    });
  }

  /// Quiet UX: transient reconnect/network flags are silent until they persist;
  /// then at most one subtle banner chip is shown (via [_sustainedCallDegradation]).
  void _syncDegradationTrackingAfterMutation() {
    final degrading = _localConnectionReconnecting || _remoteConnectionUnstable;
    if (!degrading) {
      _degradationSustainTimer?.cancel();
      _degradationSustainTimer = null;
      _degradationStartedAt = null;
      if (_sustainedCallDegradation) {
        safeSetState(() => _sustainedCallDegradation = false);
      }
      return;
    }

    final now = DateTime.now();
    _degradationStartedAt ??= now;
    final elapsed = now.difference(_degradationStartedAt!);

    if (elapsed >= _kSustainedDegradationThreshold) {
      _degradationSustainTimer?.cancel();
      _degradationSustainTimer = null;
      if (!_sustainedCallDegradation) {
        safeSetState(() => _sustainedCallDegradation = true);
      }
      return;
    }

    _degradationSustainTimer?.cancel();
    final remaining = _kSustainedDegradationThreshold - elapsed;
    _degradationSustainTimer = Timer(remaining, () {
      if (!mounted) return;
      if (_localConnectionReconnecting || _remoteConnectionUnstable) {
        safeSetState(() => _sustainedCallDegradation = true);
      }
    });
  }

  ParticipantState? get _currentRemoteParticipant {
    final uid = _remoteUID;
    if (uid == null) return null;
    return _participants[uid];
  }

  List<int> _galleryRemoteUids() {
    final remoteUids = _participants.entries
        .where((e) => !e.value.userLeft)
        .map((e) => e.key)
        .toSet();
    if (_remoteUID != null && !_remoteUserLeft) {
      remoteUids.add(_remoteUID!);
    }
    return remoteUids.toList();
  }

  List<int> _sortedGalleryUids() {
    final remoteUids = _galleryRemoteUids();
    remoteUids.sort((a, b) {
      final aPinned = _pinnedParticipantUid == a ? 1 : 0;
      final bPinned = _pinnedParticipantUid == b ? 1 : 0;
      if (aPinned != bPinned) return bPinned.compareTo(aPinned);

      final aSpeaking = _speakingUids.contains(a) ? 1 : 0;
      final bSpeaking = _speakingUids.contains(b) ? 1 : 0;
      if (aSpeaking != bSpeaking) return bSpeaking.compareTo(aSpeaking);

      final aActivity = _participants[a]?.lastActivityAt;
      final bActivity = _participants[b]?.lastActivityAt;
      if (aActivity != null && bActivity != null)
        return bActivity.compareTo(aActivity);
      if (aActivity != null) return -1;
      if (bActivity != null) return 1;
      return a.compareTo(b);
    });
    return remoteUids;
  }

  List<int> _sortedActiveRemoteParticipantsFromRegistry() {
    final remoteUids = _participants.entries
        .where((e) => !e.value.userLeft)
        .map((e) => e.key)
        .toList();
    remoteUids.sort((a, b) {
      final aPinned = _pinnedParticipantUid == a ? 1 : 0;
      final bPinned = _pinnedParticipantUid == b ? 1 : 0;
      if (aPinned != bPinned) return bPinned.compareTo(aPinned);

      final aSpeaking = _speakingUids.contains(a) ? 1 : 0;
      final bSpeaking = _speakingUids.contains(b) ? 1 : 0;
      if (aSpeaking != bSpeaking) return bSpeaking.compareTo(aSpeaking);

      final aActivity = _participants[a]?.lastActivityAt;
      final bActivity = _participants[b]?.lastActivityAt;
      if (aActivity != null && bActivity != null) {
        return bActivity.compareTo(aActivity);
      }
      if (aActivity != null) return -1;
      if (bActivity != null) return 1;
      return a.compareTo(b);
    });
    return remoteUids;
  }

  /// Resolves who is publishing the screen track (prefer Agora `[ownerUid]` when present).
  int? _resolvedScreenSharePublisherUid() {
    final owner = _screenShareOwnerUid;
    final cur = _agoraService.currentUID;
    final activeRemotes = _sortedActiveRemoteParticipantsFromRegistry();

    if (_localScreenShareCapturing && cur != null) {
      return owner ?? cur;
    }
    if (_activeRemoteScreenShare) {
      if (owner != null && activeRemotes.contains(owner)) {
        return owner;
      }
      if (_remoteUID != null &&
          !_remoteUserLeft &&
          activeRemotes.contains(_remoteUID!)) {
        return _remoteUID;
      }
      if (activeRemotes.isNotEmpty) {
        final screenSharers =
            activeRemotes
                .where((u) => _participants[u]?.screenSharing == true)
                .toList(growable: false);
        if (screenSharers.isNotEmpty) return screenSharers.first;
      }
      return owner;
    }
    return owner ?? cur;
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
    if (_pinnedParticipantUid == uid) {
      _pinnedParticipantUid = null;
    }
  }

  /// Dual-stream HIGH follows gallery pin + speaker; cleared outside gallery layout.
  void _syncDualStreamPinWithLayout() {
    if (_layout != VideoLayout.gallery) {
      _agoraService.setDualStreamPinnedRemoteUid(null);
    } else {
      _agoraService.setDualStreamPinnedRemoteUid(_pinnedParticipantUid);
    }
  }

  void _applyGalleryPagingOnLayoutChanged(
    VideoLayout before,
    VideoLayout after,
  ) {
    if (before == VideoLayout.gallery && after != VideoLayout.gallery) {
      unawaited(_agoraService.clearGalleryPagingVideoSubscriptions());
      _galleryPageIndex = 0;
    }
    if (before != VideoLayout.gallery && after == VideoLayout.gallery) {
      _galleryPageIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_galleryPageController.hasClients) {
          _galleryPageController.jumpToPage(0);
        }
        _syncGalleryPagingVideoAfterMutationBatch();
      });
    }
  }

  void _onLayoutTransitionGalleryPagingAfterBatch() {
    _applyGalleryPagingOnLayoutChanged(_previousLayoutForPaging, _layout);
    _previousLayoutForPaging = _layout;
  }

  void _syncGalleryPagingVideoAfterMutationBatch() {
    if (_layout != VideoLayout.gallery) return;
    final localUid = _agoraService.currentUID;
    if (localUid == null) return;
    final tileUids = <int>[localUid, ..._sortedGalleryUids()];
    if (tileUids.length < _kGalleryPagingMinTiles) {
      unawaited(_agoraService.clearGalleryPagingVideoSubscriptions());
      return;
    }
    final chunks = _chunkGalleryTiles(tileUids, _kGalleryTilesPerPage);
    if (chunks.isEmpty) return;
    var idx = min(_galleryPageIndex, chunks.length - 1);
    if (idx < 0) {
      idx = 0;
    }
    if (idx != _galleryPageIndex && mounted) {
      safeSetState(() => _galleryPageIndex = idx);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_galleryPageController.hasClients) {
          _galleryPageController.jumpToPage(idx);
        }
      });
    }
    final visibleRemotes = chunks[idx].where((u) => u != localUid).toSet();
    unawaited(
      _agoraService.syncGalleryVisibleRemoteVideoSubscriptions(visibleRemotes),
    );
  }

  void _syncLegacyRemoteStateFromRegistry() {
    final p = _currentRemoteParticipant;
    if (p == null) {
      _remoteVideoMuted = false;
      _remoteAudioMuted = false;
      _remoteVideoReady = false;
      _remoteIsScreenSharing = false;
      // `_remoteUserLeft` is driven by concrete join/leave + multiparty arbitration;
      // do not force false here (that undoes "participant left" when `_remoteUID` is cleared).
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

  /// Maps Supabase auth id from [SessionHeartbeatService] to the deterministic Agora UID.
  int? _agoraUidForSupabaseHeartbeatPeer(String peerSupabaseUserId) {
    final bundle = _sessionParticipantBundle;
    final sid = widget.sessionId;
    if (bundle != null) {
      final tid = bundle.tutorUserId;
      if (tid != null && tid == peerSupabaseUserId) {
        return agoraNumericUidForSessionRole(
          sessionId: sid,
          userId: tid,
          role: 'tutor',
        );
      }
      final lid = bundle.learnerUserId;
      if (lid != null && lid == peerSupabaseUserId) {
        return agoraNumericUidForSessionRole(
          sessionId: sid,
          userId: lid,
          role: 'learner',
        );
      }
    }
    final asTutor = agoraNumericUidForSessionRole(
      sessionId: sid,
      userId: peerSupabaseUserId,
      role: 'tutor',
    );
    final active = _sortedActiveRemoteParticipantsFromRegistry();
    if (active.contains(asTutor)) return asTutor;
    final asLearner = agoraNumericUidForSessionRole(
      sessionId: sid,
      userId: peerSupabaseUserId,
      role: 'learner',
    );
    if (active.contains(asLearner)) return asLearner;
    return null;
  }

  void _applyAgoraRemoteUidLeaveConfirmed(int leftUid, {required String source}) {
    final myUid = _agoraService.currentUID;
    if (myUid != null && leftUid == myUid) {
      return;
    }
    _remoteLeftCheckTimer?.cancel();
    _remoteLeftCheckTimer = null;

    _scheduleUiUpdate(() {
      _upsertParticipant(leftUid, userLeft: true);
      _remoteJoinedAt = null;
      _lastRemoteUID = leftUid;
      _removeParticipant(leftUid);
      _raisedHandUids.remove(leftUid);
      _remoteHandRaised = _raisedHandUids.isNotEmpty;

      final primaryDeparted = _remoteUID == leftUid;
      if (primaryDeparted) {
        _remoteUID = null;
      }
      final stillActiveSorted = _sortedActiveRemoteParticipantsFromRegistry();
      if (primaryDeparted ||
          (_remoteUID != null && !stillActiveSorted.contains(_remoteUID!))) {
        _remoteUID = stillActiveSorted.isEmpty ? null : stillActiveSorted.first;
      }
      _remoteUserLeft = stillActiveSorted.isEmpty;
      _syncLegacyRemoteStateFromRegistry();

      final remoteCount = stillActiveSorted.length;
      if (remoteCount != _lastAppliedRemoteCountForLayout) {
        _lastAppliedRemoteCountForLayout = remoteCount;
        if (remoteCount >= 2) {
          _layout = VideoLayout.gallery;
        } else if (remoteCount == 1) {
          _layout = VideoLayout.sideBySide;
        } else {
          _layout = VideoLayout.spotlight;
        }
      }
    });

    LogService.info(
      'Remote marked left – source: $source (remoteUid=$leftUid)',
    );
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
    _recoveryQoeCorrelationId = QoeTelemetryService.buildCorrelationId(
      widget.sessionId,
    );
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
    // Safety net: if route was popped without going through _endCall (e.g. error nav), try to leave and release.
    // On web, defer two frames: ripping platform-view / WebRTC DOM while the engine view is still composing
    // triggers `EngineFlutterView.render` after dispose (flutter engine window.dart assert spam).
    if (_explicitCallCleanupDone) {
      // Already cleaned up via explicit end-call flow.
    } else if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await _agoraService.leaveChannel();
            await _agoraService.releaseEngineAfterLeave();
          } catch (e) {
            LogService.warning('Dispose safety net leave/release (web): $e');
          }
        });
      });
    } else {
      Future.microtask(() async {
        try {
          await _agoraService.leaveChannel();
          await _agoraService.releaseEngineAfterLeave();
        } catch (e) {
          LogService.warning('Dispose safety net leave/release: $e');
        }
      });
    }

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
    _mutedMicSpeechHintSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _recordingFailedSubscription?.cancel();
    _workspaceStateSubscription?.cancel();
    _workspaceSyncIssueSubscription?.cancel();
    _peerLeftHeartbeatSubscription?.cancel();
    _peerBeatHeartbeatSubscription?.cancel();
    _localCameraPublishingSubscription?.cancel();
    _audioOnlyFallbackTimer?.cancel();
    _timeRemainingSubscription?.cancel();
    _sessionEndedSubscription?.cancel();

    _workspaceRealtime?.unsubscribe();
    unawaited(_workspaceRealtime?.disposeIssueStream() ?? Future<void>.value());
    _workspaceRealtime?.workspace.dispose();
    unawaited(_disposeIncallChatRealtime());

    // Cancel debounce timer
    _videoStateDebounceTimer?.cancel();
    _localPreviewWatchdogTimer?.cancel();
    _uiUpdateDebounceTimer?.cancel();
    _remoteUnstableTimer?.cancel();
    _localReconnectClearTimer?.cancel();
    _degradationSustainTimer?.cancel();
    _recoveryHealthTimer?.cancel();

    _callConnectivitySubscription?.cancel();
    _connectivityOfflineDebounce?.cancel();
    _joinStuckOfflineProbeTimer?.cancel();
    _reconnectStuckOfflineProbeTimer?.cancel();

    _remoteLeftCheckTimer?.cancel();
    _remoteLeftCheckTimer = null;
    _cancelLessonPingCooldownTicker();
    _removeMobileWebOverlay();

    // Stop timer
    _timerService.stopSession();
    WidgetsBinding.instance.removeObserver(this);
    SessionHeartbeatService().stop();
    CallPipController().detachFromLifecycle();
    _galleryPageController.dispose();
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
    } else if (state == AppLifecycleState.resumed) {
      _lastLifecycleResumedAt = DateTime.now();
      unawaited(() async {
        try {
          final online = await _connectivity.checkConnectivity();
          if (!mounted || !online) return;
          _dismissInCallOfflineDialogIfOpen();
        } catch (_) {
          // Keep current state; reconnect callbacks can settle naturally.
        }
      }());
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // Web hot-restart in debug can skip normal route teardown; force media cleanup
    // so camera/mic do not stay active after the app resets to home.
    if (kIsWeb && kDebugMode) {
      unawaited(_agoraService.prepareFreshJoinState());
    }
  }

  void _insertMobileWebOverlayIfNeeded() {
    if (!mounted || !kIsWeb || !platform_utils.PlatformUtils.isMobileWeb)
      return;
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_mobileWebOverlayEntry!);
    LogService.info(
      '[MOBILE_WEB] In-call overlay inserted into Overlay layer (state=$_sessionState)',
    );
    debugPrint('[MOBILE_WEB] Overlay inserted state=$_sessionState');
  }

  void _removeMobileWebOverlay() {
    _mobileWebOverlayEntry?.remove();
    _mobileWebOverlayEntry = null;
  }

  /// On mobile web, we ignore onUserOffline (to avoid spurious "left" when local mutes).
  /// Use a timeout: if no remote activity for [_remoteLeftInactivityThreshold], treat as left.
  void _startRemoteLeftCheckTimerIfNeeded() {
    if (!kIsWeb || !platform_utils.PlatformUtils.isMobileWeb) return;
    _remoteLeftCheckTimer?.cancel();
    _remoteLeftCheckTimer = Timer.periodic(_remoteLeftCheckInterval, (_) {
      if (!mounted || _remoteUID == null || _lastRemoteActivityAt == null)
        return;
      if (_sessionState != AgoraSessionState.connected) return;
      final elapsed = DateTime.now().difference(_lastRemoteActivityAt!);
      if (elapsed >= _remoteLeftInactivityThreshold) {
        _remoteLeftCheckTimer?.cancel();
        _remoteLeftCheckTimer = null;
        final leftUid = _remoteUID;
        final layoutBefore = _layout;
        safeSetState(() {
          _remoteUserLeft = true;
          _remoteUID = null;
          _remoteConnectionUnstable = false;
          _layout = VideoLayout.spotlight;
        });
        _syncDualStreamPinWithLayout();
        _applyGalleryPagingOnLayoutChanged(layoutBefore, _layout);
        _previousLayoutForPaging = _layout;
        _syncDegradationTrackingAfterMutation();
        LogService.info(
          'Mobile web: remote marked left after ${elapsed.inSeconds}s inactivity (uid=$leftUid)',
        );
        // Keep UX minimal: top status banner already communicates this state.
      }
    });
  }

  Future<void> _setupWorkspaceRealtime(String currentUserId) async {
    final tutorId = await _profileService.getTutorUserIdForSession(
      widget.sessionId,
    );
    if (tutorId == null || tutorId.isEmpty) {
      LogService.warning(
        '[WORKSPACE] No tutor_id for session ${widget.sessionId}; realtime skipped',
      );
      return;
    }
    _workspaceRealtime = WorkspaceRealtimeSync(
      sessionId: widget.sessionId,
      currentUserId: currentUserId,
      tutorUserId: tutorId,
    );
    await _workspaceRealtime!.subscribe();
    _workspaceStateSubscription?.cancel();
    _workspaceStateSubscription = _workspaceRealtime!.workspace.stateStream
        .listen((_) {
          _lastWorkspacePacketAt = DateTime.now();
          if (mounted) safeSetState(() {});
        });
    _workspaceSyncIssueSubscription?.cancel();
    _workspaceSyncIssueSubscription = _workspaceRealtime!.syncIssues.listen((
      _,
    ) {
      if (!mounted) return;
      final now = DateTime.now();
      if (_lastWorkspaceSyncReconnectAt != null &&
          now.difference(_lastWorkspaceSyncReconnectAt!) <
              const Duration(seconds: 12)) {
        return;
      }
      _lastWorkspaceSyncReconnectAt = now;
      LogService.warning('[WORKSPACE] Transport issue — reconnecting channel');
      _showSnackBar('Teaching workspace sync had a hiccup. Reconnecting…');
      unawaited(_workspaceRealtime!.reconnectChannel());
    });
    _lastWorkspacePacketAt = DateTime.now();
    if (mounted) safeSetState(() {});
  }

  void _beginWorkspaceRealtimeWarmup(String userId) {
    if (!AppConfig.enableClassroomWorkspaceRealtime) return;
    unawaited(
      _setupWorkspaceRealtime(userId).catchError((Object e, StackTrace _) {
        LogService.warning('[WORKSPACE] Failed to start realtime sync: $e');
      }),
    );
  }

  Future<void> _startSessionHeartbeat(String userId) async {
    try {
      await SessionHeartbeatService().start(
        sessionId: widget.sessionId,
        userId: userId,
      );
      if (kIsWeb) {
        platform_utils.PlatformUtils.registerCallUnloadHandler(() {
          SessionHeartbeatService().sendLeftSignal();
        });
      }
      _peerLeftHeartbeatSubscription?.cancel();
      _peerLeftHeartbeatSubscription = SessionHeartbeatService().peerLeftStream
          .listen((peerId) {
            if (!mounted) return;
            final mappedUid = _agoraUidForSupabaseHeartbeatPeer(peerId);
            if (mappedUid != null) {
              _applyAgoraRemoteUidLeaveConfirmed(
                mappedUid,
                source: 'session_heartbeat_left',
              );
            } else if (_galleryRemoteUids().length <= 1) {
              _scheduleUiUpdate(() {
                _remoteUserLeft = true;
                _remoteConnectionUnstable = false;
              });
            } else {
              LogService.info(
                '[HEARTBEAT] peer left peerId=$peerId — could not map to Agora UID '
                '(group roster); not collapsing entire call UI.',
              );
            }
            _emitRecoveryQoe(
              'classroom_recovery_heartbeat_peer_left',
              <String, dynamic>{'peer_id': peerId, 'role': widget.userRole},
            );
          });
      _peerBeatHeartbeatSubscription?.cancel();
      _peerBeatHeartbeatSubscription = SessionHeartbeatService().peerBeatStream
          .listen((_) {});
    } catch (e) {
      LogService.warning('[HEARTBEAT] Failed to start heartbeat: $e');
    }
  }

  void _startRecoveryHealthMonitor() {
    _recoveryHealthTimer?.cancel();
    _recoveryHealthTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final active =
          _sessionState == AgoraSessionState.connected ||
          _sessionState == AgoraSessionState.reconnecting;
      if (!active || _remoteUID == null || _remoteUserLeft) {
        if (_showRecoveryBanner) {
          _emitRecoveryModeExit('call_not_active_or_peer_left');
          safeSetState(() {
            _showRecoveryBanner = false;
            _recoveryReason = '';
          });
        }
        return;
      }

      String? reason;
      if (_localConnectionReconnecting || _remoteConnectionUnstable) {
        final now = DateTime.now();
        _recoveryUnstableObservedAt ??= now;
        if (now.difference(_recoveryUnstableObservedAt!) >=
            const Duration(seconds: 40)) {
          reason = 'Connection is unstable.';
        }
      } else {
        _recoveryUnstableObservedAt = null;
      }
      if (reason == null &&
          SessionHeartbeatService().lastPeerBeatAt != null &&
          DateTime.now().difference(SessionHeartbeatService().lastPeerBeatAt!) >
              const Duration(seconds: 105)) {
        reason = 'Peer heartbeat is delayed.';
      } else if (reason == null &&
          !_remoteVideoReady &&
          !_remoteAudioMuted &&
          !_activeRemoteScreenShare) {
        final lastReady = _lastRemoteVideoReadyAt ?? _remoteJoinedAt;
        if (lastReady != null &&
            DateTime.now().difference(lastReady) >
                const Duration(seconds: 35)) {
          reason = 'Remote video is not recovering.';
        }
      }

      if (reason == null &&
          widget.userRole == 'tutor' &&
          AppConfig.enableClassroomWorkspaceRealtime &&
          _workspaceRealtime != null &&
          (_workspaceRealtime!.workspace.state.teachingLaneOpen) &&
          _lastWorkspacePacketAt != null &&
          DateTime.now().difference(_lastWorkspacePacketAt!) >
              const Duration(seconds: 180)) {
        reason = 'Workspace sync appears stale.';
      }

      if (reason != null) {
        if (!_showRecoveryBanner || _recoveryReason != reason) {
          if (!_showRecoveryBanner) {
            _emitRecoveryModeEnter(reason);
          } else {
            _emitRecoveryQoe('classroom_recovery_mode_reason_changed', {
              'from': _recoveryReason,
              'to': reason,
              'role': widget.userRole,
            });
          }
          safeSetState(() {
            _showRecoveryBanner = true;
            _recoveryReason = reason!;
          });
        }
      } else if (_showRecoveryBanner) {
        _emitRecoveryModeExit('auto_recovered');
        safeSetState(() {
          _showRecoveryBanner = false;
          _recoveryReason = '';
        });
      }
    });
  }

  Future<void> _openBackupCallLink() async {
    final url = AppConfig.classroomBackupCallUrl;
    if (url.isEmpty) {
      _showSnackBar('No backup call link configured.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnackBar('Backup call link is invalid.');
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnackBar('Could not open backup call link.');
      } else {
        _emitRecoveryQoe('classroom_recovery_backup_opened', <String, dynamic>{
          'url_host': uri.host,
          'role': widget.userRole,
        });
      }
    } catch (_) {
      _showSnackBar('Could not open backup call link.');
    }
  }

  Future<void> _contactLiveClassSupport() async {
    try {
      await WhatsAppSupportService.openWhatsApp(
        context: 'general_support',
        additionalInfo:
            'Live classroom recovery help needed.\n'
            'Session ID: ${widget.sessionId}\n'
            'Reason: ${_recoveryReason.isEmpty ? "n/a" : _recoveryReason}\n'
            'Role: ${widget.userRole}',
      );
      _emitRecoveryQoe('classroom_recovery_support_opened', <String, dynamic>{
        'role': widget.userRole,
        'reason': _recoveryReason,
      });
    } catch (_) {
      _showSnackBar('Could not open support chat.');
    }
  }

  void _showSnackBar(String text) {
    if (!mounted || _isTearingDownUi) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(text)));
  }

  bool _shouldUseSoloWaitingHeroLayout() {
    if (_layout != VideoLayout.spotlight) return false;
    if (_anyScreenShareActive) return false;
    if (_remoteUserLeft) return false;
    if (_galleryRemoteUids().isNotEmpty) return false;
    if (_remoteUID != null) return false;
    return _sessionState == AgoraSessionState.connected ||
        _sessionState == AgoraSessionState.joining ||
        _sessionState == AgoraSessionState.reconnecting;
  }

  Duration? get _lessonPingClientCooldownRemaining {
    final last = _lastLessonWaitingPingAt;
    if (last == null) return null;
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= _lessonPingClientCooldown) return null;
    return _lessonPingClientCooldown - elapsed;
  }

  void _cancelLessonPingCooldownTicker() {
    _lessonPingCooldownTicker?.cancel();
    _lessonPingCooldownTicker = null;
  }

  void _startLessonPingCooldownTicker() {
    _cancelLessonPingCooldownTicker();
    if (_lastLessonWaitingPingAt == null) return;
    _lessonPingCooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_lessonPingClientCooldownRemaining == null) {
        _cancelLessonPingCooldownTicker();
      }
      safeSetState(() {});
    });
  }

  static String _formatLessonPingCooldown(Duration d) {
    final total = d.inSeconds;
    final m = total ~/ 60;
    final s = total % 60;
    if (m <= 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String _localDisplayNameForChat() {
    final raw = (_localProfile?['full_name'] as String?)?.trim();
    if (raw != null && raw.isNotEmpty && raw != 'User') return raw;
    return widget.userRole == 'tutor' ? 'Tutor' : 'Learner';
  }

  String _chatPeerLabel() => widget.userRole == 'tutor' ? 'learner' : 'tutor';

  String _localInitialsForPip() {
    final name = (_localProfile?['full_name'] as String?)?.trim();
    if (name != null && name.isNotEmpty && name != 'User' && name.length >= 1) {
      final parts = name
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }
    return widget.userRole == 'tutor' ? 'T' : 'L';
  }

  /// Meet-style in-body chat column (not the full-screen overlay). Used to keep Send above web
  /// [PointerInterceptor] and avoid stealing hits from the composer.
  bool _embeddedIncallChatRailVisible(MediaQueryData mq) {
    if (mq.size.width < _kClassroomDualPaneMinWidth || !_inCallChatOpen) {
      return false;
    }
    final shellActive =
        _useClassroomWorkspaceShell &&
        (_sessionState.isActive || _sessionState.isConnecting);
    if (!shellActive) return false;
    final teachingOpen =
        _workspaceRealtime?.workspace.state.teachingLaneOpen ?? false;
    final teachingLaneVisibleWide =
        mq.size.width >= _kClassroomDualPaneMinWidth &&
        shellActive &&
        teachingOpen;
    if (widget.userRole == 'learner') {
      return !teachingLaneVisibleWide;
    }
    if (widget.userRole == 'tutor') {
      return true;
    }
    return false;
  }

  /// Narrow phones: chat overlay fills below header; dock hides; participant strip stays on top.
  bool _narrowOverlayChatMode(MediaQueryData mq) =>
      _inCallChatOpen &&
      (mq.size.width < _kParticipantStripBreakpointWidth ||
          (mq.viewInsets.bottom > 0 && mq.size.width < 760)) &&
      !_embeddedIncallChatRailVisible(mq);

  bool _shouldShowDraggableParticipantStrip(MediaQueryData mq) {
    if (_showLeavingScreen) return false;
    if (_anyScreenShareActive) return false;
    if (!(_sessionState.isActive || _sessionState.isConnecting)) return false;
    if (_remoteUID != null && !_remoteUserLeft) return false;
    if (mq.size.width >= _kParticipantStripBreakpointWidth) return false;
    // Group-call arbitration: keep this strip for one-on-one style calls.
    if (_galleryRemoteUids().length > 1) return false;
    return true;
  }

  /// One remote + side-by-side or gallery: PiP replaces embedded local tile (Meet-style).
  bool _pipSupersedesEmbeddedLocalView() {
    // Multi-user classroom UX: local participant should remain a participant tile,
    // not a floating PiP, once another participant is in call.
    return false;
  }

  Widget _maybeLocalPipOverlay() {
    final mq = MediaQuery.of(context);
    if (_narrowOverlayChatMode(mq)) {
      return const SizedBox.shrink();
    }
    if (_webSecondLocalCameraPreviewBreaksScreenShare) {
      return const SizedBox.shrink();
    }
    // During screen share, suppress the camera PiP on mobile/small layouts to
    // avoid stacking a second "camera" surface on top of the share stage.
    if (_anyScreenShareActive) {
      return const SizedBox.shrink();
    }
    if (_agoraService.engine == null || _agoraService.currentUID == null) {
      return const SizedBox.shrink();
    }
    final waitingSolo = _shouldUseSoloWaitingHeroLayout();
    if (waitingSolo && _soloWaitingSelfExpanded) {
      return const SizedBox.shrink();
    }
    final hasRemote = _remoteUID != null && !_remoteUserLeft;
    if (hasRemote) return const SizedBox.shrink();
    final aloneInCall =
        !hasRemote && (_sessionState.isActive || _sessionState.isConnecting);
    final showSpotlightPip =
        _layout == VideoLayout.spotlight &&
        (((hasRemote && _isVideoEnabled) || waitingSolo));
    final showTiledPip = _pipSupersedesEmbeddedLocalView() && hasRemote;
    final showSoloPip = aloneInCall;
    if (!showSpotlightPip && !showTiledPip && !showSoloPip) {
      return const SizedBox.shrink();
    }
    return _buildLocalVideoPIP();
  }

  Widget _buildSoloWaitingHeroMain() {
    final cooldownLeft = _lessonPingClientCooldownRemaining;
    final isTutor = widget.userRole == 'tutor';
    final title = isTutor
        ? 'Waiting for your learner'
        : 'Waiting for your tutor';
    final subline = isTutor
        ? 'You\'re in the lesson room. We\'ll send them a reminder in PrepSkul. For a longer note, message them from PrepSkul.'
        : 'You\'re in the lesson room. We\'ll send them a reminder in PrepSkul. You can also message them from PrepSkul.';
    final remindLabel = isTutor
        ? 'Remind learner to join'
        : 'Remind tutor to join';

    return Container(
      color: _kSoftDark,
      child: SafeArea(
        child: Align(
          alignment: const Alignment(0, 0.28),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    _kClassroomTileBorderRadius,
                  ),
                  border: Border.all(
                    color: _kClassroomChromeBorder,
                    width: 1.5,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                  color: const Color(0xFF16233C),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        subline,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryDark,
                          disabledBackgroundColor: const Color(0xFFD8DEE9),
                          disabledForegroundColor: const Color(0xFF0F1A2E),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        icon: _lessonWaitingPingSending
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryDark,
                                ),
                              )
                            : Icon(
                                Icons.notifications_active_outlined,
                                color: AppTheme.primaryDark,
                              ),
                        label: Text(
                          remindLabel,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        onPressed:
                            cooldownLeft != null ||
                                _lessonWaitingPingSending ||
                                _sessionLocalSupabaseUserId == null
                            ? null
                            : _onLessonWaitingPing,
                      ),
                      if (cooldownLeft != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'You can send another reminder in ${_formatLessonPingCooldown(cooldownLeft)}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                      if (isTutor) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Lesson link',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: _copyLessonInviteToClipboard,
                              icon: const Icon(
                                Icons.copy,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Copy',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: _shareLessonInvite,
                              icon: const Icon(Icons.share, size: 18),
                              label: Text(
                                'Share',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSoloWaitingExpandedLocalMain(agora_rtc_engine.RtcEngine engine) {
    final localUid = _agoraService.currentUID;
    if (localUid == null) return Container(color: _kSoftDark);
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildStableLocalSurface(
          engine: engine,
          localUid: localUid,
          showWaiting: false,
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Material(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(22),
                child: Tooltip(
                  message: 'Back to waiting summary',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () =>
                        safeSetState(() => _soloWaitingSelfExpanded = false),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.close_fullscreen_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onLessonWaitingPing() async {
    if (_lessonWaitingPingSending || _sessionLocalSupabaseUserId == null) {
      return;
    }
    if (_lessonPingClientCooldownRemaining != null) {
      _showSnackBar('Please wait before sending another reminder.');
      return;
    }
    safeSetState(() => _lessonWaitingPingSending = true);
    try {
      final outcome = await LessonWaitingPingService.ping(
        sessionId: widget.sessionId,
      );
      if (!mounted) return;
      switch (outcome) {
        case LessonWaitingPingOutcome.success:
          _showSnackBar('Reminder sent.');
          safeSetState(() {
            _lastLessonWaitingPingAt = DateTime.now();
          });
          _startLessonPingCooldownTicker();
          break;
        case LessonWaitingPingOutcome.cooldown:
          safeSetState(() {
            _lastLessonWaitingPingAt = DateTime.now();
          });
          _startLessonPingCooldownTicker();
          _showSnackBar('Please wait before sending another reminder.');
          break;
        case LessonWaitingPingOutcome.failure:
          _showSnackBar(
            'Could not send a reminder. Try again, or use PrepSkul messages.',
          );
          break;
      }
    } finally {
      if (mounted) safeSetState(() => _lessonWaitingPingSending = false);
    }
  }

  Future<void> _ensureIncallChatRealtime() async {
    final bundle = _sessionParticipantBundle;
    final inRoom =
        _sessionState == AgoraSessionState.connected ||
        _sessionState == AgoraSessionState.reconnecting;
    if (!inRoom || bundle == null) return;
    final t = bundle.tutorUserId;
    final l = bundle.learnerUserId;
    if ((t == null || t.isEmpty) && (l == null || l.isEmpty)) return;
    try {
      final chat =
          _incallChat ??
          IncallChatRealtime(sessionId: widget.sessionId, bundle: bundle);
      _incallChat = chat;
      chat.subscribe();
      if (mounted) safeSetState(() {});
    } catch (e) {
      LogService.warning('[INCALL_CHAT] ensure failed: $e');
      if (mounted) safeSetState(() {});
    }
  }

  Future<void> _disposeIncallChatRealtime() async {
    final c = _incallChat;
    if (c == null) return;
    _incallChat = null;
    try {
      await c.dispose();
    } catch (_) {}
  }

  void _openIncallChatPanel() {
    if (!_sessionState.isActive && !_sessionState.isConnecting) return;
    if (_sessionParticipantBundle == null) {
      _showSnackBar('Still loading lesson details — try again in a moment.');
      return;
    }
    safeSetState(() => _inCallChatOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_ensureIncallChatRealtime());
    });
  }

  void _toggleIncallChatPanel() {
    if (!_sessionState.isActive && !_sessionState.isConnecting) return;
    if (_sessionParticipantBundle == null) {
      _showSnackBar('Still loading lesson details — try again in a moment.');
      return;
    }
    final next = !_inCallChatOpen;
    safeSetState(() => _inCallChatOpen = next);
    if (next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_ensureIncallChatRealtime());
      });
    }
  }

  void _closeIncallChatPanel() {
    if (!_inCallChatOpen) return;
    safeSetState(() => _inCallChatOpen = false);
  }

  void _emitRecoveryModeEnter(String reason) {
    _recoveryModeEnteredAt = DateTime.now();
    _emitRecoveryQoe('classroom_recovery_mode_enter', <String, dynamic>{
      'reason': reason,
      'role': widget.userRole,
      'remote_uid_present': _remoteUID != null,
    });
  }

  void _emitRecoveryModeExit(String exitReason) {
    final enteredAt = _recoveryModeEnteredAt;
    final activeMs = enteredAt == null
        ? null
        : DateTime.now().difference(enteredAt).inMilliseconds;
    _emitRecoveryQoe('classroom_recovery_mode_exit', <String, dynamic>{
      'exit_reason': exitReason,
      'active_ms': activeMs,
      'role': widget.userRole,
      'last_reason': _recoveryReason,
    });
    _recoveryModeEnteredAt = null;
  }

  void _emitRecoveryQoe(String eventName, Map<String, dynamic> payload) {
    final correlationId = _recoveryQoeCorrelationId;
    if (correlationId == null || widget.sessionId.isEmpty) return;
    QoeTelemetryService.emit(
      sessionId: widget.sessionId,
      correlationId: correlationId,
      eventName: eventName,
      eventSource: 'session_screen_recovery',
      payload: payload,
    );
  }

  void _emitAudioOnlyFallbackQoe(
    String eventName,
    Map<String, dynamic> payload,
  ) {
    final correlationId = _recoveryQoeCorrelationId;
    if (correlationId == null || widget.sessionId.isEmpty) return;
    QoeTelemetryService.emit(
      sessionId: widget.sessionId,
      correlationId: correlationId,
      eventName: eventName,
      eventSource: 'session_screen_audio_fallback',
      payload: payload,
    );
  }

  void _scheduleAudioOnlyFallbackIfNeeded() {
    _audioOnlyFallbackTimer?.cancel();
    if (_audioOnlyFallbackOffered) return;
    if (!AppConfig.enableClassroomAudioOnlyFallback) return;
    if (_sessionState != AgoraSessionState.connected) return;
    if (!_isVideoEnabled) return;
    if (_agoraService.isPublishingScreen) return;
    if (_agoraService.localCameraPublishingSignalReceived) return;

    _audioOnlyFallbackTimer = Timer(_kAudioOnlyFallbackGrace, () {
      if (!mounted || _audioOnlyFallbackOffered) return;
      if (_sessionState != AgoraSessionState.connected) return;
      if (!_isVideoEnabled) return;
      if (_agoraService.isPublishingScreen) return;
      if (_agoraService.localCameraPublishingSignalReceived) return;
      _offerAudioOnlyFallbackSnackBar();
    });
  }

  void _offerAudioOnlyFallbackSnackBar() {
    if (!mounted || _audioOnlyFallbackOffered) return;
    _audioOnlyFallbackOffered = true;
    _emitAudioOnlyFallbackQoe(
      'audio_only_fallback_prompt_shown',
      <String, dynamic>{
        'role': widget.userRole,
        'grace_seconds': _kAudioOnlyFallbackGrace.inSeconds,
      },
    );
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          'Camera is not starting reliably. Continue with audio only?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        action: SnackBarAction(
          label: 'Audio only',
          onPressed: () {
            unawaited(_applyAudioOnlyFallbackFromPrompt());
          },
        ),
        duration: const Duration(seconds: 14),
      ),
    );
  }

  Future<void> _applyAudioOnlyFallbackFromPrompt() async {
    if (!_isVideoEnabled) return;
    _emitAudioOnlyFallbackQoe('audio_only_fallback_accepted', <String, dynamic>{
      'role': widget.userRole,
    });
    await _toggleVideo();
  }

  IconData _workspaceSurfaceIcon(WorkspaceSurface surface) {
    switch (surface) {
      case WorkspaceSurface.launcher:
        return Icons.dashboard_rounded;
      case WorkspaceSurface.whiteboard:
        return Icons.gesture_rounded;
      case WorkspaceSurface.pdfDocument:
        return Icons.picture_as_pdf_rounded;
      case WorkspaceSurface.lessonNotes:
        return Icons.note_alt_rounded;
    }
  }

  String _workspaceSurfaceLabel(WorkspaceSurface surface) {
    switch (surface) {
      case WorkspaceSurface.launcher:
        return 'Home';
      case WorkspaceSurface.whiteboard:
        return 'Board';
      case WorkspaceSurface.pdfDocument:
        return 'Materials';
      case WorkspaceSurface.lessonNotes:
        return 'Notes';
    }
  }

  /// Preply-aligned hierarchy: board + materials deck + notes (short UI labels via [_workspaceSurfaceLabel]).
  String _workspaceSurfaceTooltip(WorkspaceSurface surface) {
    switch (surface) {
      case WorkspaceSurface.launcher:
        return 'Teaching tools — pick board, materials, or notes';
      case WorkspaceSurface.whiteboard:
        return 'Board — shared whiteboard';
      case WorkspaceSurface.pdfDocument:
        return 'Materials — PDF / slides (page syncs)';
      case WorkspaceSurface.lessonNotes:
        return 'Notes — lesson scratchpad';
    }
  }

  static const List<WorkspaceSurface> _workspaceSurfacesForTabBar =
      <WorkspaceSurface>[
        WorkspaceSurface.whiteboard,
        WorkspaceSurface.pdfDocument,
        WorkspaceSurface.lessonNotes,
      ];

  Future<void> _publishTeachingLaneOpen(bool open) async {
    final sync = _workspaceRealtime;
    if (sync == null || widget.userRole != 'tutor') return;
    await sync.publishPacket(TeachingLaneOpenPacket(open: open));
  }

  static const List<String> _lessonAgenda = <String>[
    'Warm-up recap',
    'Core concept practice',
    'Guided exercise',
    'Independent attempt',
    'Review and homework',
  ];

  int _agendaIndexClamped(int index) {
    if (_lessonAgenda.isEmpty) return 0;
    return index.clamp(0, _lessonAgenda.length - 1);
  }

  Widget _buildAgendaStatusChip(
    WorkspaceRealtimeSync sync,
    WorkspaceViewState data,
  ) {
    final idx = _agendaIndexClamped(data.agendaStepIndex);
    final label = _lessonAgenda[idx];
    final isTutor = widget.userRole == 'tutor';
    final showHideTeachingRail = isTutor && data.teachingLaneOpen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.checklist_rounded,
            size: 16,
            color: Colors.white.withOpacity(0.86),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lesson step ${idx + 1}/${_lessonAgenda.length}: $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (showHideTeachingRail)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Hide teaching tools',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _publishTeachingLaneOpen(false),
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: Colors.white.withOpacity(0.72),
              ),
            ),
          if (isTutor) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Previous activity',
              onPressed: () =>
                  sync.publishPacket(AgendaStepPacket(index: max(0, idx - 1))),
              icon: Icon(
                Icons.chevron_left,
                size: 20,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Next activity',
              onPressed: () => sync.publishPacket(
                AgendaStepPacket(index: min(_lessonAgenda.length - 1, idx + 1)),
              ),
              icon: Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Tutor-authored workspace surface + pagination (Realtime). Used in-shell and as overlay fallback.
  Widget _buildWorkspaceTutorControlBar(
    WorkspaceRealtimeSync sync,
    WorkspaceViewState data,
  ) {
    Widget surfaceButton(WorkspaceSurface surface, {required bool showLabel}) {
      final selected = data.surface == surface;
      final label = _workspaceSurfaceLabel(surface);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Tooltip(
          message: _workspaceSurfaceTooltip(surface),
          child: Material(
            color: selected
                ? Colors.white.withOpacity(0.22)
                : Colors.white.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: selected
                    ? Colors.white.withOpacity(0.45)
                    : Colors.white.withOpacity(0.2),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: InkWell(
              onTap: () async {
                await sync.publishPacket(ToolChangePacket(surface: surface));
                if (_useClassroomWorkspaceShell &&
                    widget.userRole == 'tutor' &&
                    !data.teachingLaneOpen) {
                  await _publishTeachingLaneOpen(true);
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: showLabel ? 10 : 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _workspaceSurfaceIcon(surface),
                      size: 20,
                      color: Colors.white.withOpacity(selected ? 0.95 : 0.72),
                    ),
                    if (showLabel) ...[
                      const SizedBox(width: 6),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: Colors.white.withOpacity(
                            selected ? 0.95 : 0.78,
                          ),
                        ),
                      ),
                    ],
                    if (selected) ...[
                      const SizedBox(width: 5),
                      Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white.withOpacity(0.92),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.black.withOpacity(0.48),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Icon-only when workspace chrome is cramped; widen for Preply-like trio labels.
            final showToolLabels =
                constraints.maxWidth >= _kWorkspaceTutorToolLabelBreakWidth;
            final showPdfPagingControls =
                data.surface == WorkspaceSurface.pdfDocument;
            return Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _workspaceSurfacesForTabBar
                          .map(
                            (s) => surfaceButton(s, showLabel: showToolLabels),
                          )
                          .toList(),
                    ),
                  ),
                ),
                if (showPdfPagingControls) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Previous page',
                    onPressed: () {
                      sync.publishPacket(
                        SlideIndexPacket(index: max(0, data.pdfPageIndex - 1)),
                      );
                    },
                    icon: Icon(
                      Icons.chevron_left,
                      color: Colors.white.withOpacity(0.9),
                      size: 24,
                    ),
                  ),
                  Text(
                    'Page ${data.pdfPageIndex + 1}',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Next page',
                    onPressed: () {
                      sync.publishPacket(
                        SlideIndexPacket(index: data.pdfPageIndex + 1),
                      );
                    },
                    icon: Icon(
                      Icons.chevron_right,
                      color: Colors.white.withOpacity(0.9),
                      size: 24,
                    ),
                  ),
                ],
                if (data.surface == WorkspaceSurface.whiteboard) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Clear board',
                    onPressed: () {
                      sync.publishPacket(const ClearWhiteboardPacket());
                    },
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white.withOpacity(0.88),
                      size: 22,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWorkspaceLearnerStatusPill(WorkspaceViewState data) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _workspaceSurfaceIcon(data.surface),
              size: 16,
              color: Colors.white.withOpacity(0.85),
            ),
            const SizedBox(width: 8),
            Text(
              data.surface == WorkspaceSurface.launcher
                  ? 'Pick a teaching tool'
                  : '${_workspaceSurfaceLabel(data.surface)} · Page ${data.pdfPageIndex + 1}',
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.88),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Step ${_agendaIndexClamped(data.agendaStepIndex) + 1}',
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.75),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _useClassroomWorkspaceShell {
    if (!AppConfig.enableClassroomWorkspaceRealtime) return false;
    if (_workspaceRealtime == null) return false;
    if (!(_sessionState == AgoraSessionState.connected ||
        _sessionState == AgoraSessionState.reconnecting)) {
      return false;
    }
    // Gallery (3+ remotes) stays video-only. 1:1 may use sideBySide in the
    // video lane while the workspace shell provides Board/Materials/Notes.
    if (_layout == VideoLayout.gallery) {
      return false;
    }
    return true;
  }

  /// Fixed workspace slot beside (or below) video; tools dock here when shell is active.
  Widget _buildClassroomWorkspacePanel({
    required bool workspaceDividerFromVideo,
  }) {
    final sync = _workspaceRealtime;
    if (sync == null) return const SizedBox.shrink();
    final isTutor = widget.userRole == 'tutor';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1528),
        border: Border(
          left: workspaceDividerFromVideo
              ? const BorderSide(color: Color(0x22FFFFFF))
              : BorderSide.none,
          top: workspaceDividerFromVideo
              ? BorderSide.none
              : const BorderSide(color: Color(0x22FFFFFF)),
        ),
      ),
      child: StreamBuilder<WorkspaceViewState>(
        stream: sync.workspace.stateStream,
        initialData: sync.workspace.state,
        builder: (context, snapshot) {
          final data = snapshot.data ?? sync.workspace.state;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              if (!isTutor)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Align(
                    alignment: Alignment.center,
                    child: _buildWorkspaceLearnerStatusPill(data),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(12, isTutor ? 12 : 8, 12, 6),
                child: _buildAgendaStatusChip(sync, data),
              ),
              Expanded(
                child: ClassroomWorkspaceIndexedStack(
                  workspace: data,
                  userRole: widget.userRole,
                  publishPacket: isTutor ? sync.publishPacket : null,
                  sessionIdForMaterialsUpload: widget.sessionId,
                ),
              ),
              if (isTutor)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: SafeArea(
                    top: false,
                    child: _buildWorkspaceTutorControlBar(sync, data),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Shared right-column chat for wide [MediaQuery] layouts (tutor + learner).
  Widget _buildEmbeddedIncallChatRailPanel() {
    final mq = MediaQuery.of(context);
    final chatUserId =
        _sessionLocalSupabaseUserId ??
        SupabaseService.client.auth.currentUser?.id ??
        '';
    return Padding(
      padding: EdgeInsets.only(
        top: _kCallTopChromeReserveHeight(mq),
        bottom: _kCallControlBarReserveHeight(mq),
      ),
      child: _incallChat == null || chatUserId.isEmpty
          ? const ColoredBox(
              color: Color(0xFF121A2E),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),
            )
          : IncallChatPanel(
              sync: _incallChat!,
              localUserId: chatUserId,
              localDisplayName: _localDisplayNameForChat(),
              peerLabel: _chatPeerLabel(),
              railMode: true,
              onClose: _closeIncallChatPanel,
            ),
    );
  }

  /// Video-first lane scoped with [MediaQuery] so [LocalVideoPIP] clamps to lane bounds.
  Widget _buildClassroomSplitBody() {
    final sync = _workspaceRealtime;
    if (sync != null) {
      return StreamBuilder<WorkspaceViewState>(
        stream: sync.workspace.stateStream,
        initialData: sync.workspace.state,
        builder: (context, snapshot) {
          final ws = snapshot.data ?? sync.workspace.state;
          return _buildClassroomSplitBodyForWorkspace(ws);
        },
      );
    }
    return _buildClassroomSplitBodyForWorkspace(null);
  }

  Widget _buildClassroomSplitBodyForWorkspace(WorkspaceViewState? ws) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _kClassroomDualPaneMinWidth;
        Widget videoLane(BoxConstraints laneConstraints) {
          final mq = MediaQuery.of(context);
          final laneSize = Size(
            laneConstraints.maxWidth,
            laneConstraints.maxHeight,
          );
          return MediaQuery(
            data: mq.copyWith(size: laneSize),
            child: Stack(
              fit: StackFit.expand,
              children: [_buildMainVideoArea(), _maybeLocalPipOverlay()],
            ),
          );
        }

        final videoLaneWidget = LayoutBuilder(
          builder: (context, c) => videoLane(c),
        );
        final shellActive =
            _useClassroomWorkspaceShell &&
            (_sessionState.isActive || _sessionState.isConnecting);
        final teachingOpen = ws?.teachingLaneOpen ?? false;
        final teachingLaneVisibleWide = wide && shellActive && teachingOpen;
        final teachingLaneVisibleNarrow = !wide && shellActive && teachingOpen;
        final workspace = _buildClassroomWorkspacePanel(
          workspaceDividerFromVideo: true,
        );
        if (teachingLaneVisibleWide && widget.userRole == 'tutor') {
          if (_inCallChatOpen && shellActive) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 12, child: videoLaneWidget),
                      Expanded(flex: 10, child: workspace),
                    ],
                  ),
                ),
                SizedBox(
                  width: _kLearnerIncallChatRailWidth,
                  child: _buildEmbeddedIncallChatRailPanel(),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 12, child: videoLaneWidget),
              Expanded(flex: 10, child: workspace),
            ],
          );
        }
        if (teachingLaneVisibleWide && widget.userRole == 'learner') {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 12, child: videoLaneWidget),
              Expanded(flex: 10, child: workspace),
            ],
          );
        }
        final learnerChatRailEligible =
            wide &&
            widget.userRole == 'learner' &&
            _inCallChatOpen &&
            !teachingLaneVisibleWide &&
            shellActive;
        if (learnerChatRailEligible) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: videoLaneWidget)],
                ),
              ),
              SizedBox(
                width: _kLearnerIncallChatRailWidth,
                child: _buildEmbeddedIncallChatRailPanel(),
              ),
            ],
          );
        }
        final tutorChatRailEligible =
            wide &&
            widget.userRole == 'tutor' &&
            _inCallChatOpen &&
            !teachingLaneVisibleWide &&
            shellActive;
        if (tutorChatRailEligible) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: videoLaneWidget),
              SizedBox(
                width: _kLearnerIncallChatRailWidth,
                child: _buildEmbeddedIncallChatRailPanel(),
              ),
            ],
          );
        }
        if (teachingLaneVisibleNarrow) {
          final workspacePanel = _buildClassroomWorkspacePanel(
            workspaceDividerFromVideo: false,
          );
          final sharedContentIsScreenShare = _anyScreenShareActive;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sharedContentIsScreenShare) ...[
                Expanded(flex: 13, child: videoLaneWidget),
                Expanded(flex: 7, child: workspacePanel),
              ] else ...[
                // Narrow: show shared content (board/materials) above, then
                // participants below in a scrollable region.
                Expanded(flex: 11, child: workspacePanel),
                Expanded(flex: 9, child: videoLaneWidget),
              ],
            ],
          );
        }
        // Narrow layouts without active teaching lane: full-bleed video.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Expanded(child: videoLaneWidget)],
        );
      },
    );
  }

  Widget _buildSessionBody() {
    if (_useClassroomWorkspaceShell) {
      return _buildClassroomSplitBody();
    }
    return Stack(
      fit: StackFit.expand,
      children: [_buildMainVideoArea(), _maybeLocalPipOverlay()],
    );
  }

  /// Collaborative workspace lane overlay when not using the dual-pane classroom shell (full-bleed video).
  Widget _buildWorkspaceTeachingRail() {
    final sync = _workspaceRealtime;
    if (!AppConfig.enableClassroomWorkspaceRealtime ||
        !(_sessionState == AgoraSessionState.connected ||
            _sessionState == AgoraSessionState.reconnecting) ||
        sync == null) {
      return const SizedBox.shrink();
    }
    if (_anyScreenShareActive) return const SizedBox.shrink();
    if (_useClassroomWorkspaceShell) return const SizedBox.shrink();

    final reservedAboveControls =
        MediaQuery.of(context).padding.bottom +
        (MediaQuery.of(context).size.height < 760 ? 70.0 : 78.0);

    if (widget.userRole == 'tutor') {
      return Positioned(
        left: 8,
        right: 8,
        bottom: reservedAboveControls,
        child: SafeArea(
          top: false,
          child: StreamBuilder<WorkspaceViewState>(
            stream: sync.workspace.stateStream,
            initialData: sync.workspace.state,
            builder: (context, snapshot) {
              final data = snapshot.data ?? sync.workspace.state;
              return _buildWorkspaceTutorControlBar(sync, data);
            },
          ),
        ),
      );
    }

    return Positioned(
      left: 10,
      right: 10,
      bottom: reservedAboveControls + 56,
      child: SafeArea(
        top: false,
        child: StreamBuilder<WorkspaceViewState>(
          stream: sync.workspace.stateStream,
          initialData: sync.workspace.state,
          builder: (context, snapshot) {
            final data = snapshot.data ?? sync.workspace.state;
            return Align(
              alignment: Alignment.center,
              child: _buildWorkspaceLearnerStatusPill(data),
            );
          },
        ),
      ),
    );
  }

  /// [forceWebRtcFullReset] — set true on retry-after-error so web does not reuse a broken engine.
  Future<void> _initializeSession({bool forceWebRtcFullReset = false}) async {
    try {
      LogService.info(
        '[SESSION] 🎥 Initializing - Session ID: ${widget.sessionId}, User Role: ${widget.userRole}',
      );
      // Web: avoid nuking a warm pre-join preview engine (full reset costs seconds).
      // Always reset if already in channel or caller forces (e.g. error retry).
      if (kIsWeb) {
        final bool needFullReset =
            forceWebRtcFullReset || _agoraService.isInChannel;
        if (needFullReset) {
          await _agoraService.prepareFreshJoinState();
        } else if (_agoraService.engine != null) {
          LogService.info(
            '[SESSION] Web join: reusing preview engine (skipped full teardown)',
          );
        }
      }

      safeSetState(() {
        _sessionState = AgoraSessionState.joining;
        _errorMessage = null;
        _joinOverlayDetail =
            'Securing your lesson token and syncing your account…';
      });

      // Get current user ID
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Load profile data
      _loadProfileData(user.id);

      // Workspace realtime (tutor resolution + Supabase subscribe) must not block RTC join.
      _beginWorkspaceRealtimeWarmup(user.id);

      final sessionCameraEnabled =
          AppConfig.enableSessionCameraPublishing &&
          widget.initialCameraEnabled;

      // Set initial camera/mic state from pre-join (camera gated product-wide).
      _isVideoEnabled = sessionCameraEnabled;
      _isAudioEnabled = widget.initialMicEnabled;

      safeSetState(() {
        _joinOverlayDetail = 'Connecting to the video lesson room…';
      });

      // Heartbeat + channel join in parallel — both are on the critical path to "in call".
      await Future.wait<void>([
        _startSessionHeartbeat(user.id),
        _agoraService.joinChannel(
          sessionId: widget.sessionId,
          userId: user.id,
          userRole: widget.userRole,
          initialCameraEnabled: sessionCameraEnabled,
          initialMicEnabled: widget.initialMicEnabled,
        ),
      ]);

      if (mounted) {
        safeSetState(() {
          _joinOverlayDetail =
              'Finishing microphone, webcam and channel setup…';
        });
      }

      // Update state to reflect actual camera/mic state
      safeSetState(() {
        _isVideoEnabled = _agoraService.isVideoEnabled();
        _isAudioEnabled = _agoraService.isAudioEnabled();
      });

      // CRITICAL: Explicitly set up local video IMMEDIATELY after joining
      // This ensures the user sees their own video right away (not just after toggle)
      if (sessionCameraEnabled) {
        try {
          LogService.info(
            '[SESSION] Setting up local video immediately after join...',
          );

          await _agoraService.setupLocalVideoAfterJoin();

          // Ensure video stream is unmuted (publishing)
          await _agoraService.ensureLocalVideoPublishing();

          LogService.info(
            '[SESSION] Local video set up successfully - should be visible now',
          );

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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleAudioOnlyFallbackIfNeeded();
      });

      // If tutor, start the session in the lifecycle service
      if (widget.userRole == 'tutor') {
        try {
          await SessionLifecycleService.startSession(
            widget.sessionId,
            isOnline: true,
            skipCloudRecording:
                kIsWeb && platform_utils.PlatformUtils.isMobileWeb,
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
      if (userMessage.contains('timeout') ||
          userMessage.contains('unreachable') ||
          userMessage.contains('slow to respond')) {
        userMessage =
            'Poor network connection. Please check your internet and try again.';
      } else if (userMessage.contains('CORS') ||
          userMessage.contains('cors') ||
          userMessage.contains('Cross-Origin') ||
          userMessage.contains('API URL') ||
          userMessage.contains('origin')) {
        userMessage =
            'Poor network connection. Please check your internet and try again.';
      } else if (userMessage.contains('Unauthorized') ||
          userMessage.contains('401')) {
        userMessage = 'Session expired. Please log in again.';
      } else if (userMessage.contains('Access denied') ||
          userMessage.contains('403')) {
        userMessage = 'You do not have access to this session.';
      } else if (userMessage.contains('createIrisApiEngine') ||
          userMessage.contains('undefined') ||
          userMessage.contains('iris-web-rtc')) {
        userMessage =
            'Unable to start video session. Please refresh the page and try again.';
      } else if (userMessage.contains('Failed to initialize')) {
        userMessage =
            'Unable to start video session. Please check your internet connection and try again.';
      } else if (userMessage.contains('permission') ||
          userMessage.contains('Permission') ||
          userMessage.contains('NotAllowedError') ||
          userMessage.contains('NotAllowed') ||
          userMessage.contains('Permission denied')) {
        userMessage =
            'Camera and Microphone Permission Required\n\n'
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
      } else if (userMessage.contains('localhost:3000') ||
          userMessage.contains('API URL') ||
          userMessage.contains('Check:')) {
        userMessage =
            'Poor network connection. Please check your internet and try again.';
      } else if (userMessage.contains('Something went wrong on our end')) {
        userMessage =
            'Something went wrong on our end. Please try again later.';
      } else if (userMessage.contains('Connection failed') ||
          userMessage.contains('Unable to connect') ||
          userMessage.contains('Connection timed out') ||
          userMessage.contains('Connection error')) {
        // Already user-friendly from token service
      } else if (userMessage.contains('Failed to') ||
          userMessage.contains('Error') ||
          userMessage.contains('Exception') ||
          userMessage.contains('http')) {
        userMessage =
            'Connection failed. Please check your internet and try again.';
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
      _sessionLocalSupabaseUserId = localUserId;
      final participantsFuture = _profileService.getSessionParticipants(
        widget.sessionId,
      );
      final bookingFuture = _profileService.getSessionBookingSummary(
        widget.sessionId,
      );

      _localProfile = await _profileService.getUserProfile(localUserId);

      final bundle = await participantsFuture;
      final booking = await bookingFuture;

      _sessionParticipantBundle = bundle;

      if (widget.userRole == 'tutor') {
        _remoteProfile = bundle.learnerProfile;
      } else {
        _remoteProfile = bundle.tutorProfile;
      }
      _sessionBookingSummary = booking;

      safeSetState(() {});
      if (mounted &&
          (_sessionState == AgoraSessionState.connected ||
              _sessionState == AgoraSessionState.reconnecting)) {
        unawaited(_ensureIncallChatRealtime());
      }
    } catch (e) {
      LogService.warning('Error loading profile data: $e');
    }
  }

  /// Profile row → display name + avatar for gallery / tiles.
  ({String name, String? avatarUrl}) _nameAvatarFromProfileMap(
    Map<String, dynamic> p, {
    String fallbackName = 'Participant',
  }) {
    final raw = (p['full_name'] as String?)?.trim();
    final name = raw != null && raw.isNotEmpty && raw != 'User'
        ? raw
        : fallbackName;
    final avatarUrl = p['avatar_url'] as String?;
    return (name: name, avatarUrl: avatarUrl);
  }

  /// When [uid] matches the server’s deterministic Agora UID for tutor, learner, or self.
  ({String name, String? avatarUrl})? _galleryRosterFaceForUid(int uid) {
    final bundle = _sessionParticipantBundle;
    if (bundle == null) return null;

    final sid = widget.sessionId;
    final localId = _sessionLocalSupabaseUserId;
    if (localId != null) {
      final rtcRole = widget.userRole == 'tutor' ? 'tutor' : 'learner';
      final expectedSelf = agoraNumericUidForSessionRole(
        sessionId: sid,
        userId: localId,
        role: rtcRole,
      );
      if (expectedSelf == uid && _localProfile != null) {
        return _nameAvatarFromProfileMap(_localProfile!, fallbackName: 'You');
      }
    }

    final tid = bundle.tutorUserId;
    if (tid != null) {
      final tUid = agoraNumericUidForSessionRole(
        sessionId: sid,
        userId: tid,
        role: 'tutor',
      );
      if (tUid == uid && bundle.tutorProfile != null) {
        return _nameAvatarFromProfileMap(bundle.tutorProfile!);
      }
    }

    final lid = bundle.learnerUserId;
    if (lid != null) {
      final lUid = agoraNumericUidForSessionRole(
        sessionId: sid,
        userId: lid,
        role: 'learner',
      );
      if (lUid == uid && bundle.learnerProfile != null) {
        return _nameAvatarFromProfileMap(bundle.learnerProfile!);
      }
    }

    return null;
  }

  ({String name, String? avatarUrl}) _spotlightDisplayForUid(int uid) {
    final roster = _galleryRosterFaceForUid(uid);
    if (roster != null) return roster;

    final localUid = _agoraService.currentUID;
    if (localUid != null && uid == localUid && _localProfile != null) {
      final raw = (_localProfile!['full_name'] as String?)?.trim();
      final name = raw != null && raw.isNotEmpty && raw != 'User' ? raw : 'You';
      return (name: name, avatarUrl: _localProfile!['avatar_url'] as String?);
    }

    if (uid == _remoteUID && _remoteProfile != null) {
      final raw = (_remoteProfile!['full_name'] as String?)?.trim();
      final name = raw != null && raw.isNotEmpty && raw != 'User'
          ? raw
          : 'Participant $uid';
      return (name: name, avatarUrl: _remoteProfile!['avatar_url'] as String?);
    }

    return (name: 'Participant $uid', avatarUrl: null);
  }

  /// Full-area Discord-style mute / waiting overlay for spotlight & side layouts (not gallery).
  Widget _buildSpotlightDiscordMuteShell({
    required int uid,
    required bool userLeft,
    required bool waitingForVideoFrame,
    required bool cameraOff,
    required bool screenOff,
    required bool audioMuted,
  }) {
    final face = _spotlightDisplayForUid(uid);
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildGalleryDiscordMutedFace(
          uid: uid,
          displayName: face.name,
          avatarUrl: face.avatarUrl,
          userLeft: userLeft,
          waitingForVideoFrame: waitingForVideoFrame,
          showCameraOffBadge: !userLeft && !waitingForVideoFrame && cameraOff,
          showScreenOffBadge:
              !userLeft && !waitingForVideoFrame && screenOff && !cameraOff,
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (audioMuted) ...[
                  Icon(
                    Icons.mic_off_rounded,
                    size: 14,
                    color: Colors.white.withOpacity(0.92),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    face.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Setup Agora event listeners
  void _setupListeners() {
    _startRecoveryHealthMonitor();
    _localCameraPublishingSubscription?.cancel();
    _localCameraPublishingSubscription = _agoraService
        .localCameraPublishingSignalStream
        .listen((_) {
          _audioOnlyFallbackTimer?.cancel();
          _audioOnlyFallbackTimer = null;
        });

    _stateSubscription = _agoraService.stateStream.listen((state) {
      if (state == AgoraSessionState.reconnecting) {
        _armReconnectStuckOfflineProbe();
      } else if (state == AgoraSessionState.connected) {
        _reconnectStuckOfflineProbeTimer?.cancel();
        _joinStuckOfflineProbeTimer?.cancel();
      }
      if (state == AgoraSessionState.connected ||
          state == AgoraSessionState.reconnecting) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_ensureIncallChatRealtime());
        });
      }
      if (state == AgoraSessionState.disconnected ||
          state == AgoraSessionState.leaving) {
        unawaited(_disposeIncallChatRealtime());
        if (mounted && _inCallChatOpen) {
          safeSetState(() => _inCallChatOpen = false);
        }
      }
      _scheduleUiUpdate(() {
        if (_sessionState == AgoraSessionState.joining &&
            state == AgoraSessionState.disconnected) {
          return;
        }
        _sessionState = state;
      });
      if (state != AgoraSessionState.connected) {
        _audioOnlyFallbackTimer?.cancel();
        _audioOnlyFallbackTimer = null;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _scheduleAudioOnlyFallbackIfNeeded();
        });
      }
    });

    _userJoinedSubscription = _agoraService.userJoinedStream.listen((uid) {
      LogService.info('👤 Remote user joined: UID=$uid');
      _remoteUnstableTimer?.cancel();
      _videoStateDebounceTimer?.cancel();
      _scheduleUiUpdate(() {
        final primaryBefore = _remoteUID;
        _remoteJoinedAt = DateTime.now();
        _lastRemoteActivityAt =
            DateTime.now(); // For mobile web "user left" timeout
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
        // Multiparty: keep spotlight/side-by-side "primary" remote stable while they
        // remain active; newest joiner used to overwrite _remoteUID and broke leave handling.
        final selfRtc = _agoraService.currentUID;
        final primaryStillPresent =
            primaryBefore != null &&
            selfRtc != primaryBefore &&
            (_participants[primaryBefore] != null &&
                !(_participants[primaryBefore]?.userLeft ?? true));
        if (primaryBefore == null || !primaryStillPresent) {
          _remoteUID = uid;
        }
        _lastRemoteUID = uid;
        _syncLegacyRemoteStateFromRegistry();
        final remoteCount = _galleryRemoteUids().length;
        if (remoteCount != _lastAppliedRemoteCountForLayout) {
          _lastAppliedRemoteCountForLayout = remoteCount;
          if (remoteCount >= 2) {
            _layout = VideoLayout.gallery;
          } else if (remoteCount == 1) {
            // Spotlight keeps a single remote in the video lane; workspace shell
            // can show teaching tools beside video (sideBySide hid the panel).
            _layout = VideoLayout.spotlight;
          } else {
            _layout = VideoLayout.spotlight;
          }
        }
        _soloWaitingSelfExpanded = false;
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
        LogService.info(
          '⏱️ Remote participant joined – starting shared session timer',
        );
        _timerStarted = true;
        _startSessionTimer();
      }

      // VA indicator is the small logo only; avoid popups for a clean call surface.
      if (!_vaJoinNotificationShown) {
        _vaJoinNotificationShown = true;
        LogService.info(
          'PrepSkul VA join notification suppressed (quiet call UX).',
        );
      }
    });

    _errorSubscription = _agoraService.errorStream.listen((error) {
      final userMessage = _toUserFriendlyError(error);
      final lowered = userMessage.toLowerCase();
      final isRecoverableConnectionIssue =
          lowered.contains('connection') ||
          lowered.contains('network') ||
          lowered.contains('internet') ||
          lowered.contains('timeout') ||
          lowered.contains('reconnecting') ||
          lowered.contains('resyncing');

      if ((_sessionState == AgoraSessionState.connected ||
              _sessionState == AgoraSessionState.joining ||
              _sessionState == AgoraSessionState.reconnecting) &&
          isRecoverableConnectionIssue) {
        LogService.info(
          '[CALL] Recoverable connection event (no UI popup): $userMessage',
        );
        return;
      }

      safeSetState(() {
        _errorMessage = userMessage;
        _sessionState = AgoraSessionState.error;
      });
    });

    // Remote video muted state - DEBOUNCED to prevent flickering; frame-ready is authoritative.
    _remoteVideoMutedSubscription = _agoraService.remoteVideoMutedStream.listen((
      data,
    ) {
      final uid = data['uid'] as int;
      final muted = data['muted'] as bool;
      if (uid == _remoteUID) {
        _lastRemoteVideoMutedState = muted;
        final debounceScheduledAt = DateTime.now();
        _scheduleUiUpdate(() {
          _upsertParticipant(uid, lastActivityAt: DateTime.now());
          _syncLegacyRemoteStateFromRegistry();
          _videoStateDebounceTimer?.cancel();
          final debounceDelay = kIsWeb
              ? const Duration(milliseconds: 650)
              : const Duration(milliseconds: 250);
          _videoStateDebounceTimer = Timer(debounceDelay, () {
            if (!mounted || uid != _remoteUID) return;
            _scheduleUiUpdate(() {
              final lastReady = _lastRemoteVideoReadyAt;
              final mutedSoonAfterReady =
                  muted &&
                  kIsWeb &&
                  lastReady != null &&
                  DateTime.now().difference(lastReady) <
                      const Duration(milliseconds: 1200);
              if (mutedSoonAfterReady) {
                // Web can briefly emit muted while frames are still flowing.
                return;
              }
              _upsertParticipant(uid, videoMuted: muted);
              // Only set ready=false if no frame-ready arrived after we scheduled this debounce
              if (muted) {
                if (lastReady == null ||
                    lastReady.isBefore(debounceScheduledAt)) {
                  _upsertParticipant(uid, videoReady: false);
                }
              }
              _syncLegacyRemoteStateFromRegistry();
            });
          });
        });
      }
    });

    _remoteVideoFrameSubscription = _agoraService.remoteVideoFrameStream.listen((
      data,
    ) {
      final uid = data['uid'] as int;
      final ready = data['ready'] as bool? ?? false;
      if (uid == _remoteUID) {
        final prevReady = _participants[uid]?.videoReady ?? false;
        // Agora can emit overlapping decode/start events; skip redundant ready bursts.
        if (prevReady && ready) {
          return;
        }
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
    _remoteAudioMutedSubscription = _agoraService.remoteAudioMutedStream.listen(
      (data) {
        final uid = data['uid'] as int;
        final muted = data['muted'] as bool;
        if (uid == _remoteUID) {
          _lastRemoteAudioMutedState = muted;
          _scheduleUiUpdate(() {
            _upsertParticipant(
              uid,
              audioMuted: muted,
              lastActivityAt: DateTime.now(),
            );
            _syncLegacyRemoteStateFromRegistry();
          });
        }
      },
    );

    // Screen sharing state (Realtime, data stream, or video-size telemetry).
    _screenSharingSubscription = _agoraService.screenSharingStream.listen((
      data,
    ) {
      final uid = data['uid'] as int;
      final sharing = data['sharing'] as bool;
      final ownerUid = data['ownerUid'] as int?;
      final myUid = _agoraService.currentUID;

      _scheduleUiUpdate(() {
        _screenShareOwnerUid = ownerUid;

        if (ownerUid == null) {
          for (final id in _participants.keys.toList()) {
            _upsertParticipant(id, screenSharing: false);
          }
          _isScreenSharing = false;
          _remoteIsScreenSharing = false;
        } else {
          for (final id in _participants.keys.toList()) {
            _upsertParticipant(id, screenSharing: id == ownerUid);
          }
          if (!_participants.containsKey(ownerUid) &&
              myUid != null &&
              ownerUid != myUid) {
            _upsertParticipant(
              ownerUid,
              screenSharing: true,
              userLeft: false,
              lastActivityAt: DateTime.now(),
            );
          }
          _isScreenSharing = myUid != null && ownerUid == myUid;
          _remoteIsScreenSharing = myUid != null && ownerUid == _remoteUID;
        }
        _syncLegacyRemoteStateFromRegistry();

        if (sharing &&
            myUid != null &&
            uid == myUid &&
            ownerUid == myUid &&
            mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            safeSetState(() {
              _screenShareLayoutPreset =
                  ScreenShareLayoutPreset.shareWithCompanionCameras;
            });
          });
        }
      });
    });

    // User left (after grace period + reconnection checks in AgoraService)
    _userLeftSubscription = _agoraService.userLeftStream.listen((uid) {
      // Web refresh race: old UID may leave after a new UID joined — accept any UID we
      // are still tracking in the roster (not only `_remoteUID` / `_lastRemoteUID`).
      final myUid = _agoraService.currentUID;
      if (myUid != null && uid == myUid) {
        return;
      }
      final tracked = _participants.containsKey(uid) ||
          uid == _remoteUID ||
          uid == _lastRemoteUID;
      if (!tracked) {
        LogService.info(
          'userLeftStream uid=$uid ignored (not tracked; current=$_remoteUID, '
          'last=$_lastRemoteUID, roster=${_participants.keys.toList()})',
        );
        return;
      }

      _applyAgoraRemoteUidLeaveConfirmed(uid, source: 'userLeftStream');
    });

    // Remote network quality (for instability detection)
    _remoteNetworkQualitySubscription = _agoraService.remoteNetworkQualityStream
        .listen((data) {
          final uid = data['uid'] as int;
          final isUnstable = data['isUnstable'] as bool? ?? false;

          if (uid == _remoteUID) {
            final now = DateTime.now();
            // Keep instability UI sticky for a short period to avoid rapid
            // unstable/stable flip-flop rendering on short network jitters.
            _remoteUnstableStickyUntil = isUnstable
                ? now.add(const Duration(seconds: 3))
                : now.add(const Duration(seconds: 2));
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
    _reactionSubscription = _agoraService.reactionStream.listen((data) {
      final uid = data['uid'] as int;
      final emoji = data['emoji'] as String;
      final myUid = _agoraService.currentUID ?? -1;
      // In 1:1 call, any reaction not from self is from the remote user - always show
      if (uid == myUid) return;
      // If _remoteUID not set (e.g. remote joined with camera/mic off), set it now
      if (_remoteUID == null) {
        safeSetState(() {
          _remoteUID = uid;
          _soloWaitingSelfExpanded = false;
          _upsertParticipant(
            uid,
            userLeft: false,
            lastActivityAt: DateTime.now(),
          );
          _syncLegacyRemoteStateFromRegistry();
        });
      }
      if (emoji == _kHandRaiseOnSignal || emoji == _kHandRaiseOffSignal) {
        final raised = emoji == _kHandRaiseOnSignal;
        final myUid = _agoraService.currentUID;
        safeSetState(() {
          if (raised) {
            _raisedHandUids.add(uid);
          } else {
            _raisedHandUids.remove(uid);
          }
          _remoteHandRaised = _raisedHandUids.any((id) => id != myUid);
        });
        if (raised && widget.userRole == 'tutor') {
          SystemSound.play(SystemSoundType.alert);
        }
        return;
      }
      LogService.info('🎉 Displaying remote reaction: $emoji from UID=$uid');
      _addReactionAnimation(emoji);
    });

    // Remote screen-off detection
    _remoteScreenOffSubscription = _agoraService.remoteScreenOffStream.listen((
      data,
    ) {
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
    // Speaking indicator (who is talking). Keep this set remote-focused to avoid
    // frequent whole-screen rebuilds from local voice bursts (video platform views can jitter).
    _speakingSubscription = _agoraService.speakingStream.listen((uids) {
      final localUid = _agoraService.currentUID;
      final normalized = Set<int>.from(uids);
      if (localUid != null && normalized.contains(0)) {
        normalized.remove(0);
        normalized.add(localUid);
      }
      if (localUid != null) {
        normalized.remove(localUid);
      }
      if (_speakingUids.length == normalized.length &&
          _speakingUids.containsAll(normalized) &&
          normalized.containsAll(_speakingUids)) {
        return;
      }
      _scheduleUiUpdate(() {
        _speakingUids = normalized;
      });
    });

    // Mic muted but local speech energy detected (Agora volume) — one gentle hint, cool-down in [AgoraService].
    _mutedMicSpeechHintSubscription = _agoraService.mutedMicSpeechHintStream
        .listen((_) {
          if (!mounted) return;
          final now = DateTime.now();
          if (_lastMutedMicHintUiAt != null &&
              now.difference(_lastMutedMicHintUiAt!) <
                  _mutedMicHintUiCooldown) {
            return;
          }
          _lastMutedMicHintUiAt = now;
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                'Your microphone is muted. Tap Unmute to speak.',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xE6141F36),
            ),
          );
        });

    // Recording failed - show non-blocking snackbar (skip on mobile web; we don't start recording there)
    if (!(kIsWeb && platform_utils.PlatformUtils.isMobileWeb)) {
      _recordingFailedSubscription = AgoraRecordingService.onRecordingFailed
          .listen((message) {
            LogService.warning('[Recording] $message');
            if (kDebugMode && mounted) {
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

    // Local connection state: track reconnecting for gating (no “connection restored” toasts).
    _connectionStateSubscription = _agoraService.connectionStateStream.listen((
      state,
    ) {
      final reconnecting =
          state ==
              agora_rtc_engine
                  .ConnectionStateType
                  .connectionStateReconnecting ||
          state ==
              agora_rtc_engine.ConnectionStateType.connectionStateConnecting;
      final connected =
          state ==
          agora_rtc_engine.ConnectionStateType.connectionStateConnected;
      if (reconnecting) {
        _armReconnectStuckOfflineProbe();
      }
      _scheduleUiUpdate(() {
        final now = DateTime.now();
        if (connected && _localConnectionReconnecting) {
          if (_isVideoEnabled && !_localVideoReady) {
            _ensureLocalPreviewActiveNow();
          }
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

    _setupCallConnectivityGuards();
  }

  /// Offline / stuck-reconnect: surface [OfflineDialog] instead of only deep-blue call chrome.
  void _setupCallConnectivityGuards() {
    _armJoinStuckOfflineProbeOnce();

    unawaited(() async {
      try {
        await _connectivity.initialize();
      } catch (e) {
        LogService.warning('Call connectivity monitor init failed: $e');
      }
      if (!mounted) return;

      var bootOnline = true;
      try {
        bootOnline = await _connectivity.checkConnectivity();
      } catch (e) {
        LogService.warning('Boot connectivity check failed: $e');
        bootOnline = false;
      }
      if (!mounted) return;
      _scheduleUiUpdate(() => _callConnectivityOnline = bootOnline);

      _callConnectivitySubscription = _connectivity.connectivityStream.listen((
        online,
      ) {
        if (!mounted) return;
        _scheduleUiUpdate(() => _callConnectivityOnline = online);
        if (!online) {
          _connectivityOfflineDebounce?.cancel();
          _connectivityOfflineDebounce = Timer(
            _kConnectivityOfflineDebounce,
            () async {
              if (!mounted) return;
              try {
                final ok = await _connectivity.checkConnectivity();
                if (ok || !mounted) return;
                await _presentInCallOfflineDialog();
              } catch (e) {
                LogService.warning('Connectivity recheck failed: $e');
              }
            },
          );
        } else {
          _connectivityOfflineDebounce?.cancel();
          unawaited(() async {
            if (!mounted) return;
            try {
              final ok = await _connectivity.checkConnectivity();
              if (!ok || !mounted) return;
            } catch (_) {
              return;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _dismissInCallOfflineDialogIfOpen();
            });
          }());
        }
      });

      if (!bootOnline && mounted) {
        await _presentInCallOfflineDialog();
      }
    }());
  }

  void _armJoinStuckOfflineProbeOnce() {
    _joinStuckOfflineProbeTimer?.cancel();
    _joinStuckOfflineProbeTimer = Timer(_kJoinStuckProbe, () async {
      if (!mounted) return;
      if (_sessionState != AgoraSessionState.joining) return;
      try {
        final online = await _connectivity.checkConnectivity();
        if (!online && mounted) {
          await _presentInCallOfflineDialog();
        }
      } catch (e) {
        LogService.warning('Join stuck connectivity probe failed: $e');
      }
    });
  }

  void _armReconnectStuckOfflineProbe() {
    _reconnectStuckOfflineProbeTimer?.cancel();
    _reconnectStuckOfflineProbeTimer = Timer(_kReconnectStuckProbe, () async {
      if (!mounted) return;
      final stuck =
          _sessionState == AgoraSessionState.reconnecting ||
          _localConnectionReconnecting;
      if (!stuck) return;
      try {
        final online = await _connectivity.checkConnectivity();
        if (!online && mounted) {
          await _presentInCallOfflineDialog();
        }
      } catch (e) {
        LogService.warning('Reconnect connectivity probe failed: $e');
      }
    });
  }

  Future<void> _presentInCallOfflineDialog() async {
    if (!mounted || _inCallOfflineDialogOpen) return;
    if (_sessionState == AgoraSessionState.leaving ||
        _showLeavingScreen ||
        _isEndingCall) {
      return;
    }
    final resumedAt = _lastLifecycleResumedAt;
    if (resumedAt != null &&
        DateTime.now().difference(resumedAt) < _kResumeReconnectGrace) {
      try {
        final online = await _connectivity.checkConnectivity();
        if (online || !mounted) return;
      } catch (_) {
        return;
      }
    }
    safeSetState(() {
      _inCallOfflineDialogOpen = true;
      _inCallOfflineCardOpen = true;
    });
  }

  /// Closes the branded offline sheet when connectivity is back (duplicate `OK` tap not required).
  void _dismissInCallOfflineDialogIfOpen() {
    if (!mounted || !_inCallOfflineDialogOpen) return;
    safeSetState(() {
      _inCallOfflineDialogOpen = false;
      _inCallOfflineCardOpen = false;
    });
  }

  /// Setup session timer
  void _setupTimer() {
    // Listen to time remaining updates
    _timeRemainingSubscription = _timerService.timeRemainingStream.listen((
      remaining,
    ) {
      safeSetState(() {
        _timeRemaining = remaining;
      });
    });

    // Listen to session ended events (auto-termination)
    _sessionEndedSubscription = _timerService.sessionEndedStream.listen((
      sessionId,
    ) {
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
          LogService.info(
            '⏱️ 30-minute trial session detected - using fixed 30 minute duration',
          );
        } else {
          LogService.info(
            '⏱️ Regular session - using config duration: ${AppConfig.sessionDurationMinutes} minutes',
          );
        }
      }

      // Resolve start time: use stored call_timer_started_at if set (sync on rejoin), else set and use now
      DateTime startTime = DateTime.now();
      try {
        final result = await _supabase.rpc(
          'ensure_call_timer_started',
          params: {'p_session_id': widget.sessionId},
        );
        if (result != null && result is String) {
          final parsed = DateTime.tryParse(result);
          if (parsed != null &&
              parsed.isBefore(DateTime.now()) &&
              parsed.isAfter(
                DateTime.now().subtract(const Duration(days: 1)),
              )) {
            startTime = parsed;
            LogService.info(
              '⏱️ Session timer synced to call_timer_started_at: $startTime',
            );
          }
        }
      } catch (rpcError) {
        LogService.warning(
          'ensure_call_timer_started RPC failed (using now): $rpcError',
        );
      }

      await _timerService.startSession(
        widget.sessionId,
        startTime: startTime,
        durationMinutes: durationMinutes,
      );
      LogService.info(
        '⏱️ Session timer started with duration: $durationMinutes minutes, startTime: $startTime',
      );
    } catch (e) {
      LogService.warning('Error starting session timer: $e');
      try {
        await _timerService.startSession(
          widget.sessionId,
          startTime: DateTime.now(),
          durationMinutes: AppConfig.sessionDurationMinutes,
        );
        LogService.info(
          '⏱️ Session timer started with fallback duration: ${AppConfig.sessionDurationMinutes} minutes',
        );
      } catch (e2) {
        LogService.error(
          'Failed to start session timer even with fallback: $e2',
        );
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

      LogService.info(
        '[SESSION] Local preview watchdog running – ensuring preview is active',
      );
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
          LogService.info(
            '[SESSION] Local preview watchdog reapplied preview successfully',
          );
        } catch (e) {
          LogService.warning('[SESSION] Local preview watchdog failed: $e');
        }
      });
    });
  }

  Future<void> _ensureLocalPreviewActiveNow({bool force = false}) async {
    if (_agoraService.engine == null || !_isVideoEnabled) return;
    if (_agoraService.isPublishingScreen && !_localScreenShareCapturing) {
      return;
    }
    if (_localPreviewEnsureInProgress) return;
    final now = DateTime.now();
    final isMobileWeb = kIsWeb && platform_utils.PlatformUtils.isMobileWeb;
    if (!force &&
        _localVideoReady &&
        _lastLocalPreviewEnsureAt != null &&
        now.difference(_lastLocalPreviewEnsureAt!) <
            const Duration(seconds: 8)) {
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
    if (!_agoraService.isInChannel) {
      LogService.debug('[VIDEO_TOGGLE] skipped: not in channel');
      return;
    }
    if (_localScreenShareCapturing) {
      final newEnabled = !_isVideoEnabled;
      try {
        await _agoraService.setLocalVideoPreviewEnabledDuringScreenShare(
          newEnabled,
        );
        if (mounted) {
          safeSetState(() => _isVideoEnabled = newEnabled);
        } else {
          _isVideoEnabled = newEnabled;
        }

        if (newEnabled) {
          await _ensureLocalPreviewActiveNow(force: true);
          _scheduleAudioOnlyFallbackIfNeeded();
        }
      } catch (_) {
        _showSnackBar('Could not update camera preview during share.');
      }
      return;
    }
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
              _scheduleAudioOnlyFallbackIfNeeded();
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

  /// Dev-only tracing for web video mute; never show raw state in a SnackBar (looks like bugs to users).
  void _showVideoMuteDiagnostic(String? error) {
    if (!AppConfig.enableSessionCameraPublishing) return;
    if (!mounted || !kIsWeb || !kDebugMode) return;
    final msg = error != null
        ? 'Video mute error: $error'
        : 'Video ${_isVideoEnabled ? "on" : "off"}. remoteUID=$_remoteUID, remoteLeft=$_remoteUserLeft';
    LogService.debug('[WEB_VIDEO_MUTE_DIAG] $msg');
  }

  /// Send current camera state to remote user via data channel
  /// This is a fallback for when onRemoteVideoStateChanged doesn't fire reliably
  void _sendCameraStateToRemote() {
    _agoraService.sendCameraState(_isVideoEnabled);
  }

  /// Toggle audio (microphone)
  /// Defers setState to next frame to avoid UI disappearing on mobile web when tapping control.
  Future<void> _toggleAudio() async {
    if (!_agoraService.isInChannel) {
      LogService.debug('[AUDIO_TOGGLE] skipped: not in channel');
      return;
    }
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
      if (_localScreenShareCapturing) {
        // Optimistic UI clear so the dock/state immediately reflects "not sharing"
        // while Agora + browser tear down capture tracks.
        if (mounted) {
          safeSetState(() {
            _isScreenSharing = false;
            _screenShareOwnerUid = null;
            _remoteIsScreenSharing = false;
          });
        }
        await _agoraService.stopScreenSharing();
        return;
      }
      if (!_canStartScreenShareFromThisDevice) return;
      if (!_agoraService.isInChannel) {
        LogService.info(
          '[SESSION] Screen share skipped: not in channel (wait until connected)',
        );
        return;
      }
      await _agoraService.startScreenSharing();
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      final isUserCancel =
          (errorStr.contains('user') &&
              (errorStr.contains('cancel') || errorStr.contains('canceled'))) ||
          errorStr.contains('canceled') ||
          errorStr.contains('cancelled') ||
          errorStr.contains('abort');
      final isPermissionDenied =
          errorStr.contains('notallowed') ||
          errorStr.contains('not allowed') ||
          errorStr.contains('permission') ||
          errorStr.contains('denied');
      final isNotSupported =
          errorStr.contains('notsupported') ||
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

      if (errorStr.contains('not in channel') ||
          errorStr.contains('engine not initialized')) {
        LogService.info(
          '[SESSION] Screen sharing unavailable until connected: $e',
        );
        return;
      }

      LogService.warning('[SESSION] Screen sharing error: $e');
    }
  }

  /// Show message when screen share is not supported (iOS Safari)
  void _showIosScreenShareUnsupportedMessage() {
    if (!mounted || _isTearingDownUi) return;
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
        content: Text(message, style: GoogleFonts.poppins(fontSize: 14)),
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

  Future<void> _toggleHandRaise() async {
    final nextRaised = !_localHandRaised;
    safeSetState(() {
      _localHandRaised = nextRaised;
    });
    try {
      await _agoraService.sendReaction(
        nextRaised ? _kHandRaiseOnSignal : _kHandRaiseOffSignal,
      );
      final myUid = _agoraService.currentUID;
      if (myUid != null) {
        safeSetState(() {
          if (nextRaised) {
            _raisedHandUids.add(myUid);
          } else {
            _raisedHandUids.remove(myUid);
          }
          _remoteHandRaised = _raisedHandUids.any((id) => id != myUid);
        });
      }
      if (nextRaised) {
        _addReactionAnimation('🙋');
      }
    } catch (e) {
      LogService.warning('Failed to sync hand raise state: $e');
      if (!mounted) return;
      safeSetState(() {
        _localHandRaised = !nextRaised;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'Could not update hand raise. Please try again.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
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

  /// Web: release RTC engine after routes/dialogs settle — avoids capture LED staying on and
  /// reduces races with platform-view teardown (see dispose safety net).
  void _scheduleDeferredWebEngineRelease() {
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await _agoraService.releaseEngineAfterLeave();
          LogService.info(
            '✅ Agora engine released after leave (web, deferred)',
          );
        } catch (e) {
          LogService.warning('Web deferred engine release: $e');
        }
      });
    });
  }

  String _lessonInviteClipboardText() {
    final peer = widget.userRole == 'tutor' ? 'learner' : 'tutor';
    final lines = <String>[
      'PrepSkul live lesson',
      'Session ID: ${widget.sessionId}',
      if (widget.userRole == 'tutor')
        'Ask your $peer to open PrepSkul → My Sessions and join this lesson when it appears.'
      else
        'Tell your tutor you are in PrepSkul and ready — they join from Tutor → Sessions.',
    ];
    if (kIsWeb) {
      final base = '${Uri.base.origin}${Uri.base.path}';
      lines.add('Lesson tab: $base');
    }
    lines.add('Keep this PrepSkul tab open until the other person joins.');
    return lines.join('\n');
  }

  Future<void> _copyLessonInviteToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _lessonInviteClipboardText()));
    if (!mounted) return;
    final peer = widget.userRole == 'tutor' ? 'learner' : 'tutor';
    _showSnackBar('Copied invite text — paste to your $peer');
  }

  Future<void> _shareLessonInvite() async {
    try {
      await Share.share(
        _lessonInviteClipboardText(),
        subject: 'PrepSkul lesson',
      );
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Could not open share sheet');
    }
  }

  Future<void> _showInviteLearnerSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Invite your learner',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Share this lesson from PrepSkul so your learner can join quickly.',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _shareLessonInvite();
                },
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(
                  'Share lesson invite',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _copyLessonInviteToClipboard();
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(
                  'Copy invite text',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTutorTalkTimeSheet() async {
    if (!mounted) return;
    final snap = _agoraService.talkTimeSnapshot;
    if (snap.samples < 12 || snap.totalMs < 12000) {
      _showSnackBar('Talk time will appear after a little more conversation.');
      return;
    }
    final youPct = (snap.localShare * 100).round().clamp(0, 100);
    final themPct = (snap.remoteShare * 100).round().clamp(0, 100);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Talk time',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Use this as a gentle balance cue during one-on-one lessons.',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildTalkTimeRow(
                label: 'You',
                value: youPct,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 10),
              _buildTalkTimeRow(
                label: 'Learner',
                value: themPct,
                color: const Color(0xFF78D6FF),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTalkTimeRow({
    required String label,
    required int value,
    required Color color,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 10,
              color: color,
              backgroundColor: Colors.white12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$value%',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _reportClassroomIssue() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report issue',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Use this when something affects your lesson quality or safety.',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFE8EEF9),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Examples: audio/video quality issues, sync problems, unexpected disconnections, missing tools, or inappropriate behavior.',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFC9D6E9),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await WhatsAppSupportService.openWhatsApp(
                      context: 'general_support',
                      additionalInfo:
                          'Classroom report.\nSession: ${widget.sessionId}\nRole: ${widget.userRole}',
                    );
                  } catch (_) {
                    _showSnackBar('Could not open support.');
                  }
                },
                child: Text(
                  'Contact support',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
          title: Text(
            'Leave session?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
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
              child: Text(
                'Leave',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        _isEndingCall = false;
        return;
      }
    }

    _isTearingDownUi = true;

    // Full-screen "Leaving..." overlay – fully opaque so no profile or "Waiting for..." shows behind
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: _kSoftDark,
        builder: (context) => Dialog(
          backgroundColor: _kSoftDark,
          insetPadding: EdgeInsets.zero,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: _buildCallTransitionSurface(
              title: 'Leaving call',
              subtitle: 'Wrapping up your session safely...',
              icon: Icons.call_end_rounded,
              accentColor: const Color(0xFFF97316),
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
        _explicitCallCleanupDone = true;
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
          await SessionLifecycleService.endSession(widget.sessionId).timeout(
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

      // Step 5b — Release native/WebRTC capture. Mobile releases here; web defers two frames after
      // dialogs/routes unwind so platform views aren't torn down mid-render (window.dart asserts).
      if (!kIsWeb) {
        try {
          await _agoraService.releaseEngineAfterLeave();
          LogService.info('✅ Agora engine released after leave');
        } catch (e) {
          LogService.warning('Error releasing engine (continuing): $e');
        }
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
          _scheduleDeferredWebEngineRelease();
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
          _scheduleDeferredWebEngineRelease();
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
    if (!mounted || _isTearingDownUi) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
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
                  bottom: Theme.of(context).platform == TargetPlatform.android
                      ? false
                      : true,
                  child: TooltipVisibility(
                    visible: !_isTearingDownUi,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Keep video + workspace above the bottom control bar (layout + web platform-view z-order).
                        Padding(
                          padding: EdgeInsets.only(
                            top: _kCallTopChromeReserveHeight(
                              MediaQuery.of(context),
                            ),
                            bottom: _kCallControlBarReserveHeight(
                              MediaQuery.of(context),
                            ),
                          ),
                          child: _buildSessionBody(),
                        ),
                        _buildConnectionOverlay(),
                        if (_inCallOfflineCardOpen)
                          _buildCallTransitionSurface(
                            title: 'Reconnecting…',
                            subtitle:
                                'No internet connection. Reconnect to restore video.',
                            icon: Icons.wifi_off_rounded,
                            accentColor: Colors.orangeAccent,
                          ),
                        _buildWorkspaceTeachingRail(),
                        if (_shouldShowDraggableParticipantStrip(
                              MediaQuery.of(context),
                            ) &&
                            !_narrowOverlayChatMode(MediaQuery.of(context)))
                          _buildDraggableParticipantStrip(),
                        // In narrow overlay-chat mode, keep the stage clear:
                        // participant strip + PiP are hidden to avoid covering composer/CTAs.
                        ..._reactionAnimations,
                        // Status/control bar: on mobile web render IN the Stack so they stay visible.
                        // Listener with opaque ensures this overlay is in the hit-test path on web (platform view
                        // can steal focus otherwise; opaque makes overlay receive taps so buttons work).
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [_buildStatusBar(), _buildControlBar()],
                            ),
                          ),
                        ),
                        // In-call chat must sit ABOVE web PointerInterceptor so Send / composer receive taps.
                        if (_inCallChatOpen &&
                            !_embeddedIncallChatRailVisible(
                              MediaQuery.of(context),
                            ))
                          Positioned(
                            left: 0,
                            right: 0,
                            top: _narrowOverlayChatMode(MediaQuery.of(context))
                                ? 0
                                : _kCallTopChromeReserveHeight(
                                    MediaQuery.of(context),
                                  ),
                            bottom:
                                (_narrowOverlayChatMode(MediaQuery.of(context))
                                ? 0.0
                                : _kCallControlBarReserveHeight(
                                    MediaQuery.of(context),
                                  )),
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final mq = MediaQuery.of(context);
                                final narrowOverlay = _narrowOverlayChatMode(mq);
                                Widget chatBody() {
                                  final chatUserId =
                                      _sessionLocalSupabaseUserId ??
                                      SupabaseService
                                          .client
                                          .auth
                                          .currentUser
                                          ?.id ??
                                      '';
                                  if (_incallChat == null ||
                                      chatUserId.isEmpty) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white54,
                                      ),
                                    );
                                  }
                                  return IncallChatPanel(
                                    sync: _incallChat!,
                                    localUserId: chatUserId,
                                    localDisplayName:
                                        _localDisplayNameForChat(),
                                    peerLabel: _chatPeerLabel(),
                                    railMode: false,
                                    onClose: _closeIncallChatPanel,
                                  );
                                }

                                final sheet = Material(
                                  color: const Color(0xF20F1A2E),
                                  child: chatBody(),
                                );
                                if (narrowOverlay) return sheet;
                                final maxW = min(
                                  _kIncallChatOverlayMaxWidth,
                                  box.maxWidth,
                                );
                                return Align(
                                  alignment: Alignment.bottomCenter,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: maxW),
                                    child: sheet,
                                  ),
                                );
                              },
                            ),
                          ),
                        // Keep global blocking overlays ABOVE status/control layer so
                        // their buttons (e.g. Retry) always receive taps.
                        if (_errorMessage != null) _buildErrorOverlay(),
                        if (_sessionState == AgoraSessionState.joining)
                          _buildLoadingOverlay(),
                        if (_showReactionsPanel) _buildReactionsPanel(),
                      ],
                    ),
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
      final now = DateTime.now();
      if (_lastMainAreaDiagnosticAt == null ||
          now.difference(_lastMainAreaDiagnosticAt!) >
              const Duration(seconds: 2)) {
        _lastMainAreaDiagnosticAt = now;
        LogService.info(
          '📺 [MAIN_AREA] state=$_sessionState remoteUID=$_remoteUID remoteLeft=$_remoteUserLeft '
          'videoMuted=$_remoteVideoMuted isVideoEnabled=$_isVideoEnabled localVideoReady=$_localVideoReady '
          'engine=${engine != null} isJoining=$isJoining',
        );
      }
    }
    if (engine == null || isJoining) {
      return Container(color: _kSoftDark);
    }

    // CRITICAL: Check if remote user left FIRST before showing screen sharing
    // This ensures we show profile card instead of blank screen after user leaves during screen share
    if (_remoteUserLeft && _anyScreenShareActive) {
      return Container(color: _kSoftDark, child: _buildPeerLeftMainState());
    }

    // If screen sharing is active, show screen share (not camera video)
    if (_anyScreenShareActive) {
      final sharingUid = _resolvedScreenSharePublisherUid();
      final isLocalSharing =
          sharingUid != null && sharingUid == _agoraService.currentUID;
      if (sharingUid != null && !_screenShareSharerMarkedGone(sharingUid)) {
        final now = DateTime.now();
        if (_lastMainAreaDiagnosticAt == null ||
            now.difference(_lastMainAreaDiagnosticAt!) >
                const Duration(seconds: 2)) {
          _lastMainAreaDiagnosticAt = now;
          LogService.info(
            '📺 [ScreenShare] Showing screen share view: UID=$sharingUid, isLocal=$isLocalSharing, platform=${kIsWeb ? "web" : "mobile"}',
          );
        }
        return SizedBox.expand(
          child: _buildScreenShareStageWithOptionalCompanions(
            engine,
            sharingUid,
            isLocalSharing,
          ),
        );
      }
      // Keep a neutral bridging placeholder while share flags are active but owner
      // is still settling; avoid camera fallback that can look zoomed/cropped.
      LogService.warning(
        '⚠️ [ScreenShare] Active but unresolved publisher UID: '
        '_isScreenSharing=$_isScreenSharing _remoteIsScreenSharing=$_remoteIsScreenSharing '
        '_anyShare=$_anyScreenShareActive owner=$_screenShareOwnerUid '
        'remoteUID=$_remoteUID currentUID=${_agoraService.currentUID} remoteLeft=$_remoteUserLeft',
      );
      return SizedBox.expand(
        child: _buildScreenShareBridgingPlaceholder(
          localIsPresenter: _localScreenShareCapturing,
        ),
      );
    }

    // Screen-share stream must take precedence over layout mode (spotlight/side-by-side/gallery)
    // to avoid mounting competing local camera and local screen sources at the same time.
    if (_layout == VideoLayout.gallery) {
      return _buildGalleryLayout();
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

    // If remote user joined: show their video only when unmuted; when muted show only their profile (no black video behind)
    // CRITICAL: When _remoteUID != null && !_remoteUserLeft, main area must show REMOTE only (never local).
    // Key is stable and does not depend on local _isVideoEnabled so toggling own camera on web does not swap views.
    // On mobile web: always keep main area on remote (or profile) when remote is present so that turning off
    // local camera never produces a blank screen or full-screen local view; overlay (timer, controls) stays visible.
    if (_remoteUID != null && !_remoteUserLeft) {
      final connection = _agoraService.currentConnection;
      // Overlay when frame not ready, camera off, or poor network so we never show a frozen/black video surface.
      final showRemoteOverlay =
          _remoteVideoMuted ||
          !_remoteVideoReady ||
          _remoteScreenOff ||
          connection == null;

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
                child: _remoteUID != null
                    ? _buildSpotlightDiscordMuteShell(
                        uid: _remoteUID!,
                        userLeft: false,
                        waitingForVideoFrame:
                            connection == null ||
                            (!_remoteVideoReady &&
                                !_remoteVideoMuted &&
                                !_remoteScreenOff),
                        cameraOff: _remoteVideoMuted,
                        screenOff: _remoteScreenOff,
                        audioMuted: _remoteAudioMuted,
                      )
                    : Container(color: _kSoftDark),
              ),
            ),
          ],
        ),
      );
    }

    // If remote user left: calm empty state (no waiting ring / duplicate copy).
    if (_remoteUserLeft) {
      LogService.info('📺 [UI] Main area REMOTE_LEFT: peer-left empty state');
      return Container(color: _kSoftDark, child: _buildPeerLeftMainState());
    }

    // When alone: show self (video or profile) WITH "waiting for" overlay.
    // Include joining/reconnecting so local preview can render while the channel
    // handshake finishes (otherwise users only see the avatar placeholder).
    if (_remoteUID == null &&
        !_remoteUserLeft &&
        (_sessionState == AgoraSessionState.connected ||
            _sessionState == AgoraSessionState.joining ||
            _sessionState == AgoraSessionState.reconnecting)) {
      final now = DateTime.now();
      if (_lastWaitingLocalMainAreaLogAt == null ||
          now.difference(_lastWaitingLocalMainAreaLogAt!) >
              const Duration(seconds: 8)) {
        _lastWaitingLocalMainAreaLogAt = now;
        LogService.info(
          '📺 [UI] Main area showing LOCAL (waiting for remote): remoteUID=null, remoteUserLeft=$_remoteUserLeft, isVideoEnabled=$_isVideoEnabled',
        );
      }
      if (_shouldUseSoloWaitingHeroLayout()) {
        if (_soloWaitingSelfExpanded && _agoraService.currentUID != null) {
          return _buildSoloWaitingExpandedLocalMain(engine);
        }
        return _buildSoloWaitingHeroMain();
      }
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
    return Container(color: _kSoftDark, child: _buildWaitingPlaceholder());
  }

  /// Local presenter: footer so large screens aren't an unexplained black void while the capture warms up.
  /// Narrow widths keep the prominent banner + Stop; wide widths use a slimmer strip (controls still include Stop share).
  Widget _wrapLocalScreenShareStatusChrome({
    required BuildContext context,
    required bool isLocalSharing,
    required Widget child,
  }) {
    if (!isLocalSharing || !_localScreenShareCapturing) return child;
    final narrow =
        MediaQuery.sizeOf(context).width <
        _kScreenShareCompanionSidebarBreakpoint;
    final peer = widget.userRole == 'tutor' ? 'your learner' : 'your tutor';
    final msg = _remoteUID != null && !_remoteUserLeft
        ? 'You\'re sharing your screen with $peer.'
        : 'You\'re sharing your screen.';
    final hPad = narrow ? 14.0 : 24.0;
    Widget overlay;
    if (narrow) {
      overlay = DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xB30F1A2E), Color(0xA80B1426)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                msg,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryDark,
                ),
                onPressed: _controlsEnabled ? _toggleScreenSharing : null,
                icon: Icon(
                  Icons.stop_screen_share,
                  color: AppTheme.primaryDark,
                ),
                label: Text(
                  'Stop sharing',
                  style: GoogleFonts.poppins(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      overlay = DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x960F1A2E), Color(0x7A0B1426)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Icon(
                Icons.cast_rounded,
                size: 20,
                color: Colors.white.withOpacity(0.88),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 12.8,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _controlsEnabled ? _toggleScreenSharing : null,
                icon: Icon(
                  Icons.stop_screen_share_rounded,
                  size: 20,
                  color: Colors.white.withOpacity(0.95),
                ),
                label: Text(
                  'Stop',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 10),
              child: overlay,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenShareBridgingPlaceholder({
    required bool localIsPresenter,
  }) {
    final title = localIsPresenter
        ? 'Preparing your screen share…'
        : 'Receiving screen share…';
    final detail = localIsPresenter
        ? 'Complete your browser\'s picker and allow capture. Preview can stay dark for a moment until frames arrive.'
        : 'Connecting…';
    return Container(
      color: _kSoftDark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.92),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_localScreenShareCapturing)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryDark,
                      ),
                      onPressed: _controlsEnabled ? _toggleScreenSharing : null,
                      icon: Icon(
                        Icons.stop_screen_share_rounded,
                        color: AppTheme.primaryDark,
                      ),
                      label: Text(
                        'Stop sharing',
                        style: GoogleFonts.poppins(
                          color: AppTheme.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Primary screen-share surface (`sourceScreen`) optionally paired with companion camera tiles (Preply v1 preset).
  Widget _buildScreenShareStageWithOptionalCompanions(
    agora_rtc_engine.RtcEngine engine,
    int sharingUid,
    bool isLocalSharing,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Let Agora [renderModeFit] letterbox inside the stage — avoid a fixed 16:9
        // inner box so local preview and remote viewers see the same framing.
        final softenPhoneShareStage =
            constraints.maxWidth < _kScreenShareCompanionSidebarBreakpoint;
        final stageBorder = Border.all(color: Colors.white24, width: 1);
        final stageDecoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: softenPhoneShareStage
                ? const [
                    Color(0xFF0E1A2F),
                    Color(0xFF0B1426),
                    Color(0xFF050A12),
                  ]
                : const [
                    Color(0xFF0A1222),
                    Color(0xFF050A12),
                    Color(0xFF000000),
                  ],
          ),
          border: stageBorder,
        );

        final stage = Container(
          decoration: stageDecoration,
          child: SizedBox.expand(
            child: agora_widget.AgoraVideoViewWidget(
              key: ValueKey('screen_stage_$sharingUid'),
              engine: engine,
              uid: sharingUid,
              isLocal: isLocalSharing,
              connection: _agoraService.currentConnection,
              sourceType: agora_rtc_engine.VideoSourceType.videoSourceScreen,
            ),
          ),
        );

        if (_screenShareLayoutPreset == ScreenShareLayoutPreset.stageOnly) {
          return _wrapLocalScreenShareStatusChrome(
            context: context,
            isLocalSharing: isLocalSharing,
            child: stage,
          );
        }

        final remoteAvailable = _remoteUID != null && !_remoteUserLeft;
        final webHidesPresenterCamWhileSharing =
            kIsWeb && _localScreenShareCapturing;
        final localCamAvailable =
            !webHidesPresenterCamWhileSharing &&
            (_isVideoEnabled && _localVideoReady);
        final hasAnyCompanionFace =
            remoteAvailable ||
            (_agoraService.currentUID != null && localCamAvailable);

        if (!hasAnyCompanionFace) {
          return _wrapLocalScreenShareStatusChrome(
            context: context,
            isLocalSharing: isLocalSharing,
            child: stage,
          );
        }

        // Meet-style: companion strip + main share stage (phones get a narrower rail).
        final narrowLane =
            constraints.maxWidth < _kScreenShareCompanionSidebarBreakpoint;
        final sidebarWidth = min(
          _kScreenShareSidebarWidthCap,
          narrowLane
              ? (constraints.maxWidth * 0.36).clamp(112.0, 200.0)
              : constraints.maxWidth * _kScreenShareSidebarWidthFractionOfLane,
        ).clamp(112.0, _kScreenShareSidebarWidthCap);

        if (narrowLane) {
          final companionHeight = min(300.0, constraints.maxHeight * 0.42);
          return _wrapLocalScreenShareStatusChrome(
            context: context,
            isLocalSharing: isLocalSharing,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: stage),
                SizedBox(
                  height: companionHeight,
                  child: _screenShareCompanionRail(
                    context,
                    engine,
                    remoteAvailable: remoteAvailable,
                    localCamAvailable: localCamAvailable,
                    verticalLayout: true,
                  ),
                ),
              ],
            ),
          );
        }

        return _wrapLocalScreenShareStatusChrome(
          context: context,
          isLocalSharing: isLocalSharing,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: sidebarWidth,
                child: _screenShareCompanionRail(
                  context,
                  engine,
                  remoteAvailable: remoteAvailable,
                  localCamAvailable: localCamAvailable,
                ),
              ),
              Expanded(child: stage),
            ],
          ),
        );
      },
    );
  }

  Widget _screenShareCompanionRail(
    BuildContext context,
    agora_rtc_engine.RtcEngine engine, {
    required bool remoteAvailable,
    required bool localCamAvailable,
    bool verticalLayout = false,
  }) {
    final connection = _agoraService.currentConnection;
    Widget tile({required Widget child}) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(aspectRatio: 16 / 9, child: child),
        ),
      );
    }

    Widget remoteMini() {
      if (!remoteAvailable || connection == null) {
        return const SizedBox.shrink();
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: _kSoftDark,
            child: _wrapWithSpeakingIndicator(
              SizedBox.expand(
                child: agora_widget.AgoraVideoViewWidget(
                  key: ValueKey('companion_remote_${_remoteUID}_camera'),
                  engine: engine,
                  uid: _remoteUID!,
                  isLocal: false,
                  connection: connection,
                  sourceType:
                      agora_rtc_engine.VideoSourceType.videoSourceCamera,
                ),
              ),
              _remoteUID,
            ),
          ),
          if (_remoteVideoMuted || !_remoteVideoReady || _remoteScreenOff)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.58),
                ),
                child: Center(
                  child: Icon(
                    Icons.videocam_off_rounded,
                    color: Colors.white.withOpacity(0.76),
                    size: 38,
                  ),
                ),
              ),
            ),
          _screenShareCompanionNameHint(context, _remoteCompanionLabel()),
        ],
      );
    }

    Widget localMini() {
      final uid = _agoraService.currentUID;
      if (uid == null || !localCamAvailable || connection == null) {
        return const SizedBox.shrink();
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: _kSoftDark,
            child: _wrapWithSpeakingIndicator(
              SizedBox.expand(
                child: agora_widget.AgoraVideoViewWidget(
                  key: ValueKey('companion_local_${uid}_camera'),
                  engine: engine,
                  uid: uid,
                  isLocal: true,
                  connection: connection,
                  sourceType:
                      agora_rtc_engine.VideoSourceType.videoSourceCamera,
                ),
              ),
              uid,
            ),
          ),
          _screenShareCompanionNameHint(context, 'You'),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.32),
        border: Border(
          right: verticalLayout
              ? BorderSide.none
              : BorderSide(color: Colors.white.withOpacity(0.12)),
          top: verticalLayout
              ? BorderSide(color: Colors.white.withOpacity(0.12))
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (remoteAvailable && localCamAvailable) ...[
            Expanded(child: tile(child: remoteMini())),
            Expanded(child: tile(child: localMini())),
          ] else if (remoteAvailable)
            Expanded(child: tile(child: remoteMini()))
          else if (localCamAvailable)
            Expanded(child: tile(child: localMini()))
          else
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Companion camera lanes appear once at least one video feed is available.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          if (kIsWeb && _localScreenShareCapturing && widget.userRole == 'tutor')
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Text(
                'Browsers hide your selfie camera beside your screen capture — your learner still hears you and sees the shared content.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  height: 1.35,
                  color: Colors.white38,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Label for companion rail / bubble describing the peer’s camera lane.
  String _remoteCompanionLabel() {
    final base = widget.userRole == 'tutor' ? 'Learner' : 'Tutor';
    final name = (_remoteProfile?['full_name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return base;
    return name;
  }

  Widget _screenShareCompanionNameHint(
    BuildContext context,
    String text, {
    bool compact = false,
  }) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.all(compact ? 6 : 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.48),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 7 : 8,
              vertical: 4,
            ),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.92),
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _shareLayoutPresetMenuIcon() {
    final menuTheme = Theme.of(context).copyWith(
      canvasColor: const Color(0xEE141F36),
      colorScheme: Theme.of(context).colorScheme.copyWith(
        onSurface: Colors.white,
        surface: const Color(0xEE141F36),
        primary: Colors.white,
        onPrimary: AppTheme.primaryDark,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white38;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
      ),
    );
    return Theme(
      data: menuTheme,
      child: PopupMenuButton<ScreenShareLayoutPreset>(
        tooltip: 'Share layout',
        padding: EdgeInsets.zero,
        color: const Color(0xEE141F36),
        elevation: 8,
        onSelected: (v) {
          safeSetState(() => _screenShareLayoutPreset = v);
        },
        offset: const Offset(0, 44),
        itemBuilder: (context) => <PopupMenuEntry<ScreenShareLayoutPreset>>[
          CheckedPopupMenuItem<ScreenShareLayoutPreset>(
            value: ScreenShareLayoutPreset.stageOnly,
            checked:
                _screenShareLayoutPreset == ScreenShareLayoutPreset.stageOnly,
            child: Row(
              children: [
                const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Fullscreen share',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
          ),
          CheckedPopupMenuItem<ScreenShareLayoutPreset>(
            value: ScreenShareLayoutPreset.shareWithCompanionCameras,
            checked:
                _screenShareLayoutPreset ==
                ScreenShareLayoutPreset.shareWithCompanionCameras,
            child: Row(
              children: [
                const Icon(
                  Icons.view_sidebar_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  'Share + cameras',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kGlassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kGlassBorder.withOpacity(0.7)),
          ),
          child: const Icon(
            Icons.horizontal_split_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  /// Optional subtle speaking indicator: ring is painted as an overlay so the video
  /// layout bounds never change (avoids resize "shake" when VAD toggles on Android).
  Widget _wrapWithSpeakingIndicator(Widget child, int? uid) {
    final isLocal = uid == _agoraService.currentUID;
    final isSpeaking =
        uid != null &&
        _speakingUids.contains(uid) &&
        (isLocal
            ? _isAudioEnabled
            : true); // Don't show "you're speaking" when muted
    if (!isSpeaking) return child;
    final accent = AppTheme.primaryColor.withOpacity(0.75);
    const radius = BorderRadius.all(Radius.circular(12));
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: accent.withOpacity(0.55),
                  width: 1.25,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Stable remote surface: keeps the same widget structure and fades overlay
  /// in/out instead of replacing entire branches on transient state changes.
  Widget _buildStableRemoteSurface({
    required agora_rtc_engine.RtcEngine engine,
    required int remoteUid,
    required agora_rtc_engine.RtcConnection? connection,
    bool forceOverlay = false,
  }) {
    final showOverlay =
        forceOverlay ||
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
              child: _buildSpotlightDiscordMuteShell(
                uid: remoteUid,
                userLeft: _remoteUserLeft,
                waitingForVideoFrame:
                    !_remoteUserLeft &&
                    (connection == null ||
                        (!_remoteVideoReady &&
                            !_remoteVideoMuted &&
                            !_remoteScreenOff)),
                cameraOff: _remoteVideoMuted,
                screenOff: _remoteScreenOff,
                audioMuted: _remoteAudioMuted,
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
    final showReconnectOverlay =
        _localConnectionReconnecting && _sustainedCallDegradation;
    final webShareHidesSelfCamera =
        _webSecondLocalCameraPreviewBreaksScreenShare;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasReadyVideo && !webShareHidesSelfCamera)
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
          else if (hasReadyVideo && webShareHidesSelfCamera)
            Container(
              color: _kSoftDark,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.screen_share_outlined,
                      color: Colors.white.withOpacity(0.45),
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Self-view is hidden while sharing on this browser',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (showLoading)
            Container(
              color: _kSoftDark,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white70),
                    const SizedBox(height: 14),
                    Text(
                      'Starting camera…',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildSpotlightDiscordMuteShell(
              uid: localUid,
              userLeft: false,
              waitingForVideoFrame: false,
              cameraOff: !_isVideoEnabled,
              screenOff: false,
              audioMuted: !_isAudioEnabled,
            ),
          if (showReconnectOverlay)
            IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity(0.32),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Reconnecting…',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Waiting state is communicated by top banner + minimal reconnect overlay.
        ],
      ),
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
    if (_remoteUserLeft && _anyScreenShareActive) {
      return Container(color: _kSoftDark, child: _buildPeerLeftMainState());
    }
    if (_anyScreenShareActive) {
      final sharingUid = _resolvedScreenSharePublisherUid();
      final isLocalSharing =
          sharingUid != null && sharingUid == _agoraService.currentUID;
      if (sharingUid != null && !_screenShareSharerMarkedGone(sharingUid)) {
        return RepaintBoundary(
          child: SizedBox.expand(
            child: _buildScreenShareStageWithOptionalCompanions(
              engine,
              sharingUid,
              isLocalSharing,
            ),
          ),
        );
      }
      LogService.warning(
        '⚠️ [ScreenShare] Remote panel unresolved while share flags set: '
        '_isScreenSharing=$_isScreenSharing _remoteIsScreenSharing=$_remoteIsScreenSharing '
        '_anyShare=$_anyScreenShareActive owner=$_screenShareOwnerUid '
        'remoteUID=$_remoteUID currentUID=${_agoraService.currentUID}',
      );
      return RepaintBoundary(
        child: SizedBox.expand(
          child: _buildScreenShareBridgingPlaceholder(
            localIsPresenter: _localScreenShareCapturing,
          ),
        ),
      );
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
    if (_pipSupersedesEmbeddedLocalView()) {
      return ColoredBox(
        color: _kSoftDark,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Your camera is the floating tile — drag it where you like.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.38),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ),
      );
    }
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

  Widget _buildGalleryLayout() {
    final engine = _agoraService.engine;
    final localUid = _agoraService.currentUID;
    if (engine == null || localUid == null) {
      return Container(color: _kSoftDark);
    }

    final remoteUids = _sortedGalleryUids();
    final usePipInsteadOfLocalTile = _pipSupersedesEmbeddedLocalView();
    final tileUids = usePipInsteadOfLocalTile
        ? List<int>.from(remoteUids)
        : <int>[localUid, ...remoteUids];
    final participantCount = tileUids.length;
    final usePaging = tileUids.length >= _kGalleryPagingMinTiles;
    final chunks = _chunkGalleryTiles(tileUids, _kGalleryTilesPerPage);

    return Container(
      color: _kSoftDark,
      child: Column(
        children: [
          if (participantCount > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Text(
                'Participants: $participantCount',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useVerticalListLayout =
                    constraints.maxWidth < 520 && tileUids.length > 1;
                if (useVerticalListLayout) {
                  return _buildGalleryVerticalListForConstraints(
                    constraints: constraints,
                    tileUids: tileUids,
                    engine: engine,
                    localUid: localUid,
                  );
                }
                if (!usePaging) {
                  return _buildGalleryGridForConstraints(
                    constraints: constraints,
                    pageTileUids: tileUids,
                    engine: engine,
                    localUid: localUid,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _galleryPageController,
                        onPageChanged: (pageIdx) {
                          safeSetState(() => _galleryPageIndex = pageIdx);
                          final chunk = chunks[pageIdx];
                          final remotes = chunk
                              .where((u) => u != localUid)
                              .toSet();
                          unawaited(
                            _agoraService
                                .syncGalleryVisibleRemoteVideoSubscriptions(
                                  remotes,
                                ),
                          );
                        },
                        itemCount: chunks.length,
                        itemBuilder: (context, pageIdx) {
                          return LayoutBuilder(
                            builder: (context, pageConstraints) {
                              return _buildGalleryGridForConstraints(
                                constraints: pageConstraints,
                                pageTileUids: chunks[pageIdx],
                                engine: engine,
                                localUid: localUid,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (chunks.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Page ${_galleryPageIndex + 1} of ${chunks.length} · swipe sideways for more',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGridForConstraints({
    required BoxConstraints constraints,
    required List<int> pageTileUids,
    required agora_rtc_engine.RtcEngine engine,
    required int localUid,
  }) {
    const galleryGridHorizontalInset =
        20.0; // matches EdgeInsets L+R on GridView below
    const galleryGridVerticalInset =
        126.0; // matches EdgeInsets top+bottom on GridView below

    final innerW = constraints.maxWidth > galleryGridHorizontalInset
        ? constraints.maxWidth - galleryGridHorizontalInset
        : 1.0;
    final innerH = constraints.maxHeight > galleryGridVerticalInset
        ? constraints.maxHeight - galleryGridVerticalInset
        : 1.0;
    final maxColsCap = constraints.maxWidth >= 1400
        ? 10
        : constraints.maxWidth >= 900
        ? 8
        : 6;
    final plan = GalleryGridLayout.compute(
      innerWidth: innerW,
      innerHeight: innerH,
      tileCount: pageTileUids.length,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      maxColumnsCap: maxColsCap,
    );

    // Delegate wraps each cell in RepaintBoundary by default — isolate compositing work per tile.
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: pageTileUids.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: plan.crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: plan.childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final uid = pageTileUids[index];
        final isLocal = uid == localUid;
        return KeyedSubtree(
          key: ValueKey<int>(uid),
          child: _buildGalleryTile(engine: engine, uid: uid, isLocal: isLocal),
        );
      },
    );
  }

  /// Narrow: show gallery participants as a single vertical, scrollable column
  /// (instead of a grid) so the shared content stays visually “above”.
  Widget _buildGalleryVerticalListForConstraints({
    required BoxConstraints constraints,
    required List<int> tileUids,
    required agora_rtc_engine.RtcEngine engine,
    required int localUid,
  }) {
    final horizontalInset = 20.0;
    final innerW = max(1.0, constraints.maxWidth - horizontalInset);
    final tileHeight = (innerW * 9 / 16).clamp(140.0, 220.0);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: tileUids.length,
      itemBuilder: (context, index) {
        final uid = tileUids[index];
        final isLocal = uid == localUid;
        return KeyedSubtree(
          key: ValueKey<int>(uid),
          child: SizedBox(
            height: tileHeight,
            child: _buildGalleryTile(
              engine: engine,
              uid: uid,
              isLocal: isLocal,
            ),
          ),
        );
      },
    );
  }

  /// Saturated fill + centered avatar when a gallery tile is not showing live video.
  Widget _buildGalleryDiscordMutedFace({
    required int uid,
    required String displayName,
    String? avatarUrl,
    required bool userLeft,
    required bool waitingForVideoFrame,
    required bool showCameraOffBadge,
    required bool showScreenOffBadge,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final avatarD = (side * 0.42).clamp(52.0, 92.0);
        final baseColor = userLeft
            ? const Color(0xFF37474F)
            : _galleryDiscordBackdropForUid(uid);

        late final Widget centerChild;
        if (userLeft) {
          centerChild = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_off_rounded,
                size: avatarD * 0.62,
                color: Colors.white54,
              ),
              const SizedBox(height: 10),
              Text(
                'Left the session',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        } else if (waitingForVideoFrame) {
          centerChild = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Connecting video…',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.88),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        } else {
          centerChild = Container(
            width: avatarD,
            height: avatarD,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.32),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              color: Colors.white.withOpacity(0.08),
            ),
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          _galleryAvatarInitials(displayName),
                          style: GoogleFonts.poppins(
                            fontSize: avatarD * 0.34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      _galleryAvatarInitials(displayName),
                      style: GoogleFonts.poppins(
                        fontSize: avatarD * 0.34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
          );
        }

        return ColoredBox(
          color: baseColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: centerChild),
              if (showScreenOffBadge)
                Positioned(
                  top: 8,
                  left: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.38),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.phone_android_rounded,
                        size: 15,
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                  ),
                ),
              if (showCameraOffBadge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.38),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.videocam_off_rounded,
                        size: 15,
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGalleryTile({
    required agora_rtc_engine.RtcEngine engine,
    required int uid,
    required bool isLocal,
  }) {
    final participant = _participants[uid];
    final isPinned = _pinnedParticipantUid == uid;
    final connection = _agoraService.currentConnection;
    final remoteVideoBlocked =
        !isLocal &&
        participant != null &&
        (participant.userLeft ||
            participant.videoMuted ||
            participant.screenOff ||
            (!participant.videoReady && !participant.videoMuted));
    final localVideoBlocked = !_isVideoEnabled || !_localVideoReady;
    final showProfile = isLocal ? localVideoBlocked : remoteVideoBlocked;

    var galleryDisplayName = isLocal
        ? ((_localProfile?['full_name'] as String?)?.trim().isNotEmpty == true
              ? (_localProfile!['full_name'] as String)
              : 'You')
        : 'Participant $uid';
    var galleryAvatarUrl = isLocal
        ? (_localProfile?['avatar_url'] as String?)
        : (uid == _remoteUID
              ? (_remoteProfile?['avatar_url'] as String?)
              : null);

    final rosterFace = _galleryRosterFaceForUid(uid);
    if (rosterFace != null) {
      galleryDisplayName = rosterFace.name;
      if (rosterFace.avatarUrl != null &&
          rosterFace.avatarUrl!.trim().isNotEmpty) {
        galleryAvatarUrl = rosterFace.avatarUrl;
      }
    } else if (!isLocal &&
        participant != null &&
        _remoteProfile != null &&
        participant.uid == _remoteUID) {
      final profileName = _remoteProfile!['full_name'] as String?;
      if (profileName != null &&
          profileName.isNotEmpty &&
          profileName != 'User') {
        galleryDisplayName = profileName;
      }
      final url = _remoteProfile!['avatar_url'] as String?;
      if (url != null && url.isNotEmpty) {
        galleryAvatarUrl = url;
      }
    }

    final userLeftGallery =
        !isLocal && participant != null && participant.userLeft;
    final discordWaitingGallery =
        !userLeftGallery &&
        (isLocal
            ? (_isVideoEnabled && !_localVideoReady)
            : participant != null &&
                  !participant.userLeft &&
                  !participant.videoMuted &&
                  !participant.screenOff &&
                  !participant.videoReady);
    final showCamOffDiscordBadge =
        !userLeftGallery &&
        !discordWaitingGallery &&
        (isLocal ? !_isVideoEnabled : (participant?.videoMuted ?? false));
    final showScreenOffDiscordBadge =
        !isLocal &&
        !userLeftGallery &&
        !discordWaitingGallery &&
        (participant?.screenOff ?? false);
    final audioMutedInTile = isLocal
        ? !_isAudioEnabled
        : (participant?.audioMuted ?? false);

    return GestureDetector(
      onTap: () {
        if (isLocal) return;
        setState(() {
          _pinnedParticipantUid = isPinned ? null : uid;
        });
        _syncDualStreamPinWithLayout();
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16233C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPinned
                ? AppTheme.primaryColor.withOpacity(0.9)
                : Colors.white24,
            width: isPinned ? 1.8 : 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!showProfile)
              _wrapWithSpeakingIndicator(
                agora_widget.AgoraVideoViewWidget(
                  engine: engine,
                  uid: uid,
                  isLocal: isLocal,
                  connection: connection,
                ),
                uid,
              )
            else if (isLocal || participant != null)
              _buildGalleryDiscordMutedFace(
                uid: uid,
                displayName: galleryDisplayName,
                avatarUrl: galleryAvatarUrl,
                userLeft: userLeftGallery,
                waitingForVideoFrame: discordWaitingGallery,
                showCameraOffBadge: showCamOffDiscordBadge,
                showScreenOffBadge: showScreenOffDiscordBadge,
              )
            else
              ColoredBox(
                color: _galleryDiscordBackdropForUid(uid),
                child: Center(
                  child: Text(
                    galleryDisplayName,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    if (audioMutedInTile) ...[
                      Icon(
                        Icons.mic_off_rounded,
                        size: 13,
                        color: Colors.white.withOpacity(0.92),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Text(
                        galleryDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isPinned)
                      const Icon(
                        Icons.push_pin,
                        size: 14,
                        color: Colors.white70,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    final waitingSolo = _shouldUseSoloWaitingHeroLayout();
    final multiRemote = _galleryRemoteUids().length > 1;
    final aloneInCall =
        _remoteUID == null &&
        !_remoteUserLeft &&
        (_sessionState.isActive || _sessionState.isConnecting);
    final mq = MediaQuery.of(context);
    return LocalVideoPIP(
      engine: engine,
      localUid: localUid,
      isVideoEnabled: _isVideoEnabled,
      isAudioEnabled: _isAudioEnabled,
      cameraOffBackdrop: localUid != null
          ? _galleryDiscordBackdropForUid(localUid)
          : null,
      selfDisplayName: _localDisplayNameForChat(),
      selfAvatarUrl: _localProfile?['avatar_url'] as String?,
      selfInitials: _localInitialsForPip(),
      isSpeaking:
          localUid != null &&
          _isAudioEnabled &&
          _speakingUids.contains(localUid),
      onExpandSelfView: (waitingSolo || aloneInCall)
          ? () => safeSetState(() => _soloWaitingSelfExpanded = true)
          : null,
      allowDrag: !multiRemote || aloneInCall,
      preferTopCorner: false,
      showInitialDragHint:
          (waitingSolo || aloneInCall) && !_soloPipDragHintShown,
      onInitialDragHintShown: () {
        if (_soloPipDragHintShown || !mounted) return;
        safeSetState(() => _soloPipDragHintShown = true);
      },
      bottomDragReserve: () {
        final isNarrow = mq.size.width < 520;
        final waitingOrAlone = waitingSolo || aloneInCall;
        final baseReserve = _kCallControlBarReserveHeight(mq);
        final delta = waitingOrAlone
            ? (isNarrow ? 72.0 : 48.0)
            : (isNarrow ? 40.0 : 0.0);
        return max(16.0, baseReserve - delta);
      }(),
    );
  }

  /// Calm empty state when the peer has left (no waiting spinner).
  Widget _buildPeerLeftMainState() {
    String name = widget.userRole == 'tutor' ? 'Learner' : 'Tutor';
    if (_remoteProfile != null) {
      final profileName = _remoteProfile!['full_name'] as String?;
      if (profileName != null &&
          profileName.isNotEmpty &&
          profileName != 'User') {
        name = profileName;
      }
    }
    final roleColor = widget.userRole == 'tutor'
        ? AppTheme.accentGreen
        : AppTheme.accentBlue;
    final initials = name.isNotEmpty
        ? (name.trim().split(' ').length >= 2
              ? '${name.trim().split(' ')[0][0]}${name.trim().split(' ')[1][0]}'
              : name[0])
            .toUpperCase()
        : '?';
    final avatarUrl = _remoteProfile?['avatar_url'] as String?;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: roleColor.withOpacity(0.15),
                border: Border.all(color: roleColor.withOpacity(0.4), width: 2),
              ),
              child: hasAvatar
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        width: 96,
                        height: 96,
                        errorWidget: (_, __, ___) => Center(
                          child: Text(
                            initials,
                            style: GoogleFonts.poppins(
                              fontSize: 32,
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
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Left the session',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'They can rejoin from their session link if the lesson is still active.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white54,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Placeholder when waiting for remote (no video yet): avatar (or initials) + name + "Waiting for [Tutor/Learner]..."
  Widget _buildWaitingPlaceholder() {
    String name = widget.userRole == 'tutor' ? 'Learner' : 'Tutor';
    if (_remoteProfile != null) {
      final profileName = _remoteProfile!['full_name'] as String?;
      if (profileName != null &&
          profileName.isNotEmpty &&
          profileName != 'User') {
        name = profileName;
      }
    }
    final roleColor = widget.userRole == 'tutor'
        ? AppTheme.accentGreen
        : AppTheme.accentBlue;
    String initials = name.isNotEmpty
        ? name.trim().split(' ').length >= 2
              ? '${name.trim().split(' ')[0][0]}${name.trim().split(' ')[1][0]}'
                    .toUpperCase()
              : name[0].toUpperCase()
        : '?';
    final avatarUrl = _remoteProfile?['avatar_url'] as String?;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SessionWaitingAvatarRing(
            accent: roleColor,
            size: 120,
            child: Container(
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

  /// Estimated airtime split from SDK volume indications (tutor-facing nudge).
  Widget _buildTutorTalkTimeChip() {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 5), (i) => i),
      builder: (_, __) {
        final snap = _agoraService.talkTimeSnapshot;
        if (snap.samples < 12 || snap.totalMs < 12000) {
          return const SizedBox.shrink();
        }
        final youPct = (snap.localShare * 100).round().clamp(0, 100);
        final themPct = (snap.remoteShare * 100).round().clamp(0, 100);
        return Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mic_rounded,
                  size: 15,
                  color: AppTheme.primaryColor.withOpacity(0.95),
                ),
                const SizedBox(width: 6),
                Text(
                  'Talk · You $youPct% · Them $themPct%',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  void _openLessonInfoSheet() {
    if (!mounted) return;
    unawaited(
      showSessionInCallInfoSheet(
        context: context,
        sessionId: widget.sessionId,
        userRole: widget.userRole,
        localProfile: _localProfile,
        remoteProfile: _remoteProfile,
        booking: _sessionBookingSummary,
        timeRemaining: _timeRemaining,
        onOpenConnectionHelp: () {
          if (!mounted) return;
          showSessionConnectionHelpSheet(
            context: context,
            agoraService: _agoraService,
            remoteParticipantUid: _remoteUID,
          );
        },
      ),
    );
  }

  /// Small draggable who-is-in-call strip for narrow layouts (in-app; not OS PiP).
  Widget _buildDraggableParticipantStrip() {
    final mq = MediaQuery.of(context);
    // Meet-style: strip under top chrome (not buried near the control bar).
    final topBase = _kCallTopChromeReserveHeight(mq) + 6;
    final maxLeft = max(8.0, mq.size.width - 140);
    final left = (12.0 + _participantStripDrag.dx).clamp(8.0, maxLeft);
    final top = topBase + _participantStripDrag.dy.clamp(-12.0, 100.0);

    String remoteInitials() {
      if (_remoteProfile == null) return '?';
      final n = (_remoteProfile!['full_name'] as String?)?.trim();
      if (n == null || n.isEmpty) {
        return widget.userRole == 'tutor' ? 'L' : 'T';
      }
      final parts = n.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }

    Widget avatar({required String initials, String? url}) {
      final d = 30.0;
      if (url != null && url.trim().isNotEmpty) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: d,
            height: d,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(width: d, height: d, color: Colors.white12),
            errorWidget: (_, __, ___) => Container(
              width: d,
              height: d,
              color: Colors.white12,
              alignment: Alignment.center,
              child: Text(
                initials,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }
      return Container(
        width: d,
        height: d,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x44FFFFFF),
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final localUrl = _localProfile?['avatar_url'] as String?;
    final remoteUrl = _remoteProfile?['avatar_url'] as String?;
    final narrowOverlayChat = _narrowOverlayChatMode(mq);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: narrowOverlayChat && _inCallChatOpen
            ? _closeIncallChatPanel
            : null,
        onPanUpdate: (d) {
          safeSetState(() {
            _participantStripDrag += d.delta;
          });
        },
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xD90F1A2E),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar(initials: _localInitialsForPip(), url: localUrl),
                if (_remoteUID != null && !_remoteUserLeft) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      Icons.link,
                      size: 14,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ),
                  avatar(initials: remoteInitials(), url: remoteUrl),
                ] else ...[
                  const SizedBox(width: 8),
                  avatar(initials: remoteInitials(), url: remoteUrl),
                  const SizedBox(width: 6),
                  Text(
                    _remoteUserLeft ? 'Left' : 'Waiting',
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build status bar (gradient header: connection pill, timer, quality)
  Widget _buildStatusBar() {
    final mq = MediaQuery.of(context);
    final isAloneWaiting =
        _sessionState.isActive &&
        !_remoteUserLeft &&
        _remoteUID == null &&
        _galleryRemoteUids().isEmpty &&
        !_shouldUseSoloWaitingHeroLayout() &&
        !_anyScreenShareActive;
    final showSecondaryHeaderChips =
        mq.size.width >= 420 && !_narrowOverlayChatMode(mq);
    final canShowLayoutToggle =
        _sessionState.isActive && _galleryRemoteUids().isNotEmpty;
    final chatRailExtra = _embeddedIncallChatRailVisible(mq)
        ? _kLearnerIncallChatRailWidth + 8
        : 0.0;
    final connected =
        _sessionState == AgoraSessionState.connected ||
        _sessionState == AgoraSessionState.reconnecting;
    final shareHeader = connected && _anyScreenShareActive;

    Widget? headerTrailing;
    if (connected && (shareHeader || canShowLayoutToggle)) {
      headerTrailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shareHeader) _shareLayoutPresetMenuIcon(),
          if (shareHeader && canShowLayoutToggle) const SizedBox(width: 8),
          if (canShowLayoutToggle)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  final before = _layout;
                  setState(() {
                    if (_layout == VideoLayout.spotlight) {
                      _layout = VideoLayout.sideBySide;
                    } else if (_layout == VideoLayout.sideBySide) {
                      _layout = VideoLayout.gallery;
                    } else {
                      _layout = VideoLayout.spotlight;
                    }
                  });
                  _syncDualStreamPinWithLayout();
                  _applyGalleryPagingOnLayoutChanged(before, _layout);
                  _previousLayoutForPaging = _layout;
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
                        ? Icons.view_sidebar
                        : _layout == VideoLayout.sideBySide
                        ? Icons.grid_view
                        : Icons.filter_1,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_callConnectivityOnline && !_inCallOfflineCardOpen)
            const SafeArea(
              bottom: false,
              child: ClassroomOfflineBanner(
                message: 'No internet — reconnect to restore video.',
              ),
            ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              CallStatusBanner(
                sessionState: _sessionState,
                showSustainedDegradation: _sustainedCallDegradation,
                remoteUserLeft: _remoteUserLeft,
                isAloneWaiting:
                    isAloneWaiting && !_shouldUseSoloWaitingHeroLayout(),
                userRole: widget.userRole,
                timeRemaining: _timeRemaining,
                rightContentInset: chatRailExtra,
                trailing: headerTrailing,
              ),
              if (showSecondaryHeaderChips &&
                  widget.userRole == 'tutor' &&
                  _remoteUID != null &&
                  !_remoteUserLeft)
                Positioned(top: 52, left: 10, child: _buildTutorTalkTimeChip()),
              if (showSecondaryHeaderChips &&
                  widget.userRole == 'tutor' &&
                  _remoteHandRaised &&
                  _remoteUID != null &&
                  !_remoteUserLeft)
                Positioned(
                  top: 52,
                  right: 12,
                  child: _buildRemoteHandRaiseChip(),
                ),
              if (_showRecoveryBanner)
                Positioned(
                  top: 56,
                  left: 10,
                  right: 10,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        _showRecoveryActionsSheet();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xB35B2C10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE0A96D)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.health_and_safety_rounded,
                              color: Color(0xFFFFD7A3),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Recovery mode: $_recoveryReason',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white.withOpacity(0.65),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Workspace lane is hidden under video on phones; reopen as a Meet-style drawer.
  Future<void> _openTeachingToolsSheet() async {
    if (!_useClassroomWorkspaceShell || _workspaceRealtime == null) return;

    final mq = MediaQuery.of(context);
    final wide = mq.size.width >= _kClassroomDualPaneMinWidth;
    final active = _sessionState.isActive || _sessionState.isConnecting;
    final teachingOpen = _workspaceRealtime!.workspace.state.teachingLaneOpen;

    // Wide dual-pane already embeds the workspace — do not stack a second sheet ("duplicate board").
    if (wide && active && teachingOpen && widget.userRole == 'tutor') {
      _showSnackBar('Teaching tools are already open.');
      return;
    }

    if (widget.userRole == 'tutor' && active) {
      await _publishTeachingLaneOpen(!teachingOpen);
      if (teachingOpen && mounted) {
        _showSnackBar('Teaching tools hidden.');
      }
      return;
    }
    // Learner narrow fallback: keep sheet path for read-only exploration.

    if (!mounted) return;

    final workspaceSheetTitle = widget.userRole == 'tutor'
        ? 'Teaching tools'
        : 'Lesson workspace';

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
      pageBuilder: (sheetCtx, animation, secondaryAnimation) {
        final w = MediaQuery.sizeOf(sheetCtx).width;
        final h = MediaQuery.sizeOf(sheetCtx).height;
        final panelW = min(420.0, w * 0.9).clamp(280.0, 520.0);
        return Align(
          alignment: Alignment.centerRight,
          child: SafeArea(
            child: SizedBox(
              width: panelW,
              height: h,
              child: Material(
                color: const Color(0xFF0C1528),
                elevation: 10,
                shadowColor: Colors.black54,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              workspaceSheetTitle,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(sheetCtx).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0x22FFFFFF)),
                    Expanded(
                      child: _buildClassroomWorkspacePanel(
                        workspaceDividerFromVideo: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() async {
      if (!mounted) return;
      if (widget.userRole == 'tutor' &&
          !wide &&
          active &&
          (_sessionState.isActive || _sessionState.isConnecting)) {
        await _publishTeachingLaneOpen(false);
      }
    });
  }

  void _applyInCallMoreMenuAction(
    String action, {
    required bool includeScreenShare,
    required bool connectionHelpEnabled,
  }) {
    switch (action) {
      case _kInCallMoreTeachingTools:
        _openTeachingToolsSheet();
        break;
      case _kInCallMoreReactions:
        if (!_controlsEnabled) return;
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              safeSetState(() {
                _showReactionsPanel = !_showReactionsPanel;
              });
            }
          });
        }
        break;
      case _kInCallMoreScreenShare:
        if (!includeScreenShare) return;
        if (!_controlsEnabled) return;
        _toggleScreenSharing();
        break;
      case _kInCallMoreConnectionHelp:
        if (!connectionHelpEnabled) return;
        showSessionConnectionHelpSheet(
          context: context,
          agoraService: _agoraService,
          remoteParticipantUid: _remoteUID,
        );
        break;
      case _kInCallMoreInCallMessages:
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _openIncallChatPanel();
          }
        });
        break;
      case _kInCallMoreLessonInfo:
        _openLessonInfoSheet();
        break;
      case _kInCallMoreInviteLearner:
        _showInviteLearnerSheet();
        break;
      case _kInCallMoreTalkTime:
        _showTutorTalkTimeSheet();
        break;
      case _kInCallMoreReportIssue:
        _reportClassroomIssue();
        break;
      case _kInCallMorePrepSkulAssist:
        if (!mounted) return;
        _showPrepSkulAssistHintSheet();
        break;
      case _kInCallMoreConnectionQuality:
        if (_showRecoveryBanner) {
          _showRecoveryActionsSheet();
        } else if (mounted) {
          _showSnackBar('Your lesson connection looks normal right now.');
        }
        break;
    }
  }

  Future<void> _showRecoveryActionsSheet() async {
    if (!mounted) return;
    if (!_recoveryActionsOpenedOnce) {
      _recoveryActionsOpenedOnce = true;
      LogService.info(
        '[RECOVERY] Actions opened for session ${widget.sessionId}',
      );
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Recovery mode: $_recoveryReason',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Something in this lesson looks off — sync, video, or the virtual board may need a moment. You can reach PrepSkul support or use a backup link if your school configured one.',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFE8EEF9),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFE7C9),
                  foregroundColor: const Color(0xFF3D2A0C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _contactLiveClassSupport();
                },
                child: Text(
                  'Support',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
              ),
              if (AppConfig.classroomBackupCallUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openBackupCallLink();
                  },
                  child: Text(
                    'Backup call link',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showPrepSkulAssistHintSheet() {
    if (!mounted) return;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF121A2E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'PrepSkul assist',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'We may show gentle tips during your lesson so you get the most from PrepSkul. Nothing here changes how your camera or mic work.',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFE8EEF9),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shared rows for Meet-style overflow menus (phone bottom sheet + desktop side panel).
  List<Widget> _buildMeetMoreOptionTiles(
    BuildContext navigatorContext, {
    required bool includeScreenShare,
    required bool connectionHelpEnabled,
    required bool showTeachingToolsInMore,
    required bool showLearnerWorkspaceInMore,
    required bool showReactionsInMore,
    required bool showInCallMessagesInMore,
    required bool showHandRaiseInMore,
    bool compactMobile = false,
  }) {
    final screenShareLabel =
        _localScreenShareCapturing ? 'Stop sharing' : 'Share screen';
    final screenShareIcon = _localScreenShareCapturing
        ? Icons.stop_screen_share
        : Icons.screen_share;
    final showInviteLearnerInMore =
        widget.userRole == 'tutor' &&
        _sessionState.isActive &&
        (_remoteUID == null || _remoteUserLeft);
    final showTalkTimeInMore =
        widget.userRole == 'tutor' &&
        _sessionState.isActive &&
        _remoteUID != null &&
        !_remoteUserLeft;
    final teachingLaneOpen =
        _workspaceRealtime?.workspace.state.teachingLaneOpen ?? false;

    Widget sheetRow({
      required IconData icon,
      required String title,
      String? subtitle,
      required bool enabled,
      bool selected = false,
      VoidCallback? onTap,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && onTap != null
              ? () {
                  Navigator.of(navigatorContext).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    onTap();
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: enabled ? Colors.white70 : Colors.white38,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: enabled ? Colors.white : Colors.white54,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(
                              enabled ? 0.42 : 0.34,
                            ),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white.withOpacity(0.92),
                  )
                else if (enabled)
                  Icon(Icons.chevron_right, color: Colors.white24),
              ],
            ),
          ),
        ),
      );
    }

    return [
      sheetRow(
        icon: Icons.info_outline_rounded,
        title: 'Lesson info',
        subtitle: 'Session details & participants',
        enabled: true,
        onTap: () => _applyInCallMoreMenuAction(
          _kInCallMoreLessonInfo,
          includeScreenShare: includeScreenShare,
          connectionHelpEnabled: connectionHelpEnabled,
        ),
      ),
      if (showInviteLearnerInMore)
        sheetRow(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Invite learner',
          subtitle: 'Copy or share this lesson invite',
          enabled: true,
          onTap: () => _applyInCallMoreMenuAction(
            _kInCallMoreInviteLearner,
            includeScreenShare: includeScreenShare,
            connectionHelpEnabled: connectionHelpEnabled,
          ),
        ),
      if (showTalkTimeInMore)
        sheetRow(
          icon: Icons.graphic_eq_rounded,
          title: 'Talk time',
          subtitle: 'You vs learner speaking balance',
          enabled: true,
          onTap: () => _applyInCallMoreMenuAction(
            _kInCallMoreTalkTime,
            includeScreenShare: includeScreenShare,
            connectionHelpEnabled: connectionHelpEnabled,
          ),
        ),
      sheetRow(
        icon: Icons.flag_outlined,
        title: 'Report issue',
        subtitle: 'Quality, safety, or technical problems',
        enabled: true,
        onTap: () => _applyInCallMoreMenuAction(
          _kInCallMoreReportIssue,
          includeScreenShare: includeScreenShare,
          connectionHelpEnabled: connectionHelpEnabled,
        ),
      ),
      sheetRow(
        icon: Icons.support_agent_rounded,
        title: 'PrepSkul assist',
        subtitle: 'What tips in the lesson mean',
        enabled: true,
        onTap: () => _applyInCallMoreMenuAction(
          _kInCallMorePrepSkulAssist,
          includeScreenShare: includeScreenShare,
          connectionHelpEnabled: connectionHelpEnabled,
        ),
      ),
      sheetRow(
        icon: Icons.health_and_safety_outlined,
        title: 'Connection quality',
        subtitle: _showRecoveryBanner
            ? 'Recovery mode is on — tap for help'
            : 'We’ll flag sync or network issues here',
        enabled: true,
        onTap: () => _applyInCallMoreMenuAction(
          _kInCallMoreConnectionQuality,
          includeScreenShare: includeScreenShare,
          connectionHelpEnabled: connectionHelpEnabled,
        ),
      ),
      const Divider(height: 20, color: Colors.white12),
      if (showTeachingToolsInMore)
        sheetRow(
          icon: Icons.grid_view_rounded,
          title: 'Teaching tools',
          subtitle: 'Board, PDF & notes',
          enabled: true,
          selected: teachingLaneOpen,
          onTap: () => _applyInCallMoreMenuAction(
            _kInCallMoreTeachingTools,
            includeScreenShare: includeScreenShare,
            connectionHelpEnabled: connectionHelpEnabled,
          ),
        ),
      if (showLearnerWorkspaceInMore)
        sheetRow(
          icon: Icons.grid_view_rounded,
          title: 'Lesson workspace',
          subtitle: 'Board & materials',
          enabled: true,
          selected: teachingLaneOpen,
          onTap: () => _applyInCallMoreMenuAction(
            _kInCallMoreTeachingTools,
            includeScreenShare: includeScreenShare,
            connectionHelpEnabled: connectionHelpEnabled,
          ),
        ),
      if (showReactionsInMore && !compactMobile)
        sheetRow(
          icon: Icons.emoji_emotions_outlined,
          title: 'Reactions',
          enabled: _controlsEnabled,
          selected: _showReactionsPanel,
          onTap: () => _applyInCallMoreMenuAction(
            _kInCallMoreReactions,
            includeScreenShare: includeScreenShare,
            connectionHelpEnabled: connectionHelpEnabled,
          ),
        ),
      if (showHandRaiseInMore && !compactMobile)
        sheetRow(
          icon: Icons.pan_tool_alt_outlined,
          title: _localHandRaised ? 'Lower hand' : 'Raise hand',
          subtitle: _localHandRaised
              ? 'Tell tutor you are done'
              : 'Notify tutor you need to speak',
          enabled: _controlsEnabled,
          selected: _localHandRaised,
          onTap: _toggleHandRaise,
        ),
      if (includeScreenShare && !compactMobile)
        sheetRow(
          icon: screenShareIcon,
          title: screenShareLabel,
          enabled: _controlsEnabled,
          selected: _localScreenShareCapturing,
          onTap: () => _applyInCallMoreMenuAction(
            _kInCallMoreScreenShare,
            includeScreenShare: true,
            connectionHelpEnabled: connectionHelpEnabled,
          ),
        ),
      sheetRow(
        icon: Icons.wifi_tethering,
        title: 'Connection help',
        subtitle: 'Audio, video & network tips',
        enabled: connectionHelpEnabled,
        onTap: () => _applyInCallMoreMenuAction(
          _kInCallMoreConnectionHelp,
          includeScreenShare: includeScreenShare,
          connectionHelpEnabled: connectionHelpEnabled,
        ),
      ),
      const Divider(height: 24, color: Colors.white12),
      if (showInCallMessagesInMore && !compactMobile)
        sheetRow(
          icon: Icons.chat_bubble_outline,
          title: 'In-call messages',
          subtitle: 'Quick notes — not saved after this lesson',
          enabled: true,
          selected: _inCallChatOpen,
          onTap: () => _applyInCallMoreMenuAction(
            _kInCallMoreInCallMessages,
            includeScreenShare: includeScreenShare,
            connectionHelpEnabled: connectionHelpEnabled,
          ),
        ),
    ];
  }

  /// Google Meet–like bottom sheet on phones; parity doc: bottom sheet on narrow viewports.
  Future<void> _showMeetStyleInCallMoreSheet({
    required bool includeScreenShare,
    required bool connectionHelpEnabled,
    required bool showTeachingToolsInMore,
    required bool showLearnerWorkspaceInMore,
    required bool showReactionsInMore,
    required bool showInCallMessagesInMore,
    required bool showHandRaiseInMore,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161E30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final mq = MediaQuery.of(sheetCtx);
        final sheetMaxH = (mq.size.height * 0.8).clamp(
          420.0,
          mq.size.height - 80,
        );
        Widget quickAction({
          required IconData icon,
          required String label,
          required bool enabled,
          required VoidCallback onTap,
          bool active = false,
        }) {
          return SizedBox(
            width: 104,
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Material(
                color: active
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: enabled
                      ? () {
                          Navigator.of(sheetCtx).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            onTap();
                          });
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 18, color: Colors.white),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(height: 4),
                          const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: sheetMaxH,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'More options',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      quickAction(
                        icon: Icons.mic,
                        label: _isAudioEnabled ? 'Mute' : 'Unmute',
                        enabled: _controlsEnabled,
                        active: _isAudioEnabled,
                        onTap: _toggleAudio,
                      ),
                      quickAction(
                        icon: _isVideoEnabled
                            ? Icons.videocam
                            : Icons.videocam_off,
                        label: _isVideoEnabled ? 'Camera on' : 'Camera off',
                        enabled: _controlsEnabled,
                        active: _isVideoEnabled,
                        onTap: _toggleVideo,
                      ),
                      if (includeScreenShare)
                        quickAction(
                          icon: _localScreenShareCapturing
                              ? Icons.stop_screen_share
                              : Icons.screen_share,
                          label:
                              _localScreenShareCapturing ? 'Stop share' : 'Share',
                          enabled: _controlsEnabled,
                          active: _localScreenShareCapturing,
                          onTap: () => _applyInCallMoreMenuAction(
                            _kInCallMoreScreenShare,
                            includeScreenShare: includeScreenShare,
                            connectionHelpEnabled: connectionHelpEnabled,
                          ),
                        ),
                      quickAction(
                        icon: Icons.chat_bubble_outline,
                        label: 'Messages',
                        enabled: true,
                        active: _inCallChatOpen,
                        onTap: _toggleIncallChatPanel,
                      ),
                      quickAction(
                        icon: Icons.emoji_emotions_outlined,
                        label: 'Reactions',
                        enabled: _controlsEnabled,
                        active: _showReactionsPanel,
                        onTap: () => _applyInCallMoreMenuAction(
                          _kInCallMoreReactions,
                          includeScreenShare: includeScreenShare,
                          connectionHelpEnabled: connectionHelpEnabled,
                        ),
                      ),
                      if (showHandRaiseInMore)
                        quickAction(
                          icon: Icons.pan_tool_alt_outlined,
                          label: _localHandRaised ? 'Lower hand' : 'Raise hand',
                          enabled: _controlsEnabled,
                          active: _localHandRaised,
                          onTap: _toggleHandRaise,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _buildMeetMoreOptionTiles(
                          sheetCtx,
                          includeScreenShare: includeScreenShare,
                          connectionHelpEnabled: connectionHelpEnabled,
                          showTeachingToolsInMore: showTeachingToolsInMore,
                          showLearnerWorkspaceInMore:
                              showLearnerWorkspaceInMore,
                          showReactionsInMore: showReactionsInMore,
                          showInCallMessagesInMore: showInCallMessagesInMore,
                          showHandRaiseInMore: showHandRaiseInMore,
                          compactMobile: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Tablet / desktop: slide-in side panel (readable vs low-contrast anchored popup).
  Future<void> _showMeetStyleInCallMoreSideSheet({
    required bool includeScreenShare,
    required bool connectionHelpEnabled,
    required bool showTeachingToolsInMore,
    required bool showLearnerWorkspaceInMore,
    required bool showReactionsInMore,
    required bool showInCallMessagesInMore,
    required bool showHandRaiseInMore,
  }) async {
    final mq = MediaQuery.of(context);
    final panelWidth = min(400.0, mq.size.width * 0.42).clamp(292.0, 440.0);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.48),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogCtx, _, __) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogCtx).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: const Color(0xFF121A2E),
                elevation: 16,
                shadowColor: Colors.black54,
                child: SizedBox(
                  width: panelWidth,
                  height: mq.size.height,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SafeArea(
                        left: false,
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 4, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'More options',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () => Navigator.of(dialogCtx).pop(),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0x22FFFFFF)),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          children: _buildMeetMoreOptionTiles(
                            dialogCtx,
                            includeScreenShare: includeScreenShare,
                            connectionHelpEnabled: connectionHelpEnabled,
                            showTeachingToolsInMore: showTeachingToolsInMore,
                            showLearnerWorkspaceInMore:
                                showLearnerWorkspaceInMore,
                            showReactionsInMore: showReactionsInMore,
                            showInCallMessagesInMore: showInCallMessagesInMore,
                            showHandRaiseInMore: showHandRaiseInMore,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  /// Meet-style bottom sheet on phone; slide-in side panel on larger viewports.
  Widget _buildMoreOptionsMenuButton({
    required double buttonSize,
    required double iconSize,
    required bool connectionHelpEnabled,
    bool includeScreenShare = false,
    bool showTeachingToolsInMore = false,
    bool showLearnerWorkspaceInMore = false,
    bool showReactionsInMore = true,
    bool showInCallMessagesInMore = true,
    bool showHandRaiseInMore = false,
  }) {
    final mqSize = MediaQuery.sizeOf(context);
    final useMeetSheet =
        mqSize.shortestSide < _kMeetStyleMoreSheetMaxShortestSide ||
        mqSize.width < _kControlBarCompactWidth;

    void openMore() {
      if (useMeetSheet) {
        _showMeetStyleInCallMoreSheet(
          includeScreenShare: includeScreenShare,
          connectionHelpEnabled: connectionHelpEnabled,
          showTeachingToolsInMore: showTeachingToolsInMore,
          showLearnerWorkspaceInMore: showLearnerWorkspaceInMore,
          showReactionsInMore: showReactionsInMore,
          showInCallMessagesInMore: showInCallMessagesInMore,
          showHandRaiseInMore: showHandRaiseInMore,
        );
      } else {
        _showMeetStyleInCallMoreSideSheet(
          includeScreenShare: includeScreenShare,
          connectionHelpEnabled: connectionHelpEnabled,
          showTeachingToolsInMore: showTeachingToolsInMore,
          showLearnerWorkspaceInMore: showLearnerWorkspaceInMore,
          showReactionsInMore: showReactionsInMore,
          showInCallMessagesInMore: showInCallMessagesInMore,
          showHandRaiseInMore: showHandRaiseInMore,
        );
      }
    }

    return _buildControlButton(
      icon: Icons.more_vert,
      label: 'More options',
      onPressed: openMore,
      isActive: false,
      enabled: true,
      buttonSize: buttonSize,
      iconSize: iconSize,
    );
  }

  static List<Widget> _interleaveControlBarGap(
    List<Widget> children,
    double gap,
  ) {
    if (children.isEmpty) return const <Widget>[];
    final out = <Widget>[children.first];
    for (var i = 1; i < children.length; i++) {
      out.add(SizedBox(width: gap));
      out.add(children[i]);
    }
    return out;
  }

  /// Build control bar (bottom glass strip)
  Widget _buildControlBar() {
    final media = MediaQuery.of(context);
    if (_narrowOverlayChatMode(media)) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: const SizedBox.shrink(),
      );
    }
    final isShortViewport = media.size.height < 760;
    final isNarrowViewport = media.size.width < 390;
    final verticalPadding = isShortViewport ? 8.0 : 14.0;
    final buttonSize = isNarrowViewport ? 52.0 : 56.0;
    final iconSize = isNarrowViewport ? 23.0 : 25.0;
    final gap = isNarrowViewport ? 10.0 : 12.0;
    final connectionHelpEnabled =
        _sessionState.isActive || _sessionState.isConnecting;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              12,
              verticalPadding,
              12,
              verticalPadding + media.padding.bottom,
            ),
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
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.14),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompactBar =
                      constraints.maxWidth < _kControlBarCompactWidth;
                  final screenShareAvailable =
                      !(kIsWeb && platform_utils.PlatformUtils.isMobileWeb) &&
                      _canStartScreenShareFromThisDevice;
                  final showScreenShareInline =
                      !isCompactBar && screenShareAvailable;
                  final includeScreenShareInMoreMenu =
                      isCompactBar && screenShareAvailable;
                  final narrowClassroomDock =
                      constraints.maxWidth < _kClassroomDualPaneMinWidth;
                  final teachingLaneOpenForDock =
                      _workspaceRealtime?.workspace.state.teachingLaneOpen ??
                      false;
                  final workspaceSurfaceForDock =
                      _workspaceRealtime?.workspace.state.surface ??
                      WorkspaceSurface.launcher;
                  final teachingToolSelectedForDock =
                      workspaceSurfaceForDock != WorkspaceSurface.launcher;
                  final teachingToolsDockIcon = teachingToolSelectedForDock
                      ? _workspaceSurfaceIcon(workspaceSurfaceForDock)
                      : Icons.grid_view_rounded;
                  final teachingToolsDockLabel = teachingToolSelectedForDock
                      ? _workspaceSurfaceLabel(workspaceSurfaceForDock)
                      : 'Teaching tools';
                  // Narrow: Teaching tools also in ⋮. Wide: keep ⋮ entry only on narrow; wide closed lane uses dock grid.
                  final showTeachingToolsInMore =
                      _useClassroomWorkspaceShell &&
                      widget.userRole == 'tutor' &&
                      narrowClassroomDock;
                  // Narrow: workspace hidden under video → row in More. Wide: dual-pane lane + optional fullscreen sheet via More (same UX affordance Preply parity).
                  final showLearnerWorkspaceInMore =
                      _useClassroomWorkspaceShell &&
                      widget.userRole == 'learner' &&
                      !narrowClassroomDock;
                  // Show dock grid when lane is hidden under video (narrow) OR teaching lane not yet open (wide).
                  final showTeachingToolsDockShortcut =
                      !isCompactBar &&
                      _useClassroomWorkspaceShell &&
                      widget.userRole == 'tutor' &&
                      _workspaceRealtime != null;
                  final tallBarLearnerReactionsShortcut =
                      !isCompactBar && widget.userRole == 'learner';
                  final tallBarTutorReactionsShortcut =
                      !isCompactBar && widget.userRole == 'tutor';
                  final tallBarLearnerMessagesShortcut =
                      !isCompactBar && widget.userRole == 'learner';
                  final tallBarTutorMessagesShortcut =
                      !isCompactBar && widget.userRole == 'tutor';
                  final tallBarIncallMessagesShortcut =
                      tallBarLearnerMessagesShortcut ||
                      tallBarTutorMessagesShortcut;
                  final tallBarLearnerHandRaiseShortcut =
                      !isCompactBar && widget.userRole == 'learner';
                  final showReactionsInMore =
                      !tallBarLearnerReactionsShortcut &&
                      !tallBarTutorReactionsShortcut;
                  final showMessagesInMore = !tallBarIncallMessagesShortcut;
                  final showHandRaiseInMore =
                      !tallBarLearnerHandRaiseShortcut &&
                      widget.userRole == 'learner';

                  final toolGap =
                      !isNarrowViewport &&
                          widget.userRole == 'learner' &&
                          !isCompactBar
                      ? 18.0
                      : gap;

                  final micTool = StreamBuilder<double>(
                    stream: _agoraService.inCallLocalMicLevelStream,
                    initialData: 0,
                    builder: (context, snap) {
                      final raw = (snap.data ?? 0).clamp(0.0, 1.0).toDouble();
                      final levelGate = kIsWeb ? 0.008 : 0.03;
                      final now = DateTime.now();
                      if (_isAudioEnabled && raw > levelGate) {
                        _inCallMicWaveHoldUntil = now.add(
                          const Duration(milliseconds: 240),
                        );
                      }
                      var target = _isAudioEnabled ? raw : 0.0;
                      if (_isAudioEnabled &&
                          now.isBefore(_inCallMicWaveHoldUntil) &&
                          target < 0.14) {
                        target = 0.14;
                      }
                      final easing = target > _inCallMicWaveVisualLevel
                          ? 0.58
                          : 0.22;
                      _inCallMicWaveVisualLevel +=
                          (target - _inCallMicWaveVisualLevel) * easing;
                      if (!_isAudioEnabled ||
                          _inCallMicWaveVisualLevel < 0.015) {
                        _inCallMicWaveVisualLevel = 0;
                      }
                      final showWave =
                          _isAudioEnabled &&
                          _inCallMicWaveVisualLevel > (kIsWeb ? 0.035 : 0.05);
                      final amp = _inCallMicWaveVisualLevel;
                      return _buildControlButton(
                        icon: _isAudioEnabled ? Icons.mic : Icons.mic_off,
                        label: _isAudioEnabled ? 'Mute' : 'Unmute',
                        onPressed: _controlsEnabled ? _toggleAudio : () {},
                        isActive: _isAudioEnabled,
                        showMutedIndicator: !_isAudioEnabled,
                        useMediaToggleStyle: true,
                        showSpeakingWave: showWave,
                        speakingWaveAmplitude: showWave ? amp : 0,
                        enabled: _controlsEnabled,
                        buttonSize: buttonSize,
                        iconSize: iconSize,
                      );
                    },
                  );

                  final barTools = <Widget>[micTool];
                  if (AppConfig.enableSessionCameraPublishing) {
                    final cameraToggleEnabled = _controlsEnabled;
                    barTools.add(
                      _buildControlButton(
                        icon: _isVideoEnabled
                            ? Icons.videocam
                            : Icons.videocam_off,
                        label: _isVideoEnabled
                            ? 'Turn camera off'
                            : 'Turn camera on',
                        onPressed: cameraToggleEnabled ? _toggleVideo : () {},
                        isActive: _isVideoEnabled,
                        showMutedIndicator: !_isVideoEnabled,
                        useMediaToggleStyle: true,
                        enabled: cameraToggleEnabled,
                        buttonSize: buttonSize,
                        iconSize: iconSize,
                      ),
                    );
                  }
                  if (showScreenShareInline) {
                    barTools.add(
                      _buildScreenShareButton(
                        buttonSize: buttonSize,
                        iconSize: iconSize,
                      ),
                    );
                  }
                  if (showTeachingToolsDockShortcut) {
                    final teachingToolsEngagedForDock =
                        _useClassroomWorkspaceShell
                        ? teachingLaneOpenForDock
                        : (teachingLaneOpenForDock ||
                              teachingToolSelectedForDock);
                    barTools.add(
                      _buildControlButton(
                        icon: teachingToolsDockIcon,
                        label: teachingToolsDockLabel,
                        onPressed: _controlsEnabled
                            ? _openTeachingToolsSheet
                            : () {},
                        isActive: teachingToolsEngagedForDock,
                        showActiveBadge: teachingLaneOpenForDock,
                        enabled: _controlsEnabled,
                        buttonSize: buttonSize,
                        iconSize: iconSize,
                      ),
                    );
                  }
                  if (tallBarIncallMessagesShortcut) {
                    barTools.add(
                      _buildControlButton(
                        icon: Icons.chat_bubble_outline,
                        label: _inCallChatOpen ? 'Hide messages' : 'Messages',
                        onPressed: _controlsEnabled
                            ? _toggleIncallChatPanel
                            : () {},
                        isActive: _inCallChatOpen,
                        showActiveBadge: _inCallChatOpen,
                        enabled: _controlsEnabled,
                        buttonSize: buttonSize,
                        iconSize: iconSize,
                      ),
                    );
                  }
                  if (tallBarLearnerHandRaiseShortcut) {
                    barTools.add(
                      _buildControlButton(
                        icon: Icons.pan_tool_alt_outlined,
                        label: _localHandRaised ? 'Lower hand' : 'Raise hand',
                        onPressed: _controlsEnabled ? _toggleHandRaise : () {},
                        isActive: _localHandRaised,
                        showActiveBadge: _localHandRaised,
                        enabled: _controlsEnabled,
                        buttonSize: buttonSize,
                        iconSize: iconSize,
                      ),
                    );
                  }
                  if (tallBarLearnerReactionsShortcut ||
                      tallBarTutorReactionsShortcut) {
                    barTools.add(
                      _buildControlButton(
                        icon: Icons.emoji_emotions_outlined,
                        label: _showReactionsPanel
                            ? 'Hide reactions'
                            : 'Reactions',
                        onPressed: _controlsEnabled
                            ? () {
                                safeSetState(() {
                                  _showReactionsPanel = !_showReactionsPanel;
                                });
                              }
                            : () {},
                        isActive: _showReactionsPanel,
                        showActiveBadge: _showReactionsPanel,
                        enabled: _controlsEnabled,
                        buttonSize: buttonSize,
                        iconSize: iconSize,
                      ),
                    );
                  }
                  barTools.add(
                    _buildMoreOptionsMenuButton(
                      buttonSize: buttonSize,
                      iconSize: iconSize,
                      connectionHelpEnabled: connectionHelpEnabled,
                      includeScreenShare: includeScreenShareInMoreMenu,
                      showTeachingToolsInMore: showTeachingToolsInMore,
                      showLearnerWorkspaceInMore: showLearnerWorkspaceInMore,
                      showReactionsInMore: showReactionsInMore,
                      showInCallMessagesInMore: showMessagesInMore,
                      showHandRaiseInMore: showHandRaiseInMore,
                    ),
                  );
                  barTools.add(
                    Container(
                      width: 1,
                      height: buttonSize * 0.5,
                      color: Colors.white.withOpacity(0.22),
                    ),
                  );
                  barTools.add(
                    _buildControlButton(
                      icon: Icons.call_end,
                      label: 'Leave',
                      onPressed: _endCall,
                      isActive: false,
                      isDanger: true,
                      enabled: true,
                      buttonSize: buttonSize,
                      iconSize: iconSize,
                    ),
                  );

                  final spacedTools = _interleaveControlBarGap(
                    barTools,
                    toolGap,
                  );

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: spacedTools,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build screen share button (hidden on mobile web via caller).
  /// Android web supports getDisplayMedia; iOS Safari does not.
  Widget _buildScreenShareButton({
    required double buttonSize,
    required double iconSize,
  }) {
    return _buildControlButton(
      icon: Icons.screen_share,
      label: _localScreenShareCapturing ? 'Stop Sharing' : 'Share Screen',
      onPressed: _controlsEnabled ? _toggleScreenSharing : () {},
      isActive: _localScreenShareCapturing,
      showActiveBadge: _localScreenShareCapturing,
      enabled: _controlsEnabled,
      buttonSize: buttonSize,
      iconSize: iconSize,
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

  /// Build control button: [useMediaToggleStyle] = glass/outline when live, **filled white + dark icons** when muted/off (Preply-style on dark dock).
  /// Optional [showSpeakingWave] shows a small wave at bottom of button (e.g. for mic when speaking).
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
    String? semanticLabel,
    bool isDanger = false,
    bool showMutedIndicator = false,
    bool useMediaToggleStyle = false,
    bool showActiveBadge = false,
    bool showSpeakingWave = false,
    double speakingWaveAmplitude = 1,
    bool enabled = true,
    double buttonSize = 58,
    double iconSize = 26,
  }) {
    Color bgColor;
    BoxBorder? circleBorder;
    Color iconColor;
    Color slashColor;

    if (isDanger) {
      bgColor = Colors.red;
      circleBorder = null;
      iconColor = Colors.white;
      slashColor = Colors.white38;
    } else if (showMutedIndicator) {
      if (useMediaToggleStyle) {
        // Preply-style: high-contrast "off" read on deep blue chrome (avoid rose/red mute pills).
        bgColor = Colors.white;
        circleBorder = Border.all(
          color: Colors.black.withOpacity(0.08),
          width: 1,
        );
        iconColor = const Color(0xFF121212);
        slashColor = iconColor;
      } else {
        bgColor = Colors.white.withOpacity(0.08);
        circleBorder = Border.all(
          color: Colors.white.withOpacity(0.36),
          width: 1.1,
        );
        iconColor = Colors.white;
        slashColor = Colors.white38;
      }
    } else {
      bgColor = isActive
          ? Colors.white.withOpacity(0.18)
          : Colors.white.withOpacity(0.08);
      circleBorder = Border.all(
        color: Colors.white.withOpacity(isActive ? 0.44 : 0.34),
        width: 1.15,
      );
      iconColor = Colors.white;
      slashColor = Colors.white38;
    }

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
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: circleBorder,
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
                  Icon(icon, color: iconColor, size: iconSize),
                  // Extra slash only for non–media-toggle buttons; mic_off / videocam_off already imply mute.
                  if (showMutedIndicator && !useMediaToggleStyle)
                    Positioned(
                      top: buttonSize * 0.17,
                      right: buttonSize * 0.17,
                      child: Container(
                        width: buttonSize * 0.2,
                        height: 1.5,
                        decoration: BoxDecoration(
                          color: slashColor,
                          borderRadius: BorderRadius.circular(1),
                        ),
                        transform: Matrix4.rotationZ(-0.785398),
                      ),
                    ),
                  if (showSpeakingWave)
                    _buildSpeakingWave(amplitude: speakingWaveAmplitude),
                  if (showActiveBadge && isActive)
                    Positioned(
                      top: buttonSize * 0.15,
                      right: buttonSize * 0.15,
                      child: Container(
                        width: buttonSize * 0.18,
                        height: buttonSize * 0.18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black.withOpacity(0.18),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.check,
                          size: buttonSize * 0.12,
                          color: const Color(0xFF0F172A),
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
    if (!enabled) {
      return IgnorePointer(
        ignoring: true,
        child: Opacity(opacity: 0.45, child: content),
      );
    }
    return content;
  }

  /// Small wave bars (audio level) for speaking indicator next to mic icon.
  Widget _buildSpeakingWave({double amplitude = 1}) {
    final amp = amplitude.clamp(0.0, 1.0);
    return Positioned(
      bottom: 10,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (i) {
          final base = 4 + (i % 2) * 4.0;
          return Container(
            width: 2,
            height: base + amp * (6 + i * 2.0),
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

  Widget _buildRemoteHandRaiseChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xC2202D47),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pan_tool_alt, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'Learner hand raised',
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

  /// Convert technical error messages to user-friendly ones
  String _toUserFriendlyError(String error) {
    String msg = error;
    if (msg.startsWith('Failed to join: ')) msg = msg.substring(15);
    if (msg.startsWith('Exception: ')) msg = msg.substring(11);
    final lowerMsg = msg.toLowerCase();
    if (lowerMsg.contains('errjoinchannelrejected') ||
        lowerMsg.contains('join channel rejected') ||
        lowerMsg.contains('session is resyncing') ||
        lowerMsg.contains('reconnecting')) {
      return 'Session is resyncing. Reconnecting...';
    }
    if (msg.contains('permission') ||
        msg.contains('Permission') ||
        msg.contains('NotAllowedError') ||
        msg.contains('NotAllowed')) {
      return 'Camera and microphone are blocked. Allow access in browser/app settings, refresh, then rejoin.';
    }
    if (msg.contains('CORS') ||
        msg.contains('cors') ||
        msg.contains('API URL') ||
        msg.contains('origin') ||
        msg.contains('Check:')) {
      return 'Poor network connection. Please check your internet and try again.';
    }
    if (msg.contains('timeout') ||
        msg.contains('unreachable') ||
        msg.contains('slow to respond')) {
      return 'Connection timed out. Please check your connection and try again.';
    }
    if (msg.contains('Unauthorized') || msg.contains('401'))
      return 'Session expired. Please log in again.';
    if (msg.contains('Access denied') || msg.contains('403'))
      return 'You do not have access to this session.';
    if (msg.contains('Something went wrong on our end')) return msg;
    if (msg.contains('Connection failed') ||
        msg.contains('Unable to connect') ||
        msg.contains('Connection timed out') ||
        msg.contains('Connection error') ||
        msg.contains('Poor network')) {
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
        await _initializeSession(forceWebRtcFullReset: true);
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
    final isNetworkIssue =
        lowerMessage.contains('network') ||
        lowerMessage.contains('connection') ||
        lowerMessage.contains('internet') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('poor');
    final isPermissionBlocked =
        lowerMessage.contains('camera and microphone are blocked') ||
        (lowerMessage.contains('camera') &&
            lowerMessage.contains('allow access'));
    final iconColor = isSessionExpired
        ? AppTheme.warning
        : isNetworkIssue
        ? AppTheme.softYellow
        : AppTheme.error;
    final title = isSessionExpired
        ? 'Session Expired'
        : isNetworkIssue
        ? 'Connection issue'
        : isPermissionBlocked
        ? 'Permissions Required'
        : 'Error';

    if (isNetworkIssue) {
      return Positioned.fill(
        child: Material(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CallTransitionCard(
                    title: title,
                    subtitle: message,
                    icon: Icons.wifi_off_rounded,
                    accentColor: iconColor,
                    footnote: null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _retryFromError,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                    ),
                    child: Text(
                      'Retry',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.14),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPermissionBlocked
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
      ),
    );
  }

  Widget _buildCallTransitionSurface({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    String? footnote,
  }) {
    return Container(
      color: _kSoftDark,
      child: SafeArea(
        child: Center(
          child: _CallTransitionCard(
            title: title,
            subtitle: subtitle,
            icon: icon,
            accentColor: accentColor,
            footnote: footnote,
          ),
        ),
      ),
    );
  }

  /// Build loading overlay (branded and animated, no generic spinner)
  Widget _buildLoadingOverlay() {
    return _buildCallTransitionSurface(
      title: 'Connecting call',
      subtitle: _joinOverlayDetail,
      icon: Icons.videocam_rounded,
      accentColor: Colors.green,
      footnote: null,
    );
  }
}

class _CallTransitionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String? footnote;

  const _CallTransitionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.footnote,
  });

  @override
  State<_CallTransitionCard> createState() => _CallTransitionCardState();
}

class _CallTransitionCardState extends State<_CallTransitionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final haloScale = 1 + (t * 0.09);
        final haloOpacity = 0.22 + ((1 - t) * 0.18);
        final bar1 = 0.25 + (t * 0.75);
        final bar2 = 0.25 + (((1 - (t - 0.5).abs() * 2).clamp(0, 1)) * 0.75);
        final bar3 = 0.25 + ((1 - t) * 0.75);

        return Container(
          width: 320,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: haloScale,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.accentColor.withOpacity(haloOpacity),
                      ),
                    ),
                  ),
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          widget.accentColor.withOpacity(0.95),
                          widget.accentColor.withOpacity(0.68),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 30),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (widget.footnote != null &&
                  widget.footnote!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  widget.footnote!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.48),
                    fontSize: 11.8,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _signalBar(widget.accentColor, bar1),
                  const SizedBox(width: 6),
                  _signalBar(widget.accentColor, bar2),
                  const SizedBox(width: 6),
                  _signalBar(widget.accentColor, bar3),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _signalBar(Color color, double factor) {
    final height = 8 + (18 * factor);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 6,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withOpacity(0.92),
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
            'Waiting for ${widget.waitingFor ?? 'participant'}$dots',
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
