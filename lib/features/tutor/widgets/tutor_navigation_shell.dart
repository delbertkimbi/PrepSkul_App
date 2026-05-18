import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

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
        backgroundColor: AppTheme.softBackground,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onIndexChanged,
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppTheme.surfaceColor,
              indicatorColor: AppTheme.accentLightBlue,
              selectedIconTheme: IconThemeData(
                color: AppTheme.primaryColor,
                size: 26,
              ),
              unselectedIconTheme: IconThemeData(
                color: AppTheme.textMedium,
                size: 24,
              ),
              selectedLabelTextStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
              unselectedLabelTextStyle: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMedium,
              ),
              destinations: railDestinations,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: tabBody),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      body: tabBody,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onIndexChanged,
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
        items: bottomBarItems,
      ),
    );
  }
}
