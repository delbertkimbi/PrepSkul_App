/// Models for skulMate social features (friendships, leaderboards, challenges)

/// Friendship status
enum FriendshipStatus {
  pending,
  accepted,
  blocked;

  static FriendshipStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return FriendshipStatus.pending;
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'blocked':
        return FriendshipStatus.blocked;
      default:
        return FriendshipStatus.pending;
    }
  }

  @override
  String toString() {
    switch (this) {
      case FriendshipStatus.pending:
        return 'pending';
      case FriendshipStatus.accepted:
        return 'accepted';
      case FriendshipStatus.blocked:
        return 'blocked';
    }
  }
}

/// Friendship model
class Friendship {
  final String id;
  final String userId;
  final String friendId;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? friendName;
  final String? friendAvatarUrl;

  Friendship({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.friendName,
    this.friendAvatarUrl,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      friendId: json['friend_id'] as String,
      status: FriendshipStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      friendName: json['friend_name'] as String?,
      friendAvatarUrl: json['friend_avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'friend_id': friendId,
      'status': status.toString(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Leaderboard type (custom vs platform)
enum LeaderboardType {
  custom,
  platform,
  combined;
  
  static LeaderboardType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'custom':
        return LeaderboardType.custom;
      case 'platform':
        return LeaderboardType.platform;
      case 'combined':
        return LeaderboardType.combined;
      default:
        return LeaderboardType.custom;
    }
  }
  
  @override
  String toString() {
    switch (this) {
      case LeaderboardType.custom:
        return 'custom';
      case LeaderboardType.platform:
        return 'platform';
      case LeaderboardType.combined:
        return 'combined';
    }
  }
}

/// Leaderboard period
enum LeaderboardPeriod {
  daily,
  weekly,
  monthly,
  allTime;

  static LeaderboardPeriod fromString(String value) {
    switch (value.toLowerCase()) {
      case 'daily':
        return LeaderboardPeriod.daily;
      case 'weekly':
        return LeaderboardPeriod.weekly;
      case 'monthly':
        return LeaderboardPeriod.monthly;
      case 'all_time':
        return LeaderboardPeriod.allTime;
      default:
        return LeaderboardPeriod.allTime;
    }
  }

  @override
  String toString() {
    switch (this) {
      case LeaderboardPeriod.daily:
        return 'daily';
      case LeaderboardPeriod.weekly:
        return 'weekly';
      case LeaderboardPeriod.monthly:
        return 'monthly';
      case LeaderboardPeriod.allTime:
        return 'all_time';
    }
  }
}

/// Leaderboard entry
class LeaderboardEntry {
  final String id;
  final String userId;
  final LeaderboardPeriod period;
  final DateTime periodStart;
  final DateTime? periodEnd;
  final int totalXP;
  final int gamesPlayed;
  final int perfectScores;
  final double averageScore;
  final int? rank;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userName;
  final String? userAvatarUrl;
  final int? userLevel;

  LeaderboardEntry({
    required this.id,
    required this.userId,
    required this.period,
    required this.periodStart,
    this.periodEnd,
    required this.totalXP,
    required this.gamesPlayed,
    required this.perfectScores,
    required this.averageScore,
    this.rank,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userAvatarUrl,
    this.userLevel,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      period: LeaderboardPeriod.fromString(json['period'] as String),
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: json['period_end'] != null
          ? DateTime.parse(json['period_end'] as String)
          : null,
      totalXP: json['total_xp'] as int? ?? 0,
      gamesPlayed: json['games_played'] as int? ?? 0,
      perfectScores: json['perfect_scores'] as int? ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
      rank: json['rank'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userName: json['user_name'] as String?,
      userAvatarUrl: json['user_avatar_url'] as String?,
      userLevel: json['user_level'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'period': period.toString(),
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd?.toIso8601String(),
      'total_xp': totalXP,
      'games_played': gamesPlayed,
      'perfect_scores': perfectScores,
      'average_score': averageScore,
      'rank': rank,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Challenge type
enum ChallengeType {
  score,
  time,
  perfectScore;

  static ChallengeType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'score':
        return ChallengeType.score;
      case 'time':
        return ChallengeType.time;
      case 'perfect_score':
        return ChallengeType.perfectScore;
      default:
        return ChallengeType.score;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ChallengeType.score:
        return 'score';
      case ChallengeType.time:
        return 'time';
      case ChallengeType.perfectScore:
        return 'perfect_score';
    }
  }
}

/// Challenge status
enum ChallengeStatus {
  pending,
  accepted,
  completed,
  declined,
  expired;

  static ChallengeStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return ChallengeStatus.pending;
      case 'accepted':
        return ChallengeStatus.accepted;
      case 'completed':
        return ChallengeStatus.completed;
      case 'declined':
        return ChallengeStatus.declined;
      case 'expired':
        return ChallengeStatus.expired;
      default:
        return ChallengeStatus.pending;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ChallengeStatus.pending:
        return 'pending';
      case ChallengeStatus.accepted:
        return 'accepted';
      case ChallengeStatus.completed:
        return 'completed';
      case ChallengeStatus.declined:
        return 'declined';
      case ChallengeStatus.expired:
        return 'expired';
    }
  }
}

/// Challenge model
class Challenge {
  final String id;
  final String challengerId;
  final String challengeeId;
  final String? gameId;
  final ChallengeType challengeType;
  final int? targetValue;
  final ChallengeStatus status;
  final Map<String, dynamic>? challengerResult;
  final Map<String, dynamic>? challengeeResult;
  final String? winnerId;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? challengerName;
  final String? challengerAvatarUrl;
  final String? challengeeName;
  final String? challengeeAvatarUrl;
  final String? gameTitle;

  Challenge({
    required this.id,
    required this.challengerId,
    required this.challengeeId,
    this.gameId,
    required this.challengeType,
    this.targetValue,
    required this.status,
    this.challengerResult,
    this.challengeeResult,
    this.winnerId,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.challengerName,
    this.challengerAvatarUrl,
    this.challengeeName,
    this.challengeeAvatarUrl,
    this.gameTitle,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      challengerId: json['challenger_id'] as String,
      challengeeId: json['challengee_id'] as String,
      gameId: json['game_id'] as String?,
      challengeType: ChallengeType.fromString(json['challenge_type'] as String),
      targetValue: json['target_value'] as int?,
      status: ChallengeStatus.fromString(json['status'] as String),
      challengerResult: json['challenger_result'] as Map<String, dynamic>?,
      challengeeResult: json['challengee_result'] as Map<String, dynamic>?,
      winnerId: json['winner_id'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      challengerName: json['challenger_name'] as String?,
      challengerAvatarUrl: json['challenger_avatar_url'] as String?,
      challengeeName: json['challengee_name'] as String?,
      challengeeAvatarUrl: json['challengee_avatar_url'] as String?,
      gameTitle: json['game_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'challenger_id': challengerId,
      'challengee_id': challengeeId,
      'game_id': gameId,
      'challenge_type': challengeType.toString(),
      'target_value': targetValue,
      'status': status.toString(),
      'challenger_result': challengerResult,
      'challengee_result': challengeeResult,
      'winner_id': winnerId,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => status == ChallengeStatus.pending;
  bool get isAccepted => status == ChallengeStatus.accepted;
  bool get isCompleted => status == ChallengeStatus.completed;
}


