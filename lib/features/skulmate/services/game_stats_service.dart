import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../models/game_stats_model.dart';
import 'social_service.dart';

/// Service for managing game statistics (XP, levels, streaks, achievements)
class GameStatsService {
  static const String _prefsKey = 'game_stats';
  static const String _streakKey = 'current_streak';
  static const String _lastPlayedKey = 'last_played_date';

  /// Get user's game stats
  static Future<GameStats> getStats() async {
    try {
      // Try to get from database first
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        try {
          final response = await SupabaseService.client
              .from('user_game_stats')
              .select()
              .eq('user_id', userId)
              .maybeSingle();

          if (response != null) {
            final stats = GameStats.fromJson(response);
            // Also save to local prefs for offline access
            await _saveToPrefs(stats);
            LogService.info('📊 [GameStats] Loaded from database');
            return stats;
          }
        } catch (e) {
          LogService.debug('📊 [GameStats] Could not load from database: $e');
        }
      }

      // Fallback to local storage
      return await _loadFromPrefs();
    } catch (e) {
      LogService.error('📊 [GameStats] Error loading stats: $e');
      return GameStats.empty();
    }
  }

  /// Add XP and update stats after a game
  static Future<GameStats> addGameResult({
    required int correctAnswers,
    required int totalQuestions,
    required int timeTakenSeconds,
    bool isPerfectScore = false,
  }) async {
    try {
      final currentStats = await getStats();
      
      // Calculate XP earned
      int xpEarned = correctAnswers * 10; // 10 XP per correct answer
      
      // Bonus XP for perfect score
      if (isPerfectScore) {
        xpEarned += 50;
      }
      
      // Bonus XP for speed (under 2 minutes)
      if (timeTakenSeconds < 120) {
        xpEarned += 25;
      }
      
      // Update streak
      final today = DateTime.now();
      final lastPlayed = currentStats.lastPlayedDate;
      int newStreak = currentStats.currentStreak;
      
      if (lastPlayed != null) {
        final daysSince = today.difference(lastPlayed).inDays;
        if (daysSince == 0) {
          // Same day, maintain streak
        } else if (daysSince == 1) {
          // Consecutive day, increment streak
          newStreak++;
        } else {
          // Streak broken
          newStreak = 1;
        }
      } else {
        // First game
        newStreak = 1;
      }
      
      // Update best streak
      final newBestStreak = newStreak > currentStats.bestStreak 
          ? newStreak 
          : currentStats.bestStreak;
      
      // Calculate new XP and level
      final newXP = currentStats.totalXP + xpEarned;
      final newLevel = GameStats.calculateLevel(newXP);
      final wasLevelUp = newLevel > currentStats.level;
      
      // Update stats
      final updatedStats = currentStats.copyWith(
        totalXP: newXP,
        level: newLevel,
        currentStreak: newStreak,
        bestStreak: newBestStreak,
        gamesPlayed: currentStats.gamesPlayed + 1,
        perfectScores: isPerfectScore 
            ? currentStats.perfectScores + 1 
            : currentStats.perfectScores,
        totalCorrectAnswers: currentStats.totalCorrectAnswers + correctAnswers,
        totalQuestions: currentStats.totalQuestions + totalQuestions,
        lastPlayedDate: today,
      );
      
      // Check for new achievements
      final newAchievements = await _checkAchievements(updatedStats);
      final statsWithAchievements = updatedStats.copyWith(
        achievements: newAchievements,
      );
      
      // Save to database and local storage
      await _saveStats(statsWithAchievements);
      
      // Update leaderboards (non-blocking)
      try {
        final averageScore = totalQuestions > 0
            ? (correctAnswers / totalQuestions * 100)
            : 0.0;
        await SocialService.updateLeaderboard(
          xpEarned: xpEarned,
          gamesPlayed: 1,
          isPerfectScore: isPerfectScore,
          averageScore: averageScore,
        );
      } catch (e) {
        // Log but don't fail - leaderboard update is not critical
        LogService.debug('📊 [GameStats] Leaderboard update failed: $e');
      }
      
      LogService.success('📊 [GameStats] Added $xpEarned XP (Total: $newXP, Level: $newLevel)');
      
      return statsWithAchievements;
    } catch (e) {
      LogService.error('📊 [GameStats] Error adding game result: $e');
      return await getStats();
    }
  }

  /// Check for new achievements
  static Future<List<String>> _checkAchievements(GameStats stats) async {
    final currentAchievements = stats.achievements;
    final newAchievements = <String>[];
    
    // Check each achievement
    for (final achievement in Achievement.allAchievements) {
      if (currentAchievements.contains(achievement.id)) {
        continue; // Already earned
      }
      
      bool earned = false;
      
      switch (achievement.id) {
        case 'first_game':
          earned = stats.gamesPlayed >= 1;
          break;
        case 'perfect_score':
          earned = stats.perfectScores >= 1;
          break;
        case 'streak_5':
          earned = stats.currentStreak >= 5;
          break;
        case 'streak_10':
          earned = stats.currentStreak >= 10;
          break;
        case 'games_10':
          earned = stats.gamesPlayed >= 10;
          break;
        case 'games_50':
          earned = stats.gamesPlayed >= 50;
          break;
        case 'level_5':
          earned = stats.level >= 5;
          break;
        case 'level_10':
          earned = stats.level >= 10;
          break;
      }
      
      if (earned) {
        newAchievements.add(achievement.id);
        LogService.success('🏆 [Achievement] Unlocked: ${achievement.name}');
      }
    }
    
    return [...currentAchievements, ...newAchievements];
  }

  /// Save stats to database and local storage
  static Future<void> _saveStats(GameStats stats) async {
    // Save to local storage first (for offline access)
    await _saveToPrefs(stats);
    
    // Save to database
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        // Use upsert with conflict resolution on user_id
        await SupabaseService.client
            .from('user_game_stats')
            .upsert(
              {
                'user_id': userId,
                ...stats.toJson(),
              },
              onConflict: 'user_id',
            );
        LogService.info('📊 [GameStats] Saved to database');
      } catch (e) {
        LogService.debug('📊 [GameStats] Could not save to database: $e');
      }
    }
  }

  /// Load stats from SharedPreferences
  static Future<GameStats> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);
      
      if (jsonString != null) {
        // Parse JSON manually (SharedPreferences stores as string)
        // For now, return empty and let it build up
        return GameStats.empty();
      }
      
      return GameStats.empty();
    } catch (e) {
      LogService.error('📊 [GameStats] Error loading from prefs: $e');
      return GameStats.empty();
    }
  }

  /// Save stats to SharedPreferences
  static Future<void> _saveToPrefs(GameStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // For now, just save key stats
      await prefs.setInt('total_xp', stats.totalXP);
      await prefs.setInt('level', stats.level);
      await prefs.setInt('current_streak', stats.currentStreak);
      await prefs.setInt('best_streak', stats.bestStreak);
      await prefs.setInt('games_played', stats.gamesPlayed);
      await prefs.setStringList('achievements', stats.achievements);
    } catch (e) {
      LogService.error('📊 [GameStats] Error saving to prefs: $e');
    }
  }

  /// Get current streak
  static Future<int> getCurrentStreak() async {
    final stats = await getStats();
    return stats.currentStreak;
  }

  /// Reset streak (if needed)
  static Future<void> resetStreak() async {
    final stats = await getStats();
    await _saveStats(stats.copyWith(currentStreak: 0));
  }
}
