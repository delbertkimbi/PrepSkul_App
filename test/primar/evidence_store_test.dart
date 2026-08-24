import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/learner.dart';
import 'package:prepskul/features/primar/domain/misconception.dart';
import 'package:prepskul/features/primar/services/evidence_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything a child does has to survive the app closing.
///
/// Until this existed the learner model was rebuilt from an in-memory log, so
/// shutting the app put every skill back to `notStarted` — the misconceptions
/// forgotten, the spaced reviews gone, the placement thrown away. A product
/// whose promise is "grows with your learner" cannot begin again every morning.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t0 = DateTime(2026, 8, 15, 9);

  Evidence ev(
    String skill, {
    bool correct = true,
    int minute = 0,
    bool help = false,
    bool transfer = false,
    Misconception miss = Misconception.unclear,
  }) =>
      Evidence(
        skillId: skill,
        correct: correct,
        elapsedMs: 2400,
        at: t0.add(Duration(minutes: minute)),
        neededTeaching: help,
        isTransfer: transfer,
        misconception: miss,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EvidenceStore.instance.clear();
  });

  group('a child is remembered', () {
    test('what was recorded comes back', () async {
      final store = EvidenceStore.instance;
      for (var i = 0; i < 5; i++) {
        await store.add(ev('letter.shape', minute: i));
      }

      // Drop the cache the way a relaunch would.
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('primar_evidence_v1');
      expect(stored, isNotNull, reason: 'nothing reached disk at all');
      expect((jsonDecode(stored!) as List), hasLength(5));
    });

    test('a reloaded log rebuilds the same learner', () async {
      final store = EvidenceStore.instance;
      final log = [
        for (var i = 0; i < 8; i++) ev('letter.shape', minute: i),
        ev('letter.shape', transfer: true, minute: 9),
      ];
      for (final e in log) {
        await store.add(e);
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final before = learnerFrom(log).stateOf('letter.shape');
      expect(before.state, MasteryState.mastered);

      // A cold start: drop the cache so the next read really hits storage.
      store.resetCache();

      final after = (await store.learner()).stateOf('letter.shape');
      expect(after.state, before.state,
          reason: 'a child who had mastered this came back not having');
      expect(after.attempts, before.attempts);
      expect(after.transferTested, isTrue);
    });

    test('misconceptions survive the restart', () async {
      // The pattern that drives the repair intervention is the single most
      // expensive thing to lose: it takes three misses to establish and would
      // have to be re-earned every session.
      final store = EvidenceStore.instance;
      for (var i = 0; i < 4; i++) {
        await store.add(ev('letter.sound',
            correct: false, miss: Misconception.letterReversal, minute: i));
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));

      store.resetCache();

      final reloaded = await store.load();
      expect(learnerFrom(reloaded).stateOf('letter.sound').dominantMisconception,
          Misconception.letterReversal);
    });
  });

  group('the log stays bounded without losing what matters', () {
    test('a heavy session is trimmed per skill, keeping the newest', () async {
      final store = EvidenceStore.instance;
      for (var i = 0; i < 120; i++) {
        await store.add(ev('letter.shape', minute: i));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final log = await store.load();
      final mine = log.where((e) => e.skillId == 'letter.shape').toList();
      expect(mine.length, lessThanOrEqualTo(40));
      // The newest must be the ones kept — the estimator reads the recent
      // window, so trimming from the wrong end would erase the present.
      expect(mine.last.at, t0.add(const Duration(minutes: 119)));
    });

    test('a skill untouched for months is not evicted by a busy one', () async {
      // A global cap would quietly delete the mastered skill whose review is
      // most valuable, because it is the one nobody has practised lately.
      final store = EvidenceStore.instance;
      await store.add(ev('decode.read', minute: 0));
      for (var i = 0; i < 200; i++) {
        await store.add(ev('letter.shape', minute: i + 1));
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final log = await store.load();
      expect(log.where((e) => e.skillId == 'decode.read'), hasLength(1),
          reason: 'the quiet skill was evicted by the busy one');
    });

    test('order is preserved after trimming', () async {
      final store = EvidenceStore.instance;
      for (var i = 0; i < 60; i++) {
        await store.add(ev('letter.shape', minute: i));
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final log = await store.load();
      for (var i = 1; i < log.length; i++) {
        expect(log[i].at.isBefore(log[i - 1].at), isFalse,
            reason: 'the log came back out of order, so "recent" is meaningless');
      }
    });
  });

  group('bad storage is survived, never fatal', () {
    test('unreadable data gives a fresh start rather than a crash', () async {
      SharedPreferences.setMockInitialValues({'primar_evidence_v1': '{{{ not json'});
      EvidenceStore.instance.resetCache();
      expect(await EvidenceStore.instance.load(), isEmpty);
    });

    test('one corrupt row does not cost the rest of the history', () async {
      final good = {
        's': 'letter.shape',
        'c': true,
        'ms': 1200,
        't': t0.toIso8601String(),
        'h': false,
        'm': 'unclear',
        'x': false,
      };
      SharedPreferences.setMockInitialValues({
        'primar_evidence_v1': jsonEncode([
          good,
          {'s': 'letter.shape', 't': 'not-a-date'},
          {'nonsense': true},
          good,
        ]),
      });
      EvidenceStore.instance.resetCache();
      final log = await EvidenceStore.instance.load();
      expect(log, hasLength(2), reason: 'good rows were thrown away with the bad');
    });

    test('an unknown misconception is read as unclear, not dropped', () async {
      // The attempt still happened. Only our reading of the mistake is lost,
      // and losing the whole row would corrupt the accuracy figures too.
      SharedPreferences.setMockInitialValues({
        'primar_evidence_v1': jsonEncode([
          {
            's': 'letter.shape',
            'c': false,
            'ms': 900,
            't': t0.toIso8601String(),
            'h': false,
            'm': 'somethingWeRenamedLater',
            'x': false,
          }
        ]),
      });
      EvidenceStore.instance.resetCache();
      final log = await EvidenceStore.instance.load();
      expect(log, hasLength(1));
      expect(log.first.misconception, Misconception.unclear);
    });
  });
}
