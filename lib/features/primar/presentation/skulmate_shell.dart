import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/screener.dart';
import '../domain/subjects.dart';
import '../services/evidence_store.dart';
import '../services/learner_profile_store.dart';
import '../services/primar_voice.dart';
import '../services/tutor_directory.dart';
import 'onboarding.dart';
import 'primar_motion.dart';
import 'primar_screen.dart';
import 'primar_theme.dart';
import 'profile_screen.dart';
import 'tutor_screen.dart';

/// The app around the lesson.
///
/// ## What this is fixing
///
/// SkulMate was one screen. It opened on a questionnaire, ran a session, showed
/// a result, and went back to the questionnaire. There was no home, no profile,
/// no way to reach a person, and no sense that anything persisted between one
/// use and the next — which is what "nothing reflects that it's an app" means.
///
/// A shell is not decoration. Tabs are what make a product feel like somewhere
/// you are rather than something you are being taken through, and the tab bar
/// is the one control a child learns in a day and then never has to be taught
/// again.
///
/// ## Why onboarding sits outside the tabs
///
/// It runs once, it is answered by a parent, and it is the only screen where
/// having somewhere else to go would produce a broken learner record. So it
/// takes the whole screen, and the tabs appear behind it once it is done.
class SkulMateShell extends StatefulWidget {
  const SkulMateShell({super.key});

  @override
  State<SkulMateShell> createState() => _SkulMateShellState();
}

class _SkulMateShellState extends State<SkulMateShell> {
  ScreenerAnswers? _answers;
  bool _seenDemo = false;
  bool _booting = true;
  int _tab = 0;
  Subject? _activeSubject;

  /// Rebuilt when the tab is re-entered, so the path and the profile pick up
  /// what the last session wrote rather than showing a snapshot from before it.
  Key _learnKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final profile = await LearnerProfileStore.instance.load();
    if (!mounted) return;

    if (profile != null) {
      await EvidenceStore.instance.bindChild(profile.answers.name);
      PrimarVoice.instance.init(
        locale: profile.answers.locale,
        voiceId: profile.answers.voiceId,
      );
      setState(() {
        _answers = profile.answers;
        _seenDemo = profile.seenDemo;
        _activeSubject = profile.answers.subject;
        _booting = false;
      });
      return;
    }

    setState(() => _booting = false);
  }

  Future<void> _completeOnboarding(ScreenerAnswers a) async {
    PrimarVoice.instance.newScene();
    // Show Learn immediately — prefs writes must not gate the first home frame.
    setState(() {
      _answers = a;
      _activeSubject = a.subject;
      _seenDemo = false;
    });
    unawaited(PrimarVoice.instance.init(locale: a.locale, voiceId: a.voiceId));
    unawaited(LearnerProfileStore.instance.saveAnswers(a, seenDemo: false));
    unawaited(EvidenceStore.instance.bindChild(a.name));
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(
        backgroundColor: PrimarTheme.paper,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final answers = _answers;

    if (answers == null) {
      return Scaffold(
        backgroundColor: PrimarTheme.paper,
        body: PaperGround(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 44),
                  child: Onboarding(onDone: _completeOnboarding),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final subject = _activeSubject ?? answers.subject;

    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: switch (_tab) {
        0 => PrimarScreen(
            key: _learnKey,
            answers: answers,
            activeSubject: subject,
            seenDemo: _seenDemo,
            onSeenDemo: () async {
              _seenDemo = true;
              await LearnerProfileStore.instance.markSeenDemo();
            },
          ),
        1 => _Tab(
            child: TutorScreen(
              locale: answers.locale,
              activeSubject: subject,
              onAsk: (tutor) => _ask(context, tutor),
            ),
          ),
        2 => _Tab(
            child: ProfileScreen(
              name: answers.name.trim().isEmpty ? 'You' : answers.name.trim(),
              locale: answers.locale,
              voiceId: answers.voiceId,
              subject: subject,
              onSubjectChanged: (s) => setState(() {
                _activeSubject = s;
                _learnKey = UniqueKey();
              }),
            ),
          ),
        _ => const SizedBox.shrink(),
      },
      bottomNavigationBar: _NavBar(
        index: _tab,
        onChanged: (i) => setState(() {
          _tab = i;
          if (i == 0) _learnKey = UniqueKey();
        }),
      ),
    );
  }

  void _ask(BuildContext context, TutorCard tutor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PrimarTheme.navy,
        content: Text(
          'Ask a grown-up to book ${tutor.name} in the PrepSkul app.',
          style: PrimarTheme.body(14, color: Colors.white),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PaperGround(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Three tabs, drawn large — with a sliding indicator like Brilliant's nav.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.school_rounded, 'Learn'),
    (Icons.support_agent_rounded, 'Ask'),
    (Icons.person_rounded, 'You'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PrimarTheme.sheet,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.4)),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabW = constraints.maxWidth / _items.length;
            return SizedBox(
              height: 62,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: PrimarMotion.medium,
                    curve: PrimarMotion.enter,
                    left: tabW * index + tabW * 0.2,
                    width: tabW * 0.6,
                    top: 4,
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: PrimarTheme.blue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Expanded(
                          child: InkWell(
                            onTap: () => onChanged(i),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedScale(
                                  scale: i == index ? 1.08 : 1.0,
                                  duration: PrimarMotion.fast,
                                  curve: PrimarMotion.bounce,
                                  child: Icon(
                                    _items[i].$1,
                                    size: 26,
                                    color: i == index
                                        ? PrimarTheme.blue
                                        : PrimarTheme.ghostInk,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _items[i].$2,
                                  style: PrimarTheme.body(
                                    11.5,
                                    color: i == index
                                        ? PrimarTheme.blue
                                        : PrimarTheme.ghostInk,
                                    weight: i == index
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
