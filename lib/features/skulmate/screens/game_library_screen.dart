import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'skulmate_upload_screen.dart';

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
  String? _selectedFilter; // 'quiz', 'flashcards', 'matching', 'fill_blank'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGames() async {
    try {
      safeSetState(() => _isLoading = true);

      final games = await SkulMateService.getGames(childId: widget.childId);

      safeSetState(() {
        _games = games;
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

  List<GameModel> get _filteredGames {
    var filtered = _games;

    // Filter by type
    if (_selectedFilter != null) {
      filtered = filtered.where((game) {
        return game.gameType.toString() == _selectedFilter;
      }).toList();
    }

    // Filter by search
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((game) {
        return game.title.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
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
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => gameScreen),
    ).then((_) => _loadGames()); // Refresh after returning
  }

  Future<void> _deleteGame(GameModel game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game?'),
        content: Text('Are you sure you want to delete "${game.title}"?'),
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
        _loadGames();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game deleted'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
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
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SkulMateUploadScreen(
                    childId: widget.childId,
                  ),
                ),
              ).then((_) => _loadGames());
            },
            tooltip: 'Create New Game',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search games...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (_) => safeSetState(() {}),
                ),
                const SizedBox(height: 12),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', null),
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
                ? const Center(child: CircularProgressIndicator())
                : _filteredGames.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadGames,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredGames.length,
                          itemBuilder: (context, index) {
                            final game = _filteredGames[index];
                            return GameCard(
                              game: game,
                              onTap: () => _navigateToGame(game),
                              onDelete: () => _deleteGame(game),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        safeSetState(() {
          _selectedFilter = selected ? value : null;
        });
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.games_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No games yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first game to start learning!',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SkulMateUploadScreen(
                    childId: widget.childId,
                  ),
                ),
              ).then((_) => _loadGames());
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Game'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

