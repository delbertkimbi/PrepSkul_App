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
              AppTheme.primaryColor.withOpacity(0.8),
            ],
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
                    padding: const EdgeInsets.all(24.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        children: [
                          const Spacer(flex: 1),
                          const SizedBox(height: 20),

                          // Icon
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.school_outlined,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Title
                          Text(
                            'Help us find the best tutor for ${isParent ? 'your child' : 'you'}',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.3,
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

                          const SizedBox(height: 40),

                          // Benefits list
                          _buildBenefitsList(isParent),

                          const SizedBox(height: 48),

                          // Get Started Button (Primary)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _handleGetStarted,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
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

                          const SizedBox(height: 16),

                          // Skip Button (Secondary)
                          TextButton(
                            onPressed: _handleSkip,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              'Skip for Now',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Note
                          Text(
                            'You can complete this later from your home screen',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: benefits.map((benefit) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 12),
                child: Text(
                  '•',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  benefit,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
