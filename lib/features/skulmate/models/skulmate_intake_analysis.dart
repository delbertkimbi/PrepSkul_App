import 'skulmate_intake_models.dart';

/// Preview of what the learner uploaded (shown in the chat bubble).
class SkulMateIntakeAttachment {
  final SkulMateIntakeSource source;
  final String label;
  final String? fileName;
  final String? thumbnailUrl;
  final String? localImagePath;
  final List<String>? localImagePaths;
  final int? imageCount;

  const SkulMateIntakeAttachment({
    required this.source,
    required this.label,
    this.fileName,
    this.thumbnailUrl,
    this.localImagePath,
    this.localImagePaths,
    this.imageCount,
  });
}

/// Result of reading / understanding intake content before mode selection.
class SkulMateIntakeAnalysis {
  final String topicLabel;
  final String? resolvedText;
  final SkulMateIntakeAttachment attachment;
  final String? contextSummary;
  final List<String>? uploadedFileUrls;
  final List<String>? uploadedFileNames;

  const SkulMateIntakeAnalysis({
    required this.topicLabel,
    required this.attachment,
    this.resolvedText,
    this.contextSummary,
    this.uploadedFileUrls,
    this.uploadedFileNames,
  });

  SkulMateIntakePayload enrich(SkulMateIntakePayload payload) {
    final isTopicOnly = payload.hasTopicOnly;
    final text = isTopicOnly ? null : (resolvedText ?? payload.text);
    final hasResolvedYoutube =
        payload.hasYoutube && resolvedText != null && resolvedText!.isNotEmpty;

    // Keep friendly topicLabel for chat UI only — do not push auto filenames into hints.
    final explicitTopicHint = payload.topicHint?.trim();
    final explicitTitle = payload.title?.trim();

    return SkulMateIntakePayload(
      source: payload.source,
      files: payload.files,
      filesWeb: payload.filesWeb,
      images: payload.images,
      text: text,
      topicHint: isTopicOnly
          ? (explicitTopicHint ?? topicLabel)
          : explicitTopicHint,
      youtubeUrl: hasResolvedYoutube ? null : payload.youtubeUrl,
      title: explicitTitle,
      childId: payload.childId,
      preUploadedFileUrls: uploadedFileUrls ?? payload.preUploadedFileUrls,
      preUploadedSourceNames:
          uploadedFileNames ?? payload.preUploadedSourceNames,
    );
  }
}
