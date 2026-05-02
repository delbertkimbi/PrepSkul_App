import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora_rtc_engine;
import 'package:prepskul/core/theme/app_theme.dart';
import 'agora_video_view.dart' as agora_widget;

/// Draggable PrepSkul self-view (spotlight PiP): move to reduce mirror fatigue; tap minimize for a tiny chip.
class LocalVideoPIP extends StatefulWidget {
  final agora_rtc_engine.RtcEngine engine;
  final int? localUid;
  final bool isVideoEnabled;
  final bool isAudioEnabled;
  /// When true, show speaking indicator (green border + badge).
  final bool isSpeaking;
  final VoidCallback? onTap;

  const LocalVideoPIP({
    Key? key,
    required this.engine,
    required this.localUid,
    required this.isVideoEnabled,
    required this.isAudioEnabled,
    this.isSpeaking = false,
    this.onTap,
  }) : super(key: key);

  @override
  State<LocalVideoPIP> createState() => _LocalVideoPIPState();
}

class _LocalVideoPIPState extends State<LocalVideoPIP>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  bool _minimized = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updatePosition(Offset newPosition) {
    setState(() {
      _position = newPosition;
    });
  }

  Size _pipSize(MediaQueryData mq) {
    final isWide = mq.size.width > 400;
    if (_minimized) {
      return const Size(52, 52);
    }
    return isWide ? const Size(200, 150) : const Size(160, 120);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenSize = mq.size;
    final pipSize = _pipSize(mq);
    const padding = 16.0;
    const controlBarHeight = 100.0;

    final defaultPosition = Offset(
      screenSize.width - pipSize.width - padding,
      screenSize.height - pipSize.height - controlBarHeight,
    );

    final currentPosition = _position.dx == 0 && _position.dy == 0
        ? defaultPosition
        : _position;

    final constrainedX = currentPosition.dx.clamp(
      0.0,
      screenSize.width - pipSize.width,
    );
    final constrainedY = currentPosition.dy.clamp(
      0.0,
      screenSize.height - pipSize.height - 80,
    );

    final dragAccent =
        _isDragging ? AppTheme.primaryColor : Colors.white.withOpacity(0.35);

    Widget minimizedChip() {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: pipSize.width,
          height: pipSize.height,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: dragAccent, width: _isDragging ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            color: const Color(0xFF16233C),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isVideoEnabled
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded,
                color: Colors.white70,
                size: 22,
              ),
              const SizedBox(height: 2),
              Icon(
                widget.isAudioEnabled ? Icons.mic_none : Icons.mic_off,
                color:
                    widget.isAudioEnabled ? Colors.white54 : Colors.redAccent,
                size: 14,
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDragging
                  ? AppTheme.primaryColor.withOpacity(0.95)
                  : widget.isSpeaking
                      ? Colors.white54
                      : Colors.white.withOpacity(0.3),
              width: _isDragging ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              RepaintBoundary(
                child: widget.localUid != null && widget.isVideoEnabled
                    ? agora_widget.AgoraVideoViewWidget(
                        engine: widget.engine,
                        uid: widget.localUid,
                        isLocal: true,
                        sourceType:
                            agora_rtc_engine.VideoSourceType.videoSourceCamera,
                      )
                    : Container(
                        color: Colors.black,
                        child: Center(
                          child: widget.isVideoEnabled
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Icon(
                                  Icons.videocam_off,
                                  color: Colors.white.withOpacity(0.5),
                                  size: 32,
                                ),
                        ),
                      ),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: Material(
                  color: Colors.black.withOpacity(0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _minimized = true),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(
                        Icons.unfold_less_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
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
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
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
              if (widget.isSpeaking)
                Positioned(
                  left: 4,
                  bottom: 22,
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

    return Positioned(
      left: constrainedX,
      top: constrainedY,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          _updatePosition(
            Offset(
              constrainedX + details.delta.dx,
              constrainedY + details.delta.dy,
            ),
          );
        },
        onPanEnd: (_) => setState(() => _isDragging = false),
        onTap: _minimized
            ? () => setState(() => _minimized = false)
            : () => widget.onTap?.call(),
        child: _minimized ? minimizedChip() : expandedPip(),
      ),
    );
  }
}

