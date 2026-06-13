import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../features/tutor/screens/tutor_home_screen.dart';
import '../../features/dashboard/screens/student_home_screen.dart'
    show StudentHomeScreen;
import '../../features/tutor/screens/tutor_requests_screen.dart';
import '../../features/tutor/screens/tutor_sessions_screen.dart';
import '../../features/discovery/screens/find_tutors_screen.dart';
import '../../features/booking/screens/my_requests_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../core/services/auth_service.dart' hide LogService;
import '../../core/services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import 'main_nav_tabs.dart';
import '../../features/skulmate/services/game_sound_service.dart';
import '../utils/responsive_helper.dart';
import '../../features/tutor/widgets/tutor_page_body.dart';
import '../../features/tutor/widgets/tutor_navigation_shell.dart';
import '../../features/tutor/widgets/tutor_shell_scope.dart';

class MainNavigation extends StatefulWidget {
  final String userRole;
  final int? initialTab;

  const MainNavigation({Key? key, required this.userRole, this.initialTab})
    : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  late int _selectedIndex;

  void _stopGameMusicIfOnHomeTab() {
    if (_selectedIndex == 0) {
      unawaited(GameSoundService().stopMusic());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize with widget parameter first (available in initState)
    // Route arguments will be read in didChangeDependencies
    _selectedIndex = widget.initialTab ?? 0;
    _stopGameMusicIfOnHomeTab();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hot restart / resume can leave native BGM playing while shell shows Home.
    if (state == AppLifecycleState.resumed) {
      _stopGameMusicIfOnHomeTab();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // Hot-reload safety: clear any leftover game BGM on Home tab.
    _stopGameMusicIfOnHomeTab();
  }

  int _resolveInitialTabIndex(Map<String, dynamic>? routeArgs) {
    final tabName = routeArgs?['initialTabName'] as String?;
    if (tabName != null && tabName.isNotEmpty) {
      final fromName = MainNavTab.indexForRole(widget.userRole, tabName);
      if (fromName != null) return fromName;
    }
    final tabFromArgs = routeArgs?['initialTab'] as int?;
    if (tabFromArgs != null) return tabFromArgs;
    return widget.initialTab ?? 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final targetTab = _resolveInitialTabIndex(routeArgs);

    final hasExplicitTarget = routeArgs?['initialTabName'] != null ||
        routeArgs?['initialTab'] != null ||
        widget.initialTab != null;

    if (targetTab != _selectedIndex && targetTab >= 0 && hasExplicitTarget) {
      LogService.info(
        '🔵 [MAIN_NAV] Setting tab index: $targetTab '
        '(tabName: ${routeArgs?['initialTabName']}, '
        'from args: ${routeArgs?['initialTab']}, '
        'from widget: ${widget.initialTab})',
      );
      safeSetState(() {
        _selectedIndex = targetTab;
      });
    }
  }

  List<Widget> _wrappedTutorTabs() {
    return [
      const TutorPageBody(child: TutorHomeScreen()),
      const TutorPageBody(child: TutorRequestsScreen()),
      const TutorPageBody(child: TutorSessionsScreen()),
      const TutorPageBody(child: ProfileScreen(userType: 'tutor')),
    ];
  }

  List<NavigationRailDestination> _tutorRailDestinations(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return [
      NavigationRailDestination(
        icon: PhosphorIcon(PhosphorIcons.house(PhosphorIconsStyle.bold)),
        selectedIcon: PhosphorIcon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
        label: Text(t.navHome),
      ),
      NavigationRailDestination(
        icon: PhosphorIcon(PhosphorIcons.envelope(PhosphorIconsStyle.bold)),
        selectedIcon: PhosphorIcon(
          PhosphorIcons.envelope(PhosphorIconsStyle.fill),
        ),
        label: Text(t.navRequests),
      ),
      NavigationRailDestination(
        icon: PhosphorIcon(PhosphorIcons.graduationCap(PhosphorIconsStyle.bold)),
        selectedIcon: PhosphorIcon(
          PhosphorIcons.graduationCap(PhosphorIconsStyle.fill),
        ),
        label: Text(t.navSessions),
      ),
      NavigationRailDestination(
        icon: PhosphorIcon(PhosphorIcons.user(PhosphorIconsStyle.bold)),
        selectedIcon: PhosphorIcon(PhosphorIcons.user(PhosphorIconsStyle.fill)),
        label: Text(t.navProfile),
      ),
    ];
  }

  // Student screens (4 items)
  List<Widget> _getStudentScreens(String userType) {
    // Get highlightRequestId from route arguments if available
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final highlightRequestId = args?['highlightRequestId'] as String?;

    return [
      const StudentHomeScreen(), // Home Dashboard
      const FindTutorsScreen(), // Find Tutors
      MyRequestsScreen(
        highlightRequestId: highlightRequestId,
      ), // My Booking Requests
      ProfileScreen(
        userType: userType,
      ), // Profile & Settings (student or parent)
    ];
  }

  // Tutor navigation items (4 items)
  List<BottomNavigationBarItem> _getTutorItems(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return [
      BottomNavigationBarItem(
        icon: PhosphorIcon(
          PhosphorIcons.house(PhosphorIconsStyle.bold),
        ), // Thicker for unselected
        activeIcon: PhosphorIcon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
        label: t.navHome,
      ),
      BottomNavigationBarItem(
        icon: PhosphorIcon(
          PhosphorIcons.envelope(PhosphorIconsStyle.bold),
        ), // Thicker for unselected
        activeIcon: PhosphorIcon(
          PhosphorIcons.envelope(PhosphorIconsStyle.fill),
        ),
        label: t.navRequests,
      ),
      BottomNavigationBarItem(
        icon: PhosphorIcon(
          PhosphorIcons.graduationCap(PhosphorIconsStyle.bold),
        ), // Thicker for unselected
        activeIcon: PhosphorIcon(
          PhosphorIcons.graduationCap(PhosphorIconsStyle.fill),
        ),
        label: t.navSessions,
      ),
      BottomNavigationBarItem(
        icon: PhosphorIcon(
          PhosphorIcons.user(PhosphorIconsStyle.bold),
        ), // Thicker for unselected
        activeIcon: PhosphorIcon(PhosphorIcons.user(PhosphorIconsStyle.fill)),
        label: t.navProfile,
      ),
    ];
  }

  // Student/Parent navigation items (4 items)
  List<BottomNavigationBarItem> _getStudentItems(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return [
      BottomNavigationBarItem(
        icon: PhosphorIcon(
          PhosphorIcons.house(PhosphorIconsStyle.bold),
        ), // Thicker for unselected
        activeIcon: PhosphorIcon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
        label: t.navHome,
      ),
      BottomNavigationBarItem(
        icon: PhosphorIcon(
          PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
        ), // Thicker for unselected
        activeIcon: PhosphorIcon(
          PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill),
        ),
        label: t.navFindTutors,
      ),
      BottomNavigationBarItem(
        icon: PhosphorIcon(
          PhosphorIcons.clipboardText(PhosphorIconsStyle.bold),
        ), // Thicker for unselected
        activeIcon: PhosphorIcon(
          PhosphorIcons.clipboardText(PhosphorIconsStyle.fill),
        ),
        label: t.navRequests,
      ),
      BottomNavigationBarItem(
        icon: PhosphorIcon(
          PhosphorIcons.user(PhosphorIconsStyle.bold),
        ), // Thicker for unselected
        activeIcon: PhosphorIcon(PhosphorIcons.user(PhosphorIconsStyle.fill)),
        label: t.navProfile,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isTutor = widget.userRole == 'tutor';
    final userType = widget.userRole == 'parent' ? 'parent' : 'student';

    final screens = isTutor ? _wrappedTutorTabs() : _getStudentScreens(userType);
    final items = isTutor ? _getTutorItems(context) : _getStudentItems(context);
    final width = MediaQuery.sizeOf(context).width;
    final tutorUseRail = isTutor && width >= ResponsiveHelper.tabletBreakpoint;

    final tabBody = IndexedStack(index: _selectedIndex, children: screens);

    Widget tutorScaffold() {
      return TutorShellScope(
        goToHomeTab: () {
          safeSetState(() => _selectedIndex = 0);
          _stopGameMusicIfOnHomeTab();
        },
        child: TutorNavigationShell(
          useRail: tutorUseRail,
          selectedIndex: _selectedIndex,
          onIndexChanged: (index) {
            safeSetState(() {
              _selectedIndex = index;
            });
            _stopGameMusicIfOnHomeTab();
          },
          tabBody: tabBody,
          bottomBarItems: items,
          railDestinations: _tutorRailDestinations(context),
        ),
      );
    }

    final studentScaffold = Scaffold(
      backgroundColor: AppTheme.softBackground,
      body: tabBody,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          safeSetState(() {
            _selectedIndex = index;
          });
          _stopGameMusicIfOnHomeTab();
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textMedium,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
        iconSize: 22,
        items: items,
      ),
    );
    // When a detail screen is on top, the system pops that route; this PopScope only applies when MainNavigation is the top route.
    return PopScope(
      canPop: false,
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
                  PhosphorIcon(
                    PhosphorIcons.signOut(),
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
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
            try {
              await AuthService.logout();
            } catch (e) {
              LogService.warning('Error logging out: $e');
            }
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/auth-method-selection',
                (route) => false,
              );
            }
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
      child: isTutor ? tutorScaffold() : studentScaffold,
    );
  }
}
