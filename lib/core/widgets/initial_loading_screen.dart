import 'package:flutter/material.dart';

/// Initial Loading Screen
///
/// Shows an animated PrepSkul logo on deep blue during the initial app load.
/// Uses white logo so it's visible; avoids white flash on cold start.
class InitialLoadingScreen extends StatefulWidget {
  const InitialLoadingScreen({super.key});

  @override
  State<InitialLoadingScreen> createState() => _InitialLoadingScreenState();
}

class _InitialLoadingScreenState extends State<InitialLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Create animation controller with faster, more visible animation (1.2 seconds)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Pulsing/breathing effect: scale animation (more visible than translateZ)
    _scaleAnimation = Tween<double>(
      begin: 1.0,   // Normal size
      end: 1.15,    // 15% larger for visible pulse
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Opacity animation for breathing effect
    _rotationAnimation = Tween<double>(
      begin: 1.0,   // Fully opaque
      end: 0.85,    // Slightly transparent for breathing effect
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Start animation and loop it continuously
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _splashBlue = Color(0xFF1B2C4F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _splashBlue,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _rotationAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Hero(
                  tag: 'prepskul-logo',
                  transitionOnUserGestures: false,
                  child: Image.asset(
                    'assets/images/app_logo(white).png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.school,
                        size: 120,
                        color: Colors.white,
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
