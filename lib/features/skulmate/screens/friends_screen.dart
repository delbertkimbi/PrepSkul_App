import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import '../models/social_models.dart';
import '../services/social_service.dart';
import '../widgets/add_friend_dialog.dart';
import 'package:prepskul/core/widgets/empty_state_widget.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';

/// Friends screen for managing friendships
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Friendship> _friends = [];
  List<Friendship> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFriends();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _acceptRequest(String friendshipId) async {
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
            content: Text('Error accepting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Friends',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Friend',
            onPressed: () async {
              final result = await showDialog(
                context: context,
                builder: (context) => const AddFriendDialog(),
              );
              if (result == true) {
                // Refresh friends list if a request was sent
                _loadFriends();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textMedium,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Friends'),
                  if (_friends.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_friends.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Requests'),
                  if (_pendingRequests.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingRequests.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (context, index) => ShimmerLoading.listTile(),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(),
                _buildRequestsTab(),
              ],
            ),
    );
  }

  Widget _buildFriendsTab() {
    if (_friends.isEmpty) {
      return EmptyStateWidget.noFriends(
        onAddFriend: () {
          showDialog(
            context: context,
            builder: (context) => const AddFriendDialog(),
          ).then((_) => _loadFriends());
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            backgroundImage: friendship.friendAvatarUrl != null
                ? NetworkImage(friendship.friendAvatarUrl!)
                : null,
            child: friendship.friendAvatarUrl == null
                ? Text(
                    (friendship.friendName ?? 'F')[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friendship.friendName ?? 'Friend',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Friend since ${_formatDate(friendship.createdAt)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                  ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.orange.withOpacity(0.1),
            backgroundImage: request.friendAvatarUrl != null
                ? NetworkImage(request.friendAvatarUrl!)
                : null,
            child: request.friendAvatarUrl == null
                ? Text(
                    (request.friendName ?? 'U')[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[700],
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.friendName ?? 'User',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
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
          ),
          if (isIncoming)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _acceptRequest(request.id),
                  child: const Text('Accept'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentGreen,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Decline request
                  },
                  child: const Text('Decline'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
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
