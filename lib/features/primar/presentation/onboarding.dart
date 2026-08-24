import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/screener.dart';
import '../domain/teaching_voice.dart';
import '../domain/subjects.dart';
import '../services/primar_voice.dart';
import 'choice_art.dart';
import 'mascot.dart';
import 'paper_decor.dart';
import 'primar_motion.dart';
import 'primar_strings.dart';
import 'primar_theme.dart';
import 'subject_badge.dart';
import 'record_voice_screen.dart';
import 'voice_avatar.dart';

/// One question at a time.
///
/// The first version put age, subject and name on a single screen with three
/// headings and a text field. It worked, and it was the wrong shape: a dense
/// form is a wall to a parent who reads slowly or not at all, it gives the
/// voice nothing specific to say, and it collects the bare minimum because
/// every extra field makes the wall taller.
///
/// One question per page inverts all three. Each page has a single thing to
/// answer, so the voice can read *that question* rather than a generic
/// welcome; each answer is a picture rather than a sentence; and asking five
/// questions costs less than asking three did, because none of them is ever on
/// screen at the same time as another.
///
/// The answers feed [Screener], which chooses which questions the child's
/// warm-up asks. They never choose what the child is allowed to see.
class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.onDone});

  final void Function(ScreenerAnswers) onDone;

  @override
  State<Onboarding> createState() => _OnboardingState();
}

enum _Step { language, voice, name, age, school, subject, seen }

class _OnboardingState extends State<Onboarding> {
  int _index = 0;
  bool _forward = true;
  ScreenerAnswers _answers = const ScreenerAnswers();

  /// True while the parent is recording their own lines. Sits over the voice
  /// page rather than being a step of its own, because it is optional and can
  /// be abandoned at any point.
  bool _recording = false;
  final TextEditingController _name = TextEditingController();

  static const _steps = _Step.values;

  _Step get _step => _steps[_index];

  S get _s => S(_answers.locale);

  @override
  void initState() {
    super.initState();
    // Voice from the first page, not after onboarding finishes. [PrimarVoice.say]
    // is a no-op until [init] runs — a parent who cannot read hears silence on
    // step one and learns the app is broken before it starts.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PrimarVoice.instance.init(
        locale: _answers.locale,
        voiceId: _answers.voiceId,
      );
      if (mounted) _speak();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Each page says its own question. Two lines on the age page, because the
  /// reassurance is the point of that page — a parent should not think their
  /// answer is a verdict.
  void _speak() {
    final line = switch (_step) {
      _Step.language => VoiceLines.askLanguage,
      _Step.voice => VoiceLines.askVoice,
      _Step.name => VoiceLines.askName,
      _Step.age => VoiceLines.askAge,
      _Step.school => VoiceLines.askSchool,
      _Step.subject => VoiceLines.askSubject,
      _Step.seen => switch (_answers.subject) {
          Subject.reading => VoiceLines.askSeenReading,
          Subject.numeracy => VoiceLines.askSeenNumbers,
          Subject.shapes => VoiceLines.askSeenShapes,
        },
    };
    PrimarVoice.instance.interrupt().then((_) {
      if (!mounted) return;
      if (_step == _Step.age) {
        PrimarVoice.instance.sayAll([line, VoiceLines.askAgeWhy]);
      } else {
        PrimarVoice.instance.say(line);
      }
    });
  }

  void _next() {
    if (_index == _steps.length - 1) {
      widget.onDone(_answers.copyWith(name: _name.text));
      return;
    }
    setState(() {
      _forward = true;
      _index++;
    });
    _speak();
  }

  void _back() {
    if (_index == 0) return;
    PrimarVoice.instance.chime(Sfx.tap);
    setState(() {
      _forward = false;
      _index--;
    });
    _speak();
  }

  /// Choosing advances on its own after a beat.
  ///
  /// The beat matters: tapping and being thrown straight onto the next page
  /// makes a parent doubt the tap registered, so the selection is allowed to
  /// finish animating first.
  void _choose(ScreenerAnswers next) {
    PrimarVoice.instance.chime(Sfx.tap);
    final voiceChanged =
        next.locale != _answers.locale || next.voiceId != _answers.voiceId;
    setState(() => _answers = next);
    // The voice has to switch with the choice, not at the end of onboarding —
    // every page after this one is spoken, and a French parent hearing the
    // next four questions in English has learned that the picker does nothing.
    if (voiceChanged) {
      unawaited(PrimarVoice.instance.init(
        locale: next.locale,
        voiceId: next.voiceId,
      ));
    }
    Future.delayed(const Duration(milliseconds: 380), () {
      if (mounted) _next();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The wordmark alone up here now — Mate has moved down to ask the
        // question, and two of him on one screen is one too many.
        const Center(
          child: ColorWordmark(
            words: [('Skul', PrimarTheme.navy), ('Mate', PrimarTheme.blue)],
            size: 19,
          ),
        ),
        const SizedBox(height: 14),
        _Rail(count: _steps.length, at: _index),
        const SizedBox(height: 18),
        AnimatedSize(
          duration: PrimarMotion.medium,
          curve: PrimarMotion.enter,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: PrimarMotion.medium,
            switchInCurve: PrimarMotion.enter,
            switchOutCurve: PrimarMotion.exit,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, if (current != null) current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(_forward ? 0.14 : -0.14, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_recording ? 'recording' : _step.name),
              child: _recording
                  ? RecordVoiceScreen(
                      onDone: () {
                        setState(() => _recording = false);
                        PrimarVoice.instance
                            .init(locale: _answers.locale, voiceId: _answers.voiceId);
                        _next();
                      },
                    )
                  : _page(),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // A real control, not a grey word.
        //
        // Back used to be muted body text with a small doodle arrow, centred
        // under the card — the same weight as a caption, which is what it read
        // as. On a phone in daylight it was close to invisible, and a parent
        // who mistyped a name had no visible way back.
        //
        // It is now a round button the size of a thumb, with an outline that
        // survives a bright screen. It is deliberately quieter than the teal
        // primary action: going back should be findable, not tempting.
        if (_index > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: _RoundStep(
              icon: Icons.arrow_back_rounded,
              label: _s.back,
              onTap: _back,
            ),
          ),
      ],
    );
  }

  Mood _moodForStep(_Step step) => switch (step) {
        _Step.language || _Step.voice || _Step.name || _Step.seen => Mood.happy,
        _Step.age || _Step.school => Mood.thinking,
        _Step.subject => Mood.happy,
      };

  Widget _page() => switch (_step) {
        _Step.language => _Question(
            mood: _moodForStep(_Step.language),
            kicker: _s.pickLanguageKicker,
            title: _s.pickLanguage,
            note: _s.pickLanguageNote,
            child: Column(
              children: [
                for (final (code, label, native) in const [
                  ('en', 'English', 'English'),
                  ('fr', 'French', 'Français'),
                ])
                  _LanguageCard(
                    label: label,
                    native: native,
                    selected: _answers.locale == code,
                    onTap: () => _choose(_answers.copyWith(locale: code)),
                  ),
              ],
            ),
          ),
        _Step.voice => _Question(
            mood: _moodForStep(_Step.voice),
            kicker: _s.voiceKicker,
            title: _s.voiceTitle,
            note: _s.voiceNote,
            child: Column(
              children: [
                for (final v in voicesFor(_answers.locale))
                  _VoiceCard(
                    voice: v,
                    selected: _answers.voiceId == v.id,
                    onTap: () {
                      // Choosing the parent voice opens the recorder, because
                      // choosing it without recording anything would select a
                      // voice that cannot say a word.
                      if (v.needsRecording) {
                        PrimarVoice.instance.chime(Sfx.tap);
                        setState(() {
                          _answers = _answers.copyWith(voiceId: v.id);
                          _recording = true;
                        });
                        return;
                      }
                      _choose(_answers.copyWith(voiceId: v.id));
                    },
                    onPreview: () {
                      // Hearing it is the only way to choose it. A list of
                      // names tells a parent nothing about which voice their
                      // child will actually want to listen to.
                      PrimarVoice.instance.init(
                        locale: _answers.locale,
                        voiceId: v.id,
                      );
                      PrimarVoice.instance.say(VoiceLines.voiceSample);
                    },
                  ),
              ],
            ),
          ),
        _Step.name => _Question(
            mood: _moodForStep(_Step.name),
            kicker: _s.nameKicker,
            title: _s.nameTitle,
            note: _s.nameNote,
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  autofocus: false,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _next(),
                  style: PrimarTheme.display(24, color: PrimarTheme.navy),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: _s.nameHint,
                    hintStyle: PrimarTheme.display(24,
                        color: PrimarTheme.muted.withValues(alpha: .45)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.8),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: PrimarTheme.navy.withValues(alpha: 0.18)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: PrimarTheme.blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                PaperButton(
                  onPressed: _next,
                  child: Text(_s.next,
                      style: PrimarTheme.display(18,
                          color: Colors.white, weight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        _Step.age => _Question(
            mood: _moodForStep(_Step.age),
            kicker: _s.ageKicker,
            title: _s.ageTitle,
            // Said out loud as well. A parent who thinks this is the answer
            // will worry about getting it wrong, and it is not the answer.
            note: _s.ageNote,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final age in Screener.ages)
                  _AgeTile(
                    label: '$age',
                    selected: _answers.age == age,
                    onTap: () => _choose(_answers.copyWith(age: age)),
                  ),
                // Everyone above the listed ages. A picker that stopped at the
                // last number told the parent of a fifteen-year-old who cannot
                // read that this was not for them.
                _AgeTile(
                  label: '${Screener.olderThanListed}+',
                  selected: _answers.age == Screener.olderThanListed,
                  onTap: () =>
                      _choose(_answers.copyWith(age: Screener.olderThanListed)),
                ),
              ],
            ),
          ),
        _Step.school => _Question(
            mood: _moodForStep(_Step.school),
            kicker: _s.schoolKicker,
            title: _s.schoolTitle,
            note: _s.schoolNote,
            child: Column(
              children: [
                for (final (s, art, label, sub) in [
                  (Schooling.none, ArtKind.schoolNone, _s.schoolNone, _s.schoolNoneSub),
                  (Schooling.patchy, ArtKind.schoolPatchy, _s.schoolPatchy, _s.schoolPatchySub),
                  (Schooling.daily, ArtKind.schoolDaily, _s.schoolDaily, _s.schoolDailySub),
                ])
                  _ChoiceCard(
                    art: art,
                    title: label,
                    subtitle: sub,
                    selected: _answers.schooling == s,
                    onTap: () => _choose(_answers.copyWith(schooling: s)),
                  ),
              ],
            ),
          ),
        _Step.subject => _Question(
            mood: _moodForStep(_Step.subject),
            kicker: _s.subjectKicker,
            title: _s.subjectTitle,
            note: _s.subjectNote,
            child: Column(
              children: [
                for (final s in subjectOrder)
                  _SubjectCard(
                    subject: s,
                    locale: _answers.locale,
                    selected: _answers.subject == s,
                    onTap: () => _choose(_answers.copyWith(subject: s)),
                  ),
              ],
            ),
          ),
        _Step.seen => _Question(
            mood: _moodForStep(_Step.seen),
            kicker: _s.seenKicker,
            title: _seenTitle(_answers.subject, _answers.locale),
            note: _s.seenNote,
            child: Column(
              children: [
                for (final seen in SeenDoing.values)
                  _ChoiceCard(
                    art: artFor(_answers.subject, seen),
                    title: seen.prompt(_answers.subject, _answers.locale),
                    selected: _answers.seenDoing == seen,
                    onTap: () => _choose(_answers.copyWith(seenDoing: seen)),
                  ),
              ],
            ),
          ),
      };

  static String _seenTitle(Subject s, String locale) {
    final fr = locale == 'fr';
    return switch (s) {
      Subject.reading =>
        fr ? 'Que font-ils avec les lettres ?' : 'What can they do with letters?',
      Subject.numeracy =>
        fr ? 'Que font-ils avec les nombres ?' : 'What can they do with numbers?',
      Subject.shapes =>
        fr ? 'Que font-ils avec les formes ?' : 'What can they do with shapes?',
    };
  }

}

/// The picture for one answer on the last page.
///
/// Top-level so a test can assert the mapping directly: two answers sharing a
/// picture is the same defect as two answer tiles rendering identically — the
/// parent is asked to distinguish something that looks the same either way.
ArtKind artFor(Subject subject, SeenDoing seen) => switch (subject) {
        Subject.reading => switch (seen) {
            SeenDoing.notYet => ArtKind.readingNone,
            SeenDoing.starting => ArtKind.readingFew,
            SeenDoing.someOfIt => ArtKind.readingMost,
            SeenDoing.confident => ArtKind.readingWords,
          },
        Subject.numeracy => switch (seen) {
            SeenDoing.notYet => ArtKind.numbersNone,
            SeenDoing.starting => ArtKind.numbersTen,
            SeenDoing.someOfIt => ArtKind.numbersTwenty,
            SeenDoing.confident => ArtKind.numbersAdd,
          },
        Subject.shapes => switch (seen) {
            SeenDoing.notYet => ArtKind.shapesNone,
            SeenDoing.starting => ArtKind.shapesSame,
            SeenDoing.someOfIt => ArtKind.shapesFit,
            SeenDoing.confident => ArtKind.shapesMissing,
          },
    };

/// How far through. Segmented like Brilliant's onboarding — each segment is
/// one question, completed ones fill teal, the current one pulses blue.
class _Rail extends StatelessWidget {
  const _Rail({required this.count, required this.at});

  final int count;
  final int at;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
                  child: AnimatedContainer(
                    duration: PrimarMotion.medium,
                    curve: PrimarMotion.enter,
                    height: i == at ? 8 : 6,
                    decoration: BoxDecoration(
                      color: i < at
                          ? PrimarTheme.teal
                          : i == at
                              ? PrimarTheme.blue
                              : PrimarTheme.navy.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: i < at
                        ? const Align(
                            alignment: Alignment.center,
                            child: Icon(Icons.check_rounded,
                                size: 10, color: Colors.white),
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${at + 1} of $count',
          textAlign: TextAlign.center,
          style: PrimarTheme.label(10, color: PrimarTheme.muted),
        ),
      ],
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.mood,
    required this.kicker,
    required this.title,
    required this.child,
    this.note,
  });

  final Mood mood;
  final String kicker;
  final String title;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mate asks the question, rather than the page displaying it.
        //
        // The voice already read every page aloud, but nothing on screen said
        // *who* was talking — the words sat in a header like a form label while
        // a voice came out of nowhere. Putting the question in a bubble beside
        // the character joins the two, and for a parent who cannot read it is
        // the difference between an app that is talking to them and an app that
        // is making a noise.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Mate(mood: mood, size: 68),
            const SizedBox(width: 10),
            Expanded(child: _Bubble(title: title, note: note)),
          ],
        ),
        const SizedBox(height: 18),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              decoration: PrimarTheme.paperSheet(),
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kicker, style: PrimarTheme.label(10, color: PrimarTheme.muted)),
                  const SizedBox(height: 14),
                  child,
                ],
              ),
            ),
            const Positioned(top: -11, child: TapeStrip(tone: TapeTone.blue)),
          ],
        ),
      ],
    );
  }
}

/// What Mate is saying, with a tail pointing back at him.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.title, this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubbleTailPainter(),
      child: Container(
        margin: const EdgeInsets.only(left: 10),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: PrimarTheme.sheet,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PrimarTheme.navy.withValues(alpha: 0.12), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: PrimarTheme.display(20)),
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(note!, style: PrimarTheme.body(13, color: PrimarTheme.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // A small triangle on the left edge, level with Mate's head.
    final tail = Path()
      ..moveTo(12, 22)
      ..lineTo(0, 30)
      ..lineTo(12, 38)
      ..close();
    canvas.drawPath(tail, Paint()..color = PrimarTheme.sheet);
    canvas.drawPath(
      tail,
      Paint()
        ..color = PrimarTheme.navy.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter old) => false;
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.art,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final ArtKind art;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: selected ? 1.01 : 1.0,
          duration: PrimarMotion.fast,
          curve: PrimarMotion.bounce,
          child: AnimatedContainer(
            duration: PrimarMotion.fast,
            curve: PrimarMotion.enter,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: PrimarTheme.tile(
              border: selected ? PrimarTheme.teal : null,
              fill: selected ? PrimarTheme.tintTeal : null,
              lift: selected ? 7 : 3,
            ),
            child: Row(
            children: [
              ChoiceArt(kind: art, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PrimarTheme.display(15.5,
                          color: selected ? PrimarTheme.navy : PrimarTheme.inkSoft),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: PrimarTheme.body(12.5, color: PrimarTheme.muted)),
                    ],
                  ],
                ),
              ),
              _Check(on: selected),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final Subject subject;
  final String locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = SubjectBadge(subject: subject, selected: true).tint;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: PrimarTheme.tile(
            border: selected ? tint : null,
            fill: selected ? tint.withValues(alpha: 0.10) : null,
            lift: selected ? 7 : 3,
          ),
          child: Row(
            children: [
              SubjectBadge(subject: subject, selected: selected, size: 58),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.label(locale),
                      style: PrimarTheme.display(17,
                          color: selected ? PrimarTheme.navy : PrimarTheme.inkSoft),
                    ),
                    const SizedBox(height: 2),
                    Text(subject.blurb(locale),
                        style: PrimarTheme.body(12.5, color: PrimarTheme.muted)),
                  ],
                ),
              ),
              _Check(on: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgeTile extends StatelessWidget {
  const _AgeTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 62,
        height: 66,
        alignment: Alignment.center,
        decoration: PrimarTheme.tile(
          border: selected ? PrimarTheme.blue : null,
          fill: selected ? PrimarTheme.tintBlue : null,
          lift: selected ? 7 : 3,
        ),
        child: Text(
          label,
          // "13+" is three glyphs where an age is one or two, so it drops a
          // size rather than pushing the tile wider than its neighbours.
          style: PrimarTheme.display(label.length > 2 ? 21 : 26,
              color: selected ? PrimarTheme.navy : PrimarTheme.muted, weight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      scale: on ? 1 : 0.4,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 170),
        opacity: on ? 1 : 0,
        child: Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: PrimarTheme.teal, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 17, color: Colors.white),
        ),
      ),
    );
  }
}


/// The one page whose options must be legible before the language is known.
///
/// So each shows its name in the language itself — a Francophone parent looks
/// for "Français", not for the English word "French" — with the English gloss
/// beneath for anyone who is guessing.
class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.label,
    required this.native,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String native;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: PrimarTheme.tile(
            border: selected ? PrimarTheme.blue : null,
            fill: selected ? PrimarTheme.tintBlue : null,
            lift: selected ? 7 : 3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  native,
                  style: PrimarTheme.display(20,
                      color: selected ? PrimarTheme.navy : PrimarTheme.inkSoft),
                ),
              ),
              if (native != label)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(label, style: PrimarTheme.body(13, color: PrimarTheme.muted)),
                ),
              _Check(on: selected),
            ],
          ),
        ),
      ),
    );
  }
}


/// One voice to choose from, with a way to hear it.
class _VoiceCard extends StatelessWidget {
  const _VoiceCard({
    required this.voice,
    required this.selected,
    required this.onTap,
    required this.onPreview,
  });

  final TeachingVoice voice;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final tint = switch (voice.kind) {
      VoiceKind.guide => PrimarTheme.blue,
      VoiceKind.teacher => PrimarTheme.teal,
      VoiceKind.parent => PrimarTheme.orange,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: PrimarTheme.tile(
            border: selected ? tint : null,
            fill: selected ? tint.withValues(alpha: 0.10) : null,
            lift: selected ? 7 : 3,
          ),
          child: Row(
            children: [
              VoiceAvatar(voice: voice, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(voice.label,
                        style: PrimarTheme.display(16.5,
                            color: selected ? PrimarTheme.navy : PrimarTheme.inkSoft)),
                    const SizedBox(height: 2),
                    Text(voice.blurb,
                        style: PrimarTheme.body(12.5, color: PrimarTheme.muted)),
                  ],
                ),
              ),
              // A parent voice has nothing to preview until it is recorded, so
              // it gets no speaker — a button that plays silence would read as
              // the app being broken.
              if (!voice.needsRecording)
                GestureDetector(
                  onTap: onPreview,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.volume_up_rounded, color: tint, size: 26),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.mic_none_rounded,
                      color: tint.withValues(alpha: 0.75), size: 26),
                ),
              _Check(on: selected),
            ],
          ),
        ),
      ),
    );
  }
}


/// A circular step control with its name beside it.
///
/// Icon *and* word: the icon is what a child recognises and the word is what
/// the adult beside them reads. Sized well past the 48dp minimum because the
/// target audience is a small finger on a cracked screen.
class _RoundStep extends StatefulWidget {
  const _RoundStep({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_RoundStep> createState() => _RoundStepState();
}

class _RoundStepState extends State<_RoundStep> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: PrimarTheme.sheet,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD6DEE9), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC3CDDB),
                    blurRadius: 0,
                    offset: Offset(0, _down ? 1 : 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, size: 26, color: PrimarTheme.navy),
            ),
            const SizedBox(width: 12),
            Text(widget.label,
                style: PrimarTheme.display(15, color: PrimarTheme.inkSoft)),
          ],
        ),
      ),
    );
  }
}