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
  });

  bool get hasFiles =>
      (files != null && files!.isNotEmpty) ||
      (filesWeb != null && filesWeb!.isNotEmpty);

  bool get hasImages => images != null && images!.isNotEmpty;

  bool get hasText => text != null && text!.trim().isNotEmpty;

  bool get hasYoutube => youtubeUrl != null && youtubeUrl!.trim().isNotEmpty;

  bool get hasTopicOnly =>
      topicHint != null &&
      topicHint!.trim().isNotEmpty &&
      !hasFiles &&
      !hasImages &&
      !hasText &&
      !hasYoutube;
}

/// Recently played game for Continue row.
class SkulMateContinueItem {
  final String gameId;
  final String title;
  final String subtitle;
  final double progressPercent;
  final DateTime lastPlayed;

  const SkulMateContinueItem({
    required this.gameId,
    required this.title,
    required this.subtitle,
    required this.progressPercent,
    required this.lastPlayed,
  });
}
