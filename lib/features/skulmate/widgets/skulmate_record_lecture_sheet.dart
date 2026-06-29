import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_intake_models.dart';
import '../services/skulmate_access_service.dart';
import '../services/skulmate_intake_coordinator.dart';
import '../services/skulmate_lecture_recording_service.dart';
import '../services/skulmate_lecture_transcription_service.dart';
import '../widgets/skulmate_generation_error_panel.dart';
import '../widgets/skulmate_paywall_sheet.dart';
import 'skulmate_sheet_scaffold.dart';
import 'skulmate_surface_styles.dart';

enum _RecordPhase { idle, recording, complete, transcribing }

/// Gizmo-style record lecture sheet — before, during, after recording.
class SkulMateRecordLectureSheet extends StatefulWidget {
  final String? childId;

  const SkulMateRecordLectureSheet({super.key, this.childId});

  static Future<void> show(BuildContext context, {String? childId}) {
    return SkulMateSheetScaffold.show<void>(
      context,
      child: SkulMateRecordLectureSheet(childId: childId),
    );
  }

  @override
  State<SkulMateRecordLectureSheet> createState() =>
      _SkulMateRecordLectureSheetState();
}

class _SkulMateRecordLectureSheetState extends State<SkulMateRecordLectureSheet> {
  static const _minRecordingSeconds = 15;

  _RecordPhase _phase = _RecordPhase.idle;
  Timer? _timer;
  int _seconds = 0;
  String? _filePath;
  bool _busy = false;
  String? _errorTitle;
  String? _errorDetails;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerLabel {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await SkulMateLectureRecordingService.ensurePermission();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SkulMateCopy.read(context).micPermissionDenied)),
        );
        return;
      }
      final path = await SkulMateLectureRecordingService.start();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
      if (mounted) {
        setState(() {
          _phase = _RecordPhase.recording;
          _filePath = path;
          _seconds = 0;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SkulMateCopy.read(context).recordingFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopRecording() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _timer?.cancel();
      final path = await SkulMateLectureRecordingService.stop();
      if (mounted) {
        setState(() {
          _phase = _RecordPhase.complete;
          _filePath = path ?? _filePath;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _recordAgain() {
    _timer?.cancel();
    setState(() {
      _phase = _RecordPhase.idle;
      _seconds = 0;
      _filePath = null;
    });
  }

  Future<void> _generateNotes() async {
    final path = _filePath;
    if (path == null || path.isEmpty) return;

    final copy = SkulMateCopy.read(context);

    if (_seconds < _minRecordingSeconds) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.recordingTooShort)),
      );
      return;
    }

    final access = await SkulmateAccessService.checkGenerationAccess(
      sourceType: SkulmateSourceType.text,
    );
    if (!access.canProceed && mounted) {
      await SkulMatePaywallSheet.show(context, message: access.message);
      return;
    }

    setState(() {
      _phase = _RecordPhase.transcribing;
      _busy = true;
      _errorTitle = null;
      _errorDetails = null;
    });

    try {
      final result =
          await SkulMateLectureTranscriptionService.transcribeLocalFile(
        localPath: path,
        childId: widget.childId,
        title: copy.lectureRecordingTitle,
        durationSeconds: _seconds,
      );

      if (!mounted) return;
      Navigator.pop(context);

      await SkulMateIntakeCoordinator.start(
        context,
        SkulMateIntakePayload(
          source: SkulMateIntakeSource.lecture,
          text: result.text,
          title: copy.lectureRecordingTitle,
          childId: widget.childId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _phase = _RecordPhase.complete;
        _busy = false;
        _errorTitle = copy.lectureErrorTitle(msg);
        _errorDetails = copy.lectureErrorDetails(msg);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return SkulMateSheetScaffold(
      title: copy.recordLecture,
      maxHeightFactor: 0.58,
      body: Column(
          children: [
            const SizedBox(height: 12),
            _MicCircle(phase: _phase),
            const SizedBox(height: 20),
            if (_phase == _RecordPhase.transcribing) ...[
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              Text(
                copy.transcribingNotes,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ] else if (_phase == _RecordPhase.recording)
              Text(
                _timerLabel,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )
            else if (_phase == _RecordPhase.complete) ...[
              Text(
                copy.recordingComplete,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                copy.recordingDuration(_timerLabel),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
            if (_errorTitle != null) ...[
              const SizedBox(height: 16),
              SkulMateGenerationErrorPanel(
                title: _errorTitle!,
                details: _errorDetails,
                kind: SkulMateGenerationErrorPanel.kindFromMessage(
                  '${_errorTitle ?? ''} ${_errorDetails ?? ''}',
                ),
                retryable: true,
                onRetry: _generateNotes,
                onBack: () => Navigator.pop(context),
              ),
            ],
          ],
        ),
      footer: _buildActions(copy),
    );
  }

  Widget _buildActions(SkulMateCopy copy) {
    if (_phase == _RecordPhase.transcribing) {
      return const SizedBox.shrink();
    }

    switch (_phase) {
      case _RecordPhase.idle:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _startRecording,
            icon: const Icon(Icons.mic_rounded, size: 20),
            label: Text(
              copy.startRecording,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: SkulMateSurfaceStyles.sheetPrimaryButton(enabled: !_busy),
          ),
        );
      case _RecordPhase.recording:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _stopRecording,
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: Text(
              copy.stopRecording,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: SkulMateSurfaceStyles.sheetSecondaryButton(),
          ),
        );
      case _RecordPhase.complete:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _busy ? null : _generateNotes,
              style: SkulMateSurfaceStyles.sheetPrimaryButton(enabled: !_busy),
              child: Text(
                copy.generateNotes,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _recordAgain,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                copy.recordAgain,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: SkulMateSurfaceStyles.sheetSecondaryButton(),
            ),
          ],
        );
      case _RecordPhase.transcribing:
        return const SizedBox.shrink();
    }
  }
}

class _MicCircle extends StatelessWidget {
  final _RecordPhase phase;

  const _MicCircle({required this.phase});

  @override
  Widget build(BuildContext context) {
    final recording = phase == _RecordPhase.recording;
    final complete =
        phase == _RecordPhase.complete || phase == _RecordPhase.transcribing;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: recording
            ? const Color(0xFFFFEBEE)
            : AppTheme.neutral100,
        shape: BoxShape.circle,
      ),
      child: Icon(
        complete ? Icons.mic_rounded : Icons.mic_none_rounded,
        size: 44,
        color: recording ? const Color(0xFFE53935) : AppTheme.textDark,
      ),
    );
  }
}
