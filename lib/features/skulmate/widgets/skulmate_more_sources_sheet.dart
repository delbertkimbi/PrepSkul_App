import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';

/// Expanded source list (Gizmo + menu pattern) — Phase A stubs for extras.
class SkulMateMoreSourcesSheet extends StatelessWidget {
  const SkulMateMoreSourcesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const SkulMateMoreSourcesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final items = [
      (Icons.picture_as_pdf_outlined, 'PDF', copy.comingSoon),
      (Icons.slideshow_outlined, 'PowerPoint', copy.comingSoon),
      (Icons.mic_outlined, copy.recordLecture, copy.comingSoon),
      (Icons.layers_outlined, copy.quizlet, copy.comingSoon),
      (Icons.folder_outlined, copy.deck, copy.comingSoon),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...items.map(
                (item) => ListTile(
                  leading: Icon(item.$1, color: AppTheme.primaryColor),
                  title: Text(
                    item.$2,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  trailing: Text(
                    item.$3,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(copy.comingSoon),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
