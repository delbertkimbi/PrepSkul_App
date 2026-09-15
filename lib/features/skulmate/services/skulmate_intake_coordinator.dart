import 'package:flutter/material.dart';

import '../models/skulmate_intake_models.dart';
import '../screens/skulmate_path_overview_screen.dart';
import '../services/skulmate_access_service.dart';
import '../services/skulmate_home_refresh_bus.dart';
import '../services/skulmate_tutor_intake_bus.dart';
import '../widgets/skulmate_from_class_sheet.dart';
import '../widgets/skulmate_paywall_sheet.dart';
import '../widgets/skulmate_paste_sheet.dart';

/// Intake drops into the open tutor thread. No game-type picker.
class SkulMateIntakeCoordinator {
  SkulMateIntakeCoordinator._();

  static Future<void> start(
    BuildContext context,
    SkulMateIntakePayload payload,
  ) async {
    if (!context.mounted) return;

    final accessOk = await _checkAccess(context, payload);
    if (!accessOk || !context.mounted) return;

    SkulMateTutorIntakeBus.offer(payload);
    SkulMateHomeRefreshBus.notify();
  }

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

  static Future<void> openPath(
    BuildContext context,
    SkulMateIntakePayload payload,
  ) async {
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SkulMatePathOverviewScreen(payload: payload),
      ),
    );
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
}
