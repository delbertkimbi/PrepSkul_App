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
                ? ShimmerLoading() as Widget
                : _filteredChallenges.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.emoji_events,
                        title: 'No Challenges',
                        message: _selectedTab == 'sent'
                            ? 'You haven\'t sent any challenges yet'
                            : _selectedTab == 'received'
                                ? 'You don\'t have any pending challenges'
                                : 'No challenges found',
                      ) as Widget
                    : RefreshIndicator(
                        onRefresh: _loadChallenges,
                        child: ListView.builder(
                          itemCount: _filteredChallenges.length,
                          itemBuilder: (context, index) {
                            final challenge = _filteredChallenges[index];
                            return _buildChallengeCard(challenge);
                          },
                        ),
                      ) as Widget,
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

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          isChallenger ? 'Challenge to $opponentName' : 'Challenge from ${challenge.challengerName}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          challenge.gameTitle ?? 'Game Challenge',
          style: GoogleFonts.poppins(),
        ),
        trailing: Text(
          challenge.status.toString().toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: challenge.status == ChallengeStatus.completed
                ? AppTheme.accentGreen
                : challenge.status == ChallengeStatus.pending
                    ? Colors.orange
                    : AppTheme.textMedium,
          ),
        ),
        onTap: () {
          // Navigate to challenge details or game
          if (challenge.gameId != null) {
            // Could navigate to game details
          }
        },
      ),
    );
  }
}
