import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_models.dart';
import 'skulmate_sheet_scaffold.dart';
import 'skulmate_surface_styles.dart';

/// Post-intake mode picker (Play · Scroll · Path · Drill · Sheet).
class SkulMateIntentSheet extends StatefulWidget {
  final SkulMateIntakePayload payload;
  final SkulMateCopy copy;

  const SkulMateIntentSheet({
    super.key,
    required this.payload,
    required this.copy,
  });

  static Future<SkulMateIntentMode?> show(
    BuildContext context, {
    required SkulMateIntakePayload payload,
  }) {
    final copy = SkulMateCopy(
      Provider.of<LanguageNotifier>(context, listen: false)
              .currentLocale
              .languageCode ==
          'fr',
    );
    return SkulMateSheetScaffold.show<SkulMateIntentMode>(
      context,
      child: SkulMateIntentSheet(payload: payload, copy: copy),
    );
  }

  static const _selectableModes = [
    SkulMateIntentMode.play,
    SkulMateIntentMode.scroll,
    SkulMateIntentMode.path,
    SkulMateIntentMode.drill,
    SkulMateIntentMode.sheet,
  ];

  static bool isComingSoonMode(SkulMateIntentMode mode) {
    return mode == SkulMateIntentMode.sheet;
  }

  @override
  State<SkulMateIntentSheet> createState() => _SkulMateIntentSheetState();
}

class _SkulMateIntentSheetState extends State<SkulMateIntentSheet> {
  SkulMateIntentMode _selected = SkulMateIntentMode.play;

  @override
  Widget build(BuildContext context) {
    return SkulMateSheetScaffold(
      title: widget.copy.intentSheetTitle,
      showWandIcon: false,
      maxHeightFactor: 0.78,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: SkulMateIntentSheet._selectableModes
            .map(_modeCard)
            .toList(),
      ),
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: SkulMateIntentSheet.isComingSoonMode(_selected)
              ? null
              : () => Navigator.pop(context, _selected),
          style: SkulMateSurfaceStyles.sheetPrimaryButton(
            enabled: !SkulMateIntentSheet.isComingSoonMode(_selected),
          ),
          child: Text(
            widget.copy.modeCta(_selected),
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeCard(SkulMateIntentMode mode) {
    final comingSoon = SkulMateIntentSheet.isComingSoonMode(mode);
    final selected = !comingSoon && _selected == mode;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: comingSoon ? null : () => setState(() => _selected = mode),
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: comingSoon ? 0.55 : 1,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primaryColor.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppTheme.primaryColor : AppTheme.softBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(_emoji(mode), style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.copy.modeLabel(mode),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        widget.copy.modeSubtitle(mode),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (comingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.neutral100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.copy.comingSoon,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _emoji(SkulMateIntentMode mode) {
    switch (mode) {
      case SkulMateIntentMode.play:
        return '🎮';
      case SkulMateIntentMode.scroll:
        return '📱';
      case SkulMateIntentMode.path:
        return '🗺️';
      case SkulMateIntentMode.drill:
        return '🃏';
      case SkulMateIntentMode.sheet:
        return '📄';
      case SkulMateIntentMode.fromClass:
        return '🎓';
    }
  }
}
