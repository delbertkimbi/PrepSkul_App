import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import '../models/social_models.dart';
import '../models/game_model.dart';
import '../services/social_service.dart';
import '../services/skulmate_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/game_sound_service.dart';

/// Full-screen, step-based flow for creating a challenge.
/// Step 1: Pick friend → Step 2: Pick game → Step 3: Type & target.
class ChallengeCreateScreen extends StatefulWidget {
  const ChallengeCreateScreen({Key? key}) : super(key: key);

  @override
  State<ChallengeCreateScreen> createState() => _ChallengeCreateScreenState();
}

class _ChallengeCreateScreenState extends State<ChallengeCreateScreen> {
  static const int _totalSteps = 3;
  int _currentStep = 0;

  List<Map<String, dynamic>> _friends = [];
  List<GameModel> _games = [];
  Map<String, dynamic>? _selectedFriend;
  GameModel? _selectedGame;
  ChallengeType _challengeType = ChallengeType.score;
  int? _targetValue;
  final TextEditingController _targetController = TextEditingController();
  bool _isLoading = true;
  bool _isCreating = false;
  final GameSoundService _soundService = GameSoundService();

  @override
  void initState() {
    super.initState();
    _soundService.initialize();
    _loadData();
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final results = await Future.wait([
        SocialService.getFriends(),
        SkulMateService.getGames(),
      ]);
      final friendships = results[0] as List<Friendship>;
      final games = results[1] as List<GameModel>;
      setState(() {
        _friends = friendships.map((f) {
          final friendId = f.friendId == SupabaseService.client.auth.currentUser?.id
              ? f.userId
              : f.friendId;
          return {
            'id': friendId,
            'name': f.friendName ?? 'Friend',
            'avatar_url': f.friendAvatarUrl,
          };
        }).toList();
        _games = games;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('🎮 [ChallengeCreate] Error loading data: $e');
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
    if (_selectedFriend == null || _selectedGame == null) return;
    _soundService.playClick();
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
      LogService.error('🎮 [ChallengeCreate] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _soundService.playClick();
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _soundService.playClick();
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Challenge',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProgressBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: _buildStepContent(),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.softBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepPickFriend();
      case 1:
        return _buildStepPickGame();
      case 2:
        return _buildStepTypeAndTarget();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepPickFriend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a friend to challenge',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Step 1 of $_totalSteps',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 20),
        if (_friends.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.textMedium),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No friends yet. Add friends from the Friends tab first.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ..._friends.map((friend) {
            final isSelected = _selectedFriend?['id'] == friend['id'];
            final name = friend['name'] as String;
            final initial = name.trim().isEmpty
                ? '?'
                : name.trim().toUpperCase().substring(0, 1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedFriend = friend),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.softBorder,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.textDark.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              AppTheme.primaryColor.withOpacity(0.1),
                          backgroundImage: friend['avatar_url'] != null
                              ? CachedNetworkImageProvider(
                                  friend['avatar_url'] as String)
                              : null,
                          child: friend['avatar_url'] == null
                              ? Text(
                                  initial,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.accentGreen,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStepPickGame() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a game',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Step 2 of $_totalSteps',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.softBorder),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textDark.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<GameModel>(
            value: _selectedGame,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            hint: Text(
              'Select a game',
              style: GoogleFonts.poppins(color: AppTheme.textMedium),
            ),
            items: _games
                .map(
                  (game) => DropdownMenuItem<GameModel>(
                    value: game,
                    child: Text(
                      game.title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (game) => setState(() => _selectedGame = game),
          ),
        ),
      ],
    );
  }

  Widget _buildStepTypeAndTarget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Challenge type & target',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Step 3 of $_totalSteps',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.softBorder),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textDark.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Type',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<ChallengeType>(
                segments: const [
                  ButtonSegment(
                    value: ChallengeType.score,
                    label: Text('Score'),
                  ),
                  ButtonSegment(
                    value: ChallengeType.time,
                    label: Text('Time'),
                  ),
                  ButtonSegment(
                    value: ChallengeType.perfectScore,
                    label: Text('Perfect'),
                  ),
                ],
                selected: {_challengeType},
                onSelectionChanged: (Set<ChallengeType> s) {
                  setState(() {
                    _challengeType = s.first;
                    _targetValue = null;
                    _targetController.clear();
                  });
                },
              ),
              if (_challengeType == ChallengeType.score ||
                  _challengeType == ChallengeType.time) ...[
                const SizedBox(height: 20),
                Text(
                  _challengeType == ChallengeType.score
                      ? 'Target score (optional)'
                      : 'Target time in seconds (optional)',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _targetController,
                  decoration: InputDecoration(
                    hintText: _challengeType == ChallengeType.score
                        ? 'e.g. 80'
                        : 'e.g. 120',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppTheme.softBackground,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _targetValue =
                          value.isEmpty ? null : int.tryParse(value);
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: AppTheme.primaryColor),
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: _currentStep > 0 ? 1 : 2,
              child: ElevatedButton(
                onPressed: _currentStep < _totalSteps - 1
                    ? (_selectedFriend != null && _currentStep == 0 ||
                            _selectedGame != null && _currentStep == 1
                        ? _nextStep
                        : null)
                    : (_selectedFriend != null && _selectedGame != null &&
                            !_isCreating
                        ? _createChallenge
                        : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _currentStep < _totalSteps - 1 ? 'Next' : 'Create Challenge',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
