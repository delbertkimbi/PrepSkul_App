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

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    try {
      safeSetState(() => _isLoading = true);
      final challenges = await SocialService.getChallenges();
      safeSetState(() {
        _challenges = challenges;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading challenges: $e');
      safeSetState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading challenges: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createChallenge() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const CreateChallengeDialog(),
    );
    if (result == true) {
      _loadChallenges();
    }
  }

  Future<void> _acceptChallenge(Challenge challenge) async {
    try {
      await SocialService.acceptChallenge(challenge.id);
      _loadChallenges();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge accepted!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting challenge: $e'),
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
          'Challenges',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Challenge',
            onPressed: _createChallenge,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _challenges.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.sports_esports,
                  title: 'No Challenges',
                  message: 'Create a challenge or wait for friends to challenge you!',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _challenges.length,
                  itemBuilder: (context, index) {
                    final challenge = _challenges[index];
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  challenge.gameTitle ?? 'Game Challenge',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ),
                              if (challenge.status == ChallengeStatus.pending)
                                ElevatedButton(
                                  onPressed: () => _acceptChallenge(challenge),
                                  child: const Text('Accept'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'From: ${challenge.challengerName}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
