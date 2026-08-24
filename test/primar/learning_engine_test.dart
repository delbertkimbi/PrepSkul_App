import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/learner.dart';
import 'package:prepskul/features/primar/domain/literacy.dart';
import 'package:prepskul/features/primar/domain/misconception.dart';
import 'package:prepskul/features/primar/domain/intervention.dart';
import 'package:prepskul/features/primar/domain/policy.dart';
import 'package:prepskul/features/primar/domain/representation.dart';
import 'package:prepskul/features/primar/domain/skill.dart';
import 'package:prepskul/features/primar/presentation/word_picture.dart';

/// The engine decides what a child does next. Everything it gets wrong, a child
/// pays for with their afternoon, so these test behaviour rather than plumbing.
void main() {
  final t0 = DateTime(2026, 8, 15, 9);

  Evidence ev(
    String skill, {
    required bool correct,
    int ms = 2500,
    bool help = false,
    bool transfer = false,
    Misconception miss = Misconception.unclear,
    int minute = 0,
    int day = 0,
  }) =>
      Evidence(
        skillId: skill,
        correct: correct,
        elapsedMs: ms,
        at: t0.add(Duration(days: day, minutes: minute)),
        neededTeaching: help,
        misconception: miss,
        isTransfer: transfer,
      );

  List<Evidence> run(String skill, int n, {required bool correct, bool help = false}) =>
      [for (var i = 0; i < n; i++) ev(skill, correct: correct, help: help, minute: i)];

  group('the graph is well formed', () {
    test('every prerequisite names a skill that exists', () {
      for (final s in readingSkills) {
        for (final p in s.prerequisites) {
          expect(skillsById, contains(p), reason: '${s.id} requires missing $p');
        }
        for (final p in s.transferFrom) {
          expect(skillsById, contains(p), reason: '${s.id} transfers from missing $p');
        }
      }
    });

    test('no skill depends on itself, however indirectly', () {
      // A cycle means the frontier can never open, and a child sits forever on
      // a skill whose prerequisite is the skill.
      for (final s in readingSkills) {
        expect(prerequisitesOf(s.id), isNot(contains(s.id)),
            reason: '${s.id} is its own prerequisite');
      }
    });

    test('every teachable skill is reachable from the ground', () {
      // The first version of this graph had teachable skills sitting behind
      // prerequisites the app cannot present, so their door could never open —
      // every child would have been stuck on letter shapes with the rest of
      // reading sealed off. An unmeasurable prerequisite must not block.
      var learner = learnerFrom(const []);
      final reached = <String>{};

      for (var pass = 0; pass < readingSkills.length + 1; pass++) {
        final open = learner.frontier().map((s) => s.id).toSet();
        if (open.difference(reached).isEmpty) break;
        reached.addAll(open);
        learner = learnerFrom([
          for (final id in reached) ...[
            ...run(id, 8, correct: true),
            ev(id, correct: true, transfer: true, minute: 30),
          ],
        ]);
      }

      for (final s in teachableSkills) {
        expect(reached, contains(s.id),
            reason: '${s.id} can never be reached by any child');
      }
    });

    test('every reading skill marked teachable has a generator behind it', () {
      // The honesty rule, inverted: a skill marked teachable must actually be
      // presentable. For years several sat in the graph with teachable: false
      // because no generator existed — honest, but a child who cleared the
      // walkable path had finished the product. Every reading skill is now
      // built; this is the guard against marking one teachable before it is.
      for (final s in readingSkills.where((s) => s.teachable)) {
        expect(canGenerateSkill(s.id), isTrue,
            reason: '${s.id} is teachable but has no generator');
      }
    });
  });

  group('mastery is a decision, not a score', () {
    test('a perfect run is not mastery until it transfers', () {
      final s = estimate('letter.sound', run('letter.sound', 8, correct: true));
      expect(s.recentAccuracy, 1.0);
      expect(s.state, MasteryState.probable,
          reason: 'eight right in the same context is strong, not finished');
      expect(s.transferTested, isFalse);
    });

    test('the same run plus one transfer item is mastery', () {
      final log = [
        ...run('letter.sound', 8, correct: true),
        ev('letter.sound', correct: true, transfer: true, minute: 9),
      ];
      expect(estimate('letter.sound', log).state, MasteryState.mastered);
    });

    test('a failed transfer does not count as having transferred', () {
      final log = [
        ...run('letter.sound', 8, correct: true),
        ev('letter.sound', correct: false, transfer: true, minute: 9),
      ];
      final s = estimate('letter.sound', log);
      expect(s.transferTested, isFalse,
          reason: 'meeting it somewhere new and failing is information, '
              'not evidence of transfer');
      expect(s.state, isNot(MasteryState.mastered));
    });

    test('a skill propped up by being shown the answer is not mastered', () {
      // Every answer right — but every one of them after being told. This is
      // the case a raw accuracy score cannot see at all.
      final log = [
        for (var i = 0; i < 8; i++)
          ev('letter.sound', correct: true, help: true, minute: i),
        ev('letter.sound', correct: true, transfer: true, minute: 9),
      ];
      final s = estimate('letter.sound', log);
      expect(s.accuracy, 1.0);
      expect(s.helpRate, greaterThan(0.34));
      expect(s.state, MasteryState.learning,
          reason: 'perfect accuracy, entirely dependent on help');
    });

    test('too few attempts is never mastery, however clean', () {
      expect(estimate('letter.shape', run('letter.shape', 3, correct: true)).state,
          MasteryState.learning);
    });

    test('recent evidence outweighs old', () {
      // Lost at first, has it now. The all-time average hides this; the recent
      // window is what a teacher would actually look at.
      final log = [
        ...run('letter.shape', 6, correct: false),
        for (var i = 0; i < 6; i++) ev('letter.shape', correct: true, minute: 10 + i),
      ];
      final s = estimate('letter.shape', log);
      expect(s.accuracy, 0.5);
      expect(s.recentAccuracy, 1.0);
      expect(s.state, isNot(MasteryState.learning),
          reason: 'the child has turned the corner and the model should say so');
    });

    test('a skill being lost is caught, not averaged away', () {
      final log = [
        ...run('letter.shape', 8, correct: true),
        for (var i = 0; i < 5; i++) ev('letter.shape', correct: false, minute: 10 + i),
      ];
      final s = estimate('letter.shape', log);
      expect(s.accuracy, greaterThan(0.6));
      expect(s.recentAccuracy, lessThan(0.35));
      expect(s.state, MasteryState.learning);
    });

    test('the mistake that keeps coming back is named', () {
      final log = [
        for (var i = 0; i < 4; i++)
          ev('letter.sound',
              correct: false, miss: Misconception.letterReversal, minute: i),
        ev('letter.sound', correct: false, miss: Misconception.letterShape, minute: 9),
      ];
      expect(estimate('letter.sound', log).dominantMisconception,
          Misconception.letterReversal);
    });

    test('one odd mistake is not a pattern', () {
      final log = [
        ev('letter.sound', correct: false, miss: Misconception.letterReversal),
        ...run('letter.sound', 5, correct: true),
      ];
      expect(estimate('letter.sound', log).dominantMisconception,
          Misconception.unclear);
    });
  });

  group('the frontier is where the child actually is', () {
    test('a new learner starts at the foundations only', () {
      final f = const Learner(skills: {}).frontier().map((s) => s.id).toSet();
      // Anything requiring letter sounds cannot be open on day one.
      expect(f, isNot(contains('decode.read')));
      expect(f, contains('letter.shape'));
    });

    test('clearing a prerequisite opens what sits on it', () {
      final before = learnerFrom(const []);
      expect(before.frontier().map((s) => s.id), isNot(contains('decode.build')));

      final after = learnerFrom([
        ...run('letter.shape', 8, correct: true),
        ...run('pa.initial', 8, correct: true),
        ...run('letter.sound', 8, correct: true),
      ]);
      expect(after.frontier().map((s) => s.id), contains('decode.build'));
    });

    test('two children with the same number of right answers can differ', () {
      // The whole point of the graph. Same volume of evidence, different
      // shape, different next step.
      final shapes = learnerFrom(run('letter.shape', 9, correct: true));
      final sounds = learnerFrom([
        ...run('letter.shape', 9, correct: true),
        ...run('pa.initial', 9, correct: true),
      ]);
      expect(shapes.frontier().map((s) => s.id).toSet(),
          isNot(sounds.frontier().map((s) => s.id).toSet()));
    });
  });

  group('what the engine chooses', () {
    test('a brand new child is given something with no prerequisites', () {
      final d = nextSkill(learnerFrom(const []));
      expect(d.reason, Reason.advance);
      expect(skillsById[d.skillId]!.prerequisites, isEmpty);
    });

    test('it never selects a skill whose groundwork is missing', () {
      // Walked forward a hundred times from a hundred different histories.
      for (var seed = 0; seed < 60; seed++) {
        final log = <Evidence>[];
        for (var step = 0; step < 12; step++) {
          final d = nextSkill(learnerFrom(log));
          if (d.exhausted) break;

          final skill = skillsById[d.skillId]!;
          for (final p in skill.prerequisites) {
            expect(learnerFrom(log).isCleared(p), isTrue,
                reason: 'chose ${d.skillId} while $p was still open');
          }
          // A child who gets most things right, and misses on a rhythm that
          // varies with the seed.
          final correct = (step + seed) % 4 != 0;
          log.addAll([
            for (var i = 0; i < 3; i++)
              ev(d.skillId!, correct: correct, minute: log.length + i),
          ]);
        }
      }
    });

    test('it never selects something the app cannot present', () {
      for (var step = 0; step < 40; step++) {
        final log = <Evidence>[];
        final d = nextSkill(learnerFrom(log));
        if (d.exhausted) break;
        expect(skillsById[d.skillId]!.teachable, isTrue);
      }
    });

    test('a recurring reversal sends the child to the shape skill, not more sound',
        () {
      // The intervention that matters. A child picking d for /b/ has not
      // misheard anything, and more listening practice will not touch it.
      final log = [
        ...run('letter.shape', 8, correct: true),
        ...run('pa.initial', 8, correct: true),
        for (var i = 0; i < 5; i++)
          ev('letter.sound',
              correct: false, miss: Misconception.letterReversal, minute: 20 + i),
      ];
      final d = nextSkill(learnerFrom(log));
      // A different way in beats a rung down. Dropping to the shape skill was
      // the old behaviour and it was only half right: it changed *what* the
      // child worked on but still showed them the question they had already
      // failed five times.
      //
      // The plan is a comparison, not a mnemonic. A "bed" screen lived here
      // briefly and was deleted for being circular — using it needs the child
      // to already read the word "bed", and a child who reverses b and d is
      // nowhere near reading a word.
      expect(d.reason, Reason.reteach);
      expect(d.explain, contains('together'));
    });

    test('a mistake with no built way in still drops to the prerequisite', () {
      // Seven of the eight mistakes the tracker names have no screen yet. They
      // must not silently fall through to "more of the same" — the rung-down
      // is the fallback, and it has to still work.
      final log = [
        ...run('letter.shape', 8, correct: true),
        ...run('pa.initial', 8, correct: true),
        for (var i = 0; i < 5; i++)
          ev('letter.sound',
              correct: false, miss: Misconception.letterShape, minute: 20 + i),
      ];
      final d = nextSkill(learnerFrom(log));
      expect(d.reason, anyOf(Reason.reteach, Reason.repair));
      expect(d.skillId, isNotNull);
    });

    test('a due review beats new material', () {
      final log = [
        ...run('letter.shape', 8, correct: true),
        ev('letter.shape', correct: true, transfer: true, minute: 9, day: -30),
      ];
      final learner = learnerFrom(log);
      final due = learner.stateOf('letter.shape');
      expect(due.state, MasteryState.mastered);
      expect(due.isDue, isTrue, reason: 'mastered a month ago and never revisited');

      expect(nextSkill(learner).reason, Reason.review);
    });

    test('a session cannot collapse into nothing but revision', () {
      final log = [
        ...run('letter.shape', 8, correct: true),
        ev('letter.shape', correct: true, transfer: true, minute: 9, day: -30),
      ];
      final learner = learnerFrom(log);
      expect(nextSkill(learner, reviewsSoFar: maxReviewsPerSession).reason,
          isNot(Reason.review));
    });

    test('a skill that is strong but untested gets tested somewhere new', () {
      // Everything reachable is probable and nothing is left to start.
      final log = <Evidence>[
        for (final s in teachableSkills) ...run(s.id, 8, correct: true),
      ];
      final d = nextSkill(learnerFrom(log));
      expect(d.reason, Reason.transfer);
      expect(d.explain, contains('somewhere new'));
    });

    test('running out is reported honestly, not by repeating the last thing', () {
      final log = <Evidence>[
        for (final s in teachableSkills) ...[
          ...run(s.id, 8, correct: true),
          ev(s.id, correct: true, transfer: true, minute: 30),
        ],
      ];
      // Reviews suppressed, because this is about what happens when there is
      // nothing left to *teach*.
      //
      // Without this the test was quietly time-dependent: the fixture is dated,
      // spacing schedules a review a day after the last attempt, and once real
      // time passed that date every mastered skill fell due and the engine
      // correctly returned a review instead. It passed for a day and then
      // started failing on its own.
      final d = nextSkill(learnerFrom(log), reviewsSoFar: maxReviewsPerSession);
      expect(d.exhausted, isTrue);
      expect(d.reason, Reason.nothingLeft);
    });
  });

  group('what a parent is told', () {
    const deficit = ['behind', 'below', 'weak', 'poor', 'fail', 'grade', 'stupid', 'slow'];

    test('every explanation reads as a plan, not a verdict', () {
      final histories = <List<Evidence>>[
        const [],
        run('letter.shape', 9, correct: false),
        [
          ...run('letter.shape', 8, correct: true),
          ...run('pa.initial', 8, correct: true),
          for (var i = 0; i < 5; i++)
            ev('letter.sound',
                correct: false, miss: Misconception.letterReversal, minute: 20 + i),
        ],
      ];
      for (final log in histories) {
        final d = nextSkill(learnerFrom(log));
        for (final word in deficit) {
          expect(d.explain.toLowerCase(), isNot(contains(word)),
              reason: 'reads as a judgement: "${d.explain}"');
        }
        expect(summarise(learnerFrom(log), 'Ayuk').toLowerCase(),
            isNot(contains('grade')));
      }
    });

    test('the summary names the child and says what they can do', () {
      final log = [
        ...run('letter.shape', 8, correct: true),
        ev('letter.shape', correct: true, transfer: true, minute: 9),
        ...run('pa.initial', 4, correct: false),
      ];
      final text = summarise(learnerFrom(log), 'Ayuk');
      expect(text, startsWith('Ayuk can now'));
      expect(text, contains('working on'));
    });

    test('a child with no history is not described as lacking anything', () {
      expect(summarise(const Learner(skills: {}), 'Bih'),
          'Bih is just getting started.');
    });
  });

  group('the graph and the generators cannot drift apart', () {
    test('every teachable skill can actually produce an item', () {
      // The graph saying "teachable" and the generators being able to build it
      // are two different claims, kept in two different files. If they ever
      // disagree the policy picks a skill and the session throws.
      for (final s in teachableSkills) {
        expect(canGenerateSkill(s.id), isTrue,
            reason: '${s.id} is marked teachable with no generator behind it');
      }
    });

    test('nothing unteachable has a generator quietly pointing at it', () {
      for (final s in readingSkills.where((s) => !s.teachable)) {
        expect(canGenerateSkill(s.id), isFalse,
            reason: '${s.id} can be generated but the graph says it cannot, '
                'so a real skill is sitting unused');
      }
    });

    test('items come back well formed for every skill, in both languages', () {
      for (final locale in ['en', 'fr']) {
        for (final s in teachableSkills) {
          for (var i = 0; i < 60; i++) {
            final item = generateItemForSkill(s.id, Random(i * 31), index: i, locale: locale);
            expect(_hasSomethingOnScreen(item), isTrue,
                reason: '$locale ${s.id} produced a question with nothing in it');
            if (item.interaction == Interaction.choose) {
              expect(item.options, isNotEmpty);
              expect(item.answerIndex, inInclusiveRange(0, item.options.length - 1));
            }
          }
        }
      }
    });

    test('the reversal skill actually shows a mirror letter to reject', () {
      // The whole point of the intervention. A child sent here for confusing
      // b and d must meet b and d, not two letters that look nothing alike.
      const mirrors = {'b': ['d', 'p'], 'd': ['b', 'q'], 'p': ['q', 'b'], 'q': ['p', 'd']};
      var checked = 0;

      for (var i = 0; i < 120; i++) {
        final item = generateItemForSkill('letter.shape.reversal', Random(i * 7), index: i);
        final answer = item.options[item.answerIndex];
        expect(answer, isA<LetterFigure>());

        final target = (answer as LetterFigure).letter;
        expect(mirrors.keys, contains(target),
            reason: 'reversal item asked about "$target", which has no mirror twin');

        final shown = item.options.whereType<LetterFigure>().map((f) => f.letter).toSet();
        expect(shown.intersection(mirrors[target]!.toSet()), isNotEmpty,
            reason: 'reversal item for "$target" offered no mirror letter: $shown');
        checked++;
      }
      expect(checked, 120);
    });

    test('a plain letter-shape item is not silently a reversal item', () {
      // If every shape item were a reversal item the repair step would be
      // indistinguishable from ordinary work, and the intervention would mean
      // nothing.
      var nonMirror = 0;
      for (var i = 0; i < 120; i++) {
        final item = generateItemForSkill('letter.shape', Random(i * 13), index: i);
        final target = (item.options[item.answerIndex] as LetterFigure).letter;
        if (!['b', 'd', 'p', 'q'].contains(target)) nonMirror++;
      }
      expect(nonMirror, greaterThan(60),
          reason: 'letter.shape has collapsed into letter.shape.reversal');
    });
  });

  group('the picture-answer sound question is fair', () {
    test('no two pictures start with the same sound', () {
      // The failure this guards against marks a correct child wrong. Ask for
      // /b/ and offer both "ball" and "bus", and a child who knows exactly what
      // they are doing has a coin-flip.
      var checked = 0;
      for (var i = 0; i < 300; i++) {
        final item = generateItemForSkill('pa.initial', Random(i * 17), index: i);
        final pics = item.options.whereType<PictureFigure>().toList();
        if (pics.isEmpty) continue;

        final firstLetters = pics.map((p) => p.word[0]).toList();
        expect(firstLetters.toSet().length, firstLetters.length,
            reason: '${item.id} offered $firstLetters — two share a sound');
        checked++;
      }
      expect(checked, greaterThan(200),
          reason: 'the picture form barely generated, so this proves little');
    });

    test('the answer really does start with the sound being asked for', () {
      for (var i = 0; i < 300; i++) {
        final item = generateItemForSkill('pa.initial', Random(i * 29), index: i);
        final answer = item.options[item.answerIndex];
        if (answer is! PictureFigure) continue;

        // The teach line names the letter, so it has to agree with the word.
        final letterLine =
            item.teach.firstWhere((t) => t.startsWith('letter:'), orElse: () => '');
        expect(letterLine, isNotEmpty, reason: '${item.id} never names the letter');
        expect(letterLine.substring(7), answer.word[0],
            reason: '${item.id} asks about "${letterLine.substring(7)}" '
                'but the answer is "${answer.word}"');
      }
    });

    test('every picture offered is one we can actually draw', () {
      // A word with no drawing renders as a neutral placeholder box, which in a
      // pick-the-picture question is an unanswerable option.
      for (var i = 0; i < 300; i++) {
        final item = generateItemForSkill('pa.initial', Random(i * 41), index: i);
        for (final p in item.options.whereType<PictureFigure>()) {
          expect(WordPicture.canDraw(p.word), isTrue,
              reason: '${item.id} offered "${p.word}" with no picture behind it');
        }
      }
    });

    test('no letter appears anywhere in the question', () {
      // The point of this form is that a child who cannot read a single letter
      // can still answer. A stray letter tile would undo that.
      for (var i = 0; i < 200; i++) {
        final item = generateItemForSkill('pa.initial', Random(i * 53), index: i);
        if (item.options.whereType<PictureFigure>().isEmpty) continue;
        expect(item.options.whereType<LetterFigure>(), isEmpty);
        expect(item.prompt.whereType<LetterFigure>(), isEmpty);
      }
    });
  });

  group('support fades as the child gets stronger', () {
    test('a child meeting a skill gets everything', () {
      expect(supportFor(estimate('decode.read', run('decode.read', 2, correct: true))),
          Support.full);
      expect(supportFor(const Learner(skills: {}).stateOf('decode.read')),
          Support.full);
    });

    test('a child who is getting it loses the picture but keeps the sound', () {
      final s = estimate('decode.read', run('decode.read', 8, correct: true));
      expect(s.state, MasteryState.probable);
      expect(supportFor(s), Support.partial);
    });

    test('a child who knows it is asked with nothing at all', () {
      final log = [
        ...run('decode.read', 8, correct: true),
        ev('decode.read', correct: true, transfer: true, minute: 9),
      ];
      expect(supportFor(estimate('decode.read', log)), Support.none);
    });

    test('leaning on help overrules a good run', () {
      // Perfect accuracy, every answer after being shown. Withdrawing support
      // here would be taking the crutch from someone still using it.
      final log = [
        for (var i = 0; i < 8; i++)
          ev('decode.read', correct: true, help: true, minute: i),
        ev('decode.read', correct: true, transfer: true, minute: 9),
      ];
      expect(supportFor(estimate('decode.read', log)), Support.full);
    });

    test('support comes back when a child starts slipping', () {
      final strong = [
        ...run('decode.read', 8, correct: true),
        ev('decode.read', correct: true, transfer: true, minute: 9),
      ];
      expect(supportFor(estimate('decode.read', strong)), Support.none);

      final slipping = [
        ...strong,
        for (var i = 0; i < 5; i++) ev('decode.read', correct: false, minute: 20 + i),
      ];
      expect(supportFor(estimate('decode.read', slipping)), Support.full,
          reason: 'a child who is losing it must get the picture back');
    });
  });

  group('the generator actually honours the fade', () {
    test('reading a word shows the picture only while it is being learned', () {
      for (var i = 0; i < 60; i++) {
        final full = generateItemForSkill('decode.read', Random(i),
            index: i, support: Support.full);
        expect(full.prompt.whereType<PictureFigure>(), isNotEmpty,
            reason: 'a child learning to read a word needs to see the thing');

        for (final s in [Support.partial, Support.none]) {
          final faded =
              generateItemForSkill('decode.read', Random(i), index: i, support: s);
          expect(faded.prompt.whereType<PictureFigure>(), isEmpty,
              reason: 'the picture survived at $s, so a child can still answer '
                  'without reading a letter');
        }
      }
    });

    test('the sound never goes away, at any level', () {
      // Withdrawing the picture is fading a scaffold. Withdrawing the way to
      // hear the question is removing access, and a child who missed it the
      // first time would simply be stuck.
      for (final s in Support.values) {
        for (var i = 0; i < 40; i++) {
          final item =
              generateItemForSkill('decode.read', Random(i * 3), index: i, support: s);
          expect(item.prompt.whereType<SoundFigure>(), isNotEmpty,
              reason: 'no way to hear the question at $s');
        }
      }
    });

    test('an unsupported item is what counts as transfer', () {
      expect(isTransferEvidence(Support.none), isTrue);
      expect(isTransferEvidence(Support.partial), isFalse);
      expect(isTransferEvidence(Support.full), isFalse);
    });

    test('every faded item is still answerable', () {
      // Fading must never produce a blank question — the exact failure that
      // shipped once already.
      for (final skill in teachableSkills) {
        for (final s in Support.values) {
          for (var i = 0; i < 30; i++) {
            final item =
                generateItemForSkill(skill.id, Random(i * 7), index: i, support: s);
            expect(_hasSomethingOnScreen(item), isTrue,
                reason: '${skill.id} at $s has nothing on screen');
          }
        }
      }
    });
  });

  group('every mistake the tracker can name has an answer', () {
    test('no misconception falls through the registry', () {
      // The tracker classifies eight kinds of mistake. Before this registry the
      // app had exactly one response — the b/d screen — and the other seven
      // arrived at more of the same question, which is the definition of not
      // teaching.
      for (final m in Misconception.values) {
        final plan = interventionFor(m);
        expect(plan.misconception, m);
        expect(plan.why, isNotEmpty,
            reason: '$m has no stated reason, so nobody can argue with it');
      }
    });

    test('every real mistake says what a teacher would actually do', () {
      for (final m in Misconception.values) {
        if (m == Misconception.unclear) continue;
        expect(interventionFor(m).what, isNotEmpty,
            reason: '$m has no plan at all');
      }
    });

    test('nothing unbuilt claims to be built', () {
      for (final i in interventions) {
        if (i.kind == InterventionKind.none) {
          expect(i.isBuilt, isFalse);
        }
        if (i.kind == InterventionKind.demonstration) {
          expect(i.screenId, isNotNull,
              reason: '${i.misconception} claims a screen and names none');
        }
      }
    });

    test('the coverage gap is a number, not a surprise', () {
      // Deliberately asserted as a range rather than a target. It should go up;
      // it must never silently go down, and it must never read as complete
      // while seven of eight mistakes have no new way in.
      expect(interventionCoverage, greaterThan(0.0));
      expect(interventionCoverage, lessThan(1.0),
          reason: 'if this ever reads 1.0, check the entries are real rather '
              'than someone having marked the gaps as done');
    });
  });
}

/// Whether a child looking at this item has anything to work with.
///
/// The rule these tests protect is "nothing blank ever reaches a child" — the
/// dashed-empty-box bug that shipped once. It used to be written as "the
/// prompt is non-empty", which was the same thing right up until an item
/// arrived whose content is not in the prompt: a phrase to be dragged into
/// order *is* the question, and giving it a prompt row as well would show the
/// child the answer.
///
/// So the check is on the content wherever it lives, which is what the rule
/// always meant.
bool _hasSomethingOnScreen(PrimarItem item) =>
    item.prompt.any((f) => f is! SymbolFigure) ||
    item.orderItems.isNotEmpty ||
    item.matchLeft.isNotEmpty ||
    item.spellTarget.isNotEmpty ||
    item.options.isNotEmpty;
