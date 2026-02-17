import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../services/skulmate_onboarding_service.dart';
import 'skulmate_upload_screen.dart';

/// 3-screen onboarding for skulMate
class SkulMateOnboardingScreen extends StatefulWidget {
  const SkulMateOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<SkulMateOnboardingScreen> createState() => _SkulMateOnboardingScreenState();
}

class _SkulMateOnboardingScreenState extends State<SkulMateOnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  late List<AnimationController> _animationControllers;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: 'What is skulMate?',
      description: 'Your smart revision companion that turns your notes and session summaries into fun, interactive games to help you learn better.',
      icon: Icons.sports_esports_rounded,
      color: AppTheme.primaryColor,
    ),
    OnboardingSlide(
      title: 'From Sessions',
      description: 'After each tutoring session, generate revision games from your session summaries. Reinforce what you learned with engaging challenges.',
      icon: Icons.video_library_rounded,
      color: AppTheme.accentPurple,
    ),
    OnboardingSlide(
      title: 'Upload & Play',
      description: 'Upload your notes, documents, or photos. skulMate creates personalized games to help you master the content through interactive play.',
      icon: Icons.upload_file_rounded,
      color: AppTheme.accentGreen,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationControllers = List.generate(
      _slides.length,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      ),
    );
    // Start animation for first slide
    _animationControllers[0].forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    await SkulMateOnboardingService.markOnboardingComplete();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const SkulMateUploadScreen(),
        ),
      );
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  void _onPageChanged(int index) {
    safeSetState(() {
      _currentPage = index;
    });
    // Animate current slide
    _animationControllers[index].forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage < _slides.length - 1)
                    TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        'Skip',
                        style: GoogleFonts.poppins(
                          color: AppTheme.textMedium,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox.shrink(), // Spacer
                ],
              ),
            ),
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return _buildSlide(_slides[index], index);
                },
              ),
            ),
            // Page indicators
            _buildPageIndicators(),
            // Next/Get Started button
            _buildActionButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(OnboardingSlide slide, int index) {
    return FadeTransition(
      opacity: _animationControllers[index],
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationControllers[index],
          curve: Curves.easeOut,
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon/illustration
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: slide.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  slide.icon,
                  size: 100,
                  color: slide.color,
                ),
              ),
              const SizedBox(height: 48),
              // Title
              Text(
                slide.title,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                slide.description,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppTheme.textMedium,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _slides.length,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? AppTheme.primaryColor
                  : AppTheme.neutral300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: Text(
            _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingSlide {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
