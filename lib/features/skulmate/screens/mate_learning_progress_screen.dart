import 'package:flutter/material.dart';
import 'package:prepskul/core/design/learner_design.dart';
import 'package:prepskul/core/design/prepskul_icon.dart';
import '../services/learning_activity_store.dart';
import '../services/lesson_plan_service.dart';
import '../models/lesson_plan_model.dart';
import 'package:prepskul/core/widgets/alive_mate.dart';

class MateLearningProgressScreen extends StatefulWidget {
  const MateLearningProgressScreen({super.key});
  @override
  State<MateLearningProgressScreen> createState() => _ProgressState();
}

class _ProgressState extends State<MateLearningProgressScreen> {
  late final events = LearningActivityStore.read();
  late final paths = LessonPlanService.listSaved().timeout(
    const Duration(seconds: 10),
  );
  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    return Scaffold(
      backgroundColor: LearnerDesign.canvas,
      appBar: AppBar(
        title: Text(
          fr ? 'Mon apprentissage' : 'My learning',
          style: LearnerDesign.title(23),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: events,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: Text('…'));
          final rows = snapshot.data!;
          final streak = LearningActivityStore.streak(rows, DateTime.now());
          final attempts = rows.where((r) => r['kind'] == 'practice').length;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: AliveMate(mood: Mood.cheer, size: 132)),
              const SizedBox(height: 8),
              const PrepSkulIcon(PrepSkulGlyph.streak, size: 32),
              const SizedBox(height: 20),
              Text(
                fr ? '$streak jours de suite' : '$streak day learning streak',
                style: LearnerDesign.title(28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                fr
                    ? 'Activité enregistrée sur cet appareil.'
                    : 'Learning recorded on this device.',
                style: LearnerDesign.body(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FutureBuilder<List<LessonPlan>>(
                future: paths,
                builder: (context, saved) {
                  if (saved.hasError)
                    return Text(
                      fr
                          ? 'Les parcours enregistrés sont indisponibles pour le moment.'
                          : 'Saved lesson progress is temporarily unavailable.',
                      style: LearnerDesign.body(),
                    );
                  if (!saved.hasData) return const LinearProgressIndicator();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fr ? 'Tes parcours' : 'Your learning paths',
                        style: LearnerDesign.title(22),
                      ),
                      const SizedBox(height: 12),
                      if (saved.data!.isEmpty)
                        Text(
                          fr
                              ? 'Tes parcours apparaîtront ici.'
                              : 'Your saved lessons will appear here.',
                          style: LearnerDesign.body(),
                        ),
                      for (final plan in saved.data!)
                        Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plan.topic,
                                  style: LearnerDesign.title(19),
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: plan.steps.isEmpty
                                      ? 0
                                      : plan.steps
                                                .where(
                                                  (s) =>
                                                      s.status == 'completed',
                                                )
                                                .length /
                                            plan.steps.length,
                                  color: LearnerDesign.ink,
                                  backgroundColor: LearnerDesign.sky,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${plan.steps.where((s) => s.status == 'completed').length} / ${plan.steps.length} ${fr ? 'étapes terminées' : 'steps completed'}',
                                  style: LearnerDesign.body(13),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                fr
                    ? '$attempts réponses d’entraînement'
                    : '$attempts practice answers',
                style: LearnerDesign.title(21),
              ),
              const SizedBox(height: 12),
              Text(
                rows.isEmpty
                    ? (fr
                          ? 'Ta prochaine séance avec Mate commence ta série.'
                          : 'Your next learning session with Mate starts your streak.')
                    : (fr
                          ? 'Reviens explorer une notion ou t’entraîner. Les réponses aidées ne prouvent pas encore la maîtrise.'
                          : 'Come back to explore a concept or practise. Assisted answers are practice, not proof of mastery.'),
                style: LearnerDesign.text(size: 16),
              ),
            ],
          );
        },
      ),
    );
  }
}
