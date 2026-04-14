import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/widgets/empty_state_widget.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import '../models/social_models.dart';
import '../services/social_service.dart';
import '../services/games_services_controller.dart';
import '../services/game_stats_service.dart';
import '../models/game_stats_model.dart';
import '../services/character_selection_service.dart';
import '../models/skulmate_character_model.dart';
import '../widgets/skulmate_character_widget.dart';
import '../widgets/skulmate_surface_styles.dart';

/// SkulMate leaderboard — all-time rankings, Global / Friends, podium + list.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<LeaderboardEntry> _allTimeGlobal = [];
  List<Friendship> _friendships = [];
  GameStats? _myStats;
  dynamic _myCharacter;
  bool _isLoading = true;
  int _scopeIndex = 0; // 0 = Global, 1 = Friends
  final GamesServicesController _gamesServices = GamesServicesController();
  bool _platformAvailable = false;

  static const int _allTimeGamesGoal = 5;

  @override
  void initState() {
    super.initState();
    _checkPlatformAvailability();
    _loadAll();
  }

  Future<void> _checkPlatformAvailability() async {
    if (!kIsWeb) {
      safeSetState(() {
        _platformAvailable = _gamesServices.isAvailable;
      });
    }
  }

  Future<void> _loadAll() async {
    try {
      safeSetState(() => _isLoading = true);
      final myId = SupabaseService.client.auth.currentUser?.id;
      final board = await SocialService.getLeaderboard(
        period: LeaderboardPeriod.allTime,
        limit: 500,
      );
      final friends = myId != null
          ? await SocialService.getFriends(includePending: false)
          : <Friendship>[];
      final stats = await GameStatsService.getStats();
      final character = await CharacterSelectionService.getSelectedCharacter();

      safeSetState(() {
        _allTimeGlobal = board;
        _friendships = friends;
        _myStats = stats;
        _myCharacter = character;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading leaderboard: $e');
      safeSetState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserFriendlyMessage(e)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String? get _myUserId => SupabaseService.client.auth.currentUser?.id;

  Set<String> get _friendUserIds {
    final me = _myUserId;
    if (me == null) return {};
    final ids = <String>{};
    for (final f in _friendships) {
      if (f.status != FriendshipStatus.accepted) continue;
      ids.add(f.userId == me ? f.friendId : f.userId);
    }
    ids.add(me);
    return ids;
  }

  List<LeaderboardEntry> get _displayEntries {
    if (_scopeIndex == 0) return _allTimeGlobal;
    final allowed = _friendUserIds;
    final filtered =
        _allTimeGlobal.where((e) => allowed.contains(e.userId)).toList()
          ..sort((a, b) => b.totalXP.compareTo(a.totalXP));
    return filtered;
  }

  LeaderboardEntry? get _myAllTimeEntry {
    final me = _myUserId;
    if (me == null) return null;
    try {
      return _allTimeGlobal.firstWhere((e) => e.userId == me);
    } catch (_) {
      return null;
    }
  }

  /// 1-based position in the current scope list (Global or Friends), or null if not on the board.
  int? get _myRankInScope {
    final me = _myUserId;
    if (me == null) return null;
    final list = _displayEntries;
    for (var i = 0; i < list.length; i++) {
      if (list[i].userId == me) return i + 1;
    }
    return null;
  }

  /// Indices into [_displayEntries] for ranks 4+ — current user first when below the podium.
  List<int> _indicesBelowPodiumOrdered() {
    final entries = _displayEntries;
    if (entries.length <= 3) return <int>[];
    final me = _myUserId;
    final indices =
        List<int>.generate(entries.length - 3, (i) => i + 3);
    if (me == null) return indices;
    final pos = indices.indexWhere((idx) => entries[idx].userId == me);
    if (pos <= 0) return indices;
    final mine = indices.removeAt(pos);
    return [mine, ...indices];
  }

  int get _daysLeftInWeek {
    final now = DateTime.now();
    final weekday = now.weekday;
    final start =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1));
    final end = start.add(const Duration(days: 7));
    final d = end.difference(now).inDays;
    return d.clamp(0, 7);
  }

  String _formatXp(int xp) => NumberFormat.decimalPattern().format(xp);

  Widget _buildLeaderboardShimmer(double topPadding) {
    final base = AppTheme.neutral200;
    final hi = Colors.white;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      period: const Duration(milliseconds: 1200),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 72,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 168,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 18,
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(
                5,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final orderedBelow =
        _isLoading ? <int>[] : _indicesBelowPodiumOrdered();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.softBackground,
        body: _isLoading
            ? _buildLeaderboardShimmer(topPadding)
            : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _loadAll,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(),
                          const SizedBox(height: 16),
                          _buildWeeklyHeroCard(),
                          const SizedBox(height: 18),
                          _buildScopeToggle(),
                          const SizedBox(height: 18),
                          if (_displayEntries.isEmpty)
                            _buildEmptyScope()
                          else ...[
                            _buildPodium(),
                            const SizedBox(height: 14),
                            _buildYourRankSummary(),
                            const SizedBox(height: 16),
                            _buildRankedListHeader(),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (orderedBelow.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final index = orderedBelow[i];
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: _buildRankRow(
                              rank: index + 1,
                              entry: _displayEntries[index],
                            ),
                          );
                        },
                        childCount: orderedBelow.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: PhosphorIcon(
            PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'SkulMate',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryColor,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        if (_myStats != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.skyBlueLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.35)),
            ),
            child: Text(
              '${_formatXp(_myStats!.totalXP)} XP',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        if (_platformAvailable) ...[
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(Icons.emoji_events_outlined, color: AppTheme.primaryColor),
            tooltip: 'Platform leaderboard',
            onPressed: () async {
              try {
                await _gamesServices.showLeaderboard();
              } catch (e) {
                LogService.error('Error showing platform leaderboard: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open platform leaderboard'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildWeeklyHeroCard() {
    final my = _myAllTimeEntry;
    final games = my?.gamesPlayed ?? 0;
    final progress = (games / _allTimeGamesGoal).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: SkulMateSurfaceStyles.heroGradient(radius: 22),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 56,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rocket_launch_rounded,
                      color: AppTheme.softYellowLight, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'ALL-TIME',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$_daysLeftInWeek ${_daysLeftInWeek == 1 ? 'day' : 'days'} left',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Climb the all-time board',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Play SkulMate games to earn XP. Rankings are all-time.',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '$games / $_allTimeGamesGoal games',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).round()}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.softYellowLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.accentGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScopeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ScopeChip(
              label: 'Global',
              selected: _scopeIndex == 0,
              onTap: () => safeSetState(() => _scopeIndex = 0),
            ),
          ),
          Expanded(
            child: _ScopeChip(
              label: 'Friends',
              selected: _scopeIndex == 1,
              onTap: () => safeSetState(() => _scopeIndex = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyScope() {
    if (_scopeIndex == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: EmptyStateWidget(
          icon: Icons.people_outline,
          title: 'No friends on the board yet',
          message:
              'Add friends in SkulMate social, or play games to appear here.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: EmptyStateWidget(
        icon: Icons.emoji_events_outlined,
        title: 'No rankings yet',
        message: 'Be the first to play SkulMate and earn XP!',
      ),
    );
  }

  Widget _buildPodium() {
    final e = _displayEntries;
    if (e.isEmpty) return const SizedBox.shrink();
    final second = e.length > 1 ? e[1] : null;
    final first = e.first;
    final third = e.length > 2 ? e[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _podiumSlot(
            rank: 2,
            entry: second,
            color: AppTheme.skyBlue,
            height: 132,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _podiumSlot(
            rank: 1,
            entry: first,
            color: AppTheme.softYellow,
            height: 152,
            highlight: true,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _podiumSlot(
            rank: 3,
            entry: third,
            color: AppTheme.accentOrange,
            height: 118,
          ),
        ),
      ],
    );
  }

  Widget _podiumSlot({
    required int rank,
    required LeaderboardEntry? entry,
    required Color color,
    required double height,
    bool highlight = false,
  }) {
    if (entry == null) {
      return SizedBox(
        height: height + 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.softBorder, width: 2),
                color: AppTheme.neutral100,
              ),
              child: Icon(Icons.more_horiz, color: AppTheme.textLight, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              '—',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textLight,
              ),
            ),
          ],
        ),
      );
    }
    final me = entry.userId == _myUserId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (highlight)
          Icon(Icons.star_rounded, color: color, size: 22)
        else
          const SizedBox(height: 22),
        SizedBox(
          height: height,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withValues(alpha: 0.65),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: highlight ? 14 : 8,
                        spreadRadius: highlight ? 1 : 0,
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: _avatarForEntry(entry, me, size: highlight ? 52 : 46),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$rank${_suffix(rank)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (entry.userName ?? 'Player').length > 12
                      ? '${(entry.userName ?? 'Player').substring(0, 10)}…'
                      : (entry.userName ?? 'Player'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  '${_formatXp(entry.totalXP)} XP',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYourRankSummary() {
    final me = _myUserId;
    if (me == null) return const SizedBox.shrink();
    final rank = _myRankInScope;
    final weeklyXp = _myAllTimeEntry?.totalXP ?? 0;
    final label = rank != null
        ? 'Your rank: #$rank'
        : 'Your rank: —';
    final scope = _scopeIndex == 0 ? 'Global · all-time' : 'Friends · all-time';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              rank != null ? '#$rank' : '—',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  '$scope · ${_formatXp(weeklyXp)} XP',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _suffix(int r) {
    if (r % 100 >= 11 && r % 100 <= 13) return 'th';
    switch (r % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Widget _buildRankedListHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            'Rankings',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const Spacer(),
          Text(
            _scopeIndex == 0 ? 'All-time · Global' : 'All-time · Friends',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankRow({required int rank, required LeaderboardEntry entry}) {
    final isMe = entry.userId == _myUserId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? AppTheme.primaryColor.withValues(alpha: 0.45)
              : AppTheme.softBorder,
          width: isMe ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMedium,
              ),
            ),
          ),
          _avatarForEntry(entry, isMe, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.userName ?? 'Player',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'You',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'XP',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatXp(entry.totalXP),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatarForEntry(LeaderboardEntry entry, bool isMe, {required double size}) {
    final character = isMe
        ? _myCharacter
        : (entry.userCharacterId != null
            ? SkulMateCharacters.getById(entry.userCharacterId!)
            : null);
    final name = entry.userName ?? 'Player';
    final initial =
        name.trim().isEmpty ? '?' : name.trim().toUpperCase().substring(0, 1);

    if (character != null) {
      return ClipOval(
        child: Container(
          width: size,
          height: size,
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          child: Center(
            child: SkulMateCharacterWidget(
              character: character,
              size: size * 0.88,
              animated: false,
              showName: false,
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppTheme.neutral200,
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.textDark.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? AppTheme.primaryColor : AppTheme.textMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
