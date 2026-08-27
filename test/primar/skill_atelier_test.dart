import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/skill_atelier.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';

void main() {
  test('authored atelier cards are bilingual', () {
    final card = atelierForSkill('pa.rhyme');
    expect(card, isNotNull);
    expect(card!.hookIn('en').toLowerCase(), contains('ending'));
    expect(card.hookIn('fr').isNotEmpty, isTrue);
    expect(card.didYouKnowIn('en').toLowerCase(), contains('cameroon'));
    expect(card.didYouKnowIn('fr').isNotEmpty, isTrue);
  });

  test('fallback atelier still personalises unknown skills', () {
    final card = atelierFor(
      skillId: 'future.skill',
      locale: 'en',
      subject: Subject.reading,
    );
    expect(card.hookIn('en'), contains('Explore'));
    expect(card.didYouKnowIn('en').toLowerCase(), contains('different'));
  });

  test('numeracy skill has atelier curiosity copy', () {
    final card = atelierFor(skillId: 'num.count', locale: 'en');
    expect(card.hookIn('en').toLowerCase(), contains('count'));
    expect(card.didYouKnowIn('fr').isNotEmpty, isTrue);
  });
}
