import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_models.dart';
import '../widgets/skulmate_surface_styles.dart';

/// Minimal Path overview stub (Phase A).
class SkulMatePathOverviewScreen extends StatelessWidget {
  final String? topic;
  final VoidCallback? onStartPath;

  const SkulMatePathOverviewScreen({
    super.key,
    this.topic,
    this.onStartPath,
  });

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final steps = [
      copy.isFrench ? 'Aperçu du sujet' : 'Topic overview',
      copy.isFrench ? 'Concepts clés' : 'Key concepts',
      copy.isFrench ? 'Pratique guidée' : 'Guided practice',
      copy.isFrench ? 'Défi final' : 'Final challenge',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          copy.modeLabel(SkulMateIntentMode.path),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (topic != null && topic!.trim().isNotEmpty)
            Text(
              topic!,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: SkulMateSurfaceStyles.neumorphicCard(),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: onStartPath,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                copy.modeCta(SkulMateIntentMode.path),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
