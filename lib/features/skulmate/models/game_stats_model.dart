/// Model for user game statistics (XP, level, streak, achievements)
class GameStats {
  final int totalXP;
  final int level;
  final int currentStreak;
  final int bestStreak;
  final int gamesPlayed;
  final int perfectScores;
  final int totalCorrectAnswers;
  final int totalQuestions;
  final DateTime? lastPlayedDate;
  final List<String> achievements;

  GameStats({
    required this.totalXP,
    required this.level,
    required this.currentStreak,
    required this.bestStreak,
    required this.gamesPlayed,
    required this.perfectScores,
    required this.totalCorrectAnswers,
    required this.totalQuestions,
    this.lastPlayedDate,
    this.achievements = const [],
  });

  /// Calculate level from XP (100 XP per level)
  static int calculateLevel(int xp) {
    return (xp / 100).floor() + 1;
  }

  /// Calculate XP needed for next level
  int get xpForNextLevel {
    return (level * 100) - totalXP;
  }

  /// Calculate progress to next level (0.0 to 1.0)
  double get levelProgress {
    final currentLevelXP = (level - 1) * 100;
    final nextLevelXP = level * 100;
    final xpInCurrentLevel = totalXP - currentLevelXP;
    final xpNeededForLevel = nextLevelXP - currentLevelXP;
    return (xpInCurrentLevel / xpNeededForLevel).clamp(0.0, 1.0);
  }

  /// Accuracy percentage
  double get accuracy {
    if (totalQuestions == 0) return 0.0;
    return (totalCorrectAnswers / totalQuestions * 100).clamp(0.0, 100.0);
  }

  GameStats copyWith({
    int? totalXP,
    int? level,
    int? currentStreak,
    int? bestStreak,
    int? gamesPlayed,
    int? perfectScores,
    int? totalCorrectAnswers,
    int? totalQuestions,
    DateTime? lastPlayedDate,
    List<String>? achievements,
  }) {
    return GameStats(
      totalXP: totalXP ?? this.totalXP,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      perfectScores: perfectScores ?? this.perfectScores,
      totalCorrectAnswers: totalCorrectAnswers ?? this.totalCorrectAnswers,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      lastPlayedDate: lastPlayedDate ?? this.lastPlayedDate,
      achievements: achievements ?? this.achievements,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_xp': totalXP,
      'level': level,
      'current_streak': currentStreak,
      'best_streak': bestStreak,
      'games_played': gamesPlayed,
      'perfect_scores': perfectScores,
      'total_correct_answers': totalCorrectAnswers,
      'total_questions': totalQuestions,
      'last_played_date': lastPlayedDate?.toIso8601String(),
      'achievements': achievements,
    };
  }

  factory GameStats.fromJson(Map<String, dynamic> json) {
    return GameStats(
      totalXP: json['total_xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      currentStreak: json['current_streak'] as int? ?? 0,
      bestStreak: json['best_streak'] as int? ?? 0,
      gamesPlayed: json['games_played'] as int? ?? 0,
      perfectScores: json['perfect_scores'] as int? ?? 0,
      totalCorrectAnswers: json['total_correct_answers'] as int? ?? 0,
      totalQuestions: json['total_questions'] as int? ?? 0,
      lastPlayedDate: json['last_played_date'] != null
          ? DateTime.parse(json['last_played_date'] as String)
          : null,
      achievements: (json['achievements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// Default empty stats
  factory GameStats.empty() {
    return GameStats(
      totalXP: 0,
      level: 1,
      currentStreak: 0,
      bestStreak: 0,
      gamesPlayed: 0,
      perfectScores: 0,
      totalCorrectAnswers: 0,
      totalQuestions: 0,
      achievements: [],
    );
  }
}

/// Achievement definitions
class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int xpReward;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.xpReward = 50,
  });

  static const List<Achievement> allAchievements = [
    Achievement(
      id: 'first_game',
      name: 'First Steps',
      description: 'Play your first game',
      icon: '🎮',
      xpReward: 25,
    ),
    Achievement(
      id: 'perfect_score',
      name: 'Perfect Score',
      description: 'Get 100% on a game',
      icon: '🌟',
      xpReward: 100,
    ),
    Achievement(
      id: 'streak_5',
      name: 'On Fire',
      description: 'Get 5 correct answers in a row',
      icon: '🔥',
      xpReward: 50,
    ),
    Achievement(
      id: 'streak_10',
      name: 'Streak Master',
      description: 'Get 10 correct answers in a row',
      icon: '⚡',
      xpReward: 100,
    ),
    Achievement(
      id: 'speed_demon',
      name: 'Speed Demon',
      description: 'Complete a game in under 2 minutes',
      icon: '⚡',
      xpReward: 75,
    ),
    Achievement(
      id: 'games_10',
      name: 'Game Enthusiast',
      description: 'Play 10 games',
      icon: '🎯',
      xpReward: 50,
    ),
    Achievement(
      id: 'games_50',
      name: 'Game Master',
      description: 'Play 50 games',
      icon: '👑',
      xpReward: 200,
    ),
    Achievement(
      id: 'level_5',
      name: 'Rising Star',
      description: 'Reach level 5',
      icon: '⭐',
      xpReward: 100,
    ),
    Achievement(
      id: 'level_10',
      name: 'Expert Learner',
      description: 'Reach level 10',
      icon: '🏆',
      xpReward: 250,
    ),
  ];

  static Achievement? getById(String id) {
    try {
      return allAchievements.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }
}
