import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';

/// Tutor tab chrome: [NavigationRail] + content when [useRail] is true, otherwise
/// [BottomNavigationBar]. Used by [MainNavigation] so layout can be smoke-tested in isolation.
class TutorNavigationShell extends StatelessWidget {
  const TutorNavigationShell({
    super.key,
    required this.useRail,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.tabBody,
    required this.bottomBarItems,
    required this.railDestinations,
  });

  final bool useRail;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final Widget tabBody;
  final List<BottomNavigationBarItem> bottomBarItems;
  final List<NavigationRailDestination> railDestinations;

  @override
  Widget build(BuildContext context) {
    if (useRail) {
      return Scaffold(
        backgroundColor: OnboardPalette.cream,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onIndexChanged,
              labelType: NavigationRailLabelType.all,
              backgroundColor: OnboardPalette.cream,
              indicatorColor: AppTheme.skyBlueLight,
              selectedIconTheme: const IconThemeData(
                color: AppTheme.primaryColor,
                size: 26,
              ),
              unselectedIconTheme: const IconThemeData(
                color: AppTheme.textMedium,
                size: 24,
              ),
              selectedLabelTextStyle: onboardFont(
                size: 12,
                weight: FontWeight.w800,
              ),
              unselectedLabelTextStyle: onboardFont(
                size: 11,
                weight: FontWeight.w700,
                color: AppTheme.textMedium,
              ),
              destinations: railDestinations,
            ),
            const VerticalDivider(
              width: 2,
              thickness: 2,
              color: AppTheme.primaryColor,
            ),
            Expanded(child: tabBody),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: OnboardPalette.cream,
      body: tabBody,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: OnboardPalette.cream,
          border: Border(
            top: BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x381E3A8A),
              offset: Offset(0, -4),
              blurRadius: 0,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: onIndexChanged,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.textMedium,
          selectedLabelStyle: onboardFont(size: 11, weight: FontWeight.w800),
          unselectedLabelStyle: onboardFont(
            size: 11,
            weight: FontWeight.w700,
            color: AppTheme.textMedium,
          ),
          iconSize: 22,
          items: bottomBarItems,
        ),
      ),
    );
  }
}
