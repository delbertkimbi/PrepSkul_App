import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/skulmate_character_model.dart';

/// Service for managing user's skulMate character selection
class CharacterSelectionService {
  static const String _prefsKey = 'skulmate_selected_character_id';
  static const String _dbKey = 'skulmate_character_id';

  /// Get user's selected character
  static Future<SkulMateCharacter> getSelectedCharacter() async {
    try {
      // First try to get from database (for sync across devices)
      try {
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId != null) {
          try {
            final profile = await SupabaseService.client
                .from('profiles')
                .select(_dbKey)
                .eq('id', userId)
                .maybeSingle();

            if (profile != null && profile[_dbKey] != null) {
              final characterId = profile[_dbKey] as String;
              final character = SkulMateCharacters.getById(characterId);
              if (character != null) {
                // Also save to local prefs for offline access
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(_prefsKey, characterId);
                LogService.info('🎭 [Character] Loaded from database: ${character.name}');
                return character;
              }
            }
          } catch (e) {
            // If Supabase not initialized, skip database lookup
            if (e.toString().contains('Supabase is not initialized')) {
              LogService.debug('🎭 [Character] Supabase not initialized, using local storage');
            } else {
              LogService.debug('🎭 [Character] Could not load from database: $e');
            }
          }
        }
      } catch (e) {
        // Supabase not available, continue to local storage
        if (e.toString().contains('Supabase is not initialized')) {
          LogService.debug('🎭 [Character] Supabase not initialized, using local storage');
        }
      }

      // Fallback to local preferences
      final prefs = await SharedPreferences.getInstance();
      final characterId = prefs.getString(_prefsKey);
      if (characterId != null) {
        final character = SkulMateCharacters.getById(characterId);
        if (character != null) {
          LogService.info('🎭 [Character] Loaded from preferences: ${character.name}');
          return character;
        }
      }

      // Default character
      LogService.info('🎭 [Character] Using default character');
      return SkulMateCharacters.defaultCharacter;
    } catch (e) {
      LogService.error('🎭 [Character] Error loading character: $e');
      return SkulMateCharacters.defaultCharacter;
    }
  }

  /// Save user's character selection
  static Future<void> selectCharacter(SkulMateCharacter character) async {
    try {
      // Save to local preferences first (for immediate access)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, character.id);
      LogService.info('🎭 [Character] Saved to preferences: ${character.name}');

      // Also save to database (for sync across devices)
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        try {
          await SupabaseService.client
              .from('profiles')
              .update({_dbKey: character.id})
              .eq('id', userId);
          LogService.info('🎭 [Character] Saved to database: ${character.name}');
        } catch (e) {
          LogService.warning('🎭 [Character] Could not save to database: $e');
          // Continue - local save is sufficient
        }
      }
    } catch (e) {
      // If Supabase not initialized (e.g., in tests), just log and continue
      // Local save is sufficient for functionality
      if (e.toString().contains('Supabase is not initialized')) {
        LogService.warning('🎭 [Character] Supabase not initialized, using local storage only: $e');
      } else {
        LogService.error('🎭 [Character] Error saving character: $e');
        rethrow;
      }
    }
  }

  /// Check if user has selected a character
  static Future<bool> hasSelectedCharacter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final characterId = prefs.getString(_prefsKey);
      return characterId != null && SkulMateCharacters.getById(characterId) != null;
    } catch (e) {
      return false;
    }
  }

  /// Get a random motivational phrase from the selected character
  static Future<String> getMotivationalPhrase() async {
    try {
      final character = await getSelectedCharacter();
      if (character.motivationalPhrases.isNotEmpty) {
        final random = DateTime.now().millisecondsSinceEpoch %
            character.motivationalPhrases.length;
        return character.motivationalPhrases[random];
      }
      return 'Great job!';
    } catch (e) {
      return 'Keep it up!';
    }
  }
}
