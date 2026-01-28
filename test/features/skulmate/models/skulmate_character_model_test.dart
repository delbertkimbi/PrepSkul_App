import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/skulmate/models/skulmate_character_model.dart';

void main() {
  group('SkulMateCharacter Model Tests', () {
    test('should create character with all properties', () {
      const character = SkulMateCharacter(
        id: 'test_id',
        name: 'Test Character',
        ageGroup: AgeGroup.middle,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test description',
        motivationalPhrases: ['Great job!', 'Keep it up!'],
      );

      expect(character.id, 'test_id');
      expect(character.name, 'Test Character');
      expect(character.ageGroup, AgeGroup.middle);
      expect(character.gender, Gender.male);
      expect(character.assetPath, 'assets/test.png');
      expect(character.description, 'Test description');
      expect(character.motivationalPhrases, ['Great job!', 'Keep it up!']);
    });

    test('should return correct display name', () {
      const character = SkulMateCharacter(
        id: 'test',
        name: 'Kemi',
        ageGroup: AgeGroup.elementary,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test',
        motivationalPhrases: [],
      );

      expect(character.displayName, 'Kemi');
    });

    test('should return correct age group labels', () {
      const elementary = SkulMateCharacter(
        id: 'elementary',
        name: 'Test',
        ageGroup: AgeGroup.elementary,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test',
        motivationalPhrases: [],
      );

      const middle = SkulMateCharacter(
        id: 'middle',
        name: 'Test',
        ageGroup: AgeGroup.middle,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test',
        motivationalPhrases: [],
      );

      const high = SkulMateCharacter(
        id: 'high',
        name: 'Test',
        ageGroup: AgeGroup.high,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test',
        motivationalPhrases: [],
      );

      expect(elementary.ageGroupLabel, 'Elementary (5-10 years)');
      expect(middle.ageGroupLabel, 'Middle School (11-14 years)');
      expect(high.ageGroupLabel, 'High School (15-18 years)');
    });

    test('should convert to JSON correctly', () {
      const character = SkulMateCharacter(
        id: 'test_id',
        name: 'Test Character',
        ageGroup: AgeGroup.middle,
        gender: Gender.female,
        assetPath: 'assets/test.png',
        description: 'Test description',
        motivationalPhrases: ['Phrase 1', 'Phrase 2'],
      );

      final json = character.toJson();

      expect(json['id'], 'test_id');
      expect(json['name'], 'Test Character');
      expect(json['ageGroup'], 'middle');
      expect(json['gender'], 'female');
      expect(json['assetPath'], 'assets/test.png');
      expect(json['description'], 'Test description');
      expect(json['motivationalPhrases'], ['Phrase 1', 'Phrase 2']);
    });

    test('should create from JSON correctly', () {
      final json = {
        'id': 'test_id',
        'name': 'Test Character',
        'ageGroup': 'middle',
        'gender': 'female',
        'assetPath': 'assets/test.png',
        'description': 'Test description',
        'motivationalPhrases': ['Phrase 1', 'Phrase 2'],
      };

      final character = SkulMateCharacter.fromJson(json);

      expect(character.id, 'test_id');
      expect(character.name, 'Test Character');
      expect(character.ageGroup, AgeGroup.middle);
      expect(character.gender, Gender.female);
      expect(character.assetPath, 'assets/test.png');
      expect(character.description, 'Test description');
      expect(character.motivationalPhrases, ['Phrase 1', 'Phrase 2']);
    });

    test('should handle missing optional fields in JSON', () {
      final json = {
        'id': 'test_id',
        'name': 'Test Character',
        'ageGroup': 'middle',
        'gender': 'male',
        'assetPath': 'assets/test.png',
      };

      final character = SkulMateCharacter.fromJson(json);

      expect(character.description, '');
      expect(character.motivationalPhrases, []);
    });

    test('should use default values for invalid enum in JSON', () {
      final json = {
        'id': 'test_id',
        'name': 'Test Character',
        'ageGroup': 'invalid',
        'gender': 'invalid',
        'assetPath': 'assets/test.png',
      };

      final character = SkulMateCharacter.fromJson(json);

      // Should default to middle and male
      expect(character.ageGroup, AgeGroup.middle);
      expect(character.gender, Gender.male);
    });

    test('should implement equality correctly', () {
      const character1 = SkulMateCharacter(
        id: 'test_id',
        name: 'Test',
        ageGroup: AgeGroup.middle,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test',
        motivationalPhrases: [],
      );

      const character2 = SkulMateCharacter(
        id: 'test_id',
        name: 'Different Name',
        ageGroup: AgeGroup.elementary,
        gender: Gender.female,
        assetPath: 'assets/different.png',
        description: 'Different',
        motivationalPhrases: ['Different'],
      );

      const character3 = SkulMateCharacter(
        id: 'different_id',
        name: 'Test',
        ageGroup: AgeGroup.middle,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test',
        motivationalPhrases: [],
      );

      // Same ID = equal
      expect(character1 == character2, true);
      // Different ID = not equal
      expect(character1 == character3, false);
    });
  });

  group('SkulMateCharacters Predefined Characters', () {
    test('should have all 6 characters', () {
      final all = SkulMateCharacters.all;
      expect(all.length, 6);
    });

    test('should have correct character IDs', () {
      final all = SkulMateCharacters.all;
      final ids = all.map((c) => c.id).toList();

      expect(ids, contains('elementary_male'));
      expect(ids, contains('elementary_female'));
      expect(ids, contains('middle_male'));
      expect(ids, contains('middle_female'));
      expect(ids, contains('high_male'));
      expect(ids, contains('high_female'));
    });

    test('should have Cameroonian names', () {
      expect(SkulMateCharacters.elementaryMale.name, 'Kemi');
      expect(SkulMateCharacters.elementaryFemale.name, 'Nkem');
      expect(SkulMateCharacters.middleMale.name, 'Amara');
      expect(SkulMateCharacters.middleFemale.name, 'Zara');
      expect(SkulMateCharacters.highMale.name, 'Kofi');
      expect(SkulMateCharacters.highFemale.name, 'Ada');
    });

    test('should have motivational phrases for all characters', () {
      final all = SkulMateCharacters.all;
      for (final character in all) {
        expect(character.motivationalPhrases.length, greaterThan(0),
            reason: '${character.name} should have motivational phrases');
      }
    });

    test('should get characters by age group', () {
      final elementary = SkulMateCharacters.getByAgeGroup(AgeGroup.elementary);
      final middle = SkulMateCharacters.getByAgeGroup(AgeGroup.middle);
      final high = SkulMateCharacters.getByAgeGroup(AgeGroup.high);

      expect(elementary.length, 2);
      expect(middle.length, 2);
      expect(high.length, 2);

      expect(elementary.every((c) => c.ageGroup == AgeGroup.elementary), true);
      expect(middle.every((c) => c.ageGroup == AgeGroup.middle), true);
      expect(high.every((c) => c.ageGroup == AgeGroup.high), true);
    });

    test('should get character by ID', () {
      final character = SkulMateCharacters.getById('middle_male');
      expect(character, isNotNull);
      expect(character!.name, 'Amara');
      expect(character.ageGroup, AgeGroup.middle);
      expect(character.gender, Gender.male);
    });

    test('should return null for invalid ID', () {
      final character = SkulMateCharacters.getById('invalid_id');
      expect(character, isNull);
    });

    test('should have default character', () {
      final defaultChar = SkulMateCharacters.defaultCharacter;
      expect(defaultChar.id, 'middle_male');
      expect(defaultChar.name, 'Amara');
    });
  });
}





import 'package:prepskul/features/skulmate/models/skulmate_character_model.dart';

void main() {
  group('SkulMateCharacter Model Tests', () {
    test('should create character with all properties', () {
      const character = SkulMateCharacter(
        id: 'test_id',
        name: 'Test Character',
        ageGroup: AgeGroup.middle,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test description',
        motivationalPhrases: ['Great job!', 'Keep it up!'],
      );

      expect(character.id, 'test_id');
      expect(character.name, 'Test Character');
      expect(character.ageGroup, AgeGroup.middle);
      expect(character.gender, Gender.male);
      expect(character.assetPath, 'assets/test.png');
      expect(character.description, 'Test description');
      expect(character.motivationalPhrases, ['Great job!', 'Keep it up!']);
    });

    test('should return correct display name', () {
      const character = SkulMateCharacter(
        id: 'test',
        name: 'Kemi',
        ageGroup: AgeGroup.elementary,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test',
        motivationalPhrases: [],
      );

      expect(character.displayName, 'Kemi');
    });

    test('should return correct age group labels', () {
      const elementary = SkulMateCharacter(
        id: 'elementary',
        name: 'Test',
        ageGroup: AgeGroup.elementary,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test',
        motivationalPhrases: [],
      );

      const middle = SkulMateCharacter(
        id: 'middle',
        name: 'Test',
        ageGroup: AgeGroup.middle,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test',
        motivationalPhrases: [],
      );

      const high = SkulMateCharacter(
        id: 'high',
        name: 'Test',
        ageGroup: AgeGroup.high,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test',
        motivationalPhrases: [],
      );

      expect(elementary.ageGroupLabel, 'Elementary (5-10 years)');
      expect(middle.ageGroupLabel, 'Middle School (11-14 years)');
      expect(high.ageGroupLabel, 'High School (15-18 years)');
    });

    test('should convert to JSON correctly', () {
      const character = SkulMateCharacter(
        id: 'test_id',
        name: 'Test Character',
        ageGroup: AgeGroup.middle,
        gender: Gender.female,
        assetPath: 'assets/test.png',
        description: 'Test description',
        motivationalPhrases: ['Phrase 1', 'Phrase 2'],
      );

      final json = character.toJson();

      expect(json['id'], 'test_id');
      expect(json['name'], 'Test Character');
      expect(json['ageGroup'], 'middle');
      expect(json['gender'], 'female');
      expect(json['assetPath'], 'assets/test.png');
      expect(json['description'], 'Test description');
      expect(json['motivationalPhrases'], ['Phrase 1', 'Phrase 2']);
    });

    test('should create from JSON correctly', () {
      final json = {
        'id': 'test_id',
        'name': 'Test Character',
        'ageGroup': 'middle',
        'gender': 'female',
        'assetPath': 'assets/test.png',
        'description': 'Test description',
        'motivationalPhrases': ['Phrase 1', 'Phrase 2'],
      };

      final character = SkulMateCharacter.fromJson(json);

      expect(character.id, 'test_id');
      expect(character.name, 'Test Character');
      expect(character.ageGroup, AgeGroup.middle);
      expect(character.gender, Gender.female);
      expect(character.assetPath, 'assets/test.png');
      expect(character.description, 'Test description');
      expect(character.motivationalPhrases, ['Phrase 1', 'Phrase 2']);
    });

    test('should handle missing optional fields in JSON', () {
      final json = {
        'id': 'test_id',
        'name': 'Test Character',
        'ageGroup': 'middle',
        'gender': 'male',
        'assetPath': 'assets/test.png',
      };

      final character = SkulMateCharacter.fromJson(json);

      expect(character.description, '');
      expect(character.motivationalPhrases, []);
    });

    test('should use default values for invalid enum in JSON', () {
      final json = {
        'id': 'test_id',
        'name': 'Test Character',
        'ageGroup': 'invalid',
        'gender': 'invalid',
        'assetPath': 'assets/test.png',
      };

      final character = SkulMateCharacter.fromJson(json);

      // Should default to middle and male
      expect(character.ageGroup, AgeGroup.middle);
      expect(character.gender, Gender.male);
    });

    test('should implement equality correctly', () {
      const character1 = SkulMateCharacter(
        id: 'test_id',
        name: 'Test',
        ageGroup: AgeGroup.middle,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test',
        motivationalPhrases: [],
      );

      const character2 = SkulMateCharacter(
        id: 'test_id',
        name: 'Different Name',
        ageGroup: AgeGroup.elementary,
        gender: Gender.female,
        assetPath: 'assets/different.png',
        description: 'Different',
        motivationalPhrases: ['Different'],
      );

      const character3 = SkulMateCharacter(
        id: 'different_id',
        name: 'Test',
        ageGroup: AgeGroup.middle,
        gender: Gender.male,
        assetPath: 'assets/test.png',
        description: 'Test',
        motivationalPhrases: [],
      );

      // Same ID = equal
      expect(character1 == character2, true);
      // Different ID = not equal
      expect(character1 == character3, false);
    });
  });

  group('SkulMateCharacters Predefined Characters', () {
    test('should have all 6 characters', () {
      final all = SkulMateCharacters.all;
      expect(all.length, 6);
    });

    test('should have correct character IDs', () {
      final all = SkulMateCharacters.all;
      final ids = all.map((c) => c.id).toList();

      expect(ids, contains('elementary_male'));
      expect(ids, contains('elementary_female'));
      expect(ids, contains('middle_male'));
      expect(ids, contains('middle_female'));
      expect(ids, contains('high_male'));
      expect(ids, contains('high_female'));
    });

    test('should have Cameroonian names', () {
      expect(SkulMateCharacters.elementaryMale.name, 'Kemi');
      expect(SkulMateCharacters.elementaryFemale.name, 'Nkem');
      expect(SkulMateCharacters.middleMale.name, 'Amara');
      expect(SkulMateCharacters.middleFemale.name, 'Zara');
      expect(SkulMateCharacters.highMale.name, 'Kofi');
      expect(SkulMateCharacters.highFemale.name, 'Ada');
    });

    test('should have motivational phrases for all characters', () {
      final all = SkulMateCharacters.all;
      for (final character in all) {
        expect(character.motivationalPhrases.length, greaterThan(0),
            reason: '${character.name} should have motivational phrases');
      }
    });

    test('should get characters by age group', () {
      final elementary = SkulMateCharacters.getByAgeGroup(AgeGroup.elementary);
      final middle = SkulMateCharacters.getByAgeGroup(AgeGroup.middle);
      final high = SkulMateCharacters.getByAgeGroup(AgeGroup.high);

      expect(elementary.length, 2);
      expect(middle.length, 2);
      expect(high.length, 2);

      expect(elementary.every((c) => c.ageGroup == AgeGroup.elementary), true);
      expect(middle.every((c) => c.ageGroup == AgeGroup.middle), true);
      expect(high.every((c) => c.ageGroup == AgeGroup.high), true);
    });

    test('should get character by ID', () {
      final character = SkulMateCharacters.getById('middle_male');
      expect(character, isNotNull);
      expect(character!.name, 'Amara');
      expect(character.ageGroup, AgeGroup.middle);
      expect(character.gender, Gender.male);
    });

    test('should return null for invalid ID', () {
      final character = SkulMateCharacters.getById('invalid_id');
      expect(character, isNull);
    });

    test('should have default character', () {
      final defaultChar = SkulMateCharacters.defaultCharacter;
      expect(defaultChar.id, 'middle_male');
      expect(defaultChar.name, 'Amara');
    });
  });
}












