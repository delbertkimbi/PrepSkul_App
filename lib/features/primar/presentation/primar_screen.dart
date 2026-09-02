import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/curriculum.dart';
import '../domain/figure.dart';
import '../domain/mastery.dart';
import '../domain/intervention.dart';
import '../domain/misconception.dart';
import '../domain/learner.dart';
import '../domain/literacy.dart';
import '../domain/micro_lesson.dart';
import '../domain/parent_phrases.dart';
import '../domain/path.dart';
import '../domain/policy.dart';
import '../domain/progress.dart';
import '../domain/representation.dart';
import '../domain/screener.dart';
import '../domain/skill.dart';
import '../domain/subjects.dart';
import '../domain/tutor_feedback.dart';
import '../services/evidence_store.dart';
import '../services/explanation_bank.dart';
import '../services/learner_profile_store.dart';
import '../services/learner_traits.dart';
import '../services/mastery_store.dart';
import '../services/primar_voice.dart';
import '../services/tutor_brain.dart';
import 'figure_view.dart';
import 'home_screen.dart';
import 'lesson_chrome.dart';
import 'match_board.dart';
import 'mechanic_card.dart';
import 'mascot.dart';
import 'micro_lesson_card.dart';
import 'onboarding.dart';
import 'order_row.dart';
import 'paper_decor.dart';
import 'primar_motion.dart';
import 'primar_strings.dart';
import 'primar_theme.dart';
import 'progress_screen.dart';
import 'reteach_card.dart';
import 'say_it_button.dart';
import 'shape_view.dart';
import 'spell_row.dart';
import 'subject_badge.dart';
import 'thinking_ring.dart';

/// The whole flow: parent sets up and picks what to measure, hands the phone
/// over, the child plays, the parent reads the result. Everything runs on
/// device, so a session works with the network off — which matters in regions
/// where it goes off without warning.
class PrimarScreen extends StatefulWidget {
  const PrimarScreen({
    super.key,
    this.answers,
    this.activeSubject,
    this.seenDemo = false,
    this.onSeenDemo,
    this.launchSkillId,
    this.launchProgress = false,
  });

  /// Answers already collected by the shell.
  ///
  /// Null means run the onboarding here, which is how the standalone preview
  /// and every existing test still drive this screen. Non-null means the shell
  /// asked already and this opens on the path.
  final ScreenerAnswers? answers;

  /// Lets the profile tab switch subject without re-onboarding.
  final Subject? activeSubject;

  /// Whether this child has already seen the mechanic demo.
  final bool seenDemo;

  /// Persist that the demo ran (shell / profile store).
  final VoidCallback? onSeenDemo;

  /// One-shot launch from the profile tab or shell.
  final String? launchSkillId;

  /// Open the in-flow progress screen on first frame.
  final bool launchProgress;

  @override
  State<PrimarScreen> createState() => _PrimarScreenState();
}

/// The screens, in the order a child meets them.
///
/// [home] is the one that was missing. Everything used to run welcome → …  →
/// session → result → welcome again, so there was never a place that was the
/// child's rather than a step in a flow. The result screen now hands back to
/// home, and home is where a returning child lands.
enum _Stage { welcome, home, handoff, demo, warmUp, session, result, progress }

class _PrimarScreenState extends State<PrimarScreen> {
  late _Stage _stage = widget.answers == null ? _Stage.welcome : _Stage.home;
  late ScreenerAnswers _answers = widget.answers ?? const ScreenerAnswers();
  late Estimate _estimate = Screener.estimate(_answers);

  /// Where the real session starts, decided by the child's warm-up rather than
  /// by anything the parent told us.
  int? _beginAt;

  Placement? _placement;
  MisconceptionTracker? _misses;

  String get _childName => _answers.name;
  Subject get _subject => widget.activeSubject ?? _answers.subject;
  String get _locale => _answers.locale;
  S get _s => S(_locale);

  @override
  void initState() {
    super.initState();
    _seenDemo = widget.seenDemo;
    final answers = widget.answers;
    final locale = answers?.locale ?? 'en';
    final voiceId = answers?.voiceId ?? 'guide';
    PrimarVoice.instance.init(locale: locale, voiceId: voiceId).then((_) {
      if (!mounted) return;
      // Onboarding only — returning learners land on home; home speaks via
      // [HomeScreen._speakHome], not the parent questionnaire intro.
      if (answers == null) {
        PrimarVoice.instance.say(VoiceLines.welcomeParent);
      }
    });
    // Returning child with evidence: skip handoff / demo / warm-up ceremony.
    if (answers != null) {
      unawaited(_bootstrapReturning());
    } else {
      _applyShellLaunchIfNeeded();
    }
  }

  void _applyShellLaunchIfNeeded() {
    if (!widget.launchProgress && widget.launchSkillId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.launchProgress) {
        _go(_Stage.progress);
        return;
      }
      final skill = widget.launchSkillId;
      if (skill != null) {
        _sessionSkillId = skill;
        _startPlay(skill);
      }
    });
  }

  Future<void> _bootstrapReturning() async {
    await EvidenceStore.instance.bindChild(_answers.name);
    final log = await EvidenceStore.instance.load();
    if (!mounted) return;
    if (log.isNotEmpty) {
      setState(() {
        _seenDemo = true;
        if (!widget.launchProgress && widget.launchSkillId == null) {
          _stage = _Stage.home;
        }
      });
    } else if (widget.seenDemo) {
      setState(() => _seenDemo = true);
    }
    _applyShellLaunchIfNeeded();
  }

  @override
  void dispose() {
    _chrome.dispose();
    PrimarVoice.instance.dispose();
    super.dispose();
  }

  String get _name =>
      _childName.trim().isEmpty ? 'your child' : _childName.trim();

  /// Whether the rule has already been demonstrated to this child.
  ///
  /// The demonstration exists to teach the *mechanic*, once. Replaying it at
  /// the top of every session would be the app explaining tapping to someone
  /// who has been tapping for a week.
  bool _seenDemo = false;

  /// When the child taps a path node, the session opens on that skill first.
  String? _sessionSkillId;

  /// The pinned bar's state. Owned here because the bar outlives the session
  /// widget — it has to still be there while the result screen is showing.
  final LessonChrome _chrome = LessonChrome();

  /// Stop, and go back to where a child can choose again.
  ///
  /// Deliberately not "are you sure": a child who wants out should get out.
  /// Nothing is lost by stopping, because every answer was written to the
  /// evidence log as it happened rather than at the end.
  void _quit() {
    _chrome.visible.value = false;
    _chrome.toolsVisible.value = false;
    _go(_Stage.home);
  }

  /// The only way the stage changes.
  ///
  /// Every transition has to tell the voice the screen moved, or lines queued
  /// for the screen the child just left arrive on top of the one they are
  /// looking at now. Nine `setState(() => _stage = ...)` call sites were nine
  /// places to forget it, so there is one.
  void _go(_Stage next) {
    PrimarVoice.instance.newScene();
    setState(() => _stage = next);
  }

  void _startPlay([String? skillId]) {
    _sessionSkillId = skillId;
    _go(_seenDemo ? _Stage.session : _Stage.handoff);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: Column(
            children: [
              // Pinned, above the scroll. The bar and Mate are the frame; only
              // the question inside it changes. They used to scroll with the
              // content and sit vertically centred, which meant the one fixed
              // point on the screen moved every time the question did.
              ValueListenableBuilder<bool>(
                valueListenable: _chrome.visible,
                builder: (context, visible, _) => AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: visible
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: LessonTopBar(
                            chrome: _chrome,
                            onQuit: _quit,
                            locale: _locale,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ),
              Expanded(
                child: Align(
                  // Top, not centre. A question anchored to the top of the
                  // screen stays where the child last looked; a centred one
                  // jumps every time the answer row changes height.
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 44),
                      child: switch (_stage) {
                        _Stage.welcome => Onboarding(
                          onDone: (answers) {
                            // The voice the parent chose becomes the voice the
                            // child learns with, for the rest of the session.
                            PrimarVoice.instance
                                .init(
                                  locale: answers.locale,
                                  voiceId: answers.voiceId,
                                )
                                .then(
                                  (_) => PrimarVoice.instance.say(
                                    VoiceLines.handoffParent,
                                  ),
                                );
                            unawaited(
                              LearnerProfileStore.instance
                                  .saveAnswers(answers, seenDemo: false),
                            );
                            unawaited(
                              EvidenceStore.instance.bindChild(answers.name),
                            );
                            setState(() {
                              _answers = answers;
                              _estimate = Screener.estimate(answers);
                            });
                            _go(_Stage.home);
                          },
                        ),
                        _Stage.home => HomeScreen(
                          name: _name,
                          locale: _locale,
                          subject: _subject,
                          // A returning child goes straight into a session; the
                          // handoff and the demonstration are for the very first
                          // time only, and showing them again every day would be
                          // three taps of ceremony before anything happens.
                          onPlay: _startPlay,
                        ),
                        _Stage.handoff => _Handoff(
                          name: _name,
                          subject: _subject,
                          strings: _s,
                          onReady: () => _go(_Stage.demo),
                        ),
                        _Stage.demo => _DemoReel(
                          subject: _subject,
                          locale: _locale,
                          onReady: () {
                            _seenDemo = true;
                            widget.onSeenDemo?.call();
                            unawaited(
                              LearnerProfileStore.instance.markSeenDemo(),
                            );
                            _go(_Stage.warmUp);
                          },
                        ),
                        _Stage.warmUp => _WarmUp(
                          subject: _subject,
                          locale: _locale,
                          estimate: _estimate,
                          onDone: (results) {
                            setState(() {
                              _beginAt = Screener.startFromProbe(
                                results,
                                _estimate,
                              );
                            });
                            _go(_Stage.session);
                          },
                          // Reading only. Written before the session opens, so the
                          // engine's very first decision already knows what the
                          // child just showed us rather than starting from nothing.
                          onEvidence: (evidence) =>
                              EvidenceStore.instance.addAll(evidence),
                        ),
                        _Stage.session => _Session(
                          subject: _subject,
                          locale: _locale,
                          beginAt: _beginAt,
                          preferredSkillId: _sessionSkillId,
                          chrome: _chrome,
                          onFinish: (p, misses) {
                            _misses = misses;
                            // Recorded before the result is shown, so a child who
                            // closes the app on the celebration screen still keeps
                            // what they earned.
                            MasteryStore.instance.record(
                              // Locale-specific, so a French reading session never
                              // merges its score into the English letter node.
                              topicId: _subject.topicIdFor(_locale),
                              placement: p,
                            );
                            setState(() => _placement = p);
                            // After the scene bump, never before: a line queued
                            // for the screen we are about to leave is exactly what
                            // the bump throws away.
                            _go(_Stage.result);
                            PrimarVoice.instance.say(VoiceLines.resultParent);
                          },
                        ),
                        _Stage.result => _Result(
                          name: _childName.trim().isEmpty
                              ? 'Your child'
                              : _childName.trim(),
                          subject: _subject,
                          locale: _locale,
                          placement: _placement!,
                          misses: _misses,
                          // Straight back into it. A child who has just finished a
                          // session does not need the rule demonstrated again, and
                          // does not need a second warm-up — the session they just
                          // played is stronger evidence than three questions.
                          onAgain: () => _go(_Stage.session),
                          onHome: () => _go(_Stage.home),
                          onProgress: () => _go(_Stage.progress),
                        ),
                        _Stage.progress => _Progress(
                          name: _name,
                          locale: _locale,
                          subject: _subject,
                          onPlay: () => _go(_Stage.session),
                        ),
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* Shared surface                                                      */
/* ------------------------------------------------------------------ */

class _Sheet extends StatelessWidget {
  const _Sheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.tape = TapeTone.blue,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final TapeTone tape;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          decoration: PrimarTheme.paperSheet(),
          padding: padding,
          child: child,
        ),
        Positioned(top: -11, child: TapeStrip(tone: tape)),
        if (clip)
          const Positioned(top: -16, right: 26, child: Paperclip(size: 42)),
      ],
    );
  }
}

/* ------------------------------------------------------------------ */
/* Handoff                                                             */
/* ------------------------------------------------------------------ */

class _Handoff extends StatelessWidget {
  const _Handoff({
    required this.name,
    required this.subject,
    required this.strings,
    required this.onReady,
  });

  final String name;
  final Subject subject;
  final S strings;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      tape: TapeTone.kraft,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Doodle(
                kind: DoodleKind.burst,
                size: 20,
                color: PrimarTheme.yellow,
                angle: -0.3,
              ),
              SizedBox(width: 6),
              Mate(mood: Mood.happy, size: 104),
              SizedBox(width: 6),
              Doodle(
                kind: DoodleKind.star,
                size: 20,
                color: PrimarTheme.teal,
                angle: 0.3,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            strings.handoffTitle(name),
            textAlign: TextAlign.center,
            style: PrimarTheme.display(26),
          ),
          const SizedBox(height: 12),
          Text(
            strings.handoffBody,
            textAlign: TextAlign.center,
            style: PrimarTheme.body(15),
          ),
          const SizedBox(height: 24),
          PaperButton(
            onPressed: onReady,
            child: Text(
              strings.handoffButton,
              style: PrimarTheme.display(
                18,
                color: Colors.white,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* Demo — the rule is taught by watching, never by reading              */
/* ------------------------------------------------------------------ */

class _DemoReel extends StatefulWidget {
  const _DemoReel({
    required this.subject,
    required this.locale,
    required this.onReady,
  });

  final Subject subject;
  final String locale;
  final VoidCallback onReady;

  @override
  State<_DemoReel> createState() => _DemoReelState();
}

class _DemoReelState extends State<_DemoReel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<PrimarItem> _items = demonstrationsFor(
    widget.subject,
    widget.locale,
  );
  int _index = 0;
  int _seen = 1;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2700),
          )
          ..addStatusListener(_onCycle)
          ..forward();
    _speak();
  }

  void _onCycle(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() {
      _index = (_index + 1) % _items.length;
      _seen = min(_items.length, _seen + 1);
    });
    _speak();
    _controller.forward(from: 0);
  }

  void _speak() {
    final line = VoiceLines.byId(_items[_index].spoken);
    if (line != null) PrimarVoice.instance.say(line);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onCycle);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];
    final ready = _seen >= _items.length;

    return Column(
      children: [
        const SizedBox(height: 4),
        Mate(mood: ready ? Mood.happy : Mood.thinking, size: 84),
        const SizedBox(height: 8),
        _Sheet(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 22),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              // The parts lean toward each other, then the answer appears and
              // holds. Nothing travels far enough to leave its slot.
              final lean = t < 0.14
                  ? 0.0
                  : (t < 0.26 ? (t - 0.14) / 0.12 * 6 : 6.0);
              // The answer is never hidden.
              //
              // It used to fade in partway through the loop and out again at the
              // end, which left the row looking unfinished for much of the time
              // — the opposite of what a demonstration is for. Now it only
              // pops in scale on each cycle and then simply stays put.
              final pop = t < 0.26
                  ? 0.0
                  : (t < 0.42 ? (t - 0.26) / 0.16 : 1.0).clamp(0.0, 1.0);

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < item.prompt.length; i++)
                    Transform.translate(
                      offset: Offset(i == 0 ? lean : (i == 2 ? -lean : 0), 0),
                      child: FigureView(
                        figure: item.prompt[i],
                        size: _demoSize(item),
                      ),
                    ),
                  SizedBox(
                    width: _demoSize(item),
                    height: _demoSize(item),
                    child: Transform.scale(
                      scale: 0.9 + 0.1 * pop,
                      child: Center(
                        child: FigureView(
                          figure: item.options[item.answerIndex],
                          color: PrimarTheme.answerInk,
                          size: _demoSize(item),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _index ? 26 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: i == _index
                      ? PrimarTheme.blue
                      : PrimarTheme.navy.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        if (!ready)
          TextButton(
            onPressed: () {
              PrimarVoice.instance.say(VoiceLines.yourTurn);
              widget.onReady();
            },
            child: Text(
              widget.locale == 'fr' ? 'Passer' : 'Skip',
              style: PrimarTheme.body(14, color: PrimarTheme.blue),
            ),
          ),
        if (!ready) const SizedBox(height: 8),
        PaperButton(
          expand: false,
          circular: true,
          onPressed: ready
              ? () {
                  PrimarVoice.instance.say(VoiceLines.yourTurn);
                  widget.onReady();
                }
              : null,
          child: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ],
    );
  }
}

/// How wide a prompt row is allowed to draw its figures.
///
/// ## Why this counts width rather than figures
///
/// It used to be `prompt.length >= 5 ? 46 : 56` — a count of items, on the
/// assumption that every figure costs the same. A listen button does not: it
/// renders at 1.5x its nominal size, so four of them plus the answer slot came
/// to 392 logical pixels inside a 360 pixel row and overflowed by 32.
///
/// Nothing had four listen buttons until blending arrived, where the prompt
/// *is* a row of sounds. So the rule now adds up what the row actually costs
/// and divides the space available, which stays correct for whatever mix of
/// figures a future rung puts there.
double _promptSize(PrimarItem item, double available) {
  // Relative width of each figure at nominal size 1. Listen buttons are the
  // only ones that draw wider than they are asked to.
  double cost(Figure f) => switch (f) {
    SoundFigure() => 1.5,
    PhraseFigure() => 2.2,
    _ => 1.0,
  };

  var units = item.prompt.fold<double>(0, (sum, f) => sum + cost(f));
  // The mystery slot the session adds when there are options to choose from.
  if (item.options.isNotEmpty) units += 1;
  if (units <= 0) return 56;

  // A floor, because a figure shrunk far enough to fit is a figure a child
  // cannot see. Below this the row is better off scaled as a whole.
  return (available / units).clamp(34.0, 56.0);
}

/// Session prompts are the only thing on screen — give them the space.
///
/// Brilliant puts one question in the centre and lets it breathe. The warm-up
/// and demo keep [_promptSize]'s tighter cap; here the row can grow until the
/// child is looking at figures, not thumbnails.
double _sessionPromptSize(PrimarItem item, double available) {
  final base = _promptSize(item, available);
  return base.clamp(48.0, min(available * 0.22, 88.0));
}

/// The demonstration is the only place the rule is ever explained, so its
/// figures are drawn considerably larger than the ones in the session.
double _demoSize(PrimarItem item) => item.prompt.length >= 4 ? 62 : 84;

/* ------------------------------------------------------------------ */
/* Warm-up — the only placement evidence that comes from the child      */
/* ------------------------------------------------------------------ */

/// Three questions, spread wide, answered by the child.
///
/// Everything the parent said in onboarding does exactly one job: it picks
/// which three levels these questions come from. This screen is where the
/// child gets to overrule them, and it usually does — a parent's report is a
/// memory of something they saw once, and this is the child, now.
///
/// Three rules make it a warm-up rather than a test:
///
///  * **No timer.** The countdown belongs in the session, where a child
///    already knows the game.
///  * **Nothing is marked.** Both answers are met the same way. A child who
///    gets all three wrong sees three friendly screens, and the only
///    consequence is that the real game starts somewhere they can win.
///  * **No score is shown.** Not to the child, and not to the parent — the
///    number of warm-ups answered is not a result, it is a starting position.
class _WarmUp extends StatefulWidget {
  const _WarmUp({
    required this.subject,
    required this.locale,
    required this.estimate,
    required this.onDone,
    this.onEvidence,
  });

  final Subject subject;
  final String locale;
  final Estimate estimate;

  /// The staircase's view of the warm-up, for the subjects still on it.
  final void Function(List<ProbeResult>) onDone;

  /// The same three answers, tagged with the skill each one tested.
  ///
  /// Only reading produces these, because only reading has a skill graph. See
  /// [_WarmUpState._skillProbe] for why they exist at all.
  ///
  /// Returns a Future and is awaited before [onDone] fires: the session reads
  /// the evidence log the moment it opens, so a write that is merely started
  /// is a write the first question will not see.
  final Future<void> Function(List<Evidence>)? onEvidence;

  @override
  State<_WarmUp> createState() => _WarmUpState();
}

class _WarmUpState extends State<_WarmUp> {
  late final List<int> _levels = widget.estimate.probeLevels;
  late final Random _rng = Random(DateTime.now().microsecondsSinceEpoch);

  /// Reading probes *skills*, everything else probes levels.
  ///
  /// ## The bug this closes
  ///
  /// The warm-up asked three questions, the child answered them, and for
  /// reading every one was thrown away. `startFromProbe` turned them into a
  /// `beginAt`, and the reading session never reads `beginAt` — it calls
  /// `_resumeFromEvidence`, which asks the engine, which reads the evidence
  /// log, which the warm-up never wrote to.
  ///
  /// So a brand-new reader answered five parent questions and three of their
  /// own and the engine still started from nothing. The one screen where the
  /// child tells us something true about themselves was decorative.
  ///
  /// Levels are not the currency the engine deals in, so translating is not
  /// enough — the questions themselves have to come from skills. These are the
  /// first few teachable skills in path order, which is exactly the frontier a
  /// new learner should be measured against.
  late final List<String> _skillProbe = _graphProbe();

  /// Which skills to try, chosen from what the parent told us.
  ///
  /// Not simply the first three. The screener's whole remaining job is this
  /// one decision, and taking the front of the path regardless would have made
  /// every parent answer — age, schooling, what they have watched their child
  /// do — change nothing at all, which is a questionnaire with no consequence.
  ///
  /// So the estimate's levels are mapped onto positions in the path. A
  /// twelve-year-old whose parent says they read short words gets probed near
  /// decoding; a five-year-old who has never been to school gets probed at
  /// hearing first sounds. Both are then overruled by what they actually do —
  /// the answers become evidence, and the engine reads evidence.
  List<String> _graphProbe() {
    // Any subject with a graph, not just reading — numeracy has one now, and
    // a warm-up whose answers are thrown away is the defect this whole
    // mechanism exists to have fixed.
    final order = pathOrder(subject: widget.subject);
    if (order.isEmpty) return const [];

    // Screener levels run 1–10; the path is however long the graph is.
    int place(int level) => (((level - 1) / 9) * (order.length - 1))
        .round()
        .clamp(0, order.length - 1);

    final seen = <String>{};
    final picked = <String>[];
    for (final level in _levels) {
      final id = order[place(level)].id;
      if (seen.add(id)) picked.add(id);
    }

    // The probe levels can collapse onto the same rung on a short path. Pad
    // forward so the child still gets the number of questions the warm-up
    // promised rather than a silently shorter one.
    for (var i = 0; picked.length < _levels.length && i < order.length; i++) {
      if (seen.add(order[i].id)) picked.add(order[i].id);
    }
    return picked;
  }

  bool get _bySkill => _skillProbe.length == _levels.length;

  final List<ProbeResult> _results = [];

  /// What the child actually showed us, in the form the engine reads.
  final List<Evidence> _evidence = [];

  DateTime _shownAt = DateTime.now();
  late PrimarItem _item;
  int _at = 0;
  int? _chosen;
  bool _revealing = false;

  @override
  void initState() {
    super.initState();
    _item = _generate(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PrimarVoice.instance.sayAll([
        VoiceLines.warmUpChild,
        if (_item.spokenAll.isNotEmpty)
          ..._item.spokenAll.map(VoiceLines.byId)
        else
          VoiceLines.byId(_item.spoken),
      ]);
    });
  }

  /// The warm-up only ever uses tap-one-of-these.
  ///
  /// Match boards and drag-to-order are better questions, and both are the
  /// wrong question here: they take far longer than a warm-up should, and a
  /// child meeting the game for the first time would be learning the
  /// interaction rather than showing what they know. A level whose generator
  /// offers them is re-rolled until it offers a choice.
  PrimarItem _generate(int i) {
    if (_bySkill) {
      // Full scaffolding, always. This is the first thing a child ever sees;
      // withdrawing support here would measure their nerve, not their reading.
      for (var attempt = 0; attempt < 24; attempt++) {
        final item = generateItemForSkill(
          _skillProbe[i],
          _rng,
          index: 900 + i + attempt * 31,
          locale: widget.locale,
          support: Support.full,
        );
        if (item.interaction == Interaction.choose && item.options.isNotEmpty) {
          return item;
        }
      }
    }
    for (var attempt = 0; attempt < 24; attempt++) {
      final item = generateForSubject(
        widget.subject,
        _levels[i],
        _rng,
        900 + i + attempt * 31,
        widget.locale,
      );
      if (item.interaction == Interaction.choose && item.options.isNotEmpty)
        return item;
    }
    // Every level has at least one choice form, so this is unreachable — but a
    // warm-up that threw would take down a child's first minute.
    return generateForSubject(widget.subject, 1, _rng, 900 + i, widget.locale);
  }

  void _choose(int index) {
    if (_revealing) return;
    final correct = index == _item.answerIndex;

    HapticFeedback.lightImpact();
    setState(() {
      _chosen = index;
      _revealing = true;
    });

    // Both answers sound the same. A warm-up that celebrates one and
    // consoles the other has told the child it was a test after all.
    PrimarVoice.instance.chime(correct ? Sfx.correct : Sfx.tap);
    _results.add(ProbeResult(level: _levels[_at], correct: correct));
    if (_bySkill) {
      _evidence.add(
        Evidence(
          skillId: _skillProbe[_at],
          correct: correct,
          elapsedMs: DateTime.now().difference(_shownAt).inMilliseconds,
          at: DateTime.now(),
          // A warm-up answer is a genuine observation but a thin one: three
          // questions, no teaching, no second look. Never marked as transfer,
          // so it can raise the starting point without ever being mistaken for
          // proof that a skill is solid.
          isTransfer: false,
        ),
      );
    }

    Future.delayed(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      if (_at == _levels.length - 1) {
        PrimarVoice.instance.say(VoiceLines.warmUpDone);
        if (_bySkill && widget.onEvidence != null) {
          await widget.onEvidence!(_evidence);
        }
        if (!mounted) return;
        widget.onDone(_results);
        return;
      }
      setState(() {
        _at++;
        _item = _generate(_at);
        _chosen = null;
        _revealing = false;
        _shownAt = DateTime.now();
      });
      if (_item.spokenAll.isNotEmpty) {
        PrimarVoice.instance.sayAll(_item.spokenAll.map(VoiceLines.byId));
      } else {
        PrimarVoice.instance.say(VoiceLines.byId(_item.spoken));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _levels.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i <= _at ? 22 : 10,
                height: 7,
                decoration: BoxDecoration(
                  color: i < _at
                      ? PrimarTheme.teal
                      : i == _at
                      ? PrimarTheme.blue
                      : PrimarTheme.navy.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Mate(mood: _revealing ? Mood.happy : Mood.thinking, size: 78),
        const SizedBox(height: 6),
        _Sheet(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 28),
          child: LayoutBuilder(
            builder: (context, box) {
              final size = _promptSize(_item, box.maxWidth);
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final f in _item.prompt)
                      FigureView(figure: f, size: size),
                    if (_item.options.isNotEmpty) MysterySlot(size: size),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          children: [
            for (var i = 0; i < _item.options.length; i++)
              _OptionTile(
                figure: _item.options[i],
                // Nothing is revealed as right or wrong. The tile the child
                // touched lights up because they touched it, and that is all
                // that happens here.
                isAnswer: false,
                chosen: _chosen == i,
                revealing: false,
                burst: null,
                onTap: () => _choose(i),
              ),
          ],
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------------ */
/* Session — deliberately the quietest screen in the product            */
/* ------------------------------------------------------------------ */

class _Session extends StatefulWidget {
  const _Session({
    required this.subject,
    required this.locale,
    required this.beginAt,
    required this.chrome,
    required this.onFinish,
    this.preferredSkillId,
  });

  final Subject subject;
  final String locale;

  /// The pinned bar above. Written to, never read from — the session is the
  /// only thing that knows how far along it is.
  final LessonChrome chrome;

  /// Where the first question sits, from the warm-up the child just answered.
  /// Null only if the warm-up was skipped entirely.
  final int? beginAt;

  /// Path node the child tapped — first engine item uses this skill when valid.
  final String? preferredSkillId;

  final void Function(Placement, MisconceptionTracker) onFinish;

  @override
  State<_Session> createState() => _SessionState();
}

class _SessionState extends State<_Session> with TickerProviderStateMixin {
  @override
  void dispose() {
    _encourageTimer?.cancel();
    _tickTimer?.cancel();
    _comboTimer?.cancel();
    _ring.dispose();
    _burst.dispose();
    PrimarVoice.instance.interrupt();
    super.dispose();
  }

  // Opens on the default until the stored level is read, then restarts on it.
  // Reading is a single local lookup, so the swap happens before a child has
  // had time to look at the first question.
  SessionState _state = startSession(subject: Subject.shapes);
  late PrimarItem _item;
  bool _warming = true;
  int? _chosen;
  bool _revealing = false;
  bool _lastCorrect = false;
  DateTime _shownAt = DateTime.now();
  Timer? _encourageTimer;
  int _lastLevel = startLevel;
  int _streak = 0;

  /// Watches *what* keeps going wrong, not just how often.
  final MisconceptionTracker _misses = MisconceptionTracker();

  /// A fresh explanation to show alongside the spoken teaching, when the same
  /// difficulty keeps recurring. Null until a pattern emerges, and null forever
  /// if nothing was ever banked — the built-in teaching stands alone.
  String? _freshAngle;

  /// Rotates the variant, so a third miss is not the second explanation again.
  int _angleAttempt = 0;

  LearnerTraits? _traits;

  /// What the child can be invited to say back, if anything. A shape
  /// composition has no name, so most shape items offer nothing here.
  String? get _sayTarget => SayItButton.targetFor(_item);

  /// Drains while the child decides. Purely a sense of momentum — it never
  /// ends a question or marks anything wrong.
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  /// Ticks audibly as the ring drains, and when it empties the answer is shown
  /// and explained rather than marked wrong. Running out is not failing — it is
  /// the point at which a child has clearly been left alone too long, and the
  /// right response to that is help.
  Timer? _tickTimer;
  int _ticksLeft = 0;

  /// Fires on the tile a child just got right. A colour change alone is easy
  /// to miss on a bright screen outdoors — a child needs to *see* that they
  /// were right, not infer it.
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /// After a miss the child is taught, then handed the *same* item again.
  /// Getting it right on that second look is the only real evidence the
  /// teaching landed — "I do, we do, you do", with the last step actually
  /// present rather than assumed.
  bool _isRetry = false;

  /// Second miss on this skill this session — a named micro-lesson, then retry.
  final SessionMissWatch _skillMisses = SessionMissWatch();
  MicroLesson? _microLesson;
  MicroLesson? _pendingMicroLesson;
  bool _microAfterScore = false;
  List<Evidence>? _heldEngineLog;
  SessionState? _heldStaircase;

  /// Which subjects the learning engine drives.
  ///
  /// Still a statement of what has been built rather than a feature flag, and
  /// the statement has changed: numeracy now has a real skill graph, so it gets
  /// the engine too. Shapes does not, and until it has one the staircase is the
  /// honest thing to leave it on — pointing the engine at a graph that does not
  /// exist would be worse than a level number.
  ///
  /// The subject travels into every engine call, because one evidence log holds
  /// everything a child has touched. Without it a numeracy session's frontier
  /// would include letter sounds.
  bool get _useEngine => teachableSkillsFor(widget.subject).isNotEmpty;

  Decision? _decision;
  Support _support = Support.full;
  int _reviewsThisSession = 0;
  int _engineAnswered = 0;

  /// The plan showing right now, if the engine asked for a different way in.
  ///
  /// The policy could always return [Reason.reteach]; nothing rendered it, so
  /// the decision was computed and discarded and the child got the next
  /// question as if their third identical mistake had gone unnoticed.
  Intervention? _reteach;

  /// The letter behind the recurring mistake, when there is one.
  String? _reteachLetter;

  /// Mistakes already re-taught this session. Shown once — a "different way in"
  /// repeated every visit stops being different and becomes the drill.
  final Set<Misconception> _reteachShown = {};

  /// Ways of answering the child has already been shown how to use.
  ///
  /// Checked in [build] rather than at every point an item is assigned. The
  /// item is set from five different places — resume, engine advance, retry,
  /// staircase, and after a reteach card — and a check placed at each of them
  /// is a check that will be missed the sixth time. One gate on the render
  /// path cannot be routed around.
  final Set<Interaction> _mechanicsSeen = {};

  /// Whether the card currently on screen has already said its line.
  bool _mechanicSpoken = false;

  /// Mate watches while the child decides, then reacts. This is the only
  /// feedback a non-reader gets, so it has to be immediate and unmistakable.
  void _speakBrain(
    TutorMoment moment, {
    int chosenIndex = -1,
    Misconception? misconception,
    int retryCount = 0,
    Iterable<VoiceLine?> after = const [],
    String? speakTarget,
    bool speakMatched = false,
    String? heard,
    String? letter,
    String? sound,
  }) {
    PrimarVoice.instance.sayFromBrain(
      TutorContext(
        moment: moment,
        locale: widget.locale,
        skillId: _decision?.skillId,
        item: _item,
        chosenIndex: chosenIndex,
        retryCount: retryCount,
        streak: _streak,
        misconception: misconception,
        traits: _traits,
        speakTarget: speakTarget,
        speakMatched: speakMatched,
        heard: heard,
        letter: letter,
        sound: sound,
      ),
      after: after,
    );
  }

  /// Right answers this session, for the tally in the pinned bar.
  ///
  /// Counted here rather than derived from the attempt log because the engine
  /// path does not write attempts — it writes evidence — and the bar has to
  /// read the same number on both paths.
  int _correctThisSession = 0;

  /// Copies what the pinned bar shows out of session state.
  ///
  /// Called from `build` but applied after the frame: the bar lives above this
  /// widget in the tree, so writing its notifiers during this build would mark
  /// an ancestor dirty mid-build. One call site, because a bar updated from
  /// each of the eight places state changes is a bar that is wrong in the
  /// place someone forgot.
  void _publishChrome() {
    final total = _state.length;
    final done = _useEngine ? _engineAnswered : _state.attempts.length;
    final progress = total == 0 ? 0.0 : done / total;
    final mood = _warming ? Mood.idle : _mood;
    final correct = _correctThisSession;
    final sayTarget = _sayTarget;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.chrome.visible.value = true;
      widget.chrome.progress.value = progress;
      widget.chrome.mood.value = mood;
      widget.chrome.correct.value = correct;
      widget.chrome.streak.value = _streak;
      widget.chrome.toolsVisible.value = !_warming;
      widget.chrome.sayAvailable.value = sayTarget != null;
      widget.chrome.onHear = _speakPrompt;
      widget.chrome.onHint = _toolHint;
      widget.chrome.onSay = sayTarget == null ? null : _toolSay;
    });
  }

  void _toolHint() {
    if (_warming || _revealing) return;
    PrimarVoice.instance.chime(Sfx.tap);
    final hint = _actionHint();
    PrimarVoice.instance.sayTutor(
      TutorFeedback(
        id: 'hint_${_item.id}',
        text: hint,
        parentMoment: ParentMoment.patience,
      ),
    );
  }

  void _toolSay() {
    final target = _sayTarget;
    if (target == null) return;
    PrimarVoice.instance.chime(Sfx.tap);
    _speakBrain(
      TutorMoment.speak,
      speakTarget: target,
      speakMatched: false,
    );
  }

  /// Combo milestones a child can feel — 3 / 5 / 8 in a row.
  String? _comboBanner;
  Timer? _comboTimer;

  void _maybeCelebrateCombo() {
    if (_streak != 3 && _streak != 5 && _streak != 8) return;
    PrimarVoice.instance.chime(Sfx.levelUp);
    HapticFeedback.mediumImpact();
    final fr = widget.locale == 'fr';
    final line = switch (_streak) {
      3 => fr ? 'En feu ! ×3' : 'On fire! ×3',
      5 => fr ? 'Incroyable ! ×5' : 'Amazing! ×5',
      _ => fr ? 'Champion ! ×8' : 'Champion! ×8',
    };
    setState(() => _comboBanner = line);
    _comboTimer?.cancel();
    _comboTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _comboBanner = null);
    });
  }

  Mood get _mood => !_revealing
      ? Mood.thinking
      : _lastCorrect
      ? Mood.happy
      : Mood.encourage;

  @override
  void initState() {
    super.initState();
    _state = startSession(subject: widget.subject, locale: widget.locale);
    _item = nextItem(_state);
    _resolveWarmStart();
  }

  /// Picks up where this child left off, or — for a child with no history —
  /// begins where their warm-up landed rather than in the middle for everyone.
  ///
  /// A child who has played before is placed by their own past sessions, which
  /// is stronger evidence than three warm-up questions, so history wins.
  Future<void> _resolveWarmStart() async {
    // Reading is driven by the learning engine and its stored evidence; the
    // other subjects still run on the staircase.
    if (_useEngine) {
      await _resumeFromEvidence();
      return;
    }

    final last = await MasteryStore.instance.lastSettledLevel(
      widget.subject.topicIdFor(widget.locale),
    );
    if (!mounted) return;

    if (last == null && widget.beginAt != null) {
      final fresh = startSession(
        subject: widget.subject,
        locale: widget.locale,
        beginAt: widget.beginAt!,
      );
      setState(() {
        _state = fresh;
        _item = nextItem(fresh);
        _warming = false;
        _shownAt = DateTime.now();
      });
      _speakPrompt();
      return;
    }

    if (last != null) {
      final fresh = startSession(
        subject: widget.subject,
        locale: widget.locale,
        beginAt: warmStartFrom(last),
        length: returningSessionLength,
      );
      setState(() {
        _state = fresh;
        _item = nextItem(fresh);
        _warming = false;
        _shownAt = DateTime.now();
      });
    } else {
      setState(() => _warming = false);
    }
    _speakPrompt();
  }

  /// Picks up where this child left off — including on a previous day.
  Future<void> _resumeFromEvidence() async {
    final log = await EvidenceStore.instance.load();
    if (!mounted) return;
    _traits = await LearnerTraitsStore.instance.recomputeFrom(
      log,
      locale: widget.locale,
      subject: widget.subject,
    );
    if (!mounted) return;

    final decision = _decisionForStart(log);
    if (decision.exhausted) {
      // Everything reachable is finished. Falling back to the staircase keeps
      // a child playing rather than showing them a dead end they cannot act on.
      setState(() => _warming = false);
      _speakPrompt();
      return;
    }

    setState(() {
      _decision = decision;
      _support = supportFor(learnerFrom(log).stateOf(decision.skillId!));
      _item = generateItemForSkill(
        decision.skillId!,
        Random(DateTime.now().microsecondsSinceEpoch),
        index: log.length,
        locale: widget.locale,
        support: _support,
      );
      _warming = false;
      _shownAt = DateTime.now();
    });
    _speakPrompt();
  }

  /// First skill this session — honour a path tap when the skill is playable.
  Decision _decisionForStart(List<Evidence> log) {
    final learner = learnerFrom(log, locale: widget.locale);
    final preferred = widget.preferredSkillId;
    if (preferred != null) {
      final skill = skillsById[preferred];
      if (skill != null && skill.subject == widget.subject) {
        final st = learner.stateOf(preferred);
        final onPath = pathOrder(subject: widget.subject)
            .any((s) => s.id == preferred);
        final reachable = learner.frontier(subject: widget.subject)
            .any((s) => s.id == preferred);
        if (onPath &&
            (st.state == MasteryState.mastered ||
                st.attempts > 0 ||
                reachable)) {
          final reason = st.state == MasteryState.mastered
              ? Reason.review
              : Reason.advance;
          return Decision(
            skillId: preferred,
            reason: reason,
            explain: 'Working on ${skill.label}.',
          );
        }
      }
    }
    return nextSkill(learner, subject: widget.subject);
  }

  /// Records one answer as evidence and asks the engine what comes next.
  Future<void> _advanceEngine(bool correct, int chosenIndex) async {
    final log = await _commitEngineEvidence(correct, chosenIndex);
    if (log == null) return;
    await _presentNextFromEngine(log);
  }

  /// Writes the attempt. Null when the session is over or we unmounted.
  ///
  /// Split from presenting the next item so a micro-lesson can sit between
  /// the score and the next question without scoring twice or skipping it.
  Future<List<Evidence>?> _commitEngineEvidence(
    bool correct,
    int chosenIndex,
  ) async {
    final evidence = Evidence(
      skillId: _decision!.skillId!,
      correct: correct,
      elapsedMs: DateTime.now().difference(_shownAt).inMilliseconds,
      at: DateTime.now(),
      neededTeaching: _isRetry,
      misconception: correct || chosenIndex < 0
          ? Misconception.unclear
          : classifyMiss(_item, chosenIndex),
      // Transfer is not a kind of question, it is a question asked with the
      // scaffolding gone.
      isTransfer: isTransferEvidence(_support),
    );

    final log = await EvidenceStore.instance.add(evidence);
    if (!mounted) return null;

    _engineAnswered++;
    if (_engineAnswered >= _state.length) {
      PrimarVoice.instance.chime(Sfx.finish);
      PrimarVoice.instance.say(VoiceLines.allDone);
      widget.chrome.visible.value = false;
      widget.onFinish(_placementFromEngine(log), _misses);
      return null;
    }
    return log;
  }

  Future<void> _presentNextFromEngine(List<Evidence> log) async {
    final learner = learnerFrom(log, locale: widget.locale);
    final decision = nextSkill(
      learner,
      reviewsSoFar: _reviewsThisSession,
      subject: widget.subject,
    );

    if (decision.reason == Reason.reteach) {
      final miss = learner.stateOf(decision.skillId!).dominantMisconception;
      if (!_reteachShown.contains(miss)) {
        _reteachShown.add(miss);
        final answer =
            _item.options.isEmpty || _item.answerIndex >= _item.options.length
            ? null
            : _item.options[_item.answerIndex];
        setState(() {
          _decision = decision;
          _reteach = interventionFor(miss);
          _reteachLetter = answer is LetterFigure ? answer.letter : null;
          _chosen = null;
          _revealing = false;
        });
        return;
      }
    }

    if (decision.exhausted) {
      PrimarVoice.instance.chime(Sfx.finish);
      widget.chrome.visible.value = false;
      widget.onFinish(_placementFromEngine(log), _misses);
      return;
    }
    if (decision.reason == Reason.review) _reviewsThisSession++;

    final support = supportFor(learner.stateOf(decision.skillId!));
    setState(() {
      _decision = decision;
      _support = support;
      _item = generateItemForSkill(
        decision.skillId!,
        Random(DateTime.now().microsecondsSinceEpoch),
        index: log.length,
        locale: widget.locale,
        support: support,
      );
      _chosen = null;
      _revealing = false;
      _isRetry = false;
      _freshAngle = null;
      _shownAt = DateTime.now();
    });
    _speakPrompt();
  }

  /// The engine's result, in the shape the parent-facing screen already reads.
  ///
  /// The "level" here is how many skills the child has actually cleared, which
  /// is a real position on the graph rather than a rung on a ladder — the
  /// result screen also shows what they can do in words, which is the part that
  /// means anything.
  Placement _placementFromEngine(List<Evidence> log) {
    final learner = learnerFrom(log, locale: widget.locale);
    // This subject's skills, not every skill on record. A child who has done
    // reading and then opens numeracy must not be told they have already
    // cleared most of it.
    final mySkills = teachableSkillsFor(widget.subject);
    final cleared = mySkills.where((s) => learner.isCleared(s.id)).length;
    final mine = log.where((e) => e.skillId == _decision?.skillId).toList();
    final correct = mine.where((e) => e.correct).length;
    final times = log.map((e) => e.elapsedMs).toList()..sort();

    return Placement(
      level: cleared.toDouble().clamp(1, 10),
      masteryScore: mySkills.isEmpty
          ? 0
          : (cleared / mySkills.length).clamp(0.0, 1.0),
      accuracy: mine.isEmpty ? 0 : correct / mine.length,
      correct: correct,
      total: mine.length,
      medianMs: times.isEmpty ? 0 : times[times.length ~/ 2],
      provisional: cleared == 0,
    );
  }

  void _speakPrompt() {
    if (_item.spokenAll.isNotEmpty) {
      // Queued as one utterance so a tap cannot land between the sounds and
      // cut the word in half — for a blending question, half the sounds is
      // not a hint, it is a different question.
      PrimarVoice.instance.sayAll(_item.spokenAll.map(VoiceLines.byId));
    } else {
      PrimarVoice.instance.say(VoiceLines.byId(_item.spoken));
    }
    _armEncouragement();
    _startCountdown();
  }

  /// What the learner should do *on this exact screen*.
  ///
  /// The prompt row is visual by design, but a short action sentence removes
  /// guesswork ("tap the speaker, then..."), especially on oral rungs.
  String _actionHint() {
    final fr = widget.locale == 'fr';
    final id = (_decision?.skillId ?? _item.id).toLowerCase();
    final hasSoundPrompt = _item.prompt.any((f) => f is SoundFigure);

    if (_item.interaction == Interaction.match) {
      return fr
          ? 'Relie chaque image à sa paire.'
          : 'Match each picture to its pair.';
    }
    if (_item.interaction == Interaction.order) {
      return fr
          ? 'Mets les éléments dans le bon ordre.'
          : 'Put the items in the right order.';
    }
    if (_item.interaction == Interaction.spell) {
      return fr
          ? 'Construis le mot avec les lettres.'
          : 'Build the word with the letters.';
    }
    if (id.contains('pa.rhyme') || id.contains('rhyme')) {
      return fr
          ? 'Écoute, puis touche l’image qui rime.'
          : 'Listen, then tap the picture that rhymes.';
    }
    if (id.contains('pa.segment') || id.contains('endsound')) {
      return fr
          ? 'Écoute, puis touche l’image qui finit pareil.'
          : 'Listen, then tap the picture with the same ending sound.';
    }
    if (id.contains('pa.initial') || id.contains('initial')) {
      return fr
          ? 'Écoute, puis touche l’image qui commence pareil.'
          : 'Listen, then tap the picture with the same starting sound.';
    }
    if (hasSoundPrompt) {
      return fr
          ? 'Appuie sur le haut-parleur, puis choisis la bonne image.'
          : 'Tap the speaker, then choose the right picture.';
    }
    return fr ? 'Choisis la bonne réponse.' : 'Choose the right answer.';
  }

  void _startCountdown() {
    _ring.forward(from: 0);
    _tickTimer?.cancel();
    _ticksLeft = 14;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _revealing) {
        t.cancel();
        return;
      }
      _ticksLeft--;
      // Quiet for most of it, firmer in the last four seconds so the change is
      // felt without ever becoming an alarm.
      PrimarVoice.instance.tick(urgent: _ticksLeft <= 4);
      if (_ticksLeft <= 0) {
        t.cancel();
        _timeUp();
      }
    });
  }

  /// Time ran out. Show the answer and teach it — the same explanation a miss
  /// would get, because a child who could not decide needs exactly what a child
  /// who decided wrongly needs. It is never scored as an error.
  void _timeUp() {
    if (_revealing || !mounted) return;
    _encourageTimer?.cancel();
    PrimarVoice.instance.chime(Sfx.timesUp);
    setState(() {
      _revealing = true;
      _chosen = null;
      _streak = 0;
    });
    _offerFreshAngle();
    _speakBrain(
      TutorMoment.miss,
      chosenIndex: -1,
      retryCount: 0,
      after: VoiceLines.teachingFor(_item.teach),
    );

    Future.delayed(Duration(milliseconds: 2200 + 900 * _item.teach.length), () {
      if (!mounted) return;
      // Straight to a second go at the same question, unscored — the teaching
      // has just happened and this is where it gets used.
      _speakBrain(TutorMoment.retry);
      setState(() {
        _isRetry = true;
        _chosen = null;
        _revealing = false;
        _shownAt = DateTime.now();
      });
      _armEncouragement();
      _startCountdown();
    });
  }

  /// A child who has been staring for a while is not stuck, they are thinking.
  /// This says so out loud rather than leaving them in silence — and it never
  /// hurries them or hints at the answer.
  /// When one difficulty keeps recurring, put it a different way.
  ///
  /// Repeating identical words to a child who has missed the same thing three
  /// times is insistence rather than teaching. The variants were authored by a
  /// model and banked on the device, so this works with the network off.
  Future<void> _offerFreshAngle() async {
    final pattern = _misses.dominant;
    if (pattern == null) return;

    final line = await ExplanationBank.instance.variantFor(
      pattern,
      attempt: _angleAttempt,
    );
    if (!mounted) return;

    setState(() {
      _freshAngle = line;
      _angleAttempt++;
    });

    // Bank the rest for next time, if there is a connection to do it with.
    unawaited(ExplanationBank.instance.ensure(pattern));
  }

  void _armEncouragement() {
    _encourageTimer?.cancel();
    _encourageTimer = Timer(const Duration(seconds: 9), () {
      if (!mounted || _revealing) return;
      _speakBrain(TutorMoment.waiting);
    });
  }

  void _choose(int index) {
    if (_revealing) return;

    // -1 means "answered, but not correctly" — used by the match board, where
    // there is no single wrong tile to point at.
    final correct = index >= 0 && index == _item.answerIndex;
    setState(() {
      _chosen = index;
      _revealing = true;
      _lastCorrect = correct;
      if (correct) {
        _correctThisSession++;
        _streak++;
      } else {
        _streak = 0;
      }
    });

    _encourageTimer?.cancel();
    _tickTimer?.cancel();
    _ring.stop();

    final skillId = _decision?.skillId;

    if (correct) {
      _burst.forward(from: 0);
      HapticFeedback.lightImpact();
      if (_streak == 3 || _streak == 5 || _streak == 8) {
        _maybeCelebrateCombo();
      } else {
        PrimarVoice.instance.chime(_isRetry ? Sfx.streak : Sfx.correct);
      }
      _speakBrain(TutorMoment.correct, retryCount: _isRetry ? 1 : 0);
    } else if (_isRetry) {
      HapticFeedback.selectionClick();
      PrimarVoice.instance.chime(Sfx.wrong);
      // Second miss on the same item. Show the answer warmly — then, on the
      // second miss of this skill this session, a micro-lesson before moving on.
      final miss = index >= 0
          ? classifyMiss(_item, index)
          : Misconception.unclear;
      _queueMicroIfSecondMiss(index, miss);
      _speakBrain(
        TutorMoment.miss,
        chosenIndex: index,
        misconception: miss,
        retryCount: 1,
        after: VoiceLines.teachingFor(_item.teach),
      );
    } else {
      HapticFeedback.selectionClick();
      PrimarVoice.instance.chime(Sfx.wrong);
      // A miss is the moment a child is most ready to be taught. Name what they
      // chose and what was needed — then the item's own teaching lines.
      Misconception? miss;
      if (index >= 0) {
        _misses.record(_item, index);
        miss = classifyMiss(_item, index);
      }
      _queueMicroIfSecondMiss(index, miss ?? Misconception.unclear);
      _offerFreshAngle();
      _speakBrain(
        TutorMoment.miss,
        chosenIndex: index,
        misconception: miss,
        retryCount: 0,
        after: VoiceLines.teachingFor(_item.teach),
      );
    }

    // Correct moves on briskly; a miss lingers so the child actually sees the
    // right answer before the next question arrives.
    // Long enough for the teaching to be heard. Cutting it short would make
    // the explanation decorative.
    // Correct: hold on the green tile long enough to feel intentional — a
    // Brilliant-style beat between "got it" and the next question, not a glitch.
    final hold = correct
        ? const Duration(milliseconds: 1500)
        : Duration(milliseconds: 2200 + 900 * _item.teach.length);

    Future.delayed(hold, () {
      if (!mounted) return;

      if (!correct && _pendingMicroLesson != null) {
        unawaited(_openMicroLesson(scored: _isRetry, index: index));
        return;
      }

      // Taught, and not yet given a second go: hand the same question back.
      // The retry is not scored — it is the practice, not the measurement, and
      // scoring it would punish a child twice for one gap.
      if (!correct && !_isRetry) {
        _speakBrain(TutorMoment.retry);
        setState(() {
          _isRetry = true;
          _chosen = null;
          _revealing = false;
          _shownAt = DateTime.now();
        });
        _armEncouragement();
        _ring.forward(from: 0);
        return;
      }
      _continueAfterAnswer(correct, index);
    });
  }

  String _missKey() =>
      SessionMissWatch.keyFor(skillId: _decision?.skillId, item: _item);

  void _queueMicroIfSecondMiss(int index, Misconception miss) {
    if (!_skillMisses.onMiss(_missKey())) return;
    _pendingMicroLesson = MicroLesson.build(
      item: _item,
      locale: widget.locale,
      chosenIndex: index,
      skillId: _decision?.skillId,
      misconception: miss,
    );
  }

  /// Score first when this miss is the scored retry, then show the card.
  Future<void> _openMicroLesson({
    required bool scored,
    required int index,
  }) async {
    _tickTimer?.cancel();
    _encourageTimer?.cancel();
    _ring.stop();

    List<Evidence>? engineLog;
    SessionState? staircase;
    if (scored) {
      if (_useEngine && _decision != null) {
        engineLog = await _commitEngineEvidence(false, index);
        if (!mounted) return;
        if (engineLog == null) {
          _pendingMicroLesson = null;
          return;
        }
      } else {
        staircase = recordAttempt(
          _state,
          Attempt(
            itemId: _item.id,
            level: _item.level,
            correct: false,
            elapsedMs: DateTime.now().difference(_shownAt).inMilliseconds,
          ),
        );
        if (staircase.finished) {
          PrimarVoice.instance.chime(Sfx.finish);
          PrimarVoice.instance.say(VoiceLines.allDone);
          widget.chrome.visible.value = false;
          widget.onFinish(computePlacement(staircase), _misses);
          _pendingMicroLesson = null;
          return;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _microLesson = _pendingMicroLesson;
      _pendingMicroLesson = null;
      _microAfterScore = scored;
      _heldEngineLog = engineLog;
      _heldStaircase = staircase;
      _chosen = null;
      _revealing = false;
    });
  }

  void _onMicroRetry() {
    final scored = _microAfterScore;
    final engineLog = _heldEngineLog;
    final staircase = _heldStaircase;
    setState(() {
      _microLesson = null;
      _microAfterScore = false;
      _heldEngineLog = null;
      _heldStaircase = null;
    });

    if (scored) {
      if (engineLog != null) {
        unawaited(_presentNextFromEngine(engineLog));
        return;
      }
      if (staircase != null) {
        _presentNextFromStaircase(staircase);
        return;
      }
    }

    _speakBrain(TutorMoment.retry);
    setState(() {
      _isRetry = true;
      _chosen = null;
      _revealing = false;
      _shownAt = DateTime.now();
    });
    _armEncouragement();
    _startCountdown();
  }

  void _continueAfterAnswer(bool correct, int index) {
    if (_useEngine && _decision != null) {
      _advanceEngine(correct, index);
      return;
    }

    final updated = recordAttempt(
      _state,
      Attempt(
        itemId: _item.id,
        level: _item.level,
        correct: correct,
        elapsedMs: DateTime.now().difference(_shownAt).inMilliseconds,
      ),
    );

    if (updated.finished) {
      PrimarVoice.instance.chime(Sfx.finish);
      PrimarVoice.instance.say(VoiceLines.allDone);
      // The bar measures a session. On the result screen there is no session
      // left to measure, and a full bar sitting above a summary is just a
      // decoration that looks like information.
      widget.chrome.visible.value = false;
      widget.onFinish(computePlacement(updated), _misses);
      return;
    }

    _presentNextFromStaircase(updated);
  }

  void _presentNextFromStaircase(SessionState updated) {
    if (updated.currentLevel > _lastLevel) {
      PrimarVoice.instance.chime(Sfx.levelUp);
    }
    _lastLevel = updated.currentLevel;
    setState(() {
      _state = updated;
      _item = nextItem(updated);
      _chosen = null;
      _revealing = false;
      _isRetry = false;
      _freshAngle = null;
      _shownAt = DateTime.now();
    });
    _speakPrompt();
  }

  @override
  Widget build(BuildContext context) {
    _publishChrome();

    if (_warming) {
      final fr = widget.locale == 'fr';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const Mate(mood: Mood.thinking, size: 88),
            const SizedBox(height: 16),
            Text(
              fr ? 'On prépare ton jeu…' : 'Getting your game ready…',
              style: PrimarTheme.body(16, color: PrimarTheme.muted),
            ),
            const SizedBox(height: 14),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: PrimarTheme.blue,
              ),
            ),
          ],
        ),
      );
    }

    // A way of answering the child has not met yet. Shown before the question
    // rather than over it: a child who has only ever tapped one of four tiles
    // cannot be handed a row of empty slots and left to work it out while the
    // ring drains and the app decides they needed help.
    if (MechanicCard.needsIntroduction(_item.interaction) &&
        !_mechanicsSeen.contains(_item.interaction)) {
      // Spoken here rather than from the card's initState, so a rebuild while
      // it is on screen cannot make it say the line a second time.
      if (!_mechanicSpoken) {
        _mechanicSpoken = true;
        _ring.stop();
        _encourageTimer?.cancel();
        MechanicCard.speak(_item.interaction);
      }
      return MechanicCard(
        interaction: _item.interaction,
        locale: widget.locale,
        onReady: () {
          setState(() {
            _mechanicsSeen.add(_item.interaction);
            _mechanicSpoken = false;
            // The clock starts when the question does, not when the
            // explanation appeared — otherwise reading the instruction costs
            // the child the time they were given to think.
            _shownAt = DateTime.now();
          });
          _armEncouragement();
          _ring.forward(from: 0);
          _speakPrompt();
        },
      );
    }

    return Column(
      children: [
        // The dots and Mate that used to open this column now live in the
        // pinned bar at the top of the screen. What is left here is only the
        // question, which is the only thing that changes.
        //
        // The ring stays with the question rather than moving up with them: it
        // is about *this* item — how long the child has been looking at it —
        // and in the bar it read as a second, contradictory progress meter.
        Align(
          alignment: Alignment.centerRight,
          child: AnimatedBuilder(
            animation: _ring,
            builder: (context, _) =>
                ThinkingRing(progress: 1 - _ring.value, size: 22, stroke: 3),
          ),
        ),
        const SizedBox(height: 8),
        if (_microLesson != null) ...[
          MicroLessonCard(lesson: _microLesson!, onRetry: _onMicroRetry),
        ] else if (_reteach != null) ...[
          ReteachCard(
            plan: _reteach!,
            // The letter the child just got wrong, so the card can show it
            // rather than describe it. Null for anything that is not a letter
            // mistake, and the card falls back to words.
            letter: _reteachLetter,
            sound: _reteachLetter == null
                ? null
                : soundForLetter(_reteachLetter!, locale: widget.locale),
            locale: widget.locale,
            onReady: () {
              final d = _decision!;
              setState(() {
                _reteach = null;
                _reteachLetter = null;
                _support = Support.full;
                _item = generateItemForSkill(
                  d.skillId!,
                  Random(DateTime.now().microsecondsSinceEpoch),
                  index: _engineAnswered,
                  locale: widget.locale,
                  // Straight back to full scaffolding. A child who has just
                  // been shown a different way in needs everything available
                  // while they try it.
                  support: Support.full,
                );
                _shownAt = DateTime.now();
              });
              _speakPrompt();
            },
          ),
        ] else ...[
          if (_comboBanner != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ComboBanner(text: _comboBanner!),
            ),
          _ActionHintPill(text: _actionHint()),
          // Skipped entirely when there is nothing to show. An empty sheet is a
          // band of blank paper that reads as something failing to load.
          if (_item.hasVisiblePrompt || _item.options.isNotEmpty)
            AnimatedSwitcher(
              duration: PrimarMotion.medium,
              switchInCurve: PrimarMotion.enter,
              switchOutCurve: PrimarMotion.exit,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _Sheet(
                key: ValueKey(_item.id),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 36),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final size = _sessionPromptSize(_item, box.maxWidth);
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final f in _item.prompt)
                            FigureView(figure: f, size: size),
                          if (_item.options.isNotEmpty)
                            _revealing
                                ? FigureView(
                                    figure: _item.options[_item.answerIndex],
                                    color: PrimarTheme.answerInk,
                                    size: size,
                                  )
                                : MysterySlot(size: size),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          // Say it back. Offered only once the answer is on screen and right, so
          // a child is always practising something they have just got, never
          // being asked to produce something they do not have yet.
          if (_revealing && _lastCorrect && _sayTarget != null) ...[
            const SizedBox(height: 14),
            SayItButton(
              key: ValueKey('say-${_item.id}'),
              target: _sayTarget!,
              locale: widget.locale,
            ),
          ],
          if (_revealing && _freshAngle != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: PrimarTheme.yellow.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                children: [
                  const Doodle(
                    kind: DoodleKind.sparkle,
                    size: 20,
                    color: PrimarTheme.yellow,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _freshAngle!,
                      style: PrimarTheme.body(14.5, color: PrimarTheme.navy),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          if (_item.interaction == Interaction.spell)
            SpellRow(
              key: ValueKey(_item.id),
              item: _item,
              // Built or not, it is one answer to one question — there is no
              // partial credit in a word. `answerIndex` is passed on a correct
              // build so the rest of the session's bookkeeping, which is written
              // in terms of a chosen option, keeps working unchanged.
              onSolved: (correct) => _choose(correct ? _item.answerIndex : -1),
              onMiss: () => _misses.record(_item, -1),
            )
          else if (_item.interaction == Interaction.order)
            OrderRow(
              key: ValueKey(_item.id),
              item: _item,
              // Same rule as the match board, for the same reason: reaching the
              // sorted row is not evidence on its own, because every row can be
              // sorted by shuffling. Making the fewest possible moves is; one
              // extra is a slip; more than that is shuffling.
              onSolved: (movesOverPar) =>
                  _choose(movesOverPar <= 1 ? _item.answerIndex : -1),
              onMiss: () => _misses.record(_item, -1),
            )
          else if (_item.interaction == Interaction.match)
            MatchBoard(
              key: ValueKey(_item.id),
              item: _item,
              onSolved: (wrongJoins) {
                PrimarVoice.instance.chime(Sfx.levelUp);
                PrimarVoice.instance.say(VoiceLines.wellMatched);
                // Reaching the end is not evidence on its own — every board can
                // be solved by trying each combination. One slip is a slip; more
                // than that means the relationship is not there yet, and the
                // staircase must hear about it or it will climb on nothing.
                _choose(wrongJoins <= 1 ? _item.answerIndex : -1);
              },
              // A wrong join is recorded so the tracker sees the pattern, but the
              // board just lets go — no mark, no advance.
              onMiss: () => _misses.record(_item, -1),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 1.05,
              children: [
                for (var i = 0; i < _item.options.length; i++)
                  _OptionTile(
                    figure: _item.options[i],
                    isAnswer: i == _item.answerIndex,
                    chosen: _chosen == i,
                    revealing: _revealing,
                    burst: _burst,
                    onTap: () => _choose(i),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatefulWidget {
  const _OptionTile({
    required this.figure,
    required this.isAnswer,
    required this.chosen,
    required this.revealing,
    required this.burst,
    required this.onTap,
  });

  final Figure figure;
  final bool isAnswer;
  final bool chosen;
  final bool revealing;

  /// Null where there is nothing to celebrate — the warm-up marks nothing, so
  /// it has no burst to drive.
  final Animation<double>? burst;
  final VoidCallback onTap;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void didUpdateWidget(covariant _OptionTile old) {
    super.didUpdateWidget(old);
    if (widget.revealing &&
        widget.chosen &&
        widget.isAnswer &&
        !(old.revealing && old.chosen && old.isAnswer)) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _press() {
    if (widget.revealing) return;
    PrimarVoice.instance.chime(Sfx.tap);
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    // A miss is marked calmly: the right answer is highlighted and the chosen
    // tile steps back. Nothing flashes red, nothing shakes.
    final showRight = widget.revealing && widget.isAnswer;
    final showMiss = widget.revealing && widget.chosen && !widget.isAnswer;

    return GestureDetector(
      onTapDown: widget.revealing ? null : (_) => setState(() => _down = true),
      onTapUp: widget.revealing ? null : (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.revealing ? null : _press,
      child: AnimatedBuilder(
        animation: _pop,
        builder: (context, child) {
          final bounce = showRight
              ? 1.0 + Curves.easeOutBack.transform(_pop.value.clamp(0.0, 1.0)) * 0.08
              : 1.0;
          return Transform.scale(
            scale: bounce * (_down ? 0.96 : 1.0),
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _down ? 4 : 0, 0),
          decoration: PrimarTheme.tile(
            border: showRight
                ? PrimarTheme.teal
                : showMiss
                    ? PrimarTheme.ghostInk
                    : null,
            fill: showRight
                ? PrimarTheme.tintTeal
                : showMiss
                    ? const Color(0xFFF4F1EA)
                    : null,
            lift: _down ? 2 : (showRight ? 8 : 6),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: showMiss ? 0.62 : 1,
                child: Center(
                  child: FigureView(
                    figure: widget.figure,
                    color: showMiss
                        ? PrimarTheme.ghostInk
                        : PrimarTheme.answerInk,
                    size: 94,
                  ),
                ),
              ),
              if (showRight)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.check_circle_rounded,
                      color: PrimarTheme.teal, size: 22),
                ),
              // Only on the tile they actually chose, and only when it was right.
              if (widget.chosen && widget.isAnswer && widget.burst != null)
                AnimatedBuilder(
                  animation: widget.burst!,
                  builder: (context, _) =>
                      CorrectBurst(progress: widget.burst!.value, size: 130),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Short action line — Duolingo-clear, not a wall of text.
class _ActionHintPill extends StatelessWidget {
  const _ActionHintPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            PrimarTheme.tintBlue,
            PrimarTheme.tintBlue.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PrimarTheme.blue.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: PrimarTheme.blue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.touch_app_rounded,
                size: 18, color: PrimarTheme.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: PrimarTheme.body(14.5, color: PrimarTheme.navy)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Brief combo celebration — pops in, then fades with the timer above.
class _ComboBanner extends StatelessWidget {
  const _ComboBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return PrimarReveal(
      offsetY: 8,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: PrimarTheme.tintYellow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PrimarTheme.orange.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: PrimarTheme.orange.withValues(alpha: 0.28),
              blurRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_fire_department_rounded,
                color: PrimarTheme.orange, size: 26),
            const SizedBox(width: 8),
            Text(text,
                style: PrimarTheme.display(20, color: PrimarTheme.orange)),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* Result — parent facing                                              */
/* ------------------------------------------------------------------ */

class _Result extends StatefulWidget {
  const _Result({
    required this.name,
    required this.subject,
    required this.locale,
    required this.placement,
    required this.misses,
    required this.onAgain,
    required this.onHome,
    required this.onProgress,
  });

  final String name;
  final Subject subject;
  final String locale;
  final Placement placement;
  final MisconceptionTracker? misses;
  final VoidCallback onAgain;
  final VoidCallback onHome;
  final VoidCallback onProgress;

  @override
  State<_Result> createState() => _ResultState();
}

class _ResultState extends State<_Result> {
  /// What the learner model says, in words, for reading.
  String? _engineSummary;

  Future<void> _loadSummary() async {
    final learner = await EvidenceStore.instance.learner(locale: widget.locale);
    if (!mounted) return;
    setState(() => _engineSummary = summarise(learner, widget.name));
  }

  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    // Finishing is the moment worth marking. Every child who reaches this
    // screen gets it, whatever their level — the celebration is for showing up
    // and finishing, never for scoring well.
    _confetti.play();
    if (widget.subject == Subject.reading) _loadSummary();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final subject = widget.subject;
    final placement = widget.placement;
    final onAgain = widget.onAgain;
    final pattern = widget.misses?.summaryFor(name);

    // Read from the curriculum rather than from a second set of sentences kept
    // here. There were two: one for shapes and one for numbers, and reading
    // fell through to the shapes one — a child who had just spent five minutes
    // on letters was told they "put two simple parts together".
    final strings = S(widget.locale);
    final settled = placement.level.round();
    final now = outcomeFor(subject, settled);
    final next = outcomeFor(subject, settled + 1);
    final seconds = (placement.medianMs / 100).round() / 10;

    return Column(
      children: [
        SizedBox(
          height: 128,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.06,
                  numberOfParticles: 14,
                  maxBlastForce: 14,
                  minBlastForce: 6,
                  gravity: 0.28,
                  colors: const [
                    PrimarTheme.blue,
                    PrimarTheme.yellow,
                    PrimarTheme.teal,
                    PrimarTheme.purple,
                  ],
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: Mate(mood: Mood.cheer, size: 116),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _Sheet(
          clip: true,
          tape: TapeTone.purple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.rotate(
                          angle: -0.02,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            color: PrimarTheme.yellow,
                            child: Text(
                              'WHERE ${name.toUpperCase()} IS WORKING',
                              style: PrimarTheme.label(
                                10,
                                color: const Color(0xFF112B5F),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          bandFor(placement.level, widget.locale),
                          style: PrimarTheme.display(26),
                        ),
                      ],
                    ),
                  ),
                  const Doodle(
                    kind: DoodleKind.star,
                    size: 34,
                    color: PrimarTheme.teal,
                    angle: .2,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // For reading, what the engine actually knows beats a level band.
              //
              // "Ayuk can now tell two letters apart, and is working on letter
              // sounds" is a sentence a parent can act on. A band name is a
              // label, and labels are what these families have had enough of.
              if (widget.subject == Subject.reading && _engineSummary != null)
                Text(_engineSummary!, style: PrimarTheme.body(15))
              else
                Text(
                  strings.comfortably(name, now.canIn(widget.locale)),
                  style: PrimarTheme.body(15),
                ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PrimarTheme.tintBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          strings.nextStep,
                          style: PrimarTheme.label(10, color: PrimarTheme.blue),
                        ),
                        const SizedBox(width: 6),
                        const Doodle(
                          kind: DoodleKind.arrow,
                          size: 18,
                          color: PrimarTheme.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      next.canIn(widget.locale),
                      style: PrimarTheme.body(15, color: PrimarTheme.navy),
                    ),
                  ],
                ),
              ),
              if (pattern != null) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF3E7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WHAT KEEPS COMING UP',
                        style: PrimarTheme.label(
                          10,
                          color: const Color(0xFF9A5B12),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pattern,
                        style: PrimarTheme.body(14.5, color: PrimarTheme.navy),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _ProgressStrip(
                topicId: subject.topicIdFor(widget.locale),
                name: name,
              ),
              Divider(color: PrimarTheme.navy.withValues(alpha: 0.1)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Stat(
                    label: strings.statLevel,
                    value: placement.level.toStringAsFixed(1),
                  ),
                  _Stat(
                    label: strings.statCorrect,
                    value: '${placement.correct}/${placement.total}',
                  ),
                  _Stat(label: strings.statTime, value: '${seconds}s'),
                ],
              ),
              if (placement.provisional) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF0DF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'This one is a rough estimate — $name did not settle at a steady '
                    'level yet. A second session will sharpen it.',
                    style: PrimarTheme.body(13, color: const Color(0xFF8A5A12)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        PaperButton(
          expand: false,
          onPressed: widget.onHome,
          child: Text(
            strings.backToPath,
            style: PrimarTheme.display(
              17,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onAgain,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              strings.playAgain,
              textAlign: TextAlign.center,
              style: PrimarTheme.body(15, color: PrimarTheme.blue, weight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // The only way into the progress screen. Deliberately here rather than
        // on a bottom bar: this is the moment a parent has just been handed the
        // phone back, and it is the one moment they are actually looking.
        GestureDetector(
          onTap: widget.onProgress,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'See how $name is doing',
              textAlign: TextAlign.center,
              style: PrimarTheme.body(14, color: PrimarTheme.blue),
            ),
          ),
        ),
      ],
    );
  }
}

/// Past sessions, as a row of bars.
///
/// This is the only screen where a parent can see that anything is changing,
/// which is the entire reason results are stored at all. It stays hidden until
/// there are at least two sessions — a single bar is not a trend, and implying
/// one would be dishonest.
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.topicId, required this.name});

  final String topicId;
  final String name;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: MasteryStore.instance.historyFor(topicId),
      builder: (context, snap) {
        final history = snap.data ?? const [];
        if (history.length < 2) return const SizedBox.shrink();

        final recent = history.length > 8
            ? history.sublist(history.length - 8)
            : history;
        final first = (recent.first['level'] as num).toDouble();
        final last = (recent.last['level'] as num).toDouble();
        final moved = last - first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LAST ${recent.length} SESSIONS',
              style: PrimarTheme.label(10),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < recent.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          height:
                              8 +
                              ((recent[i]['level'] as num).toDouble() / 10) *
                                  34,
                          decoration: BoxDecoration(
                            color: i == recent.length - 1
                                ? PrimarTheme.teal
                                : PrimarTheme.blue.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              moved >= 0.4
                  ? '$name has moved up since the first of these.'
                  : moved <= -0.4
                  ? '$name is working a little lower than before — worth a look.'
                  : '$name is holding steady around the same level.',
              style: PrimarTheme.body(13.5),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PrimarTheme.label(9)),
          const SizedBox(height: 4),
          Text(value, style: PrimarTheme.display(22)),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* Progress — the only screen that looks backwards                      */
/* ------------------------------------------------------------------ */

/// Loads the evidence log and hands it to [ProgressScreen].
///
/// Every number on that screen is derived from attempts already recorded, so
/// this is a read and a fold — there is no progress state to keep in sync, and
/// therefore none to drift.
class _Progress extends StatefulWidget {
  const _Progress({
    required this.name,
    required this.locale,
    required this.subject,
    required this.onPlay,
  });

  final String name;
  final String locale;
  final Subject subject;
  final VoidCallback onPlay;

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  ProgressSummary? _summary;
  Learner? _learner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await EvidenceStore.instance.load();
    if (!mounted) return;
    final learner = learnerFrom(log, locale: widget.locale);
    setState(() {
      _learner = learner;
      _summary = summariseProgress(log, learner, subject: widget.subject);
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final learner = _learner;
    if (summary == null || learner == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Mate(mood: Mood.idle, size: 96),
      );
    }
    return ProgressScreen(
      summary: summary,
      learner: learner,
      name: widget.name,
      subject: widget.subject,
      onPlay: widget.onPlay,
    );
  }
}
