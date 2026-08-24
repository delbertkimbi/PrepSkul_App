import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/curriculum.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';

/// A curriculum that describes something the engine does not generate is worse
/// than no curriculum: it is a promise to a parent, a brief to a model, and a
/// label on a result screen, all of them wrong at once.
void main() {
  group('the curriculum covers the whole scale', () {
    test('every subject has all ten levels, in order', () {
      for (final subject in Subject.values) {
        final rows = curriculum[subject]!;
        expect(rows.length, 10, reason: '$subject is missing levels');
        for (var i = 0; i < rows.length; i++) {
          expect(rows[i].level, i + 1, reason: '$subject level ${i + 1} out of order');
        }
      }
    });

    test('every field is filled in', () {
      for (final subject in Subject.values) {
        for (final row in curriculum[subject]!) {
          expect(row.can, isNotEmpty, reason: '$subject L${row.level}');
          expect(row.taught, isNotEmpty, reason: '$subject L${row.level}');
          expect(row.evidence, isNotEmpty, reason: '$subject L${row.level}');
          expect(row.watchFor, isNotEmpty, reason: '$subject L${row.level}');
        }
      }
    });

    test('a level out of range still resolves', () {
      for (final subject in Subject.values) {
        expect(outcomeFor(subject, 0).level, 1);
        expect(outcomeFor(subject, 99).level, 10);
      }
    });
  });

  group('what it claims is what the engine does', () {
    /// The interactions a subject actually produces at a level.
    Set<Interaction> interactionsAt(Subject subject, int level) {
      final seen = <Interaction>{};
      for (var i = 0; i < 120; i++) {
        seen.add(generateForSubject(subject, level, Random(level * 31 + i), i).interaction);
      }
      return seen;
    }

    test('levels that promise a match board produce one', () {
      // "joins each group to its number" is a specific claim about a specific
      // screen. If the generator stops producing match boards there, the
      // sentence a parent reads becomes fiction.
      final row = outcomeFor(Subject.numeracy, 4);
      expect(row.evidence, contains('match board'));
      expect(interactionsAt(Subject.numeracy, 4), contains(Interaction.match));
    });

    test('levels that promise spelling produce spelling', () {
      final row = outcomeFor(Subject.reading, 8);
      expect(row.evidence, contains('spells'));
      expect(interactionsAt(Subject.reading, 8), contains(Interaction.spell));
    });

    test('the reading rung that promises a picture only ever uses picturable words', () {
      // The claim at level 9 is decoding *with meaning*, and meaning is carried
      // by the picture. A word with no picture there would silently turn the
      // rung back into shape-matching.
      for (var i = 0; i < 200; i++) {
        final item = generateForSubject(Subject.reading, 9, Random(i), i);
        for (final f in [...item.options, ...item.prompt]) {
          if (f is WordFigure) {
            expect(WordFigure(f.word).word, isNotEmpty);
          }
        }
      }
    });

    test('every level of every subject actually generates something', () {
      for (final subject in Subject.values) {
        for (var level = 1; level <= 10; level++) {
          final item = generateForSubject(subject, level, Random(level), 0);
          expect(item.topicId, subject.topicId,
              reason: '$subject L$level generated another subject topic');
          if (item.interaction == Interaction.choose) {
            expect(item.options, isNotEmpty, reason: '$subject L$level has no options');
          }
        }
      }
    });
  });

  group('how it reads', () {
    const deficit = [
      'cannot', 'unable', 'fails', 'behind', 'below average', 'poor', 'weak',
      'slow learner', 'struggl',
    ];

    test('every outcome is stated as something the child can do', () {
      for (final subject in Subject.values) {
        for (final row in curriculum[subject]!) {
          final text = row.can.toLowerCase();
          for (final word in deficit) {
            expect(text, isNot(contains(word)),
                reason: '$subject L${row.level} is written as a deficit: "${row.can}"');
          }
        }
      }
    });

    test('no level implies a school year', () {
      // A level is not a grade. The mismatch between the two is the premise of
      // the product, and mapping them back together would undo it.
      for (final subject in Subject.values) {
        for (final row in curriculum[subject]!) {
          final all = '${row.can} ${row.taught} ${row.evidence}'.toLowerCase();
          for (final word in ['grade', 'year group']) {
            expect(all, isNot(contains(word)),
                reason: '$subject L${row.level} reads as a school year');
          }
          // "Form 5" and "Class 3" are school years here; "fixed forms" is not.
          // Matching the bare word flagged the sentence about letter shapes,
          // which is the opposite of what this guards against.
          for (final pattern in [
            RegExp(r'\bform\s+\d'),
            RegExp(r'\bclass\s+\d'),
            RegExp(r'\bprimary\s+\d'),
          ]) {
            expect(pattern.hasMatch(all), isFalse,
                reason: '$subject L${row.level} reads as a school year: "$all"');
          }
        }
      }
      for (final level in [1.0, 3.0, 5.0, 7.0, 9.5]) {
        final band = bandFor(level);
        expect(band, isNotEmpty);
        for (final word in ['grade', 'class', 'year', 'primary', 'form']) {
          expect(band.toLowerCase(), isNot(contains(word)));
        }
      }
    });

    test('each level says something different from the one before it', () {
      for (final subject in Subject.values) {
        final claims = curriculum[subject]!.map((r) => r.can).toList();
        expect(claims.toSet().length, claims.length,
            reason: '$subject repeats an outcome, so a child moving up gains nothing to say');
      }
    });
  });
}
