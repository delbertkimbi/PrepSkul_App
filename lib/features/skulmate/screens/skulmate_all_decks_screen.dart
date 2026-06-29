import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

import '../l10n/skulmate_copy.dart';
import '../models/deck_library_entry.dart';
import '../services/deck_library_service.dart';
import '../services/skulmate_service.dart';
import '../utils/deck_navigation.dart';
import '../widgets/deck_add_sheet.dart';
import '../widgets/deck_library_tile.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_typography.dart';

/// Full deck library — My decks + Public decks tabs.
class SkulMateAllDecksScreen extends StatefulWidget {
  final List<DeckLibraryEntry>? initialDecks;
  final String? childId;
  final Future<void> Function()? onAfterDeckOpen;

  const SkulMateAllDecksScreen({
    super.key,
    this.initialDecks,
    this.childId,
    this.onAfterDeckOpen,
  });

  @override
  State<SkulMateAllDecksScreen> createState() => _SkulMateAllDecksScreenState();
}

class _SkulMateAllDecksScreenState extends State<SkulMateAllDecksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<DeckLibraryEntry> _myDecks = [];
  bool _loading = true;
  String _query = '';
  bool _searchOpen = false;
  final _searchFocus = FocusNode();
  final _searchController = TextEditingController();

  bool get _showPublicTab => DeckLibraryService.publicDecksEnabled;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _showPublicTab ? 2 : 1, vsync: this);
    _tabs.addListener(() => safeSetState(() {}));
    _myDecks = widget.initialDecks ?? [];
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    safeSetState(() => _loading = true);
    try {
      final games = await SkulMateService.getGames(childId: widget.childId);
      final my = await DeckLibraryService.listDecks(
        childId: widget.childId,
        games: games,
      );
      if (!mounted) return;
      safeSetState(() {
        _myDecks = my;
        _loading = false;
      });
    } catch (_) {
      if (mounted) safeSetState(() => _loading = false);
    }
  }

  List<DeckLibraryEntry> _filter(List<DeckLibraryEntry> decks) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return decks;
    return decks
        .where(
          (d) =>
              d.title.toLowerCase().contains(q) ||
              d.topicLabel.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _openDeck(DeckLibraryEntry entry) async {
    await DeckNavigation.openDeckHub(
      context: context,
      entry: entry,
      childId: widget.childId,
    );
    await widget.onAfterDeckOpen?.call();
    await _load();
  }

  void _toggleSearch() {
    safeSetState(() {
      _searchOpen = !_searchOpen;
      if (_searchOpen) {
        _searchFocus.requestFocus();
      } else {
        _query = '';
        _searchController.clear();
        _searchFocus.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final onMyDecksTab = !_showPublicTab || _tabs.index == 0;

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: SkulMateGameAppBar(
        light: true,
        title: copy.allDecksTitle,
        centerTitle: true,
        actions: onMyDecksTab
            ? [
                IconButton(
                  icon: Icon(
                    _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                    size: 22,
                  ),
                  onPressed: _toggleSearch,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showPublicTab)
              TabBar(
                controller: _tabs,
                labelStyle: SkulMateTypography.tabLabel(selected: true),
                unselectedLabelStyle:
                    SkulMateTypography.tabLabel(selected: false),
                indicatorColor: AppTheme.textDark,
                indicatorWeight: 3,
                labelColor: AppTheme.textDark,
                unselectedLabelColor: AppTheme.textMedium,
                tabs: [
                  Tab(text: copy.myDecks),
                  Tab(text: copy.publicDecks),
                ],
              ),
            if (_searchOpen && onMyDecksTab)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: (value) => safeSetState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: copy.searchDecksHint,
                    hintStyle: SkulMateTypography.body(color: AppTheme.textMedium),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.neutral200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.neutral200),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _showPublicTab
                      ? TabBarView(
                          controller: _tabs,
                          children: [
                            _DeckList(
                              decks: _filter(_myDecks),
                              emptyText: copy.emptyDecksHint,
                              onOpen: _openDeck,
                            ),
                            _PublicDecksComingSoon(copy: copy),
                          ],
                        )
                      : _DeckList(
                          decks: _filter(_myDecks),
                          emptyText: copy.emptyDecksHint,
                          onOpen: _openDeck,
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => DeckAddSheet.show(context, childId: widget.childId),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

class _PublicDecksComingSoon extends StatelessWidget {
  final SkulMateCopy copy;

  const _PublicDecksComingSoon({required this.copy});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.public_rounded,
              size: 48,
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              copy.publicDecksComingSoonTitle,
              textAlign: TextAlign.center,
              style: SkulMateTypography.screenTitle(),
            ),
            const SizedBox(height: 10),
            Text(
              copy.publicDecksComingSoonBody,
              textAlign: TextAlign.center,
              style: SkulMateTypography.body(color: AppTheme.textMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckList extends StatelessWidget {
  final List<DeckLibraryEntry> decks;
  final String emptyText;
  final Future<void> Function(DeckLibraryEntry) onOpen;

  const _DeckList({
    required this.decks,
    required this.emptyText,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (decks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: SkulMateTypography.body(color: AppTheme.textMedium),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: decks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final deck = decks[index];
        return DeckLibraryTile(
          entry: deck,
          onTap: () => onOpen(deck),
        );
      },
    );
  }
}
