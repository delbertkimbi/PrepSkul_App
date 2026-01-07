import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import '../models/social_models.dart';
import '../services/social_service.dart';
import '../widgets/create_challenge_dialog.dart';
import 'game_library_screen.dart';
import 'quiz_game_screen.dart';
import 'flashcard_game_screen.dart';
import 'matching_game_screen.dart';
import 'fill_blank_game_screen.dart';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';
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
  String _selectedTab = 'all'; // 'all', 'sent', 'received'

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

    switch (_selectedTab) {
      case 'sent':
        return _challenges.where((c) => c.challengerId == userId).toList();
      case 'received':
        return _challenges.where((c) => c.challengeeId == userId).toList();
      default:
        return _challenges;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Challenges', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTabButton('all', 'All'),
              ),
              Expanded(
                child: _buildTabButton('sent', 'Sent'),
              ),
              Expanded(
                child: _buildTabButton('received', 'Received'),
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (context, index) => ShimmerLoading.sessionCard(),
                  )
                : _filteredChallenges.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.emoji_events,
                        title: 'No Challenges',
                        message: _selectedTab == 'sent'
                            ? 'You haven\'t sent any challenges yet'
                            : _selectedTab == 'received'
                                ? 'You don\'t have any pending challenges'
                                : 'No challenges found',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadChallenges,
                        child: ListView.builder(
                          itemCount: _filteredChallenges.length,
                          itemBuilder: (context, index) {
                            final challenge = _filteredChallenges[index];
                            return _buildChallengeCard(challenge);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (context) => CreateChallengeDialog(),
          );
          if (result == true) {
            _loadChallenges();
          }
        },
        child: Icon(Icons.add),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildTabButton(String tab, String label) {
    final isSelected = _selectedTab == tab;
    return InkWell(
      onTap: () => safeSetState(() => _selectedTab = tab),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeCard(Challenge challenge) {
    final userId = SupabaseService.client.auth.currentUser?.id;
    final isChallenger = challenge.challengerId == userId;
    final opponentName = isChallenger ? challenge.challengeeName : challenge.challengerName;
    final opponentAvatar = isChallenger ? challenge.challengeeAvatarUrl : challenge.challengerAvatarUrl;

    Color statusColor;
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
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to challenge details or game
          if (challenge.gameId != null) {
            // Could navigate to game details
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Opponent info and status
              Row(
                children: [
                  // Opponent avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    backgroundImage: opponentAvatar != null
                        ? NetworkImage(opponentAvatar)
                        : null,
                    child: opponentAvatar == null
                        ? Icon(
                            Icons.person,
                            color: AppTheme.primaryColor,
                            size: 20,
                          )
                        : null,
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
