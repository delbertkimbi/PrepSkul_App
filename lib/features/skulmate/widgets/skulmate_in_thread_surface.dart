import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/skulmate/models/tutor_session_models.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_surface_styles.dart';

/// Compact practice card inside the tutor thread.
class SkulMateInThreadSurface extends StatefulWidget {
  final PracticeSurface surface;
  final Future<void> Function(bool correct) onOutcome;
  final Future<void> Function(bool correct, List<int?> answers)?
  onVerifiedOutcome;

  const SkulMateInThreadSurface({
    super.key,
    required this.surface,
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(options[i]),
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
          if (_done)
            Text(french ? 'Progression enregistrée' : 'Progress saved'),
        ],
      ),
    );
  }

  Future<void> _answerQuiz(int picked, int correctIndex) async {
    setState(() {
      _picked = picked;
      _revealed = true;
    });
    final correct = picked == correctIndex;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await _finish(correct);
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
