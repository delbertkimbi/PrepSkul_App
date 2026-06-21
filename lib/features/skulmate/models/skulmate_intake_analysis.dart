import 'skulmate_intake_models.dart';

/// Preview of what the learner uploaded (shown in the chat bubble).
class SkulMateIntakeAttachment {
  final SkulMateIntakeSource source;
  final String label;
  final String? fileName;
  final String? thumbnailUrl;
  final String? localImagePath;

  const SkulMateIntakeAttachment({
    required this.source,
    required this.label,
    this.fileName,
    this.thumbnailUrl,
    this.localImagePath,
  });
}

/// Result of reading / understanding intake content before mode selection.
class SkulMateIntakeAnalysis {
  final String topicLabel;
  final String? resolvedText;
  final SkulMateIntakeAttachment attachment;

  const SkulMateIntakeAnalysis({
    required this.topicLabel,
    required this.attachment,
    this.resolvedText,
  });

  SkulMateIntakePayload enrich(SkulMateIntakePayload payload) {
    final isTopicOnly = payload.hasTopicOnly;
    final text = isTopicOnly ? null : (resolvedText ?? payload.text);
    final hasResolvedYoutube =
        payload.hasYoutube && resolvedText != null && resolvedText!.isNotEmpty;

    return SkulMateIntakePayload(
      source: payload.source,
      files: payload.files,
      filesWeb: payload.filesWeb,
      images: payload.images,
      text: text,
      topicHint: payload.topicHint ?? topicLabel,
      youtubeUrl: hasResolvedYoutube ? null : payload.youtubeUrl,
      title: payload.title ?? topicLabel,
      childId: payload.childId,
    );
  }
}
