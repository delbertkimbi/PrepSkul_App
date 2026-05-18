import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora_rtc_engine;
import 'agora_video_view.dart' as agora_widget;

/// Draggable PrepSkul self-view (spotlight PiP): move to reduce mirror fatigue; tap minimize for a tiny chip.
class LocalVideoPIP extends StatefulWidget {
  final agora_rtc_engine.RtcEngine engine;
  final int? localUid;
  final bool isVideoEnabled;
  final bool isAudioEnabled;

  /// Saturated fill behind the camera-off icon (spotlight PiP), Discord-style.
  final Color? cameraOffBackdrop;

  /// Profile card when camera is off (name + avatar ring more professional than blank color + icon).
  final String? selfDisplayName;
  final String? selfAvatarUrl;
  final String? selfInitials;

  /// When true, show speaking indicator (green border + badge).
  final bool isSpeaking;

  /// Solo waiting: top-left control enlarges self-view on the main stage (Meet-style).
  final VoidCallback? onExpandSelfView;
  final VoidCallback? onTap;

  /// When false, PiP stays at the default corner (Meet-style multi-participant).
  final bool allowDrag;

  /// Minimum inset from the bottom of the video lane (match session control bar reserve).
  final double bottomDragReserve;

  /// Alone/waiting layouts can prefer top corner to avoid reminder-card overlap.
  final bool preferTopCorner;

  /// Show a subtle one-time drag hint for the first few seconds.
  final bool showInitialDragHint;

  /// Called when the one-time drag hint is shown.
  final VoidCallback? onInitialDragHintShown;

  const LocalVideoPIP({
    Key? key,
    required this.engine,
    required this.localUid,
    required this.isVideoEnabled,
    required this.isAudioEnabled,
    this.cameraOffBackdrop,
    this.selfDisplayName,
    this.selfAvatarUrl,
    this.selfInitials,
    this.isSpeaking = false,
    this.onExpandSelfView,
    this.onTap,
    this.allowDrag = true,
    this.bottomDragReserve = 50,
    this.preferTopCorner = false,
    this.showInitialDragHint = false,
    this.onInitialDragHintShown,
  }) : super(key: key);

  @override
  State<LocalVideoPIP> createState() => _LocalVideoPIPState();
}

class _LocalVideoPIPState extends State<LocalVideoPIP>
    with SingleTickerProviderStateMixin {
  /// Absolute top-left in the video lane (clamped via [LayoutBuilder] constraints).
  Offset? _positionAbs;
  bool _minimized = false;
  bool _pipHovered = false;
  bool _showDragHint = false;
  bool _initialHintConsumed = false;
  Timer? _dragHintTimer;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  double? _pipLaneMaxW;
  double? _pipLaneMaxH;

  /// Live camera tile active (shows corner mute/cam badges — not duplicated on profile plate).
  bool get _liveCameraTile => widget.localUid != null && widget.isVideoEnabled;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowInitialDragHint();
    });
  }

  @override
  void dispose() {
    _dragHintTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LocalVideoPIP oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bottomDragReserve != oldWidget.bottomDragReserve ||
        widget.allowDrag != oldWidget.allowDrag ||
        widget.preferTopCorner != oldWidget.preferTopCorner) {
      _positionAbs = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowInitialDragHint();
    });
  }

  void _maybeShowInitialDragHint() {
    if (!widget.allowDrag ||
        !widget.showInitialDragHint ||
        _initialHintConsumed ||
        !mounted) {
      return;
    }
    _initialHintConsumed = true;
    _dragHintTimer?.cancel();
    if (mounted) setState(() => _showDragHint = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onInitialDragHintShown?.call();
    });
    _dragHintTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _showDragHint = false);
    });
  }

  Size _pipSize(MediaQueryData mq) {
    final isWide = mq.size.width > 400;
    if (_minimized) {
      return const Size(52, 52);
    }
    return isWide ? const Size(200, 150) : const Size(160, 120);
  }

  String get _effectiveName =>
      (widget.selfDisplayName?.trim().isNotEmpty ?? false)
      ? widget.selfDisplayName!.trim()
      : 'You';

  String get _effectiveInitials {
    final i = widget.selfInitials?.trim();
    if (i != null && i.isNotEmpty) return i;
    final n = _effectiveName;
    if (n.length >= 2) return n.substring(0, 2).toUpperCase();
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  Widget _avatarCore(double diameter) {
    final url = widget.selfAvatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: Colors.black26,
            width: diameter,
            height: diameter,
          ),
          errorWidget: (_, __, ___) => _initialsFallback(diameter),
        ),
      );
    }
    return _initialsFallback(diameter);
  }

  Widget _initialsFallback(double diameter) {
    return Container(
      width: diameter,
      height: diameter,
      color: Colors.black.withOpacity(0.35),
      alignment: Alignment.center,
      child: Text(
        _effectiveInitials,
        style: GoogleFonts.poppins(
          fontSize: diameter * 0.36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _cameraOffPlate() {
    final base = widget.cameraOffBackdrop ?? const Color(0xFF16233C);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(base, Colors.black, 0.38)!,
                Color.lerp(base, Colors.black, 0.72)!,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 28, 8, 26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(child: _avatarCore(48)),
              ),
              const SizedBox(height: 6),
              Text(
                _effectiveName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                !widget.isAudioEnabled ? 'Camera off · Mic off' : 'Camera off',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 9.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const double _kCornerPadding = 12;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final pipSize = _pipSize(mq);

    return LayoutBuilder(
      builder: (context, constraints) {
        final laneW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mq.size.width;
        final laneH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mq.size.height;

        final laneJumpW =
            _pipLaneMaxW != null &&
            _positionAbs != null &&
            (laneW - _pipLaneMaxW!).abs() > 80;
        final laneJumpH =
            _pipLaneMaxH != null &&
            _positionAbs != null &&
            (laneH - _pipLaneMaxH!).abs() > 80;
        if (laneJumpW || laneJumpH) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _positionAbs = null);
          });
        }
        _pipLaneMaxW = laneW;
        _pipLaneMaxH = laneH;

        final maxX = (laneW - pipSize.width - _kCornerPadding).clamp(
          0.0,
          double.infinity,
        );
        final bottomReserve = widget.bottomDragReserve;
        final maxY = (laneH - pipSize.height - bottomReserve).clamp(
          0.0,
          double.infinity,
        );

        final defaultPosition = widget.preferTopCorner
            ? Offset(
                (laneW - pipSize.width - _kCornerPadding).clamp(0.0, maxX),
                _kCornerPadding.clamp(0.0, maxY),
              )
            : Offset(
                (laneW - pipSize.width - _kCornerPadding).clamp(0.0, maxX),
                (laneH - pipSize.height - bottomReserve).clamp(0.0, maxY),
              );

        final current = _positionAbs ?? defaultPosition;
        final constrained = Offset(
          current.dx.clamp(0.0, maxX),
          current.dy.clamp(0.0, maxY),
        );

        Widget minimizedChip() {
          return ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: pipSize.width,
              height: pipSize.height,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
                color: const Color(0xFF16233C),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  ClipOval(child: _avatarCore(pipSize.width * 0.72)),
                  if (!widget.isAudioEnabled)
                    Positioned(
                      bottom: 4,
                      child: Icon(
                        Icons.mic_off,
                        color: Colors.redAccent.withOpacity(0.95),
                        size: 12,
                      ),
                    ),
                  if (!widget.isVideoEnabled && widget.isAudioEnabled)
                    Positioned(
                      bottom: 4,
                      child: Icon(
                        Icons.videocam_off_rounded,
                        color: Colors.white54,
                        size: 11,
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        Widget expandedPip() {
          return ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: pipSize.width,
              height: pipSize.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: () {
                      if (widget.localUid == null) {
                        return Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                            ),
                          ),
                        );
                      }
                      if (widget.isVideoEnabled) {
                        return agora_widget.AgoraVideoViewWidget(
                          engine: widget.engine,
                          uid: widget.localUid,
                          isLocal: true,
                          sourceType: agora_rtc_engine
                              .VideoSourceType
                              .videoSourceCamera,
                        );
                      }
                      return _cameraOffPlate();
                    }(),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Material(
                      color: Colors.black.withOpacity(0.55),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          if (widget.onExpandSelfView != null) {
                            widget.onExpandSelfView!();
                          } else {
                            setState(() => _minimized = true);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            widget.onExpandSelfView != null
                                ? Icons.open_in_full_rounded
                                : Icons.unfold_less_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_liveCameraTile)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isAudioEnabled ? Icons.mic : Icons.mic_off,
                              size: 12,
                              color: widget.isAudioEnabled
                                  ? Colors.white
                                  : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isVideoEnabled
                                  ? Icons.videocam
                                  : Icons.videocam_off,
                              size: 12,
                              color: widget.isVideoEnabled
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.allowDrag &&
                      (_pipHovered || _showDragHint) &&
                      !_minimized)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'You · drag to move',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (widget.isSpeaking && _liveCameraTile)
                    Positioned(
                      left: 4,
                      bottom:
                          widget.allowDrag &&
                              (_pipHovered || _showDragHint) &&
                              !_minimized
                          ? 22
                          : 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(3, (i) {
                          return Container(
                            width: 1.5,
                            height: 3 + (i % 2) * 2.0,
                            margin: const EdgeInsets.symmetric(horizontal: 0.5),
                            decoration: BoxDecoration(
                              color: Colors.white70,
                              borderRadius: BorderRadius.circular(0.5),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        final body = _minimized ? minimizedChip() : expandedPip();

        // [Positioned] must be a direct child of [Stack]. This widget is often placed
        // inside an outer [Stack] as a non-positioned child; returning [LayoutBuilder] →
        // [Positioned] would attach StackParentData under BoxParentData and throw.
        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Positioned(
              left: constrained.dx,
              top: constrained.dy,
              child: widget.allowDrag
                  ? MouseRegion(
                      onEnter: (_) => setState(() => _pipHovered = true),
                      onExit: (_) => setState(() => _pipHovered = false),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          final base = _positionAbs ?? defaultPosition;
                          final next = base + details.delta;
                          setState(() {
                            _positionAbs = Offset(
                              next.dx.clamp(0.0, maxX),
                              next.dy.clamp(0.0, maxY),
                            );
                          });
                        },
                        onTap: _minimized
                            ? () => setState(() => _minimized = false)
                            : () => widget.onTap?.call(),
                        child: body,
                      ),
                    )
                  : GestureDetector(
                      onTap: _minimized
                          ? () => setState(() => _minimized = false)
                          : () => widget.onTap?.call(),
                      child: body,
                    ),
            ),
          ],
        );
      },
    );
  }
}
