import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/screener.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';
import 'package:prepskul/features/primar/services/evidence_store.dart';
import 'package:prepskul/features/primar/services/learner_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LearnerProfileStore.instance.resetCache();
    await EvidenceStore.instance.resetBinding();
    await EvidenceStore.instance.clear();
  });

  test('profile round-trips screener answers and seenDemo', () async {
    const answers = ScreenerAnswers(
      name: 'Ayuk',
      locale: 'fr',
      subject: Subject.reading,
      age: 8,
      schooling: Schooling.patchy,
      seenDoing: SeenDoing.starting,
      voiceId: 'guide',
    );

    await LearnerProfileStore.instance.saveAnswers(answers, seenDemo: false);
    LearnerProfileStore.instance.resetCache();

    final loaded = await LearnerProfileStore.instance.load();
    expect(loaded, isNotNull);
    expect(loaded!.answers.name, 'Ayuk');
    expect(loaded.answers.locale, 'fr');
    expect(loaded.answers.subject, Subject.reading);
    expect(loaded.answers.age, 8);
    expect(loaded.seenDemo, isFalse);

    await LearnerProfileStore.instance.markSeenDemo();
    LearnerProfileStore.instance.resetCache();
    final again = await LearnerProfileStore.instance.load();
    expect(again!.seenDemo, isTrue);
  });

  test('evidence is namespaced per child name', () async {
    await EvidenceStore.instance.bindChild('Ayuk');
    expect(EvidenceStore.instance.storageKeyForTest, 'primar_evidence_v1_ayuk');

    await EvidenceStore.instance.bindChild('Bella');
    expect(EvidenceStore.instance.storageKeyForTest, 'primar_evidence_v1_bella');

    await EvidenceStore.instance.bindChild('');
    expect(EvidenceStore.instance.storageKeyForTest, 'primar_evidence_v1');
  });

  test('bindChild migrates legacy log once for a named child', () async {
    // Write under the legacy key as an older install would.
    await EvidenceStore.instance.bindChild(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'primar_evidence_v1',
      '[{"s":"letter.shape","c":true,"ms":1000,"t":"2026-08-01T10:00:00.000","h":false,"m":"unclear","x":false}]',
    );
    EvidenceStore.instance.resetCache();

    await EvidenceStore.instance.bindChild('Ayuk');
    final log = await EvidenceStore.instance.load();
    expect(log, hasLength(1));
    expect(log.first.skillId, 'letter.shape');
    expect(
      prefs.getString('primar_evidence_v1_ayuk'),
      isNotNull,
    );
  });
}
