import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/widgets/empty_state_widget.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';
import '../services/skulmate_service.dart';
import '../models/game_model.dart';
import '../screens/quiz_game_screen.dart';
import '../screens/flashcard_game_screen.dart';
import '../screens/matching_game_screen.dart';
import '../screens/fill_blank_game_screen.dart';
import '../screens/word_guessing_game_screen.dart';

/// Tab showing completed sessions with summaries that can generate games
class SessionSummariesTab extends StatefulWidget {
  final String? childId;

  const SessionSummariesTab({Key? key, this.childId}) : super(key: key);

  @override
  State<SessionSummariesTab> createState() => _SessionSummariesTabState();
}

class _SessionSummariesTabState extends State<SessionSummariesTab> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  Map<String, bool> _generatingGames = {}; // Track which sessions are generating games

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      safeSetState(() => _isLoading = true);

      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch completed sessions with summaries
      // For parents viewing child's games, use childId
      final queryUserId = widget.childId ?? userId;

      final response = await SupabaseService.client
          .from('individual_sessions')
          .select('''
            id,
            scheduled_date,
            scheduled_time,
            session_summary,
            recurring_sessions!inner(
              id,
              tutor_name,
              tutor_avatar_url,
              subject
            )
          ''')
          .or('learner_id.eq.$queryUserId,parent_id.eq.$queryUserId')
          .eq('status', 'completed')
          .not('session_summary', 'is', null)
          .neq('session_summary', '')
          .not('recurring_session_id', 'is', null)
          .order('scheduled_date', ascending: false)
          .order('scheduled_time', ascending: false)
          .limit(50);

      final sessions = (response as List).cast<Map<String, dynamic>>();

      // Check which sessions already have games
      final sessionIds = sessions.map((s) => s['id'] as String).toList();
      
      try {
        final existingGames = await SupabaseService.client
            .from('skulmate_games')
            .select('individual_session_id')
            .inFilter('individual_session_id', sessionIds)
            .eq('user_id', queryUserId);

        final gameSessionIds = (existingGames as List)
            .map((g) => g['individual_session_id'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toSet();

        // Mark sessions that have games
        for (var session in sessions) {
          session['has_game'] = gameSessionIds.contains(session['id'] as String);
        }
      } catch (e) {
        // Column doesn't exist yet - migration not applied
        // Skip game checking, show all sessions
        debugPrint('⚠️ individual_session_id column not found - migration may not be applied: $e');
        for (var session in sessions) {
          session['has_game'] = false; // Default to no game
        }
      }

      safeSetState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading sessions: $e');
      safeSetState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sessions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateGameFromSession(Map<String, dynamic> session) async {
    final sessionId = session['id'] as String;
    if (_generatingGames[sessionId] == true) return; // Already generating

    try {
      safeSetState(() {
        _generatingGames[sessionId] = true;
      });

      final game = await SkulMateService.generateChallengeFromSession(sessionId);

      safeSetState(() {
        _generatingGames[sessionId] = false;
        session['has_game'] = true; // Mark as having game
      });

      // Validate playable before navigating (avoid broken quiz/flashcard screens)
      if (mounted && !game.isPlayable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This session challenge couldn\'t be turned into a playable game.'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Navigate to game screen
      if (mounted) {
        Widget gameScreen;
        switch (game.gameType) {
          case GameType.quiz:
            gameScreen = QuizGameScreen(game: game);
            break;
          case GameType.flashcards:
            gameScreen = FlashcardGameScreen(game: game);
            break;
          case GameType.matching:
            gameScreen = MatchingGameScreen(game: game);
            break;
          case GameType.fillBlank:
            gameScreen = WordGuessingGameScreen(game: game);
            break;
          default:
            gameScreen = QuizGameScreen(game: game);
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => gameScreen),
        );
      }
    } catch (e) {
      LogService.error('Error generating game from session: $e');
      safeSetState(() {
        _generatingGames[sessionId] = false;
      });
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

  String _getSummaryPreview(String? summary) {
    if (summary == null || summary.isEmpty) return '';
    if (summary.length <= 100) return summary;
    return '${summary.substring(0, 100)}...';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => ShimmerLoading.listTile(),
      );
    }

    if (_sessions.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.video_library_outlined,
        title: 'No Sessions Yet',
        message: 'Complete tutoring sessions to generate revision games from session summaries.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          final recurringData = session['recurring_sessions'] as Map<String, dynamic>?;
          final tutorName = recurringData?['tutor_name'] as String? ?? 'Tutor';
          final subject = recurringData?['subject'] as String? ?? 'Session';
          final date = _formatDate(session['scheduled_date'] as String?);
          final summary = session['session_summary'] as String? ?? '';
          final hasGame = session['has_game'] as bool? ?? false;
          final sessionId = session['id'] as String;
          final isGenerating = _generatingGames[sessionId] == true;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppTheme.softBorder, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'with $tutorName • $date',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasGame)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Game Ready',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentGreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _getSummaryPreview(summary),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textMedium,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isGenerating
                          ? null
                          : () => _generateGameFromSession(session),
                      icon: isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              hasGame ? Icons.play_arrow : Icons.auto_awesome,
                              size: 18,
                            ),
                      label: Text(
                        hasGame
                            ? 'Play Game'
                            : isGenerating
                                ? 'Generating...'
                                : 'Generate Game',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasGame
                            ? AppTheme.accentGreen
                            : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
