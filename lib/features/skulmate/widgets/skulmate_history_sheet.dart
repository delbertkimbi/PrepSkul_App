import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../services/skulmate_service.dart';
import '../utils/game_type_visuals.dart';
import '../utils/skulmate_game_router.dart';
import 'skulmate_sheet_scaffold.dart';

/// Gizmo-style game / chat history bottom sheet with search.
class SkulMateHistorySheet extends StatefulWidget {
  final String? childId;

  const SkulMateHistorySheet({super.key, this.childId});

  static Future<void> show(BuildContext context, {String? childId}) {
    return SkulMateSheetScaffold.show<void>(
      context,
      child: SkulMateHistorySheet(childId: childId),
    );
  }

  @override
  State<SkulMateHistorySheet> createState() => _SkulMateHistorySheetState();
}

class _SkulMateHistorySheetState extends State<SkulMateHistorySheet> {
  final _searchController = TextEditingController();
  List<GameModel> _games = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final games = await SkulMateService.getGames(childId: widget.childId);
      if (mounted) {
        setState(() {
          _games = games;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<GameModel> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _games;
    return _games
        .where((g) => g.title.toLowerCase().contains(q))
        .toList();
  }

  String _subtitle(GameModel game) {
    return '${GameTypeVisuals.labelFor(game.gameType)} · ${game.items.length} items';
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final items = _filtered;

    return SkulMateSheetScaffold(
      title: copy.history,
      showWandIcon: false,
      maxHeightFactor: 0.82,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: copy.searchHint,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppTheme.textMedium.withValues(alpha: 0.7),
                ),
                filled: true,
                fillColor: AppTheme.softBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: AppTheme.softBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            copy.historyEmpty,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: AppTheme.textMedium,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final game = items[index];
                          final accent =
                              GameTypeVisuals.accentColorFor(game.gameType);
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                if (!context.mounted) return;
                                SkulMateGameRouter.open(context, game);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            accent.withValues(alpha: 0.18),
                                            accent.withValues(alpha: 0.08),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        GameTypeVisuals.iconFor(game.gameType),
                                        color: accent,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            game.title,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: AppTheme.textDark,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            _subtitle(game),
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: AppTheme.textMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
