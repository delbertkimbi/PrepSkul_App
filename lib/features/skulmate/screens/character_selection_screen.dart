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
  List<SkulMateCharacter> _characters = [];
  SkulMateCharacter? _selectedCharacter;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
    _loadSelectedCharacter();
  }

  Future<void> _loadCharacters() async {
    final characters = SkulMateCharacters.all;
    safeSetState(() {
      _characters = characters;
      _isLoading = false;
    });
  }

  Future<void> _loadSelectedCharacter() async {
    final selected = await CharacterSelectionService.getSelectedCharacter();
    safeSetState(() {
      _selectedCharacter = selected;
    });
  }

  Future<void> _selectCharacter(SkulMateCharacter character) async {
    await CharacterSelectionService.selectCharacter(character);
    safeSetState(() {
      _selectedCharacter = character;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${character.name} selected!'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
      Navigator.pop(context);
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
          'Choose Your Character',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.isFirstTime)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Welcome! Choose a character to help you learn!',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  ..._characters.map((character) {
                    final isSelected = _selectedCharacter?.id == character.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () => _selectCharacter(character),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              SkulMateCharacterWidget(
                                character: character,
                                size: 60,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      character.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    Text(
                                      character.description,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: AppTheme.primaryColor,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}
