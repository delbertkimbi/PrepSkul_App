import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/language_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SimpleOnboardingScreen extends StatefulWidget {
  const SimpleOnboardingScreen({super.key});

  @override
  State<SimpleOnboardingScreen> createState() => _SimpleOnboardingScreenState();
}

class _SimpleOnboardingScreenState extends State<SimpleOnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: 'Find the Perfect Tutor',
      titleFr: 'Trouvez le Tuteur Parfait',
      description:
          'Connect with qualified tutors who understand your learning needs and help you achieve your goals.',
      descriptionFr:
          'Connectez-vous avec des tuteurs qualifiés qui comprennent vos besoins d\'apprentissage et vous aident à atteindre vos objectifs.',
      image: 'assets/images/onboarding1.png',
      color: AppTheme.primaryColor,
    ),
    OnboardingSlide(
      title: 'Learn at Your Pace',
      titleFr: 'Apprenez à Votre Rythme',
      description:
          'Personalized lessons that adapt to your learning style and schedule.',
      descriptionFr:
          'Des leçons personnalisées qui s\'adaptent à votre style d\'apprentissage et à votre emploi du temps.',
      image: 'assets/images/onboarding2.png',
      color: AppTheme.accentPurple,
    ),
    OnboardingSlide(
      title: 'Achieve Your Goals',
      titleFr: 'Atteignez Vos Objectifs',
      description:
          'From struggling students to confident achievers - your potential is limitless.',
      descriptionFr:
          'Des étudiants en difficulté aux réussites confiantes - votre potentiel est illimité.',
      image: 'assets/images/onboarding3.jpg',
      color: AppTheme.accentGreen,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Auto-advance slides every 4 seconds
    _startAutoSlide();
  }

  void _startAutoSlide() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _currentPage < _slides.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _startAutoSlide();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    print('Onboarding completed, navigating to auth method selection...');
    Navigator.pushReplacementNamed(context, '/auth-method-selection');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 10),
            // Header with language switcher
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Skip button
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _currentPage < _slides.length - 1
                          ? TextButton(
                              onPressed: _completeOnboarding,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Skip',
                                style: GoogleFonts.poppins(
                                  color: AppTheme.textMedium,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),

                  // Language switcher
                  const LanguageSwitcher(),
                ],
              ),
            ),
            // Responsive top spacing - reduces on small screens
            LayoutBuilder(
              builder: (context, constraints) {
                final screenHeight = MediaQuery.of(context).size.height;
                // Reduce top spacing progressively on smaller screens
                final topSpacing = screenHeight < 600
                    ? 20.0
                    : screenHeight < 700
                    ? 40.0
                    : 60.0; // Original on normal screens
                return SizedBox(height: topSpacing);
              },
            ),
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return _buildSlide(_slides[index]);
                },
              ),
            ),

            // Page indicators
            _buildPageIndicators(),

            // Get Started button
            _buildGetStartedButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(OnboardingSlide slide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Smart responsive breakpoints based on screen height
        final screenHeight = constraints.maxHeight;

        // Normal screens (>= 700px): Keep original beautiful design
        // Small screens (< 700px): Start reducing spacing
        // Very small screens (< 600px): More aggressive reductions
        final isSmallScreen = screenHeight < 700;
        final isVerySmallScreen = screenHeight < 600;

        // Responsive adjustments (only for small screens)
        final topSpacing = isVerySmallScreen
            ? 8.0
            : isSmallScreen
            ? 16.0
            : 0.0; // No extra top spacing on normal screens

        final imageHeight = isVerySmallScreen
            ? 220.0
            : isSmallScreen
            ? 250.0
            : 280.0; // Original on normal screens

        final imageTextSpacing = isVerySmallScreen
            ? 24.0
            : isSmallScreen
            ? 32.0
            : 40.0; // Original on normal screens

        final titleSize = isVerySmallScreen
            ? 22.0
            : isSmallScreen
            ? 23.0
            : 24.0; // Original on normal screens

        final descriptionSize = isVerySmallScreen
            ? 13.0
            : 14.0; // Keep same for small and normal

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth < 400 ? 24.0 : 32.0,
              vertical: isVerySmallScreen ? 12.0 : 20.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top spacing (only on small screens to reduce white space)
                if (topSpacing > 0) SizedBox(height: topSpacing),

                // Responsive image container
                _buildStackedImageContainer(slide, imageHeight),

                SizedBox(height: imageTextSpacing),

                // Title with responsive font size
                Text(
                  slide.title,
                  style: GoogleFonts.poppins(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: isVerySmallScreen ? 10 : 12),

                // Description
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth < 400 ? 4.0 : 8.0,
                  ),
                  child: Text(
                    slide.description,
                    style: GoogleFonts.poppins(
                      fontSize: descriptionSize,
                      color: AppTheme.textMedium,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Bottom spacing for very small screens
                if (isVerySmallScreen) const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStackedImageContainer(
    OnboardingSlide slide, [
    double? imageHeight,
  ]) {
    // Use provided height or default to original 280
    final containerHeight = imageHeight ?? 280.0;

    return SizedBox(
      height: containerHeight,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background decorative blob 1
          Positioned(
            top: 20,
            left: 20,
            child: TweenAnimationBuilder(
              duration: const Duration(milliseconds: 1500),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: 0.8 + (value * 0.2),
                  child: Opacity(
                    opacity: value * 0.3,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            slide.color.withOpacity(0.3),
                            slide.color.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(80),
                          topRight: Radius.circular(40),
                          bottomLeft: Radius.circular(40),
                          bottomRight: Radius.circular(80),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Background decorative blob 2
          Positioned(
            bottom: 30,
            right: 30,
            child: TweenAnimationBuilder(
              duration: const Duration(milliseconds: 1800),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: 0.8 + (value * 0.2),
                  child: Opacity(
                    opacity: value * 0.2,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentLightBlue.withOpacity(0.4),
                            AppTheme.accentLightBlue.withOpacity(0.1),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(60),
                          topRight: Radius.circular(80),
                          bottomLeft: Radius.circular(80),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Main image with stacked shadow effect
          Center(
            child: TweenAnimationBuilder(
              duration: const Duration(milliseconds: 1200),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: 0.85 + (value * 0.15),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Shadow layer 1
                      Positioned(
                        top: 8,
                        left: -8,
                        child: Opacity(
                          opacity: 0.15 * value,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              color: slide.color.withOpacity(0.3),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(50),
                                topRight: Radius.circular(120),
                                bottomLeft: Radius.circular(120),
                                bottomRight: Radius.circular(50),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Shadow layer 2
                      Positioned(
                        top: 4,
                        right: -4,
                        child: Opacity(
                          opacity: 0.1 * value,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(60),
                                topRight: Radius.circular(110),
                                bottomLeft: Radius.circular(110),
                                bottomRight: Radius.circular(60),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Main image container with liquid border
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(50),
                            topRight: Radius.circular(120),
                            bottomLeft: Radius.circular(120),
                            bottomRight: Radius.circular(50),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: slide.color.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(50),
                            topRight: Radius.circular(120),
                            bottomLeft: Radius.circular(120),
                            bottomRight: Radius.circular(50),
                          ),
                          child: Image.asset(
                            slide.image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            // Note: loadingBuilder is only for Image.network
                            // Image.asset loads synchronously from bundled assets
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      slide.color.withOpacity(0.2),
                                      slide.color.withOpacity(0.1),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.school,
                                  size: 100,
                                  color: slide.color,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Decorative accent dot
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: slide.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: slide.color.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _slides.length,
          (index) => Container(
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

  Widget _buildGetStartedButton() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
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
  final String titleFr;
  final String description;
  final String descriptionFr;
  final String image;
  final Color color;

  OnboardingSlide({
    required this.title,
    required this.titleFr,
    required this.description,
    required this.descriptionFr,
    required this.image,
    required this.color,
  });
}
