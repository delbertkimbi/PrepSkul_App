import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora_rtc_engine;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/booking/screens/session_detail_screen.dart';
import 'package:prepskul/features/booking/utils/session_live_utils.dart';
import 'package:prepskul/features/sessions/screens/agora_prejoin_screen.dart';
import 'package:prepskul/features/sessions/screens/agora_video_session_screen.dart';
import 'package:prepskul/features/sessions/services/agora_service.dart';
import 'package:prepskul/features/sessions/services/live_session_overlay_controller.dart';
import 'package:prepskul/features/sessions/utils/floating_pip_drag.dart';
import 'package:prepskul/features/sessions/widgets/agora_video_view.dart'
    as agora_widget;
import 'package:prepskul/features/tutor/screens/tutor_session_detail_full_screen.dart';

/// Draggable live PiP shown while a session is in progress (hidden on live detail).
///
/// When the Agora channel is still joined (minimized call), shows a live video
/// tile with mute/unmute. Otherwise shows the session avatar chip.
class LiveSessionFloatingBarOverlay extends StatefulWidget {
  const LiveSessionFloatingBarOverlay({super.key});

  @override
  State<LiveSessionFloatingBarOverlay> createState() =>
      _LiveSessionFloatingBarOverlayState();
}

class _LiveSessionFloatingBarOverlayState
    extends State<LiveSessionFloatingBarOverlay> {
  static const _chipSize = 88.0;
  static const _videoWidth = 112.0;
  static const _videoHeight = 148.0;
  static const _gapAboveNavBar = 3.0;
  static const _rightPadding = 16.0;

  final _controller = LiveSessionOverlayController.instance;
  final _agora = AgoraService();
  Timer? _tick;
  StreamSubscription<int>? _joinedSub;
  StreamSubscription<int>? _leftSub;
  StreamSubscription<Map<String, dynamic>>? _remoteVideoMutedSub;
  Offset _dragOffset = Offset.zero;
  bool _didDrag = false;
  bool _muteBusy = false;
  final Set<int> _remoteVideoOffUids = <int>{};
  String? _trackedSessionId;

  bool get _inCall => _agora.isInChannel && _agora.engine != null;

  double get _pipW => _inCall ? _videoWidth : _chipSize;
  double get _pipH => _inCall ? _videoHeight : _chipSize;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _joinedSub = _agora.userJoinedStream.listen((uid) {
      _remoteVideoOffUids.remove(uid);
      if (mounted) setState(() {});
    });
    _leftSub = _agora.userLeftStream.listen((uid) {
      _remoteVideoOffUids.remove(uid);
      if (mounted) setState(() {});
    });
    _remoteVideoMutedSub = _agora.remoteVideoMutedStream.listen((event) {
      final uid = event['uid'] as int?;
      if (uid == null) return;
      if (event['muted'] == true) {
        _remoteVideoOffUids.add(uid);
      } else {
        _remoteVideoOffUids.remove(uid);
      }
      if (mounted) setState(() {});
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final session = _controller.session;
      if (session != null &&
          !SessionLiveUtils.isSessionGenuinelyLive(session) &&
          !_inCall) {
        _controller.clear();
        return;
      }
      if (_controller.isActive) setState(() {});
    });
    Future.microtask(() => _controller.refreshFromServer());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _joinedSub?.cancel();
    _leftSub?.cancel();
    _remoteVideoMutedSub?.cancel();
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final sessionId = _controller.sessionId;
    if (sessionId != _trackedSessionId) {
      _trackedSessionId = sessionId;
      _dragOffset = Offset.zero;
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  double _anchorBottom(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    const navBarHeight = kBottomNavigationBarHeight + 32.0;
    return safeBottom + navBarHeight + _gapAboveNavBar;
  }

  void _clampDragOffset(BuildContext context, double anchorBottom) {
    final size = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final maxUp = size.height - anchorBottom - _pipH - topPad - 8;
    final maxLeft = size.width - _rightPadding - _pipW - 8;
    _dragOffset = FloatingPipDrag.clamp(
      offset: _dragOffset,
      maxUp: maxUp,
      maxLeft: maxLeft,
    );
  }

  Future<void> _toggleMute() async {
    if (!_inCall || _muteBusy) return;
    setState(() => _muteBusy = true);
    try {
      await _agora.toggleAudio();
    } finally {
      if (mounted) setState(() => _muteBusy = false);
    }
  }

  void _openLiveSession() {
    final session = _controller.session;
    final role = _controller.userRole;
    if (session == null || role == null) return;

    final nav = NavigationService().navigatorKey?.currentState;
    if (nav == null) return;

    final sessionId = session['id']?.toString() ?? '';
    final location = (session['location'] as String? ?? 'online').toLowerCase();

    // Already in the Agora channel (minimized) — return to the classroom.
    if (_inCall && sessionId.isNotEmpty) {
      _controller.setRouteSuppressed(true);
      nav.push(
        MaterialPageRoute(
          settings: RouteSettings(name: '/live-session-$sessionId'),
          builder: (_) => AgoraVideoSessionScreen(
            sessionId: sessionId,
            userRole: role == 'tutor' ? 'tutor' : 'learner',
            resumeExistingChannel: true,
            initialCameraEnabled: _agora.isVideoEnabled(),
            initialMicEnabled: _agora.isAudioEnabled(),
          ),
        ),
      );
      return;
    }

    if (role == 'tutor' && location == 'online' && sessionId.isNotEmpty) {
      nav
          .push<Map<String, dynamic>>(
        MaterialPageRoute(
          settings: RouteSettings(name: '/live-session-prejoin-$sessionId'),
          builder: (_) => AgoraPreJoinScreen(
            sessionId: sessionId,
            userRole: 'tutor',
          ),
        ),
      )
          .then((preJoinResult) {
        if (preJoinResult != null && preJoinResult['join'] == true) {
          nav.push(
            MaterialPageRoute(
              settings: RouteSettings(name: '/live-session-$sessionId'),
              builder: (_) => AgoraVideoSessionScreen(
                sessionId: sessionId,
                userRole: 'tutor',
                initialCameraEnabled: preJoinResult['camera'] as bool? ?? false,
                initialMicEnabled: preJoinResult['mic'] as bool? ?? false,
              ),
            ),
          );
        }
      });
      return;
    }
    if (role == 'tutor') {
      nav.push(
        MaterialPageRoute(
          settings: RouteSettings(name: '/live-session-$sessionId'),
          builder: (_) => TutorSessionDetailFullScreen(session: session),
        ),
      );
    } else {
      nav.push(
        MaterialPageRoute(
          settings: RouteSettings(name: '/live-session-$sessionId'),
          builder: (_) => SessionDetailScreen(session: session),
        ),
      );
    }
  }

  String _formatElapsed(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'Live';
  }

  String _initial(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  Widget _avatarCircle({
    required String? url,
    required String fallbackName,
    required double size,
    Color ringColor = Colors.white24,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => _initialFallback(fallbackName, size),
                errorWidget: (_, __, ___) =>
                    _initialFallback(fallbackName, size),
              )
            : _initialFallback(fallbackName, size),
      ),
    );
  }

  Widget _initialFallback(String name, double size) {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: Text(
        _initial(name),
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
        ),
      ),
    );
  }

  Widget _buildAvatars() {
    final isOnline = _controller.isOnline;
    final localUrl = _controller.localAvatarUrl;
    final counterUrl = _controller.counterpartyAvatarUrl;
    final counterName = _controller.counterpartyName ?? 'Session';
    final role = _controller.userRole ?? 'user';
    final localName = role == 'tutor' ? 'You' : counterName;

    if (isOnline) {
      return Stack(
        alignment: Alignment.center,
        children: [
          _avatarCircle(
            url: counterUrl,
            fallbackName: counterName,
            size: 52,
            ringColor: AppTheme.skyBlue.withValues(alpha: 0.85),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54),
              ),
              child: const Icon(Icons.videocam_rounded,
                  size: 12, color: Colors.white),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: 64,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 4,
            child: _avatarCircle(
              url: localUrl,
              fallbackName: localName,
              size: 36,
              ringColor: AppTheme.skyBlue.withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            right: 0,
            top: 4,
            child: _avatarCircle(
              url: counterUrl,
              fallbackName: counterName,
              size: 36,
              ringColor: AppTheme.softYellow.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveVideoTile() {
    final engine = _agora.engine!;
    final remoteUid = _agora.primaryRemoteUid;
    final connection = _agora.currentConnection;
    final localUid = _agora.currentUID;
    final micOn = _agora.isAudioEnabled();

    Widget video;
    if (remoteUid != null &&
        connection != null &&
        !_remoteVideoOffUids.contains(remoteUid)) {
      video = agora_widget.AgoraVideoViewWidget(
        engine: engine,
        uid: remoteUid,
        isLocal: false,
        connection: connection,
      );
    } else if (remoteUid == null &&
        localUid != null &&
        _agora.isVideoEnabled()) {
      video = agora_widget.AgoraVideoViewWidget(
        engine: engine,
        uid: localUid,
        isLocal: true,
        sourceType: agora_rtc_engine.VideoSourceType.videoSourceCamera,
      );
    } else {
      video = ColoredBox(
        color: AppTheme.primaryDark,
        child: Center(
          child: _avatarCircle(
            url: _controller.counterpartyAvatarUrl,
            fallbackName: _controller.counterpartyName ?? 'Session',
            size: 56,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: video,
        ),
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentGreen.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'LIVE',
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 6,
          bottom: 6,
          child: Material(
            color: Colors.black.withValues(alpha: 0.55),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _muteBusy ? null : _toggleMute,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  micOn ? Icons.mic : Icons.mic_off,
                  size: 18,
                  color: micOn ? Colors.white : Colors.redAccent,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 6,
          bottom: 6,
          child: Material(
            color: Colors.black.withValues(alpha: 0.55),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openLiveSession,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.open_in_full, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChipTile(Duration elapsed) {
    return Stack(
      children: [
        Center(child: _buildAvatars()),
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentGreen.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'LIVE',
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 6,
          child: Text(
            _formatElapsed(elapsed),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isActive) return const SizedBox.shrink();

    final startedAt = _controller.startedAt;
    final elapsed = startedAt != null
        ? DateTime.now().difference(startedAt)
        : Duration.zero;
    final anchorBottom = _anchorBottom(context);
    final inCall = _inCall;

    return Positioned(
      right: _rightPadding - _dragOffset.dx,
      bottom: anchorBottom - _dragOffset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _didDrag = true;
            _dragOffset =
                FloatingPipDrag.applyPanDelta(_dragOffset, details.delta);
            _clampDragOffset(context, anchorBottom);
          });
        },
        onPanEnd: (_) {
          Future.delayed(const Duration(milliseconds: 120), () {
            _didDrag = false;
          });
        },
        onTap: () {
          if (!_didDrag) _openLiveSession();
        },
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          shadowColor: AppTheme.primaryColor.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: _pipW,
            height: _pipH,
            decoration: BoxDecoration(
              gradient: inCall
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryDark,
                        AppTheme.primaryColor,
                      ],
                    ),
              color: inCall ? Colors.black : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: inCall ? _buildLiveVideoTile() : _buildChipTile(elapsed),
          ),
        ),
      ),
    );
  }
}
