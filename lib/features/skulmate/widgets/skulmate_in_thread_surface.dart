import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/skulmate/models/tutor_session_models.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_surface_styles.dart';

/// Compact practice card inside the tutor thread.
class SkulMateInThreadSurface extends StatefulWidget {
  final PracticeSurface surface;
  final VoidCallback? onContinue;
  final Future<void> Function(bool correct) onOutcome;
  final Future<void> Function(bool correct, List<int?> answers)?
  onVerifiedOutcome;

  const SkulMateInThreadSurface({
    super.key,
    required this.surface,
    this.onContinue,
    required this.onOutcome,
    this.onVerifiedOutcome,
  });

  @override
  State<SkulMateInThreadSurface> createState() =>
      _SkulMateInThreadSurfaceState();
}

class _SkulMateInThreadSurfaceState extends State<SkulMateInThreadSurface> {
  int _index = 0;
  final List<int?> _answers = [];
  int? _picked;
  bool _revealed = false;
  bool _done = false;
  bool _saving = false;
  bool _allCorrect = true;
  String? _saveError;

  Map<String, dynamic> get _item =>
      widget.surface.items[_index.clamp(0, widget.surface.items.length - 1)];

  @override
  Widget build(BuildContext context) {
    if (widget.surface.items.isEmpty) return const SizedBox.shrink();
    final french = Localizations.localeOf(context).languageCode == 'fr';
    final item = _item;
    final options = (item['options'] as List?)?.map((e) => '$e').toList() ?? [];
    final term = item['term'] as String?;
    final definition = item['definition'] as String?;
    final question = item['question'] as String? ?? term ?? '';
    final blank = item['blankText'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.surface.title,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            french
                ? "Question ${_index + 1} sur ${widget.surface.items.length}"
                : "Question ${_index + 1} of ${widget.surface.items.length}",
          ),
          Text(
            blank ?? question,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: AppTheme.textDark,
            ),
          ),
          if (term != null && definition != null) ...[
            const SizedBox(height: 10),
            if (!_revealed)
              TextButton(
                onPressed: () => setState(() => _revealed = true),
                child: const Text('Show'),
              )
            else
              Text(definition),
          ],
          if (options.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...List.generate(options.length, (i) {
              final selected = _picked == i;
              final correctIndex = item['correctAnswer'] is int
                  ? item['correctAnswer'] as int
                  : int.tryParse('${item['correctAnswer']}') ?? -1;
              Color? tint;
              if (_revealed && i == correctIndex) {
                tint = AppTheme.accentGreen.withValues(alpha: 0.16);
              } else if (_revealed && selected && i != correctIndex) {
                tint = AppTheme.accentPink.withValues(alpha: 0.14);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: tint ?? AppTheme.neutral50,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _revealed
                        ? null
                        : () => _answerQuiz(i, correctIndex),
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.primaryColor
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${String.fromCharCode(65 + i)}.",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(options[i])),
                            if (_revealed && i == correctIndex)
                              Text(
                                french ? 'Correct' : 'Correct',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (_revealed && selected && i != correctIndex)
                              Text(french ? 'Ton choix' : 'Your choice'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
          if (term != null && _revealed && !_done)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _saving ? null : () => _finish(true),
                child: Text(french ? 'Continuer' : 'Continue'),
              ),
            ),
          if (_revealed && options.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _picked == int.tryParse('${item['correctAnswer']}')
                  ? (french ? 'Bien joué !' : 'Nicely done!')
                  : (french
                        ? 'Regardons la correction ensemble.'
                        : 'Let’s work through the correction.'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (item['explanation'] != null) Text('${item['explanation']}'),
            if (!_done && !_saving && _saveError == null)
              FilledButton(
                onPressed: () => _finish(
                  _picked == int.tryParse('${item['correctAnswer']}'),
                ),
                child: Text(
                  _index < widget.surface.items.length - 1
                      ? (french ? 'Question suivante' : 'Next question')
                      : (french
                            ? 'Terminer cette pratique'
                            : 'Finish practice'),
                ),
              ),
          ],
          if (_saving) const LinearProgressIndicator(),
          if (_saveError != null) ...[
            Text(
              french
                  ? 'Progression non enregistrée. Réessayez.'
                  : 'Progress was not saved. Please retry.',
            ),
            TextButton(
              onPressed: _saving ? null : _saveResult,
              child: Text(french ? 'Réessayer' : 'Retry'),
            ),
          ],
          if (_done) ...[
            Text(
              _allCorrect
                  ? (french ? 'Pratique terminée.' : 'Practice complete.')
                  : (french
                        ? 'Revoyons les points difficiles avec Mate.'
                        : 'Let’s review the tricky parts with Mate.'),
            ),
            if (widget.onContinue != null)
              FilledButton(
                onPressed: widget.onContinue,
                child: Text(
                  _allCorrect
                      ? (french ? 'Continuer avec Mate' : 'Continue with Mate')
                      : (french ? 'Corriger avec Mate' : 'Review with Mate'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _answerQuiz(int picked, int correctIndex) async {
    setState(() {
      _picked = picked;
      _revealed = true;
    });
  }

  Future<void> _finish(bool correct) async {
    if (!mounted || _done || _saving) return;
    _answers.add(_picked);
    _allCorrect = _allCorrect && correct;
    if (_index < widget.surface.items.length - 1) {
      setState(() {
        _index += 1;
        _picked = null;
        _revealed = false;
      });
      return;
    }
    await _saveResult();
  }

  Future<void> _saveResult() async {
    if (_saving || _done) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (widget.onVerifiedOutcome != null) {
        await widget.onVerifiedOutcome!(
          _allCorrect,
          List.unmodifiable(_answers),
        );
      } else {
        await widget.onOutcome(_allCorrect);
      }
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) setState(() => _saveError = 'save_failed');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
