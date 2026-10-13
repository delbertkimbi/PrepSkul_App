import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_answers.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_persist.dart';
import 'package:prepskul/features/onboarding/region/region_packs.dart';
import 'package:prepskul/features/onboarding/region/cameroon_pathways.dart';

void main() {
  test(
    'arts and science change suggestion order and retain other subjects',
    () {
      final base = cameroonAnglophone.subjects;
      final science = pathwaySubjects(base, 'general', stream: 'science');
      final arts = pathwaySubjects(base, 'general', stream: 'arts');
      expect(science.take(4).map((s) => s.id), [
        'maths',
        'physics',
        'chemistry',
        'biology',
      ]);
      expect(arts.first.id, 'english');
      expect(arts.map((s) => s.id), contains('maths'));
      expect(arts.last.id, 'other');
      expect(
        pathwaySubjects(base, 'commercial').map((s) => s.id),
        contains('accounting'),
      );
      expect(
        pathwaySubjects(base, 'technical').map((s) => s.id),
        isNot(contains('accounting')),
      );
    },
  );
  test('changing level clears stale curriculum choices', () {
    const original = LearnerOnboardingAnswers(
      systemId: 'cm-anglophone',
      levelId: 'form5',
      pathwayId: 'commercial',
      subjectId: 'other',
      subjectOther: 'Accounting',
      examId: 'tvee-il',
    );
    final changed = original.copyWith(levelId: 'u6', clearPathway: true);
    expect(changed.pathwayId, isNull);
    expect(changed.subjectId, isNull);
    expect(changed.subjectOther, isNull);
    expect(changed.examId, isNull);
  });
  test('commercial subjects and scope survive saving', () {
    const answers = LearnerOnboardingAnswers(
      systemId: 'cm-anglophone',
      levelId: 'form5',
      pathwayId: 'commercial',
      subjectId: 'accounting',
      examId: 'tvee-il',
    );
    final restored = LearnerOnboardingAnswers.fromJson(answers.toJson());
    final survey = LearnerOnboardingPersist.toSurveyMap(restored);
    expect(restored.pathwayId, 'commercial');
    expect(survey['subjects'], ['Accounting']);
    expect(survey['specific_exam'], 'TVEE Intermediate Level');
  });

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
        learningGoalId: 'exam-prep',
        examId: 'bepc',
        examWhenId: 'soon',
        name: 'Amina',
      ),
    );
    expect(map['specific_exam'], 'BEPC');
    expect(map['exam_type'], 'Regional Exams');
    expect(map['class_level'], '3ème');
    expect(map['city'], 'Yaoundé');
    expect(map['subjects'], ['Mathématiques']);
    expect(map['learning_goals'], ['Préparer BEPC']);
    expect(
      '${map['specific_exam']}${map['exam_type']}',
      isNot(contains('SAT')),
    );
  });

  test('Anglophone Cameroon uses GCE not US grades', () {
    final system = systemById(packById('cm'), 'cm-anglophone');
    expect(system.levels.any((l) => l.id == 'form5'), isTrue);
    expect(system.exams.any((e) => e.id == 'gce-o'), isTrue);
    expect(system.levels.any((l) => l.label.en.contains('5th grade')), isFalse);
  });

  test('subject suggestions follow the selected country and level', () {
    final nigeria = packById('ng');
    final nigeriaSystem = systemById(nigeria, 'ng-waec');
    expect(
      subjectOptionsFor(nigeria, nigeriaSystem, 'ss3').map((item) => item.id),
      containsAll(['basic-science', 'social-studies']),
    );

    final cameroon = packById('cm');
    final francophone = systemById(cameroon, 'cm-francophone');
    expect(
      subjectOptionsFor(cameroon, francophone, 'cm2').map((item) => item.id),
      ['maths', 'language', 'science', 'other'],
    );
  });
}
