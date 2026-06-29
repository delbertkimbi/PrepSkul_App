import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/skulmate/services/deck_library_service.dart';

void main() {
  group('DeckLibraryService', () {
    test('accentForTitle is stable and uses palette', () {
      final a = DeckLibraryService.accentForTitle('Internet Safety');
      final b = DeckLibraryService.accentForTitle('Internet Safety');
      expect(a, b);
      expect(DeckLibraryService.accentForTitle('Other'), isA<Color>());
    });

    test('accent palette uses brand colors', () {
      final color = DeckLibraryService.accentForTitle('Biology');
      expect(
        [
          AppTheme.skyBlue,
          AppTheme.accentGreen,
          const Color(0xFF14B8A6),
          AppTheme.accentPurple,
          AppTheme.accentOrange,
          AppTheme.accentPink,
          AppTheme.primaryLight,
        ],
        contains(color),
      );
    });

    test('public decks disabled until API ships', () {
      expect(DeckLibraryService.publicDecksEnabled, isFalse);
    });
  });
}
