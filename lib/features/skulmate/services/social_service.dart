import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/core/utils/profile_display_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/social_models.dart';
import 'games_services_controller.dart';

/// Service for managing social features (friendships, leaderboards, challenges)
class SocialService {
  /// Get recommended skulMate friends (users who play games, Duolingo-style)
  static Future<List<Map<String, dynamic>>> getRecommendedFriends({
    int limit = 20,
  }) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await SupabaseService.client
          .rpc('get_recommended_skulmate_friends', params: {'p_limit': limit});

      return (response as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      LogService.error('🎮 [Social] Error fetching recommended friends: $e');
      return [];
    }
  }

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

      // Notify recipient (in-app + push, same as challenges)
      try {
        final requesterName = (await SupabaseService.client
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle())?['full_name'] as String? ?? 'Someone';
        await NotificationHelperService.sendSkulmateNotification(
          userId: friendId,
          type: 'skulmate_friend_request',
          title: 'New friend request ⚡',
          message: '$requesterName wants to be your friend',
          actionUrl: '/skulmate/friends',
          actionText: 'View',
          data: {'friendship_id': response['id'], 'requester_id': userId},
        );
      } catch (e) {
        LogService.debug('Could not create friend request notification: $e');
      }

      LogService.success('🎮 [Social] Friend request sent');
      return Friendship.fromJson(response);
    } catch (e) {
      LogService.error('🎮 [Social] Error sending friend request: $e');
      rethrow;
    }
  }

  /// Decline a friend request
  static Future<void> declineFriendRequest(String friendshipId) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await SupabaseService.client
          .from('skulmate_friendships')
          .delete()
          .eq('id', friendshipId)
          .eq('friend_id', userId)
          .eq('status', 'pending');

      LogService.success('🎮 [Social] Friend request declined');
    } catch (e) {
      LogService.error('🎮 [Social] Error declining friend request: $e');
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

      final row = await SupabaseService.client
          .from('skulmate_friendships')
          .update({'status': 'accepted'})
          .eq('id', friendshipId)
          .eq('friend_id', userId)
          .select('user_id')
          .maybeSingle();

      // Notify requester (user_id) that their request was accepted
      if (row != null) {
        try {
          final accepterName = (await SupabaseService.client
              .from('profiles')
              .select('full_name')
              .eq('id', userId)
              .maybeSingle())?['full_name'] as String? ?? 'Someone';
          final requesterId = row['user_id'] as String;
          await NotificationHelperService.sendSkulmateNotification(
            userId: requesterId,
            type: 'skulmate_friend_accepted',
            title: 'Friend request accepted 🎉',
            message: '$accepterName accepted your friend request',
            actionUrl: '/skulmate/friends',
            actionText: 'View',
            data: {'friendship_id': friendshipId},
          );
        } catch (e) {
          LogService.debug('Could not create friend accepted notification: $e');
        }
      }

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
      final periodStart = _getPeriodStart(period, DateTime.now());
      List<Map<String, dynamic>> rows = [];

      final periodStartsToTry = period == LeaderboardPeriod.allTime
          ? <DateTime>[
              DateTime.utc(2020, 1, 1),
              DateTime(2020, 1, 1),
              periodStart,
            ]
          : <DateTime>[periodStart];

      for (final start in periodStartsToTry) {
        try {
          final response = await SupabaseService.client
              .rpc(
                'get_skulmate_leaderboard',
                params: {
                  'p_period': period.toString(),
                  'p_period_start': start.toUtc().toIso8601String(),
                  'p_limit': limit,
                },
              )
              .timeout(const Duration(seconds: 8));
          rows = (response as List).cast<Map<String, dynamic>>();
          if (rows.isNotEmpty) break;
        } catch (e) {
          LogService.debug('Leaderboard RPC attempt failed ($start): $e');
        }
      }

      if (rows.isEmpty) {
        LogService.warning(
          '🎮 [Social] Leaderboard RPC returned no rows, using table fallback',
        );
        rows = await _fetchLeaderboardRowsFallback(
          period: period,
          periodStart: periodStart,
          limit: limit,
        );
      }

      final entries = rows.map(_leaderboardEntryFromRow).toList();
      return _enrichLeaderboardEntries(entries);
    } catch (e) {
      LogService.error('🎮 [Social] Error fetching leaderboard: $e');
      rethrow;
    }
  }

  static LeaderboardEntry _leaderboardEntryFromRow(Map<String, dynamic> json) {
    final displayName = ProfileDisplayUtils.resolveDisplayName(
      primary: json['user_name'] as String?,
    );
    return LeaderboardEntry.fromJson({
      ...json,
      'user_name': displayName,
    });
  }

  static Future<List<Map<String, dynamic>>> _fetchLeaderboardRowsFallback({
    required LeaderboardPeriod period,
    required DateTime periodStart,
    required int limit,
  }) async {
    Future<List<Map<String, dynamic>>> query(DateTime start) async {
      final response = await SupabaseService.client
          .from('skulmate_leaderboards')
          .select('*')
          .eq('period', period.toString())
          .eq('period_start', start.toUtc().toIso8601String())
          .order('total_xp', ascending: false)
          .limit(limit);
      return (response as List).cast<Map<String, dynamic>>();
    }

    var rows = await query(periodStart);
    if (rows.isEmpty && period == LeaderboardPeriod.allTime) {
      final response = await SupabaseService.client
          .from('skulmate_leaderboards')
          .select('*')
          .eq('period', period.toString())
          .order('total_xp', ascending: false)
          .limit(limit);
      rows = (response as List).cast<Map<String, dynamic>>();
    }
    return rows;
  }

  static Future<List<LeaderboardEntry>> _enrichLeaderboardEntries(
    List<LeaderboardEntry> entries,
  ) async {
    if (entries.isEmpty) return entries;

    final userIds = entries.map((e) => e.userId).toSet().toList();
    final profilesById = await _fetchPublicProfiles(userIds);

    return entries.map((entry) {
      final profile = profilesById[entry.userId];
      final avatar = (profile?['avatar_url'] as String?)?.trim();
      final resolvedAvatar =
          avatar != null && avatar.isNotEmpty ? avatar : entry.userAvatarUrl;
      return LeaderboardEntry(
        id: entry.id,
        userId: entry.userId,
        period: entry.period,
        periodStart: entry.periodStart,
        periodEnd: entry.periodEnd,
        totalXP: entry.totalXP,
        gamesPlayed: entry.gamesPlayed,
        perfectScores: entry.perfectScores,
        averageScore: entry.averageScore,
        rank: entry.rank,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
        userName: ProfileDisplayUtils.resolveDisplayName(
          primary: entry.userName,
          profile: profile,
        ),
        userAvatarUrl: resolvedAvatar,
        userCharacterId: entry.userCharacterId,
        userLevel: entry.userLevel,
      );
    }).toList();
  }

  static Future<Map<String, Map<String, dynamic>>> _fetchPublicProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return {};

    try {
      final response = await SupabaseService.client.rpc(
        'get_skulmate_public_profiles',
        params: {'p_user_ids': userIds},
      );
      final profilesById = <String, Map<String, dynamic>>{};
      for (final row in (response as List).cast<Map<String, dynamic>>()) {
        profilesById[row['id'] as String] = row;
      }
      return profilesById;
    } catch (e) {
      LogService.debug(
        'Leaderboard public profiles RPC unavailable, trying direct query: $e',
      );
    }

    final profilesById = <String, Map<String, dynamic>>{};
    try {
      final profiles = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, email, avatar_url')
          .inFilter('id', userIds);
      for (final row in (profiles as List).cast<Map<String, dynamic>>()) {
        profilesById[row['id'] as String] = row;
      }
    } catch (e) {
      LogService.debug('Leaderboard profile enrich skipped: $e');
    }

    try {
      final tutorProfiles = await SupabaseService.client
          .from('tutor_profiles')
          .select('user_id, profile_photo_url')
          .inFilter('user_id', userIds);
      for (final row in (tutorProfiles as List).cast<Map<String, dynamic>>()) {
        final uid = row['user_id'] as String?;
        final photo = (row['profile_photo_url'] as String?)?.trim();
        if (uid == null || photo == null || photo.isEmpty) continue;
        profilesById.putIfAbsent(uid, () => {'id': uid});
        profilesById[uid]!['avatar_url'] = photo;
      }
    } catch (e) {
      LogService.debug('Leaderboard tutor photo enrich skipped: $e');
    }

    return profilesById;
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
            .eq('period_start', periodStart.toUtc().toIso8601String())
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
                'period_start': periodStart.toUtc().toIso8601String(),
                'total_xp': xpEarned,
                'games_played': gamesPlayed,
                'perfect_scores': isPerfectScore ? 1 : 0,
                'average_score': averageScore,
              });
        }
      }

      LogService.success('🎮 [Social] Leaderboard updated');

      await _notifyDailyLeaderSnapshot();
      
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
        return DateTime.utc(2020, 1, 1);
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

  /// Sends one daily leaderboard snapshot notification per user/device.
  /// This keeps players aware of who is topping the daily chart.
  static Future<void> _notifyDailyLeaderSnapshot() async {
    try {
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) return;
      final userId = currentUser.id;
      final now = DateTime.now();
      final dayKey = '${now.year}-${now.month}-${now.day}';
      final prefs = await SharedPreferences.getInstance();
      final sentKey = 'skulmate_daily_leader_notified_$dayKey';
      if (prefs.getBool(sentKey) == true) return;

      final dailyEntries = await getLeaderboard(
        period: LeaderboardPeriod.daily,
        limit: 100,
      );
      if (dailyEntries.isEmpty) return;
      final top = dailyEntries.first;
      final rawTopName = (top.userName ?? '').trim();
      final topName = rawTopName.isEmpty ? 'Player' : rawTopName;
      final message = top.userId == userId
          ? 'You are topping today\'s game chart with ${top.totalXP} XP. Keep the streak going!'
          : '$topName is topping today\'s game chart with ${top.totalXP} XP.';
      await NotificationHelperService.sendSkulmateNotification(
        userId: userId,
        type: 'skulmate_daily_leaderboard',
        title: 'Daily game chart update ⚡',
        message: message,
        actionUrl: '/skulmate/leaderboard',
        actionText: 'View leaderboard',
        data: {
          'top_user_id': top.userId,
          'top_user_name': topName,
          'top_xp': top.totalXP,
          'period': 'daily',
        },
      );
      await prefs.setBool(sentKey, true);
    } catch (e) {
      LogService.debug('🎮 [Social] Daily leaderboard notification skipped: $e');
    }
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

      // Notify challengee (in-app + push, same as friend requests)
      try {
        final challengerName = (await SupabaseService.client
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle())?['full_name'] as String? ?? 'Someone';
        await NotificationHelperService.sendSkulmateNotification(
          userId: challengeeId,
          type: 'skulmate_challenge',
          title: 'Challenge from $challengerName ⚡',
          message: '$challengerName challenged you! Play to beat their score.',
          actionUrl: '/skulmate/challenges',
          actionText: 'View',
          data: {'challenge_id': response['id'], 'challenger_id': userId},
        );
      } catch (e) {
        LogService.debug('Could not create challenge notification: $e');
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

      final challenge = await SupabaseService.client
          .from('skulmate_challenges')
          .select('challenger_id')
          .eq('id', challengeId)
          .eq('challengee_id', userId)
          .eq('status', 'pending')
          .maybeSingle();

      await SupabaseService.client
          .from('skulmate_challenges')
          .update({'status': 'accepted'})
          .eq('id', challengeId)
          .eq('challengee_id', userId)
          .eq('status', 'pending');

      // Notify challenger
      if (challenge != null) {
        try {
          final accepterName = (await SupabaseService.client
              .from('profiles')
              .select('full_name')
              .eq('id', userId)
              .maybeSingle())?['full_name'] as String? ?? 'Someone';
          final challengerId = challenge['challenger_id'] as String;
          await NotificationHelperService.sendSkulmateNotification(
            userId: challengerId,
            type: 'skulmate_challenge_accepted',
            title: 'Challenge accepted 🎉',
            message: '$accepterName accepted your challenge. Play now!',
            actionUrl: '/skulmate/challenges',
            actionText: 'View',
            data: {'challenge_id': challengeId},
          );
        } catch (e) {
          LogService.debug('Could not create challenge accepted notification: $e');
        }
      }

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