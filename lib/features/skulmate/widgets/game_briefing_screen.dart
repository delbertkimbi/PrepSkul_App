import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_briefing_model.dart';
import '../models/game_model.dart';
import '../models/puzzle_step_model.dart';
import '../services/game_rules_service.dart';
import 'game_standard_widgets.dart';
import 'puzzle_journey_roadmap.dart';
import 'puzzle_sequence_widgets.dart';
import 'skulmate_game_app_bar.dart';
import 'skulmate_game_surface.dart';

/// Unified pre-game briefing — calm, structured mission screen.
class GameBriefingScreen extends StatelessWidget {
  final GameModel game;

  const GameBriefingScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final briefing = GameBriefingModel.fromGame(game);
    final rules = GameRulesService.getRulesForGameType(game.gameType);
    final visuals = _BriefingVisuals.forType(game.gameType);
    final puzzleSteps = game.gameType == GameType.puzzlePieces &&
            game.items.isNotEmpty
        ? PuzzleStepDefinition.parseFromGameItem(
            puzzleSteps: game.items.first.puzzleSteps,
            puzzlePieces: game.items.first.puzzlePieces,
            gameData: game.items.first.gameData,
          )
        : <PuzzleStepDefinition>[];

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: SkulMateGameAppBar(
        light: true,
        title: copy.briefingScreenTitle,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GameSummaryCard(
                      briefing: briefing,
                      visuals: visuals,
                      description: game.gameType == GameType.puzzlePieces
                          ? copy.puzzleMissionLine
                          : rules.description,
                      topicLine: briefing.topic != null
                          ? copy.briefingTopicLine(briefing.topic!)
                          : null,
                    ),
                    if (game.gameType == GameType.puzzlePieces &&
                        game.items.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      PuzzleHeroImage(
                        imageUrl: game.items.first.imageUrl,
                        placeholderTitle: game.title,
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (game.gameType == GameType.puzzlePieces &&
                        puzzleSteps.isNotEmpty) ...[
                      PuzzleJourneyRoadmap(steps: puzzleSteps),
                    ] else ...[
                      _SectionLabel(label: copy.briefingHowToPlaySection),
                      const SizedBox(height: 6),
                      ...List.generate(rules.steps.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _PlayStepRow(
                            index: i + 1,
                            text: rules.steps[i],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 12),
                    _SectionLabel(label: copy.briefingReadySection),
                    const SizedBox(height: 6),
                    _ReadySummary(
                      gameTypeLabel: briefing.gameTypeLabel,
                      itemCountLabel: briefing.itemCountLabel,
                      timeLabel: copy.puzzleIntroTime(briefing.estimatedMinutes),
                      xpLabel: copy.puzzleIntroReward(briefing.estimatedXp),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: GameStandardsPrimaryButton(
                label: copy.briefingStartButton,
                onPressed: () => Navigator.pop(context, true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BriefingVisuals {
  final IconData icon;

  const _BriefingVisuals({required this.icon});

  static _BriefingVisuals forType(GameType type) {
    switch (type) {
      case GameType.quiz:
        return const _BriefingVisuals(icon: Icons.quiz_rounded);
      case GameType.matching:
        return const _BriefingVisuals(icon: Icons.link_rounded);
      case GameType.puzzlePieces:
        return const _BriefingVisuals(icon: Icons.extension_rounded);
      case GameType.flashcards:
        return const _BriefingVisuals(icon: Icons.style_rounded);
      case GameType.dragDrop:
        return const _BriefingVisuals(icon: Icons.open_with_rounded);
      case GameType.fillBlank:
        return const _BriefingVisuals(icon: Icons.edit_note_rounded);
      default:
        return const _BriefingVisuals(icon: Icons.videogame_asset_rounded);
    }
  }
}

class _GameSummaryCard extends StatelessWidget {
  final GameBriefingModel briefing;
  final _BriefingVisuals visuals;
  final String description;
  final String? topicLine;

  const _GameSummaryCard({
    required this.briefing,
    required this.visuals,
    required this.description,
    this.topicLine,
  });

  @override
  Widget build(BuildContext context) {
    return GameFlatPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(visuals.icon, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      briefing.gameTypeLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: AppTheme.textMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      briefing.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (topicLine != null) ...[
            const SizedBox(height: 8),
            Text(
              topicLine!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMedium,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppTheme.textDark,
      ),
    );
  }
}

class _PlayStepRow extends StatelessWidget {
  final int index;
  final String text;

  const _PlayStepRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadySummary extends StatelessWidget {
  final String gameTypeLabel;
  final String itemCountLabel;
  final String timeLabel;
  final String xpLabel;

  const _ReadySummary({
    required this.gameTypeLabel,
    required this.itemCountLabel,
    required this.timeLabel,
    required this.xpLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Text(
        '$gameTypeLabel · $itemCountLabel · $timeLabel · $xpLabel',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark,
          height: 1.4,
        ),
      ),
    );
  }
}
