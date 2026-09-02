import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/home_copy.dart';
import 'package:prepskul/features/primar/domain/policy.dart';
import 'package:prepskul/features/primar/domain/progress.dart';

void main() {
  test('fresh day asks for one play', () {
    const summary = ProgressSummary(
      streakDays: 0,
      broken: false,
      playedToday: false,
      answeredToday: 0,
      correctToday: 0,
      skillsCleared: 0,
      skillsTotal: 10,
      minutesToday: 0,
      secondsToday: 0,
    );
    final quest = dailyQuestFor(locale: 'en', summary: summary);
    expect(quest.complete, isFalse);
    expect(quest.body, contains('Play once'));
    expect(quest.progress, 0);
  });

  test('partial answers show remaining count', () {
    const summary = ProgressSummary(
      streakDays: 1,
      broken: false,
      playedToday: true,
      answeredToday: 2,
      correctToday: 2,
      skillsCleared: 1,
      skillsTotal: 10,
      minutesToday: 3,
      secondsToday: 180,
    );
    final quest = dailyQuestFor(locale: 'en', summary: summary);
    expect(quest.complete, isFalse);
    expect(quest.body, contains('3 more'));
    expect(quest.progress, closeTo(0.4, 0.01));
  });

  test('goal met marks complete', () {
    const summary = ProgressSummary(
      streakDays: 2,
      broken: false,
      playedToday: true,
      answeredToday: 5,
      correctToday: 4,
      skillsCleared: 2,
      skillsTotal: 10,
      minutesToday: 8,
      secondsToday: 480,
    );
    final quest = dailyQuestFor(locale: 'en', summary: summary);
    expect(quest.complete, isTrue);
    expect(quest.progress, 1);
  });

  test('review decision adds bonus wording', () {
    const summary = ProgressSummary(
      streakDays: 1,
      broken: false,
      playedToday: true,
      answeredToday: 1,
      correctToday: 1,
      skillsCleared: 1,
      skillsTotal: 10,
      minutesToday: 2,
      secondsToday: 120,
    );
    const decision = Decision(skillId: 'letter.sound', reason: Reason.review);
    final quest = dailyQuestFor(
      locale: 'en',
      summary: summary,
      decision: decision,
    );
    expect(quest.body.toLowerCase(), contains('review'));
  });
}
