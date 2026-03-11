import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:flutter/foundation.dart';
import '../models/social_models.dart';
import '../services/social_service.dart';
import '../services/games_services_controller.dart';
import 'package:prepskul/core/widgets/empty_state_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import '../services/character_selection_service.dart';
import '../widgets/skulmate_character_widget.dart';

/// Leaderboard screen showing rankings
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<LeaderboardEntry> _entries = [];
  bool _isLoading = true;
  final GamesServicesController _gamesServices = GamesServicesController();
  bool _platformAvailable = false;
  dynamic _myCharacter;

  @override
  void initState() {
    super.initState();
    _checkPlatformAvailability();
    _loadLeaderboard();
    _loadMyCharacter();
  }

  Future<void> _loadMyCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    if (mounted) safeSetState(() => _myCharacter = character);
  }

  Future<void> _checkPlatformAvailability() async {
    if (!kIsWeb) {
      final available = _gamesServices.isAvailable;
      safeSetState(() {
        _platformAvailable = available;
      });
    }
  }  Future<void> _loadLeaderboard() async {
    try {
      safeSetState(() => _isLoading = true);
      final entries = await SocialService.getLeaderboard(period: LeaderboardPeriod.allTime);
      safeSetState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading leaderboard: $e');
      safeSetState(() => _isLoading = false);
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
  }  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Leaderboard',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          if (_platformAvailable)
            IconButton(
              icon: const Icon(Icons.leaderboard),
              tooltip: 'Show Platform Leaderboard',
              onPressed: () async {
                try {
                  await _gamesServices.showLeaderboard();
                } catch (e) {
                  LogService.error('Error showing platform leaderboard: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not open platform leaderboard'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.emoji_events,
                  title: 'No Rankings Yet',
                  message: 'Be the first to play and earn points!',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final rank = index + 1;
                    final isTopThree = index < 3;
                    final isMe = entry.userId == SupabaseService.client.auth.currentUser?.id;
                    final displayName = entry.userName ?? 'Player';
                    final trimmed = displayName.trim();
                    final initial = trimmed.isEmpty
                        ? '?'
                        : trimmed.toUpperCase().substring(0, 1);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.softCard,
                        borderRadius: BorderRadius.circular(14),
                        border: isTopThree
                            ? Border.all(
                                color: index == 0
                                    ? Colors.amber.shade700
                                    : index == 1
                                        ? Colors.grey.shade400!
                                        : Colors.brown.shade300!,
                                width: 2,
                              )
                            : Border.all(color: AppTheme.softBorder),
                      ),
                      child: Row(
                        children: [
                          // Leading: my SkulMate character for current user, else profile pic or initial
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: isMe && _myCharacter != null
                                ? ClipOval(
                                    child: Container(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      child: Center(
                                        child: SkulMateCharacterWidget(
                                          character: _myCharacter,
                                          size: 40,
                                          animated: false,
                                          showName: false,
                                        ),
                                      ),
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: 26,
                                    backgroundColor: isTopThree
                                        ? AppTheme.primaryColor.withOpacity(0.12)
                                        : AppTheme.softBorder,
                                    backgroundImage: entry.userAvatarUrl != null &&
                                            entry.userAvatarUrl!.isNotEmpty
                                        ? CachedNetworkImageProvider(entry.userAvatarUrl!)
                                        : null,
                                    child: entry.userAvatarUrl == null ||
                                            entry.userAvatarUrl!.isEmpty
                                        ? Text(
                                            initial,
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: isTopThree
                                                  ? AppTheme.primaryColor
                                                  : AppTheme.textMedium,
                                            ),
                                          )
                                        : null,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          // Rank badge
                          Container(
                            width: 28,
                            alignment: Alignment.center,
                            child: isTopThree
                                ? Icon(
                                    Icons.emoji_events,
                                    size: 28,
                                    color: index == 0
                                        ? Colors.amber.shade700
                                        : index == 1
                                            ? Colors.grey.shade400
                                            : Colors.brown.shade300,
                                  )
                                : Text(
                                    '$rank',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textMedium,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star_outline,
                                      size: 14,
                                      color: AppTheme.textMedium,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${entry.totalXP} XP',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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