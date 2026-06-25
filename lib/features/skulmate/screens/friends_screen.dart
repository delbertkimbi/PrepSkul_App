import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/core/utils/profile_display_utils.dart';
import '../l10n/skulmate_copy.dart';
import '../widgets/skulmate_social_screen_scaffold.dart';
import '../widgets/skulmate_surface_styles.dart';
import '../models/social_models.dart';
import '../services/social_service.dart';
import '../widgets/add_friend_dialog.dart';
import 'package:prepskul/core/widgets/empty_state_widget.dart';
import 'add_friend_screen.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';
import '../services/game_sound_service.dart';

/// Friends screen for managing friendships
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Friendship> _friends = [];
  List<Friendship> _pendingRequests = [];
  bool _isLoading = true;
  int _sectionIndex = 0;
  final GameSoundService _soundService = GameSoundService();

  @override
  void initState() {
    super.initState();
    _soundService.initialize();
    _loadFriends();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      safeSetState(() => _isLoading = true);

      final allFriendships = await SocialService.getFriends(includePending: true);
      final friends = allFriendships
          .where((f) => f.status == FriendshipStatus.accepted)
          .toList();
      final pending = allFriendships
          .where((f) => f.status == FriendshipStatus.pending)
          .toList();

      safeSetState(() {
        _friends = friends;
        _pendingRequests = pending;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('🎮 [Friends] Error loading: $e');
      safeSetState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading friends: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineRequest(String friendshipId) async {
    _soundService.playClick();
    try {
      await SocialService.declineFriendRequest(friendshipId);
      _loadFriends();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request declined'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _acceptRequest(String friendshipId) async {
    _soundService.playClick();
    try {
      await SocialService.acceptFriendRequest(friendshipId);
      _loadFriends();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request accepted!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.read(context);

    return SkulMateSocialScreenScaffold(
      title: copy.friendsTitle,
      trailing: IconButton(
        icon: const Icon(Icons.person_add_rounded),
        tooltip: copy.addFriendTitle,
        color: AppTheme.primaryColor,
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
            MaterialPageRoute(builder: (_) => const AddFriendScreen()),
          );
          if (result == true) _loadFriends();
        },
      ),
      headerBelowTitle: SkulMateSegmentedToggle(
        labels: [copy.friendsTab, copy.requestsTab],
        selectedIndex: _sectionIndex,
        badgeCounts: [_friends.length, _pendingRequests.length],
        onChanged: (i) => safeSetState(() => _sectionIndex = i),
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (_, __) => ShimmerLoading.listTile(),
            )
          : _sectionIndex == 0
              ? _buildFriendsTab()
              : _buildRequestsTab(),
    );
  }

  Widget _buildFriendsTab() {
    if (_friends.isEmpty) {
      return EmptyStateWidget.noFriends(
        onAddFriend: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const AddFriendScreen(),
            ),
          );
          if (result == true) {
            _loadFriends();
          }
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friendship = _friends[index];
          return _buildFriendCard(friendship);
        },
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_pendingRequests.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.person_add_outlined,
        title: 'No pending requests',
        message: 'Friend requests will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingRequests.length,
        itemBuilder: (context, index) {
          final request = _pendingRequests[index];
          final isIncoming = request.friendId ==
              SupabaseService.client.auth.currentUser?.id;
          return _buildRequestCard(request, isIncoming);
        },
      ),
    );
  }

  Widget _buildFriendCard(Friendship friendship) {
    final name = ProfileDisplayUtils.resolveDisplayName(
      primary: friendship.friendName,
      fallback: 'Friend',
    );
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final avatarUrl = friendship.friendAvatarUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Text(
                        initial,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  )
                : Text(
                    initial,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.people_outline, size: 14, color: AppTheme.textMedium),
                    const SizedBox(width: 4),
                    Text(
                      'Friend since ${_formatDate(friendship.createdAt)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Show options (view profile, remove friend, etc.)
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Friendship request, bool isIncoming) {
    final name = ProfileDisplayUtils.resolveDisplayName(
      primary: request.friendName,
      fallback: 'User',
    );
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final avatarUrl = request.friendAvatarUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 16).copyWith(
        border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.accentOrange.withValues(alpha: 0.12),
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Text(
                        initial,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentOrange,
                        ),
                      ),
                    ),
                  )
                : Text(
                    initial,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentOrange,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isIncoming ? Icons.mail_outline : Icons.send_outlined,
                      size: 14,
                      color: AppTheme.textMedium,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isIncoming
                          ? 'Sent you a friend request'
                          : 'Friend request sent',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isIncoming)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () => _acceptRequest(request.id),
                  style: SkulMateSurfaceStyles.sheetPrimaryButton().copyWith(
                    backgroundColor: WidgetStatePropertyAll(AppTheme.accentGreen),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                  child: const Text('Accept'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _declineRequest(request.id),
                  style: SkulMateSurfaceStyles.sheetSecondaryButton().copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                  child: Text(
                    'Decline',
                    style: GoogleFonts.poppins(color: AppTheme.textMedium),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
