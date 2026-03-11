import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../models/game_stats_model.dart';
import '../services/game_stats_service.dart';

/// Optional context to pass to game generation for better results
class GenerationContext {
  final String? topic;
  final String? difficulty;
  final String? gameType;

  const GenerationContext({
    this.topic,
    this.difficulty,
    this.gameType,
  });

  bool get isEmpty => topic == null && difficulty == null && gameType == null;
}

/// Bottom sheet for collecting optional context before game generation.
/// Returns GenerationContext on Continue, or null on Skip.
class GenerationContextSheet extends StatefulWidget {
  const GenerationContextSheet({super.key});

  static Future<GenerationContext?> show(BuildContext context) {
    return showModalBottomSheet<GenerationContext>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const Padding(
        padding: EdgeInsets.only(top: 48),
        child: GenerationContextSheet(),
      ),
    );
  }

  @override
  State<GenerationContextSheet> createState() => _GenerationContextSheetState();
}

class _GenerationContextSheetState extends State<GenerationContextSheet> {
  final TextEditingController _topicController = TextEditingController();
  String? _practiceType;
  String _gameType = 'auto';

  static const List<Map<String, String?>> _practiceOptions = [
    {'value': 'easy', 'label': 'Easy – Definitions', 'emoji': '📖'},
    {'value': 'medium', 'label': 'Medium – Facts & recall', 'emoji': '🧠'},
    {'value': 'hard', 'label': 'Hard – Problem solving', 'emoji': '🔢'},
    {'value': null, 'label': 'Mixed', 'emoji': '✨'},
  ];

  static const List<Map<String, String>> _gameTypeOptions = [
    {'value': 'auto', 'label': 'Auto (surprise me)', 'emoji': '🎲'},
    {'value': 'quiz', 'label': 'Quiz', 'emoji': '❓'},
    {'value': 'flashcards', 'label': 'Flashcards', 'emoji': '🃏'},
    {'value': 'matching', 'label': 'Matching', 'emoji': '🔗'},
  ];

  @override
  void initState() {
    super.initState();
    _prefillDifficultyFromStats();
  }

  Future<void> _prefillDifficultyFromStats() async {
    try {
      final GameStats stats = await GameStatsService.getStats();
      if (!mounted) return;

      String? recommended;
      if (stats.gamesPlayed < 3) {
        // New players: start easy so they build confidence
        recommended = 'easy';
      } else {
        final acc = stats.accuracy;
        if (acc >= 80) {
          recommended = 'hard';
        } else if (acc >= 50) {
          recommended = 'medium';
        } else {
          recommended = 'easy';
        }
      }

      setState(() {
        _practiceType = recommended;
      });
    } catch (_) {
      // If anything goes wrong, leave difficulty unset and let user choose
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  void _onContinue() {
    final topic = _topicController.text.trim();
    Navigator.pop(context, GenerationContext(
      topic: topic.isEmpty ? null : topic,
      difficulty: _practiceType,
      gameType: _gameType,
    ));
  }

  void _onSkip() {
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: PhosphorIcon(
                      PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill),
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick context (optional)',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Help us create a better game for you',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'What topic or subject?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _topicController,
                decoration: InputDecoration(
                  hintText: 'e.g. Biology, GCE Maths, SAT Vocabulary',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textLight,
                  ),
                  filled: true,
                  fillColor: AppTheme.softBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 20),
              Text(
                'What do you want to practice?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _practiceOptions.map((opt) {
                  final value = opt['value'];
                  final isSelected = _practiceType == value;
                  return FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    label: Text(
                      '${opt['emoji']} ${opt['label']}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    onSelected: (_) {
                      setState(() => _practiceType = value);
                    },
                    selectedColor: AppTheme.primaryColor,
                    backgroundColor: AppTheme.softBackground,
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.softBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text(
                'Preferred game type?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _gameTypeOptions.map((opt) {
                  final value = opt['value']!;
                  final isSelected = _gameType == value;
                  return FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    label: Text(
                      '${opt['emoji']} ${opt['label']}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    onSelected: (_) {
                      setState(() => _gameType = value);
                    },
                    selectedColor: AppTheme.primaryColor,
                    backgroundColor: AppTheme.softBackground,
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.softBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  TextButton(
                    onPressed: _onSkip,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Generate Game',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
