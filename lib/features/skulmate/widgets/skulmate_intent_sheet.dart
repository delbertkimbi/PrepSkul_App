import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/localization/language_notifier.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_models.dart';

/// Post-intake mode picker (Play · Scroll · Path · Drill · Sheet · From class).
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
    return showModalBottomSheet<SkulMateIntentMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SkulMateIntentSheet(payload: payload, copy: copy),
    );
  }

  @override
  State<SkulMateIntentSheet> createState() => _SkulMateIntentSheetState();
}

class _SkulMateIntentSheetState extends State<SkulMateIntentSheet> {
  SkulMateIntentMode _selected = SkulMateIntentMode.play;

  static const List<SkulMateIntentMode> _modes = [
    SkulMateIntentMode.play,
    SkulMateIntentMode.scroll,
    SkulMateIntentMode.path,
    SkulMateIntentMode.drill,
    SkulMateIntentMode.sheet,
    SkulMateIntentMode.fromClass,
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.neutral200,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SkulMate',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMedium,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.copy.isFrench
                      ? 'Comment veux-tu réviser ?'
                      : 'How do you want to revise?',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                ..._modes.map(_modeCard),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      widget.copy.modeCta(_selected),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _modeCard(SkulMateIntentMode mode) {
    final selected = _selected == mode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _selected = mode),
        borderRadius: BorderRadius.circular(16),
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
            ],
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
