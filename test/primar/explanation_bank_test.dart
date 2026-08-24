import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/misconception.dart';
import 'package:prepskul/features/primar/services/explanation_bank.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The adaptive teaching must survive the network being gone.
///
/// The whole point of banking model-authored explanations is that the model
/// authors once and the device replays forever. These assert the replay half —
/// the part a child in a shutdown actually depends on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ExplanationBank.instance.clear();
  });

  test('with nothing banked, it returns null rather than blocking', () async {
    // The built-in teaching is already a complete lesson. A missing variant is
    // an absent bonus, never a gap.
    final v = await ExplanationBank.instance
        .variantFor(Misconception.letterReversal, attempt: 0);
    expect(v, isNull);
  });

  test('a banked concept is replayed with no network at all', () async {
    await ExplanationBank.instance.seed(Misconception.letterReversal, [
      'Make two fists and lift your thumbs up.',
      'They are like a chicken and its water reflection.',
    ]);

    final v = await ExplanationBank.instance
        .variantFor(Misconception.letterReversal, attempt: 0);
    expect(v, 'Make two fists and lift your thumbs up.');
  });

  test('repeated misses hear a different angle each time', () async {
    // Saying the same words a fourth time is insistence, not teaching.
    await ExplanationBank.instance.seed(Misconception.offByOne, ['a', 'b', 'c']);

    final heard = <String?>[];
    for (var i = 0; i < 3; i++) {
      heard.add(await ExplanationBank.instance
          .variantFor(Misconception.offByOne, attempt: i));
    }
    expect(heard, ['a', 'b', 'c']);
  });

  test('it wraps rather than running out', () async {
    await ExplanationBank.instance.seed(Misconception.offByOne, ['a', 'b']);
    expect(
      await ExplanationBank.instance.variantFor(Misconception.offByOne, attempt: 5),
      isNotNull,
    );
  });

  test('locales are banked separately', () async {
    await ExplanationBank.instance.seed(Misconception.letterSound, ['english line']);
    await ExplanationBank.instance
        .seed(Misconception.letterSound, ['ligne française'], locale: 'fr');

    expect(
      await ExplanationBank.instance
          .variantFor(Misconception.letterSound, attempt: 0, locale: 'fr'),
      'ligne française',
    );
    expect(
      await ExplanationBank.instance
          .variantFor(Misconception.letterSound, attempt: 0),
      'english line',
    );
  });

  test('an unclassifiable miss has no concept to fetch', () async {
    expect(ExplanationBank.conceptFor(Misconception.unclear), isNull);
  });

  test('every classifiable misconception maps to a concept the server knows', () {
    // A missing mapping means a child who keeps making that mistake silently
    // never gets a fresh explanation.
    const serverKnows = {
      'letter-reversal', 'letter-shape', 'letter-sound', 'off-by-one',
      'operand-echo', 'wrong-operation', 'counting-unstable', 'shape-composition',
    };
    for (final m in Misconception.values) {
      if (m == Misconception.unclear) continue;
      final concept = ExplanationBank.conceptFor(m);
      expect(concept, isNotNull, reason: '${m.name} has no concept mapping');
      expect(serverKnows, contains(concept),
          reason: '${m.name} maps to "$concept", which the server rejects');
    }
  });

  test('corrupt storage is survived, not fatal', () async {
    SharedPreferences.setMockInitialValues({'primar.explanations': 'not json'});
    final v = await ExplanationBank.instance
        .variantFor(Misconception.letterReversal, attempt: 0);
    expect(v, isNull);
  });
}
