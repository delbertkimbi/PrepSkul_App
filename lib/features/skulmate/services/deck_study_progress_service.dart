import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local deck journey progress (Review → Ready → Practice → Master).
class DeckStudyProgress {
  final int cardsRevealed;
  final bool notesViewed;
  final bool conceptPassed;
  final List<String> modesCompleted;
  final bool sessionCompleted;

  const DeckStudyProgress({
    this.cardsRevealed = 0,
    this.notesViewed = false,
    this.conceptPassed = false,
    this.modesCompleted = const [],
    this.sessionCompleted = false,
  });

  factory DeckStudyProgress.fromJson(Map<String, dynamic> json) {
    return DeckStudyProgress(
      cardsRevealed: json['cardsRevealed'] as int? ?? 0,
      notesViewed: json['notesViewed'] as bool? ?? false,
      conceptPassed: json['conceptPassed'] as bool? ?? false,
      modesCompleted: (json['modesCompleted'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      sessionCompleted: json['sessionCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'cardsRevealed': cardsRevealed,
        'notesViewed': notesViewed,
        'conceptPassed': conceptPassed,
        'modesCompleted': modesCompleted,
        'sessionCompleted': sessionCompleted,
      };

  DeckStudyProgress copyWith({
    int? cardsRevealed,
    bool? notesViewed,
    bool? conceptPassed,
    List<String>? modesCompleted,
    bool? sessionCompleted,
  }) {
    return DeckStudyProgress(
      cardsRevealed: cardsRevealed ?? this.cardsRevealed,
      notesViewed: notesViewed ?? this.notesViewed,
      conceptPassed: conceptPassed ?? this.conceptPassed,
      modesCompleted: modesCompleted ?? this.modesCompleted,
      sessionCompleted: sessionCompleted ?? this.sessionCompleted,
    );
  }
}

enum DeckJourneyStep {
  review,
  ready,
  practice,
  master,
}

class DeckStudyProgressService {
  static const _prefix = 'skulmate_deck_progress_';

  static Future<DeckStudyProgress> load(String deckKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$deckKey');
    if (raw == null || raw.isEmpty) return const DeckStudyProgress();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return DeckStudyProgress.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return const DeckStudyProgress();
  }

  static Future<void> _save(String deckKey, DeckStudyProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$deckKey', jsonEncode(progress.toJson()));
  }

  static Future<void> recordCardRevealed(String deckKey) async {
    final current = await load(deckKey);
    await _save(
      deckKey,
      current.copyWith(cardsRevealed: current.cardsRevealed + 1),
    );
  }

  static Future<void> markNotesViewed(String deckKey) async {
    final current = await load(deckKey);
    if (current.notesViewed) return;
    await _save(deckKey, current.copyWith(notesViewed: true));
  }

  static Future<void> markConceptPassed(String deckKey) async {
    final current = await load(deckKey);
    await _save(deckKey, current.copyWith(conceptPassed: true));
  }

  static Future<void> recordModeCompleted(String deckKey, String modeKey) async {
    final current = await load(deckKey);
    if (current.modesCompleted.contains(modeKey)) return;
    await _save(
      deckKey,
      current.copyWith(
        modesCompleted: [...current.modesCompleted, modeKey],
      ),
    );
  }

  static Future<void> markSessionCompleted(String deckKey) async {
    final current = await load(deckKey);
    await _save(deckKey, current.copyWith(sessionCompleted: true));
  }

  static List<DeckJourneyStep> completedSteps({
    required DeckStudyProgress progress,
    required int totalCards,
  }) {
    final reviewTarget = totalCards <= 3 ? totalCards : 3;
    final reviewDone =
        progress.notesViewed || progress.cardsRevealed >= reviewTarget;
    final readyDone = progress.conceptPassed;
    final practiceDone = progress.modesCompleted.isNotEmpty;
    final masterDone =
        progress.sessionCompleted || progress.modesCompleted.length >= 2;

    final steps = <DeckJourneyStep>[];
    if (reviewDone) steps.add(DeckJourneyStep.review);
    if (readyDone) steps.add(DeckJourneyStep.ready);
    if (practiceDone) steps.add(DeckJourneyStep.practice);
    if (masterDone) steps.add(DeckJourneyStep.master);
    return steps;
  }

  /// 0–100 journey completion for deck list UI.
  static int percentForDeck({
    required DeckStudyProgress progress,
    required int totalCards,
  }) {
    final steps = completedSteps(
      progress: progress,
      totalCards: totalCards,
    );
    return ((steps.length / 4) * 100).round().clamp(0, 100);
  }
}
