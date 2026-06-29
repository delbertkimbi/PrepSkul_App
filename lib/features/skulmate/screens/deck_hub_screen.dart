import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../models/revision_deck_model.dart';
import '../services/deck_mastery_service.dart';
import '../services/deck_study_progress_service.dart';
import '../services/revision_deck_service.dart';
import '../services/skulmate_study_audio_service.dart';
import '../services/skulmate_service.dart';
import '../utils/deck_navigation.dart';
import '../utils/game_type_visuals.dart';
import '../utils/skulmate_game_router.dart';
import '../widgets/deck_add_content_sheet.dart';
import '../widgets/deck_mastery_banner.dart';
import '../widgets/deck_study_launcher_sheet.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_game_surface.dart';
import '../widgets/skulmate_study_audio_controls.dart';
import '../widgets/skulmate_surface_styles.dart';
import '../widgets/gizmo_deck_card.dart';
import '../widgets/skulmate_typography.dart';
import 'deck_tutor_session_screen.dart';

enum DeckHubTab { cards, notes, lessons, imports, leaderboard }

/// Gizmo-style deck hub — subject/course with cards, notes, games, imports.
class DeckHubScreen extends StatefulWidget {
  final RevisionDeckModel deck;
  final GameModel game;
  final String? childId;
  final bool openAsScrollFeed;
  final bool libraryMode;

  const DeckHubScreen({
    super.key,
    required this.deck,
    required this.game,
    this.childId,
    this.openAsScrollFeed = false,
    this.libraryMode = false,
  });

  @override
  State<DeckHubScreen> createState() => _DeckHubScreenState();
}

class _DeckHubScreenState extends State<DeckHubScreen> {
  DeckHubTab _tab = DeckHubTab.cards;
  late RevisionDeckModel _deck;
  bool _isGeneratingMore = false;
  DeckMasterySnapshot _mastery = DeckMasterySnapshot.empty;
  bool _masteryLoading = true;
  final _tabScroll = ScrollController();

  Color get _accent {
    final argb = _deck.accentColorArgb;
    if (argb != null) return Color(argb);
    return DeckLibraryServiceAccent.accentForTitle(_deck.title);
  }

  @override
  void initState() {
    super.initState();
    _deck = widget.deck;
    _refreshDeckFromApi();
    _loadMastery();
    SkulMateStudyAudioService.instance.acquireStudyAmbience(
      SkulMateStudyAudioOwner.deckHub,
    );
  }

  @override
  void dispose() {
    _tabScroll.dispose();
    SkulMateStudyAudioService.instance.releaseStudyAmbience(
      SkulMateStudyAudioOwner.deckHub,
    );
    super.dispose();
  }

  Future<void> _loadMastery() async {
    if (widget.game.id.isEmpty) {
      if (!mounted) return;
      setState(() => _masteryLoading = false);
      return;
    }
    setState(() => _masteryLoading = true);
    final snapshot = await DeckMasteryService.forGame(
      gameId: widget.game.id,
      childId: widget.childId,
      generationContext: widget.game.metadata.topic != null
          ? {'topic': widget.game.metadata.topic}
          : null,
    );
    if (!mounted) return;
    setState(() {
      _mastery = snapshot;
      _masteryLoading = false;
    });
  }

  Future<void> _refreshDeckFromApi() async {
    if (widget.game.id.isEmpty) return;
    final refreshed = await RevisionDeckService.refreshFromApi(widget.game.id);
    if (!mounted || refreshed == null) return;
    setState(() => _deck = refreshed);
    await _loadMastery();
  }

  Future<void> _onTabChanged(DeckHubTab tab) async {
    setState(() => _tab = tab);
    if (tab == DeckHubTab.notes) {
      await DeckStudyProgressService.markNotesViewed(_deck.deckKey);
    }
  }

  Future<void> _onCardRevealed() async {
    await DeckStudyProgressService.recordCardRevealed(_deck.deckKey);
  }

  Future<void> _generateMoreCards() async {
    if (_isGeneratingMore) return;
    setState(() => _isGeneratingMore = true);
    try {
      final result = await SkulMateService.appendDeckCards(
        gameId: widget.game.id,
        count: 6,
        childId: widget.childId,
      );
      if (!mounted) return;
      setState(() => _deck = result.deck);
      RevisionDeckService.cacheDeck(result.deck);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.addedCount > 0
                ? 'Added ${result.addedCount} new cards to your deck.'
                : 'Your deck is up to date.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingMore = false);
    }
  }

  Future<void> _openTutor({int cardIndex = 0}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeckTutorSessionScreen(
          deck: _deck,
          gameId: widget.game.id,
          childId: widget.childId,
          initialCardIndex: cardIndex,
        ),
      ),
    );
    await _loadMastery();
  }

  Future<void> _launchStudy() async {
    final initialMode = widget.openAsScrollFeed
        ? DeckStudyMode.scroll
        : defaultStudyModeForGame(widget.game);
    final selection = await showDeckStudyLauncherSheet(
      context: context,
      deck: _deck,
      initialMode: initialMode,
    );
    if (!mounted || selection == null) return;

    if (!widget.libraryMode) {
      Navigator.pop(context, selection);
      return;
    }

    if (selection.tutor) {
      await _openTutor();
      return;
    }

    final mode = selection.studyMode;
    if (mode == null) return;

    await DeckNavigation.playStudyModeFromHub(
      context: context,
      game: widget.game,
      deck: _deck,
      studyMode: mode,
      childId: widget.childId,
      openAsScrollFeed: widget.openAsScrollFeed,
    );
    if (mounted) await _loadMastery();
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final deck = _deck;

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: SkulMateGameAppBar(
        light: true,
        title: '',
        actions: const [SkulMateStudyAudioControls()],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton(
          onPressed: () => showDeckAddContentSheet(
            context: context,
            deckTitle: deck.title,
            childId: widget.childId,
          ),
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      deck.title,
                      style: SkulMateTypography.screenTitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                controller: _tabScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _HubTab(
                    label: 'Cards',
                    selected: _tab == DeckHubTab.cards,
                    onTap: () => _onTabChanged(DeckHubTab.cards),
                  ),
                  _HubTab(
                    label: 'Notes',
                    selected: _tab == DeckHubTab.notes,
                    onTap: () => _onTabChanged(DeckHubTab.notes),
                  ),
                  _HubTab(
                    label: 'Lessons',
                    selected: _tab == DeckHubTab.lessons,
                    onTap: () => _onTabChanged(DeckHubTab.lessons),
                  ),
                  _HubTab(
                    label: 'Imports',
                    selected: _tab == DeckHubTab.imports,
                    onTap: () => _onTabChanged(DeckHubTab.imports),
                  ),
                  _HubTab(
                    label: 'Leaderboard',
                    selected: _tab == DeckHubTab.leaderboard,
                    onTap: () => _onTabChanged(DeckHubTab.leaderboard),
                  ),
                ],
              ),
            ),
            if (_tab == DeckHubTab.cards)
              DeckMasteryBanner(snapshot: _mastery, loading: _masteryLoading),
            Expanded(
              child: switch (_tab) {
                DeckHubTab.cards => _CardsTab(
                    deck: deck,
                    childId: widget.childId,
                    onCardRevealed: _onCardRevealed,
                    onGenerateMore: _generateMoreCards,
                    isGeneratingMore: _isGeneratingMore,
                  ),
                DeckHubTab.notes => _NotesTab(deck: deck),
                DeckHubTab.lessons => _LessonsTab(
                    game: widget.game,
                    deck: deck,
                    childId: widget.childId,
                  ),
                DeckHubTab.imports => _ImportsTab(
                    game: widget.game,
                    deck: deck,
                    childId: widget.childId,
                  ),
                DeckHubTab.leaderboard => _LeaderboardTab(
                    deck: deck,
                    mastery: _mastery,
                  ),
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                onPressed: _launchStudy,
                icon: const Icon(Icons.sports_esports_rounded, color: Colors.white),
                label: Text(
                  copy.studyDeck,
                  style: SkulMateTypography.cardTitle(
                    color: Colors.white,
                    size: 15,
                  ),
                ),
                style: SkulMateSurfaceStyles.deckPrimaryButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Local accent helper to avoid circular import with deck_library_service.
class DeckLibraryServiceAccent {
  static Color accentForTitle(String title) {
    const palette = [
      AppTheme.skyBlue,
      AppTheme.accentGreen,
      Color(0xFF14B8A6),
      AppTheme.accentPurple,
      AppTheme.accentOrange,
      AppTheme.accentPink,
      AppTheme.primaryLight,
    ];
    var hash = 0;
    for (final unit in title.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }
}

class _HubTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HubTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              label,
              style: SkulMateTypography.tabLabel(selected: selected),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              width: selected ? 28 : 0,
              decoration: BoxDecoration(
                color: AppTheme.textDark,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardsTab extends StatelessWidget {
  final RevisionDeckModel deck;
  final Future<void> Function() onCardRevealed;
  final Future<void> Function() onGenerateMore;
  final bool isGeneratingMore;
  final String? childId;

  const _CardsTab({
    required this.deck,
    required this.onCardRevealed,
    required this.onGenerateMore,
    required this.isGeneratingMore,
    this.childId,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    if (deck.cards.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        children: [
          Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.skyBlueLight.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bubble_chart_rounded,
                  size: 44,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                copy.noCardsYet,
                style: SkulMateTypography.screenTitle(),
              ),
              const SizedBox(height: 6),
              Text(
                copy.noCardsSubtitle,
                textAlign: TextAlign.center,
                style: SkulMateTypography.body(color: AppTheme.textMedium),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => showDeckAddContentSheet(
                  context: context,
                  deckTitle: deck.title,
                  childId: childId,
                ),
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: Text(copy.magicImport),
                style: SkulMateSurfaceStyles.deckAccentButton(),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showDeckAddContentSheet(
                  context: context,
                  deckTitle: deck.title,
                  childId: childId,
                ),
                icon: const Icon(Icons.edit_rounded),
                label: Text(copy.writeCards),
                style: SkulMateSurfaceStyles.deckOutlineButton(minHeight: 50),
              ),
            ],
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        Row(
          children: [
            Text(
              'Cards (${deck.cards.length})',
              style: SkulMateTypography.cardTitle(size: 15),
            ),
            const Spacer(),
            Icon(Icons.swap_vert_rounded, size: 18, color: AppTheme.textMedium),
          ],
        ),
        const SizedBox(height: 10),
        ...deck.cards.map(
          (card) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GizmoDeckCard(
              card: card,
              onRevealed: onCardRevealed,
            ),
          ),
        ),
        _GenerateMorePanel(
          isGenerating: isGeneratingMore,
          onGenerate: onGenerateMore,
        ),
      ],
    );
  }
}

class _GenerateMorePanel extends StatelessWidget {
  final bool isGenerating;
  final Future<void> Function() onGenerate;

  const _GenerateMorePanel({
    required this.isGenerating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: SkulMateSurfaceStyles.deckInfoPanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Not covered everything?',
            style: SkulMateTypography.cardTitle(size: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep going to get even more cards from your source.',
            style: SkulMateTypography.cardMeta(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: isGenerating ? null : onGenerate,
            icon: isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(
              isGenerating ? 'Generating cards…' : 'Generate more cards',
              style: SkulMateTypography.linkAction(color: AppTheme.textDark),
            ),
            style: SkulMateSurfaceStyles.deckOutlineButton(),
          ),
        ],
      ),
    );
  }
}

class _NotesTab extends StatelessWidget {
  final RevisionDeckModel deck;

  const _NotesTab({required this.deck});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        GameFlatPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(deck.topicLabel, style: SkulMateTypography.screenTitle()),
              const SizedBox(height: 10),
              Text(
                deck.notes.isNotEmpty
                    ? deck.notes
                    : 'Add notes from the + button or import material.',
                style: SkulMateTypography.body(color: AppTheme.textMedium),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LessonsTab extends StatelessWidget {
  final GameModel game;
  final RevisionDeckModel deck;
  final String? childId;

  const _LessonsTab({
    required this.game,
    required this.deck,
    this.childId,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final accent = GameTypeVisuals.accentColorFor(game.gameType);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(SkulMateSurfaceStyles.deckRadius),
            onTap: () => SkulMateGameRouter.open(
              context,
              game,
              skipBriefing: true,
              childId: childId,
            ),
            child: Ink(
              decoration: SkulMateSurfaceStyles.homeCard(),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: 0.08,
                            strokeWidth: 4,
                            color: accent,
                            backgroundColor: AppTheme.neutral100,
                          ),
                          Text('0%', style: SkulMateTypography.cardTitle(size: 10)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(copy.deckLesson, style: SkulMateTypography.cardMeta()),
                          Text(game.title, style: SkulMateTypography.cardTitle(size: 15)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppTheme.textMedium),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImportsTab extends StatelessWidget {
  final GameModel game;
  final RevisionDeckModel deck;
  final String? childId;

  const _ImportsTab({
    required this.game,
    required this.deck,
    this.childId,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final sourceLabel = _sourceLabel(game, deck);
    final isEmpty = deck.cards.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        if (isEmpty) ...[
          Text(
            copy.magicImport,
            style: SkulMateTypography.cardTitle(size: 16),
          ),
          const SizedBox(height: 4),
          Text(
            copy.magicImportSubtitle,
            style: SkulMateTypography.cardMeta(),
          ),
          const SizedBox(height: 14),
        ],
        OutlinedButton.icon(
          onPressed: () => showDeckAddContentSheet(
            context: context,
            deckTitle: deck.title,
            childId: childId,
          ),
          icon: const Icon(Icons.auto_fix_high_rounded),
          label: Text(copy.magicImport, style: SkulMateTypography.cardTitle(size: 14)),
          style: SkulMateSurfaceStyles.deckOutlineButton(minHeight: 52),
        ),
        if (!isEmpty) const SizedBox(height: 12),
        if (!isEmpty && sourceLabel != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: SkulMateSurfaceStyles.homeCard(),
            child: Row(
              children: [
                Icon(_sourceIcon(game.sourceType), color: AppTheme.skyBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sourceLabel,
                        style: SkulMateTypography.cardTitle(size: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatDate(game.createdAt),
                        style: SkulMateTypography.cardMeta(),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppTheme.textMedium),
              ],
            ),
          ),
      ],
    );
  }

  String? _sourceLabel(GameModel game, RevisionDeckModel deck) {
    if ((game.sourceFileName ?? '').isNotEmpty) return game.sourceFileName;
    if (game.title.isNotEmpty) return game.title;
    if (deck.sourceType.isNotEmpty) return deck.sourceType;
    return null;
  }

  IconData _sourceIcon(String? sourceType) {
    switch ((sourceType ?? '').toLowerCase()) {
      case 'youtube':
        return Icons.play_circle_filled_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'photo':
        return Icons.photo_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}

class _LeaderboardTab extends StatelessWidget {
  final RevisionDeckModel deck;
  final DeckMasterySnapshot mastery;

  const _LeaderboardTab({
    required this.deck,
    required this.mastery,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final xp = ((mastery.masteryPercent ?? 0) * 0.6).round().clamp(0, 999);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: SkulMateSurfaceStyles.homeCard(),
          child: Row(
            children: [
              const Text('🥇', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Text('You', style: SkulMateTypography.cardTitle(size: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$xp XP',
                  style: SkulMateTypography.cardTitle(
                    size: 12,
                    color: AppTheme.accentGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.skyBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.travel_explore_rounded, color: AppTheme.skyBlue),
              ),
              const SizedBox(height: 16),
              Text(
                copy.leaderboardSharePrompt,
                style: SkulMateTypography.cardTitle(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                copy.leaderboardShareBody,
                style: SkulMateTypography.cardMeta(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(copy.shareDeck),
                style: SkulMateSurfaceStyles.deckOutlineButton(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
