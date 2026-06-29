import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// How the learner brought content into SkulMate.
enum SkulMateIntakeSource {
  document,
  photo,
  paste,
  youtube,
  typedTopic,
  fromClass,
  lecture,
}

/// Post-upload / post-intake output mode (PrepSkul terminology).
enum SkulMateIntentMode {
  play,
  scroll,
  path,
  drill,
  sheet,
  fromClass,
}

extension SkulMateIntentModeX on SkulMateIntentMode {
  /// Modes shown on intake chat and the legacy intent sheet.
  static const selectableInIntake = <SkulMateIntentMode>[
    SkulMateIntentMode.play,
    SkulMateIntentMode.drill,
    SkulMateIntentMode.scroll,
    SkulMateIntentMode.path,
  ];

  bool get isComingSoon =>
      this == SkulMateIntentMode.sheet || this == SkulMateIntentMode.fromClass;
}

/// Payload collected before the intent sheet.
class SkulMateIntakePayload {
  final SkulMateIntakeSource source;
  final List<File>? files;
  final List<PlatformFile>? filesWeb;
  final List<XFile>? images;
  final String? text;
  final String? topicHint;
  final String? youtubeUrl;
  final String? title;
  final String? childId;
  final List<String>? preUploadedFileUrls;
  final List<String>? preUploadedSourceNames;

  const SkulMateIntakePayload({
    required this.source,
    this.files,
    this.filesWeb,
    this.images,
    this.text,
    this.topicHint,
    this.youtubeUrl,
    this.title,
    this.childId,
    this.preUploadedFileUrls,
    this.preUploadedSourceNames,
  });

  bool get hasFiles =>
      (files != null && files!.isNotEmpty) ||
      (filesWeb != null && filesWeb!.isNotEmpty);

  bool get hasImages => images != null && images!.isNotEmpty;

  bool get hasText => text != null && text!.trim().isNotEmpty;

  bool get hasYoutube => youtubeUrl != null && youtubeUrl!.trim().isNotEmpty;

  bool get hasPreUploadedImages =>
      preUploadedFileUrls != null && preUploadedFileUrls!.isNotEmpty;

  bool get hasTopicOnly =>
      topicHint != null &&
      topicHint!.trim().isNotEmpty &&
      !hasFiles &&
      !hasImages &&
      !hasText &&
      !hasYoutube;
}

/// Returned when the learner confirms a mode on the intake chat screen.
class SkulMateIntakeChatResult {
  final SkulMateIntakePayload payload;
  final SkulMateIntentMode mode;

  const SkulMateIntakeChatResult({
    required this.payload,
    required this.mode,
  });
}

/// Recently played game for Continue row.
class SkulMateContinueItem {
  final String gameId;
  final String title;
  final String subtitle;
  final int progressPercent;
  final DateTime lastPlayed;
  final int currentIndex;
  final int totalItems;

  const SkulMateContinueItem({
    required this.gameId,
    required this.title,
    required this.subtitle,
    required this.progressPercent,
    required this.lastPlayed,
    this.currentIndex = 0,
    this.totalItems = 0,
  });
}
