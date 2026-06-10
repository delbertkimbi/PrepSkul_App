import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:prepskul/core/theme/app_theme.dart';
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
import 'game_generation_screen.dart';
import 'game_setup_flow_screen.dart';
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
  final String? initialGameId; // Optional game deep-link target

  const GameLibraryScreen({
    Key? key,
    this.childId,
    this.initialTab = 1,
    this.initialGameId,
  })
    : super(key: key);

  @override
  State<GameLibraryScreen> createState() => _GameLibraryScreenState();
}

class _GameLibraryScreenState extends State<GameLibraryScreen>
    with SingleTickerProviderStateMixin {
  static const Set<GameType> _comingSoonGameTypes = {
    GameType.diagramLabel,
    GameType.match3,
    GameType.bubblePop,
    GameType.wordSearch,
    GameType.crossword,
    GameType.simulation,
    GameType.mystery,
    GameType.escapeRoom,
  };
  late TabController _tabController;
  List<GameModel> _games = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _showAllGamesForList = false;
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
  bool _expandUploadHistory = false;
  bool _initialGameHandled = false;

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
        safeSetState(() {
          _currentPage = 0;
          _hasMore = true;
          // Show shimmer while refreshing (instead of spinner-only experience).
          _isLoading = true;
          _showAllGamesForList = false;
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
        _showAllGamesForList = false;
      });
      if (fromCache) {
        LogService.debug(
          '🎮 [GameLibrary] Loaded ${loadedGames.length} games from local cache',
        );
      }
      _openInitialSharedGameIfNeeded();
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

  void _openInitialSharedGameIfNeeded() {
    if (_initialGameHandled) return;
    final targetId = widget.initialGameId?.trim();
    if (targetId == null || targetId.isEmpty) return;
    final target = _games.where((g) => g.id == targetId).toList();
    if (target.isEmpty) return;
    _initialGameHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigateToGame(target.first);
    });
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
    if (_comingSoonGameTypes.contains(game.gameType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_getGameTypeLabel(game.gameType)} is coming soon. Choose another game type for now.',
            style: const TextStyle(fontSize: 14),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!game.isPlayable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This game doesn\'t have playable content. Please regenerate this game.',
            style: TextStyle(fontSize: 14),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Remove',
            textColor: Colors.white,
            onPressed: () {
              _deleteGameImmediate(game);
            },
          ),
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
      if (mounted) await _loadGames(refresh: true);
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
        await _loadGames(refresh: true); // restore list if delete fails
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

      final appDeepLink = 'prepskul://skulmate/game/${game.id}';
      final webDeepLink = 'https://www.prepskul.com/skulmate/game/${game.id}';
      String shareText = 'Check out my skulMate game: "${game.title}"\n\n';
      shareText +=
          'Game Type: ${game.gameType.toString().replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')}\n';
      if (timesPlayed > 0) {
        shareText += 'My best score: $bestScore\n';
        shareText += 'Played $timesPlayed time${timesPlayed == 1 ? '' : 's'}\n';
      }
      shareText += '\nOpen in app: $appDeepLink';
      shareText += '\nWeb fallback: $webDeepLink';
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
        automaticallyImplyLeading: false,
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 22, color: AppTheme.textDark),
            tooltip: 'More',
            padding: const EdgeInsets.only(right: 12),
            onSelected: (value) {
              switch (value) {
                case 'leaderboard':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LeaderboardScreen(),
                    ),
                  );
                  break;
                case 'friends':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FriendsScreen(),
                    ),
                  );
                  break;
                case 'challenges':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChallengesScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'leaderboard',
                child: ListTile(
                  leading: Icon(Icons.emoji_events_outlined, size: 20),
                  title: Text('Leaderboard'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'friends',
                child: ListTile(
                  leading: Icon(Icons.people_outline, size: 20),
                  title: Text('Friends'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'challenges',
                child: ListTile(
                  leading: Icon(Icons.sports_esports_outlined, size: 20),
                  title: Text('Challenges'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
          // if (_gameStats != null && _gameStats!.currentStreak > 0)
          //   Padding(
          //     padding: const EdgeInsets.only(right: 8, left: 0, top: 8),
          //     child: InkWell(
          //       onTap: () {
          //         Navigator.push(
          //           context,
          //           MaterialPageRoute(
          //             builder: (context) =>
          //                 ActivityCalendarScreen(childId: widget.childId),
          //           ),
          //         );
          //       },
          //       borderRadius: BorderRadius.circular(20),
          //       child: Tooltip(
          //         message:
          //             '${_gameStats!.currentStreak} day streak! Tap to view activity',
          //         child: Container(
          //           padding: const EdgeInsets.symmetric(
          //             horizontal: 6,
          //             vertical: 4,
          //           ),
          //           decoration: BoxDecoration(
          //             color: Colors.orange.withOpacity(0.12),
          //             borderRadius: BorderRadius.circular(20),
          //             border: Border.all(
          //               color: Colors.orange.shade400,
          //               width: 1,
          //             ),
          //           ),
          //           child: Row(
          //             mainAxisSize: MainAxisSize.min,
          //             children: [
          //               const Text('🔥', style: TextStyle(fontSize: 10)),
          //               const SizedBox(width: 2),
          //               Text(
          //                 '${_gameStats!.currentStreak}',
          //                 style: GoogleFonts.poppins(
          //                   fontSize: 10,
          //                   fontWeight: FontWeight.w700,
          //                   color: Colors.orange.shade800,
          //                 ),
          //               ),
          //             ],
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
        
        
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
      onDismissed: (_) async {
        if (mounted) {
          // Remove immediately so Flutter won't rebuild a dismissed widget.
          safeSetState(() {
            _games.removeWhere((g) => g.id == game.id);
          });
        }
        await _deleteGameImmediate(game);
      },
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

  Widget _buildLoadPreviousGamesCard({
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: AppTheme.primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Show more games',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.chevron_right,
                    color: AppTheme.primaryColor, size: 18),
              ],
            ),
          ),
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
          _showAllGamesForList = false;
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
          _showAllGamesForList = false;
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
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: (() {
                          final showLoadMoreCard =
                              !_showAllGamesForList && filteredGames.length > 6;
                          final visibleGamesCount =
                              showLoadMoreCard ? 5 : filteredGames.length;
                          final baseCount = visibleGamesCount +
                              (showLoadMoreCard ? 1 : 0);
                          return baseCount + (_isLoadingMore ? 1 : 0);
                        })(),
                        itemBuilder: (context, index) {
                          final showLoadMoreCard =
                              !_showAllGamesForList && filteredGames.length > 6;
                          final visibleGamesCount =
                              showLoadMoreCard ? 5 : filteredGames.length;
                          final baseCount = visibleGamesCount +
                              (showLoadMoreCard ? 1 : 0);

                          if (showLoadMoreCard && index == visibleGamesCount) {
                            return _buildLoadPreviousGamesCard(onTap: () {
                              safeSetState(() {
                                _showAllGamesForList = true;
                              });
                            });
                          }

                          if (index >= baseCount) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final game = filteredGames[index];
                          return _buildDismissibleGameCard(
                            game: game,
                            padding: const EdgeInsets.only(bottom: 2),
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

  List<GameModel> get _gamesFromUserUploads {
    final uploads = _games.where((g) {
      final source = (g.sourceType ?? '').toLowerCase();
      return source == 'text' ||
          source == 'image' ||
          source == 'pdf' ||
          source == 'docx' ||
          source == 'document' ||
          (g.sourceTextSnapshot ?? '').trim().isNotEmpty ||
          (g.documentUrl ?? '').trim().isNotEmpty ||
          (g.sourceFileName ?? '').trim().isNotEmpty;
    }).toList();
    uploads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // Keep one recent row per source document/text to avoid duplicate instances.
    final bySource = <String, GameModel>{};
    for (final game in uploads) {
      final key = _uploadIdentityKey(game);
      bySource.putIfAbsent(key, () => game);
    }
    final deduped = bySource.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return deduped;
  }

  String _uploadIdentityKey(GameModel game) {
    final doc = (game.documentUrl ?? '').trim();
    if (doc.isNotEmpty) return 'doc:$doc';
    final text = (game.sourceTextSnapshot ?? '').trim();
    if (text.isNotEmpty) {
      final seed = text.length > 72 ? text.substring(0, 72) : text;
      return 'text:${seed.toLowerCase()}';
    }
    final name = (game.sourceFileName ?? '').trim().toLowerCase();
    if (name.isNotEmpty) return 'name:$name';
    return 'game:${game.id}';
  }

  String _uploadDisplayTitle(GameModel game) {
    final representative = _bestRepresentativeForUpload(game);
    final sourceName = (representative.sourceFileName ?? '').trim();
    if (sourceName.isNotEmpty) {
      final dot = sourceName.lastIndexOf('.');
      final base = dot > 0 ? sourceName.substring(0, dot) : sourceName;
      final candidate = base.trim().isEmpty ? sourceName : base.trim();
      if (!_isGenericUploadName(candidate)) return candidate;
    }
    final inferredFromText = _titleFromSourceText(
      (representative.sourceTextSnapshot ?? '').trim(),
    );
    if (inferredFromText != null) return inferredFromText;

    final url = (representative.documentUrl ?? '').trim();
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      final seg = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
      if (seg.isNotEmpty) {
        final cleaned = seg.split('?').first;
        final dot = cleaned.lastIndexOf('.');
        final base = dot > 0 ? cleaned.substring(0, dot) : cleaned;
        if (base.trim().isNotEmpty && !_isGenericUploadName(base.trim())) {
          return base.trim();
        }
      }
    }
    if ((representative.sourceTextSnapshot ?? '').trim().isNotEmpty) {
      return 'Uploaded notes';
    }
    return 'Uploaded source';
  }

  IconData _uploadSourceIcon(GameModel game) {
    final source = (game.sourceType ?? '').toLowerCase();
    if (source == 'image') return Icons.photo_library_outlined;
    if (source == 'text') return Icons.text_snippet_outlined;
    if (source == 'pdf' || source == 'docx' || source == 'document') {
      return Icons.picture_as_pdf_outlined;
    }
    return Icons.description_outlined;
  }

  String _uploadSourceLabel(GameModel game) {
    final source = (game.sourceType ?? '').toLowerCase();
    if (source == 'image') return 'Image';
    if (source == 'text') return 'Text';
    if (source == 'pdf') return 'PDF';
    if (source == 'docx') return 'DOCX';
    if (source == 'document') return 'Document';
    if ((game.sourceTextSnapshot ?? '').trim().isNotEmpty) return 'Text';
    return 'Source';
  }

  Color _uploadRowAccent(GameModel game) {
    final source = (game.sourceType ?? '').toLowerCase();
    if (source == 'image') return const Color(0xFF0EA5E9);
    if (source == 'text') return const Color(0xFF8B5CF6);
    return AppTheme.primaryColor;
  }

  Future<void> _openStoredUploadSource(GameModel game) async {
    final representative = _bestRepresentativeForUpload(game);
    final snapshot = (representative.sourceTextSnapshot ?? '').trim();
    if (snapshot.isNotEmpty && mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            _uploadDisplayTitle(representative),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                snapshot,
                style: GoogleFonts.poppins(fontSize: 13, height: 1.45),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
      return;
    }

    final urlRaw = (representative.documentUrl ?? '').trim();
    if (urlRaw.isNotEmpty) {
      final uri = Uri.tryParse(urlRaw);
      if (uri != null) {
        final ok = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (ok) return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No stored source found for this upload.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  GameModel _bestRepresentativeForUpload(GameModel game) {
    final targetKey = _uploadIdentityKey(game);
    final matches = _games
        .where((g) => !g.isDeleted && _uploadIdentityKey(g) == targetKey)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (matches.isEmpty) return game;

    // Prefer records that carry source text for preview and context naming.
    for (final g in matches) {
      if ((g.sourceTextSnapshot ?? '').trim().isNotEmpty) return g;
    }
    // Then prefer a non-generic uploaded filename.
    for (final g in matches) {
      final name = (g.sourceFileName ?? '').trim();
      if (name.isNotEmpty && !_isGenericUploadName(name)) return g;
    }
    return matches.first;
  }

  bool _isGenericUploadName(String value) {
    final raw = value.trim().toLowerCase();
    if (raw.isEmpty) return true;
    final base = raw.contains('.') ? raw.split('.').first : raw;
    return base == 'skulmate_notes' ||
        base == 'upload' ||
        base == 'document' ||
        base == 'notes';
  }

  String? _titleFromSourceText(String text) {
    if (text.isEmpty) return null;
    final compact = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
        .trim();
    if (compact.isEmpty) return null;

    final words = compact
        .split(' ')
        .where((w) => w.trim().length >= 3)
        .take(6)
        .toList();
    if (words.isEmpty) return null;

    var title = words.join(' ');
    if (title.length > 42) {
      title = title.substring(0, 42).trimRight();
    }
    return title;
  }

  Future<void> _regenerateFromStoredSource(GameModel game) async {
    final representative = _bestRepresentativeForUpload(game);
    final existing = _games
        .where(
          (g) =>
              g.id != game.id &&
              !g.isDeleted &&
              _uploadIdentityKey(g) == _uploadIdentityKey(game),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (existing.isNotEmpty) {
      _navigateToGame(existing.first);
      return;
    }

    final contextSelection = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GameSetupFlowScreen()),
    );
    if (!mounted) return;

    String? selectedGameType;
    String? selectedDifficulty;
    String? selectedTopic;
    if (contextSelection != null) {
      try {
        final dynamic c = contextSelection;
        selectedGameType = c.gameType as String?;
        selectedDifficulty = c.difficulty as String?;
        selectedTopic = c.topic as String?;
      } catch (_) {}
    }

    final snapshot = (representative.sourceTextSnapshot ?? '').trim();
    if (snapshot.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameGenerationScreen(
            text: snapshot,
            childId: widget.childId,
            gameType: selectedGameType,
            difficulty: selectedDifficulty,
            topic: selectedTopic,
          ),
        ),
      );
      if (mounted) await _loadGames(refresh: true);
      return;
    }

    final source = (representative.sourceType ?? '').toLowerCase();
    final url = (representative.documentUrl ?? '').trim();
    if (url.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameGenerationScreen(
            fileUrl: source == 'image' ? null : url,
            imageUrl: source == 'image' ? url : null,
            childId: widget.childId,
            gameType: selectedGameType,
            difficulty: selectedDifficulty,
            topic: selectedTopic,
          ),
        ),
      );
      if (mounted) await _loadGames(refresh: true);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No stored file or text for this upload.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildUploadTab() {
    const kUploadRecentCap = 3;
    final uploads = _gamesFromUserUploads;
    final history = _expandUploadHistory
        ? uploads
        : uploads.take(kUploadRecentCap).toList();
    final dateFmt = DateFormat.MMMd();

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async => _loadGames(refresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0.8,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: AppTheme.primaryColor.withValues(alpha: 0.18),
                width: 1.1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.upload_file_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Create New Game',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Upload notes, documents, or photos to generate interactive revision games.',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: AppTheme.textMedium,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SkulMateUploadScreen(childId: widget.childId),
                          ),
                        ).then((_) => _loadGames(refresh: true));
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: Text(
                        'Upload content',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading && _games.isEmpty) ...[
            _buildUploadStatusCard(
              title: 'Loading uploads',
              message:
                  'We are fetching your upload history. This can take a few seconds.',
              leading: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
            const SizedBox(height: 8),
            _buildUploadStatusCard(
              title: 'Tip',
              message:
                  'Pull down or tap refresh if your list does not appear immediately.',
              leading: const Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              trailing: TextButton(
                onPressed: () => _loadGames(refresh: true),
                child: Text(
                  'Refresh',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          ] else if (history.isEmpty) ...[
            _buildUploadStatusCard(
              title: 'No uploads yet',
              message:
                  'Recent uploads will appear here after you generate a game from notes, docs, or photos.',
              leading: const Icon(
                Icons.upload_file_outlined,
                size: 20,
                color: AppTheme.primaryColor,
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                'Recent upload items',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            ...history.asMap().entries.map((entry) {
              final i = entry.key;
              final game = entry.value;
              final accent = _uploadRowAccent(game);
              final displayTitle = _uploadDisplayTitle(game);
              final rowBg = i.isEven
                  ? Colors.white
                  : AppTheme.skyBlueLight.withValues(alpha: 0.4);
              const titleStyle = TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
                height: 1.2,
              );
              const subtitleStyle = TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
                height: 1.25,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: rowBg,
                  elevation: 0.6,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openStoredUploadSource(game),
                    child: SizedBox(
                      height: 72,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 5,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                              child: Row(
                                children: [
                                  Icon(
                                    _uploadSourceIcon(game),
                                    size: 22,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayTitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: titleStyle,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${dateFmt.format(game.createdAt)} · ${_uploadSourceLabel(game)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: subtitleStyle,
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Upload actions',
                                    icon: Icon(
                                      Icons.more_horiz_rounded,
                                      color: AppTheme.primaryColor,
                                      size: 26,
                                    ),
                                    onSelected: (value) {
                                      if (value == 'open') {
                                        _openStoredUploadSource(game);
                                      } else if (value == 'regen') {
                                        _regenerateFromStoredSource(game);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'open',
                                        child: Text('View content'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'regen',
                                        child: Text('Create another game'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (uploads.length > kUploadRecentCap)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => safeSetState(
                    () => _expandUploadHistory = !_expandUploadHistory,
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _expandUploadHistory
                        ? 'Show fewer uploads'
                        : 'See more uploads (${uploads.length - kUploadRecentCap} more)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
          ],
        ],
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

  Widget _buildUploadStatusCard({
    required String title,
    required String message,
    required Widget leading,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: leading,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 11.7,
                    color: AppTheme.textMedium,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
