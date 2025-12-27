import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Reusable Empty State Widget
/// 
/// Provides consistent empty states across the app with:
/// - Customizable icon, title, message
/// - Optional action button
/// - Consistent styling
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final double? iconSize;
  final EdgeInsets? padding;

  const EmptyStateWidget({
    Key? key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconSize,
    this.padding,
  }) : super(key: key);

  /// Empty state for no tutors found
  factory EmptyStateWidget.noTutors({
    VoidCallback? onRequestTutor,
  }) {
    return EmptyStateWidget(
      icon: Icons.person_search_outlined,
      title: 'No tutors found',
      message: 'Try adjusting your search or filters, or request a custom tutor',
      actionLabel: onRequestTutor != null ? 'Request a Tutor' : null,
      onAction: onRequestTutor,
      iconColor: AppTheme.textLight,
    );
  }

  /// Empty state for no sessions
  factory EmptyStateWidget.noSessions({
    String? message,
  }) {
    return EmptyStateWidget(
      icon: Icons.event_outlined,
      title: 'No sessions yet',
      message: message ?? 'Your sessions will appear here',
      iconColor: AppTheme.textLight,
    );
  }

  /// Empty state for no requests
  factory EmptyStateWidget.noRequests({
    String? message,
    VoidCallback? onRequestTutor,
  }) {
    return EmptyStateWidget(
      icon: Icons.inbox_outlined,
      title: 'No requests yet',
      message: message ?? 'Student requests will appear here',
      actionLabel: onRequestTutor != null ? 'Find Students' : null,
      onAction: onRequestTutor,
      iconColor: AppTheme.textLight,
    );
  }

  /// Empty state for no games
  factory EmptyStateWidget.noGames({
    VoidCallback? onCreateGame,
  }) {
    return EmptyStateWidget(
      icon: Icons.games_outlined,
      title: 'No games yet',
      message: 'Create your first game to start learning!',
      actionLabel: onCreateGame != null ? 'Create Game' : null,
      onAction: onCreateGame,
      iconColor: AppTheme.textLight,
    );
  }

  /// Empty state for no notifications
  factory EmptyStateWidget.noNotifications() {
    return EmptyStateWidget(
      icon: Icons.notifications_none_outlined,
      title: 'No notifications',
      message: 'You\'re all caught up!',
      iconColor: AppTheme.textLight,
    );
  }

  /// Empty state for no search results
  factory EmptyStateWidget.noSearchResults({
    VoidCallback? onClearSearch,
  }) {
    return EmptyStateWidget(
      icon: Icons.search_off,
      title: 'No results found',
      message: 'Try a different search term',
      actionLabel: onClearSearch != null ? 'Clear Search' : null,
      onAction: onClearSearch,
      iconColor: AppTheme.textLight,
    );
  }

  /// Empty state for no payments
  factory EmptyStateWidget.noPayments() {
    return EmptyStateWidget(
      icon: Icons.payment_outlined,
      title: 'No payments yet',
      message: 'Your payment history will appear here',
      iconColor: AppTheme.textLight,
    );
  }

  /// Empty state for no earnings
  factory EmptyStateWidget.noEarnings() {
    return EmptyStateWidget(
      icon: Icons.account_balance_wallet_outlined,
      title: 'No earnings yet',
      message: 'Your earnings will appear here after completing sessions',
      iconColor: AppTheme.textLight,
    );
  }

  /// Empty state for no friends
  factory EmptyStateWidget.noFriends({
    VoidCallback? onAddFriend,
  }) {
    return EmptyStateWidget(
      icon: Icons.people_outline,
      title: 'No friends yet',
      message: 'Add friends to compete and learn together!',
      actionLabel: onAddFriend != null ? 'Add Friend' : null,
      onAction: onAddFriend,
      iconColor: AppTheme.textLight,
    );
  }

  /// Empty state for no challenges
  factory EmptyStateWidget.noChallenges({
    VoidCallback? onCreateChallenge,
  }) {
    return EmptyStateWidget(
      icon: Icons.sports_esports_outlined,
      title: 'No challenges yet',
      message: 'Challenge your friends to a game!',
      actionLabel: onCreateChallenge != null ? 'Create Challenge' : null,
      onAction: onCreateChallenge,
      iconColor: AppTheme.textLight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize ?? 64,
              color: iconColor ?? AppTheme.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 20),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
