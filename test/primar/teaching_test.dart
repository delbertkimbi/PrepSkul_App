import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/figure.dart';
import 'package:prepskul/features/primar/domain/subjects.dart';
import 'package:prepskul/features/primar/services/primar_voice.dart';

/// The product has to teach, not only mark.
///
/// These assert the thing that separates a lesson from a test: when a child
/// misses, they are told what the answer *is* and why — and every line of that
/// explanation actually exists as audio.
void main() {
  group('every item can teach', () {
    test('a miss always has something to say', () {
      for (final subject in Subject.values) {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 40; i++) {
            final item = generateForSubject(subject, level, Random(level * 19 + i), i);
            expect(item.teach, isNotEmpty,
                reason: '${subject.name} L$level item $i would only say "wrong"');
          }
        }
      }
    });

    test('every teaching line resolves to real audio', () {
      // A phrase id with no recording is silence, and silence in place of an
      // explanation is worse than saying nothing at all — the child waits for
      // help that never comes.
      final missing = <String>{};
      for (final subject in Subject.values) {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 60; i++) {
            final item = generateForSubject(subject, level, Random(level * 23 + i), i);
            for (final id in item.teach) {
              if (VoiceLines.byId(id) == null) missing.add(id);
            }
          }
        }
      }
      expect(missing, isEmpty, reason: 'teaching lines with no audio: $missing');
    });

    test('numbers and letters are named, shapes are explained', () {
      // "This one fits" is not teaching. But what counts as teaching differs by
      // subject: a number or a letter has a name to say, while a stroke
      // composition has none — there is no word for an arbitrary set of lines.
      // So numbers and letters must be NAMED, and shapes must be explained
      // structurally instead. Asserting one rule for all three was wrong.
      for (final subject in [Subject.numeracy, Subject.reading]) {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 30; i++) {
            final item = generateForSubject(subject, level, Random(level * 29 + i), i);
            if (item.interaction == Interaction.match) continue;
            final namesIt = item.teach.any((t) =>
                t.startsWith('letter:') ||
                t.startsWith('number:') ||
                t.startsWith('count:') ||
                t.startsWith('word:') ||
                t.startsWith('sound:'));
            expect(namesIt, isTrue,
                reason: '${subject.name} L$level item $i never says the answer: '
                    '\${item.teach}');
          }
        }
      }

      for (var level = 1; level <= 10; level++) {
        for (var i = 0; i < 30; i++) {
          final item = generateForSubject(Subject.shapes, level, Random(level * 29 + i), i);
          expect(item.teach, contains('these_make_this'),
              reason: 'shapes L$level item $i does not explain how it composes');
        }
      }
    });
  });

  group('the spoken catalogue stays closed', () {
    test('every line the app can say is in the prewarm list', () {
      // The offline guarantee depends on this: if a line is not in `all`, it is
      // never cached, so it goes silent the moment the network does.
      final catalogue = {for (final l in VoiceLines.all) l.id};
      final missing = <String>{};

      for (final subject in Subject.values) {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 40; i++) {
            final item = generateForSubject(subject, level, Random(level * 37 + i), i);
            for (final id in [...item.teach, if (item.spoken != null) item.spoken!]) {
              final line = VoiceLines.byId(id);
              if (line != null && !catalogue.contains(line.id)) missing.add(line.id);
            }
          }
        }
      }
      expect(missing, isEmpty,
          reason: 'these would be silent offline: $missing');
    });
  });
}
