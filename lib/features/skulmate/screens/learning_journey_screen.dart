import 'package:timeline_tile/timeline_tile.dart';
import 'package:prepskul/core/design/prepskul_icon.dart';
import 'package:prepskul/core/design/learner_action.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prepskul/features/booking/services/individual_session_service.dart';
import 'package:prepskul/core/design/learner_design.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';
import '../models/lesson_plan_model.dart';
import '../models/skulmate_intake_models.dart';
import '../services/lesson_plan_service.dart';
import '../services/learner_context_service.dart';
import 'skulmate_path_overview_screen.dart';
import 'skulmate_home_screen.dart';

class LearningJourneyScreen extends StatefulWidget {
  final String? learnerName;
  final VoidCallback? onSessions;
  final VoidCallback onMate;
  final VoidCallback onTutors;
  final Future<List<LessonPlan>> Function()? loadPlans;
  const LearningJourneyScreen({
    super.key,
    this.learnerName,
    this.onSessions,
    required this.onMate,
    required this.onTutors,
    this.loadPlans,
  });
  @override
  State<LearningJourneyScreen> createState() => _LearningJourneyScreenState();
}

class _LearningJourneyScreenState extends State<LearningJourneyScreen> {
  late Future<List<LessonPlan>> _plans;
  List<LessonPlan>? _lastPlans;
  int _loadGeneration = 0;
  Future<List<Map<String, dynamic>>>? _upcoming;
  String? _suggestedTopic;

  bool get fr => Localizations.localeOf(context).languageCode == 'fr';
  @override
  void initState() {
    super.initState();
    _plans = _load();
    _loadStartingPoint();
    if (widget.onSessions != null) {
      _upcoming = IndividualSessionService.getStudentUpcomingSessions(limit: 1);
    }
  }

  Future<void> _loadStartingPoint() async {
    try {
      final context = await LearnerContextService.build().timeout(
        const Duration(seconds: 8),
      );
      final subjects = context?['subjects'] ?? context?['subject_preferences'];
      final subject = subjects is List && subjects.isNotEmpty
          ? subjects.first.toString()
          : subjects is String
          ? subjects
          : null;
      final level = context?['class_level'] ?? context?['student_grade'];
      if (!mounted || subject == null || subject.trim().isEmpty) return;
      setState(() {
        _suggestedTopic = level == null ? subject : '$subject · $level';
      });
    } catch (_) {
      /* Manual starting points remain available. */
    }
  }

  Future<List<LessonPlan>> _load() async {
    final generation = ++_loadGeneration;
    if (widget.loadPlans == null && _lastPlans == null) {
      final cached = await LessonPlanService.readCached();
      if (mounted && generation == _loadGeneration && cached.isNotEmpty) {
        setState(() => _lastPlans = cached);
      }
    }
    final plans = await (widget.loadPlans ?? LessonPlanService.listSaved)()
        .timeout(const Duration(seconds: 10));
    // Keep the last successful result while refreshing. A late response from
    // an older request must not replace the newer result.
    if (mounted && generation == _loadGeneration) _lastPlans = plans;
    return plans;
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _plans = next;
      if (widget.onSessions != null) {
        _upcoming = IndividualSessionService.getStudentUpcomingSessions(
          limit: 1,
        );
      }
    });
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _startPlan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => SkulMateHomeScreen(
          startFresh: true,
          onExit: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _resume(LessonPlan plan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SkulMatePathOverviewScreen(
          initialLesson: plan,
          payload: SkulMateIntakePayload(
            source: SkulMateIntakeSource.typedTopic,
            topicHint: plan.topic,
          ),
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(
          fr
              ? 'Un pas de plus vers tes objectifs.'
              : 'One step closer to your goals.',
          style: LearnerDesign.body(14),
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<LessonPlan>>(
          future: _plans,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                (_lastPlans?.isNotEmpty != true)) {
              return Semantics(
                label: fr
                    ? 'Chargement de ton parcours'
                    : 'Loading your learning path',
                child: ExcludeSemantics(
                  child: Container(
                    height: 188,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: LearnerDesign.ink.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final width in [100.0, 220.0, 160.0, 120.0])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Container(
                              width: width,
                              height: 18,
                              decoration: BoxDecoration(
                                color: LearnerDesign.ink.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }
            final plans = snapshot.data ?? _lastPlans ?? <LessonPlan>[];
            if (snapshot.hasError && plans.isEmpty) {
              return _panel(
                color: const Color(0xFFFFF1DC),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fr
                          ? 'Ton parcours n’a pas pu être chargé.'
                          : 'Your saved path couldn’t load.',
                      style: LearnerDesign.title(22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fr
                          ? 'Tes progrès sont conservés. Réessaie.'
                          : 'Your progress hasn’t been reset. Try again or continue with Mate.',
                      style: LearnerDesign.body(),
                    ),
                    TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(fr ? 'Réessayer' : 'Try again'),
                    ),
                  ],
                ),
              );
            }
            if (plans.isEmpty) {
              return _panel(
                color: LearnerDesign.sky,
                child: Column(
                  children: [
                    const AliveMate(mood: Mood.wave, size: 112),
                    Text(
                      fr
                          ? 'Qu’as-tu envie d’apprendre ?'
                          : 'What will we learn today?',
                      style: LearnerDesign.title(24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _suggestedTopic ??
                          (fr
                              ? 'Une idée, une question, tes notes.'
                              : 'An idea, a question, your notes.'),
                      style: LearnerDesign.body(),
                    ),
                    const SizedBox(height: 18),
                    LearnerAction(
                      label: fr ? 'Commencer avec Mate' : 'Start with Mate',
                      onPressed: _startPlan,
                    ),
                  ],
                ),
              );
            }
            final active =
                plans.where((p) => !p.isComplete).firstOrNull ?? plans.first;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          fr
                              ? 'Dernier parcours chargé. Actualisation indisponible.'
                              : 'Showing your last loaded path. Refresh unavailable.',
                          style: LearnerDesign.body(13),
                        ),
                        TextButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(fr ? 'Réessayer' : 'Try again'),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: LearnerDesign.ink,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fr
                                      ? 'On reprend ?'
                                      : 'Ready for your next step?',
                                  style: LearnerDesign.body(
                                    13,
                                  ).copyWith(color: Colors.white70),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  active.topic,
                                  style: LearnerDesign.title(
                                    23,
                                  ).copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  active.activeStep?.title ?? '',
                                  style: LearnerDesign.body(
                                    14,
                                  ).copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const AliveMate(mood: Mood.encourage, size: 88),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD335),
                          foregroundColor: LearnerDesign.ink,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: () => _resume(active),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          fr ? 'Reprendre la leçon' : 'Resume lesson',
                          style: LearnerDesign.text(weight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: LearnerAction(
                        secondary: true,
                        label: fr ? 'Mon parcours' : 'My learning path',
                        icon: const PrepSkulIcon(PrepSkulGlyph.learn),
                        onPressed: () => _openPath(active),
                      ),
                    ),
                    const SizedBox(width: 12),
                    LearnerAction(
                      compact: true,
                      secondary: true,
                      label: fr ? 'Nouveau parcours' : 'New learning path',
                      icon: const Icon(Icons.add),
                      onPressed: _startPlan,
                    ),
                  ],
                ),
                if (plans.length > 1) ...[
                  const SizedBox(height: 18),
                  Text(
                    fr ? 'Tes autres parcours' : 'Your other paths',
                    style: LearnerDesign.title(18),
                  ),
                  for (final plan in plans.where((p) => p.id != active.id))
                    ListTile(
                      title: Text(plan.topic, style: LearnerDesign.body()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _resume(plan),
                    ),
                ],
              ],
            );
          },
        ),
        if (_upcoming != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  fr ? 'Prochaine séance' : 'Upcoming session',
                  style: LearnerDesign.title(18),
                ),
              ),
              TextButton(
                onPressed: widget.onSessions,
                child: Text(fr ? 'Tout voir' : 'View all'),
              ),
            ],
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _upcoming,
            builder: (context, snapshot) {
              final session = snapshot.data?.firstOrNull;
              final recurring = session?['recurring_sessions'];
              final details = recurring is Map ? recurring : const {};
              final subject = session?['subject'] ?? details['subject'];
              final tutor = session?['tutor_name'] ?? details['tutor_name'];
              final date = session?['scheduled_date']
                  ?.toString()
                  .split('T')
                  .first;
              final time = session?['scheduled_time']?.toString();
              final day = DateTime.tryParse(date ?? '');
              final dayLabel = day == null
                  ? date
                  : DateFormat('EEE, d MMM', fr ? 'fr' : 'en').format(day);
              final timeLabel = time != null && time.length >= 5
                  ? time.substring(0, 5)
                  : time;
              return Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: LearnerDesign.line),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: LearnerDesign.sky,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_today_outlined,
                      color: LearnerDesign.blue,
                      size: 21,
                    ),
                  ),
                  title: Text(
                    session == null
                        ? (fr
                              ? 'Ton agenda, à ton rythme.'
                              : 'Your schedule, your pace.')
                        : [subject, tutor]
                              .where(
                                (v) => v != null && v.toString().isNotEmpty,
                              )
                              .join(' · '),
                    style: LearnerDesign.title(15),
                  ),
                  subtitle: Text(
                    session == null
                        ? (fr
                              ? 'Consulte tes cours ou réserve un créneau.'
                              : 'View your lessons or book a time.')
                        : [dayLabel, timeLabel].whereType<String>().join(' · '),
                    style: LearnerDesign.body(13),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: widget.onSessions,
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        _panel(
          color: LearnerDesign.sky,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fr ? 'Apprends avec Mate' : 'Learn with Mate',
                      style: LearnerDesign.title(
                        20,
                      ).copyWith(color: LearnerDesign.ink),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fr
                          ? 'Tu n’as pas besoin d’un plan pour demander de l’aide.'
                          : 'Talk through an idea. Try it together.',
                      style: LearnerDesign.text(
                        size: 14,
                        weight: FontWeight.w500,
                        color: LearnerDesign.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: LearnerDesign.ink,
                  foregroundColor: Colors.white,
                ),
                tooltip: fr ? 'Parler à Mate' : 'Talk to Mate',
                onPressed: widget.onMate,
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.people_outline),
          title: Text(
            fr ? 'Besoin d’un tuteur ?' : 'Want to learn with a tutor?',
            style: LearnerDesign.text(size: 16),
          ),
          subtitle: Text(
            fr
                ? 'Trouve quelqu’un pour ta matière, quand tu en as besoin.'
                : 'Find someone for your subject, when you need them.',
            style: LearnerDesign.text(size: 14, weight: FontWeight.w500),
          ),
          trailing: const Icon(Icons.arrow_forward),
          onTap: widget.onTutors,
        ),
      ],
    ),
  );
  void _openPath(LessonPlan plan) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: LearnerDesign.canvas,
        appBar: AppBar(
          backgroundColor: LearnerDesign.canvas,
          title: Text(
            fr ? 'Mon parcours' : 'My learning path',
            style: LearnerDesign.title(22),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const AliveMate(mood: Mood.point, size: 112),
                Text(plan.topic, style: LearnerDesign.title(25)),
                const SizedBox(height: 20),
                _path(plan),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _panel({required Color color, required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
  void _review(
    LessonPlan plan,
    LessonPlanStep step,
  ) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (routeContext) => SkulMateHomeScreen(
        startFresh: true,
        initialMessage:
            'Review my completed lesson on ${plan.topic}: ${step.title}. ${step.body ?? ""} Use my saved class and curriculum. Start with a short recap, then one fresh check. Explain mistakes before another check. This is review; do not advance my learning path.',
        onExit: () => Navigator.of(routeContext).pop(),
      ),
    ),
  );

  Widget _path(LessonPlan plan) => Column(
    children: plan.steps.asMap().entries.map((entry) {
      final step = entry.value;
      final complete = step.status == 'completed';
      final skipped = step.status == 'skipped';
      final current = entry.key == plan.currentStep && !complete && !skipped;
      final status = complete
          ? (fr ? 'Travaillé' : 'Worked through')
          : skipped
          ? (fr ? 'Passé pour le moment' : 'Skipped for now')
          : current
          ? (fr ? 'Reprendre ici' : 'Continue here')
          : (fr ? 'À découvrir' : 'Coming up');
      final action = current
          ? () => _resume(plan)
          : complete
          ? () => _review(plan, step)
          : null;
      return TimelineTile(
        isFirst: entry.key == 0,
        isLast: entry.key == plan.steps.length - 1,
        beforeLineStyle: LineStyle(
          color: complete || current ? LearnerDesign.blue : LearnerDesign.line,
          thickness: 3,
        ),
        indicatorStyle: IndicatorStyle(
          width: 44,
          height: 44,
          indicator: Semantics(
            label: status,
            child: Container(
              decoration: BoxDecoration(
                color: current
                    ? LearnerDesign.ink
                    : complete
                    ? LearnerDesign.sky
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: current ? LearnerDesign.ink : LearnerDesign.line,
                  width: 2,
                ),
              ),
              child: Icon(
                complete
                    ? Icons.check_rounded
                    : current
                    ? Icons.play_arrow_rounded
                    : Icons.lock_outline_rounded,
                color: current ? Colors.white : LearnerDesign.ink,
                size: 22,
              ),
            ),
          ),
        ),
        endChild: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 0, 16),
          child: Material(
            color: current ? LearnerDesign.sky : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: current ? LearnerDesign.blue : LearnerDesign.line,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: action,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key + 1}'.padLeft(2, '0'),
                      style: LearnerDesign.body(12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.type == 'recap'
                          ? (fr ? 'Revoir ensemble' : 'Look back together')
                          : step.title,
                      style: LearnerDesign.title(19),
                    ),
                    const SizedBox(height: 8),
                    Text(status, style: LearnerDesign.body(13)),
                    if (complete)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          fr ? 'Revoir avec Mate →' : 'Review with Mate →',
                          style: LearnerDesign.text(
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}
