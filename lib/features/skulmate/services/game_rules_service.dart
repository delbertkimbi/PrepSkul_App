import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../models/game_model.dart';

/// Rules content for each game type
class GameRules {
  final String title;
  final String description;
  final List<String> steps;
  final String? exampleImage;

  GameRules({
    required this.title,
    required this.description,
    required this.steps,
    this.exampleImage,
  });
}

/// Service for managing game rules display
class GameRulesService {
  static const String _rulesPrefix = 'skulmate_rules_shown_';

  /// Get rules for a specific game type
  static GameRules getRulesForGameType(GameType type) {
    switch (type) {
      case GameType.quiz:
        return GameRules(
          title: 'Quiz Game',
          description: 'Test your knowledge with multiple choice questions.',
          steps: [
            'Read each question carefully',
            'Select the correct answer from the options',
            'Earn XP for correct answers',
            'Complete all questions to finish',
          ],
        );
      case GameType.flashcards:
        return GameRules(
          title: 'Flashcards',
          description: 'Flip cards to learn terms and definitions.',
          steps: [
            'Tap a card to flip it and see the answer',
            'Swipe right if you know it, left if you need to review',
            'Cards you know will appear less frequently',
            'Master all cards to complete the set',
          ],
        );
      case GameType.matching:
        return GameRules(
          title: 'Matching Game',
          description: 'Connect terms to definitions, one match at a time.',
          steps: [
            'Tap a term on the left',
            'Tap its matching definition on the right',
            'Correct pairs lock in with a chime. Wrong picks bounce back',
            'Clear all pairs in a section to unlock the next one',
            'Earn XP for every correct match',
          ],
        );
      case GameType.fillBlank:
        return GameRules(
          title: 'Fill in Blank',
          description: 'Complete sentences by filling in missing words.',
          steps: [
            'Read the sentence with the blank',
            'Type or select the correct word',
            'Get instant feedback on your answer',
            'Earn XP for correct completions',
          ],
        );
      case GameType.match3:
        return GameRules(
          title: 'Match-3 Game',
          description: 'Match three or more items to clear them.',
          steps: [
            'Swap adjacent items to create matches',
            'Match 3 or more of the same item to clear them',
            'Clear all items to complete the level',
            'Earn bonus XP for longer matches',
          ],
        );
      case GameType.bubblePop:
        return GameRules(
          title: 'Bubble Pop',
          description: 'Pop bubbles by matching colors or concepts.',
          steps: [
            'Tap bubbles to pop them',
            'Match colors or related concepts for bonus points',
            'Clear all bubbles to advance',
            'Earn XP based on your accuracy',
          ],
        );
      case GameType.wordSearch:
        return GameRules(
          title: 'Word Search',
          description: 'Find hidden words in the grid.',
          steps: [
            'Swipe to select words horizontally, vertically, or diagonally',
            'Find all words from the list',
            'Words will be highlighted when found',
            'Complete the puzzle to earn XP',
          ],
        );
      case GameType.crossword:
        return GameRules(
          title: 'Crossword',
          description: 'Solve clues to fill in the crossword puzzle.',
          steps: [
            'Read each clue carefully',
            'Type your answer in the corresponding boxes',
            'Use intersecting letters to help solve other clues',
            'Complete the entire puzzle to finish',
          ],
        );
      case GameType.diagramLabel:
        return GameRules(
          title: 'Diagram Label',
          description: 'Label parts of a diagram correctly.',
          steps: [
            'Study the diagram',
            'Drag labels to the correct positions',
            'Get feedback on each placement',
            'Label all parts correctly to complete',
          ],
        );
      case GameType.dragDrop:
        return GameRules(
          title: 'Drag & Drop',
          description: 'Drag items to their correct locations.',
          steps: [
            'Read the instructions',
            'Drag items to their correct drop zones',
            'Items will snap into place when correct',
            'Complete all matches to finish',
          ],
        );
      case GameType.puzzlePieces:
        return GameRules(
          title: 'Sequence Puzzle',
          description:
              'Rebuild the process in the right order — one step at a time.',
          steps: [
            'Read what happens first in the journey',
            'Drag a concept card into the next open slot',
            'Correct cards lock in with a satisfying snap',
            'Wrong cards bounce back — try another until the full sequence is complete',
          ],
        );
      case GameType.simulation:
        return GameRules(
          title: 'Simulation',
          description: 'Interact with a simulated scenario.',
          steps: [
            'Follow the on-screen instructions',
            'Make choices and see their consequences',
            'Learn from the outcomes',
            'Complete the simulation to finish',
          ],
        );
      case GameType.mystery:
        return GameRules(
          title: 'Mystery Game',
          description: 'Solve mysteries by finding clues.',
          steps: [
            'Explore the scene to find clues',
            'Tap on items to investigate',
            'Answer questions based on your findings',
            'Solve the mystery to complete the game',
          ],
        );
      case GameType.escapeRoom:
        return GameRules(
          title: 'Escape Room',
          description: 'Solve puzzles to escape the room.',
          steps: [
            'Explore the room and find clues',
            'Solve puzzles to unlock new areas',
            'Use items you find to progress',
            'Escape the room to complete the challenge',
          ],
        );
    }
  }

  /// Check if user has seen rules for a game type
  static Future<bool> hasSeenRules(GameType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_rulesPrefix${type.toString()}') ?? false;
    } catch (e) {
      LogService.error('Error checking rules status: $e');
      return false;
    }
  }

  /// Mark rules as seen for a game type
  static Future<void> markRulesSeen(GameType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_rulesPrefix${type.toString()}', true);
      LogService.debug('Rules marked as seen for ${type.toString()}');
    } catch (e) {
      LogService.error('Error marking rules as seen: $e');
    }
  }
}
