import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/presentation/spell_row.dart';
import 'package:prepskul/features/primar/services/primar_voice.dart';

/// Building a word out of its sounds — the interaction, on its own.
///
/// The session test proves a spelling question *reaches* a child. This proves
/// the thing they reach actually works: that the right word is graded right,
/// the wrong one is graded wrong, and a child who taps a letter they did not
/// mean can take it back rather than being stuck with it.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  const silenced = <String>[
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers',
    'flutter_tts',
    'plugins.flutter.io/path_provider',
    'dev.fluttercommunity.plus/connectivity',
  ];

  setUp(() {
    for (final name in silenced) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => null,
      );
    }
    PrimarVoice.instance.setMuted(true);
  });

  tearDown(() {
    PrimarVoice.instance.setMuted(false);
    for (final name in silenced) {
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  /// "cat", with one decoy in the pool. The pool order is fixed so the taps
  /// below are readable rather than computed.
  const item = PrimarItem(
    id: 'spell-cat',
    level: 4,
    topicId: 'literacy_en',
    prompt: [PictureFigure('cat')],
    options: [],
    answerIndex: 0,
    spoken: 'word:cat',
    interaction: Interaction.spell,
    spellTarget: ['c', 'a', 't'],
    spellPool: ['t', 'c', 'p', 'a'],
  );

  Future<void> pumpRow(
    WidgetTester tester, {
    required void Function(bool) onSolved,
    VoidCallback? onMiss,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SpellRow(
            item: item,
            onSolved: onSolved,
            onMiss: onMiss ?? () {},
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  /// Taps the pool tile carrying [letter]. The pool tiles are the ones drawn
  /// after the slots, so they are found by position in the pool.
  Future<void> tapPool(WidgetTester tester, String letter) async {
    final i = item.spellPool.indexOf(letter);
    final tiles = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.behavior == HitTestBehavior.opaque,
    );
    // Slots come first in the tree, then the pool.
    await tester.tap(tiles.at(item.spellTarget.length + i));
    await tester.pump();
  }

  testWidgets('the right word is graded right', (tester) async {
    bool? result;
    await pumpRow(tester, onSolved: (c) => result = c);

    await tapPool(tester, 'c');
    await tapPool(tester, 'a');
    await tapPool(tester, 't');

    // The row holds briefly so the finished word is seen before the session
    // replaces it.
    await tester.pump(const Duration(milliseconds: 800));
    expect(result, isTrue);
  });

  testWidgets('a wrong word is graded wrong, not silently accepted',
      (tester) async {
    bool? result;
    var misses = 0;
    await pumpRow(tester, onSolved: (c) => result = c, onMiss: () => misses++);

    await tapPool(tester, 'c');
    await tapPool(tester, 't');
    await tapPool(tester, 'a');

    await tester.pump(const Duration(milliseconds: 800));
    expect(result, isFalse);
    // Two of the three letters landed somewhere the word does not have them,
    // and the tracker has to hear about it or the engine climbs on nothing.
    expect(misses, greaterThan(0));
  });

  testWidgets('a letter tapped by mistake can be taken back', (tester) async {
    bool? result;
    await pumpRow(tester, onSolved: (c) => result = c);

    await tapPool(tester, 't');

    // Tapping the last filled slot returns the letter to the pool. Without
    // this a single mis-tap costs the whole question, which on a cheap
    // touchscreen is a thing that happens for reasons that have nothing to do
    // with reading.
    final slots = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.behavior == HitTestBehavior.opaque,
    );
    await tester.tap(slots.at(0));
    await tester.pump();

    await tapPool(tester, 'c');
    await tapPool(tester, 'a');
    await tapPool(tester, 't');

    await tester.pump(const Duration(milliseconds: 800));
    expect(result, isTrue, reason: 'undo did not actually free the slot');
  });
}
