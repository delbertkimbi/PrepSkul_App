import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../features/tutor/screens/tutor_home_screen.dart';
import '../../features/dashboard/screens/student_home_screen.dart' show StudentHomeScreen;
import '../../features/tutor/screens/tutor_requests_screen.dart';
import '../../features/tutor/screens/tutor_sessions_screen.dart';
import '../../features/discovery/screens/find_tutors_screen.dart';
import '../../features/booking/screens/my_requests_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../core/services/auth_service.dart' hide LogService;
import '../../core/services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';

class MainNavigation extends StatefulWidget {
  final String userRole;
  final int? initialTab;

  const MainNavigation({Key? key, required this.userRole, this.initialTab})
    : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    // Initialize with widget parameter first (available in initState)
    // Route arguments will be read in didChangeDependencies
    _selectedIndex = widget.initialTab ?? 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Now we can safely access inherited widgets like ModalRoute
    // Try to get initialTab from route arguments first, then fall back to widget parameter
    final routeArgs = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final tabFromArgs = routeArgs?['initialTab'] as int?;
    
    // Use route arguments if available, otherwise use widget parameter
    final targetTab = tabFromArgs ?? widget.initialTab ?? 0;
    
    if (targetTab != _selectedIndex) {
      LogService.info('🔵 [MAIN_NAV] Setting tab index: $targetTab (from args: $tabFromArgs, from widget: ${widget.initialTab})');
      safeSetState(() {
        _selectedIndex = targetTab;
      });
    }
  }

  // Tutor screens (4 items)
  final List<Widget> _tutorScreens = [
    const TutorHomeScreen(), // Home Dashboard
    const TutorRequestsScreen(), // Booking Requests
    const TutorSessionsScreen(), // Sessions
    const ProfileScreen(userType: 'tutor'), // Profile & Settings
  ];

  // Student screens (4 items)
  List<Widget> _getStudentScreens(String userType) {
    // Get highlightRequestId from route arguments if available
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final highlightRequestId = args?['highlightRequestId'] as String?;
    
    return [
    const StudentHomeScreen(), // Home Dashboard
    const FindTutorsScreen(), // Find Tutors
    MyRequestsScreen(highlightRequestId: highlightRequestId), // My Booking Requests
      ProfileScreen(userType: userType), // Profile & Settings (student or parent)
  ];
  }

  // Tutor navigation items (4 items)
  List<BottomNavigationBarItem> _getTutorItems(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home),
        label: t.navHome,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.mail_outline), // inbox icon for requests
        activeIcon: const Icon(Icons.mail),
        label: t.navRequests,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.school_outlined), // sessions icon
        activeIcon: const Icon(Icons.school),
        label: t.navSessions,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person),
        label: t.navProfile,
      ),
    ];
  }

  // Student/Parent navigation items (4 items)
  List<BottomNavigationBarItem> _getStudentItems(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home),
        label: t.navHome,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.search),
        activeIcon: const Icon(Icons.search),
        label: t.navFindTutors,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.receipt_long_outlined), // requests icon
        activeIcon: const Icon(Icons.receipt_long),
        label: t.navRequests,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person),
        label: t.navProfile,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isTutor = widget.userRole == 'tutor';
    final userType = widget.userRole == 'parent' ? 'parent' : 'student';
    
    final screens = isTutor ? _tutorScreens : _getStudentScreens(userType);
    final items = isTutor ? _getTutorItems(context) : _getStudentItems(context);

    // Wrap with PopScope to handle back navigation properly
    // Allow back navigation if there are screens to pop, prevent only at root
    final canPopFromStack = Navigator.of(context).canPop();
    return PopScope(
      canPop: canPopFromStack, // Allow pop if there are screens in stack
      onPopInvoked: (didPop) async {
        // If pop was already handled (there was a screen to pop), we're done
        if (didPop) return;
        
        // If we reach here, we're at the root and trying to exit the app
        // Check if user is authenticated
        final isAuthenticated = await AuthService.isLoggedIn();
        final hasSupabaseSession = SupabaseService.isAuthenticated;
        
        if (!isAuthenticated && !hasSupabaseSession) {
          // Not authenticated - allow back navigation (shouldn't happen, but safety check)
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          return;
        }
        
        // On web, show confirmation dialog when trying to leave app
        if (kIsWeb) {
          if (!mounted) return;
          
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.exit_to_app, color: AppTheme.primaryColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Leave PrepSkul?',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                'Are you sure you want to leave the app? You will be logged out.',
                style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: AppTheme.textMedium),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(
                    'Leave',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
          
          if (shouldExit == true && mounted) {
            // User confirmed exit - log out and allow navigation
            // The route guard will handle redirecting to auth screen if needed
            try {
              await AuthService.logout();
            } catch (e) {
              LogService.warning('Error logging out: $e');
            }
            // Allow navigation after logout
            return;
          }
        } else {
          // On mobile, when at root screen and user tries to exit,
          // minimize the app to background (like clicking home button)
          if (mounted && !Navigator.of(context).canPop()) {
            // Use SystemNavigator to minimize app to background
            // This is like clicking the home button - app goes to background
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          safeSetState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textMedium,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        items: items,
        ),
      ),
    );
  }
}
