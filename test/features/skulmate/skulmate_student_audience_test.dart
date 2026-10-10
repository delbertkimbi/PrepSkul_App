import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/l10n/skulmate_copy.dart';

void main() {
  test('welcome copy treats learner and parent as the student', () {
    final en = SkulMateCopy(false);
    final fr = SkulMateCopy(true);

    expect(en.welcomeAiLine(), contains('learner or a parent'));
    expect(fr.welcomeAiLine(), contains('learner ou parent'));

    expect(en.welcomeBenefitResume(isParent: true), contains('you left off'));
    expect(
      en.welcomeBenefitResume(isParent: true).toLowerCase(),
      isNot(contains('they left')),
    );
    expect(
      en.welcomeBenefitLeaderboard(isParent: true).toLowerCase(),
      isNot(contains('their xp')),
    );
    expect(en.tutorEmptyPrompt.toLowerCase(), contains('i am listening'));
    expect(en.historyEmpty.toLowerCase(), contains('thread'));
    expect(en.newThread.toLowerCase(), contains('new thread'));
  });
}
