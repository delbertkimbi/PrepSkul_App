import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Documentation screen for PrepSkul's Virtual Assistant (VA).
/// Explains how the VA joins sessions, monitors content, and produces Skulmate summaries.
class PrepskulVAInfoScreen extends StatelessWidget {
  const PrepskulVAInfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "About PrepSkul's VA",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: "What is PrepSkul's VA?",
              content:
                  "PrepSkul's Virtual Assistant (VA) is an AI-powered monitoring system that joins every live tutoring session to help keep sessions focused and productive.",
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: "How does it join sessions?",
              content:
                  "The VA automatically joins your session when both you and your tutor/learner are connected. It runs in the background and does not interfere with your video or audio.",
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: "What does it monitor?",
              content:
                  "The VA monitors session content to ensure discussions stay focused on education and the subject of the live session. It helps prevent discussions or exchange of information unrelated to the lesson.",
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: "Session summaries",
              content:
                  "At the end of each session, the VA produces concise summaries of what was covered. These summaries capture key topics, concepts, and learning points.",
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: "Skulmate – interactive learning",
              content:
                  "Session summaries are used to power Skulmate, PrepSkul's interactive learning tool. Skulmate turns your session summaries into revision materials, quizzes, and learning activities you can use to reinforce what you learned.",
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Your privacy is respected. The VA is designed to support learning and maintain session quality only.",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
