import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_answers.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_persist.dart';
import 'package:prepskul/features/onboarding/region/region_packs.dart';

void main() {
  test('Cameroon is the default pack with both school worlds', () {
    final cm = packById(null);
    expect(cm.id, 'cm');
    expect(cm.systems.map((s) => s.id), ['cm-francophone', 'cm-anglophone']);
    expect(cm.cities.map((c) => c.id), containsAll(['yaounde', 'douala']));
    expect(cm.label.t('fr'), 'Cameroun');
  });

  test('persist maps BEPC into booking fields, not SAT', () {
    final map = LearnerOnboardingPersist.toSurveyMap(
      const LearnerOnboardingAnswers(
        locale: 'fr',
        countryId: 'cm',
        cityId: 'yaounde',
        systemId: 'cm-francophone',
        levelId: '3eme',
        subjectId: 'maths',
        examId: 'bepc',
        examWhenId: 'soon',
        name: 'Amina',
      ),
    );
    expect(map['specific_exam'], 'BEPC');
    expect(map['exam_type'], 'Regional Exams');
    expect(map['class_level'], '3ème');
    expect(map['preferred_city'], 'Yaoundé');
    expect(map['subjects'], ['Mathématiques']);
    expect(map['learning_goals'], ['Préparer BEPC']);
    expect('${map['specific_exam']}${map['exam_type']}', isNot(contains('SAT')));
  });

  test('Anglophone Cameroon uses GCE not US grades', () {
    final system = systemById(packById('cm'), 'cm-anglophone');
    expect(system.levels.any((l) => l.id == 'form5'), isTrue);
    expect(system.exams.any((e) => e.id == 'gce-o'), isTrue);
    expect(system.levels.any((l) => l.label.en.contains('5th grade')), isFalse);
  });
}
