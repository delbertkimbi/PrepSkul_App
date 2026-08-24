import 'package:flutter/material.dart';

import '../domain/learner.dart';
import '../domain/policy.dart';
import '../domain/subjects.dart';
import '../domain/tutor_advice.dart';
import '../services/evidence_store.dart';
import '../services/tutor_directory.dart';
import 'mascot.dart';
import 'primar_motion.dart';
import 'primar_theme.dart';

/// A real person when the app is not enough — and honest advice when it is.
///
/// ## What changed
///
/// The Ask tab used to be only a tutor directory plus a booking stub. Brilliant
/// answers "what should I work on?" before it offers a human. The engine already
/// had that answer in [nextSkill]; this screen now shows it first.
class TutorScreen extends StatefulWidget {
  const TutorScreen({
    super.key,
    required this.locale,
    required this.activeSubject,
    required this.onAsk,
  });

  final String locale;
  final Subject activeSubject;
  final void Function(TutorCard tutor) onAsk;

  @override
  State<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends State<TutorScreen> {
  List<PracticeAdvice>? _advice;
  List<TutorCard>? _tutors;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TutorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeSubject != widget.activeSubject ||
        oldWidget.locale != widget.locale) {
      _load();
    }
  }

  Future<void> _load() async {
    final log = await EvidenceStore.instance.load();
    final tutors =
        await TutorDirectory.instance.load(subject: widget.activeSubject.name);
    if (!mounted) return;
    final learner = learnerFrom(log, locale: widget.locale);
    setState(() {
      _advice = practiceAdviceFor(learner);
      _tutors = tutors;
    });
  }

  PracticeAdvice? get _focus {
    final list = _advice;
    if (list == null) return null;
    for (final a in list) {
      if (a.subject == widget.activeSubject) return a;
    }
    return null;
  }

  Color _headlineColour(Reason reason) => switch (reason) {
        Reason.review => PrimarTheme.yellow,
        Reason.repair || Reason.reteach => PrimarTheme.orange,
        Reason.nothingLeft => PrimarTheme.teal,
        _ => PrimarTheme.blue,
      };

  @override
  Widget build(BuildContext context) {
    final advice = _advice;
    final tutors = _tutors;
    final focus = _focus;
    final tips = tutorTips(widget.locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (advice == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (focus != null)
            PrimarReveal(
              child: _PracticeCard(
                advice: focus,
                subject: widget.activeSubject,
                locale: widget.locale,
                colour: _headlineColour(focus.reason),
              ),
            ),
          const SizedBox(height: 14),
          PrimarReveal(
            delay: PrimarMotion.stagger(1),
            child: _TipsPanel(tips: tips),
          ),
          const SizedBox(height: 18),
          Text(
            widget.locale == 'fr' ? 'VRAIS PROFESSEURS' : 'REAL TEACHERS',
            style: PrimarTheme.label(10),
          ),
          const SizedBox(height: 10),
          if (tutors == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (tutors.isEmpty)
            _Empty(onRetry: () {
              setState(() => _tutors = null);
              TutorDirectory.instance.resetCache();
              _load();
            })
          else
            for (var i = 0; i < tutors.length; i++)
              PrimarReveal(
                delay: PrimarMotion.stagger(i + 2),
                child: _TutorTile(
                  tutor: tutors[i],
                  onAsk: () => widget.onAsk(tutors[i]),
                ),
              ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.advice,
    required this.subject,
    required this.locale,
    required this.colour,
  });

  final PracticeAdvice advice;
  final Subject subject;
  final String locale;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: PrimarTheme.tile(border: colour, lift: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Mate(mood: Mood.thinking, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale == 'fr' ? 'CE QUE MATE PROPOSE' : 'WHAT MATE SUGGESTS',
                  style: PrimarTheme.label(10, color: colour),
                ),
                const SizedBox(height: 6),
                Text(
                  '${advice.headline} · ${subject.label(locale)}',
                  style: PrimarTheme.display(17),
                ),
                if (!advice.exhausted) ...[
                  const SizedBox(height: 6),
                  Text(advice.skillLabel, style: PrimarTheme.body(14.5)),
                ],
                if (advice.explain.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    advice.explain,
                    style: PrimarTheme.body(13, color: PrimarTheme.muted),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  locale == 'fr'
                      ? 'Allez à Apprendre et appuyez sur Démarrer.'
                      : 'Go to Learn and press Start.',
                  style: PrimarTheme.label(11, color: PrimarTheme.teal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipsPanel extends StatelessWidget {
  const _TipsPanel({required this.tips});

  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: PrimarTheme.tile(lift: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TIPS', style: PrimarTheme.label(10)),
          const SizedBox(height: 10),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 16, color: PrimarTheme.yellow),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip, style: PrimarTheme.body(13.5))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: PrimarTheme.tile(lift: 4),
      child: Column(
        children: [
          const Mate(mood: Mood.idle, size: 68),
          const SizedBox(height: 14),
          Text(
            'No teachers here yet. Check again in a little while.',
            textAlign: TextAlign.center,
            style: PrimarTheme.body(14.5),
          ),
          const SizedBox(height: 16),
          PaperButton(
            expand: false,
            onPressed: onRetry,
            child: Text('Look again',
                style: PrimarTheme.display(16,
                    color: Colors.white, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _TutorTile extends StatelessWidget {
  const _TutorTile({required this.tutor, required this.onAsk});

  final TutorCard tutor;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: PrimarTheme.tile(lift: 5),
      child: Row(
        children: [
          _Face(tutor: tutor),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tutor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PrimarTheme.display(17)),
                const SizedBox(height: 3),
                Text(
                  [
                    if (tutor.subjects.isNotEmpty) tutor.subjects.first,
                    if (tutor.city != null) tutor.city!,
                    if (tutor.sessions != null && tutor.sessions! > 0)
                      '${tutor.sessions} sessions',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PrimarTheme.body(12.5, color: PrimarTheme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PaperButton(
            expand: false,
            onPressed: onAsk,
            child: Text('Ask',
                style: PrimarTheme.display(15,
                    color: Colors.white, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.tutor});

  final TutorCard tutor;

  @override
  Widget build(BuildContext context) {
    final url = tutor.photoUrl;
    final initials = tutor.name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    return ClipOval(
      child: Container(
        width: 50,
        height: 50,
        color: PrimarTheme.tintBlue,
        child: url == null || url.isEmpty
            ? Center(
                child: Text(initials,
                    style: PrimarTheme.display(18, color: PrimarTheme.navy)),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => Center(
                  child: Text(initials,
                      style: PrimarTheme.display(18, color: PrimarTheme.navy)),
                ),
              ),
      ),
    );
  }
}
