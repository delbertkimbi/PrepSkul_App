import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/deck_library_entry.dart';
import '../screens/skulmate_all_decks_screen.dart';
import '../utils/deck_navigation.dart';
import 'deck_add_sheet.dart';
import 'deck_library_tile.dart';
import 'skulmate_home_section_header.dart';
import 'skulmate_loading_skeletons.dart';
import 'skulmate_surface_styles.dart';

/// Saved decks on home — Gizmo-style: header +, 2 recent tiles, View all pill.
class SkulMateHomeDecksRow extends StatelessWidget {
  final List<DeckLibraryEntry> decks;
  final bool loading;
  final String? childId;
  final Future<void> Function()? onAfterDeckOpen;

  const SkulMateHomeDecksRow({
    super.key,
    required this.decks,
    this.loading = false,
    this.childId,
    this.onAfterDeckOpen,
  });

  Future<void> _openDeck(BuildContext context, DeckLibraryEntry entry) async {
    await DeckNavigation.openDeckHub(
      context: context,
      entry: entry,
      childId: childId,
    );
    await onAfterDeckOpen?.call();
  }

  Future<void> _openAllDecks(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SkulMateAllDecksScreen(
          initialDecks: decks,
          childId: childId,
          onAfterDeckOpen: onAfterDeckOpen,
        ),
      ),
    );
    await onAfterDeckOpen?.call();
  }

  void _openAddSheet(BuildContext context) {
    DeckAddSheet.show(context, childId: childId);
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    if (!loading && decks.isEmpty) {
      return const SizedBox.shrink();
    }
    final visible = decks.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkulMateHomeSectionHeader(
          title: copy.myDecks,
          onAdd: loading ? null : () => _openAddSheet(context),
        ),
        const SizedBox(height: 8),
        if (loading)
          Column(
            children: List.generate(
              2,
              (i) => Padding(
                padding: EdgeInsets.only(bottom: i == 0 ? 10 : 0),
                child: SkulMateLoadingSkeletons.homeDeckTile(),
              ),
            ),
          )
        else
          ...visible.map(
            (deck) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DeckLibraryTile(
                entry: deck,
                showMenu: true,
                onTap: () => _openDeck(context, deck),
              ),
            ),
          ),
        if (!loading && decks.isNotEmpty) ...[
          const SizedBox(height: 2),
          OutlinedButton(
            onPressed: () => _openAllDecks(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textDark,
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: AppTheme.neutral200),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  SkulMateSurfaceStyles.pillRadius,
                ),
              ),
            ),
            child: Text(
              copy.viewAll,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
