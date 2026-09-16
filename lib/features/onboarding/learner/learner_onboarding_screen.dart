import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _answers = LearnerOnboardingAnswers(
      locale: LanguageService.languageCode,
      accountRole: widget.userRole == 'parent' ? 'parent' : 'learner',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_tts.ensureInitialized());
      _speak();
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
    if (_pack.cities.isNotEmpty) steps.add(LearnerOnboardStep.city);
    if (_pack.systems.length > 1) steps.add(LearnerOnboardStep.system);
    steps.addAll(const [
      LearnerOnboardStep.level,
      LearnerOnboardStep.subject,
      LearnerOnboardStep.exam,
      LearnerOnboardStep.examWhen,
      LearnerOnboardStep.channel,
      LearnerOnboardStep.pace,
      LearnerOnboardStep.examFeel,
      LearnerOnboardStep.interests,
      LearnerOnboardStep.ready,
    ]);
    return steps;
  }

  LearnerOnboardStep get _step => _steps[_index.clamp(0, _steps.length - 1)];

  Future<void> _speak() async {
    final line = switch (_step) {
      LearnerOnboardStep.welcome => _c.welcomeTitle,
      LearnerOnboardStep.language => _c.languageTitle,
      LearnerOnboardStep.who => _c.whoTitle,
      LearnerOnboardStep.name => _c.nameTitle,
      LearnerOnboardStep.country => _c.countryTitle,
      LearnerOnboardStep.city => _c.cityTitle,
      LearnerOnboardStep.system => _c.systemTitle,
      LearnerOnboardStep.level => _c.levelTitle,
      LearnerOnboardStep.subject => _c.subjectTitle,
      LearnerOnboardStep.exam => _c.examTitle,
      LearnerOnboardStep.examWhen => _c.whenTitle,
      LearnerOnboardStep.channel => _c.channelTitle,
      LearnerOnboardStep.pace => _c.paceTitle,
      LearnerOnboardStep.examFeel => _c.feelTitle,
      LearnerOnboardStep.interests => _c.interestTitle,
      LearnerOnboardStep.ready => _c.readyTitle,
    };
    try {
      await _tts.stop();
      await _tts.speakAndWait(line);
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
    unawaited(_speak());
  }

  void _back() {
    if (_index == 0) return;
    setState(() {
      _forward = false;
      _index--;
    });
    unawaited(_speak());
  }

  void _choose(LearnerOnboardingAnswers next) {
    setState(() => _answers = next);
    Future.delayed(const Duration(milliseconds: 360), () {
      if (mounted) _next();
    });
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    final named = _answers.copyWith(name: _name.text.trim());
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
      LearnerOnboardStep.welcome || LearnerOnboardStep.ready => Mood.cheer,
      LearnerOnboardStep.name || LearnerOnboardStep.language => Mood.happy,
      LearnerOnboardStep.exam || LearnerOnboardStep.level => Mood.thinking,
      _ => Mood.happy,
    };
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return Scaffold(
      body: Container(
        decoration: OnboardPalette.page,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PrepSkulWordmark(),
                const SizedBox(height: 12),
                OnboardRail(
                  count: steps.length,
                  at: _index,
                  label: _c.ofCount(_index, steps.length),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final offset = Tween<Offset>(
                        begin: Offset(_forward ? 0.12 : -0.12, 0),
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
                if (_index > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _back,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(_c.back),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
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

  Widget _ask({required String kicker, required String title, String? note, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            prepMate(mood: _mood, size: 76),
            const SizedBox(width: 8),
            Expanded(child: OnboardBubble(title: title, note: note)),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          kicker,
          style: GoogleFonts.poppins(
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _page() {
    final locale = _answers.locale;
    return switch (_step) {
      LearnerOnboardStep.welcome => Column(
          children: [
            const SizedBox(height: 12),
            prepMate(mood: Mood.cheer, size: 168),
            const SizedBox(height: 18),
            OnboardBubble(title: _c.welcomeTitle, note: _c.welcomeNote),
            const SizedBox(height: 28),
            OnboardPrimaryButton(label: _c.welcomeCta, onTap: _next),
          ],
        ),
      LearnerOnboardStep.language => _ask(
          kicker: _c.languageKicker,
          title: _c.languageTitle,
          note: _c.languageNote,
          child: Column(
            children: [
              OnboardChoice(
                title: 'English',
                subtitle: 'English',
                selected: locale == 'en',
                leading: const OnboardGlyph(seed: 'EN'),
                onTap: () => _choose(_answers.copyWith(locale: 'en')),
              ),
              OnboardChoice(
                title: 'Français',
                subtitle: 'French',
                selected: locale == 'fr',
                leading: const OnboardGlyph(seed: 'FR', selected: true),
                onTap: () => _choose(_answers.copyWith(locale: 'fr')),
              ),
            ],
          ),
        ),
      LearnerOnboardStep.who => _ask(
          kicker: _c.whoKicker,
          title: _c.whoTitle,
          note: _c.whoNote,
          child: Column(
            children: [
              OnboardChoice(
                title: _c.whoStudent,
                selected: _answers.accountRole == 'learner',
                artColor: AppTheme.skyBlue,
                onTap: () => _choose(_answers.copyWith(accountRole: 'learner')),
              ),
              OnboardChoice(
                title: _c.whoParent,
                selected: _answers.accountRole == 'parent',
                artColor: AppTheme.softYellow,
                onTap: () => _choose(_answers.copyWith(accountRole: 'parent')),
              ),
            ],
          ),
        ),
      LearnerOnboardStep.name => _ask(
          kicker: _c.nameKicker,
          title: _c.nameTitle,
          child: Column(
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _next(),
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: _c.nameHint,
                  filled: true,
                  fillColor: Colors.white,
                  hintStyle: GoogleFonts.poppins(color: AppTheme.textLight),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OnboardPrimaryButton(label: _c.next, onTap: _next),
            ],
          ),
        ),
      LearnerOnboardStep.country => _ask(
          kicker: _c.countryKicker,
          title: _c.countryTitle,
          note: _c.countryNote,
          child: Column(
            children: [
              for (final pack in regionPacks)
                OnboardChoice(
                  title: pack.label.t(locale),
                  subtitle: pack.id == 'cm'
                      ? (locale == 'fr' ? 'Chez nous' : 'Home')
                      : null,
                  selected: _answers.countryId == pack.id,
                  leading: OnboardGlyph(seed: pack.countryCode, selected: pack.id == 'cm'),
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
          kicker: _c.cityKicker,
          title: _c.cityTitle,
          child: Column(
            children: [
              for (final city in _pack.cities)
                OnboardChoice(
                  title: city.label.t(locale),
                  selected: _answers.cityId == city.id,
                  leading: OnboardGlyph(seed: city.id),
                  onTap: () => _choose(_answers.copyWith(cityId: city.id)),
                ),
            ],
          ),
        ),
      LearnerOnboardStep.system => _ask(
          kicker: _c.systemKicker,
          title: _c.systemTitle,
          note: _c.systemNote,
          child: Column(
            children: [
              for (final system in _pack.systems)
                OnboardChoice(
                  title: system.label.t(locale),
                  selected: _answers.systemId == system.id,
                  onTap: () => _choose(
                    _answers.copyWith(systemId: system.id, clearLevel: true, clearExam: true),
                  ),
                ),
            ],
          ),
        ),
      LearnerOnboardStep.level => _ask(
          kicker: _c.levelKicker,
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
          kicker: _c.subjectKicker,
          title: _c.subjectTitle,
          child: Column(
            children: [
              for (final subject in _system.subjects)
                OnboardChoice(
                  title: subject.label.t(locale),
                  selected: _answers.subjectId == subject.id,
                  leading: OnboardGlyph(seed: subject.id),
                  onTap: () => _choose(_answers.copyWith(subjectId: subject.id)),
                ),
            ],
          ),
        ),
      LearnerOnboardStep.exam => _ask(
          kicker: _c.examKicker,
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
          kicker: _c.whenKicker,
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
          kicker: _c.channelKicker,
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
          kicker: _c.paceKicker,
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
          kicker: _c.feelKicker,
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
          kicker: _c.interestKicker,
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
            prepMate(mood: Mood.cheer, size: 148),
            const SizedBox(height: 16),
            OnboardBubble(title: _c.readyTitle, note: _c.readyNote),
            const SizedBox(height: 24),
            OnboardPrimaryButton(
              label: _saving ? '…' : _c.readyCta,
              onTap: _finish,
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
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}
