import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Survey Reminder Card
/// 
/// Displays on home screen when user hasn't completed the survey.
/// Can be dismissed with "Remind me later" option.
class SurveyReminderCard extends StatefulWidget {
  final String userType; // 'student' or 'parent'
  final VoidCallback? onTap;
  
  const SurveyReminderCard({
    Key? key,
    required this.userType,
    this.onTap,
  }) : super(key: key);

  @override
  State<SurveyReminderCard> createState() => _SurveyReminderCardState();

  /// Check if card should be shown (not dismissed recently)
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('survey_reminder_dismissed') ?? false;
    
    if (!dismissed) return true;
    
    // If dismissed, check if 24 hours have passed
    final dismissedTime = prefs.getInt('survey_reminder_dismissed_time') ?? 0;
    if (dismissedTime == 0) return true;
    
    final dismissedDateTime = DateTime.fromMillisecondsSinceEpoch(dismissedTime);
    final now = DateTime.now();
    final hoursSinceDismissed = now.difference(dismissedDateTime).inHours;
    
    // Show again after 24 hours
    return hoursSinceDismissed >= 24;
  }
}

class _SurveyReminderCardState extends State<SurveyReminderCard>
    with SingleTickerProviderStateMixin {
  bool _isDismissed = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Dismiss the card (remind later)
  Future<void> _dismissCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('survey_reminder_dismissed', true);
    await prefs.setInt(
      'survey_reminder_dismissed_time',
      DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _isDismissed = true;
    });

    // Animate out
    await _animationController.reverse();
    
    if (mounted) {
      setState(() {
        _isDismissed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) {
      return const SizedBox.shrink();
    }

    final isParent = widget.userType == 'parent';

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.school_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete Your Profile',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isParent
                            ? 'Help us find the best tutor for your child'
                            : 'Help us find the best tutor for you',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withOpacity(0.8),
                    size: 20,
                  ),
                  onPressed: _dismissCard,
                  tooltip: 'Remind me later',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isParent
                  ? 'Take 2 minutes to tell us about your child\'s learning needs and get personalized tutor recommendations.'
                  : 'Take 2 minutes to tell us about your learning goals and get personalized tutor recommendations.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.95),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Complete Survey',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

