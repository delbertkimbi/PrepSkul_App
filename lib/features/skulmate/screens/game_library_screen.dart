import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';
import '../widgets/game_card.dart';
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
import 'package:prepskul/core/widgets/empty_state_widget.dart';
import 'package:prepskul/core/widgets/shimmer_loading.dart';
import 'package:prepskul/core/utils/debouncer.dart';

/// Screen showing all generated games
class GameLibraryScreen extends StatefulWidget {
  final String? childId; // For parents viewing child's games

  const GameLibraryScreen({Key? key, this.childId}) : super(key: key);

  @override
  State<GameLibraryScreen> createState() => _GameLibraryScreenState();
}

class _GameLibraryScreenState extends State<GameLibraryScreen> {
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
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 500);
  Map<String, DateTime?> _gameLastPlayedDates = {}; // Cache for last played dates

  @override
  void initState() {
    super.initState();
    _loadGames();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebouncer.dispose();
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
    try {
      if (refresh) {
        safeSetState(() {
          _games = [];
          _currentPage = 0;
          _hasMore = true;
          _isLoading = true;
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
      LogService.debug('🎮 [GameLibrary] Loaded ${loadedGames.length} games');
      safeSetState(() {
        _games = loadedGames;
        _hasMore = result['hasMore'] as bool;
        _currentPage = 0;
        _isLoading = false;
      });
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
      final hasMore = result['hasMore'] as bool;

      safeSetState(() {
        _games.addAll(newGames);
        _hasMore = hasMore;
        _currentPage = nextPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      LogService.error('🎮 [skulMate] Error loading more games: $e');
      safeSetState(() => _isLoadingMore = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading more games: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      filtered = filtered.where((game) => favoriteIds.contains(game.id)).toList();
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

    // Enhanced search - search in title and content
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((game) {
        // Search in title
        if (game.title.toLowerCase().contains(query)) {
          return true;
        }
        // Search in game items (questions, terms, etc.)
        for (final item in game.items) {
          if (item.question?.toLowerCase().contains(query) == true ||
              item.term?.toLowerCase().contains(query) == true ||
              item.definition?.toLowerCase().contains(query) == true ||
              item.blankText?.toLowerCase().contains(query) == true) {
            return true;
          }
        }
        return false;
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
      filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  void _navigateToGame(GameModel game) {
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
    ).then((_) => _loadGames()); // Refresh after returning
  }

  Future<void> _deleteGame(GameModel game) async {
    // Load stats before showing confirmation
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

    if (confirmed == true) {
      try {
        await SkulMateService.deleteGame(game.id);
        _loadGames(refresh: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game deleted successfully'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting game: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _shareGame(GameModel game) async {
    try {
      // Create a shareable message
      final stats = await SkulMateService.getGameStats(game.id);
      final timesPlayed = stats['totalPlays'] as int? ?? 0;
      final bestScore = stats['bestScore'] as int? ?? 0;
      
      String shareText = '🎮 Check out my skulMate game: "${game.title}"\n\n';
      shareText += 'Game Type: ${game.gameType.toString().replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')}\n';
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
            content: Text('Error sharing game: $e'),
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
        centerTitle: true,
        title: Text(
          'My Games',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Leaderboard',
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
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
            icon: const Icon(Icons.people_outline),
            tooltip: 'Friends',
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FriendsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sports_esports_outlined),
            tooltip: 'Challenges',
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChallengesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SkulMateUploadScreen(
                    childId: widget.childId,
                  ),
                ),
              ).then((_) => _loadGames(refresh: true));
            },
            tooltip: 'Create New Game',
          ),
          const SizedBox(width: 8), // Spacing from edge
        ],
      ),
      body: Column(
        children: [
          // Search and filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                // Search bar - more compact
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    // Debounced search - will execute after user stops typing
                    _searchDebouncer.run(() {
                      if (mounted) {
                        setState(() {}); // Trigger rebuild to show filtered results
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search games...',
                    hintStyle: GoogleFonts.poppins(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const SizedBox(height: 10),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', null),
                      const SizedBox(width: 8),
                      _buildFavoriteChip(),
                      const SizedBox(width: 8),
                      _buildFilterChip('Quiz', 'quiz'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Flashcards', 'flashcards'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Matching', 'matching'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Fill Blank', 'fill_blank'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Games list
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (context, index) => ShimmerLoading.gameCard(),
                  )
                : FutureBuilder<List<GameModel>>(
                    future: _getFilteredGames(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: 5,
                          itemBuilder: (context, index) => ShimmerLoading.gameCard(),
                        );
                      }
                      final filteredGames = snapshot.data ?? [];
                      
                      if (filteredGames.isEmpty) {
                        return _buildEmptyState();
                      }

                      // Show "Recently Played" section if applicable
                      return FutureBuilder<List<GameModel>>(
                        future: _getRecentlyPlayedGames(),
                        builder: (context, recentlyPlayedSnapshot) {
                          final recentlyPlayed = recentlyPlayedSnapshot.data ?? [];
                          final showRecentlyPlayed = recentlyPlayed.isNotEmpty && 
                                                     _sortBy != 'recently_played' &&
                                                     !_showFavoritesOnly &&
                                                     _selectedFilter == null &&
                                                     _searchController.text.isEmpty;

                          return RefreshIndicator(
                            onRefresh: () async {
                              _gameLastPlayedDates.clear();
                              await _loadGames(refresh: true);
                            },
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredGames.length + 
                                        (showRecentlyPlayed ? recentlyPlayed.length + 2 : 0) +
                                        (_isLoadingMore ? 1 : 0) +
                                        (!_hasMore && filteredGames.isNotEmpty ? 1 : 0),
                              itemBuilder: (context, index) {
                                // Recently Played section header
                                if (showRecentlyPlayed && index == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Icon(Icons.history, color: AppTheme.primaryColor, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Recently Played',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                // Recently Played games
                                if (showRecentlyPlayed && index > 0 && index <= recentlyPlayed.length) {
                                  final game = recentlyPlayed[index - 1];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: GameCard(
                                      game: game,
                                      onTap: () => _navigateToGame(game),
                                      onDelete: () => _deleteGame(game),
                                      onPreview: () => _showGamePreview(game),
                                      onShare: () => _shareGame(game),
                                    ),
                                  );
                                }

                                // Divider between sections
                                if (showRecentlyPlayed && index == recentlyPlayed.length + 1) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Divider(color: Colors.grey[300]),
                                  );
                                }

                                // All games section
                                final gameIndex = showRecentlyPlayed 
                                    ? index - recentlyPlayed.length - 2
                                    : index;
                                
                                // Loading indicator at bottom
                                if (gameIndex >= filteredGames.length) {
                                  if (_isLoadingMore) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  if (!_hasMore && filteredGames.isNotEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Center(
                                        child: Text(
                                          'No more games to load',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: AppTheme.textMedium,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }
                                
                                if (gameIndex < 0) {
                                  return const SizedBox.shrink();
                                }
                                
                                final game = filteredGames[gameIndex];
                                return GameCard(
                                  game: game,
                                  onTap: () => _navigateToGame(game),
                                  onDelete: () => _deleteGame(game),
                                  onPreview: () => _showGamePreview(game),
                                  onShare: () => _shareGame(game),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
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
      avatar: Icon(
        Icons.favorite,
        size: 16,
        color: _showFavoritesOnly ? Colors.white : AppTheme.primaryColor,
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
      selectedColor: AppTheme.primaryColor, // Deep blue instead of red
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: _showFavoritesOnly ? AppTheme.primaryColor : Colors.grey[300]!,
        width: _showFavoritesOnly ? 0 : 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget.noGames(
      onCreateGame: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SkulMateUploadScreen(
              childId: widget.childId,
            ),
          ),
        ).then((_) => _loadGames());
      },
    );
  }
}
