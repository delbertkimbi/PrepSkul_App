import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeletons/student_home_skeleton.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/survey_repository.dart';
import '../../../features/notifications/widgets/notification_bell.dart';
import '../../../features/profile/widgets/survey_reminder_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({Key? key}) : super(key: key);

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  String _userName = '';
  bool _isLoading = true;
  bool _isFirstVisit = false;
  Map<String, dynamic>? _surveyData;
  String _userType = 'student';
  bool _surveyCompleted = false;
  bool _showReminderCard = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userProfile = await AuthService.getUserProfile();
      final prefs = await SharedPreferences.getInstance();
      final hasVisitedHome = prefs.getBool('has_visited_home') ?? false;

      // Get user name with priority: profile > stored signup data > session > auth metadata > default
      var userName = userProfile?['full_name'] != null
          ? userProfile!['full_name'].toString()
          : null;
      if (userName == null || userName.isEmpty || userName == 'User') {
        // Try stored signup data
        final storedName = prefs.getString('signup_full_name');
        if (storedName != null && storedName.isNotEmpty) {
          userName = storedName;
        }
      }
      if (userName == null || userName.isEmpty || userName == 'User') {
        // Try session data
        final currentUser = await AuthService.getCurrentUser();
        final sessionName = currentUser['fullName']?.toString();
        if (sessionName != null &&
            sessionName.isNotEmpty &&
            sessionName != 'User') {
          userName = sessionName;
        }
      }
      if (userName == null || userName.isEmpty || userName == 'User') {
        // Try auth user metadata
        final authUser = SupabaseService.currentUser;
        if (authUser != null && authUser.userMetadata?['full_name'] != null) {
          final metadataName = authUser.userMetadata!['full_name']?.toString();
          if (metadataName != null && metadataName.isNotEmpty) {
            userName = metadataName;
          }
        }
      }
      if (userName == null || userName.isEmpty || userName == 'User') {
        // Default fallback
        userName = 'Student';
      }

      _userName = userName;
      _userType = userProfile?['user_type'] ?? 'student';
      _isFirstVisit = !hasVisitedHome;
      _surveyCompleted = userProfile?['survey_completed'] ?? false;

      // Load survey data for personalization
      if (_userType == 'student') {
        _surveyData = await SurveyRepository.getStudentSurvey(
          userProfile?['id'],
        );
      } else if (_userType == 'parent') {
        _surveyData = await SurveyRepository.getParentSurvey(
          userProfile?['id'],
        );
      }

      // Check if reminder card should be shown
      if (!_surveyCompleted) {
        _showReminderCard = await SurveyReminderCard.shouldShow();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // First-time user? Auto-navigate to Find Tutors
      if (_isFirstVisit && mounted) {
        await prefs.setBool('has_visited_home', true);
        // Small delay for smooth transition
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            // Navigate to Find Tutors tab (index 1)
            Navigator.pushReplacementNamed(
              context,
              _userType == 'parent' ? '/parent-nav' : '/student-nav',
              arguments: {'initialTab': 1},
            );
          }
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (!mounted) return;

      setState(() {
        _userName = 'Student';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const StudentHomeSkeleton();
    }

    // Get greeting based on time
    final hour = DateTime.now().hour;
    String greeting = 'Good morning';
    String greetingEmoji = '☀️';
    if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon';
      greetingEmoji = '👋';
    } else if (hour >= 17) {
      greeting = 'Good evening';
      greetingEmoji = '🌙';
    }

    // Extract city for quick actions (only actionable data)
    final city = _surveyData?['city'];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Header with gradient
            Container(
              width: double.infinity,
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
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting $greetingEmoji',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userName,
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const NotificationBell(iconColor: Colors.white),
                    ],
                  ),
                  // Removed learning path badge - this info is for platform matching, not display
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Survey Reminder Card (if survey not completed)
                  if (_showReminderCard && !_surveyCompleted)
                    SurveyReminderCard(
                      userType: _userType,
                      onTap: () {
                        // Navigate to profile-setup with userRole argument
                        Navigator.pushNamed(
                          context,
                          '/profile-setup',
                          arguments: {'userRole': _userType},
                        );
                      },
                    ),

                  // Quick Stats
                  _buildSectionTitle('Your Progress'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.school_outlined,
                          label: 'Active Tutors',
                          value: '0',
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.calendar_today_outlined,
                          label: 'Sessions',
                          value: '0',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildSectionTitle('Quick Actions'),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.search,
                    title: 'Find Perfect Tutor',
                    subtitle: city != null
                        ? 'Browse tutors in $city'
                        : 'Discover tutors near you',
                    color: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.pushReplacementNamed(
                        context,
                        _userType == 'parent' ? '/parent-nav' : '/student-nav',
                        arguments: {'initialTab': 1},
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.inbox_outlined,
                    title: 'My Requests',
                    subtitle: 'View your booking requests',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pushReplacementNamed(
                        context,
                        _userType == 'parent' ? '/parent-nav' : '/student-nav',
                        arguments: {'initialTab': 2},
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.calendar_today,
                    title: 'My Sessions',
                    subtitle: 'View upcoming and completed sessions',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pushNamed(context, '/my-sessions');
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.payment,
                    title: 'Payment History',
                    subtitle: 'View and manage your payments',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pushNamed(context, '/payment-history');
                    },
                  ),

                  // Removed "Your Goals" section - personal info belongs in profile
                  // This data is used behind the scenes for tutor matching, not for display
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppTheme.textDark,
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
