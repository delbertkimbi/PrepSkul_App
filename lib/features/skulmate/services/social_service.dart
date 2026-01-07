import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import '../models/social_models.dart';
import '../models/game_stats_model.dart';
import 'games_services_controller.dart';

/// Service for managing social features (friendships, leaderboards, challenges)
class SocialService {
  /// Search for users by name or email
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      if (query.trim().isEmpty) {
        return [];
      }

      // Search profiles by name or email
      final response = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, email, avatar_url, user_type')
          .or('full_name.ilike.%$query%,email.ilike.%$query%')
          .neq('id', userId) // Exclude current user
          .limit(20);

      // Filter out users who are already friends or have pending requests
      final friendships = await getFriends(includePending: true);
      final friendIds = friendships.map((f) => 
        f.userId == userId ? f.friendId : f.userId
      ).toSet();

      return (response as List).where((user) {
        return !friendIds.contains(user['id'] as String);
      }).map((user) => user as Map<String, dynamic>).toList();
    } catch (e) {
      LogService.error('🎮 [Social] Error searching users: $e');
      rethrow;
    }
  }

  /// Send a friend request
  static Future<Friendship> sendFriendRequest(String friendId) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if friendship already exists
      final existing = await SupabaseService.client
          .from('skulmate_friendships')
          .select()
          .or('and(user_id.eq.$userId,friend_id.eq.$friendId),and(user_id.eq.$friendId,friend_id.eq.$userId)')
          .maybeSingle();

      if (existing != null) {
        throw Exception('Friendship already exists');
      }

      final response = await SupabaseService.client
          .from('skulmate_friendships')
          .insert({
            'user_id': userId,
            'friend_id': friendId,
            'status': 'pending',
          })
          .select()
          .maybeSingle();
      
      if (response == null) {
        throw Exception('Failed to create friend request');
      }

      LogService.success('🎮 [Social] Friend request sent');
      return Friendship.fromJson(response);
    } catch (e) {
      LogService.error('🎮 [Social] Error sending friend request: $e');
      rethrow;
    }
  }

  /// Accept a friend request
  static Future<void> acceptFriendRequest(String friendshipId) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await SupabaseService.client
          .from('skulmate_friendships')
          .update({'status': 'accepted'})
          .eq('id', friendshipId)
          .eq('friend_id', userId); // Only accept if you're the recipient

      LogService.success('🎮 [Social] Friend request accepted');
    } catch (e) {
      LogService.error('🎮 [Social] Error accepting friend request: $e');
      rethrow;
    }
  }

  /// Get user's friends
  static Future<List<Friendship>> getFriends({bool includePending = false}) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Query friendships where user is either the requester or recipient
      // We need to handle both cases: when user_id == userId and when friend_id == userId
      var query = SupabaseService.client
          .from('skulmate_friendships')
          .select('''
            *,
            friend_profile:profiles!skulmate_friendships_friend_id_fkey(
              id,
              full_name,
              email,
              avatar_url
            ),
            user_profile:profiles!skulmate_friendships_user_id_fkey(
              id,
              full_name,
              email,
              avatar_url
            )
          ''')
          .or('user_id.eq.$userId,friend_id.eq.$userId');

      if (!includePending) {
        query = query.eq('status', 'accepted');
      }

      final response = await query;

      final mapped = response.map<Friendship?>((json) {
        // Determine which profile is the friend (not the current user)
        final friendProfile = json['friend_profile'] as Map<String, dynamic>?;
        final userProfile = json['user_profile'] as Map<String, dynamic>?;
        final jsonUserId = json['user_id'] as String;
        final jsonFriendId = json['friend_id'] as String;
        
        // If current user is the requester, friend is friend_profile
        // If current user is the recipient, friend is user_profile
        final friend = jsonUserId == userId ? friendProfile : userProfile;
        // If we cannot read the friend profile (RLS), still keep the friendship with a fallback
        if (friend == null) {
          LogService.warning(
              '🎮 [Social] Missing friend profile (possible RLS). Using fallback name.');
        }

        // Prefer real name; fallback to email prefix to avoid "User"
        final rawName = (friend?['full_name'] as String?)?.trim();
        final email = friend?['email'] as String?;
        final displayName = (rawName != null &&
                rawName.isNotEmpty &&
                rawName.toLowerCase() != 'user' &&
                rawName.toLowerCase() != 'student')
            ? rawName
            : (email != null && email.isNotEmpty
                ? email.split('@').first
                : 'Friend');

        return Friendship.fromJson({
          ...json,
          'friend_name': displayName,
          'friend_avatar_url': friend?['avatar_url'],
        });
      }).whereType<Friendship>().toList();

      LogService.debug(
          '🎮 [Social] Loaded friendships: total=${mapped.length}, pending=${mapped.where((f) => f.status == FriendshipStatus.pending).length}, accepted=${mapped.where((f) => f.status == FriendshipStatus.accepted).length}');
      return mapped;
    } catch (e) {
      LogService.error('🎮 [Social] Error fetching friends: $e');
      rethrow;
    }
  }

  /// Get leaderboard entries
  static Future<List<LeaderboardEntry>> getLeaderboard({
    required LeaderboardPeriod period,
    int limit = 100,
  }) async {
    try {
      final now = DateTime.now();
      DateTime periodStart;
      DateTime? periodEnd;

      switch (period) {
        case LeaderboardPeriod.daily:
          periodStart = DateTime(now.year, now.month, now.day);
          periodEnd = periodStart.add(const Duration(days: 1));
          break;
        case LeaderboardPeriod.weekly:
          final weekday = now.weekday;
          periodStart = now.subtract(Duration(days: weekday - 1));
          periodStart = DateTime(periodStart.year, periodStart.month, periodStart.day);
          periodEnd = periodStart.add(const Duration(days: 7));
          break;
        case LeaderboardPeriod.monthly:
          periodStart = DateTime(now.year, now.month, 1);
          periodEnd = DateTime(now.year, now.month + 1, 1);
          break;
        case LeaderboardPeriod.allTime:
          periodStart = DateTime(2020, 1, 1); // Arbitrary start date
          periodEnd = null;
          break;
      }

      final response = await SupabaseService.client
          .from('skulmate_leaderboards')
          .select('''
            *,
            user:profiles!skulmate_leaderboards_user_id_fkey(
              id,
              full_name,
              email,
              avatar_url
            )
          ''')
          .eq('period', period.toString())
          .eq('period_start', periodStart.toIso8601String())
          .order('rank', ascending: true)
          .limit(limit);

      return response.map<LeaderboardEntry>((json) {
        final user = json['user'] as Map<String, dynamic>?;
        final storedName = (json['user_name'] as String?)?.trim();
        final rawName = (user?['full_name'] as String?)?.trim();
        final email = user?['email'] as String?;
        final displayName = (storedName != null &&
                storedName.isNotEmpty &&
                storedName.toLowerCase() != 'user' &&
                storedName.toLowerCase() != 'student')
            ? storedName
            : (rawName != null &&
                rawName.isNotEmpty &&
                rawName.toLowerCase() != 'user' &&
                rawName.toLowerCase() != 'student')
            ? rawName
            : (email != null && email.isNotEmpty
                ? email.split('@').first
                : 'Player');
        return LeaderboardEntry.fromJson({
          ...json,
          'user_name': displayName,
          'user_avatar_url': user?['avatar_url'],
          // Note: user_level would need to be fetched separately from user_game_stats
          // For now, we'll leave it null and it can be calculated client-side if needed
        });
      }).toList();
    } catch (e) {
      LogService.error('🎮 [Social] Error fetching leaderboard: $e');
      rethrow;
    }
  }

  /// Update leaderboard entry (called after game completion)
  static Future<void> updateLeaderboard({
    required int xpEarned,
    required int gamesPlayed,
    required bool isPerfectScore,
    required double averageScore,
  }) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();
      final periods = [
        (LeaderboardPeriod.daily, _getPeriodStart(LeaderboardPeriod.daily, now)),
        (LeaderboardPeriod.weekly, _getPeriodStart(LeaderboardPeriod.weekly, now)),
        (LeaderboardPeriod.monthly, _getPeriodStart(LeaderboardPeriod.monthly, now)),
        (LeaderboardPeriod.allTime, _getPeriodStart(LeaderboardPeriod.allTime, now)),
      ];

      for (final (period, periodStart) in periods) {
        // Get or create leaderboard entry
        final existing = await SupabaseService.client
            .from('skulmate_leaderboards')
            .select()
            .eq('user_id', userId)
            .eq('period', period.toString())
            .eq('period_start', periodStart.toIso8601String())
            .maybeSingle();

        if (existing != null) {
          // Update existing entry
          await SupabaseService.client
              .from('skulmate_leaderboards')
              .update({
                'total_xp': (existing['total_xp'] as int? ?? 0) + xpEarned,
                'games_played': (existing['games_played'] as int? ?? 0) + gamesPlayed,
                'perfect_scores': isPerfectScore
                    ? (existing['perfect_scores'] as int? ?? 0) + 1
                    : (existing['perfect_scores'] as int? ?? 0),
                'average_score': _calculateAverageScore(
                  existing['average_score'] as double? ?? 0.0,
                  existing['games_played'] as int? ?? 0,
                  averageScore,
                ),
              })
              .eq('id', existing['id']);
        } else {
          // Create new entry
          await SupabaseService.client
              .from('skulmate_leaderboards')
              .insert({
                'user_id': userId,
                'period': period.toString(),
                'period_start': periodStart.toIso8601String(),
                'total_xp': xpEarned,
                'games_played': gamesPlayed,
                'perfect_scores': isPerfectScore ? 1 : 0,
                'average_score': averageScore,
              });
        }
      }

      LogService.success('🎮 [Social] Leaderboard updated');
      
      // Submit to platform leaderboard (non-blocking)
      await submitToPlatformLeaderboard(xpEarned: xpEarned);
    } catch (e) {
      LogService.error('🎮 [Social] Error updating leaderboard: $e');
      // Don't throw - leaderboard update is not critical
    }
  }

  /// Submit score to platform leaderboard (Game Center/Play Games)
  static Future<void> submitToPlatformLeaderboard({required int xpEarned}) async {
    try {
      final gamesServices = GamesServicesController();
      if (await gamesServices.initialize()) {
        // Submit XP as score to default leaderboard
        await gamesServices.submitLeaderboardScore('default_leaderboard', xpEarned);
        LogService.info('🎮 [Social] Platform leaderboard updated');
      }
    } catch (e) {
      LogService.warning('🎮 [Social] Error submitting to platform leaderboard: $e');
      // Don't throw - platform leaderboard is optional
    }
  }

  static DateTime _getPeriodStart(LeaderboardPeriod period, DateTime now) {
    switch (period) {
      case LeaderboardPeriod.daily:
        return DateTime(now.year, now.month, now.day);
      case LeaderboardPeriod.weekly:
        final weekday = now.weekday;
        final start = now.subtract(Duration(days: weekday - 1));
        return DateTime(start.year, start.month, start.day);
      case LeaderboardPeriod.monthly:
        return DateTime(now.year, now.month, 1);
      case LeaderboardPeriod.allTime:
        return DateTime(2020, 1, 1);
    }
  }

  static double _calculateAverageScore(
    double currentAverage,
    int currentGames,
    double newScore,
  ) {
    if (currentGames == 0) return newScore;
    return ((currentAverage * currentGames) + newScore) / (currentGames + 1);
  }

  /// Create a challenge
  static Future<Challenge> createChallenge({
    required String challengeeId,
    String? gameId,
    required ChallengeType challengeType,
    int? targetValue,
    Duration? expiresIn,
  }) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final expiresAt = DateTime.now().add(expiresIn ?? const Duration(days: 7));

      final response = await SupabaseService.client
          .from('skulmate_challenges')
          .insert({
            'challenger_id': userId,
            'challengee_id': challengeeId,
            'game_id': gameId,
            'challenge_type': challengeType.toString(),
            'target_value': targetValue,
            'expires_at': expiresAt.toIso8601String(),
          })
          .select()
          .maybeSingle();
      
      if (response == null) {
        throw Exception('Failed to create challenge');
      }

      LogService.success('🎮 [Social] Challenge created');
      return Challenge.fromJson(response);
    } catch (e) {
      LogService.error('🎮 [Social] Error creating challenge: $e');
      rethrow;
    }
  }

  /// Get user's challenges
  static Future<List<Challenge>> getChallenges({
    ChallengeStatus? status,
    bool asChallenger = false,
    bool asChallengee = false,
  }) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      var query = SupabaseService.client
          .from('skulmate_challenges')
          .select('''
            *,
            challenger:profiles!skulmate_challenges_challenger_id_fkey(
              id,
              full_name,
              avatar_url
            ),
            challengee:profiles!skulmate_challenges_challengee_id_fkey(
              id,
              full_name,
              avatar_url
            ),
            game:skulmate_games!skulmate_challenges_game_id_fkey(
              id,
              title
            )
          ''');

      if (asChallenger && asChallengee) {
        query = query.or('challenger_id.eq.$userId,challengee_id.eq.$userId');
      } else if (asChallenger) {
        query = query.eq('challenger_id', userId);
      } else if (asChallengee) {
        query = query.eq('challengee_id', userId);
      } else {
        query = query.or('challenger_id.eq.$userId,challengee_id.eq.$userId');
      }

      if (status != null) {
        query = query.eq('status', status.toString());
      }

      final response = await query.order('created_at', ascending: false);

      return response.map<Challenge>((json) {
        final challenger = json['challenger'] as Map<String, dynamic>?;
        final challengee = json['challengee'] as Map<String, dynamic>?;
        final game = json['game'] as Map<String, dynamic>?;
        return Challenge.fromJson({
          ...json,
          'challenger_name': challenger?['full_name'],
          'challenger_avatar_url': challenger?['avatar_url'],
          'challengee_name': challengee?['full_name'],
          'challengee_avatar_url': challengee?['avatar_url'],
          'game_title': game?['title'],
        });
      }).toList();
    } catch (e) {
      LogService.error('🎮 [Social] Error fetching challenges: $e');
      rethrow;
    }
  }

  /// Accept a challenge
  static Future<void> acceptChallenge(String challengeId) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await SupabaseService.client
          .from('skulmate_challenges')
          .update({'status': 'accepted'})
          .eq('id', challengeId)
          .eq('challengee_id', userId)
          .eq('status', 'pending');

      LogService.success('🎮 [Social] Challenge accepted');
    } catch (e) {
      LogService.error('🎮 [Social] Error accepting challenge: $e');
      rethrow;
    }
  }

  /// Submit challenge result
  static Future<void> submitChallengeResult({
    required String challengeId,
    required Map<String, dynamic> result,
  }) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get challenge to determine if user is challenger or challengee
      final challenge = await SupabaseService.client
          .from('skulmate_challenges')
          .select()
          .eq('id', challengeId)
          .maybeSingle();

      if (challenge == null) {
        throw Exception('Challenge not found: $challengeId');
      }

      final isChallenger = challenge['challenger_id'] == userId;
      final updateData = isChallenger
          ? {'challenger_result': result}
          : {'challengee_result': result};

      await SupabaseService.client
          .from('skulmate_challenges')
          .update(updateData)
          .eq('id', challengeId);

      // Check if both results are in, then determine winner
      final updatedChallenge = await SupabaseService.client
          .from('skulmate_challenges')
          .select()
          .eq('id', challengeId)
          .maybeSingle();

      if (updatedChallenge == null) {
        throw Exception('Challenge not found: $challengeId');
      }

      if (updatedChallenge['challenger_result'] != null &&
          updatedChallenge['challengee_result'] != null) {
        // Determine winner based on challenge type
        final challengeType = ChallengeType.fromString(
          updatedChallenge['challenge_type'] as String,
        );
        final challengerResult = updatedChallenge['challenger_result'] as Map<String, dynamic>;
        final challengeeResult = updatedChallenge['challengee_result'] as Map<String, dynamic>;

        String? winnerId;
        switch (challengeType) {
          case ChallengeType.score:
            final challengerScore = challengerResult['score'] as int? ?? 0;
            final challengeeScore = challengeeResult['score'] as int? ?? 0;
            if (challengerScore > challengeeScore) {
              winnerId = challenge['challenger_id'] as String;
            } else if (challengeeScore > challengerScore) {
              winnerId = challenge['challengee_id'] as String;
            }
            break;
          case ChallengeType.time:
            final challengerTime = challengerResult['time_taken_seconds'] as int? ?? 999999;
            final challengeeTime = challengeeResult['time_taken_seconds'] as int? ?? 999999;
            if (challengerTime < challengeeTime) {
              winnerId = challenge['challenger_id'] as String;
            } else if (challengeeTime < challengerTime) {
              winnerId = challenge['challengee_id'] as String;
            }
            break;
          case ChallengeType.perfectScore:
            final challengerPerfect = challengerResult['is_perfect_score'] as bool? ?? false;
            final challengeePerfect = challengeeResult['is_perfect_score'] as bool? ?? false;
            if (challengerPerfect && !challengeePerfect) {
              winnerId = challenge['challenger_id'] as String;
            } else if (challengeePerfect && !challengerPerfect) {
              winnerId = challenge['challengee_id'] as String;
            }
            break;
        }

        // Update challenge with winner and mark as completed
        await SupabaseService.client
            .from('skulmate_challenges')
            .update({
              'winner_id': winnerId,
              'status': 'completed',
            })
            .eq('id', challengeId);
      }

      LogService.success('🎮 [Social] Challenge result submitted');
    } catch (e) {
      LogService.error('🎮 [Social] Error submitting challenge result: $e');
      rethrow;
    }
  }
}