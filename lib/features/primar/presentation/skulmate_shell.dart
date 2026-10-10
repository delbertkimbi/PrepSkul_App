import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/screener.dart';
import '../services/evidence_store.dart';
import '../services/learner_profile_store.dart';
import '../services/primar_voice.dart';
import 'onboarding.dart';
import 'learning_journey.dart';
import 'primar_theme.dart';

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
  bool _booting = true;

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

    return LearningJourney(
      name: answers.name.trim().isEmpty ? 'there' : answers.name.trim(),
      onAskTutor: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: PrimarTheme.navy,
            content: Text(
              'Tutor help is ready to match to this topic. Choose a tutor before anything is shared.',
              style: PrimarTheme.body(14, color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}
