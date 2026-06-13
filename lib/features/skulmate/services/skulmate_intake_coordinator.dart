import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_models.dart';
import '../screens/game_generation_screen.dart';
import '../screens/game_setup_flow_screen.dart';
import '../screens/skulmate_path_overview_screen.dart';
import '../services/skulmate_access_service.dart';
import '../widgets/generation_context_sheet.dart';
import '../widgets/skulmate_from_class_sheet.dart';
import '../widgets/skulmate_intent_sheet.dart';
import '../widgets/skulmate_paste_sheet.dart';
import '../screens/skulmate_plans_screen.dart';

/// Single entry for SkulMate intake → intent sheet → generation routing.
class SkulMateIntakeCoordinator {
  SkulMateIntakeCoordinator._();

  static Future<void> start(
    BuildContext context,
    SkulMateIntakePayload payload,
  ) async {
    if (!context.mounted) return;

    final accessOk = await _checkAccess(context, payload);
    if (!accessOk || !context.mounted) return;

    final mode = await SkulMateIntentSheet.show(context, payload: payload);
    if (mode == null || !context.mounted) return;

    await _routeByMode(context, payload, mode);
  }

  static Future<void> openPasteFlow(
    BuildContext context, {
    String? childId,
  }) async {
    if (!context.mounted) return;
    await SkulMatePasteSheet.show(context, childId: childId);
  }

  static Future<void> openFromClass(
    BuildContext context, {
    String? childId,
  }) async {
    if (!context.mounted) return;
    await SkulMateFromClassSheet.show(context, childId: childId);
  }

  static SkulmateSourceType _sourceTypeFor(SkulMateIntakePayload payload) {
    if (payload.hasImages) return SkulmateSourceType.image;
    return SkulmateSourceType.text;
  }

  static Future<bool> _checkAccess(
    BuildContext context,
    SkulMateIntakePayload payload,
  ) async {
    if (payload.hasYoutube || payload.hasTopicOnly) {
      return true;
    }
    if (!payload.hasFiles && !payload.hasImages && !payload.hasText) {
      return true;
    }

    final sourceType = _sourceTypeFor(payload);
    final access = await SkulmateAccessService.checkGenerationAccess(
      sourceType: sourceType,
    );
    if (access.canProceed || !context.mounted) return access.canProceed;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Plan required',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          access.message,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Not now', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.push(
                ctx,
                MaterialPageRoute(builder: (_) => const SkulmatePlansScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text(
              'See plans',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return false;
  }

  static Future<void> _routeByMode(
    BuildContext context,
    SkulMateIntakePayload payload,
    SkulMateIntentMode mode,
  ) async {
    switch (mode) {
      case SkulMateIntentMode.play:
        await _launchGeneration(context, payload);
      case SkulMateIntentMode.drill:
        await _launchGeneration(
          context,
          payload,
          presetGameType: 'flashcards',
        );
      case SkulMateIntentMode.fromClass:
        await openFromClass(context, childId: payload.childId);
      case SkulMateIntentMode.scroll:
      case SkulMateIntentMode.sheet:
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              SkulMateCopy.read(context).comingSoon,
              style: GoogleFonts.poppins(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case SkulMateIntentMode.path:
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SkulMatePathOverviewScreen(
              topic: payload.topicHint ?? payload.title,
              onStartPath: () async {
                Navigator.pop(context);
                await _launchGeneration(context, payload);
              },
            ),
          ),
        );
    }
  }

  static Future<void> _launchGeneration(
    BuildContext context,
    SkulMateIntakePayload payload, {
    String? presetGameType,
  }) async {
    if (!context.mounted) return;

    GenerationContext? contextResult;
    if (presetGameType != null) {
      contextResult = GenerationContext(gameType: presetGameType);
    } else if (payload.hasTopicOnly) {
      contextResult = GenerationContext(topic: payload.topicHint);
    } else {
      contextResult = await Navigator.push<GenerationContext?>(
        context,
        MaterialPageRoute(
          builder: (_) => GameSetupFlowScreen(
            initialGameType: presetGameType,
          ),
        ),
      );
    }

    if (!context.mounted) return;

    final gameType = presetGameType ?? contextResult?.gameType;
    final topic = contextResult?.topic ?? payload.topicHint ?? payload.title;

    dynamic document;
    if (kIsWeb && payload.filesWeb != null && payload.filesWeb!.isNotEmpty) {
      document = payload.filesWeb!.first;
    } else if (payload.files != null && payload.files!.isNotEmpty) {
      document = payload.files!.first;
    }

    List<XFile>? images;
    if (payload.images != null && payload.images!.isNotEmpty) {
      images = payload.images;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameGenerationScreen(
          documentToUpload: document,
          imageToUpload: images != null && images.length == 1
              ? images.first
              : null,
          imagesToUpload: images != null && images.length > 1 ? images : null,
          text: payload.text,
          youtubeUrl: payload.youtubeUrl,
          childId: payload.childId,
          topic: topic,
          difficulty: contextResult?.difficulty,
          gameType: gameType,
        ),
      ),
    );
  }
}
