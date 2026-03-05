import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
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
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: size + 16,
            height: size + 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                // Dark ring so pulse is visible on light backgrounds
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 14,
                  spreadRadius: 3,
                ),
                // Bright pulse (opacity 0.4–1.0, larger blur) for light and dark
                BoxShadow(
                  color: Colors.white.withOpacity(_pulseAnimation.value),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryDark,
            border: Border.all(
              color: AppTheme.accentBlue.withOpacity(0.6),
              width: 2,
            ),
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
