/// skulMate Character Model
/// 
/// Playable learner avatars for SkulMate games (human characters).
/// The PrepSkul **brand bear** is separate — see `SkulMateMascotMediaWidget` and `docs/MASCOT_IMAGE_PROMPTS.md`.
/// Characters are organized by age groups and gender.
class SkulMateCharacter {
  final String id;
  final String name;
  final AgeGroup ageGroup;
  final Gender gender;
  final String assetPath; // Path to character image asset
  final String description;
  final List<String> motivationalPhrases; // Phrases the character says

  const SkulMateCharacter({
    required this.id,
    required this.name,
    required this.ageGroup,
    required this.gender,
    required this.assetPath,
    required this.description,
    required this.motivationalPhrases,
  });

  /// Get character display name
  String get displayName => name;

  /// Get age group label
  String get ageGroupLabel {
    switch (ageGroup) {
      case AgeGroup.elementary:
        return 'Elementary (5-10 years)';
      case AgeGroup.middle:
        return 'Middle School (11-14 years)';
      case AgeGroup.high:
        return 'High School (15-18 years)';
    }
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ageGroup': ageGroup.name,
        'gender': gender.name,
        'assetPath': assetPath,
        'description': description,
        'motivationalPhrases': motivationalPhrases,
      };

  /// Create from JSON
  factory SkulMateCharacter.fromJson(Map<String, dynamic> json) {
    return SkulMateCharacter(
      id: json['id'] as String,
      name: json['name'] as String,
      ageGroup: AgeGroup.values.firstWhere(
        (e) => e.name == json['ageGroup'],
        orElse: () => AgeGroup.middle,
      ),
      gender: Gender.values.firstWhere(
        (e) => e.name == json['gender'],
        orElse: () => Gender.male,
      ),
      assetPath: json['assetPath'] as String,
      description: json['description'] as String? ?? '',
      motivationalPhrases: (json['motivationalPhrases'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkulMateCharacter &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SkulMateCharacter(id: $id, name: $name, ageGroup: $ageGroup, gender: $gender)';
}

/// Age groups for character selection
enum AgeGroup {
  elementary, // 5-10 years
  middle,     // 11-14 years
  high,        // 15-18 years
}

/// Gender options for characters
enum Gender {
  male,
  female,
}

/// Predefined skulMate characters
class SkulMateCharacters {
  // Elementary Age Group (5-10 years)
  static const SkulMateCharacter elementaryMale = SkulMateCharacter(
    id: 'elementary_male',
    name: 'Mbiya',
    ageGroup: AgeGroup.elementary,
    gender: Gender.male,
    assetPath: 'assets/characters/elementary_male.png',
    description: 'A friendly Cameroonian boy ready to learn and explore!',
    motivationalPhrases: [
      'Great job! 🎉',
      'You\'re doing amazing!',
      'Keep it up!',
      'Wow, you\'re smart!',
    ],
  );

  static const SkulMateCharacter elementaryFemale = SkulMateCharacter(
    id: 'elementary_female',
    name: 'Nchia',
    ageGroup: AgeGroup.elementary,
    gender: Gender.female,
    assetPath: 'assets/characters/elementary_female.png',
    description: 'A cheerful Cameroonian girl who loves to explore!',
    motivationalPhrases: [
      'Awesome work! 🌟',
      'You\'re so clever!',
      'Fantastic!',
      'You\'re a star!',
    ],
  );

  // Middle School Age Group (11-14 years)
  static const SkulMateCharacter middleMale = SkulMateCharacter(
    id: 'middle_male',
    name: 'Etonge',
    ageGroup: AgeGroup.middle,
    gender: Gender.male,
    assetPath: 'assets/characters/middle_male.png',
    description: 'A confident Cameroonian teen ready to tackle challenges!',
    motivationalPhrases: [
      'Excellent! 🚀',
      'You\'ve got this!',
      'Outstanding!',
      'Keep pushing forward!',
    ],
  );

  static const SkulMateCharacter middleFemale = SkulMateCharacter(
    id: 'middle_female',
    name: 'Aseh',
    ageGroup: AgeGroup.middle,
    gender: Gender.female,
    assetPath: 'assets/characters/middle_female.png',
    description: 'A determined Cameroonian teen who never gives up!',
    motivationalPhrases: [
      'Brilliant! 💪',
      'You\'re crushing it!',
      'Amazing progress!',
      'You\'re unstoppable!',
    ],
  );

  // High School Age Group (15-18 years)
  static const SkulMateCharacter highMale = SkulMateCharacter(
    id: 'high_male',
    name: 'Achu',
    ageGroup: AgeGroup.high,
    gender: Gender.male,
    assetPath: 'assets/characters/high_male.png',
    description: 'A focused Cameroonian young man preparing for success!',
    motivationalPhrases: [
      'Outstanding work! 🎯',
      'You\'re on fire!',
      'Impressive!',
      'You\'re mastering this!',
    ],
  );

  static const SkulMateCharacter highFemale = SkulMateCharacter(
    id: 'high_female',
    name: 'Nde',
    ageGroup: AgeGroup.high,
    gender: Gender.female,
    assetPath: 'assets/characters/high_female.png',
    description: 'An ambitious Cameroonian young woman reaching for excellence!',
    motivationalPhrases: [
      'Exceptional! 🌟',
      'You\'re excelling!',
      'Incredible work!',
      'You\'re achieving greatness!',
    ],
  );

  /// Get all characters
  static List<SkulMateCharacter> get all => [
        elementaryMale,
        elementaryFemale,
        middleMale,
        middleFemale,
        highMale,
        highFemale,
      ];

  /// Get characters by age group
  static List<SkulMateCharacter> getByAgeGroup(AgeGroup ageGroup) {
    return all.where((char) => char.ageGroup == ageGroup).toList();
  }

  /// Get character by ID
  static SkulMateCharacter? getById(String id) {
    try {
      return all.firstWhere((char) => char.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get default character (middle school, male)
  static SkulMateCharacter get defaultCharacter => middleMale;
}
