import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/literacy.dart';
import 'package:prepskul/features/primar/domain/path.dart';
import 'package:prepskul/features/primar/domain/representation.dart';
import 'package:prepskul/features/primar/domain/skill.dart';
import 'package:prepskul/features/primar/domain/word_bank.dart';
import 'package:prepskul/features/primar/presentation/word_picture.dart';
import 'package:prepskul/features/primar/services/primar_voice.dart';

/// The two oral rungs: blending sounds into a word, and hearing what a word
/// ends with.
///
/// ## Why these two first
///
/// The walkable path was seven skills. Six sat in the graph unteachable, and
/// these are the two the evidence base is loudest about: a child who cannot
/// blend orally does not decode, whatever else they know about letters. They
/// also come *before* letters, so they are the rungs a child with no schooling
/// at all can actually start on.
///
/// ## The rule both must obey
///
/// No letter appears in the question. That is what makes them phonological
/// awareness rather than early decoding, and it is the thing easiest to break
/// by accident later — a distractor drawn as a letter would quietly turn the
/// oral rung into a reading one and the graph would still claim otherwise.
void main() {
  const trials = 200;

  List<PrimarItem> itemsFor(String skillId) => [
        for (var i = 0; i < trials; i++)
          generateItemForSkill(skillId, Random(i * 31 + 7),
              index: i, support: Support.full),
      ];

  group('pa.blend — pushing sounds together', () {
    test('the question is sounds and pictures, never letters', () {
      for (final item in itemsFor('pa.blend')) {
        for (final f in item.prompt) {
          expect(f, isA<SoundFigure>(),
              reason: 'the prompt showed something that is not a sound');
        }
        for (final o in item.options) {
          expect(o, isA<PictureFigure>(),
              reason: 'an option was not a picture — a letter or word here '
                  'turns an oral rung into a reading one');
        }
      }
    });

    test('the sounds played are the sounds of the answer, in order', () {
      for (final item in itemsFor('pa.blend')) {
        final answer = item.options[item.answerIndex] as PictureFigure;
        final expected = [
          for (final letter in answer.word.split(''))
            'sound:${soundForLetter(letter)}',
        ];
        expect(item.spokenAll, expected,
            reason: 'the sounds spoken do not build ${answer.word}');
      }
    });

    test('every option can actually be drawn', () {
      // A blank tile is not a distractor, it is a missing question.
      for (final item in itemsFor('pa.blend')) {
        for (final o in item.options) {
          final word = (o as PictureFigure).word;
          expect(WordPicture.keyFor(word), isNotNull,
              reason: '$word has no drawing');
        }
      }
    });

    test('exactly one option is right', () {
      for (final item in itemsFor('pa.blend')) {
        final answer = (item.options[item.answerIndex] as PictureFigure).word;
        final same = item.options
            .where((o) => (o as PictureFigure).word == answer)
            .length;
        expect(same, 1, reason: '$answer appears $same times among the options');
        expect(item.options.length, greaterThanOrEqualTo(2));
      }
    });
  });

  group('pa.segment — the sound a word ends with', () {
    test('the words used are decodable, so the last letter is the last sound',
        () {
      // The bug this caught: grouping every drawable word by its final letter
      // paired "kite" with "vase". Both end in a silent e, which is not a
      // sound at all — so a rung labelled "hears the sound a word ends with"
      // was matching spelling and calling it listening.
      //
      // Only decodable words have the property that every letter makes the
      // sound we teach for it, which is what makes final-letter grouping
      // sound grouping.
      for (final item in itemsFor('pa.segment')) {
        for (final f in [...item.prompt, ...item.options]) {
          if (f is! PictureFigure) continue;
          expect(readableWords('en'), contains(f.word),
              reason: '"${f.word}" is not decodable, so its last letter is '
                  'not reliably its last sound');
        }
      }
    });

    test('the answer really does end like the cue, and the others do not', () {
      for (final item in itemsFor('pa.segment')) {
        final cue = item.prompt.whereType<PictureFigure>().first.word;
        final answer = (item.options[item.answerIndex] as PictureFigure).word;
        final end = cue[cue.length - 1];

        expect(answer[answer.length - 1], end,
            reason: '$answer does not end like $cue');
        expect(answer, isNot(cue),
            reason: 'the cue was offered as its own answer');

        for (var i = 0; i < item.options.length; i++) {
          if (i == item.answerIndex) continue;
          final other = (item.options[i] as PictureFigure).word;
          expect(other[other.length - 1], isNot(end),
              reason: '$other also ends in $end — two options are correct');
        }
      }
    });

    test('the cue is shown as well as spoken', () {
      // Same rule as every other listening rung: a child who missed the audio
      // must still be able to see what is being asked about.
      for (final item in itemsFor('pa.segment')) {
        expect(item.prompt.whereType<PictureFigure>(), isNotEmpty);
        expect(item.prompt.whereType<SoundFigure>(), isNotEmpty);
      }
    });
  });

  group('both rungs', () {
    test('every voice line they ask for exists', () {
      // A missing line is a question asked in silence, which for a
      // pre-literate child is no question at all.
      for (final skill in ['pa.blend', 'pa.segment']) {
        for (final item in itemsFor(skill)) {
          for (final id in [
            if (item.spoken != null) item.spoken!,
            ...item.spokenAll,
            ...item.teach,
          ]) {
            expect(VoiceLines.byId(id), isNotNull,
                reason: '$skill asks for the line "$id" and nothing says it');
          }
        }
      }
    });

    test('they are on the path, before the letter rungs', () {
      final order = pathOrder().map((s) => s.id).toList();

      expect(order, contains('pa.blend'));
      expect(order, contains('pa.segment'));

      // Blending is a prerequisite of segmenting, and both are hearing skills.
      // If either drifted after decoding the path would be teaching a child to
      // read words before it taught them to hear them.
      expect(order.indexOf('pa.blend'), lessThan(order.indexOf('pa.segment')));
      expect(order.indexOf('pa.segment'), lessThan(order.indexOf('decode.read')));
    });

    test('the path is longer than it was', () {
      // It was seven. Naming the old number keeps this honest if someone
      // later marks a skill teachable without a generator behind it.
      expect(pathOrder().length, greaterThan(7));
      for (final skill in pathOrder()) {
        expect(canGenerateSkill(skill.id), isTrue,
            reason: '${skill.id} is on the path with no generator behind it');
      }
    });
  });

  group('decode.sentence — reading several words together', () {
    test('the words to arrange are written words, and there are three', () {
      for (final item in itemsFor('decode.sentence')) {
        expect(item.interaction, Interaction.order);
        expect(item.orderItems.length, 3);
        for (final f in item.orderItems) {
          expect(f, isA<WordFigure>(),
              reason: 'a phrase tile was not a written word, so the rung '
                  'could be passed without reading');
        }
      }
    });

    test('the tiles carry no pictures', () {
      // Found by looking at it: the tiles were drawing each word's picture
      // above the letters, so "cat in tin" could be ordered by recognising a
      // cat and a tin. The child never had to read anything, and the graph
      // still recorded it as reading several words together.
      for (final item in itemsFor('decode.sentence')) {
        for (final f in item.orderItems) {
          expect((f as WordFigure).withPicture, isFalse,
              reason: '"${f.word}" is showing its picture, which identifies '
                  'the tile without reading it');
        }
      }
    });

    test('the solution really does spell the phrase that is spoken', () {
      for (final item in itemsFor('decode.sentence')) {
        // orderSolution[i] is where the i-th word of the phrase currently sits.
        final assembled = [
          for (final at in item.orderSolution)
            (item.orderItems[at] as WordFigure).word,
        ];
        final spoken =
            item.spokenAll.map((id) => id.substring('word:'.length)).toList();

        expect(assembled, spoken,
            reason: 'solving the row gives "${assembled.join(' ')}" but the '
                'child heard "${spoken.join(' ')}"');
      }
    });

    test('it never opens already solved', () {
      // A row that arrives in order is answered by doing nothing, which
      // measures patience rather than reading.
      var alreadySorted = 0;
      for (final item in itemsFor('decode.sentence')) {
        final sorted = List<int>.generate(item.orderSolution.length, (i) => i);
        if (item.orderSolution.toString() == sorted.toString()) alreadySorted++;
      }
      expect(alreadySorted, 0);
    });

    test('the middle word is a joiner and the ends are things', () {
      for (final item in itemsFor('decode.sentence')) {
        final phrase = [
          for (final at in item.orderSolution)
            (item.orderItems[at] as WordFigure).word,
        ];
        expect(phraseJoiners['en'], contains(phrase[1]),
            reason: '"${phrase[1]}" is not a joiner');
        expect(phrase[0], isNot(phrase[2]),
            reason: 'the same word appears at both ends');
        // Both ends must be readable, or the child is asked to decode
        // something the app never taught them to.
        expect(readableWords('en'), contains(phrase[0]));
        expect(readableWords('en'), contains(phrase[2]));
      }
    });

    test('every line the phrase asks for exists', () {
      for (final item in itemsFor('decode.sentence')) {
        for (final id in [...item.spokenAll, ...item.teach]) {
          expect(VoiceLines.byId(id), isNotNull,
              reason: 'the phrase rung asks for "$id" and nothing says it');
        }
      }
    });
  });

  group('pa.rhyme — hearing when two words rhyme', () {
    test('the answer rhymes with the cue and nothing else does', () {
      for (final item in itemsFor('pa.rhyme')) {
        final cue = item.prompt.whereType<PictureFigure>().first.word;
        final answer = (item.options[item.answerIndex] as PictureFigure).word;
        final rime = cue.substring(cue.length - 2);

        expect(answer.substring(answer.length - 2), rime,
            reason: '$answer does not rhyme with $cue');
        expect(answer, isNot(cue), reason: 'the cue was its own answer');

        for (var i = 0; i < item.options.length; i++) {
          if (i == item.answerIndex) continue;
          final other = (item.options[i] as PictureFigure).word;
          expect(other.substring(other.length - 2), isNot(rime),
              reason: '$other also rhymes with $cue — two answers are right');
        }
      }
    });

    test('only decodable words are used', () {
      // Same reason as the end-sound rung. Matching the written rime is only
      // matching the *sound* rime when every letter makes its taught sound;
      // otherwise "kite" and "vase" would come out as a rhyming pair.
      for (final item in itemsFor('pa.rhyme')) {
        for (final f in [...item.prompt, ...item.options]) {
          if (f is! PictureFigure) continue;
          expect(readableWords('en'), contains(f.word));
        }
      }
    });

    test('it has no prerequisites, so a child can start there', () {
      // Rhyme is the earliest phonological skill there is — it must sit at the
      // root or the app cannot meet a child who has nothing else yet.
      expect(skillsById['pa.rhyme']!.prerequisites, isEmpty);
      expect(pathOrder().first.id, 'pa.rhyme');
    });
  });

  group('pa.syllable — counting the beats', () {
    test('the answer is the real count, taken from the written-down table', () {
      for (final item in itemsFor('pa.syllable')) {
        final word = item.prompt.whereType<PictureFigure>().first.word;
        final answer = item.options[item.answerIndex] as QuantityFigure;
        expect(syllablesOf[word], isNotNull,
            reason: '"$word" is used by the syllable rung but has no count');
        expect(answer.count, syllablesOf[word],
            reason: '"$word" has ${syllablesOf[word]} beats, not ${answer.count}');
      }
    });

    test('the counts asked for are spread, not mostly one', () {
      // The bug this rung was held back for. The bank is thirty-one one-beat
      // words against seven longer ones, so picking a word first and asking
      // its count would make "one" the answer nearly every time — passable by
      // a child who never listened. The generator picks the count first.
      final seen = <int, int>{};
      for (final item in itemsFor('pa.syllable')) {
        final n = (item.options[item.answerIndex] as QuantityFigure).count;
        seen[n] = (seen[n] ?? 0) + 1;
      }
      expect(seen.keys.length, greaterThanOrEqualTo(3),
          reason: 'only ${seen.keys.toList()} ever came up as an answer');

      final most = seen.values.reduce((a, b) => a > b ? a : b);
      expect(most / trials, lessThan(0.55),
          reason: 'one count is the answer ${(most / trials * 100).round()}% '
              'of the time, so guessing it beats listening');
    });

    test('the options are dots, never numerals', () {
      // A child at this rung is pre-literate by definition. Offering "3" asks
      // them to read a digit, which is a different skill and not one this rung
      // is entitled to require.
      for (final item in itemsFor('pa.syllable')) {
        for (final o in item.options) {
          expect(o, isA<QuantityFigure>());
        }
      }
    });
  });

  group('French gets its endings from the table, not the spelling', () {
    List<PrimarItem> frItems(String skillId) => [
          for (var i = 0; i < trials; i++)
            generateItemForSkill(skillId, Random(i * 13 + 5),
                index: i, locale: 'fr', support: Support.full),
        ];

    test('French rhyme actually produces rhyme questions', () {
      // Before the table it produced none at all. Every French learner was
      // silently handed the initial-sound form instead, because the letter
      // rule finds zero rhyming pairs in French — "nid" and "lit" rhyme and
      // their written endings do not match.
      final real = frItems('pa.rhyme').where((i) => i.id.contains('rhyme'));
      expect(real.length, trials,
          reason: 'French rhyme fell back for ${trials - real.length} of '
              '$trials items');
    });

    test('French rhymes match by sound', () {
      for (final item in frItems('pa.rhyme')) {
        if (!item.id.contains('rhyme')) continue;
        final cue = item.prompt.whereType<PictureFigure>().first.word;
        final answer = (item.options[item.answerIndex] as PictureFigure).word;

        expect(frenchSounds[cue], isNotNull);
        expect(frenchSounds[answer]!.rime, frenchSounds[cue]!.rime,
            reason: '"$answer" does not rhyme with "$cue" in French');

        for (var i = 0; i < item.options.length; i++) {
          if (i == item.answerIndex) continue;
          final other = (item.options[i] as PictureFigure).word;
          expect(frenchSounds[other]!.rime, isNot(frenchSounds[cue]!.rime),
              reason: '"$other" also rhymes with "$cue"');
        }
      }
    });

    test('French end-sound matches by sound', () {
      for (final item in frItems('pa.segment')) {
        if (!item.id.contains('endsound')) continue;
        final cue = item.prompt.whereType<PictureFigure>().first.word;
        final answer = (item.options[item.answerIndex] as PictureFigure).word;
        expect(frenchSounds[answer]!.last, frenchSounds[cue]!.last,
            reason: '"$answer" does not end like "$cue" in French');
      }
    });

    test('every French picture word has an entry in the table', () {
      // The table is opt-in: a word without an entry is skipped by the rhyme
      // and end-sound rungs rather than mishandled. That is the safe failure,
      // and also a silent one — a word added to the bank and forgotten here
      // just quietly narrows both rungs. This is the reminder.
      for (final w in picturableWords('fr')) {
        expect(frenchSounds[w], isNotNull,
            reason: '"$w" is in the French bank with no ending recorded, so '
                'the rhyme and end-sound rungs will skip it');
        expect(WordPicture.canDraw(w), isTrue,
            reason: '"$w" has no drawing');
      }
    });

    test('the written ending would have got it wrong', () {
      // The point of the table, stated as a fact about the data rather than a
      // claim in a comment: there exist French pairs that rhyme by sound and
      // disagree by spelling. If that ever stops being true the table has
      // become redundant and can go.
      var soundAgreeSpellingDisagree = 0;
      final words = frenchSounds.keys.toList();
      for (final a in words) {
        for (final b in words) {
          if (a == b) continue;
          final sameSound = frenchSounds[a]!.rime == frenchSounds[b]!.rime;
          final sameSpelling = a.length >= 2 &&
              b.length >= 2 &&
              a.substring(a.length - 2) == b.substring(b.length - 2);
          if (sameSound && !sameSpelling) soundAgreeSpellingDisagree++;
        }
      }
      expect(soundAgreeSpellingDisagree, greaterThan(0),
          reason: 'no French pair rhymes while spelling differently, so the '
              'letter rule would have been fine and this table is dead weight');
    });
  });

  test('no prompt row can overflow a narrow phone', () {
    // The bug: prompt sizing counted figures and assumed each cost the same.
    // A listen button draws at 1.5x, so blending — whose prompt *is* a row of
    // sounds — put 392 logical pixels into a 360 pixel row and overflowed by
    // 32. Nothing had four listen buttons before that rung existed.
    //
    // 360dp is the width of the cheap Androids this is built for, minus the
    // padding the sheet and screen already take.
    const narrow = 320.0;

    for (final skill in pathOrder()) {
      for (final item in itemsFor(skill.id)) {
        var units = 0.0;
        for (final f in item.prompt) {
          units += f is SoundFigure ? 1.5 : 1.0;
        }
        if (item.options.isNotEmpty) units += 1;
        if (units == 0) continue;

        // The floor the sizing rule clamps to. Below it the FittedBox takes
        // over, which is a backstop and not a plan.
        final size = (narrow / units).clamp(34.0, 56.0);
        expect(units * size, lessThanOrEqualTo(narrow + 0.01),
            reason: '${skill.id} needs ${(units * size).toStringAsFixed(0)}px '
                'of a ${narrow.toStringAsFixed(0)}px row');
      }
    }
  });

  test('a word being read is never shown with its own picture', () {
    // The same defect lived in decode.read, which is the rung the whole
    // product is named after: four option tiles each drew their own picture,
    // so a child heard "bed", found the bed drawing and tapped it without
    // decoding a letter. Support fading did not help — the pictures were on
    // the options, not the prompt.
    for (final skill in ['decode.read', 'decode.sentence']) {
      for (final item in itemsFor(skill)) {
        for (final f in [...item.options, ...item.orderItems]) {
          if (f is WordFigure) {
            expect(f.withPicture, isFalse,
                reason: '$skill offers "${f.word}" with its picture attached');
          }
        }
      }
    }
  });

  test('the word bank can still feed both rungs', () {
    // Both generators fall back to another form when the bank is too thin.
    // A silent fallback is the right behaviour at runtime and the wrong thing
    // to discover in production, so this asserts the bank is actually rich
    // enough that the fallback is not the normal case.
    final blends = itemsFor('pa.blend')
        .where((i) => i.id.contains('blend'))
        .length;
    final ends = itemsFor('pa.segment')
        .where((i) => i.id.contains('endsound'))
        .length;

    expect(blends, trials, reason: 'blend fell back to another form');
    expect(ends, trials, reason: 'end-sound fell back to another form');
    expect(picturableWords('en').length, greaterThan(20));
  });
}
