import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_set_state.dart';
import '../../../core/utils/status_bar_utils.dart';
import '../../../core/widgets/skeletons/student_home_skeleton.dart';
import '../../../core/services/auth_service.dart' hide LogService;
import '../../../core/services/supabase_service.dart';
import '../../../core/services/survey_repository.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/widgets/offline_indicator.dart';
import '../../../features/notifications/widgets/notification_bell.dart';
import '../../../features/profile/widgets/survey_reminder_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/localization/app_localizations.dart';
import '../../../features/skulmate/screens/game_library_screen.dart';
import '../../../features/skulmate/screens/skulmate_upload_screen.dart';
import '../../../features/skulmate/services/skulmate_service.dart';
import '../../../features/messaging/screens/conversations_list_screen.dart';
import '../../../features/messaging/widgets/message_icon_badge.dart';
// TODO: Fix import path
// import 'package:prepskul/features/parent/screens/parent_progress_dashboard.dart';

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
  bool _isOffline = false;
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
    _loadUserData();
  }

  /// Initialize connectivity monitoring
  Future<void> _initializeConnectivity() async {
    await _connectivity.initialize();
    _checkConnectivity();
    
    // Listen to connectivity changes
    _connectivity.connectivityStream.listen((isOnline) {
      if (mounted) {
        final wasOffline = _isOffline;
        setState(() {
          _isOffline = !isOnline;
        });
        
        // If came back online, refresh data
        if (isOnline && wasOffline) {
          LogService.info('🌐 Connection restored - refreshing home screen');
          _loadUserData();
        }
      }
    });
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivity.checkConnectivity();
    if (mounted) {
      final wasOffline = _isOffline;
      setState(() {
        _isOffline = !isOnline;
      });
      
      // If we just came back online, refresh data
      if (isOnline && wasOffline) {
        LogService.info('🌐 Connection detected - refreshing home screen');
        _loadUserData();
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userProfile = await AuthService.getUserProfile();
      final prefs = await SharedPreferences.getInstance();
      final hasVisitedHome = prefs.getBool('has_visited_home') ?? false;

      // Get user name with priority: profile > direct Supabase query > stored signup data > session > auth metadata > default
      // Extract first name from full_name if available
      String? extractFirstName(String? fullName) {
        if (fullName == null || fullName.isEmpty || fullName == 'User' || fullName == 'Student') {
          return null;
        }
        // Split by space and take first part
        final parts = fullName.trim().split(' ');
        final firstName = parts.isNotEmpty ? parts[0] : fullName;
        // Return null if it's still "Student" or empty
        if (firstName.isEmpty || firstName == 'Student' || firstName == 'User') {
          return null;
        }
        return firstName;
      }

      var userName = extractFirstName(userProfile?['full_name']?.toString());
      LogService.debug('[HOME] Name from getUserProfile: ${userProfile?['full_name']} -> $userName');
      
      // If still no name, try direct Supabase query as fallback
      if (userName == null || userName.isEmpty) {
        try {
          final authUser = SupabaseService.currentUser;
          if (authUser != null) {
            final directProfile = await SupabaseService.client
                .from('profiles')
                .select('full_name')
                .eq('id', authUser.id)
                .maybeSingle();
            
            final directName = directProfile?['full_name']?.toString();
            LogService.debug('[HOME] Name from direct Supabase query: $directName');
            userName = extractFirstName(directName);
          }
        } catch (e) {
          LogService.debug('[HOME] Error querying Supabase directly: $e');
        }
      }
      
      if (userName == null || userName.isEmpty) {
        // Try stored signup data
        final storedName = prefs.getString('signup_full_name');
        LogService.debug('[HOME] Name from SharedPreferences: $storedName');
        if (storedName != null && storedName.isNotEmpty && storedName != 'User' && storedName != 'Student') {
          userName = extractFirstName(storedName);
          // If we found a name from signup but database doesn't have it, update the database
          try {
            final authUser = SupabaseService.currentUser;
            if (authUser != null) {
              await SupabaseService.client
                  .from('profiles')
                  .update({'full_name': storedName})
                  .eq('id', authUser.id);
              LogService.info('[HOME] Updated profile with signup name: $storedName');
            }
          } catch (e) {
            LogService.warning('[HOME] Failed to update profile with signup name: $e');
          }
        }
      }
      if (userName == null || userName.isEmpty) {
        // Try session data
        final currentUser = await AuthService.getCurrentUser();
        final sessionName = currentUser['fullName']?.toString();
        LogService.debug('[HOME] Name from session: $sessionName');
        if (sessionName != null && sessionName.isNotEmpty && sessionName != 'User') {
          userName = extractFirstName(sessionName);
        }
      }
      if (userName == null || userName.isEmpty) {
        // Try auth user metadata
        final authUser = SupabaseService.currentUser;
        if (authUser != null && authUser.userMetadata?['full_name'] != null) {
          final metadataName = authUser.userMetadata!['full_name']?.toString();
          LogService.debug('[HOME] Name from auth metadata: $metadataName');
          if (metadataName != null && metadataName.isNotEmpty) {
            userName = extractFirstName(metadataName);
          }
        }
      }
      if (userName == null || userName.isEmpty) {
        // Last resort: try email username
        final authUser = SupabaseService.currentUser;
        if (authUser?.email != null) {
          final email = authUser!.email!;
          final emailName = email.split('@')[0];
          // Capitalize first letter
          if (emailName.isNotEmpty && emailName.length > 1) {
            userName = emailName[0].toUpperCase() + emailName.substring(1);
            LogService.debug('[HOME] Using email username: $userName');
          }
        }
      }
      if (userName == null || userName.isEmpty) {
        // Default fallback
        userName = 'Student';
        LogService.warning('[HOME] All name sources failed, using default: Student');
      }
      
      LogService.success('[HOME] Final userName: $userName');

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
        safeSetState(() {
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
      LogService.debug('Error loading user data: $e');
      if (!mounted) return;

      safeSetState(() {
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
    String greeting = AppLocalizations.of(context)!.goodMorning;
    String greetingEmoji = '☀️';
    if (hour >= 12 && hour < 17) {
      greeting = AppLocalizations.of(context)!.goodAfternoon;
      greetingEmoji = '👋';
    } else if (hour >= 17) {
      greeting = AppLocalizations.of(context)!.goodEvening;
      greetingEmoji = '🌙';
    }

    // Extract city for quick actions (only actionable data)
    final city = _surveyData?['city'];

    return StatusBarUtils.withDarkStatusBar(
      Scaffold(
        backgroundColor: Colors.white,
        // SkulMate controlled by AppConfig feature flag
        floatingActionButton: AppConfig.enableSkulMate ? FloatingActionButton.extended(
        onPressed: () async {
          // Check if user has any games
          try {
            final result = await SkulMateService.getGamesPaginated(limit: 1);
            final games = result['games'] as List;
            
            if (games.isEmpty) {
              // No games yet, navigate to create game screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SkulMateUploadScreen(),
                ),
              );
            } else {
              // Has games, navigate to game library
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GameLibraryScreen(),
                ),
              );
            }
          } catch (e) {
            // On error, default to create game screen
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const SkulMateUploadScreen(),
            ),
          );
          }
        },
        backgroundColor: AppTheme.primaryColor,
        label: Text(
          'skulMate',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
      ) : null,
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
                      const MessageIconBadge(iconColor: Colors.white),
                      const SizedBox(width: 8),
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
                  _buildSectionTitle(AppLocalizations.of(context)!.yourProgress),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.school_outlined,
                          label: AppLocalizations.of(context)!.activeTutors,
                          value: '0',
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.calendar_today_outlined,
                          label: AppLocalizations.of(context)!.sessions,
                          value: '0',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildSectionTitle(AppLocalizations.of(context)!.quickActions),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: Icons.calendar_today,
                    title: AppLocalizations.of(context)!.mySessions,
                    subtitle: 'View upcoming and completed sessions',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pushNamed(context, '/my-sessions');
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildActionCard(
                    icon: Icons.payment,
                    title: AppLocalizations.of(context)!.paymentHistory,
                    subtitle: 'View and manage your payments',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pushNamed(context, '/payment-history');
                    },
                  ),
                  // Learning Progress (for parents)
                  if (_userType == 'parent') ...[
                    const SizedBox(height: 8),
                    _buildActionCard(
                      icon: Icons.trending_up,
                      title: 'Learning Progress',
                      subtitle: 'Track your child\'s learning journey and improvement',
                      color: AppTheme.accentGreen,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.trending_up,
                                    color: AppTheme.accentGreen,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Learning Progress',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Coming Soon!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'We\'re building an amazing feature that will help you track your child\'s learning journey, view their progress across subjects, see improvement trends, and celebrate their achievements.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppTheme.textMedium,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.accentGreen.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: AppTheme.accentGreen,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'You\'ll be notified when this feature is available!',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppTheme.textDark,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  'Close',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  // Removed "Your Goals" section - personal info belongs in profile
                  // This data is used behind the scenes for tutor matching, not for display
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24), // Reduced from 32
          const SizedBox(height: 6), // Reduced from 8
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20, // Reduced from 24
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11, // Reduced from 12
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
        padding: const EdgeInsets.all(14), // Increased from 12 (adds 2px to height)
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 21), // Increased from 20
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15, // Increased from 14
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13, // Increased from 12
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
