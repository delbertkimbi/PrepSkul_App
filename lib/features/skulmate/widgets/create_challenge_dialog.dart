import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import '../models/social_models.dart';
import '../models/game_model.dart';
import '../services/social_service.dart';
import '../services/skulmate_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Dialog for creating a challenge
class CreateChallengeDialog extends StatefulWidget {
  const CreateChallengeDialog({Key? key}) : super(key: key);

  @override
  State<CreateChallengeDialog> createState() => _CreateChallengeDialogState();
}

class _CreateChallengeDialogState extends State<CreateChallengeDialog> {
  List<Map<String, dynamic>> _friends = [];
  List<GameModel> _games = [];
  Map<String, dynamic>? _selectedFriend;
  GameModel? _selectedGame;
  ChallengeType _challengeType = ChallengeType.score;
  int? _targetValue;
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Load friends and games in parallel
      final results = await Future.wait([
        SocialService.getFriends(),
        SkulMateService.getGames(),
      ]);

      final friendships = results[0] as List<Friendship>;
      final games = results[1] as List<GameModel>;

      setState(() {
        _friends = friendships.map((f) => {
          'id': f.friendId == SupabaseService.client.auth.currentUser?.id
              ? f.userId
              : f.friendId,
          'name': f.friendName ?? 'Friend',
          'avatar_url': f.friendAvatarUrl,
        }).toList();
        _games = games;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('🎮 [CreateChallenge] Error loading data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createChallenge() async {
    if (_selectedFriend == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a friend'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedGame == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a game'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      await SocialService.createChallenge(
        challengeeId: _selectedFriend!['id'] as String,
        gameId: _selectedGame!.id,
        challengeType: _challengeType,
        targetValue: _targetValue,
        expiresIn: const Duration(days: 7),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Challenge sent to ${_selectedFriend!['name']}!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      LogService.error('🎮 [CreateChallenge] Error creating challenge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating challenge: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Create Challenge',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Select Friend
                      Text(
                        'Select Friend',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_friends.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'No friends yet. Add friends first!',
                            style: GoogleFonts.poppins(
                              color: AppTheme.textMedium,
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _friends.length,
                            itemBuilder: (context, index) {
                              final friend = _friends[index];
                              final isSelected = _selectedFriend?['id'] == friend['id'];
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedFriend = friend);
                                },
                                child: Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.primaryColor.withOpacity(0.1)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor:
                                            AppTheme.primaryColor.withOpacity(0.1),
                                        backgroundImage: friend['avatar_url'] != null
                                            ? CachedNetworkImageProvider(
                                                friend['avatar_url'] as String)
                                            : null,
                                        child: friend['avatar_url'] == null
                                            ? Text(
                                                (friend['name'] as String)[0]
                                                    .toUpperCase(),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        friend['name'] as String,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                      // Select Game
                      Text(
                        'Select Game',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<GameModel>(
                        value: _selectedGame,
                        decoration: InputDecoration(
                          hintText: 'Choose a game',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        items: _games.map((game) {
                          return DropdownMenuItem<GameModel>(
                            value: game,
                            child: Text(
                              game.title,
                              style: GoogleFonts.poppins(),
                            ),
                          );
                        }).toList(),
                        onChanged: (game) {
                          setState(() => _selectedGame = game);
                        },
                      ),
                      const SizedBox(height: 24),
                      // Challenge Type
                      Text(
                        'Challenge Type',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<ChallengeType>(
                        segments: const [
                          ButtonSegment(
                            value: ChallengeType.score,
                            label: Text('Highest Score'),
                          ),
                          ButtonSegment(
                            value: ChallengeType.time,
                            label: Text('Fastest Time'),
                          ),
                          ButtonSegment(
                            value: ChallengeType.perfectScore,
                            label: Text('Perfect Score'),
                          ),
                        ],
                        selected: {_challengeType},
                        onSelectionChanged: (Set<ChallengeType> newSelection) {
                          setState(() {
                            _challengeType = newSelection.first;
                            _targetValue = null; // Reset target when type changes
                          });
                        },
                      ),
                      if (_challengeType == ChallengeType.score ||
                          _challengeType == ChallengeType.time) ...[
                        const SizedBox(height: 16),
                        TextField(
                          decoration: InputDecoration(
                            labelText: _challengeType == ChallengeType.score
                                ? 'Target Score (optional)'
                                : 'Target Time in seconds (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              _targetValue = value.isEmpty
                                  ? null
                                  : int.tryParse(value);
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Create Button
                      ElevatedButton(
                        onPressed:
                            (_isCreating || _selectedFriend == null || _selectedGame == null)
                                ? null
                                : _createChallenge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isCreating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Create Challenge',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
