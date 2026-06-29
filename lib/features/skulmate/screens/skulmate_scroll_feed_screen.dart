import 'dart:async' show unawaited;
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/mobile_analytics_ingest_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../models/revision_deck_model.dart';
import '../models/scroll_slide.dart';
import '../services/game_sound_service.dart';
import '../services/revision_deck_service.dart';
import '../services/scroll_feed_service.dart';
import '../services/skulmate_study_audio_service.dart';
import '../services/spaced_repetition_service.dart';
import '../utils/sm2_lite.dart';
import '../utils/skulmate_navigation.dart';
import '../widgets/skulmate_scroll_slide_page.dart';
import '../widgets/skulmate_session_chrome.dart';
import '../widgets/skulmate_surface_styles.dart';

/// Vertical swipe revision feed — TikTok-style immersive cards.
class SkulMateScrollFeedScreen extends StatefulWidget {
  final GameModel? seedGame;
  final String? childId;

  const SkulMateScrollFeedScreen({
    super.key,
    this.seedGame,
    this.childId,
  });

  @override
  State<SkulMateScrollFeedScreen> createState() =>
      _SkulMateScrollFeedScreenState();
}

class _SkulMateScrollFeedScreenState extends State<SkulMateScrollFeedScreen> {
  final _pageController = PageController();
  final GameSoundService _soundService = GameSoundService();
  final SkulMateStudyAudioService _studyAudio =
      SkulMateStudyAudioService.instance;
  late ConfettiController _confetti;
  List<ScrollSlide> _slides = [];
  bool _loading = true;
  int _index = 0;
  int _reviewed = 0;
  int _known = 0;
  bool _flipped = false;
  bool _sessionEnded = false;
  bool _showCompletion = false;
  bool _soundsEnabled = true;
  bool _musicEnabled = true;
  bool _gestureRegistered = false;
  bool _isLeaving = false;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    unawaited(_initAudio());
    _loadQueue();
  }

  Future<void> _initAudio() async {
    await _studyAudio.acquireStudyAmbience(SkulMateStudyAudioOwner.scrollFeed);
    _soundsEnabled = _studyAudio.soundsEnabled;
    _musicEnabled = _studyAudio.musicEnabled;
    if (mounted) safeSetState(() {});
  }

  @override
  void dispose() {
    _isLeaving = true;
    _confetti.dispose();
    unawaited(
      _studyAudio.releaseStudyAmbience(SkulMateStudyAudioOwner.scrollFeed),
    );
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _registerGestureIfNeeded() async {
    if (_gestureRegistered) return;
    _gestureRegistered = true;
    await _studyAudio.registerUserGesture();
  }

  Future<void> _loadQueue() async {
    RevisionDeckModel? deck;
    if (widget.seedGame != null) {
      deck = await RevisionDeckService.resolveForGame(widget.seedGame!);
    }
    final session = await ScrollFeedService.buildSession(
      seedGame: widget.seedGame,
      deck: deck,
      childId: widget.childId,
    );
    safeSetState(() {
      _slides = session.slides;
      _loading = false;
      _startedAt = DateTime.now();
    });
    if (_slides.isEmpty && mounted) {
      await _endSession(completed: false);
    }
  }

  ScrollSlide? get _currentSlide =>
      _index < _slides.length ? _slides[_index] : null;

  Future<void> _onPageChanged(int i) async {
    if (i == _index) return;
    await _registerGestureIfNeeded();
    await _studyAudio.stopSpeaking();
    HapticFeedback.selectionClick();
    if (_soundsEnabled) unawaited(_soundService.playClick());
    safeSetState(() {
      _index = i;
    _flipped = false;
    });
    final slide = _slides[i];
    if (slide.kind == ScrollSlideKind.celebrate) {
      _confetti.play();
    }
  }

  Future<void> _toggleMusic() async {
    await _registerGestureIfNeeded();
    await _studyAudio.toggleMusic();
    safeSetState(() => _musicEnabled = _studyAudio.musicEnabled);
  }

  Future<void> _toggleSfx() async {
    await _registerGestureIfNeeded();
    final next = !_soundsEnabled;
    await _studyAudio.toggleSounds(next);
    safeSetState(() => _soundsEnabled = next);
  }

  Future<void> _onFlip() async {
    await _registerGestureIfNeeded();
    safeSetState(() => _flipped = !_flipped);
    final slide = _currentSlide;
    if (slide != null && _flipped && slide.needsRecallButtons) {
      unawaited(_studyAudio.speakScrollText(slide.answer));
    }
  }

  Future<void> _onListen() async {
    await _registerGestureIfNeeded();
    final slide = _currentSlide;
    if (slide == null) return;
    final text = _flipped ? slide.answer : slide.prompt;
    await _studyAudio.speakScrollText(text);
  }

  Future<void> _recordSlideReview({
    required ScrollSlide slide,
    required bool knew,
    bool playSound = true,
  }) async {
    if (slide.kind == ScrollSlideKind.celebrate) return;

    if (playSound && _soundsEnabled) {
      unawaited(knew ? _soundService.playCorrect() : _soundService.playClick());
    }

    await SpacedRepetitionService.recordReview(
      gameId: slide.gameId,
      itemIndex: slide.itemIndex,
      quality: qualityFromFlashcardKnown(knew),
      conceptKey: conceptKeyFromTerm(slide.prompt),
      childId: widget.childId,
    );

    safeSetState(() {
      _reviewed++;
      if (knew) _known++;
    });
  }

  Future<void> _onResponse({required bool knew}) async {
    final slide = _currentSlide;
    if (slide == null) return;

    await _registerGestureIfNeeded();
    _flipped = false;
    await _recordSlideReview(slide: slide, knew: knew);
    await _maybeGateOrAdvance();
  }

  Future<void> _onInteractiveAnswer(bool correct) async {
    final slide = _currentSlide;
    if (slide == null) return;

    await _registerGestureIfNeeded();
    if (correct) _confetti.play();
    await _recordSlideReview(slide: slide, knew: correct, playSound: true);

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await _maybeGateOrAdvance();
  }

  Future<void> _onCelebrateContinue() async {
    await _registerGestureIfNeeded();
    _confetti.play();
    await _advanceSlide();
  }

  Future<void> _maybeGateOrAdvance() async {
    final gate = ScrollFeedService.masteryGateEvery;
    if (_reviewed > 0 &&
        _reviewed % gate == 0 &&
        _index < _slides.length - 1) {
      if (!mounted) return;
      final copy = SkulMateCopy.read(context);
      final keepGoing = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                copy.scrollGateTitle,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
            copy.scrollGateBody(_known, _reviewed),
                style: GoogleFonts.plusJakartaSans(
                  height: 1.4,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(copy.scrollDone),
            ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(copy.scrollKeepGoing),
                    ),
                  ),
                ],
            ),
          ],
          ),
        ),
      );
      if (keepGoing != true) {
        await _endSession(completed: true);
        return;
      }
    }

    if (_index >= _slides.length - 1) {
      await _endSession(completed: true);
      return;
    }

    await _advanceSlide();
  }

  Future<void> _advanceSlide() async {
    if (_index >= _slides.length - 1) {
      await _endSession(completed: true);
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _leaveSession() async {
    if (_isLeaving) return;
    _isLeaving = true;
    await _studyAudio.stopSpeaking();
    if (mounted) {
      await SkulMateNavigation.popGame(context);
    }
  }

  Future<void> _confirmLeave() async {
    if (_isLeaving) return;
    if (_reviewed == 0) {
      await _leaveSession();
      return;
    }
    final copy = SkulMateCopy.read(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(copy.scrollLeaveTitle),
        content: Text(copy.scrollLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(copy.scrollKeepGoing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(copy.scrollLeaveConfirm),
          ),
        ],
      ),
    );
    if (leave == true) await _leaveSession();
  }

  Future<void> _endSession({required bool completed}) async {
    if (_sessionEnded || _isLeaving) return;
    if (!completed) {
      await _confirmLeave();
      return;
    }
    _sessionEnded = true;
    await _studyAudio.stopSpeaking();

    final userId = SupabaseService.client.auth.currentUser?.id;
    final durationSec = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;

    unawaited(
      MobileAnalyticsIngestService.trackEvent(
        eventType: 'skulmate_scroll_session_end',
        userId: userId,
        metadata: {
          'cardsReviewed': _reviewed,
          'cardsKnown': _known,
          'queueSize': _slides.length,
          'completed': completed,
          'durationSec': durationSec,
          if (widget.childId != null) 'childId': widget.childId,
        },
      ),
    );

    if (!mounted) return;
    if (_slides.isEmpty) {
      await _leaveSession();
      return;
    }

    _confetti.play();
    safeSetState(() => _showCompletion = true);
  }

  List<Color> get _completionGradient {
    if (_slides.isEmpty) {
      return SkulMateScrollSlidePage.slideGradients.first;
    }
    return SkulMateScrollSlidePage.slideGradients[
        _index % SkulMateScrollSlidePage.slideGradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_showCompletion) {
            unawaited(_leaveSession());
          } else {
            unawaited(_endSession(completed: false));
          }
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: _loading
          ? SkulMateSurfaceStyles.lightStatusBarOverlay
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _loading ? AppTheme.softBackground : Colors.black,
      body: _loading
            ? SkulMateSessionLoadingView(
                title: copy.scrollLoadingTitle,
                subtitle: copy.scrollLoadingSubtitle,
              )
            : _slides.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      copy.scrollEmptyQueue,
                      textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textMedium,
                        height: 1.45,
                      ),
                    ),
                  ),
                )
                : Stack(
                    children: [
                      PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                        physics: const BouncingScrollPhysics(
                          parent: PageScrollPhysics(),
                        ),
                        onPageChanged: (i) => unawaited(_onPageChanged(i)),
                        itemCount: _slides.length,
                        itemBuilder: (context, i) {
                          final slide = _slides[i];
                          return SkulMateScrollSlidePage(
                            slide: slide,
                            index: i,
                            total: _slides.length,
                            isLastSlide: i == _slides.length - 1,
                    flipped: i == _index && _flipped,
                            musicEnabled: _musicEnabled,
                            soundsEnabled: _soundsEnabled,
                            isActive: i == _index,
                            copy: copy,
                    onFlip: () {
                              if (i == _index) unawaited(_onFlip());
                            },
                            onKnew: () => unawaited(_onResponse(knew: true)),
                            onAgain: () => unawaited(_onResponse(knew: false)),
                            onToggleMusic: () => unawaited(_toggleMusic()),
                            onToggleSfx: () => unawaited(_toggleSfx()),
                            onListen: () => unawaited(_onListen()),
                            onInteractiveAnswer: (correct) => unawaited(
                              _onInteractiveAnswer(correct),
                            ),
                            onCelebrateContinue: () => unawaited(
                              i == _slides.length - 1
                                  ? _endSession(completed: true)
                                  : _onCelebrateContinue(),
                            ),
                          );
                        },
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConfettiWidget(
                          confettiController: _confetti,
                          blastDirection: pi / 2,
                          maxBlastForce: 18,
                          minBlastForce: 8,
                          emissionFrequency: 0.04,
                          numberOfParticles: 24,
                          gravity: 0.15,
                          colors: const [
                            Color(0xFF8B3FD4),
                            Color(0xFF4ADE80),
                            Color(0xFFFBBF24),
                            Color(0xFF3D7AE8),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_slides.isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: (_index + 1) / _slides.length,
                                      minHeight: 3,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.2),
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(8, 4, 16, 8),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                      ),
                                      onPressed: () => unawaited(
                                        _endSession(completed: false),
                                      ),
                                    ),
                                    if (_index == _slides.length - 1 &&
                                        !_showCompletion)
                                      TextButton(
                                        onPressed: () => unawaited(
                                          _endSession(completed: true),
                                        ),
                                        child: Text(
                                          copy.scrollFinishSession,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            copy.scrollFeedTitle,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            copy.scrollObjective,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white
                                                  .withValues(alpha: 0.75),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showCompletion)
                        SkulMateScrollCompletionOverlay(
                          gradientColors: _completionGradient,
                          title: copy.scrollSessionEndTitle,
                          body: copy.scrollSessionEndBody(_reviewed, _known),
                          doneLabel: copy.scrollDone,
                          onDone: () {
                            if (mounted) unawaited(_leaveSession());
                          },
                        ),
                    ],
                  ),
                  ),
                ),
    );
  }
}
