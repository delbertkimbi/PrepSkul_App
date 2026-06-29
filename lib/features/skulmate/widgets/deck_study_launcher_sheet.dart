import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../models/game_model.dart';
import '../models/revision_deck_model.dart';
import '../widgets/skulmate_surface_styles.dart';
import '../widgets/skulmate_typography.dart';

enum DeckStudyMode {
  memorise,
  quiz,
  matching,
  fillBlank,
  scroll,
}

extension DeckStudyModeX on DeckStudyMode {
  String get label {
    switch (this) {
      case DeckStudyMode.memorise:
        return 'Memorise';
      case DeckStudyMode.quiz:
        return 'Quiz';
      case DeckStudyMode.matching:
        return 'Match It';
      case DeckStudyMode.fillBlank:
        return 'Fill blanks';
      case DeckStudyMode.scroll:
        return 'Scroll feed';
    }
  }

  String get subtitle {
    switch (this) {
      case DeckStudyMode.memorise:
        return 'Active recall quizzes';
      case DeckStudyMode.quiz:
        return 'Multiple-choice practice';
      case DeckStudyMode.matching:
        return 'Connect terms and meanings';
      case DeckStudyMode.fillBlank:
        return 'Complete the sentence';
      case DeckStudyMode.scroll:
        return 'Swipe through your deck';
    }
  }

  IconData get icon {
    switch (this) {
      case DeckStudyMode.memorise:
        return Icons.style_rounded;
      case DeckStudyMode.quiz:
        return Icons.quiz_rounded;
      case DeckStudyMode.matching:
        return Icons.join_inner_rounded;
      case DeckStudyMode.fillBlank:
        return Icons.edit_note_rounded;
      case DeckStudyMode.scroll:
        return Icons.view_agenda_rounded;
    }
  }

  String? get apiGameType {
    switch (this) {
      case DeckStudyMode.memorise:
        return 'flashcards';
      case DeckStudyMode.quiz:
        return 'quiz';
      case DeckStudyMode.matching:
        return 'matching';
      case DeckStudyMode.fillBlank:
        return 'fill_blank';
      case DeckStudyMode.scroll:
        return 'scroll';
    }
  }
}

DeckStudyMode defaultStudyModeForGame(GameModel game) {
  switch (game.gameType) {
    case GameType.matching:
      return DeckStudyMode.matching;
    case GameType.fillBlank:
      return DeckStudyMode.fillBlank;
    case GameType.flashcards:
      return DeckStudyMode.memorise;
    default:
      return DeckStudyMode.quiz;
  }
}

List<DeckStudyMode> availableStudyModesForDeck(RevisionDeckModel deck) {
  if (deck.cards.length < 2) {
    return const [
      DeckStudyMode.memorise,
      DeckStudyMode.scroll,
    ];
  }

  return const [
    DeckStudyMode.memorise,
    DeckStudyMode.quiz,
    DeckStudyMode.matching,
    DeckStudyMode.fillBlank,
    DeckStudyMode.scroll,
  ];
}

Color _modeAccent(DeckStudyMode mode) {
  switch (mode) {
    case DeckStudyMode.memorise:
      return AppTheme.accentGreen;
    case DeckStudyMode.quiz:
      return AppTheme.accentPurple;
    case DeckStudyMode.matching:
      return AppTheme.skyBlue;
    case DeckStudyMode.fillBlank:
      return AppTheme.accentOrange;
    case DeckStudyMode.scroll:
      return AppTheme.accentPink;
  }
}

/// Result from the study launcher — AI tutor or a playable study mode.
class DeckLaunchSelection {
  final bool tutor;
  final DeckStudyMode? studyMode;

  const DeckLaunchSelection.tutor() : tutor = true, studyMode = null;

  const DeckLaunchSelection.play(this.studyMode) : tutor = false;

  DeckStudyMode? get playMode => tutor ? null : studyMode;
}

enum _LauncherPick { tutor, play }

Future<DeckLaunchSelection?> showDeckStudyLauncherSheet({
  required BuildContext context,
  required RevisionDeckModel deck,
  DeckStudyMode? initialMode,
}) {
  final modes = availableStudyModesForDeck(deck);
  var pick = _LauncherPick.tutor;
  var selected = initialMode ?? modes.first;

  return showModalBottomSheet<DeckLaunchSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.neutral200,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How do you want to study?',
                    style: SkulMateTypography.gameCardTitle(size: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${deck.cards.length} cards in this deck',
                    style: SkulMateTypography.cardMeta(),
                  ),
                  const SizedBox(height: 16),
                  _LauncherOption(
                    title: 'Tutor lesson',
                    subtitle: 'Explain → quick check per card',
                    icon: Icons.menu_book_rounded,
                    accent: AppTheme.accentPurple,
                    selected: pick == _LauncherPick.tutor,
                    onTap: () => setState(() => pick = _LauncherPick.tutor),
                  ),
                  const SizedBox(height: 10),
                  ...modes.map((mode) {
                    final isSelected =
                        pick == _LauncherPick.play && mode == selected;
                    final accent = _modeAccent(mode);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LauncherOption(
                        title: mode.label,
                        subtitle: mode.subtitle,
                        icon: mode.icon,
                        accent: accent,
                        selected: isSelected,
                        onTap: () => setState(() {
                          pick = _LauncherPick.play;
                          selected = mode;
                        }),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      if (pick == _LauncherPick.tutor) {
                        Navigator.pop(
                          context,
                          const DeckLaunchSelection.tutor(),
                        );
                      } else {
                        Navigator.pop(
                          context,
                          DeckLaunchSelection.play(selected),
                        );
                      }
                    },
                    style: SkulMateSurfaceStyles.deckPrimaryButton(),
                    child: Text(
                      'Start learning',
                      style: SkulMateTypography.cardTitle(
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _LauncherOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _LauncherOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(SkulMateSurfaceStyles.deckRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(SkulMateSurfaceStyles.deckRadius),
          border: Border.all(
            color: selected ? accent : AppTheme.neutral200,
            width: selected ? 2 : 1,
          ),
          color: selected ? accent.withValues(alpha: 0.08) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SkulMateTypography.gameCardTitle(size: 15)),
                  Text(subtitle, style: SkulMateTypography.gameCardMeta(size: 12)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}
