import 'package:flutter/material.dart';

import '../domain/home_copy.dart';
import '../domain/learner.dart';
import '../domain/path.dart';
import '../domain/policy.dart';
import '../domain/progress.dart';
import '../domain/skill.dart';
import '../domain/subjects.dart';
import '../domain/teaching_voice.dart';
import '../services/evidence_store.dart';
import 'mascot.dart';
import 'primar_motion.dart';
import 'primar_theme.dart';
import 'voice_avatar.dart';

/// The child's own page.
///
/// ## Why a profile at all
///
/// Not vanity. Everything the app knows about a learner lived in an evidence
/// log nobody could see, and surfaced once, in a summary written for a parent
/// at the end of a session. A child had no way to look at their own record.
///
/// The thing that makes an app feel like it belongs to you is that it
/// remembers you and will show you. This is that, and it is built from exactly
/// the same log the engine reads — so what it shows is what the app actually
/// believes, not a parallel score kept for display.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.name,
    required this.locale,
    required this.voiceId,
    this.subject = Subject.reading,
    this.onSubjectChanged,
  });

  final String name;
  final String locale;
  final String voiceId;

  /// Which subject's skills to summarise. One evidence log holds them all.
  final Subject subject;

  /// Switch reading / math / other without re-onboarding.
  final ValueChanged<Subject>? onSubjectChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProgressSummary? _summary;
  List<PathStep> _steps = const [];
  Decision? _decision;
  int _totalAnswered = 0;
  int _totalCorrect = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subject != widget.subject) _load();
  }

  Future<void> _load() async {
    final log = await EvidenceStore.instance.load();
    if (!mounted) return;
    final learner = learnerFrom(log, locale: widget.locale);
    setState(() {
      _summary = summariseProgress(log, learner, subject: widget.subject);
      _steps = pathFor(learner, subject: widget.subject);
      _decision = nextSkill(learner, subject: widget.subject);
      _totalAnswered = log.length;
      _totalCorrect = log.where((e) => e.correct).length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    if (summary == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 90),
        child: Center(child: Mate(mood: Mood.idle, size: 92)),
      );
    }

    final progress = summary.skillsTotal == 0
        ? 0.0
        : summary.skillsCleared / summary.skillsTotal;

    final done = _steps.where((s) => s.state == PathState.done).toList();
    // `current` as well as `started`.
    //
    // The skill a child is on right now is classified `current`, not
    // `started`, so filtering on `started` alone left the panel empty for the
    // exact learner it is for — someone mid-way through a skill saw "can do"
    // and nothing about what they were actually doing.
    final working = _steps
        .where((s) =>
            s.state == PathState.started || s.state == PathState.current)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: PrimarTheme.tile(lift: 6),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  PrimarProgressRing(progress: progress, size: 96, colour: PrimarTheme.teal),
                  VoiceAvatar(
                    voice: voiceById(widget.voiceId, widget.locale),
                    size: 72,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(widget.name, style: PrimarTheme.display(24)),
              const SizedBox(height: 4),
              Text(streakLine(summary), style: PrimarTheme.body(14)),
              const SizedBox(height: 10),
              _StreakDots(days: summary.streakDays),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (widget.onSubjectChanged != null) ...[
          _SubjectPicker(
            locale: widget.locale,
            selected: widget.subject,
            onChanged: widget.onSubjectChanged!,
          ),
          const SizedBox(height: 14),
        ],

        if (_decision != null && !_decision!.exhausted) ...[
          _MateSays(
            locale: widget.locale,
            headline: sessionHeadline(_decision!.reason),
            skillLabel: skillsById[_decision!.skillId!]!.label,
            body: homeMateBody(
              locale: widget.locale,
              skillLabel: skillsById[_decision!.skillId!]!.label,
              reason: _decision!.reason,
            ),
          ),
          const SizedBox(height: 14),
        ],

        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'DAY STREAK',
                value: '${summary.streakDays}',
                colour: PrimarTheme.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                label: 'SKILLS',
                value: '${summary.skillsCleared}/${summary.skillsTotal}',
                colour: PrimarTheme.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                label: 'ANSWERED',
                value: '$_totalAnswered',
                colour: PrimarTheme.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_totalAnswered > 0)
          _Panel(
            title: 'HOW IT IS GOING',
            child: Text(
              // Plain and specific. "82% accuracy" is a number a parent has to
              // interpret; this is the same fact in a form they can act on.
              '$_totalCorrect right out of $_totalAnswered. '
              '${summary.skillsCleared} of ${summary.skillsTotal} skills solid so far.',
              style: PrimarTheme.body(14.5),
            ),
          ),

        if (working.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Panel(
            title: 'WORKING ON',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in working) _SkillLine(skill: s.skill, done: false),
              ],
            ),
          ),
        ],

        if (done.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Panel(
            title: 'CAN DO',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in done) _SkillLine(skill: s.skill, done: true),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        Text(
          'Everything here is worked out on this phone. '
          'Nothing about your child is sent anywhere.',
          textAlign: TextAlign.center,
          style: PrimarTheme.body(12.5, color: PrimarTheme.muted),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _SubjectPicker extends StatelessWidget {
  const _SubjectPicker({
    required this.locale,
    required this.selected,
    required this.onChanged,
  });

  final String locale;
  final Subject selected;
  final ValueChanged<Subject> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in subjectOrder)
          if (teachableSkillsFor(s).isNotEmpty)
            GestureDetector(
              onTap: () => onChanged(s),
              child: AnimatedContainer(
                duration: PrimarMotion.fast,
                curve: PrimarMotion.enter,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: s == selected ? PrimarTheme.tintBlue : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: s == selected
                        ? PrimarTheme.blue
                        : PrimarTheme.navy.withValues(alpha: 0.14),
                    width: s == selected ? 2 : 1.4,
                  ),
                ),
                child: Text(
                  s.label(locale),
                  style: PrimarTheme.body(
                    13.5,
                    weight: s == selected ? FontWeight.w700 : FontWeight.w400,
                    color: s == selected ? PrimarTheme.blue : PrimarTheme.inkSoft,
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _MateSays extends StatelessWidget {
  const _MateSays({
    required this.locale,
    required this.headline,
    required this.skillLabel,
    required this.body,
  });

  final String locale;
  final String headline;
  final String skillLabel;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: PrimarTheme.tile(border: PrimarTheme.teal, lift: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Mate(mood: Mood.happy, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale == 'fr' ? 'MATE DIT' : 'MATE SAYS',
                  style: PrimarTheme.label(10, color: PrimarTheme.teal),
                ),
                const SizedBox(height: 6),
                Text(headline, style: PrimarTheme.display(18)),
                const SizedBox(height: 4),
                Text(skillLabel, style: PrimarTheme.body(14)),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(body,
                      style: PrimarTheme.body(13, color: PrimarTheme.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.colour});

  final String label;
  final String value;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: PrimarTheme.tile(lift: 4),
      child: Column(
        children: [
          Text(value, style: PrimarTheme.display(22, color: colour)),
          const SizedBox(height: 4),
          Text(label, style: PrimarTheme.label(9)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: PrimarTheme.tile(lift: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PrimarTheme.label(10)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SkillLine extends StatelessWidget {
  const _SkillLine({required this.skill, required this.done});

  final Skill skill;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 18,
            color: done ? PrimarTheme.teal : PrimarTheme.yellow,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(skill.label, style: PrimarTheme.body(14))),
        ],
      ),
    );
  }
}

/// Last seven days of streak — filled dots for active days, like Brilliant's
/// weekly activity strip but sized for a child's profile.
class _StreakDots extends StatelessWidget {
  const _StreakDots({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 7; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
            child: AnimatedContainer(
              duration: PrimarMotion.medium,
              width: i < days.clamp(0, 7) ? 12 : 10,
              height: i < days.clamp(0, 7) ? 12 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < days.clamp(0, 7)
                    ? PrimarTheme.orange
                    : PrimarTheme.navy.withValues(alpha: 0.12),
              ),
            ),
          ),
      ],
    );
  }
}
