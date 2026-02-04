import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import '../models/social_models.dart';
import '../services/social_service.dart';
import '../services/games_services_controller.dart';
import 'package:prepskul/core/widgets/empty_state_widget.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';

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
  bool _platformAvailable = false;  @override
  void initState() {
    super.initState();
    _checkPlatformAvailability();
    _loadLeaderboard();
  }  Future<void> _checkPlatformAvailability() async {
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
            content: Text('Error loading leaderboard: $e'),
            backgroundColor: Colors.red,
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
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final isTopThree = index < 3;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: isTopThree
                            ? Border.all(color: AppTheme.primaryColor, width: 2)
                            : null,
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
                          Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: isTopThree
                                    ? AppTheme.primaryColor
                                    : AppTheme.textMedium,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.userName ?? 'Unknown',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                Text(
                                  '${entry.totalXP} XP',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isTopThree)
                            Icon(
                              Icons.emoji_events,
                              color: index == 0
                                  ? Colors.amber
                                  : index == 1
                                      ? Colors.grey[400]
                                      : Colors.brown[300],
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}