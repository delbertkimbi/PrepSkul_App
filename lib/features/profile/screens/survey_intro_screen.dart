import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Survey Intro Screen
///
/// Friendly screen that appears after signup, encouraging users to complete
/// the survey to help find the best tutor match.
///
/// Features:
/// - Different messaging for students vs parents
/// - "Get Started" (primary) and "Skip for Now" (secondary) buttons
/// - Tracks if user has seen this screen
/// - Navigates to survey or home based on user choice
class SurveyIntroScreen extends StatefulWidget {
  final String userType; // 'student' or 'parent'

  const SurveyIntroScreen({Key? key, required this.userType}) : super(key: key);

  @override
  State<SurveyIntroScreen> createState() => _SurveyIntroScreenState();
}

class _SurveyIntroScreenState extends State<SurveyIntroScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Mark that user has seen the intro screen
  Future<void> _markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('survey_intro_seen', true);
  }

  /// Handle "Get Started" - navigate to survey
  Future<void> _handleGetStarted() async {
    await _markIntroSeen();

    if (mounted) {
      // Navigate to profile-setup with userRole argument
      // The profile-setup route will show the appropriate survey based on userRole
      Navigator.pushReplacementNamed(
        context,
        '/profile-setup',
        arguments: {'userRole': widget.userType},
      );
    }
  }

  /// Handle "Skip for Now" - navigate to home
  Future<void> _handleSkip() async {
    await _markIntroSeen();

    if (mounted) {
      // Navigate to appropriate home screen
      if (widget.userType == 'tutor') {
        Navigator.pushReplacementNamed(context, '/tutor-nav');
      } else if (widget.userType == 'parent') {
        Navigator.pushReplacementNamed(context, '/parent-nav');
      } else {
        Navigator.pushReplacementNamed(context, '/student-nav');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.userType == 'parent';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryLight.withOpacity(0.85),
              AppTheme.primaryColor.withOpacity(0.9),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        children: [
                          const Spacer(flex: 1),
                          const SizedBox(height: 12),

                          // PrepSkul branding + icon with soft fill
                          Text(
                            'PrepSkul',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              size: 52,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Title – tighter proximity
                          Text(
                            'Help us find the best tutor for ${isParent ? 'your child' : 'you'}',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.25,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 24),

                          // Description
                          Text(
                            isParent
                                ? 'Take 2 minutes to tell us about your child\'s learning needs, and we\'ll match them with the perfect tutor.'
                                : 'Take 2 minutes to tell us about your learning goals, and we\'ll match you with the perfect tutor.',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          // Parents: clarify they can add more children later
                          if (isParent) ...[
                            const SizedBox(height: 16),
                            Text(
                              'We\'ll start with one learner, you can add more children later in your profile.',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.85),
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Benefits list – soft card, closer spacing
                          _buildBenefitsList(isParent),

                          const SizedBox(height: 32),

                          // Get Started Button (Primary) – soft fill
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _handleGetStarted,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                              child: Text(
                                'Get Started',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Skip Button (Secondary)
                          TextButton(
                            onPressed: _handleSkip,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Skip for Now',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Note – softer, smaller
                          Text(
                            'You can complete this later from your home screen',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.75),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Spacer(flex: 1),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsList(bool isParent) {
    final benefits = isParent
        ? [
            'Personalized tutor matching',
            'Faster booking with pre-filled preferences',
            'Better learning outcomes',
          ]
        : [
            'Personalized tutor matching',
            'Faster booking with pre-filled preferences',
            'Track your learning progress',
          ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: benefits.map((benefit) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    benefit,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
