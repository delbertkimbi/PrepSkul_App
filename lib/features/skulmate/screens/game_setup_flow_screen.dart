import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import '../widgets/generation_context_sheet.dart';
import '../widgets/skulmate_mascot_media_widget.dart';
import '../models/game_stats_model.dart';
import '../services/game_stats_service.dart';
import '../services/game_sound_service.dart';

/// Full-screen, step-based flow for optional game setup (difficulty, subject, exam, game type).
/// Returns [GenerationContext] on completion, or null when skipped.
class GameSetupFlowScreen extends StatefulWidget {
  final String? initialGameType;

  const GameSetupFlowScreen({Key? key, this.initialGameType}) : super(key: key);

  @override
  State<GameSetupFlowScreen> createState() => _GameSetupFlowScreenState();
}

class _GameSetupFlowScreenState extends State<GameSetupFlowScreen> {
  static const int _totalSteps = 3;
  int _currentStep = 0;

  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _examOtherController = TextEditingController();
  String? _difficulty;
  String? _exam; // e.g. 'gce', 'sat', 'waec', 'igcse', 'other'
  String _gameType = 'auto';
  final GameSoundService _soundService = GameSoundService();

  static const List<Map<String, String?>> _difficultyOptions = [
    {'value': 'easy', 'label': 'Easy', 'subtitle': 'Definitions & recall'},
    {'value': 'medium', 'label': 'Medium', 'subtitle': 'Facts & application'},
    {'value': 'hard', 'label': 'Hard', 'subtitle': 'Problem solving'},
    {'value': null, 'label': 'Mixed', 'subtitle': 'Varied difficulty'},
  ];

  static const List<Map<String, dynamic>> _examOptions = [
    {'value': null, 'label': 'None'},
    // Cameroon-focused exams
    {'value': 'gce_ol', 'label': 'GCE Ordinary Level (O/L)'},
    {'value': 'gce_al', 'label': 'GCE Advanced Level (A/L)'},
    {'value': 'common_fslc', 'label': 'Common Entrance / FSLC'},
    {'value': 'cam_french', 'label': 'French / Baccalauréat exams'},
    // Regional & international exams
    {'value': 'waec', 'label': 'WAEC'},
    {'value': 'igcse', 'label': 'IGCSE'},
    {'value': 'sat', 'label': 'SAT'},
    {'value': 'act', 'label': 'ACT'},
    {'value': 'other', 'label': 'Other'},
  ];

  static const List<Map<String, dynamic>> _gameTypeOptions = [
    {'value': 'auto', 'label': 'Auto', 'subtitle': 'Surprise me', 'icon': Icons.auto_awesome},
    {'value': 'quiz', 'label': 'Quiz', 'subtitle': 'Multiple choice', 'icon': Icons.quiz},
    {'value': 'flashcards', 'label': 'Flashcards', 'subtitle': 'Flip & learn', 'icon': Icons.style},
    {'value': 'matching', 'label': 'Matching', 'subtitle': 'Match pairs', 'icon': Icons.link},
    {'value': 'fill_blank', 'label': 'Fill Blank', 'subtitle': 'Type missing words', 'icon': Icons.short_text},
    {'value': 'drag_drop', 'label': 'Drag & Drop', 'subtitle': 'Move into zones', 'icon': Icons.open_with},
    {'value': 'puzzle_pieces', 'label': 'Puzzle', 'subtitle': 'Piece together', 'icon': Icons.extension},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialGameType != null &&
        widget.initialGameType!.isNotEmpty) {
      _gameType = widget.initialGameType!;
    }
    _soundService.initialize();
    _prefillDifficulty();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _examOtherController.dispose();
    super.dispose();
  }

  Future<void> _prefillDifficulty() async {
    try {
      final GameStats stats = await GameStatsService.getStats();
      if (!mounted) return;
      String? recommended;
      if (stats.gamesPlayed < 3) {
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
      setState(() => _difficulty = recommended);
    } catch (_) {}
  }

  void _onSkip() {
    Navigator.pop(context, null);
  }

  void _onComplete() {
    _soundService.playClick();
    final topic = _topicController.text.trim();
    String? examLabel;
    if (_exam == 'other') {
      examLabel = _examOtherController.text.trim();
    } else if (_exam != null && _exam!.isNotEmpty) {
      try {
        final opt = _examOptions.cast<Map<String, dynamic>>().firstWhere(
          (e) => e['value'] == _exam,
        );
        examLabel = opt['label'] as String?;
      } catch (_) {}
    }
    final combinedTopic = [topic, if (examLabel != null && examLabel.isNotEmpty) examLabel].join(' – ');
    Navigator.pop(
      context,
      GenerationContext(
        topic: combinedTopic.isEmpty ? null : combinedTopic,
        difficulty: _difficulty,
        gameType: _gameType,
      ),
    );
  }

  void _onSelectGameType(String value) {
    setState(() => _gameType = value);
  }

  Color _gameTypeIconColor(String value) {
    switch (value) {
      case 'auto':
        return AppTheme.primaryColor;
      case 'quiz':
        return const Color(0xFF7E57C2); // purple
      case 'flashcards':
        return const Color(0xFFFF9800); // orange
      case 'matching':
        return const Color(0xFF29B6F6); // skyBlue
      case 'fill_blank':
        return const Color(0xFF43A047); // green
      case 'drag_drop':
        return const Color(0xFF4CAF50); // green
      case 'match3':
        return const Color(0xFF9C27B0); // purple
      case 'bubble_pop':
        return const Color(0xFFE91E63); // pink
      case 'word_search':
        return AppTheme.accentBlue;
      case 'crossword':
        return const Color(0xFFFF9800); // orange
      case 'simulation':
        return const Color(0xFF673AB7); // purple
      case 'mystery':
        return const Color(0xFFEC407A); // pink
      case 'escape_room':
        return const Color(0xFF03A9F4); // skyBlue
      case 'diagram_label':
        return AppTheme.textMedium;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _onSkip,
        ),
        title: Text(
          'Set up your game',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: _buildStepContent(),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: Colors.white,
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primaryColor : AppTheme.softBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepDifficulty();
      case 1:
        return _buildStepSubjectAndExam();
      case 2:
        return _buildStepGameType();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepDifficulty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Difficulty',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            Text(
              ' *',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.red.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Step 1 of $_totalSteps',
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 14),
        ..._difficultyOptions.map((opt) {
          final value = opt['value'];
          final isSelected = _difficulty == value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SelectableCard(
              title: opt['label']!,
              subtitle: opt['subtitle'],
              isSelected: isSelected,
              onTap: () => setState(() => _difficulty = value),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStepSubjectAndExam() {
    final showExamOther = _exam == 'other';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject & exam',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Step 2 of $_totalSteps',
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 14),
        Text(
          'Topic or subject',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _topicController,
          decoration: InputDecoration(
            hintText: 'e.g. Mathematics, Biology',
            hintStyle: GoogleFonts.poppins(color: AppTheme.textLight, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        const SizedBox(height: 14),
        Text(
          'Exam or standard',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.softBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _exam,
              isExpanded: true,
              hint: Text(
                'Select exam',
                style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textLight),
              ),
              items: _examOptions.map((opt) {
                final v = opt['value'] as String?;
                final label = opt['label'] as String;
                return DropdownMenuItem<String?>(
                  value: v,
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textDark),
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _exam = v),
            ),
          ),
        ),
        if (showExamOther) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _examOtherController,
            decoration: InputDecoration(
              hintText: 'Type your exam or standard',
              hintStyle: GoogleFonts.poppins(color: AppTheme.textLight, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: GoogleFonts.poppins(fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _buildStepGameType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Game type',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            Text(
              ' *',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.red.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Step 3 of $_totalSteps',
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _gameTypeOptions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
          ),
          itemBuilder: (context, index) {
            final option = _gameTypeOptions[index];
            final value = option['value'] as String;
            return _GameTypeCard(
              value: value,
              label: option['label'] as String,
              subtitle: option['subtitle'] as String,
              icon: option['icon'] as IconData,
              iconColor: _gameTypeIconColor(value),
              isSelected: _gameType == value,
              isInactive: false,
              onTap: () => _onSelectGameType(value),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _soundService.playClick();
                    setState(() => _currentStep--);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: AppTheme.primaryColor),
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: _currentStep > 0 ? 1 : 2,
              child: ElevatedButton(
                onPressed: _currentStep < _totalSteps - 1
                    ? () {
                        _soundService.playClick();
                        setState(() => _currentStep++);
                      }
                    : _onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _currentStep < _totalSteps - 1 ? 'Next' : 'Generate Game',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTypeCard extends StatelessWidget {
  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final bool isInactive;
  final VoidCallback onTap;

  const _GameTypeCard({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.isInactive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isInactive ? const Color(0xFFF3F4F6) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isInactive
                  ? const Color(0xFFD1D5DB)
                  : (isSelected ? iconColor : AppTheme.softBorder),
              width: isInactive ? 1 : (isSelected ? 2 : 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 32,
                color: isInactive ? const Color(0xFF9CA3AF) : iconColor,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isInactive ? const Color(0xFF6B7280) : AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isInactive ? const Color(0xFF9CA3AF) : AppTheme.textMedium,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableCard({
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.softBorder,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textDark.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: AppTheme.accentGreen,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
