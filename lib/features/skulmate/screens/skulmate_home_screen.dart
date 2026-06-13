import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';
import '../widgets/skulmate_continue_row.dart';
import '../widgets/skulmate_hero_mascot.dart';
import '../widgets/skulmate_home_games_row.dart';
import '../widgets/skulmate_home_top_bar.dart';
import '../widgets/skulmate_import_action_grid.dart';
import '../widgets/skulmate_study_intent_card.dart';
import '../widgets/skulmate_surface_styles.dart';
import 'game_library_screen.dart';

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
  bool _loadingGames = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyStatusBarStyle();
    _loadGames();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _topicController.dispose();
    super.dispose();
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

  Future<void> _loadGames() async {
    try {
      final games = await SkulMateService.getGames(childId: widget.childId);
      if (mounted) {
        safeSetState(() {
          _games = games;
          _loadingGames = false;
        });
      }
    } catch (_) {
      if (mounted) safeSetState(() => _loadingGames = false);
    }
  }

  void _openLibrary({int initialTab = 1}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameLibraryScreen(
          childId: widget.childId,
          initialTab: initialTab,
        ),
      ),
    ).then((_) {
      if (mounted) _applyStatusBarStyle();
    });
  }

  Future<void> _submitTopic() async {
    await submitTypedTopic(
      context,
      _topicController.text,
      childId: widget.childId,
    );
    _topicController.clear();
    await _loadGames();
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
              onRefresh: _loadGames,
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
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                              height: 1.2,
                              letterSpacing: -0.45,
                            ),
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
                      child: SkulMateContinueRow(
                        games: _games,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        SkulMateSurfaceStyles.sectionGap,
                        20,
                        32,
                      ),
                      child: SkulMateHomeGamesRow(
                        games: _games,
                        loading: _loadingGames,
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
