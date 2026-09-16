import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';
import 'package:prepskul/features/primar/presentation/mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First beat after signup. Cartoon Mate greets; next screen asks school-world
/// questions, not marketplace tutor-match questions.
class SurveyIntroScreen extends StatefulWidget {
  final String userType;

  const SurveyIntroScreen({super.key, required this.userType});

  @override
  State<SurveyIntroScreen> createState() => _SurveyIntroScreenState();
}

class _SurveyIntroScreenState extends State<SurveyIntroScreen> {
  Future<void> _markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('survey_intro_seen', true);
  }

  Future<void> _handleGetStarted() async {
    await _markIntroSeen();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/profile-setup',
      arguments: {'userRole': widget.userType},
    );
  }

  Future<void> _handleSkip() async {
    await _markIntroSeen();
    if (!mounted) return;
    if (widget.userType == 'tutor') {
      NavigationService.resetStackNamed(context, '/tutor-nav');
    } else if (widget.userType == 'parent') {
      NavigationService.resetStackNamed(context, '/parent-nav');
    } else {
      NavigationService.resetStackNamed(context, '/student-nav');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.userType == 'parent';
    return Scaffold(
      body: Container(
        decoration: OnboardPalette.page,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              children: [
                const PrepSkulWordmark(),
                const Spacer(),
                prepMate(mood: Mood.cheer, size: 168),
                const SizedBox(height: 20),
                OnboardBubble(
                  title: isParent
                      ? 'You’re a student here too. Tell me about your school.'
                      : 'Tell me about your school. I’ll tutor you from there.',
                  note: isParent
                      ? 'Two minutes. No tutor-matching quiz. You can add a child profile later.'
                      : 'Two minutes. Cameroon-first, then we adapt if you’re elsewhere.',
                ),
                const Spacer(),
                OnboardPrimaryButton(
                  label: 'Let’s go',
                  onTap: _handleGetStarted,
                ),
                TextButton(
                  onPressed: _handleSkip,
                  child: Text(
                    'Skip for now',
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
