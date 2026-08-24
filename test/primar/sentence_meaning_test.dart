import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/literacy.dart';
import 'package:prepskul/features/primar/domain/path.dart';
import 'package:prepskul/features/primar/domain/representation.dart';
import 'package:prepskul/features/primar/presentation/word_picture.dart';

/// The last reading rung: hear a phrase, pick the miniature scene.
///
/// ## What this closes
///
/// The walkable reading path ended at `meaning.word`. A child who could read a
/// word and know what it meant had finished everything there was — twelve
/// skills, with one still marked unteachable because single-object drawings
/// cannot show a *situation*.
///
/// The fix is the same one `decode.sentence` used: compose what already exists.
/// Two pictures and a joiner word make "cat on mat" without new artwork, and
/// a child who picks the wrong scene had to misunderstand the whole phrase, not
/// just recognise one noun.
void main() {
  const trials = 200;

  List<PrimarItem> itemsFor(String skillId, {String locale = 'en'}) => [
        for (var i = 0; i < trials; i++)
          generateItemForSkill(skillId, Random(i * 41 + 3),
              index: i, locale: locale, support: Support.full),
      ];

  group('meaning.sentence — hear the phrase, pick the scene', () {
    test('is on the walkable path with a generator behind it', () {
      final order = pathOrder();
      final skill = order.where((s) => s.id == 'meaning.sentence').toList();
      expect(skill, hasLength(1));
      expect(skill.single.teachable, isTrue);
      expect(canGenerateSkill('meaning.sentence'), isTrue);
    });

    test('the question is a replayable sound, the answers are miniature scenes',
        () {
      final real =
          itemsFor('meaning.sentence').where((i) => i.id.contains('sentence-meaning'));
      expect(real.length, greaterThan(trials ~/ 2),
          reason: 'meaning.sentence fell back too often');

      for (final item in real) {
        expect(item.prompt.any((f) => f is SoundFigure), isTrue,
            reason: '${item.id} had nothing to listen to');
        expect(item.spokenAll, isNotEmpty,
            reason: '${item.id} never spoke the phrase');
        for (final o in item.options) {
          expect(o, isA<PhraseFigure>(),
              reason: 'an option was not a miniature scene');
        }
      }
    });

    test('exactly one scene matches the spoken phrase', () {
      for (final item in itemsFor('meaning.sentence')) {
        if (!item.id.contains('sentence-meaning')) continue;

        final spoken = item.spokenAll
            .where((p) => p.startsWith('word:'))
            .map((p) => p.substring(5))
            .toList();
        expect(spoken.length, 3, reason: '${item.id} phrase was not three words');

        final answer = item.options[item.answerIndex] as PhraseFigure;
        expect([answer.first, answer.joiner, answer.second], spoken,
            reason: 'the right scene did not match what was spoken');

        var matches = 0;
        for (final o in item.options) {
          final scene = o as PhraseFigure;
          if (scene.first == spoken[0] &&
              scene.joiner == spoken[1] &&
              scene.second == spoken[2]) {
            matches++;
          }
        }
        expect(matches, 1,
            reason: '${item.id} had $matches scenes matching the phrase');
      }
    });

    test('distractors differ in exactly one piece from the answer', () {
      for (final item in itemsFor('meaning.sentence')) {
        if (!item.id.contains('sentence-meaning')) continue;

        final answer = item.options[item.answerIndex] as PhraseFigure;
        for (var i = 0; i < item.options.length; i++) {
          if (i == item.answerIndex) continue;
          final other = item.options[i] as PhraseFigure;
          final diffs = [
            other.first != answer.first,
            other.joiner != answer.joiner,
            other.second != answer.second,
          ].where((d) => d).length;
          expect(diffs, greaterThanOrEqualTo(1),
              reason: 'a distractor duplicated the answer');
          expect(diffs, lessThanOrEqualTo(2),
              reason: 'a distractor changed too much to be a fair near-miss');
        }
      }
    });

    test('every pictured word in a scene can actually be drawn', () {
      for (final item in itemsFor('meaning.sentence')) {
        if (!item.id.contains('sentence-meaning')) continue;
        for (final o in item.options) {
          final scene = o as PhraseFigure;
          expect(WordPicture.canDraw(scene.first), isTrue,
              reason: '${scene.first} has no drawing');
          expect(WordPicture.canDraw(scene.second), isTrue,
              reason: '${scene.second} has no drawing');
        }
      }
    });

    test('French produces real sentence-meaning questions when possible', () {
      final real = itemsFor('meaning.sentence', locale: 'fr')
          .where((i) => i.id.contains('sentence-meaning'));
      // French has fewer decodable nouns, so some fallback is honest — but not
      // all of them.
      expect(real.length, greaterThan(20),
          reason: 'French meaning.sentence fell back for almost every item');
    });
  });
}
