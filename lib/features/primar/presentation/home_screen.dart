import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/learner.dart';
import '../domain/home_copy.dart';
import '../domain/path.dart';
import '../domain/policy.dart';
import '../domain/progress.dart';
import '../domain/skill.dart';
import '../domain/skill_atelier.dart';
import '../domain/subjects.dart';
import '../services/evidence_store.dart';
import '../services/learner_traits.dart';
import '../services/primar_voice.dart';
import '../services/tutor_brain.dart';
import 'mascot.dart';
import 'primar_motion.dart';
import 'primar_theme.dart';

/// Where a child lands, and the reason to come back.
///
/// ## What was missing
///
/// The app opened straight into a questionnaire and, from then on, into a
/// session. There was no place that was *theirs* — nowhere showing what they
/// had done, what they were on, or what was next. Every session started from
/// nothing and ended in a summary written for a parent.
///
/// A child who cannot see a position cannot want to move. That is the whole of
/// what "boring" meant here: not the questions, the absence of a map.
///
/// ## The shape, and why this one
///
/// A single winding path of nodes, walked bottom to top, current node pulsing.
/// It is Duolingo's arrangement and it is worth copying for a reason that has
/// nothing to do with looking like Duolingo: it answers "where am I" with a
/// position rather than a number, which is the only form of that answer a
/// six-year-old can read.
///
/// What is different here is what the nodes *are*. Duolingo's units are
/// content the company wrote. These are skills out of the graph, ordered by
/// prerequisite, and a node is lit by the learner model rather than by how
/// many lessons someone has clicked through. A child cannot walk past a skill
/// they have not shown evidence of.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.name,
    required this.locale,
    required this.onPlay,
    this.subject = Subject.reading,
  });

  final String name;
  final String locale;

  /// Which path to draw.
  ///
  /// Not decoration: numeracy has its own graph now, and a child who chose
  /// Math seeing phonics on their home screen would be the app telling them
  /// it was not listening.
  final Subject subject;

  /// Start the next session. Optional [skillId] when the child tapped a path node.
  final void Function([String? skillId]) onPlay;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PathStep> _steps = const [];
  ProgressSummary? _summary;
  Decision? _decision;
  bool _loading = true;
  final _currentNodeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await EvidenceStore.instance.load();
    if (!mounted) return;
    final learner = learnerFrom(log, locale: widget.locale);
    final traits = await LearnerTraitsStore.instance.recomputeFrom(
      log,
      locale: widget.locale,
      subject: widget.subject,
    );
    if (!mounted) return;
    final steps = pathFor(learner, subject: widget.subject);
    final decision = nextSkill(learner, subject: widget.subject);
    setState(() {
      _steps = steps;
      _summary = summariseProgress(log, learner, subject: widget.subject);
      _decision = decision;
      _loading = false;
    });
    _scrollToCurrent(steps);
    _speakHome(decision, traits);
  }

  void _speakHome(Decision decision, LearnerTraits traits) {
    if (decision.exhausted || decision.skillId == null) return;
    unawaited(
      TutorBrain.instance
          .lineFor(
            TutorContext(
              moment: TutorMoment.homeNext,
              locale: widget.locale,
              childName: widget.name,
              skillId: decision.skillId,
              reason: decision.reason,
              traits: traits,
            ),
          )
          .then((result) {
        PrimarVoice.instance.sayTutor(result.feedback);
      }),
    );
  }

  void _scrollToCurrent(List<PathStep> steps) {
    final currentIndex =
        steps.indexWhere((s) => s.state == PathState.current);
    if (currentIndex < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentNodeKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: PrimarMotion.slow,
          curve: PrimarMotion.enter,
          alignment: 0.35,
        );
      }
    });
  }

  String get _startLabel {
    final fromDecision = _decision?.skillId;
    if (fromDecision != null) {
      return skillsById[fromDecision]?.label ??
          widget.subject.label(widget.locale);
    }
    final currentIndex =
        _steps.indexWhere((s) => s.state == PathState.current);
    if (currentIndex >= 0) return _steps[currentIndex].skill.label;
    return widget.subject.label(widget.locale);
  }

  String get _startHeadline =>
      sessionHeadline(_decision?.reason ?? Reason.advance);

  String? get _startSubline {
    final decision = _decision;
    if (decision == null || decision.exhausted || decision.skillId == null) {
      return null;
    }
    final label = skillsById[decision.skillId!]?.label ?? _startLabel;
    return homeStartSubline(
      locale: widget.locale,
      skillLabel: label,
      reason: decision.reason,
    );
  }

  SkillAtelierCard? get _atelier {
    final id = _decision?.skillId;
    if (id == null) return null;
    return atelierFor(
      skillId: id,
      locale: widget.locale,
      subject: widget.subject,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 90),
          child: Mate(mood: Mood.idle, size: 92),
        ),
      );
    }

    final summary = _summary!;
    final currentIndex = _steps.indexWhere((s) => s.state == PathState.current);
    final atelier = _atelier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimarReveal(
          child: _Header(name: widget.name, summary: summary),
        ),
        const SizedBox(height: 18),

        PrimarReveal(
          delay: PrimarMotion.stagger(1),
          child: _StartCard(
            label: _startLabel,
            headline: _startHeadline,
            subline: _startSubline,
            hook: atelier?.hookIn(widget.locale),
            didYouKnow: atelier?.didYouKnowIn(widget.locale),
            locale: widget.locale,
            onPlay: () => widget.onPlay(_decision?.skillId),
          ),
        ),
        const SizedBox(height: 22),

        for (var i = 0; i < _steps.length; i++)
          PrimarReveal(
            delay: PrimarMotion.stagger(i + 2),
            key: i == currentIndex ? _currentNodeKey : null,
            child: _PathNode(
              step: _steps[i],
              leanAbove: i == 0 ? null : sin((i - 1) * 0.9),
              leanBelow: i == _steps.length - 1 ? null : sin((i + 1) * 0.9),
              lean: sin(i * 0.9),
              isLast: i == _steps.length - 1,
              onTap: _steps[i].state == PathState.locked
                  ? null
                  : () => widget.onPlay(_steps[i].skill.id),
            ),
          ),
        const SizedBox(height: 30),
      ],
    );
  }
}

/// Streak, stars and a greeting. The parts a child checks first.
class _Header extends StatelessWidget {
  const _Header({required this.name, required this.summary});

  final String name;
  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final progress = summary.skillsTotal == 0
        ? 0.0
        : summary.skillsCleared / summary.skillsTotal;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: PrimarTheme.tile(lift: 6),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              PrimarProgressRing(progress: progress, size: 62),
              const Mate(mood: Mood.happy, size: 44),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: PrimarTheme.display(21)),
                const SizedBox(height: 4),
                Text(
                  streakLine(summary),
                  style: PrimarTheme.body(13.5),
                ),
                if (summary.playedToday) ...[
                  const SizedBox(height: 4),
                  Text(
                    summary.answeredToday == 0
                        ? '${summary.timeToday} today'
                        : '${summary.correctToday}/${summary.answeredToday} today · ${summary.timeToday}',
                    style: PrimarTheme.label(11, color: PrimarTheme.muted),
                  ),
                ],
                if (summary.skillsTotal > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${summary.skillsCleared} of ${summary.skillsTotal} skills',
                    style: PrimarTheme.label(11, color: PrimarTheme.teal),
                  ),
                ],
              ],
            ),
          ),
          _Chip(
            icon: Icons.local_fire_department_rounded,
            colour: PrimarTheme.orange,
            value: '${summary.streakDays}',
          ),
          const SizedBox(width: 8),
          _Chip(
            icon: Icons.workspace_premium_rounded,
            colour: PrimarTheme.teal,
            value: '${summary.skillsCleared}',
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.colour, required this.value});

  final IconData icon;
  final Color colour;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colour, size: 24),
        const SizedBox(height: 2),
        Text(value, style: PrimarTheme.display(15, color: PrimarTheme.navy)),
      ],
    );
  }
}

/// The one thing to press — Skill Atelier card.
class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.label,
    required this.onPlay,
    required this.locale,
    this.headline = 'UP NEXT',
    this.subline,
    this.hook,
    this.didYouKnow,
  });

  /// What the child is about to work on. A skill label where there is a graph,
  /// and the subject's own name where there is not.
  final String label;
  final String headline;
  final String? subline;
  final String? hook;
  final String? didYouKnow;
  final String locale;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final accent = switch (headline) {
      'REVIEW' => PrimarTheme.yellow,
      'PRACTICE' => PrimarTheme.orange,
      _ => PrimarTheme.teal,
    };
    final kickerColour = switch (headline) {
      'REVIEW' => PrimarTheme.orange,
      'PRACTICE' => PrimarTheme.orange,
      _ => PrimarTheme.blue,
    };
    final atelierKicker = locale == 'fr' ? 'ATELIER' : 'ATELIER';

    return Container(
      decoration: PrimarTheme.tile(border: PrimarTheme.blue, lift: 8),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accent, accent.withValues(alpha: 0.55)],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kickerColour.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(headline,
                              style:
                                  PrimarTheme.label(10, color: kickerColour)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: PrimarTheme.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            atelierKicker,
                            style: PrimarTheme.label(10,
                                color: PrimarTheme.teal),
                          ),
                        ),
                        const Spacer(),
                        const Mate(mood: Mood.happy, size: 40),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(label, style: PrimarTheme.display(24)),
                    if (hook != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        hook!,
                        style: PrimarTheme.body(15, color: PrimarTheme.navy),
                      ),
                    ],
                    if (subline != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subline!,
                        style: PrimarTheme.body(13.5, color: PrimarTheme.muted),
                      ),
                    ],
                    if (didYouKnow != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: PrimarTheme.paper,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locale == 'fr' ? 'Le savais-tu ?' : 'Did you know?',
                              style: PrimarTheme.label(10,
                                  color: PrimarTheme.blue),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              didYouKnow!,
                              style: PrimarTheme.body(13,
                                  color: PrimarTheme.navy),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    PaperButton(
                      onPressed: () {
                        PrimarVoice.instance.chime(Sfx.tap);
                        onPlay();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 26),
                          const SizedBox(width: 4),
                          Text(
                            locale == 'fr' ? 'Démarrer' : 'Start',
                            style: PrimarTheme.display(18,
                                color: Colors.white, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One skill on the path.
class _PathNode extends StatefulWidget {
  const _PathNode({
    required this.step,
    required this.lean,
    required this.leanAbove,
    required this.leanBelow,
    required this.isLast,
    required this.onTap,
  });

  /// Lean of the neighbouring nodes, or null at the ends of the path.
  final double? leanAbove;
  final double? leanBelow;

  final PathStep step;

  /// Where this node sits across the path, from -1 (hard left) to 1 (right).
  ///
  /// A ratio rather than pixels, because it is applied as padding and the
  /// pixels have to come out of a width this widget does not know until build.
  final double lean;

  final bool isLast;
  final VoidCallback? onTap;

  @override
  State<_PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<_PathNode>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: PrimarMotion.pulse,
  );

  late final AnimationController _donePop = AnimationController(
    vsync: this,
    duration: PrimarMotion.medium,
  );

  @override
  void initState() {
    super.initState();
    if (widget.step.state == PathState.current) _pulse.repeat(reverse: true);
    if (widget.step.state == PathState.done) _donePop.forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _donePop.dispose();
    super.dispose();
  }

  Color get _fill => switch (widget.step.state) {
        PathState.done => PrimarTheme.teal,
        PathState.current => PrimarTheme.blue,
        PathState.started => PrimarTheme.yellow,
        // Available but not started. Distinct from locked, because only one
        // of the two is a wall — but quieter than current, because only one of
        // them is where the child is being sent.
        PathState.open => const Color(0xFFDDE7F5),
        PathState.locked => const Color(0xFFE2E8F0),
      };

  IconData get _glyph => switch (widget.step.state) {
        PathState.done => Icons.check_rounded,
        PathState.locked => Icons.lock_rounded,
        PathState.open => Icons.play_arrow_rounded,
        _ => switch (widget.step.skill.strand) {
            Strand.phonologicalAwareness => Icons.hearing_rounded,
            Strand.letterKnowledge => Icons.abc_rounded,
            Strand.decoding => Icons.auto_stories_rounded,
            Strand.meaning => Icons.lightbulb_rounded,
            // Numeracy. Each strand gets the thing it is about rather than a
            // generic badge, for the same reason the reading ones do.
            Strand.counting => Icons.pin_rounded,
            Strand.comparison => Icons.balance_rounded,
            Strand.arithmetic => Icons.calculate_rounded,
            Strand.visualReasoning => Icons.category_rounded,
          },
      };

  @override
  Widget build(BuildContext context) {
    final locked = widget.step.state == PathState.locked;
    // Only a padlock greys the label. An open step is startable, and greying
    // its name said otherwise.
    final dim = locked;

    // Padding, not Transform.translate.
    //
    // A transform moves a node *after* layout, so nothing accounts for it and
    // the offset simply pushes content past the edge — on a 360dp screen the
    // current node was clipped in half by the left bezel, which is the one
    // node that matters. As padding, the shift is part of the layout: the row
    // is narrower by exactly what it leans, and the label wraps instead of
    // running off.
    const swing = 26.0;
    final shift = widget.lean * swing;

    // The trail, painted *outside* the padding.
    //
    // This is the whole trick and getting it wrong once cost a build: with the
    // CustomPaint inside the Padding its canvas is only as tall as the row, so
    // the gap between one circle and the next is not paintable at all and the
    // line came out as a nub above each node. Wrapping the padding instead
    // gives the painter the full slot — node plus the space either side — so a
    // segment drawn to the slot edge meets the segment drawn from the next.
    //
    // Without the trail the nodes were a column of circles, which reads as a
    // list of things rather than one route with a position on it, and the
    // position is the entire point of the screen.
    return CustomPaint(
      painter: _TrailPainter(
        above: widget.leanAbove == null
            ? null
            : (widget.leanAbove! - widget.lean) * swing,
        below: widget.leanBelow == null
            ? null
            : (widget.leanBelow! - widget.lean) * swing,
        centreX: swing + shift + _TrailPainter._nodeRadius,
        doneColour: _fill,
        isDone: widget.step.state == PathState.done,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          // 18 rather than 6: twelve logical pixels between circles left the
          // trail no room to read as a line.
          top: 18,
          bottom: 18,
          left: swing + shift,
          right: swing - shift,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulse, _donePop]),
                builder: (context, child) {
                  final scale = switch (widget.step.state) {
                    PathState.current => 1 + _pulse.value * 0.06,
                    PathState.done => 0.88 + _donePop.value * 0.12,
                    _ => 1.0,
                  };
                  return Transform.scale(scale: scale, child: child);
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.step.strength > 0.02 &&
                        widget.step.state != PathState.locked)
                      PrimarProgressRing(
                        progress: widget.step.strength,
                        size: 74,
                      ),
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: _fill,
                        shape: BoxShape.circle,
                        border: widget.step.state == PathState.open
                            ? Border.all(color: PrimarTheme.blue, width: 3)
                            : widget.step.state == PathState.current
                                ? Border.all(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    width: 3,
                                  )
                                : null,
                        boxShadow: [
                          BoxShadow(
                            color: dim
                                ? const Color(0xFFCBD5E1)
                                : _fill.withValues(alpha: 0.55),
                            blurRadius: 0,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        _glyph,
                        color: widget.step.state == PathState.open
                            ? PrimarTheme.blue
                            : dim
                                ? PrimarTheme.ghostInk
                                : Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.step.skill.label,
                // Two lines is enough for every label in the graph at 360dp.
                // The ellipsis is the guard for whatever gets added later.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PrimarTheme.body(
                  13.5,
                  color: dim ? PrimarTheme.ghostInk : PrimarTheme.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The line joining one node to its neighbours.
///
/// Drawn per node rather than as one long path down the screen, because the
/// column is a plain Column of variable-height rows — a single path would need
/// every row's final height before any of them had been laid out.
class _TrailPainter extends CustomPainter {
  const _TrailPainter({
    required this.above,
    required this.below,
    required this.centreX,
    required this.doneColour,
    required this.isDone,
  });

  /// Where this node's centre sits horizontally within the slot.
  final double centreX;

  /// Horizontal offset of the neighbouring node relative to this one, in
  /// logical pixels. Null where there is no neighbour.
  final double? above;
  final double? below;

  final Color doneColour;
  final bool isDone;

  static const double _nodeRadius = 33;
  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(centreX, size.height / 2);

    final paint = Paint()
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Half of each neighbour's lean, because each slot draws half the run and
    // the next slot draws the other half. They meet on the boundary.
    if (above != null) {
      // Cleared trail behind, pale ahead. The colour changes at the node, so
      // the last filled segment ends exactly where the child stopped.
      paint.color = isDone ? doneColour : const Color(0xFFD3DDE9);
      canvas.drawLine(
        centre + const Offset(0, -_nodeRadius - _gap),
        Offset(centre.dx + above! / 2, 0),
        paint,
      );
    }

    if (below != null) {
      paint.color = const Color(0xFFD3DDE9);
      canvas.drawLine(
        centre + const Offset(0, _nodeRadius + _gap),
        Offset(centre.dx + below! / 2, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.above != above ||
      old.below != below ||
      old.centreX != centreX ||
      old.isDone != isDone ||
      old.doneColour != doneColour;
}
