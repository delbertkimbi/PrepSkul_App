import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/booking/screens/session_detail_screen.dart';
import 'package:prepskul/features/booking/utils/session_live_utils.dart';
import 'package:prepskul/features/sessions/services/live_session_overlay_controller.dart';
import 'package:prepskul/features/tutor/screens/tutor_session_detail_full_screen.dart';

/// Draggable square PiP shown while a session is in progress (hidden on live detail).
class LiveSessionFloatingBarOverlay extends StatefulWidget {
  const LiveSessionFloatingBarOverlay({super.key});

  @override
  State<LiveSessionFloatingBarOverlay> createState() =>
      _LiveSessionFloatingBarOverlayState();
}

class _LiveSessionFloatingBarOverlayState
    extends State<LiveSessionFloatingBarOverlay> {
  static const _pipSize = 88.0;
  static const _gapAboveNavBar = 3.0;
  static const _rightPadding = 16.0;

  final _controller = LiveSessionOverlayController.instance;
  Timer? _tick;
  Offset _dragOffset = Offset.zero;
  bool _didDrag = false;
  String? _trackedSessionId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final session = _controller.session;
      if (session != null &&
          !SessionLiveUtils.isSessionGenuinelyLive(session)) {
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

  /// Default anchor: right-padded, sitting 3px above the bottom tab bar.
  double _anchorBottom(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // Icon row + label row on a fixed [BottomNavigationBar].
    const navBarHeight = kBottomNavigationBarHeight + 32.0;
    return safeBottom + navBarHeight + _gapAboveNavBar;
  }

  void _clampDragOffset(BuildContext context, double anchorBottom) {
    final size = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final maxUp = size.height - anchorBottom - _pipSize - topPad - 8;
    final maxLeft = size.width - _rightPadding - _pipSize - 8;
    _dragOffset = Offset(
      _dragOffset.dx.clamp(-maxLeft, _rightPadding - 8),
      _dragOffset.dy.clamp(-maxUp, 0),
    );
  }

  void _openLiveSession() {
    final session = _controller.session;
    final role = _controller.userRole;
    if (session == null || role == null) return;

    final nav = NavigationService().navigatorKey?.currentState;
    if (nav == null) return;

    final sessionId = session['id']?.toString() ?? '';
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
                errorWidget: (_, __, ___) => _initialFallback(fallbackName, size),
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
              child: const Icon(Icons.videocam_rounded, size: 12, color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    if (!_controller.isActive) return const SizedBox.shrink();

    final startedAt = _controller.startedAt;
    final elapsed = startedAt != null
        ? DateTime.now().difference(startedAt)
        : Duration.zero;
    final anchorBottom = _anchorBottom(context);

    return Positioned(
      right: _rightPadding - _dragOffset.dx,
      bottom: anchorBottom - _dragOffset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _didDrag = true;
            _dragOffset -= details.delta;
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
            width: _pipSize,
            height: _pipSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryDark,
                  AppTheme.primaryColor,
                ],
              ),
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
            child: Stack(
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
            ),
          ),
        ),
      ),
    );
  }
}
