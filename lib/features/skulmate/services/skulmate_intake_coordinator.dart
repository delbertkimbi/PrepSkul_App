import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/skulmate_intake_models.dart';
import '../screens/game_generation_screen.dart';
import '../screens/game_setup_flow_screen.dart';
import '../screens/skulmate_path_overview_screen.dart';
import '../services/skulmate_access_service.dart';
import '../screens/skulmate_intake_chat_screen.dart';
import '../widgets/generation_context_sheet.dart';
import '../widgets/skulmate_from_class_sheet.dart';
import '../widgets/skulmate_paywall_sheet.dart';
import '../widgets/skulmate_paste_sheet.dart';

/// Single entry for SkulMate intake → chat analysis → generation routing.
class SkulMateIntakeCoordinator {
  SkulMateIntakeCoordinator._();

  static Future<void> start(
    BuildContext context,
    SkulMateIntakePayload payload,
  ) async {
    if (!context.mounted) return;

    final accessOk = await _checkAccess(context, payload);
    if (!accessOk || !context.mounted) return;

    final result = await Navigator.push<SkulMateIntakeChatResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SkulMateIntakeChatScreen(payload: payload),
      ),
    );
    if (result != null && context.mounted) {
      await _routeByMode(context, result.payload, result.mode);
    }
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

    final purchased = await SkulMatePaywallSheet.show(
      context,
      message: access.message,
    );
    if (!context.mounted) return false;
    if (purchased) {
      final retry = await SkulmateAccessService.checkGenerationAccess(
        sourceType: sourceType,
      );
      return retry.canProceed;
    }
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
      case SkulMateIntentMode.scroll:
        await _launchGeneration(
          context,
          payload,
          presetGameType: 'flashcards',
          openAsScrollFeed: true,
        );
      case SkulMateIntentMode.sheet:
      case SkulMateIntentMode.fromClass:
        break;
      case SkulMateIntentMode.path:
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SkulMatePathOverviewScreen(payload: payload),
          ),
        );
    }
  }

  static Future<void> _launchGeneration(
    BuildContext context,
    SkulMateIntakePayload payload, {
    String? presetGameType,
    bool openAsScrollFeed = false,
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
    final String? topic;
    if (contextResult?.topic != null &&
        contextResult!.topic!.trim().isNotEmpty) {
      topic = contextResult.topic!.trim();
    } else if (payload.hasTopicOnly) {
      topic = payload.topicHint?.trim();
    } else {
      topic = null;
    }

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
          openAsScrollFeed: openAsScrollFeed,
        ),
      ),
    );
  }
}
