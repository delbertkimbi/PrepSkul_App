import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/skulmate/services/deck_mastery_service.dart';

void main() {
  group('DeckMasteryService — band & percent', () {
    test('bandLabelForScore maps thresholds', () {
      expect(DeckMasteryService.bandLabelForScore(null), 'New');
      expect(DeckMasteryService.bandLabelForScore(0.8), 'Solid');
      expect(DeckMasteryService.bandLabelForScore(0.75), 'Solid');
      expect(DeckMasteryService.bandLabelForScore(0.6), 'Building');
      expect(DeckMasteryService.bandLabelForScore(0.4), 'Needs work');
    });

    test('bandColorForScore uses theme accents', () {
      expect(DeckMasteryService.bandColorForScore(null), AppTheme.textMedium);
      expect(DeckMasteryService.bandColorForScore(0.9), AppTheme.accentGreen);
      expect(DeckMasteryService.bandColorForScore(0.55), AppTheme.skyBlue);
      expect(DeckMasteryService.bandColorForScore(0.2), AppTheme.accentOrange);
    });

    test('snapshotFromScore rounds percent', () {
      final snap = DeckMasteryService.snapshotFromScore(
        score: 0.667,
        dueReviewCount: 3,
      );
      expect(snap.masteryPercent, 67);
      expect(snap.bandLabel, 'Building');
      expect(snap.dueReviewCount, 3);
      expect(snap.hasDueReviews, isTrue);
    });
  });
}
