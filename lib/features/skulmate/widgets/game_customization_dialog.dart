import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Dialog for customizing game generation options
class GameCustomizationDialog extends StatefulWidget {
  final String? initialTopic;
  final String? initialDifficulty;
  final int? initialNumQuestions;

  const GameCustomizationDialog({
    Key? key,
    this.initialTopic,
    this.initialDifficulty,
    this.initialNumQuestions,
  }) : super(key: key);

  @override
  State<GameCustomizationDialog> createState() => _GameCustomizationDialogState();
}

class _GameCustomizationDialogState extends State<GameCustomizationDialog> {
  String? _selectedDifficulty;
  String? _selectedTopic;
  int? _numQuestions;

  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _questionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = widget.initialDifficulty ?? 'medium';
    _selectedTopic = widget.initialTopic;
    _numQuestions = widget.initialNumQuestions ?? 10;
    
    if (_selectedTopic != null) {
      _topicController.text = _selectedTopic!;
    }
    _questionsController.text = _numQuestions.toString();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _questionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.tune,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Customize Your Game',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Difficulty Selection
            Text(
              'Difficulty Level',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDifficultyChip('Easy', 'easy', Colors.green),
                const SizedBox(width: 8),
                _buildDifficultyChip('Medium', 'medium', AppTheme.primaryColor),
                const SizedBox(width: 8),
                _buildDifficultyChip('Hard', 'hard', Colors.orange),
              ],
            ),
            const SizedBox(height: 24),
            
            // Topic/Subject
            Text(
              'Topic/Subject (Optional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                hintText: 'e.g., Mathematics, Biology, History',
                hintStyle: GoogleFonts.poppins(
                  color: AppTheme.textLight,
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.textLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
              onChanged: (value) {
                _selectedTopic = value.isEmpty ? null : value;
              },
            ),
            const SizedBox(height: 24),
            
            // Number of Questions
            Text(
              'Number of Questions',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '10-20',
                      hintStyle: GoogleFonts.poppins(
                        color: AppTheme.textLight,
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.textLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: GoogleFonts.poppins(fontSize: 14),
                    onChanged: (value) {
                      final num = int.tryParse(value);
                      if (num != null && num >= 5 && num <= 30) {
                        _numQuestions = num;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '(5-30)',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: AppTheme.textLight),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final numQuestions = int.tryParse(_questionsController.text);
                      if (numQuestions != null && numQuestions >= 5 && numQuestions <= 30) {
                        Navigator.pop(context, {
                          'difficulty': _selectedDifficulty,
                          'topic': _selectedTopic,
                          'numQuestions': numQuestions,
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a number between 5 and 30'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'Generate',
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
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(String label, String value, Color color) {
    final isSelected = _selectedDifficulty == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDifficulty = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            border: Border.all(
              color: isSelected ? color : AppTheme.textLight,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? color : AppTheme.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

