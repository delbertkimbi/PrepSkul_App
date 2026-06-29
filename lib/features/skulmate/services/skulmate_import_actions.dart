import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/skulmate_intake_models.dart';
import '../services/skulmate_intake_coordinator.dart';
import '../widgets/skulmate_import_photos_sheet.dart';
import '../widgets/skulmate_youtube_import_sheet.dart';

/// Shared upload entry points for home tools, deck empty state, and deck hub.
class SkulMateImportActions {
  SkulMateImportActions._();

  static Future<void> pickDocuments(
    BuildContext context, {
    String? childId,
    bool allowMultiple = true,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'pptx'],
      allowMultiple: allowMultiple,
    );
    if (result == null || result.files.isEmpty || !context.mounted) return;

    if (kIsWeb) {
      await SkulMateIntakeCoordinator.start(
        context,
        SkulMateIntakePayload(
          source: SkulMateIntakeSource.document,
          filesWeb: result.files,
          childId: childId,
        ),
      );
      return;
    }

    final paths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .map((p) => File(p))
        .toList();
    if (paths.isEmpty || !context.mounted) return;

    await SkulMateIntakeCoordinator.start(
      context,
      SkulMateIntakePayload(
        source: SkulMateIntakeSource.document,
        files: paths,
        childId: childId,
      ),
    );
  }

  static Future<void> pickPhotos(BuildContext context, {String? childId}) async {
    if (SkulMateImportPhotosSheet.isOpening) return;
    final images = await SkulMateImportPhotosSheet.show(context);
    if (images == null || images.isEmpty || !context.mounted) return;
    await SkulMateIntakeCoordinator.start(
      context,
      SkulMateIntakePayload(
        source: SkulMateIntakeSource.photo,
        images: images,
        childId: childId,
      ),
    );
  }

  static Future<void> openPaste(BuildContext context, {String? childId}) async {
    await SkulMateIntakeCoordinator.openPasteFlow(context, childId: childId);
  }

  static Future<void> importYoutube(
    BuildContext context, {
    String? childId,
  }) async {
    final url = await SkulMateYoutubeImportSheet.show(context);
    if (url == null || !context.mounted) return;
    await SkulMateIntakeCoordinator.start(
      context,
      SkulMateIntakePayload(
        source: SkulMateIntakeSource.youtube,
        youtubeUrl: url,
        childId: childId,
      ),
    );
  }
}
