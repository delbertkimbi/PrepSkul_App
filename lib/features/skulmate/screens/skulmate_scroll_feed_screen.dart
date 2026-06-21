import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/mobile_analytics_ingest_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

import '../l10n/skulmate_copy.dart';
import '../models/game_model.dart';
import '../models/scroll_feed_item.dart';
import '../services/scroll_feed_service.dart';
import '../services/spaced_repetition_service.dart';
import '../utils/sm2_lite.dart';
import '../widgets/skulmate_surface_styles.dart';

/// D2 — vertical swipe revision feed (bounded session, due queue first).
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
  List<ScrollFeedItem> _queue = [];
  bool _loading = true;
  int _index = 0;
  int _reviewed = 0;
  int _known = 0;
  bool _flipped = false;
  bool _sessionEnded = false;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadQueue() async {
    final queue = await ScrollFeedService.buildQueue(
      seedGame: widget.seedGame,
      childId: widget.childId,
    );
    safeSetState(() {
      _queue = queue;
      _loading = false;
      _startedAt = DateTime.now();
    });
    if (queue.isEmpty && mounted) {
      await _endSession(completed: false);
    }
  }

  Future<void> _onResponse({required bool knew}) async {
    if (_index >= _queue.length) return;
    final card = _queue[_index];
    _flipped = false;

    await SpacedRepetitionService.recordReview(
      gameId: card.gameId,
      itemIndex: card.itemIndex,
      quality: qualityFromFlashcardKnown(knew),
      conceptKey: conceptKeyFromTerm(card.term),
      childId: widget.childId,
    );

    safeSetState(() {
      _reviewed++;
      if (knew) _known++;
    });

    final gate = ScrollFeedService.masteryGateEvery;
    if (_reviewed % gate == 0 && _index < _queue.length - 1) {
      if (!mounted) return;
      final copy = SkulMateCopy.read(context);
      final keepGoing = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            copy.scrollGateTitle,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Text(
            copy.scrollGateBody(_known, _reviewed),
            style: GoogleFonts.poppins(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(copy.scrollDone),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(copy.scrollKeepGoing),
            ),
          ],
        ),
      );
      if (keepGoing != true) {
        await _endSession(completed: true);
        return;
      }
    }

    if (_index >= _queue.length - 1) {
      await _endSession(completed: true);
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    safeSetState(() => _index++);
  }

  Future<void> _endSession({required bool completed}) async {
    if (_sessionEnded) return;
    _sessionEnded = true;

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
          'queueSize': _queue.length,
          'completed': completed,
          'durationSec': durationSec,
          if (widget.childId != null) 'childId': widget.childId,
        },
      ),
    );

    if (!mounted) return;
    final copy = SkulMateCopy.read(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          copy.scrollSessionEndTitle,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          copy.scrollSessionEndBody(_reviewed, _known),
          style: GoogleFonts.poppins(height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(copy.scrollDone),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.softBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textDark),
          onPressed: () => _endSession(completed: false),
        ),
        title: Text(
          copy.scrollFeedTitle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
            fontSize: 17,
          ),
        ),
        actions: [
          if (_queue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_index + 1}/${_queue.length}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMedium,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _queue.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      copy.scrollEmptyQueue,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: AppTheme.textMedium,
                        height: 1.45,
                      ),
                    ),
                  ),
                )
              : PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: const PageScrollPhysics(),
                  onPageChanged: (i) {
                    safeSetState(() {
                      _index = i;
                      _flipped = false;
                    });
                  },
                  itemCount: _queue.length,
                  itemBuilder: (context, i) => _ScrollCard(
                    item: _queue[i],
                    flipped: i == _index && _flipped,
                    onFlip: () {
                      if (i == _index) safeSetState(() => _flipped = !_flipped);
                    },
                    onKnew: () => _onResponse(knew: true),
                    onAgain: () => _onResponse(knew: false),
                    copy: copy,
                  ),
                ),
    );
  }
}

class _ScrollCard extends StatelessWidget {
  final ScrollFeedItem item;
  final bool flipped;
  final VoidCallback onFlip;
  final VoidCallback onKnew;
  final VoidCallback onAgain;
  final SkulMateCopy copy;

  const _ScrollCard({
    required this.item,
    required this.flipped,
    required this.onFlip,
    required this.onKnew,
    required this.onAgain,
    required this.copy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onFlip,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: SkulMateSurfaceStyles.chipCard().copyWith(
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (item.gameTitle != null) ...[
                        Text(
                          item.gameTitle!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textMedium,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        flipped ? item.definition : item.term,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: flipped ? 18 : 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        flipped ? copy.scrollTapTerm : copy.scrollTapReveal,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onAgain,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.softBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    copy.scrollAgain,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onKnew,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    copy.scrollGotIt,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}