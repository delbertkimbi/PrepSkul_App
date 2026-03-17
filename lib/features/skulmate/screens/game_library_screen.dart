import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../models/game_model.dart';
import '../models/game_stats_model.dart';
import '../services/skulmate_service.dart';
import '../services/game_stats_service.dart';
import '../services/skulmate_streak_reminder_service.dart';
import '../widgets/game_card.dart';
import '../widgets/daily_challenge_card.dart';
import '../services/daily_challenge_service.dart';
import 'quiz_game_screen.dart';
import 'flashcard_game_screen.dart';
import 'matching_game_screen.dart';
import 'fill_blank_game_screen.dart';
import 'match3_game_screen.dart';
import 'bubble_pop_game_screen.dart';
import 'word_search_game_screen.dart';
import 'crossword_game_screen.dart';
import 'diagram_label_game_screen.dart';
import 'drag_drop_game_screen.dart';
import 'puzzle_pieces_game_screen.dart';
import 'simulation_game_screen.dart';
import 'mystery_game_screen.dart';
import 'escape_room_game_screen.dart';
import 'skulmate_upload_screen.dart';
import 'leaderboard_screen.dart';
import 'friends_screen.dart';
import 'challenges_screen.dart';
import 'activity_calendar_screen.dart';
import 'package:prepskul/core/widgets/empty_state_widget.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';
import '../widgets/session_summaries_tab.dart';

/// Screen showing all generated games with tabs: Sessions, My Games, Upload
class GameLibraryScreen extends StatefulWidget {
  final String? childId; // For parents viewing child's games
  final int initialTab; // 0 = Sessions, 1 = My Games, 2 = Upload

  const GameLibraryScreen({Key? key, this.childId, this.initialTab = 1})
    : super(key: key);

  @override
  State<GameLibraryScreen> createState() => _GameLibraryScreenState();
}

class _GameLibraryScreenState extends State<GameLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<GameModel> _games = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  String? _selectedFilter; // 'quiz', 'flashcards', 'matching', 'fill_blank'
  bool _showFavoritesOnly = false;
  String _sortBy = 'recent'; // 'recent', 'recently_played', 'alphabetical'
  Map<String, DateTime?> _gameLastPlayedDates =
      {}; // Cache for last played dates
  Set<String> _favoriteGameIds = {};
  GameStats? _gameStats;
  int _dailyChallengeRefreshKey = 0;
  bool _swipeHintSeen =
      true; // After load: true = user has seen/dismissed the hint
  bool _isFetchingGames = false;
  bool _showOfflineGamesNotice = false;

  static const String _prefKeySwipeHint = 'skulmate_swipe_delete_hint_seen';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _loadGames();
    _loadGameStats();
    _loadSwipeHintSeen();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadSwipeHintSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_prefKeySwipeHint) ?? false;
      if (mounted) safeSetState(() => _swipeHintSeen = seen);
    } catch (_) {}
  }

  Future<void> _loadGameStats() async {
    final stats = await GameStatsService.getStats();
    if (mounted) safeSetState(() => _gameStats = stats);
    // Reschedule streak reminder if needed (daily at 6 PM when not played yet)
    SkulMateStreakReminderService.rescheduleIfNeeded();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when user scrolls to 80% of the list
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadMore();
      }
    }
  }

  Future<void> _loadGames({bool refresh = false}) async {
    if (_isFetchingGames) return;
    _isFetchingGames = true;
    try {
      if (refresh) {
        // Keep current list visible during refresh to avoid distracting flashes.
        safeSetState(() {
          _currentPage = 0;
          _hasMore = true;
        });
      } else {
        safeSetState(() => _isLoading = true);
      }

      final result = await SkulMateService.getGamesPaginated(
        childId: widget.childId,
        limit: _pageSize,
        offset: 0,
      );

      final loadedGames = result['games'] as List<GameModel>;
      final fromCache = (result['fromCache'] as bool?) ?? false;
      LogService.debug('🎮 [GameLibrary] Loaded ${loadedGames.length} games');
      final favorites = <String>{};
      for (final game in loadedGames) {
        if (await SkulMateService.isFavorite(game.id)) {
          favorites.add(game.id);
        }
      }
      safeSetState(() {
        _games = loadedGames;
        _favoriteGameIds = favorites;
        _hasMore = result['hasMore'] as bool;
        _currentPage = 0;
        _isLoading = false;
        _showOfflineGamesNotice = fromCache;
      });
      if (mounted && fromCache) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'You are offline. Showing saved games from this device.',
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      LogService.error('🎮 [skulMate] Error loading games: $e');
      safeSetState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading games: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isFetchingGames = false;
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    try {
      safeSetState(() => _isLoadingMore = true);

      final nextPage = _currentPage + 1;
      final result = await SkulMateService.getGamesPaginated(
        childId: widget.childId,
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );

      final newGames = result['games'] as List<GameModel>;
      final fromCache = (result['fromCache'] as bool?) ?? false;
      final hasMore = result['hasMore'] as bool;
      final favoriteIds = Set<String>.from(_favoriteGameIds);
      for (final game in newGames) {
        if (await SkulMateService.isFavorite(game.id)) {
          favoriteIds.add(game.id);
        }
      }

      safeSetState(() {
        _games.addAll(newGames);
        _favoriteGameIds = favoriteIds;
        _hasMore = fromCache ? false : hasMore;
        _currentPage = nextPage;
        _isLoadingMore = false;
        if (fromCache) _showOfflineGamesNotice = true;
      });
    } catch (e) {
      LogService.error('🎮 [skulMate] Error loading more games: $e');
      safeSetState(() => _isLoadingMore = false);
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

  List<GameModel> _getFilteredGamesSync() {
    var filtered = List<GameModel>.from(_games);

    if (_showFavoritesOnly) {
      filtered = filtered
          .where((g) => _favoriteGameIds.contains(g.id))
          .toList();
    }

    if (_selectedFilter != null) {
      filtered = filtered.where((game) {
        final gameTypeStr = game.gameType.toString();
        if (_selectedFilter == 'fill_blank') {
          return gameTypeStr == 'fillBlank';
        }
        return gameTypeStr == _selectedFilter;
      }).toList();
    }

    if (_sortBy == 'alphabetical') {
      filtered.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    } else {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return filtered;
  }

  Future<List<GameModel>> _getFilteredGames() async {
    var filtered = _games;

    // Filter by favorites (async operation)
    if (_showFavoritesOnly) {
      final favoriteIds = <String>[];
      for (final game in filtered) {
        if (await SkulMateService.isFavorite(game.id)) {
          favoriteIds.add(game.id);
        }
      }
      filtered = filtered
          .where((game) => favoriteIds.contains(game.id))
          .toList();
    }

    // Filter by type
    if (_selectedFilter != null) {
      filtered = filtered.where((game) {
        // Handle both 'fill_blank' and 'fillBlank' for compatibility
        final gameTypeStr = game.gameType.toString();
        if (_selectedFilter == 'fill_blank') {
          return gameTypeStr == 'fillBlank';
        }
        return gameTypeStr == _selectedFilter;
      }).toList();
    }

    // Sort games
    if (_sortBy == 'recently_played') {
      // Load last played dates for sorting
      final gamesWithDates = <MapEntry<GameModel, DateTime?>>[];
      for (final game in filtered) {
        if (!_gameLastPlayedDates.containsKey(game.id)) {
          final stats = await SkulMateService.getGameStats(game.id);
          final lastPlayed = stats['lastPlayed'] as DateTime?;
          _gameLastPlayedDates[game.id] = lastPlayed;
        }
        gamesWithDates.add(MapEntry(game, _gameLastPlayedDates[game.id]));
      }

      // Sort by last played (most recent first), then by created date
      gamesWithDates.sort((a, b) {
        if (a.value == null && b.value == null) {
          return b.key.createdAt.compareTo(a.key.createdAt);
        }
        if (a.value == null) return 1;
        if (b.value == null) return -1;
        return b.value!.compareTo(a.value!);
      });

      filtered = gamesWithDates.map((e) => e.key).toList();
    } else if (_sortBy == 'alphabetical') {
      filtered.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    } else {
      // 'recent' - already sorted by created_at in getGames()
      // No additional sorting needed
    }

    return filtered;
  }

  Future<List<GameModel>> _getRecentlyPlayedGames() async {
    // Get games played in the last 7 days
    final allGames = await _getFilteredGames();
    final recentlyPlayed = <GameModel>[];
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    for (final game in allGames) {
      if (!_gameLastPlayedDates.containsKey(game.id)) {
        final stats = await SkulMateService.getGameStats(game.id);
        final lastPlayed = stats['lastPlayed'] as DateTime?;
        _gameLastPlayedDates[game.id] = lastPlayed;
      }

      final lastPlayed = _gameLastPlayedDates[game.id];
      if (lastPlayed != null && lastPlayed.isAfter(sevenDaysAgo)) {
        recentlyPlayed.add(game);
      }
    }

    // Sort by most recently played
    recentlyPlayed.sort((a, b) {
      final aDate = _gameLastPlayedDates[a.id];
      final bDate = _gameLastPlayedDates[b.id];
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    return recentlyPlayed;
  }

  Future<void> _showGamePreview(GameModel game) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      game.title,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getGameTypeLabel(game.gameType),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${game.items.length} items',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Preview:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: game.items.length > 3 ? 3 : game.items.length,
                  itemBuilder: (context, index) {
                    final item = game.items[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.question != null)
                            Text(
                              item.question!,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textDark,
                              ),
                            ),
                          if (item.term != null)
                            Text(
                              item.term!,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textDark,
                              ),
                            ),
                          if (item.blankText != null)
                            Text(
                              item.blankText!,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.textDark,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (game.items.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '... and ${game.items.length - 3} more items',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToGame(game);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: const Text('Play Game'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGameTypeLabel(GameType type) {
    switch (type) {
      case GameType.quiz:
        return 'Quiz';
      case GameType.flashcards:
        return 'Flashcards';
      case GameType.matching:
        return 'Matching';
      case GameType.fillBlank:
        return 'Fill in Blank';
      case GameType.match3:
        return 'Match-3';
      case GameType.bubblePop:
        return 'Bubble Pop';
      case GameType.wordSearch:
        return 'Word Search';
      case GameType.crossword:
        return 'Crossword';
      case GameType.diagramLabel:
        return 'Diagram Label';
      case GameType.dragDrop:
        return 'Drag & Drop';
      case GameType.puzzlePieces:
        return 'Puzzle Pieces';
      case GameType.simulation:
        return 'Simulation';
      case GameType.mystery:
        return 'Mystery';
      case GameType.escapeRoom:
        return 'Escape Room';
    }
  }

  void _navigateToGame(GameModel game, {bool isDailyChallenge = false}) {
    if (!game.isPlayable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This game doesn\'t have playable content. Try generating a new one or use "Enter Text Manually".',
            style: TextStyle(fontSize: 14),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Widget gameScreen;
    switch (game.gameType) {
      case GameType.quiz:
        gameScreen = QuizGameScreen(
          game: game,
          isDailyChallenge: isDailyChallenge,
        );
        break;
      case GameType.flashcards:
        gameScreen = FlashcardGameScreen(game: game);
        break;
      case GameType.matching:
        gameScreen = MatchingGameScreen(game: game);
        break;
      case GameType.fillBlank:
        gameScreen = FillBlankGameScreen(game: game);
        break;
      case GameType.match3:
        gameScreen = Match3GameScreen(game: game);
        break;
      case GameType.bubblePop:
        gameScreen = BubblePopGameScreen(game: game);
        break;
      case GameType.wordSearch:
        gameScreen = WordSearchGameScreen(game: game);
        break;
      case GameType.crossword:
        gameScreen = CrosswordGameScreen(game: game);
        break;
      case GameType.diagramLabel:
        // TODO: Implement DiagramLabelGameScreen - using fallback for now
        gameScreen = MysteryGameScreen(game: game);
        break;
      case GameType.dragDrop:
        gameScreen = DragDropGameScreen(game: game);
        break;
      case GameType.puzzlePieces:
        gameScreen = PuzzlePiecesGameScreen(game: game);
        break;
      case GameType.simulation:
        gameScreen = SimulationGameScreen(game: game);
        break;
      case GameType.mystery:
        gameScreen = MysteryGameScreen(game: game);
        break;
      case GameType.escapeRoom:
        gameScreen = EscapeRoomGameScreen(game: game);
        break;
      default:
        gameScreen = QuizGameScreen(game: game);
        break;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => gameScreen),
    ).then((_) {
      _loadGames();
      _loadGameStats();
      if (isDailyChallenge) safeSetState(() => _dailyChallengeRefreshKey++);
    });
  }

  Future<void> _deleteGame(GameModel game) async {
    final confirmed = await _confirmDeleteGame(game);
    if (confirmed) await _deleteGameImmediate(game);
  }

  Future<void> _deleteGameImmediate(GameModel game) async {
    try {
      await SkulMateService.deleteGame(game.id);
      if (mounted) _loadGames(refresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Game deleted'),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
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

  Future<bool> _confirmDeleteGame(GameModel game) async {
    final stats = await SkulMateService.getGameStats(game.id);
    final timesPlayed = stats['totalPlays'] as int? ?? 0;
    final bestScore = stats['bestScore'] as int? ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${game.title}"?'),
            if (timesPlayed > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ This game has statistics:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Played $timesPlayed time${timesPlayed == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                    if (bestScore > 0)
                      Text(
                        '• Best score: $bestScore',
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'All statistics will be permanently deleted.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _shareGame(GameModel game) async {
    try {
      // Create a shareable message
      final stats = await SkulMateService.getGameStats(game.id);
      final timesPlayed = stats['totalPlays'] as int? ?? 0;
      final bestScore = stats['bestScore'] as int? ?? 0;

      String shareText = '🎮 Check out my skulMate game: "${game.title}"\n\n';
      shareText +=
          'Game Type: ${game.gameType.toString().replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')}\n';
      if (timesPlayed > 0) {
        shareText += 'My best score: $bestScore\n';
        shareText += 'Played $timesPlayed time${timesPlayed == 1 ? '' : 's'}\n';
      }
      shareText += '\nPlay this game in skulMate!';

      // TODO: In the future, we can add a deep link like: prepskul://game/${game.id}
      // For now, just share the text
      await Share.share(shareText);
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppTheme.textDark,
            size: 24,
          ),
          onPressed: () async {
            final role = await AuthService.getUserRole();
            final navService = NavigationService();
            final route = role == 'parent' ? '/parent-nav' : '/student-nav';
            if (navService.isReady) {
              await navService.navigateToRoute(route, replace: true);
            } else if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          tooltip: 'Back to main app',
        ),
        centerTitle: true,
        titleSpacing: 0,
        title: LayoutBuilder(
          builder: (context, constraints) {
            final canShowIcon = constraints.maxWidth >= 130;
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canShowIcon) ...[
                    PhosphorIcon(
                      PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                      color: AppTheme.textDark,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    'skulMate',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textMedium,
          indicatorColor: AppTheme.primaryColor,
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Sessions'),
            Tab(text: 'My Games'),
            Tab(text: 'Upload'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined, size: 20),
            tooltip: 'Leaderboard',
            iconSize: 20,
            padding: const EdgeInsets.all(1),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LeaderboardScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.people_outline, size: 20),
            tooltip: 'Friends',
            iconSize: 20,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FriendsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sports_esports_outlined, size: 20),
            tooltip: 'Challenges',
            iconSize: 20,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChallengesScreen(),
                ),
              );
            },
          ),
          if (_gameStats != null && _gameStats!.currentStreak > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4, left: 0, top: 8),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ActivityCalendarScreen(childId: widget.childId),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Tooltip(
                  message:
                      '${_gameStats!.currentStreak} day streak! Tap to view activity',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.orange.shade400,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 2),
                        Text(
                          '${_gameStats!.currentStreak}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Sessions
          SessionSummariesTab(childId: widget.childId),
          // Tab 1: My Games
          _buildMyGamesTab(),
          // Tab 2: Upload
          _buildUploadTab(),
        ],
      ),
    );
  }

  Widget _buildDismissibleGameCard({
    required GameModel game,
    required EdgeInsets padding,
  }) {
    return Dismissible(
      key: ValueKey(game.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) => _confirmDeleteGame(game),
      onDismissed: (_) => _deleteGameImmediate(game),
      child: Padding(
        padding: padding,
        child: GameCard(
          game: game,
          onTap: () => _navigateToGame(game),
          onShare: () => _shareGame(game),
        ),
      ),
    );
  }

  Widget _buildSwipeToDeleteHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Material(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_prefKeySwipeHint, true);
            if (mounted) safeSetState(() => _swipeHintSeen = true);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.swipe_left_rounded,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Swipe left on a game to delete it',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to dismiss',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Got it',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.white : AppTheme.textDark,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        safeSetState(() {
          _selectedFilter = selected ? value : null;
          if (selected)
            _showFavoritesOnly =
                false; // Deselect Favorites when another tab is chosen
        });
      },
      selectedColor: AppTheme.primaryColor, // Deep blue when selected
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
        width: isSelected ? 0 : 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildFavoriteChip() {
    return FilterChip(
      showCheckmark: false,
      avatar: Icon(
        Icons.favorite,
        size: 16,
        color: _showFavoritesOnly ? Colors.red : AppTheme.primaryColor,
      ),
      label: Text(
        'Favorites',
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: _showFavoritesOnly ? FontWeight.w600 : FontWeight.normal,
          color: _showFavoritesOnly ? Colors.white : AppTheme.textDark,
        ),
      ),
      selected: _showFavoritesOnly,
      onSelected: (selected) {
        safeSetState(() {
          _showFavoritesOnly = selected;
        });
      },
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: _showFavoritesOnly ? AppTheme.primaryColor : Colors.grey[300]!,
        width: _showFavoritesOnly ? 0 : 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildMyGamesTab() {
    return Column(
      children: [
        // Daily Challenge card (one focused set per day; user-specific)
        DailyChallengeCard(
          key: ValueKey(_dailyChallengeRefreshKey),
          games: _games,
          childId: widget.childId,
          currentStreak: _gameStats?.currentStreak,
          onRefresh: () async {
            await _loadGames(refresh: true);
            safeSetState(() => _dailyChallengeRefreshKey++);
          },
          onPlay: (game, {isDailyChallenge = false}) =>
              _navigateToGame(game, isDailyChallenge: isDailyChallenge),
        ),
        // Filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: Colors.white,
          child: Column(
            children: [
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', null),
                    const SizedBox(width: 6),
                    _buildFavoriteChip(),
                    const SizedBox(width: 6),
                    _buildFilterChip('Quiz', 'quiz'),
                    const SizedBox(width: 6),
                    _buildFilterChip('Flashcards', 'flashcards'),
                    const SizedBox(width: 6),
                    _buildFilterChip('Matching', 'matching'),
                    const SizedBox(width: 6),
                    _buildFilterChip('Fill Blank', 'fill_blank'),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_showOfflineGamesNotice)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              'Offline mode: showing games saved on this device.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        // First-time: swipe to delete hint
        if (!_swipeHintSeen) _buildSwipeToDeleteHint(),
        // Games list
        Expanded(
          child: _isLoading
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 5,
                  itemBuilder: (context, index) => ShimmerLoading.gameCard(),
                )
              : Builder(
                  builder: (context) {
                    final filteredGames = _getFilteredGamesSync();
                    if (filteredGames.isEmpty) return _buildEmptyState();
                    return RefreshIndicator(
                      onRefresh: () async {
                        _gameLastPlayedDates.clear();
                        await _loadGames(refresh: true);
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                        itemCount:
                            filteredGames.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= filteredGames.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final game = filteredGames[index];
                          return _buildDismissibleGameCard(
                            game: game,
                            padding: const EdgeInsets.only(bottom: 4),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUploadTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.upload_file_rounded,
              size: 80,
              color: AppTheme.primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Create New Game',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Upload your notes, documents, or photos to generate interactive revision games.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textMedium,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SkulMateUploadScreen(childId: widget.childId),
                  ),
                ).then((_) => _loadGames(refresh: true));
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Upload Content'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget.noGames(
      onCreateGame: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SkulMateUploadScreen(childId: widget.childId),
          ),
        ).then((_) => _loadGames());
      },
    );
  }
}
