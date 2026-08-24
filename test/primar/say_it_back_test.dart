import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/services/say_it_back.dart';

/// Speaking practice is only safe if the matcher is genuinely forgiving.
///
/// The design rule is that speech can earn a reward and never cost one, and
/// these assert the half of that which is testable: a child who said the right
/// thing is accepted even when the recogniser mangles it.
void main() {
  group('a child who said it right is accepted', () {
    test('exact words match', () {
      expect(SayItBack.matches('cat', 'cat'), isTrue);
      expect(SayItBack.matches('CAT', 'cat'), isTrue);
      expect(SayItBack.matches('  cat  ', 'cat'), isTrue);
    });

    test('the word inside a sentence still counts', () {
      // Children answer in sentences. "It is a cat" must not fail.
      expect(SayItBack.matches('it is a cat', 'cat'), isTrue);
      expect(SayItBack.matches('the dog', 'dog'), isTrue);
    });

    test('a one-letter recogniser slip still counts', () {
      // The single most common failure on accented speech is one wrong
      // phoneme. Refusing these would fail correct children constantly.
      expect(SayItBack.matches('cot', 'cat'), isTrue);
      expect(SayItBack.matches('bag', 'bat'), isTrue);
      expect(SayItBack.matches('sunn', 'sun'), isTrue);
    });

    test('letter names are accepted for letter sounds', () {
      // Asked for "g", a recogniser returns "gee", "jee", sometimes "jay".
      // A child saying the letter correctly must not be told they are wrong.
      expect(SayItBack.matches('gee', 'g'), isTrue);
      expect(SayItBack.matches('bee', 'b'), isTrue);
      expect(SayItBack.matches('em', 'm'), isTrue);
    });

    test('punctuation and casing from the recogniser are ignored', () {
      expect(SayItBack.matches('Cat.', 'cat'), isTrue);
      expect(SayItBack.matches('"dog"', 'dog'), isTrue);
    });

    test('French accents survive normalisation', () {
      expect(SayItBack.matches('lune', 'lune'), isTrue);
      expect(SayItBack.matches('vélo', 'vélo'), isTrue);
    });
  });

  group('it does not accept absolutely everything', () {
    test('an unrelated word is not a match', () {
      // Being generous is not the same as being meaningless — a child who says
      // something else should simply not get the bonus.
      expect(SayItBack.matches('elephant', 'cat'), isFalse);
      expect(SayItBack.matches('banana', 'sun'), isFalse);
    });

    test('silence is not a match', () {
      expect(SayItBack.matches('', 'cat'), isFalse);
      expect(SayItBack.matches('   ', 'cat'), isFalse);
    });
  });

  group('results carry heard text without scoring', () {
    test('matched and heardOther are never session grades', () {
      final ok = SpeechResult.matched('cat');
      expect(ok.matched, isTrue);
      expect(ok.heard, 'cat');
      expect(ok.hasHeard, isTrue);

      final other = SpeechResult.heardOther('dog');
      expect(other.matched, isFalse);
      expect(other.heard, 'dog');
      expect(other.hasHeard, isTrue);

      expect(SpeechResult.notHeard.matched, isFalse);
      expect(SpeechResult.notHeard.hasHeard, isFalse);
    });
  });
}
