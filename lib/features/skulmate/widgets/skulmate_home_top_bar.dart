import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/navigation/main_navigation_scope.dart';
import 'package:prepskul/core/navigation/student_tab_index.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../screens/challenges_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/leaderboard_screen.dart';
import 'skulmate_history_sheet.dart';
import 'skulmate_surface_styles.dart';

/// Gizmo-style top pills: History (left) · More menu (right).
class SkulMateHomeTopBar extends StatelessWidget {
  final String? childId;

  const SkulMateHomeTopBar({super.key, this.childId});

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _PillButton(
            icon: Icons.arrow_back_ios_new_rounded,
            label: copy.isFrench ? 'Accueil' : 'Home',
            onTap: () {
              final nav = MainNavigationScope.maybeOf(context);
              if (nav != null) {
                nav.switchTab(StudentTabIndex.home);
              } else if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
          const SizedBox(width: 8),
          _PillButton(
            icon: Icons.history_rounded,
            label: copy.history,
            onTap: () => SkulMateHistorySheet.show(context, childId: childId),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) => _onMenuSelected(context, value),
            itemBuilder: (context) => [
              _menuItem(
                Icons.emoji_events_outlined,
                copy.isFrench ? 'Classement' : 'Leaderboard',
                'leaderboard',
              ),
              _menuItem(
                Icons.people_outline,
                copy.isFrench ? 'Amis' : 'Friends',
                'friends',
              ),
              _menuItem(
                Icons.sports_esports_outlined,
                copy.isFrench ? 'Défis' : 'Challenges',
                'challenges',
              ),
            ],
            child: _PillButton(
              icon: Icons.keyboard_arrow_down_rounded,
              label: copy.more,
              onTap: null,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(IconData icon, String label, String value) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _onMenuSelected(BuildContext context, String value) {
    switch (value) {
      case 'leaderboard':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
        );
      case 'friends':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FriendsScreen()),
        );
      case 'challenges':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChallengesScreen()),
        );
    }
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: SkulMateSurfaceStyles.chipCard(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.textDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkulMateSurfaceStyles.pillRadius),
        child: child,
      ),
    );
  }
}
