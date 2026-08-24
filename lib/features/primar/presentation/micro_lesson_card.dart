import 'package:flutter/material.dart';

import '../domain/micro_lesson.dart';
import '../services/primar_voice.dart';
import '../services/tutor_brain.dart';
import 'letter_card.dart';
import 'mascot.dart';
import 'primar_theme.dart';

/// Shown after the second miss on a skill, before the next attempt.
///
/// Names the error, shows a tiny teach gesture, then waits for "Try again".
/// Spoken through [TutorBrain] so the line stays specific when the network is
/// off — this card never waits on a request.
class MicroLessonCard extends StatefulWidget {
  const MicroLessonCard({
    super.key,
    required this.lesson,
    required this.onRetry,
  });

  final MicroLesson lesson;
  final VoidCallback onRetry;

  @override
  State<MicroLessonCard> createState() => _MicroLessonCardState();
}

class _MicroLessonCardState extends State<MicroLessonCard> {
  @override
  void initState() {
    super.initState();
    final lesson = widget.lesson;
    PrimarVoice.instance.sayFromBrain(
      TutorContext(
        moment: TutorMoment.microLesson,
        locale: lesson.locale,
        skillId: lesson.skillId,
        item: lesson.item,
        chosenIndex: lesson.chosenIndex,
        misconception: lesson.misconception,
        letter: lesson.letter,
        sound: lesson.sound,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    return Column(
      children: [
        const Mate(mood: Mood.encourage, size: 84),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: PrimarTheme.tile(border: PrimarTheme.orange, lift: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lesson.locale == 'fr' ? 'PETITE LEÇON' : 'QUICK TEACH',
                style: PrimarTheme.label(10, color: PrimarTheme.orange),
              ),
              const SizedBox(height: 8),
              Text(lesson.title, style: PrimarTheme.display(19)),
              const SizedBox(height: 10),
              Text(lesson.coachLine, style: PrimarTheme.body(16.5)),
              if (lesson.gestureHint.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(lesson.gestureHint,
                    style: PrimarTheme.body(15, color: PrimarTheme.navy)),
              ],
              if (lesson.showLetterCard &&
                  LetterCard.canShow(lesson.letter!, locale: lesson.locale)) ...[
                const SizedBox(height: 16),
                LetterCard(
                  letter: lesson.letter!,
                  sound: lesson.sound!,
                  locale: lesson.locale,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: widget.onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: PrimarTheme.tile(
                border: PrimarTheme.teal,
                fill: PrimarTheme.tintTeal,
                lift: 5,
              ),
              alignment: Alignment.center,
              child: Text(
                lesson.cta,
                style: PrimarTheme.display(20, color: PrimarTheme.navy),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
