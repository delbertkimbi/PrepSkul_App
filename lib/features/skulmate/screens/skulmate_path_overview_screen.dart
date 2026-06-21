import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

import '../l10n/skulmate_copy.dart';
import '../models/lesson_plan_model.dart';
import '../models/skulmate_intake_models.dart';
import '../screens/game_generation_screen.dart';
import '../services/lesson_plan_service.dart';
import '../widgets/skulmate_surface_styles.dart';

/// Turn-by-turn Path screen (Phase D1).
class SkulMatePathOverviewScreen extends StatefulWidget {
  final SkulMateIntakePayload payload;

  const SkulMatePathOverviewScreen({
    super.key,
    required this.payload,
  });

  @override
  State<SkulMatePathOverviewScreen> createState() =>
      _SkulMatePathOverviewScreenState();
}

class _SkulMatePathOverviewScreenState extends State<SkulMatePathOverviewScreen> {
  LessonPlan? _lesson;
  bool _loading = true;
  String? _error;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  Future<void> _loadLesson() async {
    safeSetState(() {
      _loading = true;
      _error = null;
    });

    try {
      final topic = widget.payload.topicHint ?? widget.payload.title;
      final lesson = await LessonPlanService.createLessonPlan(
        topic: topic,
        text: widget.payload.text,
        childId: widget.payload.childId,
      );
      if (!mounted) return;
      safeSetState(() {
        _lesson = lesson;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      safeSetState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _onStepTap(int index) async {
    final lesson = _lesson;
    if (lesson == null || _advancing) return;
    if (index != lesson.currentStep) return;

    final step = lesson.steps[index];
    if (step.isContentOnly) {
      await _showContentSheet(step);
      await _completeStep(index);
      return;
    }

    if (step.isInteractive) {
      await _launchGameForStep(step);
      await _completeStep(index);
    }
  }

  Future<void> _showContentSheet(LessonPlanStep step) async {
    final copy = SkulMateCopy.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (step.body != null && step.body!.trim().isNotEmpty)
                Text(
                  step.body!,
                  style: GoogleFonts.poppins(height: 1.45),
                ),
              if (step.bullets.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...step.bullets.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(
                          child: Text(
                            b,
                            style: GoogleFonts.poppins(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    copy.isFrench ? 'Continuer' : 'Continue',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchGameForStep(LessonPlanStep step) async {
    final payload = widget.payload;
    final topic = _lesson?.topic ?? payload.topicHint ?? payload.title;

    dynamic document;
    if (payload.filesWeb != null && payload.filesWeb!.isNotEmpty) {
      document = payload.filesWeb!.first;
    } else if (payload.files != null && payload.files!.isNotEmpty) {
      document = payload.files!.first;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => GameGenerationScreen(
          documentToUpload: document,
          imageToUpload:
              payload.images != null && payload.images!.length == 1
                  ? payload.images!.first
                  : null,
          imagesToUpload:
              payload.images != null && payload.images!.length > 1
                  ? payload.images
                  : null,
          text: payload.text ?? step.body,
          youtubeUrl: payload.youtubeUrl,
          childId: payload.childId,
          topic: topic,
          gameType: step.gameType ?? 'quiz',
        ),
      ),
    );
  }

  Future<void> _completeStep(int index) async {
    final lesson = _lesson;
    if (lesson == null) return;

    safeSetState(() => _advancing = true);
    try {
      final updated = await LessonPlanService.completeStep(
        lesson: lesson,
        stepIndex: index,
      );
      if (!mounted) return;
      safeSetState(() => _lesson = updated);
    } finally {
      if (mounted) safeSetState(() => _advancing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          copy.modeLabel(SkulMateIntentMode.path),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: _buildBody(copy),
    );
  }

  Widget _buildBody(SkulMateCopy copy) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadLesson,
                child: Text(copy.isFrench ? 'Réessayer' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final lesson = _lesson;
    if (lesson == null) return const SizedBox.shrink();

    final active = lesson.currentStep;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          lesson.topic,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          copy.isFrench
              ? 'Étape ${active + 1} sur ${lesson.steps.length}'
              : 'Step ${active + 1} of ${lesson.steps.length}',
          style: GoogleFonts.poppins(
            color: AppTheme.textMedium,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(lesson.steps.length, (i) {
          final step = lesson.steps[i];
          final isActive = i == active && !step.isCompleted;
          final isDone = step.isCompleted;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isActive ? () => _onStepTap(i) : null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: SkulMateSurfaceStyles.neumorphicCard().copyWith(
                    border: isActive
                        ? Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.35),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isDone
                            ? AppTheme.primaryColor.withValues(alpha: 0.18)
                            : AppTheme.primaryColor.withValues(alpha: 0.12),
                        child: isDone
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: AppTheme.primaryColor,
                              )
                            : Text(
                                '${i + 1}',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (step.body != null &&
                                step.body!.trim().isNotEmpty)
                              Text(
                                step.body!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isActive)
                        Icon(
                          step.isInteractive ? Icons.play_arrow : Icons.chevron_right,
                          color: AppTheme.primaryColor,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (lesson.isComplete) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: SkulMateSurfaceStyles.neumorphicCard(),
            child: Text(
              copy.isFrench
                  ? 'Parcours terminé — bravo !'
                  : 'Path complete — nice work!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ] else if (lesson.activeStep != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _advancing ? null : () => _onStepTap(active),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                copy.modeCta(SkulMateIntentMode.path),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
