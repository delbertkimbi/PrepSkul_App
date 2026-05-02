import 'dart:async' show Timer, unawaited;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/skulmate/services/game_sound_service.dart';
import 'package:video_player/video_player.dart';

enum SkulMateMascotState { neutral, thinking, encouraging, celebration }

class SkulMateMascotMediaWidget extends StatefulWidget {
  final SkulMateMascotState state;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool autoplay;
  final bool loop;
  final bool useLandscapeFrame;

  /// 0.0 = muted (default). Mascot clips should not compete with game BGM/TTS.
  final double videoVolume;

  /// When true, skips video and shows the static mascot image only (e.g. tiny HUD chips).
  final bool preferStaticImage;

  /// Frame fill behind mascot art (matches quiz / companion card greys, not stark white).
  final Color frameBackgroundColor;

  const SkulMateMascotMediaWidget({
    super.key,
    required this.state,
    this.width,
    this.height,
    this.borderRadius = 16,
    this.autoplay = true,
    this.loop = false,

    /// When true, wraps content in a square [AspectRatio] (1:1). Mascot art is square; avoid 16:9.
    this.useLandscapeFrame = false,
    this.videoVolume = 0.0,
    this.preferStaticImage = false,
    this.frameBackgroundColor = AppTheme.neutral100,
  });

  @override
  State<SkulMateMascotMediaWidget> createState() => _SkulMateMascotMediaWidgetState();
}

class _SkulMateMascotMediaWidgetState extends State<SkulMateMascotMediaWidget>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _videoDimensionsReady = false;
  Timer? _fallbackTimer;
  late AnimationController _fadeOutController;
  late Animation<double> _videoOpacity;

  static const String _animDir = 'assets/characters/animations/';

  static List<String> _videoPathCandidates(SkulMateMascotState state) {
    switch (state) {
      case SkulMateMascotState.neutral:
        return ['${_animDir}Neutral.mp4', '${_animDir}neutral.mp4'];
      case SkulMateMascotState.thinking:
        return ['${_animDir}Think.mp4', '${_animDir}think.mp4'];
      case SkulMateMascotState.encouraging:
        return ['${_animDir}Encouraging.mp4', '${_animDir}encouraging.mp4'];
      case SkulMateMascotState.celebration:
        return ['${_animDir}Celebrate.mp4', '${_animDir}celebrate.mp4'];
    }
  }

  static const Map<SkulMateMascotState, String> _imagePaths = {
    SkulMateMascotState.neutral: 'assets/characters/mascots/default.png',
    SkulMateMascotState.thinking: 'assets/characters/mascots/thinking.png',
    SkulMateMascotState.encouraging: 'assets/characters/mascots/encouraging.png',
    SkulMateMascotState.celebration: 'assets/characters/mascots/celebration.png',
  };

  @override
  void initState() {
    super.initState();
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _videoOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeOutCubic),
    );
    _fadeOutController.addStatusListener(_onFadeStatus);
    if (!widget.preferStaticImage) {
      _initVideo();
    }
  }

  void _onFadeStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _finalizeVideoToStill();
    }
  }

  @override
  void didUpdateWidget(covariant SkulMateMascotMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state ||
        oldWidget.preferStaticImage != widget.preferStaticImage) {
      _resetForNewState();
      if (!widget.preferStaticImage) {
        _initVideo();
      } else if (mounted) {
        setState(() => _videoReady = false);
      }
    }
  }

  void _disposeVideoOnly() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    final c = _controller;
    _controller?.removeListener(_onVideoTick);
    _controller?.removeListener(_onVideoSizeOrCompletion);
    _controller = null;
    _videoReady = false;
    _videoDimensionsReady = false;
    c?.dispose();
  }

  void _resetForNewState() {
    _disposeVideoOnly();
    _fadeOutController.reset();
  }

  void _onVideoSizeOrCompletion() {
    if (!mounted || _controller == null || _videoDimensionsReady) return;
    final v = _controller!.value;
    // First frame / dimension update: rebuild so FittedBox gets non-zero intrinsic size.
    if (v.isInitialized && v.size.width > 0 && v.size.height > 0) {
      _videoDimensionsReady = true;
      setState(() {});
    }
  }

  Future<void> _initVideo() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted && !_videoReady && _controller == null) {
        setState(() {});
      }
    });

    final forState = widget.state;
    final candidates = _videoPathCandidates(forState);
    for (final path in candidates) {
      final controller = VideoPlayerController.asset(path);
      try {
        await controller.initialize();
        if (!mounted || widget.state != forState) {
          await controller.dispose();
          return;
        }
        await controller.setLooping(widget.loop);
        await controller.setVolume(widget.videoVolume.clamp(0.0, 1.0));
        // Assign before listeners so _onVideoTick always sees _controller.
        _controller = controller;
        controller.addListener(_onVideoTick);
        controller.addListener(_onVideoSizeOrCompletion);
        if (widget.autoplay) {
          await controller.play();
        }
        if (!mounted || widget.state != forState) {
          controller.removeListener(_onVideoTick);
          controller.removeListener(_onVideoSizeOrCompletion);
          await controller.dispose();
          _controller = null;
          return;
        }
        if (mounted) {
          setState(() {
            _videoReady = true;
          });
        }
        return;
      } catch (_) {
        await controller.dispose();
      }
    }

    if (mounted && widget.state == forState) {
      setState(() {
        _videoReady = false;
      });
    }
  }

  void _onVideoTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized || widget.loop || !mounted) return;
    if (_fadeOutController.isAnimating || _fadeOutController.value >= 1.0) return;
    final v = c.value;
    final d = v.duration;
    if (d == Duration.zero) return;

    // Prefer platform isCompleted; fall back for drivers that stop before updating position.
    final pos = v.position;
    final nearEnd = pos + const Duration(milliseconds: 80) >= d;
    final stalledAtEnd =
        !v.isPlaying &&
        pos >= d - const Duration(milliseconds: 200) &&
        pos > Duration.zero;
    final ended = v.isCompleted || nearEnd || stalledAtEnd;
    if (ended) {
      c.removeListener(_onVideoTick);
      c.removeListener(_onVideoSizeOrCompletion);
      _fadeOutController.forward();
    }
  }

  void _finalizeVideoToStill() {
    final c = _controller;
    if (c != null) {
      c.removeListener(_onVideoTick);
      c.removeListener(_onVideoSizeOrCompletion);
      c.dispose();
      _controller = null;
    }
    _videoReady = false;
    _fadeOutController.reset();
    // Video player can steal/duck BGM on some devices; restore generation/game music.
    unawaited(GameSoundService().resumeBgmIfNeeded());
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 120),
        () => GameSoundService().resumeBgmIfNeeded(),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Never use generic "pet" or school icons — last resort is brand color + monogram.
  Widget _mascotLoadFallback() {
    return Container(
      color: widget.frameBackgroundColor,
      alignment: Alignment.center,
      child: Text(
        'S',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildImage(String imagePath, {required bool fillFrame}) {
    return Image.asset(
      imagePath,
      fit: fillFrame ? BoxFit.cover : BoxFit.contain,
      alignment: Alignment.center,
      errorBuilder: (_, __, ___) => _mascotLoadFallback(),
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _disposeVideoOnly();
    _fadeOutController.removeStatusListener(_onFadeStatus);
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _imagePaths[widget.state]!;

    final Widget inner = widget.preferStaticImage
        ? _buildImage(imagePath, fillFrame: false)
        : Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              _buildImage(imagePath, fillFrame: true),
              if (_videoReady && _controller != null)
                Positioned.fill(
                  child: FadeTransition(
                    opacity: _videoOpacity,
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: _controller!.value.size.width > 0
                              ? _controller!.value.size.width
                              : 1,
                          height: _controller!.value.size.height > 0
                              ? _controller!.value.size.height
                              : 1,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );

    final frame = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.frameBackgroundColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: AppTheme.softBorder.withValues(alpha: 0.45)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: inner,
        ),
      ),
    );

    if (!widget.useLandscapeFrame) return frame;
    return AspectRatio(
      aspectRatio: 1,
      child: frame,
    );
  }
}
