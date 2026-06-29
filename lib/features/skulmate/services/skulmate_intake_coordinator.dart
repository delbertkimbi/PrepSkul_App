import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' show File;

import '../models/skulmate_intake_models.dart';
import '../screens/game_generation_screen.dart';
import '../screens/skulmate_path_overview_screen.dart';
import '../services/skulmate_access_service.dart';
import '../services/skulmate_home_refresh_bus.dart';
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
    SkulMateHomeRefreshBus.notify();
  }

  /// Tutoring session recap → same intake + paywall path as paste/import.
  static Future<void> startFromSessionSummary(
    BuildContext context, {
    required String summary,
    String? topicHint,
    String? childId,
  }) {
    final topic = topicHint?.trim();
    return start(
      context,
      SkulMateIntakePayload(
        source: SkulMateIntakeSource.fromClass,
        text: summary,
        topicHint: topic?.isNotEmpty == true ? topic : null,
        title: topic?.isNotEmpty == true ? topic : null,
        childId: childId,
      ),
    );
  }

  static Future<void> openPasteFlow(
    BuildContext context, {
    String? childId,
  }) async {
    if (!context.mounted) return;
    await SkulMatePasteSheet.show(context, childId: childId);
    SkulMateHomeRefreshBus.notify();
  }

  static Future<void> openFromClass(
    BuildContext context, {
    String? childId,
  }) async {
    if (!context.mounted) return;
    await SkulMateFromClassSheet.show(context, childId: childId);
    SkulMateHomeRefreshBus.notify();
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
        await _launchGeneration(context, payload, mode);
      case SkulMateIntentMode.drill:
        await _launchGeneration(
          context,
          payload,
          mode,
          presetGameType: 'flashcards',
        );
      case SkulMateIntentMode.scroll:
        await _launchGeneration(
          context,
          payload,
          mode,
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
    SkulMateIntakePayload payload,
    SkulMateIntentMode intakeMode, {
    String? presetGameType,
    bool openAsScrollFeed = false,
  }) async {
    if (!context.mounted) return;

    final GenerationContext contextResult;
    if (presetGameType != null) {
      contextResult = GenerationContext(gameType: presetGameType);
    } else if (payload.hasTopicOnly) {
      contextResult = GenerationContext(topic: payload.topicHint);
    } else {
      contextResult = const GenerationContext();
    }

    final gameType = presetGameType ?? contextResult.gameType;
    final String? topic;
    if (contextResult.topic != null && contextResult.topic!.trim().isNotEmpty) {
      topic = contextResult.topic!.trim();
    } else if (payload.hasTopicOnly) {
      topic = payload.topicHint?.trim();
    } else {
      topic = null;
    }

    dynamic document;
    List<dynamic>? documents;
    if (kIsWeb && payload.filesWeb != null && payload.filesWeb!.isNotEmpty) {
      if (payload.filesWeb!.length == 1) {
        document = payload.filesWeb!.first;
      } else {
        documents = List<PlatformFile>.from(payload.filesWeb!);
      }
    } else if (payload.files != null && payload.files!.isNotEmpty) {
      if (payload.files!.length == 1) {
        document = payload.files!.first;
      } else {
        documents = List<File>.from(payload.files!);
      }
    }

    List<XFile>? images;
    if (payload.images != null && payload.images!.isNotEmpty) {
      images = payload.images;
    }

    final preUrls = payload.preUploadedFileUrls;
    final preNames = payload.preUploadedSourceNames;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GameGenerationScreen(
          documentToUpload: document,
          documentsToUpload: documents,
          imageToUpload: images != null && images.length == 1 && preUrls == null
              ? images.first
              : null,
          imagesToUpload: images != null && images.length > 1 && preUrls == null
              ? images
              : null,
          preUploadedFileUrls: preUrls,
          preUploadedSourceNames: preNames,
          text: payload.text,
          youtubeUrl: payload.youtubeUrl,
          childId: payload.childId,
          topic: topic,
          difficulty: contextResult.difficulty,
          gameType: gameType,
          openAsScrollFeed: openAsScrollFeed,
          intakeMode: intakeMode,
        ),
      ),
    );
  }
}
