import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/premium_promo_card_shell.dart';
import 'package:prepskul/features/booking/models/upcoming_session_item.dart';
import 'package:prepskul/features/booking/utils/session_live_utils.dart';
import 'package:prepskul/features/dashboard/models/wallet_snapshot.dart';
import 'package:prepskul/features/dashboard/widgets/wallet_home_promo_card.dart';
import 'package:prepskul/features/skulmate/models/game_model.dart';
import 'package:prepskul/features/skulmate/services/daily_challenge_service.dart';
import 'package:shimmer/shimmer.dart';

/// Auto-rotating home promo cards (SkulMate, sessions, wallet).
class StudentHomePromoCarousel extends StatefulWidget {
  static const double cardHeight = 184;

  final List<GameModel> skulMateGames;
  final UpcomingSessionItem? nextSession;
  final int upcomingSessionsCount;
  final WalletSnapshot? wallet;
  final String userType;
  final bool isReady;
  final void Function(GameModel game, {bool isDailyChallenge}) onPlayGame;
  final VoidCallback? onOpenSkulMate;
  final VoidCallback? onCreateGame;
  final VoidCallback onFindTutors;
  final void Function(UpcomingSessionItem session) onOpenSession;
  final VoidCallback? onOpenWallet;

  const StudentHomePromoCarousel({
    super.key,
    required this.skulMateGames,
    this.nextSession,
    this.upcomingSessionsCount = 0,
    this.wallet,
    this.userType = 'student',
    this.isReady = true,
    required this.onPlayGame,
    this.onOpenSkulMate,
    this.onCreateGame,
    required this.onFindTutors,
    required this.onOpenSession,
    this.onOpenWallet,
  });

  @override
  State<StudentHomePromoCarousel> createState() =>
      _StudentHomePromoCarouselState();
}

class _StudentHomePromoCarouselState extends State<StudentHomePromoCarousel> {
  final PageController _pageController = PageController();
  Timer? _autoTimer;
  int _currentPage = 0;

  bool _loadingSkulMate = true;
  bool _dailyCompleted = false;
  bool _dailyHidden = false;
  int _streak = 0;
  GameModel? _todayGame;

  static const _autoPlayInterval = Duration(seconds: 5);

  bool get _isParent => widget.userType == 'parent';

  @override
  void initState() {
    super.initState();
    _loadSkulMateState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoPlay());
  }

  @override
  void didUpdateWidget(StudentHomePromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.skulMateGames != widget.skulMateGames ||
        oldWidget.nextSession?.id != widget.nextSession?.id ||
        oldWidget.upcomingSessionsCount != widget.upcomingSessionsCount ||
        oldWidget.userType != widget.userType) {
      _loadSkulMateState();
    }
    if (oldWidget.isReady != widget.isReady) {
      _startAutoPlay();
    }
  }

  Future<void> _loadSkulMateState() async {
    if (!AppConfig.enableSkulMate) {
      if (mounted) setState(() => _loadingSkulMate = false);
      _startAutoPlay();
      return;
    }
    setState(() => _loadingSkulMate = true);
    final completed = await DailyChallengeService.isCompletedToday();
    final hidden = await DailyChallengeService.isHiddenToday();
    final streak = await DailyChallengeService.getDailyStreak();
    final today = await DailyChallengeService.getTodayChallengeGame(
      widget.skulMateGames,
    );
    if (!mounted) return;
    setState(() {
      _dailyCompleted = completed;
      _dailyHidden = hidden;
      _streak = streak;
      _todayGame = today;
      _loadingSkulMate = false;
    });
    _startAutoPlay();
  }

  List<_HomeSlide> get _slides {
    final slides = <_HomeSlide>[];

    if (AppConfig.enableSkulMate &&
        !_loadingSkulMate &&
        !(_dailyCompleted && _dailyHidden)) {
      slides.add(_PromoHomeSlide(_skulMateSlide()));
    }

    final paidAhead = widget.wallet?.paidSessionsAhead ?? 0;
    final hasUpcomingSignal = widget.nextSession != null ||
        widget.upcomingSessionsCount > 0 ||
        paidAhead > 0;

    if (widget.nextSession != null) {
      slides.add(_PromoHomeSlide(_sessionSlide(widget.nextSession!)));
    } else if (!hasUpcomingSignal) {
      slides.add(_PromoHomeSlide(_bookTutorSlide()));
    }

    if (widget.onOpenWallet != null) {
      slides.add(
        _WalletHomeSlide(wallet: widget.wallet ?? WalletSnapshot.empty),
      );
    }

    return slides;
  }

  String _gameTypeLabel(GameType type) {
    switch (type) {
      case GameType.quiz:
        return 'Quiz';
      case GameType.flashcards:
        return 'Flashcards';
      case GameType.matching:
        return 'Matching';
      case GameType.fillBlank:
        return 'Fill in the blanks';
      case GameType.wordSearch:
        return 'Word search';
      case GameType.crossword:
        return 'Crossword';
      case GameType.match3:
        return 'Match-3';
      case GameType.bubblePop:
        return 'Bubble pop';
      case GameType.diagramLabel:
        return 'Label the diagram';
      case GameType.dragDrop:
        return 'Drag & drop';
      default:
        return 'Game';
    }
  }

  String _dailyChallengeDescription(GameModel game) {
    final topic = game.metadata.topic?.trim();
    final typeLabel = _gameTypeLabel(game.gameType);
    final count = game.metadata.totalItems;
    final title = game.title.trim();

    if (topic != null && topic.isNotEmpty && count > 0) {
      final unit = count == 1 ? 'question' : 'questions';
      return '$typeLabel on $topic. $count $unit pulled from your notes.';
    }
    if (topic != null && topic.isNotEmpty) {
      return '$typeLabel on $topic. Beat today\'s challenge while it is fresh.';
    }
    if (count > 0) {
      final unit = count == 1 ? 'item' : 'items';
      return '$typeLabel on $title. $count $unit to clear in today\'s challenge.';
    }
    return _isParent
        ? 'Today\'s challenge is ready. Help them beat it and lock in the lesson.'
        : 'Today\'s challenge is ready. Beat it and lock in what you learned.';
  }

  String _noGameDescription({required bool noGames, required bool dailyCompleted}) {
    if (noGames) {
      return _isParent
          ? 'Upload notes or photos to generate their first interactive quiz.'
          : 'Upload notes or photos to generate your first interactive quiz.';
    }
    if (dailyCompleted) {
      return _isParent
          ? 'Browse their library or create a new quiz from fresh notes.'
          : 'Browse your library or create a new quiz from fresh notes.';
    }
    return _isParent
        ? 'Quick games between lessons to keep them practicing.'
        : 'Jump into quick games between lessons.';
  }

  _PromoSlide _skulMateSlide() {
    final hasDaily = _todayGame != null && !_dailyCompleted;
    final noGames = widget.skulMateGames.isEmpty;

    if (hasDaily) {
      return _PromoSlide(
        eyebrow: 'DAILY SKULMATE',
        title: _todayGame!.title,
        subtitle: _streak > 0
            ? '$_streak-day streak. Keep it going.'
            : 'Today\'s challenge is ready',
        description: _dailyChallengeDescription(_todayGame!),
        buttonLabel: 'Play',
        mascotAsset: 'assets/characters/mascots/default.png',
        accent: AppTheme.skyBlue,
        onTap: () => widget.onPlayGame(_todayGame!, isDailyChallenge: true),
      );
    }

    if (noGames || _dailyCompleted) {
      return _PromoSlide(
        eyebrow: 'SKULMATE',
        title: noGames
            ? (_isParent ? 'Create their first game' : 'Create your first game')
            : (_isParent ? 'Explore more games' : 'Explore more games'),
        subtitle: noGames
            ? (_isParent
                ? 'Turn their notes into fun practice'
                : 'Turn notes into fun practice')
            : 'New games unlock daily',
        description: _noGameDescription(
          noGames: noGames,
          dailyCompleted: _dailyCompleted && !noGames,
        ),
        buttonLabel: noGames ? 'Create game' : 'Open SkulMate',
        mascotAsset: 'assets/characters/mascots/thinking.png',
        accent: AppTheme.primaryLight,
        onTap: noGames
            ? (widget.onCreateGame ?? widget.onOpenSkulMate ?? () {})
            : (widget.onOpenSkulMate ?? () {}),
      );
    }

    return _PromoSlide(
      eyebrow: 'SKULMATE',
      title: _isParent ? 'Games for your child' : 'Play & learn',
      subtitle: 'Games from your own notes',
      description: _noGameDescription(noGames: false, dailyCompleted: false),
      buttonLabel: 'Browse games',
      mascotAsset: 'assets/characters/mascots/encouraging.png',
      accent: AppTheme.skyBlue,
      onTap: widget.onOpenSkulMate ?? () {},
    );
  }

  _PromoSlide _sessionSlide(UpcomingSessionItem session) {
    final isLive = SessionLiveUtils.showsLiveUi(session.sessionMap);
    final isOnsite = session.location != 'online';
    final formatted =
        DateFormat('EEE, MMM d, HH:mm').format(session.scheduledStart);

    return _PromoSlide(
      eyebrow: isLive ? 'LIVE NOW' : 'NEXT LESSON',
      title: session.tutorName,
      subtitle: formatted,
      description: '${session.subject}, ${isOnsite ? 'on-site' : 'online'}',
      buttonLabel: isLive ? 'Join session' : 'View session',
      avatarUrl: session.tutorAvatarUrl,
      avatarFallback: session.tutorName,
      accent: isLive ? AppTheme.accentGreen : AppTheme.softYellow,
      badges: [
        if (isLive) 'LIVE' else SessionLiveUtils.displayStatusBadge(session.sessionMap),
        isOnsite ? 'On-site' : 'Online',
        if (session.isTrial) 'Trial',
      ],
      onTap: () => widget.onOpenSession(session),
    );
  }

  _PromoSlide _bookTutorSlide() {
    return _PromoSlide(
      eyebrow: 'FIND A TUTOR',
      title: _isParent
          ? 'Book your child\'s next lesson'
          : 'Book your next lesson',
      description: _isParent
          ? 'Browse verified tutors and pick a time that works for your child.'
          : 'Browse verified tutors and pick a time that works for you.',
      subtitle: 'Online or on-site sessions',
      buttonLabel: 'Find tutors',
      mascotAsset: 'assets/characters/mascots/encouraging.png',
      accent: AppTheme.softYellow,
      onTap: widget.onFindTutors,
    );
  }

  void _startAutoPlay() {
    _autoTimer?.cancel();
    final count = _slides.length;
    if (count <= 1) return;

    _autoTimer = Timer.periodic(_autoPlayInterval, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % count;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isReady) {
      return _CarouselShimmer(height: StudentHomePromoCarousel.cardHeight);
    }

    final slides = _slides;
    if (slides.isEmpty) return const SizedBox.shrink();

    if (slides.length == 1) {
      return _buildSlide(slides.first);
    }

    return Column(
      children: [
        SizedBox(
          height: StudentHomePromoCarousel.cardHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildSlide(slides[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (i) {
            final active = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: active
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.22),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSlide(_HomeSlide slide) {
    return switch (slide) {
      _PromoHomeSlide(:final promo) => _PromoCard(slide: promo),
      _WalletHomeSlide(:final wallet) => WalletHomePromoCard(
          wallet: wallet,
          isParent: _isParent,
          onTap: widget.onOpenWallet ?? () {},
        ),
    };
  }
}

class _CarouselShimmer extends StatelessWidget {
  final double height;

  const _CarouselShimmer({required this.height});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.neutral200,
      highlightColor: Colors.white,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

sealed class _HomeSlide {}

class _PromoHomeSlide extends _HomeSlide {
  final _PromoSlide promo;
  _PromoHomeSlide(this.promo);
}

class _WalletHomeSlide extends _HomeSlide {
  final WalletSnapshot wallet;
  _WalletHomeSlide({required this.wallet});
}

class _PromoSlide {
  final String eyebrow;
  final String title;
  final String description;
  final String subtitle;
  final String buttonLabel;
  final String? mascotAsset;
  final String? avatarUrl;
  final String? avatarFallback;
  final Color accent;
  final List<String> badges;
  final VoidCallback onTap;

  const _PromoSlide({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.subtitle,
    required this.buttonLabel,
    this.mascotAsset,
    this.avatarUrl,
    this.avatarFallback,
    this.accent = AppTheme.skyBlue,
    this.badges = const [],
    required this.onTap,
  });
}

class _PromoCard extends StatelessWidget {
  final _PromoSlide slide;

  const _PromoCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    final textWidth = MediaQuery.sizeOf(context).width * 0.54;

    return PremiumPromoCardShell(
      height: StudentHomePromoCarousel.cardHeight,
      accent: slide.accent,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slide.eyebrow,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: textWidth,
                child: Text(
                  slide.title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (slide.subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                SizedBox(
                  width: textWidth,
                  child: Text(
                    slide.subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.72),
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (slide.description.isNotEmpty) ...[
                const SizedBox(height: 3),
                SizedBox(
                  width: textWidth,
                  child: Text(
                    slide.description,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (slide.badges.isNotEmpty) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: textWidth,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: slide.badges.map(_badge).toList(),
                  ),
                ),
              ],
              const Spacer(),
              PremiumGlassButton(label: slide.buttonLabel, onTap: slide.onTap),
            ],
          ),
          Positioned(
            top: 28,
            right: 4,
            child: _trailingVisual(),
          ),
        ],
      ),
    );
  }

  Widget _trailingVisual() {
    if (slide.avatarUrl != null && slide.avatarUrl!.isNotEmpty) {
      return Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: slide.avatarUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _avatarFallback(),
          ),
        ),
      );
    }
    if (slide.avatarFallback != null &&
        (slide.avatarUrl == null || slide.avatarUrl!.isEmpty)) {
      return _avatarFallback();
    }
    if (slide.mascotAsset != null) {
      return SizedBox(
        width: 88,
        height: 88,
        child: Image.asset(
          slide.mascotAsset!,
          fit: BoxFit.contain,
          alignment: Alignment.centerRight,
          errorBuilder: (_, __, ___) => Icon(
            Icons.auto_awesome,
            color: Colors.white.withValues(alpha: 0.8),
            size: 40,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _avatarFallback() {
    final initial = (slide.avatarFallback?.isNotEmpty ?? false)
        ? slide.avatarFallback![0].toUpperCase()
        : 'T';
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _badge(String label) {
    final upper = label.toUpperCase();
    final isLive = upper.contains('LIVE');
    final isUpcoming = upper == 'UPCOMING';

    Color bg;
    Color border;
    Color textColor = Colors.white;

    if (isLive) {
      bg = AppTheme.accentGreen.withValues(alpha: 0.28);
      border = AppTheme.accentGreen.withValues(alpha: 0.5);
    } else if (isUpcoming) {
      bg = AppTheme.softYellow.withValues(alpha: 0.32);
      border = AppTheme.softYellow.withValues(alpha: 0.55);
      textColor = Colors.white.withValues(alpha: 0.95);
    } else {
      bg = Colors.white.withValues(alpha: 0.12);
      border = Colors.white.withValues(alpha: 0.22);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
