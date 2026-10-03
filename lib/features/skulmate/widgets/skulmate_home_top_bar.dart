import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../screens/challenges_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/skulmate_games_screen.dart';
import '../screens/skulmate_progress_screen.dart';
import '../screens/leaderboard_screen.dart';
import 'skulmate_history_sheet.dart';

/// Gizmo-style top pills: History (left) · More menu (right).
class SkulMateHomeTopBar extends StatelessWidget {
  final String? childId;
  final String? activeSessionId;
  final ValueChanged<String>? onSelectSession;
  final VoidCallback? onNewSession;

  const SkulMateHomeTopBar({
    super.key,
    this.childId,
    this.activeSessionId,
    this.onSelectSession,
    this.onNewSession,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _PillButton(
            icon: PhosphorIcons.clockCounterClockwise,
            label: copy.history,
            onTap: () => SkulMateHistorySheet.show(
              context,
              childId: childId,
              activeSessionId: activeSessionId,
              onSelectSession: onSelectSession,
              onNewSession: onNewSession,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) => _onMenuSelected(context, value),
            itemBuilder: (context) => [
              _menuItem(PhosphorIcons.gridFour, copy.myGames, 'library'),
              _menuItem(
                PhosphorIcons.chartLineUp,
                copy.myProgressTitle,
                'progress',
              ),
              _menuItem(
                PhosphorIcons.trophy,
                copy.isFrench ? 'Classement' : 'Leaderboard',
                'leaderboard',
              ),
              _menuItem(PhosphorIcons.users, copy.friendsTitle, 'friends'),
              _menuItem(
                PhosphorIcons.gameController,
                copy.challengesTitle,
                'challenges',
              ),
            ],
            child: _PillButton(
              icon: PhosphorIcons.dotsThree,
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
      case 'library':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SkulMateGamesScreen(childId: childId),
          ),
        );
      case 'progress':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SkulMateProgressScreen(childId: childId),
          ),
        );
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

  const _PillButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 7),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}
