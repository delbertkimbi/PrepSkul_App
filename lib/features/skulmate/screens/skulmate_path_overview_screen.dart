import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';
import '../models/lesson_plan_model.dart';
import '../models/skulmate_intake_models.dart';
import '../services/lesson_plan_service.dart';
import 'skulmate_home_screen.dart';

/// Opens the current lesson from the Learn map. Legacy games are not a lesson.
class SkulMatePathOverviewScreen extends StatefulWidget {
  final SkulMateIntakePayload payload;
  final LessonPlan? initialLesson;
  const SkulMatePathOverviewScreen({
    super.key,
    required this.payload,
    this.initialLesson,
  });
  @override
  State<SkulMatePathOverviewScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<SkulMatePathOverviewScreen> {
  LessonPlan? _lesson;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool get fr => Localizations.localeOf(context).languageCode == 'fr';

  @override
  void initState() {
    super.initState();
    _lesson = widget.initialLesson;
    if (_lesson != null) {
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lesson = await LessonPlanService.createLessonPlan(
        topic: widget.payload.topicHint ?? widget.payload.title,
        text: widget.payload.text,
        childId: widget.payload.childId,
      );
      if (mounted)
        setState(() {
          _lesson = lesson;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = fr
              ? 'Ton parcours n’a pas pu être enregistré. Réessaie.'
              : 'Your path couldn’t be saved. Please retry.';
        });
    }
  }

  Future<void> _complete(int index, {String? sessionId, String? turnId}) async {
    if (_saving ||
        _lesson == null ||
        _lesson!.steps[index].status == 'completed')
      return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await LessonPlanService.completeStep(
        lesson: _lesson!,
        stepIndex: index,
        sessionId: sessionId,
        turnId: turnId,
      );
      if (mounted) setState(() => _lesson = updated);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = fr
              ? 'Cette étape n’a pas été enregistrée. Réessaie.'
              : 'This step wasn’t saved. Please retry.',
        );
      rethrow;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;
    if (!_loading && lesson != null && lesson.steps.isNotEmpty) {
      final index = lesson.currentStep;
      final step = lesson.steps[index];
      if (step.isInteractive && step.status != 'completed') {
        return SkulMateHomeScreen(
          key: ValueKey('${lesson.id}-$index'),
          lessonId: lesson.id,
          lessonStep: index,
          childId: widget.payload.childId,
          initialMessage:
              'Help me practise ${lesson.topic}: ${step.title}. '
              'Check what I understand, then give one short multiple-choice practice. '
              'Do not reveal the answer before I try. ${step.body ?? ''}',
          onPracticeSaved: (sessionId, turnId) =>
              _complete(index, sessionId: sessionId, turnId: turnId),
        );
      }
    }
    final finished =
        lesson != null &&
        lesson.steps.isNotEmpty &&
        lesson.steps.every((s) => s.status == 'completed');
    final step = lesson != null && lesson.steps.isNotEmpty
        ? lesson.steps[lesson.currentStep]
        : null;
    return Scaffold(
      backgroundColor: OnboardPalette.cream,
      appBar: AppBar(
        backgroundColor: OnboardPalette.cream,
        foregroundColor: AppTheme.primaryColor,
        title: Text(
          lesson?.topic ?? (fr ? 'Ton parcours' : 'Your learning path'),
          style: onboardFont(size: 17),
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    children: [
                      ExcludeSemantics(
                        child: AliveMate(
                          mood: finished ? Mood.happy : Mood.thinking,
                          size: 112,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: OnboardPalette.paperCard,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              finished
                                  ? (fr
                                        ? 'Un bon pas en avant.'
                                        : 'A good step forward.')
                                  : step?.type == 'recap'
                                  ? (fr
                                        ? 'Revoir ensemble'
                                        : 'Look back together')
                                  : step?.title ??
                                        (fr
                                            ? 'On réessaie ?'
                                            : 'Let’s try again'),
                              style: onboardDisplay(size: 28),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              finished
                                  ? (fr
                                        ? 'Ton travail est enregistré. Reviens au parcours ou apporte ta prochaine question à Mate.'
                                        : 'Your work is saved. Return to your path, or bring your next question to Mate.')
                                  : step?.type == 'recap'
                                  ? (fr
                                        ? 'Qu’est-ce qui est plus clair maintenant ? Qu’aimerais-tu encore travailler ?'
                                        : 'What feels clearer now? What would you like to work on next?')
                                  : step?.body ?? '',
                              style: onboardFont(
                                size: 17,
                                weight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                            if (!finished && step?.type != 'recap')
                              ...?step?.bullets.map(
                                (text) => Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Text(
                                    text,
                                    style: onboardFont(
                                      size: 16,
                                      weight: FontWeight.w500,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(_error!, style: onboardFont(size: 15)),
                        ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving
                            ? null
                            : finished
                            ? () => Navigator.pop(context)
                            : lesson == null
                            ? _load
                            : () async {
                                try {
                                  await _complete(lesson.currentStep);
                                } catch (_) {}
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Text(
                          _saving
                              ? (fr ? 'Enregistrement…' : 'Saving…')
                              : finished
                              ? (fr ? 'Revenir au parcours' : 'Back to my path')
                              : lesson == null
                              ? (fr ? 'Réessayer' : 'Retry')
                              : (fr
                                    ? 'J’ai lu cette étape'
                                    : 'I’ve read this step'),
                          style: onboardFont(size: 17, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
