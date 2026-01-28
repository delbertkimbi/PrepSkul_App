import 'package:flutter/material.dart';

/// Initial Loading Screen
/// 
/// Shows an animated PrepSkul logo on a white background
/// during the initial app load. This appears before the splash screen
/// to provide immediate visual feedback to users.
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

  @override
  Widget build(BuildContext context) {
    // White background
    return Scaffold(
      backgroundColor: Colors.white,
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
                    'assets/images/app_logo(blue).png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if image fails to load
                      return const Icon(
                        Icons.school,
                        size: 120,
                        color: Color(0xFF1B2C4F), // Deep blue color
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
