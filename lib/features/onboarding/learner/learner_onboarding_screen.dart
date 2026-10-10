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
import 'package:prepskul/features/skulmate/services/tts_service.dart';

enum LearnerOnboardStep {
  welcome,
  language,
  who,
  name,
  meet,
  country,
  city,
  system,
  level,
  subject,
  goal,
  exam,
  examWhen,
  mode,
  channel,
  pace,
  examFeel,
  interests,
  ready,
  paywall,
}

class LearnerOnboardingScreen extends StatefulWidget {
  const LearnerOnboardingScreen({
    super.key,
    this.userRole = 'student',
    this.beforeAuth = false,
  });

  final String userRole;
  final bool beforeAuth;

  @override
  State<LearnerOnboardingScreen> createState() =>
      _LearnerOnboardingScreenState();
}

class _LearnerOnboardingScreenState extends State<LearnerOnboardingScreen> {
  int _index = 0;
  bool _forward = true;
  bool _saving = false;
  late LearnerOnboardingAnswers _answers;
  final _name = TextEditingController();
  final _countryOther = TextEditingController();
  final _cityOther = TextEditingController();
  final _subjectOther = TextEditingController();
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
      unawaited(_initializeOnboarding());
    });
  }

  Future<void> _initializeOnboarding() async {
    await _tts.ensureInitialized();
    final draft = await LearnerOnboardingPersist.loadDraft();
    if (draft != null) {
      if (widget.beforeAuth) {
        final step = await LearnerOnboardingPersist.loadDraftStep();
        if (!mounted) return;
        setState(() {
          _answers = draft;
          _name.text = draft.name;
          _countryOther.text = draft.countryOther ?? '';
          _cityOther.text = draft.cityOther ?? '';
          _subjectOther.text = draft.subjectOther ?? '';
          _index = step.clamp(0, _steps.length - 1);
        });
        return;
      } else {
        final saved = await LearnerOnboardingPersist.save(draft);
        if (saved) {
          if (!mounted) return;
          final role = draft.accountRole == 'parent' ? 'parent' : 'student';
          NavigationService.resetStackNamed(
            context,
            role == 'parent' ? '/parent-nav' : '/student-nav',
          );
          return;
        }
        if (mounted) {
          setState(() {
            _answers = draft;
            _name.text = draft.name;
            _countryOther.text = draft.countryOther ?? '';
            _cityOther.text = draft.cityOther ?? '';
            _subjectOther.text = draft.subjectOther ?? '';
            _index = _steps.length - 1;
          });
          return;
        }
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _countryOther.dispose();
    _cityOther.dispose();
    _subjectOther.dispose();
    unawaited(_tts.stop());
    super.dispose();
  }

  LearnerOnboardingCopy get _c =>
      LearnerOnboardingCopy(_answers.locale == 'fr');
  RegionPack get _pack => packById(_answers.countryId);
  RegionSystem get _system => systemById(_pack, _answers.systemId);

  List<LearnerOnboardStep> get _steps {
    final steps = <LearnerOnboardStep>[
      LearnerOnboardStep.welcome,
      LearnerOnboardStep.language,
      LearnerOnboardStep.who,
      LearnerOnboardStep.name,
      LearnerOnboardStep.meet,
      LearnerOnboardStep.country,
    ];
    if (_pack.systems.length > 1) steps.add(LearnerOnboardStep.system);
    steps.addAll(const [
      LearnerOnboardStep.level,
      LearnerOnboardStep.subject,
      LearnerOnboardStep.goal,
    ]);
    RegionLevel? selectedLevel;
    for (final item in _system.levels) {
      if (item.id == _answers.levelId) selectedLevel = item;
    }
    if (_answers.learningGoalId == 'exam-prep' &&
        selectedLevel?.educationLevel != 'Primary School' &&
        _system.exams.length > 1) {
      steps.add(LearnerOnboardStep.exam);
      steps.add(LearnerOnboardStep.examWhen);
    }
    steps.add(LearnerOnboardStep.mode);
    if (_answers.tutorModeId == 'in-person' || _answers.tutorModeId == 'flexible') {
      steps.add(LearnerOnboardStep.city);
    }
    steps.addAll(const [
      LearnerOnboardStep.channel,
      LearnerOnboardStep.pace,
      LearnerOnboardStep.ready,
      LearnerOnboardStep.paywall,
    ]);
    return steps;
  }

  String get _selectedEducationLevel {
    for (final item in _system.levels) {
      if (item.id == _answers.levelId) return item.educationLevel;
    }
    return '';
  }

  List<RegionOption> get _availableSubjects {
    final primary = _selectedEducationLevel == 'Primary School';
    final upper = _selectedEducationLevel == 'High School';
    if (primary) {
      return [
        ..._system.subjects.where((s) => {'maths', 'french', 'english'}.contains(s.id)),
        const RegionOption(id: 'science', label: Bilingual(en: 'Discovering science', fr: 'Découverte des sciences')),
        const RegionOption(id: 'other', label: Bilingual(en: 'Something else', fr: 'Autre chose')),
      ];
    }
    return _system.subjects.where((s) => upper || s.id != 'philo').toList();
  }

  String get _chosenSubject {
    for (final item in _availableSubjects) {
      if (item.id == _answers.subjectId) {
        return item.id == 'other'
            ? (_answers.subjectOther ?? '').trim()
            : item.label.t(_answers.locale);
      }
    }
    return '';
  }

  String get _chosenLevel {
    for (final item in _system.levels) {
      if (item.id == _answers.levelId) return item.label.t(_answers.locale);
    }
    return '';
  }

  LearnerOnboardStep get _step => _steps[_index.clamp(0, _steps.length - 1)];

  Future<void> _speakWelcome() async {
    await _speakText(_c.welcomeTitle, _c.welcomeNote);
  }

  Future<void> _speakText(String title, String? note) async {
    if (!_answers.voiceOut) return;
    try {
      await _tts.ensureInitialized();
      if (!mounted || !_answers.voiceOut) return;
      await _tts.setLanguage(_answers.locale);
      final text = [
        title,
        if (note != null && note.trim().isNotEmpty) note,
      ].join('. ');
      await _tts.speakAndWait(text);
    } catch (_) {}
  }

  void _next() {
    if (!_canContinue) return;
    if (_index >= _steps.length - 1) {
      unawaited(_finish());
      return;
    }
    unawaited(_tts.stop());
    setState(() {
      _forward = true;
      _index++;
    });
    unawaited(_persistDraft());
  }

  void _back() {
    if (_index == 0) return;
    setState(() {
      _forward = false;
      _index--;
    });
    unawaited(_persistDraft());
  }

  void _choose(LearnerOnboardingAnswers next) {
    setState(() => _answers = next);
    unawaited(_persistDraft());
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _next();
    });
  }

  bool get _canContinue => switch (_step) {
    LearnerOnboardStep.name => _name.text.trim().isNotEmpty,
    LearnerOnboardStep.country =>
      _answers.countryId != 'global' ||
          (_answers.countryOther?.trim().isNotEmpty ?? false),
    LearnerOnboardStep.city =>
      _pack.cities.isEmpty
          ? (_answers.cityOther?.trim().isNotEmpty ?? false)
          : (_answers.cityId != 'other' && _answers.cityId != null) ||
                (_answers.cityOther?.trim().isNotEmpty ?? false),
    LearnerOnboardStep.subject =>
      _answers.subjectId != null &&
          (_answers.subjectId != 'other' ||
              (_answers.subjectOther?.trim().isNotEmpty ?? false)),
    LearnerOnboardStep.goal => _answers.learningGoalId != null,
    LearnerOnboardStep.mode => _answers.tutorModeId != null,
    _ => true,
  };

  Future<void> _persistDraft() async {
    if (!widget.beforeAuth) return;
    await LearnerOnboardingPersist.saveDraft(
      _answers.copyWith(name: _name.text.trim()),
      step: _index,
    );
  }

  Future<void> _finish({String superChoice = 'skip'}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final named = _answers.copyWith(
      name: _name.text.trim(),
      superChoice: superChoice,
    );
    if (widget.beforeAuth) {
      await LearnerOnboardingPersist.saveDraft(named, step: _index);
      await LearnerOnboardingPersist.markOnboardingComplete();
      if (!mounted) return;
      await _goToAuth();
      return;
    }
    final saved = await LearnerOnboardingPersist.save(named);
    if (!mounted) return;
    if (!saved) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _answers.locale == 'fr'
                ? 'Impossible d’enregistrer pour le moment. Réessaie.'
                : 'We couldn’t save that yet. Please try again.',
          ),
        ),
      );
      return;
    }
    final role = named.accountRole == 'parent' ? 'parent' : 'student';
    NavigationService.resetStackNamed(
      context,
      role == 'parent' ? '/parent-nav' : '/student-nav',
    );
  }

  Future<void> _goToAuth({bool asTutor = false}) async {
    if (asTutor) {
      await LearnerOnboardingPersist.clearDraft();
      await LearnerOnboardingPersist.markOnboardingComplete();
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/auth-method-selection',
      (route) => false,
      arguments: const {'isLogin': false},
    );
  }

  Mood get _mood {
    return switch (_step) {
      LearnerOnboardStep.welcome => Mood.wave,
      LearnerOnboardStep.name || LearnerOnboardStep.who => Mood.wave,
      LearnerOnboardStep.meet => Mood.happy,
      LearnerOnboardStep.ready => Mood.cheer,
      LearnerOnboardStep.paywall => Mood.encourage,
      LearnerOnboardStep.country || LearnerOnboardStep.city || LearnerOnboardStep.mode => Mood.point,
      LearnerOnboardStep.goal => Mood.thinking,
      LearnerOnboardStep.subject ||
      LearnerOnboardStep.level ||
      LearnerOnboardStep.exam => Mood.thinking,
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
                    key: ValueKey((_step == LearnerOnboardStep.welcome || _step == LearnerOnboardStep.ready || _step == LearnerOnboardStep.paywall) ? _step.name : 'questions'),
                    child: SingleChildScrollView(child: _page()),
                  ),
                ),
              ),
              if (_index > 0 && _step != LearnerOnboardStep.paywall) ...[
                const SizedBox(height: 12),
                OnboardPrimaryButton(
                  label: _step == LearnerOnboardStep.ready
                      ? _c.readyCta
                      : _c.next,
                  onTap: _next,
                  enabled: _canContinue,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _announcedQuestion;

  Future<void> _toggleVoice(String title, String? note) async {
    setState(() => _answers = _answers.copyWith(voiceOut: !_answers.voiceOut));
    await _persistDraft();
    await _tts.stop();
    if (_answers.voiceOut) await _speakText(title, note);
  }

  Widget _ask({required String title, String? note, required Widget child}) {
    final questionKey = '${_step.name}:${_answers.locale}:$title';
    if (_announcedQuestion != questionKey) {
      _announcedQuestion = questionKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _announcedQuestion == questionKey) {
          unawaited(_speakText(title, null));
        }
      });
    }
    return OnboardAsk(
      title: title,
      mood: _mood,
      speaking: _tts.speaking,
      listenLabel: _answers.voiceOut ? (_c.isFrench ? "Couper le son" : "Mute voice") : (_c.isFrench ? "Activer la voix" : "Unmute voice"),
      voiceEnabled: _answers.voiceOut,
      onListen: () => _toggleVoice(title, null),
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
            listenLabel: _c.listen,
            voiceEnabled: _answers.voiceOut,
            onListen: () => _toggleVoice(_c.welcomeTitle, _c.welcomeNote),
            onTyped: () {
              if (mounted && !_welcomeTyped) {
                setState(() => _welcomeTyped = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) unawaited(_speakWelcome());
                });
              }
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
          if (widget.beforeAuth) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => unawaited(_goToAuth(asTutor: true)),
              child: Text(_c.tutorEntry, style: onboardFont(size: 15)),
            ),
          ],
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
              onTap: () {
                unawaited(
                  _tts.ensureInitialized().then((_) => _tts.setLanguage('en')),
                );
                _choose(_answers.copyWith(locale: 'en'));
              },
            ),
            OnboardChoice(
              title: 'Français',
              glyph: 'fr',
              selected: locale == 'fr',
              onTap: () {
                unawaited(
                  _tts.ensureInitialized().then((_) => _tts.setLanguage('fr')),
                );
                _choose(_answers.copyWith(locale: 'fr'));
              },
            ),
          ],
        ),
      ),
      LearnerOnboardStep.who => _ask(
        title: _c.whoTitle,
        note: _c.whoNote,
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
        title: _answers.accountRole == 'parent'
            ? (_answers.locale == 'fr'
                  ? 'Quel est le prénom de l’élève ?'
                  : 'What’s the learner’s first name?')
            : _c.nameTitle,
        child: Column(
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onChanged: (_) => unawaited(_persistDraft()),
              onSubmitted: (_) => _next(),
              style: onboardFont(size: 20, weight: FontWeight.w800),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: _answers.accountRole == 'parent'
                    ? (_answers.locale == 'fr'
                          ? 'Prénom de l’élève'
                          : 'Learner’s first name')
                    : _c.nameHint,
                filled: true,
                fillColor: Colors.white,
                hintStyle: onboardFont(
                  size: 16,
                  weight: FontWeight.w700,
                  color: AppTheme.textMedium,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0x291B2C4F)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: AppTheme.skyBlue,
                    width: 2,
                  ),
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
      LearnerOnboardStep.meet => _ask(
        title: _c.meetTitle(_name.text.trim()),
        note: _c.meetNote,
        child: const SizedBox.shrink(),
      ),
      LearnerOnboardStep.country => _ask(
        title: _c.countryTitle,
        note: _c.countryNote,
        child: Column(
          children: [
            for (final pack in regionPacks)
              OnboardChoice(
                title: pack.label.t(locale),
                glyph: '${pack.id}_country',
                selected: _answers.countryId == pack.id,
                onTap: () {
                  final next = _answers.copyWith(
                    countryId: pack.id,
                    clearCountryOther: true,
                    clearCity: true,
                    clearCityOther: true,
                    clearSystem: true,
                    clearLevel: true,
                    clearExam: true,
                    clearSubjectOther: true,
                  );
                  if (pack.id == 'global') {
                    setState(() => _answers = next);
                    _countryOther.clear();
                    unawaited(_persistDraft());
                  } else {
                    _choose(next);
                  }
                },
              ),
            if (_answers.countryId == 'global')
              TextField(
                controller: _countryOther,
                textCapitalization: TextCapitalization.words,
                decoration: paperFieldDecoration(
                  hintText: locale == 'fr' ? 'Ton pays' : 'Which country?',
                ),
                onChanged: (value) {
                  setState(
                    () => _answers = _answers.copyWith(countryOther: value),
                  );
                  unawaited(_persistDraft());
                },
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
                onTap: () {
                  final next = _answers.copyWith(
                    cityId: city.id,
                    clearCityOther: true,
                  );
                  if (city.id == 'other') {
                    setState(() => _answers = next);
                    _cityOther.clear();
                    unawaited(_persistDraft());
                  } else {
                    _choose(next);
                  }
                },
              ),
            if (_answers.cityId == 'other' || _pack.cities.isEmpty)
              TextField(
                controller: _cityOther,
                textCapitalization: TextCapitalization.words,
                decoration: paperFieldDecoration(
                  hintText: locale == 'fr' ? 'Ta ville' : 'Your town or city',
                ),
                onChanged: (value) {
                  setState(
                    () => _answers = _answers.copyWith(cityOther: value),
                  );
                  unawaited(_persistDraft());
                },
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
                  _answers.copyWith(
                    systemId: system.id,
                    clearLevel: true,
                    clearExam: true,
                  ),
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
            for (final subject in _availableSubjects)
              OnboardChoice(
                title: subject.label.t(locale),
                glyph: subject.id,
                selected: _answers.subjectId == subject.id,
                onTap: () {
                  final next = _answers.copyWith(
                    subjectId: subject.id,
                    clearSubjectOther: true,
                  );
                  if (subject.id == 'other') {
                    setState(() => _answers = next);
                    _subjectOther.clear();
                    unawaited(_persistDraft());
                  } else {
                    _choose(next);
                  }
                },
              ),
            if (_answers.subjectId == 'other')
              TextField(
                controller: _subjectOther,
                textCapitalization: TextCapitalization.sentences,
                decoration: paperFieldDecoration(
                  hintText: locale == 'fr'
                      ? 'Quelle matière ?'
                      : 'Which subject?',
                ),
                onChanged: (value) {
                  setState(
                    () => _answers = _answers.copyWith(subjectOther: value),
                  );
                  unawaited(_persistDraft());
                },
              ),
          ],
        ),
      ),
      LearnerOnboardStep.goal => _ask(
        title: _c.goalTitle,
        child: Column(
          children: [
            OnboardChoice(
              title: _c.goalLessons,
              glyph: 'book',
              selected: _answers.learningGoalId == 'lessons',
              onTap: () => _choose(
                _answers.copyWith(learningGoalId: 'lessons', clearExam: true),
              ),
            ),
            OnboardChoice(
              title: _c.goalCatchUp,
              glyph: 'maths',
              selected: _answers.learningGoalId == 'catch-up',
              onTap: () => _choose(
                _answers.copyWith(learningGoalId: 'catch-up', clearExam: true),
              ),
            ),
            if (_selectedEducationLevel != 'Primary School')
              OnboardChoice(
                title: _c.goalExam,
                glyph: 'medal',
                selected: _answers.learningGoalId == 'exam-prep',
                onTap: () => _choose(
                  _answers.copyWith(
                    learningGoalId: 'exam-prep',
                    clearExam: true,
                  ),
                ),
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
      LearnerOnboardStep.mode => _ask(
        title: _c.isFrench ? "Souhaites-tu aussi l’aide d’un tuteur ?" : "Would you also like help from a tutor?",
        child: Column(
          children: [
            OnboardChoice(
              title: _c.isFrench ? 'Avec Mate pour le moment' : 'Just Mate for now',
              glyph: 'book',
              selected: _answers.tutorModeId == 'not-now',
              onTap: () => _choose(_answers.copyWith(
                tutorModeId: 'not-now', clearCity: true, clearCityOther: true)),
            ),
            OnboardChoice(
              title: _c.modeOnline,
              glyph: 'online',
              selected: _answers.tutorModeId == 'online',
              onTap: () => _choose(
                _answers.copyWith(
                  tutorModeId: 'online',
                  clearCity: true,
                  clearCityOther: true,
                ),
              ),
            ),
            OnboardChoice(
              title: _c.modeInPerson,
              glyph: 'home',
              selected: _answers.tutorModeId == 'in-person',
              onTap: () => _choose(_answers.copyWith(tutorModeId: 'in-person')),
            ),
            OnboardChoice(
              title: _c.modeFlexible,
              glyph: 'globe',
              selected: _answers.tutorModeId == 'flexible',
              onTap: () => _choose(_answers.copyWith(tutorModeId: 'flexible')),
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
                      setState(
                        () => _answers = _answers.copyWith(interestIds: next),
                      );
                      unawaited(_persistDraft());
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
          OnboardSpeech(
            title: _c.readyTitle(
              _name.text.trim(),
              _chosenSubject,
              _chosenLevel,
            ),
            note: _c.readyNote(_answers.learningGoalId == 'exam-prep'),
            tail: false,
            listenLabel: _c.listen,
            onListen: () => _speakText(
              _c.readyTitle(_name.text.trim(), _chosenSubject, _chosenLevel),
              _c.readyNote(_answers.learningGoalId == 'exam-prep'),
            ),
          ),
        ],
      ),
      LearnerOnboardStep.paywall => Column(
        children: [
          prepMate(mood: Mood.cheer, size: 196),
          const SizedBox(height: 16),
          OnboardSpeech(
            title: _c.payTitle(_name.text.trim()),
            note: _c.payNote(_answers.countryId),
            tail: false,
            listenLabel: _c.listen,
            onListen: () => _speakText(
              _c.payTitle(_name.text.trim()),
              _c.payNote(_answers.countryId),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _c.payBenefits.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: OnboardPalette.card(selected: false),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: switch (i) {
                          0 => const Color(0xFFFEF3C7),
                          1 => const Color(0xFFDBEAFE),
                          _ => const Color(0xFFD1FAE5),
                        },
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        switch (i) {
                          0 => Icons.auto_awesome_rounded,
                          1 => Icons.mic_rounded,
                          _ => Icons.person_search_rounded,
                        },
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _c.payBenefits[i],
                        style: onboardDisplay(size: 16),
                      ),
                    ),
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
            child: Text(
              _c.paySkip,
              style: onboardFont(size: 14, color: AppTheme.textMedium),
            ),
          ),
        ],
      ),
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
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
