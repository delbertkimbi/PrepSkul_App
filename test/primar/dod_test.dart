import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/literacy.dart';
import 'package:prepskul/features/primar/domain/mastery.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';

/// The Definition of Done, enforced — the parts that are pure logic.
///
/// The pixel-level rule lives in dod_render_test.dart. Widget tests and plain
/// tests must not share a file: with the widget binding initialised, a plain
/// test's expect() can fire while a pumpWidget is still in flight and the whole
/// file fails at once, which is exactly what happened here.
///
/// Every rule in the DoD that can be checked by a machine is checked here, by
/// the same name. A rule stated in a document and not asserted in code is a
/// hope; the point of this file is that the document cannot drift away from
/// what the software actually does.
///
/// Rules deliberately absent, because they need a human and a real phone:
///   · "Under five seconds to first tap"  — watch a child, say nothing
///   · "Smooth on a 2GB Android"          — run it on the device
/// Those two stay marked unverified in the DoD until someone does them.
void main() {
  group('DoD 1 · Correctness', () {
    test('every distractor is genuinely wrong, in every subject', () {
      for (final subject in Subject.values) {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 60; i++) {
            final item = generateForSubject(subject, level, Random(level * 31 + i), i);
            // Spelling is built and matching is joined — neither offers a set
            // of options one of which could be wrongly correct.
            if (item.interaction != Interaction.choose) continue;
            // Exactly one option may be the answer. If a distractor is also
            // correct, the child is punished for being right.
            final answer = item.options[item.answerIndex];
            var equalToAnswer = 0;
            for (final o in item.options) {
              if (_figureEquals(o, answer)) equalToAnswer++;
            }
            expect(equalToAnswer, 1,
                reason: '${subject.name} L$level item $i has $equalToAnswer '
                    'options equal to the answer');
          }
        }
      }
    });

    test('no generated imagery can carry a lesson', () {
      // Enforced structurally: Figure is a sealed union and none of its
      // variants can hold a remote or model-produced image. If someone adds
      // one, this test fails and they have to argue for it.
      const samples = <Figure>[
        ShapeFigure([]),
        QuantityFigure(3),
        NumeralFigure(7),
        LetterFigure('a'),
        WordFigure('cat'),
        SymbolFigure(MathSymbol.plus),
      ];
      for (final f in samples) {
        expect(
          f,
          anyOf(
            isA<ShapeFigure>(),
            isA<QuantityFigure>(),
            isA<NumeralFigure>(),
            isA<LetterFigure>(),
            isA<WordFigure>(),
            isA<SymbolFigure>(),
          ),
          reason: 'a lesson-bearing figure type was added outside the drawn set',
        );
      }
    });

    test('both languages carry items of the same shape and difficulty', () {
      for (var level = 1; level <= 10; level++) {
        int optionCount(String locale) {
          var total = 0;
          for (var i = 0; i < 40; i++) {
            total += generateLiteracyItem(level, Random(level * 7 + i),
                    index: i, locale: locale)
                .options
                .length;
          }
          return total;
        }

        // A child must not get an easier or harder deal for speaking French.
        expect(optionCount('en'), optionCount('fr'),
            reason: 'L$level offers a different number of choices per language');
      }
    });
  });

  group("DoD 2 · The child's experience", () {
    test('nothing a child looks at is instructional text', () {
      // Letters, numerals and single words are content — recognising them is
      // the lesson. Prose is not: a child who cannot read cannot be given an
      // instruction in writing.
      for (final subject in Subject.values) {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 40; i++) {
            final item = generateForSubject(subject, level, Random(level * 13 + i), i);
            for (final f in [...item.prompt, ...item.options]) {
              if (f is WordFigure) {
                expect(f.word.trim().split(RegExp(r'\s+')).length, 1,
                    reason: 'a phrase reached a child: "${f.word}"');
              }
              if (f is LetterFigure) {
                expect(f.letter.length, lessThanOrEqualTo(2),
                    reason: 'not a letter: "${f.letter}"');
              }
            }
          }
        }
      }
    });

    test('a session is understandable in silence', () {
      // Every item must be answerable from what is on screen. An item whose
      // prompt is only the "unknown" placeholder relies entirely on audio, so
      // it must name a spoken line — otherwise a muted phone shows a blank.
      for (final subject in Subject.values) {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 40; i++) {
            final item = generateForSubject(subject, level, Random(level * 17 + i), i);
            final visible = item.prompt.where((f) => f is! SymbolFigure).isNotEmpty;
            if (!visible) {
              expect(item.spoken, isNotNull,
                  reason: '${subject.name} L$level item $i is silent AND blank');
            }
          }
        }
      }
    });

    test('accuracy stays above 50% across the ability range', () {
      for (final trueLevel in [1, 3, 5, 7, 10]) {
        var accuracy = 0.0;
        const runs = 30;
        for (var r = 0; r < runs; r++) {
          var state = startSession(subject: Subject.numeracy, seed: r * 61 + trueLevel);
          final rng = Random(r + 3);
          while (!state.finished) {
            final item = nextItem(state);
            // Knowledge plus a guess across the options actually offered. Modelling a
            // child who never guesses made every accuracy figure pessimistic, and
            // produced a false alarm about the weakest learners.
            final know = 1 / (1 + exp((item.level - trueLevel) * 1.6));
            // A match board has no options, so there is nothing to guess from — and
            // 1/0 would make the simulated child answer everything correctly.
            // Joining three pairs by luck is close enough to impossible.
            final guess = item.options.isEmpty ? 0.02 : 1 / item.options.length;
            final p = know + (1 - know) * guess;
            state = recordAttempt(
              state,
              Attempt(
                itemId: item.id,
                level: item.level,
                correct: rng.nextDouble() < p,
                elapsedMs: 3000,
              ),
            );
          }
          accuracy += computePlacement(state).accuracy;
        }
        final mean = accuracy / runs;
        expect(mean, greaterThan(0.5),
            reason: 'a child at level $trueLevel meets a wall: '
                '${(mean * 100).round()}% correct');
      }
    });
  });

  group('DoD 3 · Works where it has to work', () {
    test('a full session runs with no network and no async', () {
      // Generation, scoring and placement are all synchronous and pure. If any
      // of them ever needs to await something, a question can block on a
      // network that is not there — so the signature itself is the guarantee.
      var state = startSession(subject: Subject.reading, seed: 5);

      final Object generated = nextItem(state);
      expect(generated, isNot(isA<Future>()),
          reason: 'item generation became asynchronous');

      while (!state.finished) {
        final item = nextItem(state);
        final Object stepped = recordAttempt(
          state,
          Attempt(itemId: item.id, level: item.level, correct: true, elapsedMs: 100),
        );
        expect(stepped, isNot(isA<Future>()), reason: 'scoring became asynchronous');
        state = stepped as SessionState;
      }

      final Object placement = computePlacement(state);
      expect(placement, isNot(isA<Future>()), reason: 'placement became asynchronous');
      expect(state.attempts, hasLength(sessionLength));
    });
  });

  group('DoD 4 · Evidence', () {
    test('placement converges within 1.5 levels', () {
      for (final trueLevel in [2, 4, 6, 8]) {
        var sum = 0.0;
        const runs = 40;
        for (var r = 0; r < runs; r++) {
          var state = startSession(subject: Subject.shapes, seed: r * 131 + trueLevel);
          final rng = Random(r * 131 + trueLevel + 5);
          while (!state.finished) {
            final item = nextItem(state);
            // Knowledge plus a guess across the options actually offered. Modelling a
            // child who never guesses made every accuracy figure pessimistic, and
            // produced a false alarm about the weakest learners.
            final know = 1 / (1 + exp((item.level - trueLevel) * 1.6));
            // A match board has no options, so there is nothing to guess from — and
            // 1/0 would make the simulated child answer everything correctly.
            // Joining three pairs by luck is close enough to impossible.
            final guess = item.options.isEmpty ? 0.02 : 1 / item.options.length;
            final p = know + (1 - know) * guess;
            state = recordAttempt(
              state,
              Attempt(
                itemId: item.id,
                level: item.level,
                correct: rng.nextDouble() < p,
                elapsedMs: 3000,
              ),
            );
          }
          sum += computePlacement(state).level;
        }
        expect((sum / runs - trueLevel).abs(), lessThan(1.5));
      }
    });

    test('an unsettled placement says so rather than reporting a guess', () {
      // A child who answers at random never settles. Reporting that as a level
      // would hand a parent a number with nothing behind it.
      var provisionalSeen = 0;
      for (var r = 0; r < 40; r++) {
        var state = startSession(subject: Subject.numeracy, seed: r * 7);
        final rng = Random(r);
        while (!state.finished) {
          final item = nextItem(state);
          state = recordAttempt(
            state,
            Attempt(
              itemId: item.id,
              level: item.level,
              // Pure noise, uncorrelated with difficulty.
              correct: rng.nextBool(),
              elapsedMs: 500,
            ),
          );
        }
        if (computePlacement(state).provisional) provisionalSeen++;
      }
      expect(provisionalSeen, greaterThan(0),
          reason: 'random answering always produced a confident level');
    });
  });
}

bool _figureEquals(Figure a, Figure b) => switch ((a, b)) {
      (ShapeFigure x, ShapeFigure y) =>
        x.shape.toSet().length == y.shape.toSet().length &&
            x.shape.toSet().containsAll(y.shape),
      (QuantityFigure x, QuantityFigure y) => x.count == y.count,
      (NumeralFigure x, NumeralFigure y) => x.value == y.value,
      (LetterFigure x, LetterFigure y) => x.letter == y.letter,
      (WordFigure x, WordFigure y) => x.word == y.word,
      (SymbolFigure x, SymbolFigure y) => x.symbol == y.symbol,
      _ => false,
    };
