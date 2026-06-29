import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_analysis.dart';
import '../models/skulmate_intake_models.dart';
import '../services/skulmate_intake_analysis_service.dart';
import '../services/skulmate_intake_coordinator.dart';
import '../widgets/skulmate_generation_error_panel.dart';
import '../widgets/skulmate_mascot_media_widget.dart';
import '../widgets/skulmate_mode_card.dart';
import '../widgets/skulmate_surface_styles.dart';

/// Gizmo-style chat intake — analyze content, then pick how to revise.
class SkulMateIntakeChatScreen extends StatefulWidget {
  final SkulMateIntakePayload payload;

  const SkulMateIntakeChatScreen({super.key, required this.payload});

  @override
  State<SkulMateIntakeChatScreen> createState() =>
      _SkulMateIntakeChatScreenState();
}

class _SkulMateIntakeChatScreenState extends State<SkulMateIntakeChatScreen> {
  static const _selectableModes = SkulMateIntentModeX.selectableInIntake;


  SkulMateIntentMode _selected = SkulMateIntentMode.play;
  bool _analyzing = true;
  SkulMateIntakeAnalysis? _analysis;
  String? _errorTitle;
  String? _errorDetails;
  final _refineController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  @override
  void dispose() {
    _refineController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    final copy = SkulMateCopy.read(context);
    final instantTopic = widget.payload.hasTopicOnly;
    if (!instantTopic) {
      setState(() {
        _analyzing = true;
        _errorTitle = null;
        _errorDetails = null;
      });
    }

    try {
      final analysis = await SkulMateIntakeAnalysisService.analyze(
        widget.payload,
        copy: copy,
      );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _analyzing = false;
        _errorTitle = copy.intakeErrorTitle(widget.payload.source, msg);
        _errorDetails = copy.intakeErrorDetails(widget.payload.source, msg);
      });
    }
  }

  Future<void> _startGeneration() async {
    final analysis = _analysis;
    if (analysis == null) return;

    var enriched = analysis.enrich(widget.payload);
    final refinement = _refineController.text.trim();
    if (refinement.isNotEmpty) {
      enriched = SkulMateIntakePayload(
        source: enriched.source,
        files: enriched.files,
        filesWeb: enriched.filesWeb,
        images: enriched.images,
        text: enriched.text,
        topicHint: refinement,
        youtubeUrl: enriched.youtubeUrl,
        title: refinement,
        childId: enriched.childId,
        preUploadedFileUrls: enriched.preUploadedFileUrls,
        preUploadedSourceNames: enriched.preUploadedSourceNames,
      );
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      SkulMateIntakeChatResult(payload: enriched, mode: _selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.softBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          _analysis != null && !_analyzing
              ? _truncateTitle(_analysis!.topicLabel)
              : copy.intakeChatTitle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _UserAttachmentBubble(
                    attachment: _analysis?.attachment ??
                        SkulMateIntakeAnalysisService.previewAttachment(
                          widget.payload,
                          copy,
                        ),
                    imageFiles: widget.payload.images,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: SkulMateMascotMediaWidget(
                        state: SkulMateMascotState.encouraging,
                        showFrame: false,
                        preferStaticImage: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'SkulMate',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_analyzing) ...[
                  const SizedBox(height: 24),
                  const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    copy.intakeAnalyzing,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ] else if (_errorTitle != null) ...[
                  SkulMateGenerationErrorPanel(
                    title: _errorTitle!,
                    details: _errorDetails,
                    kind: SkulMateGenerationErrorPanel.kindFromMessage(
                      '${_errorTitle ?? ''} ${_errorDetails ?? ''}',
                    ),
                    retryable: true,
                    onRetry: _runAnalysis,
                    onBack: () => Navigator.pop(context),
                    onManualText: widget.payload.hasYoutube
                        ? () => SkulMateIntakeCoordinator.openPasteFlow(
                              context,
                              childId: widget.payload.childId,
                            )
                        : null,
                  ),
                ] else if (_analysis != null) ...[
                  ..._selectableModes.map((mode) => _modeCard(mode, copy)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selected.isComingSoon ? null : _startGeneration,
                      style: SkulMateSurfaceStyles.sheetPrimaryButton(
                        enabled: !_selected.isComingSoon,
                      ),
                      child: Text(
                        copy.modeCta(_selected),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SummaryText(
                    message: _summaryMessage(copy),
                    topic: _analysis!.topicLabel,
                  ),
                ],
              ],
            ),
          ),
          if (!_analyzing && _errorTitle == null && _analysis != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  controller: _refineController,
                  decoration: InputDecoration(
                    hintText: copy.intakeRefinePlaceholder,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: AppTheme.softBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: AppTheme.softBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    hintStyle: GoogleFonts.poppins(
                      color: AppTheme.textMedium.withValues(alpha: 0.55),
                      fontSize: 15,
                    ),
                  ),
                  style: GoogleFonts.poppins(fontSize: 15),
                  textInputAction: TextInputAction.done,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeCard(SkulMateIntentMode mode, SkulMateCopy copy) {
    final comingSoon = mode.isComingSoon;
    final selected = !comingSoon && _selected == mode;
    final topic = _analysis?.topicLabel ?? '';
    final spec = _modeSpec(mode);

    return SkulMateModeCard(
      title: copy.modeLabel(mode),
      subtitle: copy.modeCardSubtitle(mode, topic),
      icon: spec.icon,
      accent: spec.accent,
      selected: selected,
      comingSoon: comingSoon,
      comingSoonLabel: comingSoon ? copy.comingSoon : null,
      onTap: () => setState(() => _selected = mode),
    );
  }

  ({IconData icon, Color accent}) _modeSpec(SkulMateIntentMode mode) {
    switch (mode) {
      case SkulMateIntentMode.play:
        return (icon: Icons.sports_esports_rounded, accent: AppTheme.skyBlue);
      case SkulMateIntentMode.scroll:
        return (icon: Icons.view_agenda_rounded, accent: AppTheme.accentPink);
      case SkulMateIntentMode.path:
        return (icon: Icons.route_rounded, accent: const Color(0xFF3B82F6));
      case SkulMateIntentMode.drill:
        return (icon: Icons.style_rounded, accent: AppTheme.accentGreen);
      case SkulMateIntentMode.sheet:
        return (icon: Icons.description_rounded, accent: AppTheme.accentOrange);
      case SkulMateIntentMode.fromClass:
        return (icon: Icons.school_rounded, accent: AppTheme.primaryColor);
    }
  }

  String _truncateTitle(String title) {
    if (title.length <= 36) return title;
    return '${title.substring(0, 33)}…';
  }

  String _summaryMessage(SkulMateCopy copy) {
    final summary = _analysis?.contextSummary?.trim();
    if (summary != null && summary.isNotEmpty) return summary;
    return copy.intakeChatSummary(_analysis!.topicLabel);
  }
}

class _UserAttachmentBubble extends StatelessWidget {
  final SkulMateIntakeAttachment attachment;
  final List<XFile>? imageFiles;

  const _UserAttachmentBubble({
    required this.attachment,
    this.imageFiles,
  });

  @override
  Widget build(BuildContext context) {
    final count = attachment.imageCount ?? 0;
    if (count > 1) {
      return _MultiPhotoAttachmentGrid(
        attachment: attachment,
        imageFiles: imageFiles,
      );
    }
    return _buildChip(attachment);
  }

  Widget _buildChip(SkulMateIntakeAttachment att) {
    if (att.thumbnailUrl != null) {
      return _AttachmentChip(
        label: att.label,
        imageUrl: att.thumbnailUrl,
      );
    }
    if (att.localImagePath != null &&
        att.localImagePath!.isNotEmpty &&
        !kIsWeb) {
      return _AttachmentChip(
        label: att.label,
        imageFile: File(att.localImagePath!),
      );
    }
    if (att.source == SkulMateIntakeSource.document &&
        (att.fileName?.toLowerCase().endsWith('.pdf') ?? false)) {
      return _AttachmentChip(
        label: 'PDF',
        icon: Icons.picture_as_pdf_rounded,
        iconColor: const Color(0xFFE53935),
      );
    }
    if (att.source == SkulMateIntakeSource.typedTopic ||
        att.source == SkulMateIntakeSource.paste) {
      return _AttachmentChip(
        label: att.label,
        icon: Icons.sticky_note_2_outlined,
        iconColor: AppTheme.textDark,
        compact: true,
      );
    }
    return _AttachmentChip(
      label: att.fileName ?? att.label,
      icon: _iconFor(att.source),
      iconColor: AppTheme.textDark,
      compact: att.fileName != null,
    );
  }

  IconData _iconFor(SkulMateIntakeSource source) {
    switch (source) {
      case SkulMateIntakeSource.youtube:
        return Icons.play_circle_filled_rounded;
      case SkulMateIntakeSource.photo:
        return Icons.image_outlined;
      case SkulMateIntakeSource.lecture:
        return Icons.mic_rounded;
      default:
        return Icons.description_outlined;
    }
  }
}

class _MultiPhotoAttachmentGrid extends StatelessWidget {
  final SkulMateIntakeAttachment attachment;
  final List<XFile>? imageFiles;

  const _MultiPhotoAttachmentGrid({
    required this.attachment,
    this.imageFiles,
  });

  @override
  Widget build(BuildContext context) {
    final count = attachment.imageCount ?? imageFiles?.length ?? 0;
    final paths = attachment.localImagePaths ?? const <String>[];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        for (var i = 0; i < count; i++)
          _PhotoPreviewTile(
            path: i < paths.length ? paths[i] : null,
            file: imageFiles != null && i < imageFiles!.length
                ? imageFiles![i]
                : null,
            onTap: () => _showPreview(context, i),
          ),
      ],
    );
  }

  void _showPreview(BuildContext context, int index) {
    final paths = attachment.localImagePaths ?? const <String>[];
    final files = imageFiles;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: _previewImage(
                  index < paths.length ? paths[index] : null,
                  files != null && index < files.length ? files[index] : null,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewImage(String? path, XFile? file) {
    if (!kIsWeb && path != null && path.isNotEmpty) {
      return Image.file(File(path), fit: BoxFit.contain);
    }
    if (file != null) {
      return FutureBuilder<List<int>>(
        future: file.readAsBytes(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          return Image.memory(
            Uint8List.fromList(snap.data!),
            fit: BoxFit.contain,
          );
        },
      );
    }
    return const Icon(Icons.image_outlined, color: Colors.white, size: 64);
  }
}

class _PhotoPreviewTile extends StatelessWidget {
  final String? path;
  final XFile? file;
  final VoidCallback onTap;

  const _PhotoPreviewTile({
    this.path,
    this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 88,
              height: 88,
              child: _thumb(),
            ),
          ),
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Material(
            color: Colors.black.withValues(alpha: 0.45),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.zoom_in_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumb() {
    if (!kIsWeb && path != null && path!.isNotEmpty) {
      return Image.file(File(path!), fit: BoxFit.cover);
    }
    if (file != null) {
      return FutureBuilder<List<int>>(
        future: file!.readAsBytes(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return Image.memory(
            Uint8List.fromList(snap.data!),
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        },
      );
    }
    return const Center(
      child: Icon(Icons.image_outlined, color: AppTheme.textMedium),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final String? imageUrl;
  final File? imageFile;
  final bool compact;

  const _AttachmentChip({
    required this.label,
    this.icon,
    this.iconColor,
    this.imageUrl,
    this.imageFile,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 200 : 140),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl!,
                width: 112,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.play_circle_filled_rounded,
                  color: const Color(0xFFFF0000),
                  size: 36,
                ),
              ),
            )
          else if (imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                imageFile!,
                width: 112,
                height: 64,
                fit: BoxFit.cover,
              ),
            )
          else if (icon != null)
            Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryText extends StatelessWidget {
  final String message;
  final String topic;

  const _SummaryText({required this.message, required this.topic});

  @override
  Widget build(BuildContext context) {
    final parts = message.split(topic);
    if (parts.length < 2) {
      return Text(
        message,
        style: GoogleFonts.poppins(
          fontSize: 14,
          height: 1.45,
          color: AppTheme.textMedium,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
          fontSize: 14,
          height: 1.45,
          color: AppTheme.textMedium,
        ),
        children: [
          TextSpan(text: parts.first),
          TextSpan(
            text: topic,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          TextSpan(text: parts.sublist(1).join(topic)),
        ],
      ),
    );
  }
}
