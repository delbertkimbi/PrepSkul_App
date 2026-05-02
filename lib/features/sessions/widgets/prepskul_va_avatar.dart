import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// PrepSkul VA (Virtual Assistant) avatar shown during sessions to indicate monitoring.
/// UI-only: no backend; displays a circular avatar with a subtle pulsing "recording" ring.
class PrepSkulVAAvatar extends StatefulWidget {
  /// Diameter of the avatar circle (default 48).
  final double size;

  const PrepSkulVAAvatar({Key? key, this.size = 48}) : super(key: key);

  @override
  State<PrepSkulVAAvatar> createState() => _PrepSkulVAAvatarState();
}

class _PrepSkulVAAvatarState extends State<PrepSkulVAAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _ringOpacityAnimation;
  late Animation<double> _ringWidthAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      label: 'PrepSkul virtual assistant monitoring',
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentBlue.withOpacity(_ringOpacityAnimation.value),
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
          decoration: BoxDecoration(
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
