import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/primar/domain/literacy.dart';
import 'package:prepskul/features/primar/domain/representation.dart';
import 'package:prepskul/features/primar/domain/word_bank.dart';

/// Every French reading rung must produce real questions, not silent fallbacks.
///
/// Francophone Cameroon is half the market. A rung that falls back to an
/// easier form teaches nothing about the skill on the graph.
void main() {
  const trials = 100;
  const minReal = 85; // >90% with room for honest edge cases

  /// Skill id → substring that appears in a real item's id (not a fallback).
  const rungs = {
    'pa.rhyme': 'rhyme',
    'pa.syllable': 'syllable',
    'pa.blend': 'blend',
    'pa.segment': 'endsound',
    'decode.sentence': 'phrase',
    'meaning.sentence': 'sentence-meaning',
  };

  group('French rungs produce real items', () {
    for (final entry in rungs.entries) {
      test('${entry.key} — ${entry.value}', () {
        final real = [
          for (var i = 0; i < trials; i++)
            generateItemForSkill(entry.key, Random(i * 23 + 7),
                index: i, locale: 'fr', support: Support.full),
        ].where((item) => item.id.contains(entry.value)).length;

        expect(real, greaterThan(minReal),
            reason: '${entry.key} fell back ${trials - real} of $trials times '
                'for French — the bank or tables are still too thin');
      });
    }
  });

  group('French decodable bank meets the bar', () {
    test('at least twenty readable words', () {
      expect(readableWords('fr').length, greaterThanOrEqualTo(20));
    });

    test('every picturable French word has frenchSounds when rhyme needs it', () {
      for (final w in picturableWords('fr')) {
        expect(frenchSounds[w], isNotNull,
            reason: '"$w" is picturable but missing from frenchSounds');
      }
    });
  });
}
