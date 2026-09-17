import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prepskul/core/localization/language_service.dart';
import 'package:prepskul/core/navigation/navigation_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_answers.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_copy.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_persist.dart';
import 'package:prepskul/features/onboarding/region/region_packs.dart';
import 'package:prepskul/features/primar/presentation/mascot.dart';
import 'package:prepskul/features/skulmate/services/tts_service.dart';

enum LearnerOnboardStep {
  welcome,
  language,
  who,
  name,
  country,
  city,
  system,
  level,
  subject,
  exam,
  examWhen,
  channel,
  pace,
  examFeel,
  interests,
  ready,
  paywall,
}

class LearnerOnboardingScreen extends StatefulWidget {
  const LearnerOnboardingScreen({super.key, this.userRole = 'student'});

  final String userRole;

  @override
  State<LearnerOnboardingScreen> createState() => _LearnerOnboardingScreenState();
}

class _LearnerOnboardingScreenState extends State<LearnerOnboardingScreen> {
  int _index = 0;
  bool _forward = true;
  bool _saving = false;
  late LearnerOnboardingAnswers _answers;
  final _name = TextEditingController();
  final _tts = TTSService();
  bool _welcomeTyped = false;

  @override
  void initState() {
    super.initState();
    _answers = LearnerOnboardingAnswers(
      locale: LanguageService.languageCode,
      accountRole: widget.userRole == 'parent' ? 'parent' : 'learner',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_tts.ensureInitialized());
      unawaited(_speakWelcome());
    });
  }

  @override
  void dispose() {
    _name.dispose();
    unawaited(_tts.stop());
    super.dispose();
  }

  LearnerOnboardingCopy get _c => LearnerOnboardingCopy(_answers.locale == 'fr');
  RegionPack get _pack => packById(_answers.countryId);
  RegionSystem get _system => systemById(_pack, _answers.systemId);

  List<LearnerOnboardStep> get _steps {
    final steps = <LearnerOnboardStep>[
      LearnerOnboardStep.welcome,
      LearnerOnboardStep.language,
      LearnerOnboardStep.who,
      LearnerOnboardStep.name,
      LearnerOnboardStep.country,
    ];
    if (_pack.systems.length > 1) steps.add(LearnerOnboardStep.system);
    steps.addAll(const [
      LearnerOnboardStep.level,
      LearnerOnboardStep.subject,
      LearnerOnboardStep.ready,
      LearnerOnboardStep.paywall,
    ]);
    return steps;
  }

  LearnerOnboardStep get _step => _steps[_index.clamp(0, _steps.length - 1)];

  Future<void> _speakWelcome() async {
    try {
      await _tts.stop();
      await _tts.speakAndWait(_c.welcomeTitle);
    } catch (_) {}
  }

  void _next() {
    if (_index >= _steps.length - 1) {
      unawaited(_finish());
      return;
    }
    setState(() {
      _forward = true;
      _index++;
    });
  }

  void _back() {
    if (_index == 0) return;
    setState(() {
      _forward = false;
      _index--;
    });
  }

  void _choose(LearnerOnboardingAnswers next) {
    setState(() => _answers = next);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _next();
    });
  }

  Future<void> _finish({String superChoice = 'skip'}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final named = _answers.copyWith(name: _name.text.trim(), superChoice: superChoice);
    await LearnerOnboardingPersist.save(named);
    if (!mounted) return;
    final role = named.accountRole == 'parent' ? 'parent' : 'student';
    NavigationService.resetStackNamed(
      context,
      role == 'parent' ? '/parent-nav' : '/student-nav',
    );
  }

  Mood get _mood {
    return switch (_step) {
      LearnerOnboardStep.welcome => Mood.wave,
      LearnerOnboardStep.ready || LearnerOnboardStep.paywall => Mood.cheer,
      LearnerOnboardStep.subject || LearnerOnboardStep.level || LearnerOnboardStep.exam => Mood.thinking,
      _ => Mood.idle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final progress = _index == 0 ? 0.0 : _index / (steps.length - 1);
    return Scaffold(
      backgroundColor: OnboardPalette.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_index == 0)
                const SizedBox(height: 12)
              else
                OnboardTopBar(progress: progress, onBack: _back),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final offset = Tween<Offset>(
                      begin: Offset(_forward ? 0.08 : -0.08, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_step.name),
                    child: SingleChildScrollView(child: _page()),
                  ),
                ),
              ),
              if (_index > 0 && _step != LearnerOnboardStep.paywall) ...[
                const SizedBox(height: 12),
                OnboardPrimaryButton(
                  label: _step == LearnerOnboardStep.ready ? _c.readyCta : _c.next,
                  onTap: _next,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _ask({required String title, String? note, required Widget child}) {
    return OnboardAsk(
      title: title,
      note: note,
      mood: _mood,
      child: child,
    );
  }

  Widget _page() {
    final locale = _answers.locale;
    return switch (_step) {
      LearnerOnboardStep.welcome => Column(
          children: [
            const SizedBox(height: 16),
            prepMate(mood: _welcomeTyped ? Mood.idle : Mood.wave, size: 228),
            const SizedBox(height: 18),
            OnboardSpeech(
              title: _c.welcomeTitle,
              note: _c.welcomeNote,
              tail: false,
              onTyped: () {
                if (mounted && !_welcomeTyped) setState(() => _welcomeTyped = true);
              },
            ),
            const SizedBox(height: 28),
            AnimatedOpacity(
              opacity: _welcomeTyped ? 1 : 0,
              duration: const Duration(milliseconds: 320),
              child: IgnorePointer(
                ignoring: !_welcomeTyped,
                child: OnboardPrimaryButton(label: _c.welcomeCta, onTap: _next),
              ),
            ),
          ],
        ),
      LearnerOnboardStep.language => _ask(
          title: _c.languageTitle,
          child: Column(
            children: [
              OnboardChoice(
                title: 'English',
                glyph: 'en',
                selected: locale == 'en',
                onTap: () => _choose(_answers.copyWith(locale: 'en')),
              ),
              OnboardChoice(
                title: 'Français',
                glyph: 'fr',
                selected: locale == 'fr',
                onTap: () => _choose(_answers.copyWith(locale: 'fr')),
              ),
            ],
          ),
        ),
      LearnerOnboardStep.who => _ask(
          title: _c.whoTitle,
          child: Column(
            children: [
              OnboardChoice(
                title: _c.whoStudent,
                glyph: 'student',
                selected: _answers.accountRole == 'learner',
                onTap: () => _choose(_answers.copyWith(accountRole: 'learner')),
              ),
              OnboardChoice(
                title: _c.whoParent,
                glyph: 'parent',
                selected: _answers.accountRole == 'parent',
                onTap: () => _choose(_answers.copyWith(accountRole: 'parent')),
              ),
            ],
          ),
        ),
      LearnerOnboardStep.name => _ask(
          title: _c.nameTitle,
          child: Column(
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _next(),
                style: onboardFont(size: 20, weight: FontWeight.w800),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: _c.nameHint,
                  filled: true,
                  fillColor: Colors.white,
                  hintStyle: onboardFont(size: 16, weight: FontWeight.w700, color: AppTheme.textMedium),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0x291B2C4F)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppTheme.skyBlue, width: 2),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0x291B2C4F)),
                  ),
                ),
              ),
            ],
          ),
        ),
      LearnerOnboardStep.country => _ask(
          title: _c.countryTitle,
          note: _c.countryNote,
          child: Column(
            children: [
              for (final pack in regionPacks)
                OnboardChoice(
                  title: pack.label.t(locale),
                  glyph: pack.id,
                  subtitle: pack.id == 'cm'
                      ? (locale == 'fr' ? 'Chez nous' : 'Home')
                      : null,
                  selected: _answers.countryId == pack.id,
                  onTap: () => _choose(
                    _answers.copyWith(
                      countryId: pack.id,
                      clearCity: true,
                      clearSystem: true,
                      clearLevel: true,
                      clearExam: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
      LearnerOnboardStep.city => _ask(
          title: _c.cityTitle,
          child: Column(
            children: [
              for (final city in _pack.cities)
                OnboardChoice(
                  title: city.label.t(locale),
                  selected: _answers.cityId == city.id,
                  onTap: () => _choose(_answers.copyWith(cityId: city.id)),
                ),
            ],
          ),
        ),
      LearnerOnboardStep.system => _ask(
          title: _c.systemTitle,
          note: _c.systemNote,
          child: Column(
            children: [
              for (final system in _pack.systems)
                OnboardChoice(
                  title: system.label.t(locale),
                  glyph: system.id,
                  selected: _answers.systemId == system.id,
                  onTap: () => _choose(
                    _answers.copyWith(systemId: system.id, clearLevel: true, clearExam: true),
                  ),
                ),
            ],
          ),
        ),
      LearnerOnboardStep.level => _ask(
          title: _c.levelTitle,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in _system.levels)
                _Chip(
                  label: level.label.t(locale),
                  selected: _answers.levelId == level.id,
                  onTap: () => _choose(_answers.copyWith(levelId: level.id)),
                ),
            ],
          ),
        ),
      LearnerOnboardStep.subject => _ask(
          title: _c.subjectTitle,
          child: Column(
            children: [
              for (final subject in _system.subjects)
                OnboardChoice(
                  title: subject.label.t(locale),
                  glyph: subject.id,
                  selected: _answers.subjectId == subject.id,
                  onTap: () => _choose(_answers.copyWith(subjectId: subject.id)),
                ),
            ],
          ),
        ),
      LearnerOnboardStep.exam => _ask(
          title: _c.examTitle,
          note: _c.examNote,
          child: Column(
            children: [
              for (final exam in _system.exams)
                OnboardChoice(
                  title: exam.label.t(locale),
                  selected: _answers.examId == exam.id,
                  onTap: () => _choose(_answers.copyWith(examId: exam.id)),
                ),
            ],
          ),
        ),
      LearnerOnboardStep.examWhen => _ask(
          title: _c.whenTitle,
          child: Column(
            children: [
              for (final when in examWhenOptions)
                OnboardChoice(
                  title: when.label.t(locale),
                  selected: _answers.examWhenId == when.id,
                  onTap: () => _choose(_answers.copyWith(examWhenId: when.id)),
                ),
            ],
          ),
        ),
      LearnerOnboardStep.channel => _ask(
          title: _c.channelTitle,
          note: _c.channelNote,
          child: Column(
            children: [
              for (final channel in channelOptions)
                OnboardChoice(
                  title: channel.label.t(locale),
                  selected: _answers.channelId == channel.id,
                  onTap: () => _choose(_answers.copyWith(channelId: channel.id)),
                ),
            ],
          ),
        ),
      LearnerOnboardStep.pace => _ask(
          title: _c.paceTitle,
          child: Column(
            children: [
              for (final pace in paceOptions)
                OnboardChoice(
                  title: pace.label.t(locale),
                  selected: _answers.paceId == pace.id,
                  onTap: () => _choose(_answers.copyWith(paceId: pace.id)),
                ),
            ],
          ),
        ),
      LearnerOnboardStep.examFeel => _ask(
          title: _c.feelTitle,
          child: Column(
            children: [
              for (final feel in examFeelOptions)
                OnboardChoice(
                  title: feel.label.t(locale),
                  selected: _answers.examFeelId == feel.id,
                  onTap: () => _choose(_answers.copyWith(examFeelId: feel.id)),
                ),
              TextButton(onPressed: _next, child: Text(_c.skip)),
            ],
          ),
        ),
      LearnerOnboardStep.interests => _ask(
          title: _c.interestTitle,
          note: _c.interestNote,
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final interest in _pack.interests)
                    _Chip(
                      label: interest.label.t(locale),
                      selected: _answers.interestIds.contains(interest.id),
                      onTap: () {
                        final next = [..._answers.interestIds];
                        if (next.contains(interest.id)) {
                          next.remove(interest.id);
                        } else {
                          next.add(interest.id);
                        }
                        setState(() => _answers = _answers.copyWith(interestIds: next));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              OnboardPrimaryButton(label: _c.next, onTap: _next),
            ],
          ),
        ),
      LearnerOnboardStep.ready => Column(
          children: [
            prepMate(mood: Mood.cheer, size: 228),
            const SizedBox(height: 16),
            OnboardSpeech(title: _c.readyTitle, note: _c.readyNote, tail: false),
          ],
        ),
      LearnerOnboardStep.paywall => Column(
          children: [
            prepMate(mood: Mood.cheer, size: 196),
            const SizedBox(height: 16),
            OnboardSpeech(
              title: _c.payTitle(_name.text.trim()),
              note: _c.payNote,
              tail: false,
            ),
            const SizedBox(height: 16),
            for (final item in _c.payBenefits)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: OnboardPalette.card(selected: false),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF9C3),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryColor, width: 2),
                        ),
                        child: Text('★', style: onboardDisplay(size: 16)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item, style: onboardDisplay(size: 16))),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OnboardPrimaryButton(
              label: _c.payCta,
              onTap: () => unawaited(_finish(superChoice: 'try')),
            ),
            TextButton(
              onPressed: () => unawaited(_finish(superChoice: 'skip')),
              child: Text(_c.paySkip, style: onboardFont(size: 14, color: AppTheme.textMedium)),
            ),
          ],
        ),
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: OnboardPalette.card(selected: selected),
        child: Text(label, style: onboardFont(size: 14)),
      ),
    );
  }
}
