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
import '../../features/skulmate/screens/skulmate_home_screen.dart';
import '../../features/skulmate/screens/skulmate_onboarding_screen.dart';
import '../../features/skulmate/services/skulmate_onboarding_service.dart';
import '../../core/config/app_config.dart';
import '../../core/services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import '../../features/skulmate/services/game_sound_service.dart';
import '../utils/responsive_helper.dart';
import '../../features/tutor/widgets/tutor_page_body.dart';
import '../../features/tutor/widgets/tutor_navigation_shell.dart';
import '../../features/sessions/services/live_session_overlay_controller.dart';
import 'main_navigation_scope.dart';
import 'nav_tab_args.dart';

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
  bool _initialTabApplied = false;

  void _stopGameMusicIfOnHomeTab() {
    if (_selectedIndex == 0) {
      unawaited(GameSoundService().stopMusic());
    }
  }

  int get _skulMateTabIndex => AppConfig.enableSkulMate ? 2 : -1;
  bool _skulMateOnboardingCheckInFlight = false;

  Future<void> _handleStudentTabTap(int index) async {
    // Respond on first tap — do not block on async onboarding/network checks.
    if (index != _selectedIndex) {
      safeSetState(() => _selectedIndex = index);
      _stopGameMusicIfOnHomeTab();
    }

    if (index != _skulMateTabIndex ||
        _skulMateOnboardingCheckInFlight ||
        !mounted) {
      return;
    }

    _skulMateOnboardingCheckInFlight = true;
    try {
      final showOnboarding =
          await SkulMateOnboardingService.shouldShowOnboarding().timeout(
                const Duration(seconds: 2),
                onTimeout: () => false,
              );
      if (!mounted || !showOnboarding) return;

      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const SkulMateOnboardingScreen(popWhenDone: true),
        ),
      );
    } finally {
      _skulMateOnboardingCheckInFlight = false;
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
      unawaited(LiveSessionOverlayController.instance.refreshFromServer());
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // Hot-reload safety: clear any leftover game BGM on Home tab.
    _stopGameMusicIfOnHomeTab();
  }

  void _applyInitialTabOnce() {
    if (_initialTabApplied) return;
    _initialTabApplied = true;

    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final tabFromArgs = widget.userRole == 'tutor'
        ? NavTabArgs.resolveTutorTabIndex(routeArgs)
        : NavTabArgs.resolveStudentTabIndex(routeArgs);
    final targetTab = tabFromArgs ?? widget.initialTab;
    if (targetTab == null || targetTab < 0) return;

    if (targetTab != _selectedIndex) {
      LogService.info(
        '🔵 [MAIN_NAV] Initial tab: $targetTab (args: $tabFromArgs, widget: ${widget.initialTab})',
      );
      safeSetState(() => _selectedIndex = targetTab);
    }
  }

  void _switchTab(int index) {
    if (index < 0 || index == _selectedIndex) return;
    safeSetState(() => _selectedIndex = index);
    _stopGameMusicIfOnHomeTab();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyInitialTabOnce();
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

  // Student screens (4 or 5 items depending on SkulMate flag)
  List<Widget> _getStudentScreens(String userType) {
    // Get highlightRequestId from route arguments if available
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final highlightRequestId = args?['highlightRequestId'] as String?;

    final screens = <Widget>[
      const StudentHomeScreen(),
      const FindTutorsScreen(),
    ];

    if (AppConfig.enableSkulMate) {
      screens.add(const SkulMateHomeScreen());
    }

    screens.addAll([
      MyRequestsScreen(highlightRequestId: highlightRequestId),
      ProfileScreen(userType: userType),
    ]);

    return screens;
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

  // Student/Parent navigation items (5 items when SkulMate enabled)
  List<BottomNavigationBarItem> _getStudentItems(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: PhosphorIcon(PhosphorIcons.house(PhosphorIconsStyle.bold)),
        activeIcon: PhosphorIcon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
        label: t.navHome,
      ),
      BottomNavigationBarItem(
        icon: PhosphorIcon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold)),
        activeIcon: PhosphorIcon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill)),
        label: t.navFindTutors,
      ),
    ];

    if (AppConfig.enableSkulMate) {
      items.add(
        BottomNavigationBarItem(
          icon: PhosphorIcon(PhosphorIcons.sparkle(PhosphorIconsStyle.bold)),
          activeIcon: PhosphorIcon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill)),
          label: t.navSkulMate,
        ),
      );
    }

    items.addAll([
      BottomNavigationBarItem(
        icon: PhosphorIcon(PhosphorIcons.clipboardText(PhosphorIconsStyle.bold)),
        activeIcon: PhosphorIcon(PhosphorIcons.clipboardText(PhosphorIconsStyle.fill)),
        label: t.navRequests,
      ),
      BottomNavigationBarItem(
        icon: PhosphorIcon(PhosphorIcons.user(PhosphorIconsStyle.bold)),
        activeIcon: PhosphorIcon(PhosphorIcons.user(PhosphorIconsStyle.fill)),
        label: t.navProfile,
      ),
    ]);

    return items;
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
      return TutorNavigationShell(
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
      );
    }

    final studentScaffold = AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppTheme.softBackground,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.softBackground,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.softBackground,
        body: tabBody,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _handleStudentTabTap,
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
      ),
    );
    // When a detail screen is on top, the system pops that route; this PopScope only applies when MainNavigation is the top route.
    return MainNavigationScope(
      selectedIndex: _selectedIndex,
      switchTab: _switchTab,
      child: PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Pop pushed routes (session detail, etc.) before handling tab/root back.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        // On any non-home tab, back goes to Home — never log out.
        if (_selectedIndex != 0) {
          safeSetState(() => _selectedIndex = 0);
          return;
        }

        final hasSupabaseSession = SupabaseService.isAuthenticated;
        if (!hasSupabaseSession) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          return;
        }

        // On web at root Home tab: do not log out on browser back.
        if (kIsWeb) return;

        // On mobile at root Home tab, minimize to background.
        if (mounted && !Navigator.of(context).canPop()) {
          SystemNavigator.pop();
        }
      },
      child: isTutor ? tutorScaffold() : studentScaffold,
      ),
    );
  }
}
