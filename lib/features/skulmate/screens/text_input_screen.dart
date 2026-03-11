import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/storage_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../services/skulmate_service.dart';
import '../widgets/generation_context_sheet.dart';
import 'game_setup_flow_screen.dart';
import 'game_generation_screen.dart';

/// Screen for entering game title and notes text manually
class TextInputScreen extends StatefulWidget {
  final String? childId;

  const TextInputScreen({Key? key, this.childId}) : super(key: key);

  @override
  State<TextInputScreen> createState() => _TextInputScreenState();
}

class _TextInputScreenState extends State<TextInputScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isGenerating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static const int _minTextLength = 50;

  Future<void> _generateGame() async {
    final text = _notesController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your notes'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (text.length < _minTextLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter at least $_minTextLength characters (you have ${text.length}). Add more detail for better games!'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    safeSetState(() => _isGenerating = true);

    try {
      final gameTitle = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : null;

      if (!mounted) return;
      final contextResult = await Navigator.push<GenerationContext?>(
        context,
        MaterialPageRoute(
          builder: (context) => const GameSetupFlowScreen(),
        ),
      );
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameGenerationScreen(
            text: text,
            topic: contextResult?.topic ?? gameTitle,
            difficulty: contextResult?.difficulty,
            gameType: contextResult?.gameType,
            childId: widget.childId,
          ),
        ),
      );

      safeSetState(() => _isGenerating = false);
    } catch (e) {
      LogService.error('Error generating game: $e');
      safeSetState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Enter Your Notes',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Title Input
            Text(
              'Game Title (Optional)',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter a title for your game...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[400],
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),

            const SizedBox(height: 24),

            // Notes Input
            Text(
              'Your Notes',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'At least 50 characters needed for better games.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _notesController,
              maxLines: 15,
              minLines: 10,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Type or paste your notes here...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[400],
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _notesController,
              builder: (context, value, _) {
                final len = value.text.trim().length;
                final ok = len >= _minTextLength;
                return Text(
                  '$len / $_minTextLength characters${ok ? ' ✓' : ''}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: ok ? Colors.green[700] : Colors.grey[600],
                    fontWeight: ok ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Generate Game Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isGenerating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Generating...',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Generate Game',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

