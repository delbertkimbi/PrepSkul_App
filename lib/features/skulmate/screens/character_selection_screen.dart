import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import '../models/skulmate_character_model.dart';
import '../services/character_selection_service.dart';
import '../widgets/skulmate_character_widget.dart';
import '../widgets/skulmate_game_app_bar.dart';
import '../widgets/skulmate_companion_banner.dart';
import 'skulmate_upload_screen.dart';

/// Screen for selecting skulMate character
class CharacterSelectionScreen extends StatefulWidget {
  final bool isFirstTime;
  final bool popWhenDone;

  const CharacterSelectionScreen({
    super.key,
    this.isFirstTime = false,
    this.popWhenDone = false,
  });

  @override
  State<CharacterSelectionScreen> createState() =>
      _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
  AgeGroup? _selectedAgeGroup;
  SkulMateCharacter? _selectedCharacter;

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

  void _finishFirstTimeFlow() {
    if (widget.popWhenDone) {
      Navigator.pop(context, true);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SkulMateUploadScreen()),
    );
  }

  void _skipToUpload() {
    if (widget.isFirstTime) {
      _finishFirstTimeFlow();
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SkulMateUploadScreen()),
    );
  }

  /// Only updates selection in UI so user can preview before explicit save.
  void _selectCharacter(SkulMateCharacter character) {
    safeSetState(() => _selectedCharacter = character);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${character.name} selected. Tap Continue to confirm.'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _continueWithCharacter() async {
    if (_selectedCharacter == null) return;
    await CharacterSelectionService.selectCharacter(_selectedCharacter!);
    if (!mounted) return;
    if (widget.isFirstTime) {
      _finishFirstTimeFlow();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedAgeGroup = _selectedAgeGroup;
    final ageGroupCharacters = selectedAgeGroup == null
        ? const <SkulMateCharacter>[]
        : SkulMateCharacters.getByAgeGroup(selectedAgeGroup);

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: SkulMateGameAppBar(
        title: widget.isFirstTime ? 'Choose Your Companion' : 'Change Character',
        actions: widget.isFirstTime
            ? [
                TextButton(
                  onPressed: _skipToUpload,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isFirstTime) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.16),
                      AppTheme.primaryLight.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to skulMate!',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pick a companion that matches your style.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            SkulMateCompanionBanner(
              tone: CompanionTone.tip,
              message: _selectedCharacter == null
                  ? 'Choose your learner character for gameplay identity. I stay as your fixed SkulMate guide.'
                  : 'Nice choice. I will guide you while ${_selectedCharacter!.name} represents your learner in games.',
              celebrate: _selectedCharacter != null,
            ),
            const SizedBox(height: 14),
            Text(
              'Select Age Group',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildAgeGroupButton(
                    ageGroup: AgeGroup.elementary,
                    label: 'Elementary',
                    ageRange: '5-10',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildAgeGroupButton(
                    ageGroup: AgeGroup.middle,
                    label: 'Middle',
                    ageRange: '11-14',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildAgeGroupButton(
                    ageGroup: AgeGroup.high,
                    label: 'High',
                    ageRange: '15-18',
                  ),
                ),
              ],
            ),
            if (selectedAgeGroup != null) ...[
              const SizedBox(height: 22),
              Text(
                'Select Character',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.86,
                ),
                itemCount: ageGroupCharacters.length,
                itemBuilder: (context, index) {
                  final character = ageGroupCharacters[index];
                  final isSelected = _selectedCharacter?.id == character.id;
                  return _buildCharacterCard(
                    character: character,
                    isSelected: isSelected,
                  );
                },
              ),
            ],
            if (_selectedCharacter != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _continueWithCharacter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterCard({
    required SkulMateCharacter character,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _selectCharacter(character),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.16),
                      AppTheme.primaryLight.withValues(alpha: 0.1),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.surfaceColor, Color(0xFFF7FAFF)],
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.7)
                  : AppTheme.softBorder,
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryDark.withValues(
                  alpha: isSelected ? 0.2 : 0.08,
                ),
                blurRadius: isSelected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkulMateCharacterWidget(
                character: character,
                size: 72,
                animated: true,
                showName: false,
              ),
              const SizedBox(height: 8),
              Text(
                character.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppTheme.primaryDark : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                character.gender == Gender.female ? 'Female' : 'Male',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: isSelected ? AppTheme.primaryColor : AppTheme.softBorder,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgeGroupButton({
    required AgeGroup ageGroup,
    required String label,
    required String ageRange,
  }) {
    final isSelected = _selectedAgeGroup == ageGroup;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          safeSetState(() {
            _selectedAgeGroup = ageGroup;
            if (_selectedCharacter?.ageGroup != ageGroup) {
              _selectedCharacter = null;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withValues(alpha: 0.18),
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '($ageRange)',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white70 : AppTheme.textMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}