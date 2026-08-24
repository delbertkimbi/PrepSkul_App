import 'home_copy.dart';
import 'learner.dart';
import 'policy.dart';
import 'skill.dart';
import 'subjects.dart';

/// What the engine thinks a child should work on — for the Ask tab and profile.
///
/// Brilliant's tutor tab answers "what should I do next?" before it offers a
/// human. PrepSkul has real tutors too, but the learner model already knows
/// something honest; hiding it behind a booking stub was the biggest gap in
/// the Ask tab.
class PracticeAdvice {
  const PracticeAdvice({
    required this.subject,
    required this.headline,
    required this.skillLabel,
    required this.explain,
    required this.reason,
  });

  final Subject subject;
  final String headline;
  final String skillLabel;

  /// Child-facing next-step copy — same family as home/profile [homeMateBody].
  /// Never parent-facing [Decision.explain] ("Coming back to…", "keeps going…").
  final String explain;
  final Reason reason;

  bool get exhausted => skillLabel.isEmpty;
}

/// One row per subject that has a skill graph.
List<PracticeAdvice> practiceAdviceFor(Learner learner) {
  final out = <PracticeAdvice>[];
  final locale = learner.locale;
  for (final subject in subjectOrder) {
    if (teachableSkillsFor(subject).isEmpty) continue;
    final decision = nextSkill(learner, subject: subject);
    if (decision.exhausted) {
      out.add(PracticeAdvice(
        subject: subject,
        headline: sessionHeadline(Reason.nothingLeft),
        skillLabel: '',
        explain: homeMateBody(
          locale: locale,
          skillLabel: subject.label(locale),
          reason: Reason.nothingLeft,
        ),
        reason: Reason.nothingLeft,
      ));
      continue;
    }
    final skill = skillsById[decision.skillId!]!;
    out.add(PracticeAdvice(
      subject: subject,
      headline: sessionHeadline(decision.reason),
      skillLabel: skill.label,
      explain: homeMateBody(
        locale: locale,
        skillLabel: skill.label,
        reason: decision.reason,
      ),
      reason: decision.reason,
    ));
  }
  return out;
}

/// Tips that do not pretend a tutor is on the line — honest self-help first.
List<String> tutorTips(String locale) {
  final fr = locale == 'fr';
  return fr
      ? const [
          'Appuyez sur Démarrer sur l\'onglet Apprendre — Mate choisit la prochaine compétence.',
          'Si c\'est difficile, revenez demain : la révision est prévue automatiquement.',
          'Un adulte peut enregistrer sa voix dans les réglages de voix.',
          'Pour un vrai professeur, appuyez sur Demander et demandez à un adulte de réserver dans PrepSkul.',
        ]
      : const [
          'Press Start on the Learn tab — Mate picks the next skill from what you have done.',
          'If it feels hard, come back tomorrow; review is scheduled automatically.',
          'A grown-up can record their voice in the voice settings.',
          'For a real teacher, tap Ask and have a grown-up book in the PrepSkul app.',
        ];
}
