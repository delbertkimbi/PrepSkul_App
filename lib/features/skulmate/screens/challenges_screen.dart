import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import '../models/social_models.dart';
import '../services/social_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/skulmate_copy.dart';
import '../widgets/skulmate_social_screen_scaffold.dart';
import '../widgets/skulmate_surface_styles.dart';
import 'challenge_create_screen.dart';
import 'package:prepskul/core/widgets/empty_state_widget.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';

/// Challenges screen for viewing and managing challenges
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({Key? key}) : super(key: key);

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  List<Challenge> _challenges = [];
  bool _isLoading = true;
  int _tabIndex = 0; // 0 all, 1 sent, 2 received

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    safeSetState(() => _isLoading = true);
    try {
      final challenges = await SocialService.getChallenges();
      safeSetState(() {
        _challenges = challenges;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading challenges: $e');
      safeSetState(() => _isLoading = false);
    }
  }

  List<Challenge> get _filteredChallenges {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];

    switch (_tabIndex) {
      case 1:
        return _challenges.where((c) => c.challengerId == userId).toList();
      case 2:
        return _challenges.where((c) => c.challengeeId == userId).toList();
      default:
        return _challenges;
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.read(context);

    return SkulMateSocialScreenScaffold(
      title: copy.challengesTitle,
      headerBelowTitle: SkulMateSegmentedToggle(
        labels: [copy.challengesAll, copy.challengesSent, copy.challengesReceived],
        selectedIndex: _tabIndex,
        onChanged: (i) => safeSetState(() => _tabIndex = i),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const ChallengeCreateScreen()),
          );
          if (result == true) _loadChallenges();
        },
        backgroundColor: AppTheme.textDark,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (_, __) => ShimmerLoading.sessionCard(),
            )
          : _filteredChallenges.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.emoji_events,
                  title: 'No Challenges',
                  message: _tabIndex == 1
                      ? 'You haven\'t sent any challenges yet'
                      : _tabIndex == 2
                          ? 'You don\'t have any pending challenges'
                          : 'No challenges found',
                )
              : RefreshIndicator(
                  onRefresh: _loadChallenges,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: _filteredChallenges.length,
                    itemBuilder: (context, index) {
                      return _buildChallengeCard(_filteredChallenges[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildChallengeCard(Challenge challenge) {
    final userId = SupabaseService.client.auth.currentUser?.id;
    final isChallenger = challenge.challengerId == userId;
    final opponentName = isChallenger ? challenge.challengeeName : challenge.challengerName;
    final opponentAvatar = isChallenger ? challenge.challengeeAvatarUrl : challenge.challengerAvatarUrl;    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    
    switch (challenge.status) {
      case ChallengeStatus.completed:
        statusColor = AppTheme.accentGreen;
        statusLabel = 'Completed';
        statusIcon = Icons.check_circle;
        break;
      case ChallengeStatus.accepted:
        statusColor = Colors.blue;
        statusLabel = 'Accepted';
        statusIcon = Icons.play_circle;
        break;
      case ChallengeStatus.pending:
        statusColor = Colors.orange;
        statusLabel = 'Pending';
        statusIcon = Icons.pending;
        break;
      case ChallengeStatus.declined:
        statusColor = Colors.red;
        statusLabel = 'Declined';
        statusIcon = Icons.cancel;
        break;
      case ChallengeStatus.expired:
        statusColor = Colors.grey;
        statusLabel = 'Expired';
        statusIcon = Icons.access_time;
        break;
    }    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 16),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Opponent info and status
              Row(
                children: [
                  // Opponent avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: opponentAvatar != null && opponentAvatar.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: opponentAvatar,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Icon(
                                Icons.person,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.person,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isChallenger ? 'You challenged $opponentName' : '$opponentName challenged you',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Game title - prominently displayed
                        if (challenge.gameTitle != null)
                          Row(
                            children: [
                              Icon(
                                Icons.sports_esports,
                                size: 14,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  challenge.gameTitle!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.primaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Game Challenge',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Challenge details
              if (challenge.targetValue != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getChallengeTypeIcon(challenge.challengeType),
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getChallengeTypeLabel(challenge.challengeType, challenge.targetValue!),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Expiry info
              if (challenge.status == ChallengeStatus.pending || challenge.status == ChallengeStatus.accepted) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppTheme.textMedium,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Expires ${_formatExpiry(challenge.expiresAt)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getChallengeTypeIcon(ChallengeType type) {
    switch (type) {
      case ChallengeType.score:
        return Icons.star;
      case ChallengeType.time:
        return Icons.timer;
      case ChallengeType.perfectScore:
        return Icons.emoji_events;
    }
  }

  String _getChallengeTypeLabel(ChallengeType type, int targetValue) {
    switch (type) {
      case ChallengeType.score:
        return 'Target Score: $targetValue';
      case ChallengeType.time:
        return 'Complete in: ${targetValue}s';
      case ChallengeType.perfectScore:
        return 'Get Perfect Score';
    }
  }

  String _formatExpiry(DateTime expiresAt) {
    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    
    if (difference.inDays > 0) {
      return 'in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'soon';
    }
  }
}