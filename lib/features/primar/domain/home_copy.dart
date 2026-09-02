/// Copy for the home screen and profile — never session intros.
///
/// Home tells a child *what to play next*. Session intros teach mechanics.
/// Those must never share phrasing, or a returning learner hears onboarding
/// again every morning.
library;

import 'policy.dart';
import 'progress.dart';
import 'skill.dart';

/// How many correct answers count as finishing today's quest.
const int dailyQuestAnswerGoal = 5;

/// Today's goal on the home path — streak framing without punishing misses.
class DailyQuest {
  const DailyQuest({
    required this.title,
    required this.body,
    required this.progress,
    required this.complete,
    this.goal = dailyQuestAnswerGoal,
  });

  final String title;
  final String body;

  /// 0–1 toward [goal].
  final double progress;
  final bool complete;
  final int goal;
}

DailyQuest dailyQuestFor({
  required String locale,
  required ProgressSummary summary,
  Decision? decision,
  int answerGoal = dailyQuestAnswerGoal,
}) {
  final fr = locale == 'fr';
  final title = fr ? 'Quête du jour' : "Today's quest";

  if (!summary.playedToday) {
    return DailyQuest(
      title: title,
      body: fr ? 'Joue une fois aujourd\'hui.' : 'Play once today.',
      progress: 0,
      complete: false,
      goal: 1,
    );
  }

  if (summary.answeredToday >= answerGoal) {
    return DailyQuest(
      title: title,
      body: fr ? 'Quête faite — bravo !' : 'Quest done — nice work!',
      progress: 1,
      complete: true,
      goal: answerGoal,
    );
  }

  final left = answerGoal - summary.answeredToday;
  final reviewBonus = decision != null &&
      !decision.exhausted &&
      decision.reason == Reason.review;
  final body = reviewBonus
      ? (fr
          ? 'Réponds à $left de plus — et revois une compétence.'
          : 'Answer $left more — and review a skill.')
      : (fr
          ? 'Réponds à $left de plus aujourd\'hui.'
          : 'Answer $left more today.');

  return DailyQuest(
    title: title,
    body: body,
    progress: summary.answeredToday / answerGoal,
    complete: false,
    goal: answerGoal,
  );
}

/// Snackbar when a child taps a locked path node.
String lockedPathMessage({
  required String locale,
  required String blockerLabel,
}) {
  final fr = locale == 'fr';
  return fr
      ? 'Finis « $blockerLabel » d\'abord.'
      : 'Finish $blockerLabel first.';
}

/// Phrases that belong on onboarding or in-lesson intros — banned on home.
const List<String> bannedHomePhraseFragments = [
  'four short questions',
  'four questions',
  'ask you four',
  'take you through',
  'next 4 steps',
  'next four steps',
  'i will ask you',
  'let us try three quick',
  'three quick ones',
  'now the real game',
  'give the phone to',
  'hand the phone',
  'how it works',
  'quatre petites questions',
  'je vais te poser',
  'quatre questions',
  'trois essais rapides',
  'passe le téléphone',
  'comment ça marche',
];

/// True when [text] reads like onboarding or a session walk-through.
bool isSessionIntroCopy(String text) {
  final lower = text.toLowerCase();
  return bannedHomePhraseFragments.any(lower.contains);
}

/// Short label under the Start card kicker (UP NEXT / REVIEW / PRACTICE).
String homeStartSubline({
  required String locale,
  required String skillLabel,
  required Reason reason,
}) {
  final fr = locale == 'fr';
  return switch (reason) {
    Reason.review => fr
        ? 'On revoit $skillLabel — appuie sur Démarrer.'
        : 'Review $skillLabel — tap Start when you are ready.',
    Reason.repair || Reason.reteach => fr
        ? 'On s\'entraîne sur $skillLabel. Démarrer quand tu es prêt.'
        : 'Practice $skillLabel — tap Start when you are ready.',
    Reason.transfer => fr
        ? '$skillLabel dans un nouveau jeu — Démarrer.'
        : '$skillLabel in a new activity — tap Start.',
    Reason.nothingLeft => fr
        ? 'Tu as tout fini ici pour l\'instant.'
        : 'You have finished everything here for now.',
    _ => fr
        ? 'Prochain jeu : $skillLabel. Appuie sur Démarrer.'
        : 'Next up: $skillLabel. Tap Start when you are ready.',
  };
}

/// Voice line when the Learn tab opens — action-oriented, names the skill.
String homeNextVoiceLine({
  required String locale,
  required String childName,
  required String skillLabel,
  required Reason reason,
}) {
  final who = childName.trim().isEmpty
      ? (locale == 'fr' ? 'toi' : 'you')
      : childName.trim();
  final fr = locale == 'fr';
  return switch (reason) {
    Reason.review => fr
        ? '$who, on revoit $skillLabel. Appuie sur Démarrer.'
        : '$who, time to review $skillLabel. Tap Start when you are ready.',
    Reason.repair || Reason.reteach => fr
        ? '$who, on s\'entraîne sur $skillLabel. Démarrer quand tu es prêt.'
        : '$who, let us practice $skillLabel. Tap Start when you are ready.',
    Reason.transfer => fr
        ? '$who, $skillLabel dans un nouveau jeu. Appuie sur Démarrer.'
        : '$who, $skillLabel in a new activity. Tap Start when you are ready.',
    Reason.nothingLeft => fr
        ? '$who, tu as tout fini ici. Reviens demain pour la révision.'
        : '$who, you have finished everything here. Come back tomorrow for review.',
    _ => fr
        ? '$who, prochain jeu : $skillLabel. Appuie sur Démarrer.'
        : '$who, next up: $skillLabel. Tap Start when you are ready.',
  };
}

/// Mate-says body on home/profile — not the engine's parent-facing [Decision.explain].
String homeMateBody({
  required String locale,
  required String skillLabel,
  required Reason reason,
  String? objective,
}) {
  final hint = (objective != null && objective.isNotEmpty)
      ? objective
      : homeStartSubline(
          locale: locale,
          skillLabel: skillLabel,
          reason: reason,
        );
  assert(!isSessionIntroCopy(hint), 'Home copy must not use session-intro phrasing');
  return hint;
}

/// One-line skill objective from the curriculum when we have a skill id.
String? skillObjective(String? skillId, String locale) {
  if (skillId == null) return null;
  final skill = skillsById[skillId];
  if (skill == null) return null;
  // Keep it short — the skill label plus strand is enough for v1.
  final fr = locale == 'fr';
  return fr ? 'Compétence : ${skill.label}.' : 'Skill: ${skill.label}.';
}
