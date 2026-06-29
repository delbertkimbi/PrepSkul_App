import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../services/skulmate_service.dart';
import '../services/tts_service.dart';

/// Quiz-style learn-more bottom sheet for puzzle steps.
Future<void> showPuzzleLearnMoreSheet({
  required BuildContext context,
  required String term,
  required String definition,
  required String gameId,
  TTSService? ttsService,
  bool ttsEnabled = true,
}) {
  final explainFuture = SkulMateService.explainFlashcard(
    term: term,
    definition: definition,
    gameId: gameId,
    weakTopicReroute: true,
  );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: FutureBuilder<ExplainResult>(
              future: explainFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      definition.isNotEmpty
                          ? definition
                          : 'Could not load more details right now.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    ),
                  );
                }
                final result = snapshot.data!;
                if (ttsEnabled && ttsService != null && result.explanation.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ttsService.speak(result.explanation);
                  });
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Learn more',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        term,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        result.explanation,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          height: 1.45,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
