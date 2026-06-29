import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_models.dart';
import '../models/deck_library_entry.dart';
import '../models/game_model.dart';
import '../services/deck_library_service.dart';
import '../services/game_sound_service.dart';
import '../services/skulmate_intake_coordinator.dart';
import '../services/skulmate_service.dart';
import '../services/skulmate_streak_reminder_service.dart';
import '../services/skulmate_home_refresh_bus.dart';
import '../services/skulmate_pricing_service.dart';
import '../widgets/skulmate_hero_mascot.dart';
import '../widgets/skulmate_home_decks_row.dart';
import '../widgets/skulmate_home_games_row.dart';
import '../widgets/skulmate_home_top_bar.dart';
import '../widgets/skulmate_import_action_grid.dart';
import '../widgets/skulmate_next_stop_card.dart';
import '../widgets/skulmate_reroute_nudge.dart';
import '../widgets/skulmate_study_intent_card.dart';
import '../widgets/skulmate_surface_styles.dart';
import '../widgets/skulmate_typography.dart';

/// SkulMate tab landing — Gizmo structure, PrepSkul identity (single scroll).
class SkulMateHomeScreen extends StatefulWidget {
  final String? childId;

  const SkulMateHomeScreen({super.key, this.childId});

  @override
  State<SkulMateHomeScreen> createState() => _SkulMateHomeScreenState();
}

class _SkulMateHomeScreenState extends State<SkulMateHomeScreen>
    with WidgetsBindingObserver {
  final _topicController = TextEditingController();
  List<GameModel> _games = [];
  List<DeckLibraryEntry> _decks = [];
  bool _loadingGames = true;
  bool _loadingDecks = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SkulMateHomeRefreshBus.tick.addListener(_onLibraryRefresh);
    _applyStatusBarStyle();
    unawaited(GameSoundService().stopMusic(force: true));
    unawaited(SkulmatePricingService.resolveMaxImagesPerPrompt());
    _loadGames();
    _loadDecks();
    SkulMateStreakReminderService.recordActivityAndReschedule();
  }

  @override
  void dispose() {
    SkulMateHomeRefreshBus.tick.removeListener(_onLibraryRefresh);
    WidgetsBinding.instance.removeObserver(this);
    _topicController.dispose();
    super.dispose();
  }

  void _onLibraryRefresh() {
    if (!mounted) return;
    unawaited(_refreshHome());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyStatusBarStyle();
    }
  }

  void _applyStatusBarStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      SkulMateSurfaceStyles.lightStatusBarOverlay,
    );
  }

  Future<void> _loadDecks() async {
    try {
      final decks = await DeckLibraryService.listDecks(
        childId: widget.childId,
        games: _games.isNotEmpty ? _games : null,
      );
      if (mounted) {
        safeSetState(() {
          _decks = decks;
          _loadingDecks = false;
        });
      }
    } catch (_) {
      if (mounted) safeSetState(() => _loadingDecks = false);
    }
  }

  Future<void> _refreshHome() async {
    await _loadGames();
    await _loadDecks();
  }

  Future<void> _loadGames() async {
    try {
      final cached =
          await SkulMateService.getCachedGames(childId: widget.childId);
      if (mounted && cached.isNotEmpty) {
        safeSetState(() {
          _games = cached;
          _loadingGames = false;
        });
      }
    } catch (_) {
      if (mounted) safeSetState(() => _loadingGames = false);
    }

    try {
      final games = await SkulMateService.getGames(childId: widget.childId);
      if (mounted) {
        safeSetState(() {
          _games = games;
          _loadingGames = false;
        });
        unawaited(_loadDecks());
      }
    } catch (_) {
      if (mounted) {
        safeSetState(() => _loadingGames = false);
      }
    }
  }

  Future<void> _submitTopic() async {
    final trimmed = _topicController.text.trim();
    if (trimmed.isEmpty) return;
    await SkulMateIntakeCoordinator.start(
      context,
      SkulMateIntakePayload(
        source: SkulMateIntakeSource.typedTopic,
        topicHint: trimmed,
        childId: widget.childId,
      ),
    );
    _topicController.clear();
    await _refreshHome();
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SkulMateSurfaceStyles.lightStatusBarOverlay,
      child: Scaffold(
        backgroundColor: AppTheme.softBackground,
        body: ColoredBox(
          color: AppTheme.softBackground,
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _refreshHome,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SkulMateHomeTopBar(childId: widget.childId),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Column(
                        children: [
                          const SkulMateHeroMascot(),
                          const SizedBox(height: 8),
                          Text(
                            copy.heroQuestion,
                            textAlign: TextAlign.center,
                            style: SkulMateTypography.heroTitle(),
                          ),
                          const SizedBox(height: 18),
                          SkulMateStudyIntentCard(
                            controller: _topicController,
                            onSubmit: _submitTopic,
                            childId: widget.childId,
                          ),
                          const SizedBox(height: 10),
                          SkulMateImportActionGrid(childId: widget.childId),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        SkulMateSurfaceStyles.sectionGap,
                        20,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SkulMateNextStopCard(
                            games: _games,
                            childId: widget.childId,
                          ),
                          SkulMateRerouteNudge(
                            games: _games,
                            childId: widget.childId,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!_loadingGames && _games.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          SkulMateSurfaceStyles.sectionGap,
                          20,
                          SkulMateSurfaceStyles.homeSectionSpacing,
                        ),
                        child: SkulMateHomeGamesRow(
                          games: _games,
                          loading: _loadingGames,
                          childId: widget.childId,
                          onAfterGameOpen: _refreshHome,
                        ),
                      ),
                    ),
                  if (!_loadingDecks && _decks.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        child: SkulMateHomeDecksRow(
                          decks: _decks,
                          loading: _loadingDecks,
                          childId: widget.childId,
                          onAfterDeckOpen: _refreshHome,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
