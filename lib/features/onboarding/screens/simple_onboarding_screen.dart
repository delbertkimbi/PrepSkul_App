import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/language_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/localization/app_localizations.dart';

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
      titleBuilder: (t) => t.onboardingConnectTitle,
      descriptionBuilder: (t) => t.onboardingConnectSubtitle,
      image: 'assets/images/onboarding1.png',
      color: AppTheme.primaryColor,
    ),
    OnboardingSlide(
      titleBuilder: (t) => t.onboardingLearnTitle,
      descriptionBuilder: (t) => t.onboardingLearnSubtitle,
      image: 'assets/images/onboarding2.png',
      color: AppTheme.accentPurple,
    ),
    OnboardingSlide(
      titleBuilder: (t) => t.onboardingAchieveTitle,
      descriptionBuilder: (t) => t.onboardingAchieveSubtitle,
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
    LogService.debug('Onboarding completed, navigating to auth method selection...');
    Navigator.pushReplacementNamed(context, '/auth-method-selection');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
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
                                t.buttonSkip,
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
            _buildGetStartedButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(OnboardingSlide slide) {
    final t = AppLocalizations.of(context)!;
    final title = slide.titleBuilder(t);
    final description = slide.descriptionBuilder(t);
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
                  title,
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
                    description,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // For large screens, constrain width to prevent scattered appearance
        final isLargeScreen = constraints.maxWidth > 600;
        final maxWidth = isLargeScreen ? 400.0 : double.infinity;
        
        // Structured shape configuration for consistent positioning
        final shapeConfig = _DecorativeShapeConfig(
          containerWidth: isLargeScreen ? 350.0 : constraints.maxWidth,
          containerHeight: containerHeight,
        );
        
        return SizedBox(
          height: containerHeight,
          width: maxWidth,
          child: Center(
            child: SizedBox(
              height: containerHeight,
              width: isLargeScreen ? 350.0 : double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background decorative blob 1 - Top Left (Structured)
                  Positioned(
                    top: shapeConfig.blob1Top,
                    left: shapeConfig.blob1Left,
                    child: TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 1500),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: 0.8 + (value * 0.2),
                          child: Opacity(
                            opacity: value * 0.3,
                            child: Container(
                              width: shapeConfig.blob1Size,
                              height: shapeConfig.blob1Size,
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

                  // Background decorative blob 2 - Bottom Right (Structured)
                  Positioned(
                    bottom: shapeConfig.blob2Bottom,
                    right: shapeConfig.blob2Right,
                    child: TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 1800),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: 0.8 + (value * 0.2),
                          child: Opacity(
                            opacity: value * 0.2,
                            child: Container(
                              width: shapeConfig.blob2Size,
                              height: shapeConfig.blob2Size,
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
                            cacheWidth: isLargeScreen ? 700 : null, // Cache optimized size for large screens
                            cacheHeight: isLargeScreen ? 700 : null,
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

                      // Decorative accent dot - Structured positioning
                      Positioned(
                        top: shapeConfig.accentDotTop,
                        right: shapeConfig.accentDotRight,
                        child: Container(
                          width: shapeConfig.accentDotSize,
                          height: shapeConfig.accentDotSize,
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
            ),
          ),
        );
      },
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

  Widget _buildGetStartedButton(BuildContext context) {
    final t = AppLocalizations.of(context)!;
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
            _currentPage == _slides.length - 1 ? t.buttonGetStarted : t.buttonNext,
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

/// Structured configuration for decorative shapes in onboarding
/// Ensures consistent, organized positioning relative to container size
class _DecorativeShapeConfig {
  final double containerWidth;
  final double containerHeight;
  
  // Blob 1 (Top Left) - Primary decorative shape
  late final double blob1Size;
  late final double blob1Top;
  late final double blob1Left;
  
  // Blob 2 (Bottom Right) - Secondary decorative shape
  late final double blob2Size;
  late final double blob2Bottom;
  late final double blob2Right;
  
  // Accent dot (Top Right of image)
  late final double accentDotSize;
  late final double accentDotTop;
  late final double accentDotRight;
  
  _DecorativeShapeConfig({
    required this.containerWidth,
    required this.containerHeight,
  }) {
    // Calculate sizes relative to container (maintains proportions)
    final baseSize = containerHeight * 0.64; // ~180px for 280px container
    
    // Blob 1: Top-left corner, ~64% of container height
    blob1Size = baseSize;
    blob1Top = containerHeight * 0.07; // ~20px for 280px container
    blob1Left = containerWidth * 0.06; // ~20px for 350px container
    
    // Blob 2: Bottom-right corner, ~50% of blob1 size
    blob2Size = baseSize * 0.78; // ~140px for 280px container
    blob2Bottom = containerHeight * 0.11; // ~30px for 280px container
    blob2Right = containerWidth * 0.09; // ~30px for 350px container
    
    // Accent dot: Small decorative element, top-right of image
    accentDotSize = 16.0; // Fixed small size
    accentDotTop = 10.0; // Fixed offset from top
    accentDotRight = 10.0; // Fixed offset from right
  }
}

class OnboardingSlide {
  final String Function(AppLocalizations) titleBuilder;
  final String Function(AppLocalizations) descriptionBuilder;
  final String image;
  final Color color;

  OnboardingSlide({
    required this.titleBuilder,
    required this.descriptionBuilder,
    required this.image,
    required this.color,
  });
}
