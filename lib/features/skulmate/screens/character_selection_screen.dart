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
  AgeGroup? _selectedAgeGroup;
  SkulMateCharacter? _selectedCharacter;  @override
  void initState() {
    super.initState();
    _loadCurrentCharacter();
  }  Future<void> _loadCurrentCharacter() async {
    final character = await CharacterSelectionService.getSelectedCharacter();
    safeSetState(() {
      _selectedCharacter = character;
      _selectedAgeGroup = character.ageGroup;
    });
  }  Future<void> _selectCharacter(SkulMateCharacter character) async {
    safeSetState(() => _selectedCharacter = character);
    await CharacterSelectionService.selectCharacter(character);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${character.name} selected!'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
      
      if (widget.isFirstTime) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isFirstTime ? 'Choose Your Companion' : 'Change Character',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isFirstTime) ...[
              Text(
                'Welcome to skulMate!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a companion to help you learn',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 32),
            ],
            Text(
              'Select Age Group',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAgeGroupButton(AgeGroup.elementary, 'Elementary\n(5-10)'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAgeGroupButton(AgeGroup.middle, 'Middle School\n(11-14)'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAgeGroupButton(AgeGroup.high, 'High School\n(15-18)'),
                ),
              ],
            ),
            if (_selectedAgeGroup != null) ...[
              const SizedBox(height: 32),
              Text(
                'Select Character',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: SkulMateCharacters.getByAgeGroup(_selectedAgeGroup!).length,
                itemBuilder: (context, index) {
                  final character = SkulMateCharacters.getByAgeGroup(_selectedAgeGroup!)[index];
                  final isSelected = _selectedCharacter?.id == character.id;
                  
                  return InkWell(
                    onTap: () => _selectCharacter(character),
                    child: Card(
                      elevation: isSelected ? 4 : 1,
                      color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SkulMateCharacterWidget(
                            character: character,
                            size: 80,
                            animated: true,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            character.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppTheme.primaryColor : Colors.black,
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, color: AppTheme.primaryColor),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAgeGroupButton(AgeGroup ageGroup, String label) {
    final isSelected = _selectedAgeGroup == ageGroup;
    return ElevatedButton(
      onPressed: () => safeSetState(() => _selectedAgeGroup = ageGroup),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppTheme.primaryColor : Colors.grey[200],
        padding: EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}