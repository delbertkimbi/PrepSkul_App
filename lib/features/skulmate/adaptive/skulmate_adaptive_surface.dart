import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../widgets/skulmate_surface_styles.dart';
import 'skulmate_adaptive_data_model.dart';
import 'skulmate_adaptive_types.dart';

/// Renders one adaptive surface from a [SkulMateAdaptiveDataModel].
///
/// Mirrors genui [Surface] + [CatalogItem] — swap for package widgets after SDK upgrade.
class SkulMateAdaptiveSurface extends StatelessWidget {
  final SkulMateAdaptiveSurfaceSpec spec;
  final SkulMateAdaptiveDataModel dataModel;
  final VoidCallback? onFlip;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final String? primaryLabel;
  final String? secondaryLabel;

  const SkulMateAdaptiveSurface({
    super.key,
    required this.spec,
    required this.dataModel,
    this.onFlip,
    this.onPrimaryAction,
    this.onSecondaryAction,
    this.primaryLabel,
    this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dataModel,
      builder: (context, _) {
        return switch (spec.kind) {
          SkulMateCatalogKind.scrollCard ||
          SkulMateCatalogKind.flashcard =>
            _FlipCardSurface(
              dataModel: dataModel,
              onFlip: onFlip,
              onPrimary: onPrimaryAction,
              onSecondary: onSecondaryAction,
              primaryLabel: primaryLabel,
              secondaryLabel: secondaryLabel,
            ),
          SkulMateCatalogKind.quizQuestion => _QuizSurface(dataModel: dataModel),
          SkulMateCatalogKind.matchingPair => _MatchingSurface(dataModel: dataModel),
          SkulMateCatalogKind.puzzlePrompt => _PuzzleSurface(dataModel: dataModel),
          SkulMateCatalogKind.notesBlock => _NotesSurface(dataModel: dataModel),
        };
      },
    );
  }

  /// Hydrate [dataModel] from [spec] — call when spec or flip state changes.
  static void hydrate(
    SkulMateAdaptiveDataModel model,
    SkulMateAdaptiveSurfaceSpec spec,
  ) {
    model.applyAll(spec.initialData);
  }
}

class _FlipCardSurface extends StatelessWidget {
  final SkulMateAdaptiveDataModel dataModel;
  final VoidCallback? onFlip;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final String? primaryLabel;
  final String? secondaryLabel;

  const _FlipCardSurface({
    required this.dataModel,
    this.onFlip,
    this.onPrimary,
    this.onSecondary,
    this.primaryLabel,
    this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final flipped = dataModel.getBool('flipped');
    final term = dataModel.getString('term') ?? '';
    final definition = dataModel.getString('definition') ?? '';
    final gameTitle = dataModel.getString('gameTitle');
    final tapHint = dataModel.getString('tapHint') ??
        (flipped ? copy.scrollTapTerm : copy.scrollTapReveal);
    final revealHint = dataModel.getString('revealHint');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onFlip,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Container(
                  key: ValueKey(flipped),
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: SkulMateSurfaceStyles.chipCard().copyWith(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (gameTitle != null && gameTitle.isNotEmpty) ...[
                          Text(
                            gameTitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textMedium,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          flipped ? definition : term,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: flipped ? 18 : 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          revealHint ?? tapHint,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (onPrimary != null || onSecondary != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (onSecondary != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppTheme.softBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        secondaryLabel ?? copy.scrollAgain,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (onSecondary != null && onPrimary != null)
                  const SizedBox(width: 12),
                if (onPrimary != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        primaryLabel ?? copy.scrollGotIt,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizSurface extends StatelessWidget {
  final SkulMateAdaptiveDataModel dataModel;

  const _QuizSurface({required this.dataModel});

  @override
  Widget build(BuildContext context) {
    final question = dataModel.getString('question') ?? '';
    final options = dataModel.get('options');
    final optionList = options is List
        ? options.map((e) => e.toString()).toList()
        : <String>[];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: SkulMateSurfaceStyles.chipCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            ...optionList.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.softBorder),
                  ),
                  child: Text(
                    o,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchingSurface extends StatelessWidget {
  final SkulMateAdaptiveDataModel dataModel;

  const _MatchingSurface({required this.dataModel});

  @override
  Widget build(BuildContext context) {
    final left = dataModel.getString('leftItem') ?? '';
    final right = dataModel.getString('rightItem') ?? '';
    final revealed = dataModel.getBool('revealed');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(child: _matchTile(left)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.link_rounded, color: AppTheme.primaryColor),
          ),
          Expanded(child: _matchTile(revealed ? right : '•••')),
        ],
      ),
    );
  }

  Widget _matchTile(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SkulMateSurfaceStyles.chipCard(),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark,
        ),
      ),
    );
  }
}

class _PuzzleSurface extends StatelessWidget {
  final SkulMateAdaptiveDataModel dataModel;

  const _PuzzleSurface({required this.dataModel});

  @override
  Widget build(BuildContext context) {
    final prompt = dataModel.getString('prompt') ?? '';
    final hint = dataModel.getString('hint') ?? '';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: SkulMateSurfaceStyles.chipCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.extension_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Puzzle',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              prompt,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (hint.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                hint,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textMedium,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotesSurface extends StatelessWidget {
  final SkulMateAdaptiveDataModel dataModel;

  const _NotesSurface({required this.dataModel});

  @override
  Widget build(BuildContext context) {
    final title = dataModel.getString('title') ?? '';
    final body = dataModel.getString('body') ?? '';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: SkulMateSurfaceStyles.chipCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (title.isNotEmpty) const SizedBox(height: 8),
            Text(
              body,
              style: GoogleFonts.poppins(
                fontSize: 15,
                height: 1.45,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
