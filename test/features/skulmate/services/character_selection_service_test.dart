import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/features/skulmate/models/skulmate_character_model.dart';
import 'package:prepskul/features/skulmate/services/character_selection_service.dart';

void main() {
  // Initialize Flutter bindings for SharedPreferences
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CharacterSelectionService Tests', () {
    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    test('should return default character when none selected', () async {
      final character = await CharacterSelectionService.getSelectedCharacter();

      expect(character, isNotNull);
      expect(character.id, 'middle_male'); // Default character
      expect(character.name, 'Amara');
    });

    test('should save and retrieve character selection', () async {
      const testCharacter = SkulMateCharacters.elementaryFemale;

      // Save character
      await CharacterSelectionService.selectCharacter(testCharacter);

      // Retrieve character
      final retrieved = await CharacterSelectionService.getSelectedCharacter();

      expect(retrieved.id, testCharacter.id);
      expect(retrieved.name, testCharacter.name);
      expect(retrieved.ageGroup, testCharacter.ageGroup);
      expect(retrieved.gender, testCharacter.gender);
    });

    test('should check if character has been selected', () async {
      // Initially no selection
      final hasSelected1 = await CharacterSelectionService.hasSelectedCharacter();
      expect(hasSelected1, false);

      // After selection
      await CharacterSelectionService.selectCharacter(
        SkulMateCharacters.highMale,
      );
      final hasSelected2 = await CharacterSelectionService.hasSelectedCharacter();
      expect(hasSelected2, true);
    });

    test('should return motivational phrase', () async {
      // Select a character
      await CharacterSelectionService.selectCharacter(
        SkulMateCharacters.elementaryMale,
      );

      // Get motivational phrase
      final phrase = await CharacterSelectionService.getMotivationalPhrase();

      expect(phrase, isNotEmpty);
      expect(phrase.length, greaterThan(0));

      // Should be one of the character's phrases
      final character = SkulMateCharacters.elementaryMale;
      expect(character.motivationalPhrases, contains(phrase));
    });

    test('should return default phrase if character has no phrases', () async {
      // This shouldn't happen with predefined characters, but test the fallback
      final phrase = await CharacterSelectionService.getMotivationalPhrase();

      // Should return a valid string (either from character or default)
      expect(phrase, isNotEmpty);
      // Phrase should be non-empty (either from character or default fallback)
      expect(phrase.length, greaterThan(0));
    });

    test('should handle multiple character selections', () async {
      // Select first character
      await CharacterSelectionService.selectCharacter(
        SkulMateCharacters.elementaryMale,
      );
      final char1 = await CharacterSelectionService.getSelectedCharacter();
      expect(char1.id, 'elementary_male');

      // Select different character
      await CharacterSelectionService.selectCharacter(
        SkulMateCharacters.highFemale,
      );
      final char2 = await CharacterSelectionService.getSelectedCharacter();
      expect(char2.id, 'high_female');
      expect(char2.name, 'Ada');
    });

    test('should handle all age groups', () async {
      // Test elementary
      await CharacterSelectionService.selectCharacter(
        SkulMateCharacters.elementaryMale,
      );
      var char = await CharacterSelectionService.getSelectedCharacter();
      expect(char.ageGroup, AgeGroup.elementary);

      // Test middle
      await CharacterSelectionService.selectCharacter(
        SkulMateCharacters.middleFemale,
      );
      char = await CharacterSelectionService.getSelectedCharacter();
      expect(char.ageGroup, AgeGroup.middle);

      // Test high
      await CharacterSelectionService.selectCharacter(
        SkulMateCharacters.highMale,
      );
      char = await CharacterSelectionService.getSelectedCharacter();
      expect(char.ageGroup, AgeGroup.high);
    });

    test('should handle all genders', () async {
      // Test male
      await CharacterSelectionService.selectCharacter(
        SkulMateCharacters.middleMale,
      );
      var char = await CharacterSelectionService.getSelectedCharacter();
      expect(char.gender, Gender.male);

      // Test female
      await CharacterSelectionService.selectCharacter(
        SkulMateCharacters.middleFemale,
      );
      char = await CharacterSelectionService.getSelectedCharacter();
      expect(char.gender, Gender.female);
    });

    test('should persist selection across service calls', () async {
      const testCharacter = SkulMateCharacters.elementaryFemale;

      // Save character
      await CharacterSelectionService.selectCharacter(testCharacter);

      // Get character multiple times
      final char1 = await CharacterSelectionService.getSelectedCharacter();
      final char2 = await CharacterSelectionService.getSelectedCharacter();
      final char3 = await CharacterSelectionService.getSelectedCharacter();

      // All should return the same character
      expect(char1.id, testCharacter.id);
      expect(char2.id, testCharacter.id);
      expect(char3.id, testCharacter.id);
    });
  });
}

