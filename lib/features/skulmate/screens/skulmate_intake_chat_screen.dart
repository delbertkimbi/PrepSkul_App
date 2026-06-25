import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_analysis.dart';
import '../models/skulmate_intake_models.dart';
import '../services/skulmate_intake_analysis_service.dart';
import '../services/skulmate_intake_coordinator.dart';
import '../widgets/skulmate_generation_error_panel.dart';
import '../widgets/skulmate_intent_sheet.dart';
import '../widgets/skulmate_mascot_media_widget.dart';
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
  static const _selectableModes = [
    SkulMateIntentMode.play,
    SkulMateIntentMode.drill,
    SkulMateIntentMode.scroll,
    SkulMateIntentMode.path,
  ];

  static const _selectedGreen = Color(0xFF22C55E);

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
        _errorTitle = copy.lectureErrorTitle(msg);
        _errorDetails = copy.lectureErrorDetails(msg);
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
          copy.intakeChatTitle,
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
                      onPressed: SkulMateIntentSheet.isComingSoonMode(_selected)
                          ? null
                          : _startGeneration,
                      style: SkulMateSurfaceStyles.sheetPrimaryButton(
                        enabled: !SkulMateIntentSheet.isComingSoonMode(_selected),
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
                    message: copy.intakeChatSummary(_analysis!.topicLabel),
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
    final comingSoon = SkulMateIntentSheet.isComingSoonMode(mode);
    final selected = !comingSoon && _selected == mode;
    final topic = _analysis?.topicLabel ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: comingSoon ? null : () => setState(() => _selected = mode),
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: comingSoon ? 0.55 : 1,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? _selectedGreen.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? _selectedGreen : AppTheme.softBorder,
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: _selectedGreen.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                Text(_emoji(mode), style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.modeLabel(mode),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        copy.modeCardSubtitle(mode, topic),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (comingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.neutral100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      copy.comingSoon,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _emoji(SkulMateIntentMode mode) {
    switch (mode) {
      case SkulMateIntentMode.play:
        return '🎮';
      case SkulMateIntentMode.scroll:
        return '📱';
      case SkulMateIntentMode.path:
        return '🗺️';
      case SkulMateIntentMode.drill:
        return '🃏';
      case SkulMateIntentMode.sheet:
        return '📄';
      case SkulMateIntentMode.fromClass:
        return '🎓';
    }
  }
}

class _UserAttachmentBubble extends StatelessWidget {
  final SkulMateIntakeAttachment attachment;

  const _UserAttachmentBubble({required this.attachment});

  @override
  Widget build(BuildContext context) {
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
