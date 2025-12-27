# skulMate Character System

A comprehensive character system for skulMate games, similar to Duo from Duolingo, with age-appropriate characters for different learner groups.

## Overview

The character system provides:
- **3 Age Groups**: Elementary (5-10), Middle School (11-14), High School (15-18)
- **2 Gender Options**: Male and Female for each age group
- **6 Total Characters**: Skully, Skylar, Max, Maya, Alex, Aria
- **Cross-Device Sync**: Character selection stored in database and local preferences
- **Game Integration**: Characters appear in all game screens with motivational messages

## Architecture

### Models
- **`SkulMateCharacter`** (`models/skulmate_character_model.dart`)
  - Character data model with age group, gender, asset path, and motivational phrases
  - Predefined characters in `SkulMateCharacters` class

### Services
- **`CharacterSelectionService`** (`services/character_selection_service.dart`)
  - Manages character selection and persistence
  - Syncs between database and local preferences
  - Provides motivational phrases

### Widgets
- **`SkulMateCharacterWidget`** (`widgets/skulmate_character_widget.dart`)
  - Animated character display
  - Compact version for game screens
  - Message bubble support

### Screens
- **`CharacterSelectionScreen`** (`screens/character_selection_screen.dart`)
  - Age group selection
  - Character selection grid
  - First-time onboarding support

## Usage

### 1. Character Selection (First Time)

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => CharacterSelectionScreen(isFirstTime: true),
  ),
);
```

### 2. Get Selected Character

```dart
final character = await CharacterSelectionService.getSelectedCharacter();
```

### 3. Display Character in Games

```dart
SkulMateCharacterWidget(
  character: character,
  size: 100,
  animated: true,
  showName: true,
)
```

### 4. Get Motivational Message

```dart
final phrase = await CharacterSelectionService.getMotivationalPhrase();
// Returns: "Great job! 🎉", "You're doing amazing!", etc.
```

### 5. Change Character

```dart
await CharacterSelectionService.selectCharacter(newCharacter);
```

## Character Details

### Elementary (5-10 years)
- **Kemi** (Male) - Friendly young learner
- **Nkem** (Female) - Cheerful explorer

### Middle School (11-14 years)
- **Amara** (Male) - Confident challenger
- **Zara** (Female) - Determined learner

### High School (15-18 years)
- **Kofi** (Male) - Focused achiever
- **Ada** (Female) - Ambitious learner

## Database Schema

Migration `032_add_skulmate_character.sql` adds:
- `profiles.skulmate_character_id` (TEXT) - Stores selected character ID

## Asset Requirements

Add character images to `assets/characters/`:
- `elementary_male.png` - Skully
- `elementary_female.png` - Skylar
- `middle_male.png` - Max
- `middle_female.png` - Maya
- `high_male.png` - Alex
- `high_female.png` - Aria

**Specifications:**
- Format: PNG (transparent background recommended)
- Size: 512x512px or higher (square)
- Style: Friendly, age-appropriate

## Integration Points

### Game Screens
Characters can be displayed in:
- Quiz game screen
- Flashcard game screen
- Matching game screen
- Fill-in-the-blank game screen
- Results screen

### Navigation
Route: `/skulmate/character-selection`
```dart
Navigator.pushNamed(
  context,
  '/skulmate/character-selection',
  arguments: {'isFirstTime': false},
);
```

## Future Enhancements

Potential additions:
- Character animations for correct/incorrect answers
- Character expressions (happy, sad, excited)
- Character achievements/badges
- Custom character creation
- Character voice messages
- Character progress tracking




A comprehensive character system for skulMate games, similar to Duo from Duolingo, with age-appropriate characters for different learner groups.

## Overview

The character system provides:
- **3 Age Groups**: Elementary (5-10), Middle School (11-14), High School (15-18)
- **2 Gender Options**: Male and Female for each age group
- **6 Total Characters**: Skully, Skylar, Max, Maya, Alex, Aria
- **Cross-Device Sync**: Character selection stored in database and local preferences
- **Game Integration**: Characters appear in all game screens with motivational messages

## Architecture

### Models
- **`SkulMateCharacter`** (`models/skulmate_character_model.dart`)
  - Character data model with age group, gender, asset path, and motivational phrases
  - Predefined characters in `SkulMateCharacters` class

### Services
- **`CharacterSelectionService`** (`services/character_selection_service.dart`)
  - Manages character selection and persistence
  - Syncs between database and local preferences
  - Provides motivational phrases

### Widgets
- **`SkulMateCharacterWidget`** (`widgets/skulmate_character_widget.dart`)
  - Animated character display
  - Compact version for game screens
  - Message bubble support

### Screens
- **`CharacterSelectionScreen`** (`screens/character_selection_screen.dart`)
  - Age group selection
  - Character selection grid
  - First-time onboarding support

## Usage

### 1. Character Selection (First Time)

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => CharacterSelectionScreen(isFirstTime: true),
  ),
);
```

### 2. Get Selected Character

```dart
final character = await CharacterSelectionService.getSelectedCharacter();
```

### 3. Display Character in Games

```dart
SkulMateCharacterWidget(
  character: character,
  size: 100,
  animated: true,
  showName: true,
)
```

### 4. Get Motivational Message

```dart
final phrase = await CharacterSelectionService.getMotivationalPhrase();
// Returns: "Great job! 🎉", "You're doing amazing!", etc.
```

### 5. Change Character

```dart
await CharacterSelectionService.selectCharacter(newCharacter);
```

## Character Details

### Elementary (5-10 years)
- **Kemi** (Male) - Friendly young learner
- **Nkem** (Female) - Cheerful explorer

### Middle School (11-14 years)
- **Amara** (Male) - Confident challenger
- **Zara** (Female) - Determined learner

### High School (15-18 years)
- **Kofi** (Male) - Focused achiever
- **Ada** (Female) - Ambitious learner

## Database Schema

Migration `032_add_skulmate_character.sql` adds:
- `profiles.skulmate_character_id` (TEXT) - Stores selected character ID

## Asset Requirements

Add character images to `assets/characters/`:
- `elementary_male.png` - Skully
- `elementary_female.png` - Skylar
- `middle_male.png` - Max
- `middle_female.png` - Maya
- `high_male.png` - Alex
- `high_female.png` - Aria

**Specifications:**
- Format: PNG (transparent background recommended)
- Size: 512x512px or higher (square)
- Style: Friendly, age-appropriate

## Integration Points

### Game Screens
Characters can be displayed in:
- Quiz game screen
- Flashcard game screen
- Matching game screen
- Fill-in-the-blank game screen
- Results screen

### Navigation
Route: `/skulmate/character-selection`
```dart
Navigator.pushNamed(
  context,
  '/skulmate/character-selection',
  arguments: {'isFirstTime': false},
);
```

## Future Enhancements

Potential additions:
- Character animations for correct/incorrect answers
- Character expressions (happy, sad, excited)
- Character achievements/badges
- Custom character creation
- Character voice messages
- Character progress tracking

