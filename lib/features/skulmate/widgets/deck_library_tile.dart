import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../models/deck_library_entry.dart';
import '../services/deck_study_progress_service.dart';
import 'skulmate_surface_styles.dart';
import 'skulmate_typography.dart';

/// Gizmo-style deck row — accent bar, curved card, progress ring.
class DeckLibraryTile extends StatelessWidget {
  final DeckLibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onMenuStudy;
  final bool showMenu;

  const DeckLibraryTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onMenuStudy,
    this.showMenu = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DeckStudyProgress>(
      future: DeckStudyProgressService.load(entry.deck.deckKey),
      builder: (context, snapshot) {
        final progress = snapshot.data ?? const DeckStudyProgress();
        final percent = DeckStudyProgressService.percentForDeck(
          progress: progress,
          totalCards: entry.cardCount,
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(SkulMateSurfaceStyles.deckRadius),
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    entry.accentColor.withValues(alpha: 0.1),
                    Colors.white,
                    Colors.white,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius:
                    BorderRadius.circular(SkulMateSurfaceStyles.deckRadius),
                border: Border.all(
                  color: entry.accentColor.withValues(alpha: 0.22),
                ),
                boxShadow: SkulMateSurfaceStyles.homeCardShadow(compact: true),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 44,
                      decoration: BoxDecoration(
                        color: entry.accentColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: SkulMateTypography.gameCardTitle(size: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${entry.cardCount} cards',
                            style: SkulMateTypography.gameCardMeta(),
                          ),
                        ],
                      ),
                    ),
                    _ProgressBadge(percent: percent, accent: entry.accentColor),
                    if (onMenuStudy != null)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: AppTheme.textMedium,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'study') onMenuStudy?.call();
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'study',
                            child: Text('Open deck'),
                          ),
                        ],
                      )
                    else if (showMenu)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: AppTheme.textMedium.withValues(alpha: 0.55),
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  final int percent;
  final Color accent;

  const _ProgressBadge({required this.percent, required this.accent});

  @override
  Widget build(BuildContext context) {
    final value = (percent.clamp(0, 100)) / 100;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value > 0 ? value : null,
            strokeWidth: 4,
            backgroundColor: AppTheme.neutral100,
            color: accent,
          ),
          Text(
            '$percent%',
            style: SkulMateTypography.cardTitle(size: 10),
          ),
        ],
      ),
    );
  }
}
