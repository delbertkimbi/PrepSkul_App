import 'package:flutter/material.dart';

import 'dart:math';

import '../domain/figure.dart';
import '../domain/numeracy.dart';
import '../domain/subjects.dart';
import '../domain/learner.dart';
import '../domain/literacy.dart';
import '../domain/misconception.dart';
import '../domain/policy.dart';
import '../domain/progress.dart';
import '../presentation/letter_card.dart';
import '../presentation/progress_screen.dart';
import '../domain/representation.dart';
import '../domain/skill.dart';
import '../services/evidence_store.dart';
import '../services/primar_voice.dart';
import '../presentation/choice_art.dart';
import '../presentation/figure_view.dart';
import '../presentation/word_picture.dart';
import '../presentation/order_row.dart';
import '../presentation/mascot.dart';
import '../presentation/home_screen.dart';
import '../presentation/profile_screen.dart';
import '../presentation/skulmate_shell.dart';
import '../presentation/splash.dart';
import '../presentation/primar_theme.dart';

/// Standalone harness so the experiment can be run and looked at without
/// booting the whole app or touching its router.
///
/// Pass `--dart-define=PRIMAR_VIEW=moods` to open the mascot gallery instead of
/// the flow — every mood on one screen, which is far faster to eyeball than
/// clicking through a session to reach each one.
///
/// `PRIMAR_VIEW=art` does the same for the onboarding pictures. Fifteen drawn
/// icons that a parent has to tell apart at a glance are not something to judge
/// one at a time, five taps deep into a flow.
void main() => runApp(const _PrimarPreviewApp());

const _view = String.fromEnvironment('PRIMAR_VIEW', defaultValue: 'flow');

class _PrimarPreviewApp extends StatelessWidget {
  const _PrimarPreviewApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SkulMate',
        home: switch (_view) {
          'moods' => const _MoodGallery(),
          'art' => const _ArtGallery(),
          'order' => const _OrderPreview(),
          'items' => const _ItemGallery(),
          'engine' => const _EnginePreview(),
          'pics' => const _PictureSheet(),
          'progress' => const _ProgressPreview(),
          'letters' => const _LetterCards(),
          'home' => const _HomePreview(),
          'profile' => const _ProfilePreview(),
          'rungs' => const _RungsPreview(),
          'maths' => const _MathsPathPreview(),
          _ => const _Boot(),
        },
      );
}

/// Splash, then the flow.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  bool _welcomed = false;

  @override
  Widget build(BuildContext context) => _welcomed
      // The shell, not the lesson. The lesson is one tab of an app now, and
      // booting straight into it was how the product came to have no home.
      ? const SkulMateShell()
      : PrimarSplash(onDone: () => setState(() => _welcomed = true));
}

class _MoodGallery extends StatefulWidget {
  const _MoodGallery();

  @override
  State<_MoodGallery> createState() => _MoodGalleryState();
}

class _MoodGalleryState extends State<_MoodGallery> {
  int _pulse = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Mate — every mood', style: PrimarTheme.display(22)),
                  const SizedBox(height: 4),
                  Text('tap to replay the reaction', style: PrimarTheme.body(13)),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 6,
                    runSpacing: 14,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final mood in Mood.values)
                        SizedBox(
                          width: 158,
                          child: Column(
                            children: [
                              // The key forces a rebuild so the entrance
                              // physics fire again on tap.
                              Mate(key: ValueKey('${mood.name}$_pulse'), mood: mood, size: 132),
                              const SizedBox(height: 2),
                              Text(mood.name, style: PrimarTheme.label(11)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  PaperButton(
                    expand: false,
                    onPressed: () => setState(() => _pulse++),
                    child: Text('Replay',
                        style: PrimarTheme.display(16,
                            color: Colors.white, weight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Every onboarding picture at once.
///
/// Fifteen icons a parent has to tell apart at a glance are not something to
/// judge one at a time, five taps deep into a flow — the first cut of these
/// looked fine in isolation and turned out to be three near-identical school
/// icons the moment they were seen side by side.
class _ArtGallery extends StatelessWidget {
  const _ArtGallery();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('Onboarding pictures', style: PrimarTheme.display(22)),
                const SizedBox(height: 4),
                Text('they have to be tellable apart at a glance',
                    style: PrimarTheme.body(13)),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final kind in ArtKind.values)
                      SizedBox(
                        width: 152,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: PrimarTheme.tile(lift: 3),
                              child: Center(child: ChoiceArt(kind: kind, size: 68)),
                            ),
                            const SizedBox(height: 4),
                            Text(kind.name, style: PrimarTheme.label(10)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The drag-to-order board on its own.
///
/// Reaching it inside the flow means answering four onboarding pages, a
/// warm-up and enough session items to climb to level five, which is far too
/// slow a loop to judge a drag interaction on.
class _OrderPreview extends StatefulWidget {
  const _OrderPreview();

  @override
  State<_OrderPreview> createState() => _OrderPreviewState();
}

class _OrderPreviewState extends State<_OrderPreview> {
  int _seed = 0;
  String _status = 'drag the tiles';

  PrimarItem _item() {
    for (var i = 0; i < 400; i++) {
      final item = generateNumeracyItem(5, Random(_seed * 977 + i), i);
      if (item.interaction == Interaction.order) return item;
    }
    throw StateError('no ordering item at level 5');
  }

  @override
  Widget build(BuildContext context) {
    final item = _item();
    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Smallest first', style: PrimarTheme.display(22)),
                    const SizedBox(height: 4),
                    Text(_status, style: PrimarTheme.body(13)),
                    const SizedBox(height: 24),
                    OrderRow(
                      key: ValueKey(item.id),
                      item: item,
                      onSolved: (over) =>
                          setState(() => _status = 'solved, \$over move(s) over par'),
                      onMiss: () => setState(() => _status = 'that went further away'),
                    ),
                    const SizedBox(height: 28),
                    PaperButton(
                      expand: false,
                      onPressed: () => setState(() {
                        _seed++;
                        _status = 'drag the tiles';
                      }),
                      child: Text('Another',
                          style: PrimarTheme.display(16,
                              color: Colors.white, weight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Every level of one subject, side by side.
///
/// The flow reaches level nine only after a child climbs there, which is far
/// too slow a loop to judge whether the content is any good. This shows all ten
/// at once, which is the only way to see that a set of questions is monotonous
/// before a child does.
class _ItemGallery extends StatefulWidget {
  const _ItemGallery();

  @override
  State<_ItemGallery> createState() => _ItemGalleryState();
}

class _ItemGalleryState extends State<_ItemGallery> {
  Subject _subject = Subject.numeracy;
  int _seed = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (final s in Subject.values)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _subject = s),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: PrimarTheme.tile(
                              border: _subject == s ? PrimarTheme.blue : null,
                              lift: _subject == s ? 6 : 2,
                            ),
                            child: Text(s.label('en'), style: PrimarTheme.display(14)),
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: () => setState(() => _seed++),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: PrimarTheme.tile(lift: 3),
                        child: Text('reroll', style: PrimarTheme.display(14)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (var level = 1; level <= 10; level++) ...[
                  _LevelRow(subject: _subject, level: level, seed: _seed),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.subject, required this.level, required this.seed});

  final Subject subject;
  final int level;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final item = generateForSubject(subject, level, Random(seed * 977 + level), level);
    final shown = <Figure>[
      ...item.prompt,
      ...item.orderItems,
      ...item.matchLeft,
      ...item.options.take(4),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: PrimarTheme.tile(lift: 2),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('L$level', style: PrimarTheme.label(11)),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final f in shown)
                  FigureView(figure: f, color: PrimarTheme.answerInk, size: 40),
              ],
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(item.interaction.name, style: PrimarTheme.label(9)),
          ),
        ],
      ),
    );
  }
}


/// The learning engine, playable.
///
/// The engine is a pure function of a child's evidence, which makes it easy to
/// test and impossible to *feel*. This puts a real decision on a real screen:
/// answer, and watch what it decides to do next and why.
class _EnginePreview extends StatefulWidget {
  const _EnginePreview();

  @override
  State<_EnginePreview> createState() => _EnginePreviewState();
}

class _EnginePreviewState extends State<_EnginePreview> {
  List<Evidence> _log = [];
  final Random _rng = Random(7);
  bool _loading = true;

  late Decision _decision = nextSkill(learnerFrom(_log));

  PrimarItem? _item;
  int? _chosen;
  bool _revealing = false;
  int _reviewsThisSession = 0;

  @override
  void initState() {
    super.initState();
    _resume();
  }

  /// Picks up exactly where the child left off, including yesterday.
  ///
  /// The engine was always a pure function of an evidence log; the log just
  /// never survived the app closing. Reading it back on launch is the whole
  /// difference between a game that starts again every morning and something
  /// that knows the child.
  Future<void> _resume() async {
    final log = await EvidenceStore.instance.load();
    if (!mounted) return;
    setState(() {
      _log = log;
      _decision = nextSkill(learnerFrom(log));
      _item = _decision.exhausted ? null : _next();
      _loading = false;
    });
  }

  /// How much help this child currently needs on this skill.
  Support get _support =>
      supportFor(learnerFrom(_log).stateOf(_decision.skillId!));

  PrimarItem _next() => generateItemForSkill(
        _decision.skillId!,
        _rng,
        index: _log.length,
        support: _support,
      );

  void _answer(int index) {
    if (_revealing || _decision.exhausted) return;
    final correct = index == _item!.answerIndex;
    final support = _support;

    setState(() {
      _chosen = index;
      _revealing = true;
    });
    PrimarVoice.instance.chime(correct ? Sfx.correct : Sfx.tap);

    final evidence = Evidence(
      skillId: _decision.skillId!,
      correct: correct,
      elapsedMs: 2500,
      at: DateTime.now(),
      misconception: correct ? Misconception.unclear : classifyMiss(_item!, index),
      // Transfer is not a kind of question, it is a question asked with the
      // scaffolding gone. Reading that off the item the child actually saw is
      // the only way it stays true.
      isTransfer: isTransferEvidence(support),
    );
    // Written through to storage, so closing the app mid-session keeps it.
    EvidenceStore.instance.add(evidence).then((saved) {
      if (mounted) _log = saved;
    });
    _log = [..._log, evidence];

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final learner = learnerFrom(_log);
      final d = nextSkill(learner, reviewsSoFar: _reviewsThisSession);
      setState(() {
        if (d.reason == Reason.review) _reviewsThisSession++;
        _decision = d;
        _chosen = null;
        _revealing = false;
        _item = d.exhausted ? null : _next();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: PrimarTheme.paper,
        body: Center(child: Mate(mood: Mood.idle, size: 96)),
      );
    }
    final learner = learnerFrom(_log);

    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: PrimarTheme.tile(lift: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_decision.reason.name.toUpperCase(),
                          style: PrimarTheme.label(10, color: PrimarTheme.blue)),
                      const SizedBox(height: 4),
                      Text(_decision.explain, style: PrimarTheme.body(14)),
                      if (!_decision.exhausted) ...[
                        const SizedBox(height: 4),
                        Text(supportExplain(_support, 'Ayuk'),
                            style: PrimarTheme.body(12, color: PrimarTheme.muted)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_decision.exhausted)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text('Nothing left to teach.',
                        textAlign: TextAlign.center, style: PrimarTheme.display(20)),
                  )
                else ...[
                  _Sheet2(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final f in _item!.prompt)
                          FigureView(figure: f, color: PrimarTheme.answerInk, size: 52),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.6,
                    children: [
                      for (var i = 0; i < _item!.options.length; i++)
                        GestureDetector(
                          onTap: () => _answer(i),
                          child: Container(
                            decoration: PrimarTheme.tile(
                              border: _revealing && i == _item!.answerIndex
                                  ? PrimarTheme.teal
                                  : null,
                              fill: _revealing && i == _item!.answerIndex
                                  ? PrimarTheme.tintTeal
                                  : null,
                              lift: _chosen == i ? 2 : 5,
                            ),
                            child: Center(
                              child: FigureView(
                                figure: _item!.options[i],
                                color: PrimarTheme.answerInk,
                                size: 46,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Text(summarise(learner, 'Ayuk'), style: PrimarTheme.body(13.5)),
                const SizedBox(height: 12),
                for (final s in readingSkills)
                  _SkillRow(skill: s, state: learner.stateOf(s.id)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sheet2 extends StatelessWidget {
  const _Sheet2({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: PrimarTheme.paperSheet(),
        child: child,
      );
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
      MasteryState.notStarted => const Color(0xFFDDE2EA),
    };

    return Opacity(
      opacity: skill.teachable ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(color: colour, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                skill.teachable ? skill.label : '${skill.label}  (not built yet)',
                style: PrimarTheme.body(12),
              ),
            ),
            Text(
              state.attempts == 0 ? '' : '${state.attempts}  ${(state.recentAccuracy * 100).round()}%',
              style: PrimarTheme.label(9),
            ),
          ],
        ),
      ),
    );
  }
}


/// Every drawable word, at the size a child actually sees it.
///
/// The pictures are the whole reading experience — a word without one is a
/// shape-matching exercise — so they need looking at together rather than one
/// at a time as they happen to come up in a session.
class _PictureSheet extends StatelessWidget {
  const _PictureSheet();

  @override
  Widget build(BuildContext context) {
    final words = WordPicture.drawable.toList()..sort();

    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Pictures', style: PrimarTheme.display(24)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final w in words)
                      Container(
                        width: 108,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: PrimarTheme.tile(lift: 4),
                        child: Column(
                          children: [
                            WordPicture(word: w, size: 84),
                            const SizedBox(height: 4),
                            Text(w, style: PrimarTheme.body(13)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




/// The progress screen with a plausible history behind it.
///
/// Empty it shows dashes and zeros, which is correct but tells you nothing
/// about whether the screen works. This seeds four days of a real-looking
/// child: strong on letter shapes, still learning sounds, nothing beyond.
class _ProgressPreview extends StatelessWidget {
  const _ProgressPreview();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    Evidence at(int daysAgo, String skill, bool correct, {int min = 0}) => Evidence(
          skillId: skill,
          correct: correct,
          elapsedMs: 3400,
          at: now.subtract(Duration(days: daysAgo, minutes: min)),
        );

    final log = <Evidence>[
      for (var i = 0; i < 9; i++) at(3, 'letter.shape', true, min: i),
      at(3, 'letter.shape', true, min: 10),
      for (var i = 0; i < 6; i++) at(2, 'pa.initial', i.isEven, min: i),
      for (var i = 0; i < 7; i++) at(1, 'pa.initial', i > 1, min: i),
      for (var i = 0; i < 5; i++) at(0, 'letter.sound', i > 2, min: i),
    ];
    final learner = learnerFrom(log);

    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            child: ProgressScreen(
              summary: summariseProgress(log, learner),
              learner: learner,
              name: 'Ayuk',
              onPlay: () {},
            ),
          ),
        ),
      ),
    );
  }
}


/// Every letter card the word bank can build.
///
/// Shows at a glance which letters have two drawable words behind them and
/// which do not — the gap is the art backlog, and it is easier to close when
/// you can see it.
class _LetterCards extends StatelessWidget {
  const _LetterCards();

  @override
  Widget build(BuildContext context) {
    const sounds = {
      'a': 'aah', 'b': 'buh', 'c': 'kuh', 'd': 'duh', 'f': 'fff', 'h': 'huh',
      'k': 'kuh', 'l': 'lll', 'm': 'mmm', 'n': 'nnn', 'p': 'puh', 's': 'sss',
      't': 'tuh', 'v': 'vvv', 'y': 'yuh',
    };
    final ready = sounds.keys.where(LetterCard.canShow).toList();
    final missing = sounds.keys.where((l) => !LetterCard.canShow(l)).toList();

    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Letter cards', style: PrimarTheme.display(24)),
              const SizedBox(height: 4),
              Text('${ready.length} ready · needs two pictures each',
                  style: PrimarTheme.body(13, color: PrimarTheme.muted)),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('still short: ${missing.join(", ")}',
                    style: PrimarTheme.body(13, color: PrimarTheme.orange)),
              ],
              const SizedBox(height: 16),
              for (final l in ready) ...[
                LetterCard(letter: l, sound: sounds[l]!),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


/// A learner partway up the path, so the home screen can be *looked at*.
///
/// Every other way of seeing these screens needs a device: the phone dropped
/// off adb, the browser pane cannot deliver a tap to a Flutter canvas, and the
/// simulator build wants an Xcode component that is not installed. A preview
/// that seeds evidence and renders the screen directly needs none of them.
class _HomePreview extends StatefulWidget {
  const _HomePreview();

  @override
  State<_HomePreview> createState() => _HomePreviewState();
}

class _HomePreviewState extends State<_HomePreview> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    EvidenceStore.instance.seed(_partwayUp());
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                child: HomeScreen(name: 'Ayuk', locale: 'en', onPlay: () {}),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilePreview extends StatefulWidget {
  const _ProfilePreview();

  @override
  State<_ProfilePreview> createState() => _ProfilePreviewState();
}

class _ProfilePreviewState extends State<_ProfilePreview> {
  @override
  void initState() {
    super.initState();
    EvidenceStore.instance.seed(_partwayUp());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                child: const ProfileScreen(
                    name: 'Ayuk', locale: 'en', voiceId: 'guide'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Letters cleared, sounds solid, decoding just started — the position most
/// children will actually be in after a week.
List<Evidence> _partwayUp() {
  final now = DateTime.now();
  Evidence at(int daysAgo, String skill, bool correct, {int min = 0}) => Evidence(
        skillId: skill,
        correct: correct,
        elapsedMs: 3200,
        at: now.subtract(Duration(days: daysAgo, minutes: min)),
        isTransfer: min > 5,
      );

  return [
    for (var i = 0; i < 8; i++) at(2, 'pa.initial', true, min: i),
    for (var i = 0; i < 8; i++) at(2, 'letter.shape', true, min: i),
    for (var i = 0; i < 8; i++) at(1, 'letter.shape.reversal', true, min: i),
    for (var i = 0; i < 8; i++) at(1, 'letter.sound', true, min: i),
    for (var i = 0; i < 4; i++) at(0, 'decode.build', i > 1, min: i),
  ];
}


/// One question from each of the three new rungs, rendered through the real
/// widgets the session uses.
///
/// The point is to see them the way a child would. Three generators can be
/// green in unit tests and still be unreadable on a phone — a row of four
/// sound buttons that all look identical, a phrase whose tiles are too narrow
/// for the words. Neither shows up in an assertion.
class _RungsPreview extends StatelessWidget {
  const _RungsPreview();

  static const _skills = [
    ('pa.rhyme', 'Which one rhymes'),
    ('pa.syllable', 'How many beats'),
    ('pa.blend', 'Blend the sounds'),
    ('pa.segment', 'What does it end with'),
    ('decode.sentence', 'Put the phrase in order'),
    ('meaning.word', 'What does the word mean'),
    ('meaning.sentence', 'Which scene matches'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (id, title) in _skills) ...[
                  Text(title.toUpperCase(),
                      style: PrimarTheme.label(11, color: PrimarTheme.blue)),
                  const SizedBox(height: 8),
                  _RungCard(item: generateItemForSkill(id, Random(9), index: 3)),
                  const SizedBox(height: 26),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RungCard extends StatelessWidget {
  const _RungCard({required this.item});

  final PrimarItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: PrimarTheme.tile(lift: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.prompt.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final f in item.prompt)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FigureView(figure: f, size: 56),
                  ),
              ],
            ),
          if (item.interaction == Interaction.order)
            OrderRow(item: item, onSolved: (_) {}, onMiss: () {})
          else ...[
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: [
                for (var i = 0; i < item.options.length; i++)
                  Container(
                    decoration: PrimarTheme.tile(
                      border: i == item.answerIndex ? PrimarTheme.teal : null,
                      lift: 4,
                    ),
                    child: Center(
                      child: FigureView(figure: item.options[i], size: 56),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'says: ${item.spokenAll.isNotEmpty ? item.spokenAll.join("  ") : item.spoken}',
            style: PrimarTheme.body(11.5, color: PrimarTheme.muted),
          ),
        ],
      ),
    );
  }
}


/// The numeracy path, with a learner partway up it.
///
/// Worth looking at separately from reading: the two graphs share a lookup
/// table and a single evidence log, and the failure mode is not a crash but a
/// path quietly showing the wrong subject's skills.
class _MathsPathPreview extends StatefulWidget {
  const _MathsPathPreview();

  @override
  State<_MathsPathPreview> createState() => _MathsPathPreviewState();
}

class _MathsPathPreviewState extends State<_MathsPathPreview> {
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    EvidenceStore.instance.seed([
      for (final id in ['num.count', 'num.numeral', 'num.compare'])
        for (var n = 0; n < 8; n++)
          Evidence(
            skillId: id,
            correct: true,
            elapsedMs: 3000,
            at: now.subtract(Duration(days: 1, minutes: n)),
            isTransfer: n > 5,
          ),
      for (var n = 0; n < 4; n++)
        Evidence(
          skillId: 'num.order',
          correct: n > 1,
          elapsedMs: 3000,
          at: now.subtract(Duration(minutes: n)),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                child: HomeScreen(
                  name: 'Ayuk',
                  locale: 'en',
                  subject: Subject.numeracy,
                  onPlay: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
