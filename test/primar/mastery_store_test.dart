import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/mastery.dart';
import 'package:prepskul/features/primar/services/mastery_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A result the child earned must survive whatever the network is doing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const topic = 'foundational.numeracy.number-sense';

  Placement placement({
    double level = 5,
    int correct = 10,
    int total = 14,
    bool provisional = false,
  }) =>
      Placement(
        level: level,
        masteryScore: level / 10,
        accuracy: correct / total,
        correct: correct,
        total: total,
        medianMs: 3200,
        provisional: provisional,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MasteryStore.instance.clear();
  });

  test('a finished session is kept on the device', () async {
    // Supabase is not initialised in tests, so sync throws internally — the
    // point of this test is that recording still succeeds regardless.
    await MasteryStore.instance.record(topicId: topic, placement: placement());

    final history = await MasteryStore.instance.historyFor(topic);
    expect(history, hasLength(1));
    expect(history.first['level'], 5);
    expect(history.first['correct'], 10);
    expect(history.first['total'], 14);
  });

  test('history accumulates in order and keeps topics apart', () async {
    await MasteryStore.instance.record(topicId: topic, placement: placement(level: 3));
    await MasteryStore.instance.record(topicId: topic, placement: placement(level: 6));
    await MasteryStore.instance.record(
      topicId: 'foundational.literacy.letters-and-words.en',
      placement: placement(level: 9),
    );

    final numeracy = await MasteryStore.instance.historyFor(topic);
    expect(numeracy.map((e) => e['level']), [3, 6],
        reason: 'oldest first, and only this topic');

    final reading = await MasteryStore.instance
        .historyFor('foundational.literacy.letters-and-words.en');
    expect(reading, hasLength(1));
  });

  test('sessions for different children do not mix', () async {
    await MasteryStore.instance
        .record(topicId: topic, placement: placement(level: 2), childId: 'ayuk');
    await MasteryStore.instance
        .record(topicId: topic, placement: placement(level: 8), childId: 'bih');

    expect(
      (await MasteryStore.instance.historyFor(topic, childId: 'ayuk')).single['level'],
      2,
    );
    expect(
      (await MasteryStore.instance.historyFor(topic, childId: 'bih')).single['level'],
      8,
    );
  });

  test('a provisional placement is kept locally but never queued for sync',
      () async {
    // A provisional result is a guess. Syncing guesses would poison the signal
    // that routing later depends on.
    await MasteryStore.instance
        .record(topicId: topic, placement: placement(provisional: true));

    final prefs = await SharedPreferences.getInstance();
    expect(await MasteryStore.instance.historyFor(topic), hasLength(1));
    expect(prefs.getString('primar.mastery.outbox') ?? '[]', '[]',
        reason: 'provisional results must not reach the outbox');
  });

  test('a settled placement is queued, and survives having no connection',
      () async {
    await MasteryStore.instance.record(topicId: topic, placement: placement());

    final prefs = await SharedPreferences.getInstance();
    final outbox = prefs.getString('primar.mastery.outbox') ?? '[]';
    expect(outbox, contains(topic),
        reason: 'result was dropped instead of waiting for a connection');
  });

  test('corrupt storage is survived rather than crashing a session', () async {
    SharedPreferences.setMockInitialValues({
      'primar.mastery.history': 'not json at all',
    });

    expect(await MasteryStore.instance.historyFor(topic), isEmpty);
    await MasteryStore.instance.record(topicId: topic, placement: placement());
    expect(await MasteryStore.instance.historyFor(topic), hasLength(1));
  });

  test('history is capped so storage cannot grow without bound', () async {
    for (var i = 0; i < 130; i++) {
      await MasteryStore.instance.record(topicId: topic, placement: placement());
    }
    final history = await MasteryStore.instance.historyFor(topic);
    expect(history.length, lessThanOrEqualTo(120));
  });
}
