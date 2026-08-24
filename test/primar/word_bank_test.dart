import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/literacy.dart';
import 'package:prepskul/features/primar/domain/representation.dart';
import 'package:prepskul/features/primar/domain/skill.dart';
import 'package:prepskul/features/primar/domain/word_bank.dart';
import 'package:prepskul/features/primar/presentation/word_picture.dart';

/// The word bank is the one place a child's own world reaches them.
///
/// It is also the easiest thing to break silently: a word with no drawing is a
/// blank tile, and a word that cannot be sounded out is a reading question a
/// child can only guess at. Both look fine in code review.
void main() {
  group('every word in the bank can be drawn', () {
    test('no entry is missing its picture', () {
      for (final w in wordBank) {
        expect(WordPicture.canDraw(w.word), isTrue,
            reason: '"${w.word}" is in the bank with no drawing behind it, '
                'so it would render as an empty placeholder');
      }
    });

    test('nothing drawable is stranded outside the bank', () {
      // A drawing nobody can reach is dead weight, and usually means a word was
      // added to one place and forgotten in the other.
      final banked = wordBank.map((w) => WordPicture.keyFor(w.word)).toSet();
      final orphans = WordPicture.drawable.difference(banked);
      expect(orphans, isEmpty, reason: 'drawn but unreachable: $orphans');
    });

    test('a shared drawing serves both languages', () {
      // One mango, two names. The alternative is a second painter kept
      // looking identical to the first by hand, which it never stays.
      expect(WordPicture.keyFor('mangue'), 'mango');
      expect(WordPicture.canDraw('mangue'), isTrue);
    });
  });

  group('reading and picturing are different constraints', () {
    test('every readable word is decodable', () {
      for (final w in readableWords('en')) {
        final entry = wordBank.firstWhere((e) => e.word == w && e.locale == 'en');
        expect(entry.decodable, isTrue,
            reason: '"$w" is offered as a word to read but cannot be sounded out');
      }
    });

    test('the picture set is genuinely wider than the readable set', () {
      // This is the whole point of separating them. Conflating the two kept
      // mango, plantain and drum out of the app entirely, because they cannot
      // be spelled by a beginner — even though a child can obviously look at a
      // mango and hear what it starts with.
      expect(picturableWords('en').length, greaterThan(readableWords('en').length));
      expect(picturableWords('en'), contains('mango'));
      expect(readableWords('en'), isNot(contains('mango')));
    });

    test('reading items only ever offer decodable words', () {
      final decodable = readableWords('en').toSet();
      for (var i = 0; i < 300; i++) {
        final item = generateItemForSkill('decode.read', Random(i * 11), index: i);
        for (final f in item.options.whereType<WordFigure>()) {
          expect(decodable, contains(f.word),
              reason: '"${f.word}" cannot be sounded out but was offered as a '
                  'word to read');
        }
      }
    });
  });

  group('built from here, not localised into here', () {
    test('the local words come first', () {
      final ordered = wordsFor('en');
      final firstGlobal = ordered.indexWhere((w) => !w.isLocal);
      final lastLocal = ordered.lastIndexWhere((w) => w.isLocal);
      expect(lastLocal, lessThan(firstGlobal),
          reason: 'local and global words are interleaved, so a child meets '
              'their own world only by chance');
    });

    test('there are real local words, not one token gesture', () {
      final local = wordBank.where((w) => w.regions.contains(regionCameroon));
      expect(local.length, greaterThanOrEqualTo(8),
          reason: 'a handful of local nouns bolted onto a foreign list is '
              'exactly what this exists to avoid');
    });

    test('nothing is withheld from another region', () {
      // Regional tagging orders, it never filters. A child in Nairobi should
      // still meet a mango; only one of them should meet it constantly.
      final everywhere = wordsFor('en', region: 'KE').map((w) => w.word).toSet();
      final here = wordsFor('en', region: regionCameroon).map((w) => w.word).toSet();
      expect(everywhere, here);
    });

    test('French has its own entries rather than translated English', () {
      final fr = wordBank.where((w) => w.locale == 'fr').toList();
      expect(fr.length, greaterThanOrEqualTo(30),
          reason: 'Francophone Cameroon is half the market — thirteen words '
              'was a seventh of English');
      for (final w in fr) {
        expect(WordPicture.canDraw(w.word), isTrue);
      }
    });

    test('French readable set is wider than before', () {
      expect(readableWords('fr').length, greaterThanOrEqualTo(30));
      expect(picturableWords('fr').length, greaterThan(readableWords('fr').length));
    });

    test('Cameroon French words are drawable and honest', () {
      for (final w in ['moto', 'riz', 'arbre', 'gobelet', 'eau', 'feu']) {
        expect(WordPicture.canDraw(w), isTrue, reason: '"$w" has no drawing');
      }
      expect(wordBank.firstWhere((e) => e.word == 'moto').decodable, isTrue);
      expect(wordBank.firstWhere((e) => e.word == 'riz').decodable, isTrue);
      expect(wordBank.firstWhere((e) => e.word == 'eau').decodable, isFalse);
      expect(wordBank.firstWhere((e) => e.word == 'arbre').decodable, isFalse);
      expect(wordBank.firstWhere((e) => e.word == 'feu').decodable, isTrue);
    });

    test('French rhyme rung produces real questions', () {
      final real = [
        for (var i = 0; i < 100; i++)
          generateItemForSkill('pa.rhyme', Random(i * 17 + 3),
              index: i, locale: 'fr', support: Support.full),
      ].where((i) => i.id.contains('rhyme'));
      expect(real.length, greaterThan(80),
          reason: 'French pa.rhyme fell back too often');
    });

    test('French syllable rung produces real questions', () {
      final real = [
        for (var i = 0; i < 100; i++)
          generateItemForSkill('pa.syllable', Random(i * 17 + 2),
              index: i, locale: 'fr', support: Support.full),
      ].where((i) => i.id.contains('syllable'));
      expect(real.length, greaterThan(80),
          reason: 'French pa.syllable fell back too often');
    });
  });

  group('the pictures reach the child', () {
    test('local words actually appear in generated items', () {
      // A bank entry that no generator ever selects has changed nothing.
      final seen = <String>{};
      for (final skill in teachableSkills) {
        for (var i = 0; i < 400; i++) {
          final item = generateItemForSkill(skill.id, Random(i * 7), index: i);
          for (final f in [...item.prompt, ...item.options].whereType<PictureFigure>()) {
            seen.add(f.word);
          }
        }
      }
      expect(seen.intersection({'mango', 'plantain', 'drum', 'hen', 'tin', 'pan'}),
          isNotEmpty,
          reason: 'not one local word reached a child: $seen');
    });
  });
}
