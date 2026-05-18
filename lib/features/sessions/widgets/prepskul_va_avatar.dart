import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// PrepSkul VA (Virtual Assistant) avatar shown during sessions to indicate monitoring.
/// UI-only: no backend; displays a circular avatar with pulsing + slowly rotating accent ring.
class PrepSkulVAAvatar extends StatefulWidget {
  /// Diameter of the avatar circle (default 48).
  final double size;

  const PrepSkulVAAvatar({Key? key, this.size = 48}) : super(key: key);

  @override
  State<PrepSkulVAAvatar> createState() => _PrepSkulVAAvatarState();
}

class _PrepSkulVAAvatarState extends State<PrepSkulVAAvatar>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _ringOpacityAnimation;
  late Animation<double> _ringWidthAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _ringOpacityAnimation = Tween<double>(begin: 0.35, end: 0.95).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _ringWidthAnimation = Tween<double>(begin: 1.4, end: 2.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final sweepSize = size + 8;
    return Semantics(
      label: 'PrepSkul virtual assistant monitoring',
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _rotateController]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              RotationTransition(
                turns: _rotateController,
                child: Container(
                  width: sweepSize,
                  height: sweepSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppTheme.accentBlue.withOpacity(0.02),
                        AppTheme.accentBlue.withOpacity(0.65),
                        const Color(0xFF4FC3F7).withOpacity(0.35),
                        AppTheme.accentBlue.withOpacity(0.02),
                      ],
                      stops: const [0.0, 0.35, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: size,
                height: size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentBlue
                          .withOpacity(_ringOpacityAnimation.value),
                      width: _ringWidthAnimation.value,
                    ),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryDark,
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/app_logo(blue).png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    Icons.record_voice_over,
                    size: size * 0.5,
                    color: Colors.white70,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Rotating accent ring around a waiting / placeholder avatar (e.g. remote participant).
class SessionWaitingAvatarRing extends StatefulWidget {
  final Color accent;
  final double size;
  final Widget child;

  const SessionWaitingAvatarRing({
    Key? key,
    required this.accent,
    required this.size,
    required this.child,
  }) : super(key: key);

  @override
  State<SessionWaitingAvatarRing> createState() =>
      _SessionWaitingAvatarRingState();
}

class _SessionWaitingAvatarRingState extends State<SessionWaitingAvatarRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotate;

  @override
  void initState() {
    super.initState();
    _rotate = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _rotate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outer = widget.size + 10;
    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          RotationTransition(
            turns: _rotate,
            child: Container(
              width: outer,
              height: outer,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    widget.accent.withOpacity(0.04),
                    widget.accent.withOpacity(0.55),
                    widget.accent.withOpacity(0.2),
                    widget.accent.withOpacity(0.04),
                  ],
                  stops: const [0.0, 0.4, 0.72, 1.0],
                ),
              ),
            ),
          ),
          SizedBox(width: widget.size, height: widget.size, child: widget.child),
        ],
      ),
    );
  }
}
