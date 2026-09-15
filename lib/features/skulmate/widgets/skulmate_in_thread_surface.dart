import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/skulmate/models/tutor_session_models.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_surface_styles.dart';

/// Compact practice card inside the tutor thread.
class SkulMateInThreadSurface extends StatefulWidget {
  final PracticeSurface surface;
  final Future<void> Function(bool correct) onOutcome;

  const SkulMateInThreadSurface({
    super.key,
    required this.surface,
    required this.onOutcome,
  });

  @override
  State<SkulMateInThreadSurface> createState() =>
      _SkulMateInThreadSurfaceState();
}

class _SkulMateInThreadSurfaceState extends State<SkulMateInThreadSurface> {
  int _index = 0;
  int? _picked;
  bool _revealed = false;
  bool _done = false;

  Map<String, dynamic> get _item =>
      widget.surface.items[_index.clamp(0, widget.surface.items.length - 1)];

  @override
  Widget build(BuildContext context) {
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentPurple,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            blank ?? question,
            style: GoogleFonts.plusJakartaSans(
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
                onPressed: () => _finish(true),
                child: const Text('Got it'),
              ),
            ),
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
    if (_done) return;
    if (_index < widget.surface.items.length - 1) {
      setState(() {
        _index += 1;
        _picked = null;
        _revealed = false;
      });
      return;
    }
    setState(() => _done = true);
    await widget.onOutcome(correct);
  }
}
