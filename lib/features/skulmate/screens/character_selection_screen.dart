import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../models/skulmate_character_model.dart';
import '../services/character_selection_service.dart';
import '../widgets/skulmate_character_widget.dart';

/// Screen for selecting skulMate character
class CharacterSelectionScreen extends StatefulWidget {
  final bool isFirstTime; // If true, shows welcome message

  const CharacterSelectionScreen({
    Key? key,
    this.isFirstTime = false,
  }) : super(key: key);

  @override
  State<CharacterSelectionScreen> createState() => _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
  SkulMateCharacter? _selectedCharacter;
  AgeGroup _selectedAgeGroup = AgeGroup.middle;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentCharacter();
  }

  Future<void> _loadCurrentCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    safeSetState(() {
      _selectedCharacter = character;
      _selectedAgeGroup = character.ageGroup;
    });
  }

  Future<void> _saveSelection() async {
    if (_selectedCharacter == null) return;

    safeSetState(() {
      _isSaving = true;
    });

    try {
      await CharacterSelectionService.selectCharacter(_selectedCharacter!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedCharacter!.name} is now your learning companion! 🎉',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back or to next screen
        if (widget.isFirstTime) {
          Navigator.pushReplacementNamed(context, '/student-nav');
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving character selection. Please try again.',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      safeSetState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.isFirstTime ? 'Choose Your Companion' : 'Change Character',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isFirstTime) ...[
              // Welcome message
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Welcome to skulMate! 🎮',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choose a learning companion to join you on your journey!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textMedium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Age group selector
            Text(
              'Select Age Group',
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
                  child: _buildAgeGroupButton(
                    AgeGroup.elementary,
                    'Elementary\n(5-10)',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAgeGroupButton(
                    AgeGroup.middle,
                    'Middle\n(11-14)',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAgeGroupButton(
                    AgeGroup.high,
                    'High School\n(15-18)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Character selection
            Text(
              'Choose Your Character',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 16),
            _buildCharacterGrid(),

            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              onPressed: _selectedCharacter != null && !_isSaving
                  ? _saveSelection
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.isFirstTime ? 'Start Learning!' : 'Save Selection',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeGroupButton(AgeGroup ageGroup, String label) {
    final isSelected = _selectedAgeGroup == ageGroup;
    return GestureDetector(
      onTap: () {
        safeSetState(() {
          _selectedAgeGroup = ageGroup;
          _selectedCharacter = null; // Reset selection when age group changes
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : AppTheme.softBorder,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterGrid() {
    final characters = SkulMateCharacters.getByAgeGroup(_selectedAgeGroup);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        final character = characters[index];
        final isSelected = _selectedCharacter?.id == character.id;

        return GestureDetector(
          onTap: () {
            safeSetState(() {
              _selectedCharacter = character;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.accentBlue : AppTheme.softBorder,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.accentBlue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkulMateCharacterWidget(
                  character: character,
                  size: 100,
                  animated: isSelected,
                ),
                const SizedBox(height: 8),
                Text(
                  character.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  character.gender == Gender.male ? '👦' : '👧',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

