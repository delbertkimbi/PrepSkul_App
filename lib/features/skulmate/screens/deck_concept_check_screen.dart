import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

import '../models/revision_deck_model.dart';
import '../services/deck_concept_check_service.dart';
import '../widgets/deck_study_launcher_sheet.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_game_surface.dart';
import '../widgets/skulmate_surface_styles.dart';

typedef DeckConceptCheckComplete = void Function(bool passed);

/// Short readiness probe before full quiz/play modes.
class DeckConceptCheckScreen extends StatefulWidget {
  final RevisionDeckModel deck;
  final DeckStudyMode studyMode;
  final DeckConceptCheckComplete onComplete;

  const DeckConceptCheckScreen({
    super.key,
    required this.deck,
    required this.studyMode,
    required this.onComplete,
  });

  @override
  State<DeckConceptCheckScreen> createState() => _DeckConceptCheckScreenState();
}

class _DeckConceptCheckScreenState extends State<DeckConceptCheckScreen> {
  late final List<RevisionDeckCard> _probeCards;
  int _index = 0;
  int _correct = 0;
  String? _selected;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _probeCards = widget.deck.conceptCheckCards;
  }

  RevisionDeckCard get _current => _probeCards[_index];

  List<String> get _options {
    final card = _current;
    if (card.supportsMcqProbe) return card.mcqOptions;
    return [card.answer, 'Not sure yet', 'Something else'];
  }

  Future<void> _finish({required bool passed}) async {
    if (passed) {
      await DeckConceptCheckService.markPassed(widget.deck.deckKey);
    }
    widget.onComplete(passed);
    if (mounted) Navigator.pop(context, passed);
  }

  void _submit() {
    if (_selected == null || _revealed) return;
    final isCorrect =
        _selected!.trim().toLowerCase() == _current.answer.trim().toLowerCase();
    safeSetState(() {
      _revealed = true;
      if (isCorrect) _correct++;
    });
  }

  void _next() {
    if (_index + 1 >= _probeCards.length) {
      final passed = _correct >= 2;
      _finish(passed: passed);
      return;
    }
    safeSetState(() {
      _index++;
      _selected = null;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_probeCards.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _finish(passed: true);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final progress = (_index + (_revealed ? 1 : 0)) / _probeCards.length;

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: SkulMateGameAppBar(
        light: true,
        title: 'Concept check',
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quick check before ${widget.studyMode.label.toLowerCase()}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.05, 1.0),
                  minHeight: 8,
                  backgroundColor: AppTheme.neutral100,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: GameFlatPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Question ${_index + 1} of ${_probeCards.length}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _current.cardType == RevisionDeckCardType.termDef
                            ? 'What does this mean?\n\n${_current.prompt}'
                            : _current.prompt,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ..._options.map((option) {
                        final isSelected = _selected == option;
                        final isAnswer =
                            option.trim().toLowerCase() ==
                            _current.answer.trim().toLowerCase();
                        Color border = AppTheme.neutral200;
                        Color fill = Colors.white;
                        if (_revealed && isAnswer) {
                          border = Colors.green;
                          fill = Colors.green.withValues(alpha: 0.08);
                        } else if (_revealed && isSelected && !isAnswer) {
                          border = Colors.red;
                          fill = Colors.red.withValues(alpha: 0.08);
                        } else if (isSelected) {
                          border = AppTheme.primaryColor;
                          fill = AppTheme.primaryColor.withValues(alpha: 0.06);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _revealed
                                ? null
                                : () => safeSetState(() => _selected = option),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: fill,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: border),
                              ),
                              child: Text(
                                option,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (_revealed && (_current.explanation ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _current.explanation!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _revealed
                    ? _next
                    : (_selected == null ? null : _submit),
                style: SkulMateSurfaceStyles.deckAccentButton(),
                child: Text(
                  _revealed
                      ? (_index + 1 >= _probeCards.length ? 'Continue' : 'Next')
                      : 'Check answer',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => _finish(passed: true),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
