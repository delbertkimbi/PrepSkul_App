import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../discovery/widgets/tutor_card.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';

class ProfilePreviewScreen extends StatelessWidget {
  final Map<String, dynamic> tutor;

  const ProfilePreviewScreen({Key? key, required this.tutor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardPalette.cream,
      appBar: paperAppBar(
        title: 'Profile Preview',
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.visibility_outlined, size: 32, color: AppTheme.primaryColor),
                    const SizedBox(height: 8),
                    Text(
                      'This is your Tutor Card',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This is exactly how students see you in search results.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // The Card
              TutorCard(tutor: tutor, isPreview: true),
              
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_outlined, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Click the card to view your full profile details',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

