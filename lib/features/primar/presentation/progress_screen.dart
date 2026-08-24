import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/learner.dart';
import '../domain/progress.dart';
import '../domain/skill.dart';
import 'mascot.dart';
import 'primar_theme.dart';

/// How it is going.
///
/// Two audiences on one screen, which is unusual and deliberate: a child looks
/// at the ring and the streak, a parent reads the skill list underneath. They
/// want different things and neither needs their own screen for it.
///
/// The rule the whole screen follows: **it reports, it never grades.** There is
/// no total score, no comparison to other children, and no percentage of a
/// curriculum — because "22% of reading" is a number that means nothing to a
/// parent and discourages every child who is early.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({
    super.key,
    required this.summary,
    required this.learner,
    required this.name,
    this.onPlay,
  });

  final ProgressSummary summary;
  final Learner learner;
  final String name;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Centred, not stretched.
        //
        // The column stretches its children to full width so the ring and the
        // skill list line up — which also forced the mascot to fill the screen
        // and paint behind everything else. A fixed-size drawing needs saying
        // so explicitly in a stretching column.
        Center(
          child: Mate(mood: summary.playedToday ? Mood.happy : Mood.idle, size: 76),
        ),
        const SizedBox(height: 12),
        Text(progressGreeting(summary, name),
            textAlign: TextAlign.center, style: PrimarTheme.display(24)),
        const SizedBox(height: 22),

        // Today, as a ring.
        Center(
          child: SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: _RingPainter(summary.accuracyToday),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // Before anything is answered the ring shows a dash, not
                      // a zero. Zero reads as failure; a dash reads as "not
                      // started", which is what it means.
                      summary.accuracyToday == null
                          ? '–'
                          : '${(summary.accuracyToday! * 100).round()}%',
                      style: PrimarTheme.display(40),
                    ),
                    Text('today', style: PrimarTheme.label(10)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            _Stat(value: '${summary.streakDays}', label: streakLine(summary)),
            _Stat(
              value: '${summary.skillsCleared}/${summary.skillsTotal}',
              label: 'things they can do',
            ),
            _Stat(value: summary.timeToday, label: 'spent today'),
          ],
        ),
        const SizedBox(height: 24),

        Text('WHAT ${name.toUpperCase()} CAN DO', style: PrimarTheme.label(10)),
        const SizedBox(height: 10),
        // Named abilities, in order, so a parent can see the road rather than a
        // score. Skills the app cannot yet teach are shown greyed rather than
        // hidden — the gap is part of the honest picture.
        for (final s in readingSkills)
          _SkillRow(skill: s, state: learner.stateOf(s.id)),

        if (onPlay != null) ...[
          const SizedBox(height: 24),
          PaperButton(
            onPressed: onPlay,
            child: Text(summary.playedToday ? 'Play more' : 'Start today',
                style: PrimarTheme.display(18,
                    color: Colors.white, weight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);

  /// Null means nothing answered yet.
  final double? value;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 12;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = PrimarTheme.tintGrey.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16,
    );

    if (value == null) return;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * value!.clamp(0.0, 1.0),
      false,
      Paint()
        // Teal at any level. A ring that turns red below some threshold would
        // be grading, and a six-year-old reading a red ring learns only that
        // they are the wrong kind of child.
        ..color = PrimarTheme.teal
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 16,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: PrimarTheme.display(28)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: PrimarTheme.body(11.5, color: PrimarTheme.muted)),
        ],
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.skill, required this.state});

  final Skill skill;
  final SkillState state;

  @override
  Widget build(BuildContext context) {
    final colour = switch (state.state) {
      MasteryState.mastered => PrimarTheme.teal,
      MasteryState.probable => PrimarTheme.blue,
      MasteryState.learning => PrimarTheme.yellow,
      MasteryState.notStarted => PrimarTheme.tintGrey,
    };

    return Opacity(
      opacity: skill.teachable ? 1 : 0.4,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                skill.teachable ? skill.label : '${skill.label}  (coming)',
                style: PrimarTheme.body(13.5),
              ),
            ),
            if (state.state == MasteryState.mastered)
              const Icon(Icons.check_rounded, size: 18, color: PrimarTheme.teal),
          ],
        ),
      ),
    );
  }
}
