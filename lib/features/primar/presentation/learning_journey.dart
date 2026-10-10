import 'package:flutter/material.dart';

import '../domain/learner.dart';
import '../services/evidence_store.dart';
import 'mascot.dart';
import 'primar_theme.dart';

/// The first vertical slice of PrepSkul's learning journey.  It deliberately
/// keeps the map semantic: every landmark is a teachable capability, not a
/// decorative place the learner has to navigate through.
class LearningJourney extends StatefulWidget {
  const LearningJourney({
    super.key,
    required this.name,
    required this.onAskTutor,
  });

  final String name;
  final VoidCallback onAskTutor;

  @override
  State<LearningJourney> createState() => _LearningJourneyState();
}

class _LearningJourneyState extends State<LearningJourney> {
  int _tab = 0;
  bool _demonstrated = false;

  void _openSession() async {
    final demonstrated = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const FocusedMathSession()));
    if (demonstrated == true && mounted) setState(() => _demonstrated = true);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _TodayPage(
        name: widget.name,
        demonstrated: _demonstrated,
        onLearn: _openSession,
        onTutor: widget.onAskTutor,
      ),
      _JourneyPage(demonstrated: _demonstrated, onLearn: _openSession),
      const _LibraryPage(),
      _HelpPage(onTutor: widget.onAskTutor),
    ];
    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: IndexedStack(index: _tab, children: pages),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _JourneyNav(
        index: _tab,
        onChanged: (value) => setState(() => _tab = value),
      ),
    );
  }
}

class _JourneyScaffold extends StatelessWidget {
  const _JourneyScaffold({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
    child: child,
  );
}

class _TodayPage extends StatelessWidget {
  const _TodayPage({
    required this.name,
    required this.demonstrated,
    required this.onLearn,
    required this.onTutor,
  });
  final String name;
  final bool demonstrated;
  final VoidCallback onLearn;
  final VoidCallback onTutor;

  @override
  Widget build(BuildContext context) => _JourneyScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today', style: PrimarTheme.display(34)),
                  Text(
                    'Preparing for your algebra assessment',
                    style: PrimarTheme.body(15, color: PrimarTheme.muted),
                  ),
                ],
              ),
            ),
            const Mate(mood: Mood.wave, size: 74),
          ],
        ),
        const SizedBox(height: 20),
        _GoalCard(demonstrated: demonstrated, onLearn: onLearn),
        const SizedBox(height: 18),
        Text('Bring a question', style: PrimarTheme.display(22)),
        const SizedBox(height: 8),
        Text(
          'Type it, say it, or add a photo. Mate will help you find the next useful step.',
          style: PrimarTheme.body(15),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.add_comment_rounded,
          title: 'I need help with a maths question',
          subtitle: 'Start with what is confusing you',
          color: PrimarTheme.tintBlue,
          onTap: onLearn,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.people_alt_rounded,
          title: 'Ask a tutor',
          subtitle: 'Share your attempted steps only after you review them',
          color: PrimarTheme.tintYellow,
          onTap: onTutor,
        ),
        const SizedBox(height: 22),
        Text('Prepared for you', style: PrimarTheme.display(22)),
        const SizedBox(height: 8),
        _PreparedCard(demonstrated: demonstrated),
      ],
    ),
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.demonstrated, required this.onLearn});
  final bool demonstrated;
  final VoidCallback onLearn;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: PrimarTheme.paperSheet(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          demonstrated
              ? 'You have evidence for substitution.'
              : 'Your next step is ready.',
          style: PrimarTheme.display(22),
        ),
        const SizedBox(height: 8),
        Text(
          demonstrated
              ? 'Come back for a short mixed review later this week.'
              : 'Start by checking the first move in a simultaneous-equations problem.',
          style: PrimarTheme.body(15),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _StatusDot(
              color: demonstrated ? PrimarTheme.teal : PrimarTheme.yellow,
            ),
            const SizedBox(width: 8),
            Text(
              demonstrated ? 'Demonstrated independently' : 'Exploring',
              style: PrimarTheme.body(14, weight: FontWeight.w700),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onLearn,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(demonstrated ? 'Review' : 'Continue'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PreparedCard extends StatelessWidget {
  const _PreparedCard({required this.demonstrated});
  final bool demonstrated;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: PrimarTheme.tintTeal,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Mate(mood: Mood.thinking, size: 58),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                demonstrated
                    ? 'A retrieval check is queued'
                    : 'A 4-minute starting-point check is ready',
                style: PrimarTheme.body(15, weight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                demonstrated
                    ? 'It will use a new problem, so your route reflects what you can do without hints.'
                    : 'Mate chose it because it clarifies whether rearranging equations is the blocker.',
                style: PrimarTheme.body(13.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _JourneyPage extends StatelessWidget {
  const _JourneyPage({required this.demonstrated, required this.onLearn});
  final bool demonstrated;
  final VoidCallback onLearn;
  @override
  Widget build(BuildContext context) => _JourneyScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Journey', style: PrimarTheme.display(34)),
        const SizedBox(height: 5),
        Text(
          'Algebra assessment · Your route stays in place while evidence changes.',
          style: PrimarTheme.body(15, color: PrimarTheme.muted),
        ),
        const SizedBox(height: 22),
        _RouteMap(demonstrated: demonstrated, onLearn: onLearn),
        const SizedBox(height: 22),
        Text('Route details', style: PrimarTheme.display(22)),
        const SizedBox(height: 10),
        _RouteRow(
          number: '1',
          title: 'Rearrange a linear equation',
          state: 'Exploring',
          active: !demonstrated,
        ),
        _RouteRow(
          number: '2',
          title: 'Use substitution',
          state: demonstrated ? 'Demonstrated' : 'Next',
          active: demonstrated,
        ),
        const _RouteRow(
          number: '3',
          title: 'Solve a new problem independently',
          state: 'Not checked',
        ),
        const _RouteRow(
          number: '4',
          title: 'Mixed review',
          state: 'Review due',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _showListView(context),
          icon: const Icon(Icons.format_list_bulleted_rounded),
          label: const Text('Open accessible list view'),
        ),
      ],
    ),
  );

  void _showListView(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Algebra route',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 12),
            Text('1. Rearrange a linear equation — Exploring'),
            SizedBox(height: 8),
            Text('2. Use substitution — Next'),
            SizedBox(height: 8),
            Text('3. Solve a new problem independently — Not checked'),
            SizedBox(height: 8),
            Text('4. Mixed review — Review due'),
          ],
        ),
      ),
    ),
  );
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.demonstrated, required this.onLearn});
  final bool demonstrated;
  final VoidCallback onLearn;
  @override
  Widget build(BuildContext context) => Container(
    height: 310,
    decoration: BoxDecoration(
      color: PrimarTheme.navy,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Stack(
      children: [
        const Positioned(
          left: 30,
          top: 44,
          child: _MapNode(
            icon: Icons.edit_rounded,
            label: 'Rearrange',
            status: 'Exploring',
            color: PrimarTheme.yellow,
          ),
        ),
        Positioned(
          right: 30,
          top: 130,
          child: _MapNode(
            icon: Icons.functions_rounded,
            label: 'Substitution',
            status: demonstrated ? 'Demonstrated' : 'Next',
            color: demonstrated ? PrimarTheme.teal : PrimarTheme.blue,
          ),
        ),
        const Positioned(
          left: 54,
          bottom: 28,
          child: _MapNode(
            icon: Icons.fact_check_rounded,
            label: 'Independent check',
            status: 'Not checked',
            color: Colors.white,
          ),
        ),
        Positioned(
          right: 28,
          bottom: 22,
          child: _MapNode(
            icon: Icons.event_repeat_rounded,
            label: 'Review',
            status: 'Review due',
            color: PrimarTheme.orange,
          ),
        ),
        Positioned(
          left: 128,
          top: 110,
          width: 188,
          child: Transform.rotate(
            angle: .36,
            child: const Divider(color: Color(0x88FFFFFF), thickness: 3),
          ),
        ),
        Positioned(
          left: 130,
          top: 204,
          width: 150,
          child: Transform.rotate(
            angle: -.27,
            child: const Divider(color: Color(0x88FFFFFF), thickness: 3),
          ),
        ),
        Positioned(
          bottom: 14,
          right: 16,
          child: FilledButton(
            onPressed: onLearn,
            child: const Text('Start next step'),
          ),
        ),
      ],
    ),
  );
}

class _MapNode extends StatelessWidget {
  const _MapNode({
    required this.icon,
    required this.label,
    required this.status,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String status;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      CircleAvatar(
        radius: 27,
        backgroundColor: color,
        child: Icon(icon, color: PrimarTheme.navy),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
      Text(
        status,
        style: const TextStyle(color: Color(0xFFDDE8FF), fontSize: 10),
      ),
    ],
  );
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.number,
    required this.title,
    required this.state,
    this.active = false,
  });
  final String number, title, state;
  final bool active;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? PrimarTheme.tintBlue : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PrimarTheme.tintGrey),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: active ? PrimarTheme.blue : PrimarTheme.tintGrey,
            child: Text(
              number,
              style: TextStyle(
                color: active ? Colors.white : PrimarTheme.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: PrimarTheme.body(14, weight: FontWeight.w800),
            ),
          ),
          Text(state, style: PrimarTheme.body(12, color: PrimarTheme.muted)),
        ],
      ),
    ),
  );
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage();
  @override
  Widget build(BuildContext context) => _JourneyScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Library', style: PrimarTheme.display(34)),
        const SizedBox(height: 6),
        Text(
          'Your saved questions, worked examples, and downloads.',
          style: PrimarTheme.body(15, color: PrimarTheme.muted),
        ),
        const SizedBox(height: 22),
        _ActionTile(
          icon: Icons.calculate_rounded,
          title: 'Simultaneous equations',
          subtitle: 'One saved route · Available offline',
          color: PrimarTheme.tintBlue,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.picture_as_pdf_rounded,
          title: 'Tutor session notes',
          subtitle: 'Nothing shared until you choose it',
          color: PrimarTheme.tintYellow,
        ),
      ],
    ),
  );
}

class _HelpPage extends StatelessWidget {
  const _HelpPage({required this.onTutor});
  final VoidCallback onTutor;
  @override
  Widget build(BuildContext context) => _JourneyScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Help', style: PrimarTheme.display(34)),
        const SizedBox(height: 6),
        Text(
          'Choose the kind of help that fits this moment.',
          style: PrimarTheme.body(15, color: PrimarTheme.muted),
        ),
        const SizedBox(height: 20),
        _ActionTile(
          icon: Icons.smart_toy_rounded,
          title: 'Ask Mate now',
          subtitle: 'Hints, examples, and a short check',
          color: PrimarTheme.tintTeal,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.person_search_rounded,
          title: 'Find a relevant tutor',
          subtitle: 'Review the question and attempted steps before sharing',
          color: PrimarTheme.tintYellow,
          onTap: onTutor,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.groups_rounded,
          title: 'Study circle',
          subtitle: 'A moderated group for this topic',
          color: PrimarTheme.tintBlue,
        ),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(icon, color: PrimarTheme.navy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PrimarTheme.body(15, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: PrimarTheme.body(12.5)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: PrimarTheme.navy),
          ],
        ),
      ),
    ),
  );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 11,
    height: 11,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _JourneyNav extends StatelessWidget {
  const _JourneyNav({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;
  static const _items = [
    (Icons.today_rounded, 'Today'),
    (Icons.route_rounded, 'Journey'),
    (Icons.menu_book_rounded, 'Library'),
    (Icons.support_agent_rounded, 'Help'),
  ];
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      color: Colors.white,
      height: 68,
      child: Row(
        children: List.generate(
          _items.length,
          (i) => Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _items[i].$1,
                    color: index == i ? PrimarTheme.blue : PrimarTheme.ghostInk,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _items[i].$2,
                    style: PrimarTheme.body(
                      10.5,
                      color: index == i
                          ? PrimarTheme.blue
                          : PrimarTheme.ghostInk,
                      weight: index == i ? FontWeight.w800 : FontWeight.w500,
                    ),
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

/// A complete, interruptible learning loop. Answers are intentionally checked
/// independently after the explanation; seeing the worked method is never
/// represented as proof that the learner understands it.
class FocusedMathSession extends StatefulWidget {
  const FocusedMathSession({super.key});
  @override
  State<FocusedMathSession> createState() => _FocusedMathSessionState();
}

class _FocusedMathSessionState extends State<FocusedMathSession> {
  int _step = 0;
  final _answer = TextEditingController();
  bool _correct = false;
  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step++);

  Future<void> _checkIndependentAnswer() async {
    final correct = _answer.text.trim() == '4';
    if (correct) {
      await EvidenceStore.instance.add(
        Evidence(
          skillId: 'algebra_balancing_equations',
          correct: true,
          elapsedMs: 0,
          at: DateTime.now(),
          isTransfer: true,
        ),
      );
    }
    if (mounted) setState(() => _correct = correct);
  }

  @override
  Widget build(BuildContext context) {
    final mood = switch (_step) {
      0 => Mood.wave,
      1 => Mood.thinking,
      2 => Mood.point,
      3 => _correct ? Mood.cheer : Mood.encourage,
      _ => Mood.idle,
    };
    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      appBar: AppBar(
        backgroundColor: PrimarTheme.paper,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, _correct),
          icon: const Icon(Icons.close, color: PrimarTheme.navy),
        ),
        title: Text(
          'Algebra with Mate',
          style: PrimarTheme.body(17, weight: FontWeight.w800),
        ),
      ),
      body: PaperGround(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: (_step + 1) / 4,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    const SizedBox(height: 22),
                    Center(child: Mate(mood: mood, size: 125)),
                    const SizedBox(height: 20),
                    _sessionCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sessionCard() => Container(
    padding: const EdgeInsets.all(22),
    decoration: PrimarTheme.paperSheet(),
    child: switch (_step) {
      0 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bring your question', style: PrimarTheme.display(27)),
          const SizedBox(height: 8),
          Text(
            'You said: “I do not understand simultaneous equations.” We will start with one small check.',
            style: PrimarTheme.body(16),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _next, child: const Text('Start the check')),
        ],
      ),
      1 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Show your first step', style: PrimarTheme.display(27)),
          const SizedBox(height: 8),
          Text(
            'For 2x + 3 = 11, what should we do first?',
            style: PrimarTheme.body(16),
          ),
          const SizedBox(height: 14),
          _Choice(label: 'Subtract 3 from both sides', onTap: _next),
          _Choice(label: 'Divide both sides by 2', onTap: _next),
          _Choice(label: 'Add 3 to both sides', onTap: _next),
        ],
      ),
      2 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A useful next step', style: PrimarTheme.display(27)),
          const SizedBox(height: 8),
          Text(
            'Subtract 3 from both sides first. The equation becomes 2x = 8. Then divide both sides by 2, so x = 4.',
            style: PrimarTheme.body(16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PrimarTheme.tintBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Why this route? Your answer tells Mate that keeping both sides balanced is the useful prerequisite before substitution.',
              style: PrimarTheme.body(14),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _next,
            child: const Text('Try a new problem yourself'),
          ),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _correct ? 'You demonstrated it' : 'Independent check',
            style: PrimarTheme.display(27),
          ),
          const SizedBox(height: 8),
          Text(
            _correct
                ? 'You solved a new problem without a hint. Your route now shows evidence for this step.'
                : 'Solve 3x + 4 = 16. What is x?',
            style: PrimarTheme.body(16),
          ),
          if (!_correct) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _answer,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Your answer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _checkIndependentAnswer,
              child: const Text('Check my answer'),
            ),
          ] else ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Return to my journey'),
            ),
          ],
        ],
      ),
    },
  );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(15),
      ),
      child: Text(label),
    ),
  );
}
