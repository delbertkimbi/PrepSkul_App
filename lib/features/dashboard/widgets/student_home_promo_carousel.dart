import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/alive_mate.dart';
import 'package:prepskul/core/widgets/premium_promo_card_shell.dart';
import 'package:prepskul/features/onboarding/learner/learner_onboarding_chrome.dart';
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

  bool _dailyCompleted = false;
  bool _dailyHidden = false;
  int _streak = 0;
  GameModel? _todayGame;

  static const _autoPlayInterval = Duration(seconds: 5);
  static const _autoPlayStartDelay = Duration(seconds: 4);

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
    final oldSlideCount = _slidesFor(
      games: oldWidget.skulMateGames,
      nextSession: oldWidget.nextSession,
      upcomingCount: oldWidget.upcomingSessionsCount,
      wallet: oldWidget.wallet,
    ).length;

    if (oldWidget.skulMateGames != widget.skulMateGames ||
        oldWidget.nextSession?.id != widget.nextSession?.id ||
        oldWidget.upcomingSessionsCount != widget.upcomingSessionsCount ||
        oldWidget.userType != widget.userType ||
        oldWidget.isReady != widget.isReady) {
      _loadSkulMateState(reload: true);
    }

    final newSlideCount = _slides.length;
    if (oldSlideCount != newSlideCount && _pageController.hasClients) {
      _currentPage = 0;
      _pageController.jumpToPage(0);
      _startAutoPlay();
    } else if (oldWidget.isReady != widget.isReady) {
      _startAutoPlay();
    }
  }

  Future<void> _loadSkulMateState({bool reload = false}) async {
    if (!AppConfig.enableSkulMate) {
      _startAutoPlay();
      return;
    }
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
    });
    _startAutoPlay();
  }

  List<_HomeSlide> _slidesFor({
    required List<GameModel> games,
    required UpcomingSessionItem? nextSession,
    required int upcomingCount,
    required WalletSnapshot? wallet,
  }) {
    final slides = <_HomeSlide>[];

    if (AppConfig.enableSkulMate && !(_dailyCompleted && _dailyHidden)) {
      slides.add(_PromoHomeSlide(_skulMateSlideForGames(games)));
    }

    final paidAhead = wallet?.paidSessionsAhead ?? 0;
    final hasUpcomingSignal =
        nextSession != null || upcomingCount > 0 || paidAhead > 0;

    if (nextSession != null) {
      slides.add(_PromoHomeSlide(_sessionSlide(nextSession)));
    } else if (!hasUpcomingSignal) {
      slides.add(_PromoHomeSlide(_bookTutorSlide()));
    }

    if (widget.onOpenWallet != null) {
      slides.add(
        _WalletHomeSlide(wallet: wallet ?? WalletSnapshot.empty),
      );
    }

    return slides;
  }

  List<_HomeSlide> get _slides => _slidesFor(
        games: widget.skulMateGames,
        nextSession: widget.nextSession,
        upcomingCount: widget.upcomingSessionsCount,
        wallet: widget.wallet,
      );

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
        ? 'Today\'s challenge is ready. Beat it and lock in the lesson.'
        : 'Today\'s challenge is ready. Beat it and lock in what you learned.';
  }

  String _noGameDescription({required bool noGames, required bool dailyCompleted}) {
    if (noGames) {
      return 'Upload notes or photos to generate your first interactive quiz.';
    }
    if (dailyCompleted) {
      return 'Browse your library or create a new quiz from fresh notes.';
    }
    return 'Jump into quick games between lessons.';
  }

  _PromoSlide _skulMateSlideForGames(List<GameModel> games) {
    final hasDaily = _todayGame != null && !_dailyCompleted;
    final noGames = games.isEmpty;

    if (hasDaily) {
      return _PromoSlide(
        eyebrow: 'MATE',
        title: _todayGame!.title,
        subtitle: _streak > 0
            ? '$_streak-day streak. Keep it going.'
            : 'Today\'s challenge is ready',
        description: _dailyChallengeDescription(_todayGame!),
        buttonLabel: 'Play',
        mascotMood: Mood.point,
        accent: AppTheme.skyBlue,
        onTap: () => widget.onPlayGame(_todayGame!, isDailyChallenge: true),
      );
    }

    if (noGames || _dailyCompleted) {
      return _PromoSlide(
        eyebrow: 'MATE',
        title: 'Talk. I’m already listening.',
        subtitle: noGames
            ? 'No notes required. Interrupt anytime.'
            : 'Type if the phone is shared.',
        description: _noGameDescription(
          noGames: noGames,
          dailyCompleted: _dailyCompleted && !noGames,
        ),
        buttonLabel: 'Talk to Mate',
        mascotMood: Mood.talk,
        accent: AppTheme.primaryLight,
        onTap: widget.onOpenSkulMate ?? () {},
      );
    }

    return _PromoSlide(
      eyebrow: 'MATE',
      title: 'Talk. I’m already listening.',
      subtitle: 'Games from what you bring me',
      description: _noGameDescription(noGames: false, dailyCompleted: false),
      buttonLabel: 'Talk to Mate',
      mascotMood: Mood.talk,
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
      eyebrow: 'FIND A PERSON',
      title: 'Need a person at the table?',
      description: _isParent
          ? 'Find a tutor, or request one. Live online, or onsite.'
          : 'Find a tutor, or request one. Live online, or onsite.',
      subtitle: 'Mate first. A person when you ask.',
      buttonLabel: 'Find a person',
      mascotMood: Mood.point,
      accent: AppTheme.softYellow,
      onTap: widget.onFindTutors,
    );
  }

  void _startAutoPlay() {
    _autoTimer?.cancel();
    final count = _slides.length;
    if (count <= 1 || !widget.isReady) return;

    _autoTimer = Timer(_autoPlayStartDelay, () {
      if (!mounted || !_pageController.hasClients) return;
      _autoTimer = Timer.periodic(_autoPlayInterval, (_) {
        if (!mounted || !_pageController.hasClients) return;
        final slideCount = _slides.length;
        if (slideCount <= 1) return;
        final next = (_currentPage + 1) % slideCount;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutCubic,
        );
      });
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
  final Mood? mascotMood;
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
    this.mascotMood,
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
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: textWidth,
                child: Text(
                  slide.title,
                  style: onboardDisplay(
                    size: 18,
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
                    style: onboardFont(
                      size: 11,
                      weight: FontWeight.w700,
                      color: AppTheme.textMedium,
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
                    style: onboardFont(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppTheme.textMedium,
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
            top: 8,
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
            color: AppTheme.primaryColor,
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
    if (slide.mascotMood != null) {
      return SizedBox(
        width: 88,
        height: 88,
        child: AliveMate(
          mood: slide.mascotMood!,
          size: 88,
          flip: true,
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
        color: AppTheme.skyBlueLight,
        border: Border.all(color: AppTheme.primaryColor, width: 2.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: onboardDisplay(
          size: 28,
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
    Color textColor = AppTheme.primaryColor;

    if (isLive) {
      bg = AppTheme.accentGreen.withValues(alpha: 0.16);
      border = AppTheme.accentGreen;
    } else if (isUpcoming) {
      bg = AppTheme.softYellowLight;
      border = AppTheme.softYellow;
      textColor = AppTheme.primaryColor;
    } else {
      bg = Colors.white;
      border = AppTheme.primaryColor.withValues(alpha: 0.28);
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
