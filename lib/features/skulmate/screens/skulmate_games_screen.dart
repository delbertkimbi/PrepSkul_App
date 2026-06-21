import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/widgets/empty_state_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';
import '../utils/skulmate_game_router.dart';
import '../widgets/game_card.dart';
import '../widgets/skulmate_surface_styles.dart';

/// Saved games list — connected to SkulMate home (back button, no legacy tabs).
class SkulMateGamesScreen extends StatefulWidget {
  final String? childId;
  final String? initialGameId;

  const SkulMateGamesScreen({
    super.key,
    this.childId,
    this.initialGameId,
  });

  @override
  State<SkulMateGamesScreen> createState() => _SkulMateGamesScreenState();
}

class _SkulMateGamesScreenState extends State<SkulMateGamesScreen> {
  List<GameModel> _games = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  String? _selectedFilter;
  bool _showFavoritesOnly = false;
  Set<String> _favoriteGameIds = {};
  bool _swipeHintSeen = true;
  bool _initialGameHandled = false;

  static const String _prefKeySwipeHint = 'skulmate_swipe_delete_hint_seen';

  @override
  void initState() {
    super.initState();
    _loadGames();
    _loadSwipeHintSeen();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSwipeHintSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_prefKeySwipeHint) ?? false;
      if (mounted) safeSetState(() => _swipeHintSeen = seen);
    } catch (_) {}
  }

  Future<void> _dismissSwipeHint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeySwipeHint, true);
    if (mounted) safeSetState(() => _swipeHintSeen = true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadGames({bool refresh = false}) async {
    try {
      if (refresh) {
        _currentPage = 0;
        _hasMore = true;
      }
      final result = await SkulMateService.getGamesPaginated(
        childId: widget.childId,
        limit: _pageSize,
        offset: 0,
      );
      final games = result['games'] as List<GameModel>;
      final hasMore = result['hasMore'] as bool;
      final favoriteIds = <String>{};
      for (final game in games) {
        if (await SkulMateService.isFavorite(game.id)) {
          favoriteIds.add(game.id);
        }
      }
      if (!mounted) return;
      safeSetState(() {
        _games = games;
        _favoriteGameIds = favoriteIds;
        _hasMore = hasMore;
        _currentPage = 0;
        _isLoading = false;
      });
      _openInitialGameIfNeeded();
    } catch (e) {
      if (mounted) {
        safeSetState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserFriendlyMessage(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    safeSetState(() => _isLoadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final result = await SkulMateService.getGamesPaginated(
        childId: widget.childId,
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );
      final newGames = result['games'] as List<GameModel>;
      final hasMore = result['hasMore'] as bool;
      final favoriteIds = Set<String>.from(_favoriteGameIds);
      for (final game in newGames) {
        if (await SkulMateService.isFavorite(game.id)) {
          favoriteIds.add(game.id);
        }
      }
      if (!mounted) return;
      safeSetState(() {
        _games.addAll(newGames);
        _favoriteGameIds = favoriteIds;
        _hasMore = hasMore;
        _currentPage = nextPage;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) safeSetState(() => _isLoadingMore = false);
    }
  }

  void _openInitialGameIfNeeded() {
    if (_initialGameHandled) return;
    final targetId = widget.initialGameId?.trim();
    if (targetId == null || targetId.isEmpty) return;
    final target = _games.where((g) => g.id == targetId).toList();
    if (target.isEmpty) return;
    _initialGameHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SkulMateGameRouter.open(context, target.first);
    });
  }

  List<GameModel> get _filteredGames {
    var filtered = List<GameModel>.from(_games);
    if (_showFavoritesOnly) {
      filtered =
          filtered.where((g) => _favoriteGameIds.contains(g.id)).toList();
    }
    if (_selectedFilter != null) {
      filtered = filtered.where((game) {
        final type = game.gameType.toString();
        if (_selectedFilter == 'fill_blank') return type == 'fillBlank';
        return type == _selectedFilter;
      }).toList();
    }
    return filtered;
  }

  Future<void> _deleteGame(GameModel game) async {
    try {
      await SkulMateService.deleteGame(game.id);
      if (mounted) await _loadGames(refresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getUserFriendlyMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final games = _filteredGames;

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppTheme.softBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          copy.myGames,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadGames(refresh: true),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: _FilterChips(
                        showFavoritesOnly: _showFavoritesOnly,
                        selectedFilter: _selectedFilter,
                        onFavorites: () => safeSetState(
                          () => _showFavoritesOnly = !_showFavoritesOnly,
                        ),
                        onAll: () => safeSetState(() {
                          _showFavoritesOnly = false;
                          _selectedFilter = null;
                        }),
                        onFilter: (value) => safeSetState(() {
                          _selectedFilter =
                              _selectedFilter == value ? null : value;
                        }),
                      ),
                    ),
                  ),
                  if (!_swipeHintSeen && _games.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _SwipeHintBanner(onDismiss: _dismissSwipeHint),
                      ),
                    ),
                  if (games.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyStateWidget(
                        icon: PhosphorIcons.gameController(),
                        title: copy.isFrench ? 'Aucun jeu' : 'No games yet',
                        message: copy.isFrench
                            ? 'Importe des notes depuis l\'accueil SkulMate.'
                            : 'Import notes from the SkulMate home to create games.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: games.length + (_isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index >= games.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          final game = games[index];
                          return Dismissible(
                            key: ValueKey(game.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(
                                        copy.isFrench
                                            ? 'Supprimer ce jeu ?'
                                            : 'Delete this game?',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: Text(copy.isFrench
                                              ? 'Annuler'
                                              : 'Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: Text(
                                            copy.isFrench
                                                ? 'Supprimer'
                                                : 'Delete',
                                            style: const TextStyle(
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                            },
                            onDismissed: (_) => _deleteGame(game),
                            child: GameCard(
                              game: game,
                              onTap: () async {
                                await SkulMateGameRouter.open(context, game);
                                if (mounted) _loadGames(refresh: true);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final bool showFavoritesOnly;
  final String? selectedFilter;
  final VoidCallback onFavorites;
  final VoidCallback onAll;
  final ValueChanged<String> onFilter;

  const _FilterChips({
    required this.showFavoritesOnly,
    required this.selectedFilter,
    required this.onFavorites,
    required this.onAll,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            label: copy.isFrench ? 'Tous' : 'All',
            selected: !showFavoritesOnly && selectedFilter == null,
            onTap: onAll,
          ),
          const SizedBox(width: 8),
          _chip(
            label: copy.isFrench ? 'Favoris' : 'Favorites',
            icon: Icons.favorite_rounded,
            selected: showFavoritesOnly,
            onTap: onFavorites,
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'Quiz',
            selected: selectedFilter == 'quiz',
            onTap: () => onFilter('quiz'),
          ),
          const SizedBox(width: 8),
          _chip(
            label: copy.isFrench ? 'Flashcards' : 'Flashcards',
            selected: selectedFilter == 'flashcards',
            onTap: () => onFilter('flashcards'),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor
                  : AppTheme.softBorder.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : AppTheme.textMedium,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeHintBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const _SwipeHintBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 12),
      child: Row(
        children: [
          const Icon(Icons.swipe_left_rounded, size: 20, color: AppTheme.textMedium),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              copy.isFrench
                  ? 'Glisse à gauche pour supprimer un jeu.'
                  : 'Swipe left on a game to delete it.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
            ),
          ),
          TextButton(
            onPressed: onDismiss,
            child: Text(
              copy.isFrench ? 'OK' : 'Got it',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
