import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Empty Conversations State Widget
/// 
/// User-type aware empty state for when user has no conversations
/// Shows different content based on user type (student/parent vs tutor vs admin)
class EmptyConversationsState extends StatelessWidget {
  final VoidCallback? onFindTutor;
  final String? userType; // 'student', 'parent', 'learner', 'tutor', 'admin'

  const EmptyConversationsState({
    super.key,
    this.onFindTutor,
    this.userType,
  });

  @override
  Widget build(BuildContext context) {
    final isTutor = userType == 'tutor';
    final isAdmin = userType == 'admin';
    final isStudentOrParent = userType == 'student' || userType == 'parent' || userType == 'learner';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            // Heading - different for each user type
            Text(
              isTutor 
                  ? 'No messages yet'
                  : isAdmin
                      ? 'No conversations'
                      : 'Start a conversation',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Description - different for each user type
            Text(
              isTutor
                  ? 'You\'ll receive messages from students after they book a trial session or when a booking request is approved. Messages help you coordinate lessons and answer questions.'
                  : isAdmin
                      ? 'Conversations will appear here when users start messaging.'
                      : 'You can message tutors after booking a trial session or when a booking request is approved. Messages help you discuss lessons, ask questions, and coordinate with your tutor.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: AppTheme.textMedium,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            // Info card - only for students/parents
            if (isStudentOrParent) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'When can I message?',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• After booking and paying for a trial session\n• When a booking request is approved by a tutor',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Button - only for students/parents
            if (isStudentOrParent && onFindTutor != null) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onFindTutor,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Find a tutor',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

