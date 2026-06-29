import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/skulmate_copy.dart';
import '../models/scroll_slide.dart';

/// Renders one slide in the immersive scroll feed.
class SkulMateScrollSlidePage extends StatefulWidget {
  final ScrollSlide slide;
  final int index;
  final int total;
  final bool isLastSlide;
  final bool flipped;
  final bool musicEnabled;
  final bool soundsEnabled;
  final bool isActive;
  final SkulMateCopy copy;
  final VoidCallback onFlip;
  final VoidCallback onKnew;
  final VoidCallback onAgain;
  final VoidCallback onToggleMusic;
  final VoidCallback onToggleSfx;
  final VoidCallback? onListen;
  final ValueChanged<bool>? onInteractiveAnswer;
  final VoidCallback? onCelebrateContinue;

  const SkulMateScrollSlidePage({
    super.key,
    required this.slide,
    required this.index,
    required this.total,
    this.isLastSlide = false,
    required this.flipped,
    required this.musicEnabled,
    required this.soundsEnabled,
    required this.isActive,
    required this.copy,
    required this.onFlip,
    required this.onKnew,
    required this.onAgain,
    required this.onToggleMusic,
    required this.onToggleSfx,
    this.onListen,
    this.onInteractiveAnswer,
    this.onCelebrateContinue,
  });

  static const slideGradients = [
    [Color(0xFF0A2A66), Color(0xFF1E4FA8), Color(0xFF3D7AE8)],
    [Color(0xFF1A0F3D), Color(0xFF4A1D7A), Color(0xFF8B3FD4)],
    [Color(0xFF0D3B2E), Color(0xFF1A6B52), Color(0xFF2DA87A)],
    [Color(0xFF3D1A0A), Color(0xFF8B3A1A), Color(0xFFE07A3A)],
    [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
  ];

  @override
  State<SkulMateScrollSlidePage> createState() =>
      _SkulMateScrollSlidePageState();
}

class _SkulMateScrollSlidePageState extends State<SkulMateScrollSlidePage> {
  int? _selectedOption;
  bool? _matchRevealed;
  bool _listenPlayed = false;

  @override
  void didUpdateWidget(SkulMateScrollSlidePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slide != widget.slide || !widget.isActive) {
      _selectedOption = null;
      _matchRevealed = null;
      _listenPlayed = false;
    }
    if (widget.isActive &&
        widget.slide.kind == ScrollSlideKind.listen &&
        !_listenPlayed) {
      _listenPlayed = true;
      widget.onListen?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SkulMateScrollSlidePage.slideGradients[
        widget.index % SkulMateScrollSlidePage.slideGradients.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildBody()),
            if (widget.slide.kind != ScrollSlideKind.celebrate)
              Positioned(
                right: 12,
                bottom: 120,
                child: _buildRail(),
              ),
            if (widget.slide.kind != ScrollSlideKind.celebrate)
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: _buildFooter(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (widget.slide.kind) {
      case ScrollSlideKind.hook:
        return _HookBody(
          slide: widget.slide,
          flipped: widget.flipped,
          copy: widget.copy,
          onTap: widget.onFlip,
        );
      case ScrollSlideKind.listen:
        return _ListenBody(
          slide: widget.slide,
          flipped: widget.flipped,
          copy: widget.copy,
          onTap: widget.onFlip,
          onListen: widget.onListen,
        );
      case ScrollSlideKind.mcq:
        return _McqBody(
          slide: widget.slide,
          copy: widget.copy,
          selected: _selectedOption,
          onSelect: (i) {
            HapticFeedback.mediumImpact();
            setState(() => _selectedOption = i);
            final correct = widget.slide.options[i].toLowerCase() ==
                widget.slide.answer.toLowerCase();
            widget.onInteractiveAnswer?.call(correct);
          },
        );
      case ScrollSlideKind.match:
        return _MatchBody(
          slide: widget.slide,
          copy: widget.copy,
          revealed: _matchRevealed ?? false,
          onReveal: () {
            HapticFeedback.mediumImpact();
            setState(() => _matchRevealed = true);
            widget.onInteractiveAnswer?.call(true);
          },
        );
      case ScrollSlideKind.celebrate:
        return _CelebrateBody(
          slide: widget.slide,
          copy: widget.copy,
          isLastSlide: widget.isLastSlide,
          onContinue: widget.onCelebrateContinue,
        );
      case ScrollSlideKind.reveal:
        return _RevealBody(
          slide: widget.slide,
          flipped: widget.flipped,
          copy: widget.copy,
          onTap: widget.onFlip,
        );
    }
  }

  Widget _buildRail() {
    final showRecall = widget.slide.needsRecallButtons;
    return Column(
      children: [
        _RailButton(
          icon: widget.musicEnabled
              ? Icons.music_note_rounded
              : Icons.music_off_rounded,
          label: widget.musicEnabled
              ? widget.copy.scrollMusicOn
              : widget.copy.scrollMusicOff,
          onTap: widget.onToggleMusic,
        ),
        const SizedBox(height: 14),
        _RailButton(
          icon: widget.soundsEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          label: widget.soundsEnabled
              ? widget.copy.scrollSfxOn
              : widget.copy.scrollSfxOff,
          onTap: widget.onToggleSfx,
        ),
        if (widget.slide.kind == ScrollSlideKind.listen) ...[
          const SizedBox(height: 14),
          _RailButton(
            icon: Icons.record_voice_over_rounded,
            label: widget.copy.scrollListen,
            onTap: widget.onListen ?? () {},
          ),
        ],
        if (showRecall && !widget.slide.isInteractive) ...[
          const SizedBox(height: 14),
          _RailButton(
            icon: widget.flipped
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            label: widget.copy.scrollRevealAction,
            onTap: widget.onFlip,
          ),
          const SizedBox(height: 14),
          _RailButton(
            icon: Icons.check_circle_outline_rounded,
            label: widget.copy.scrollGotIt,
            accent: const Color(0xFF4ADE80),
            onTap: widget.onKnew,
          ),
          const SizedBox(height: 14),
          _RailButton(
            icon: Icons.replay_rounded,
            label: widget.copy.scrollAgain,
            accent: const Color(0xFFFBBF24),
            onTap: widget.onAgain,
          ),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Icon(
          Icons.keyboard_arrow_up_rounded,
          color: Colors.white.withValues(alpha: 0.55),
          size: 28,
        ),
        Text(
          widget.copy.scrollSwipeHint,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.index + 1} / ${widget.total}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

class _HookBody extends StatelessWidget {
  final ScrollSlide slide;
  final bool flipped;
  final SkulMateCopy copy;
  final VoidCallback onTap;

  const _HookBody({
    required this.slide,
    required this.flipped,
    required this.copy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 88, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (slide.gameTitle?.isNotEmpty == true) _DeckChip(slide.gameTitle!),
            if (slide.emoji != null) ...[
              Text(slide.emoji!, style: const TextStyle(fontSize: 42)),
              const SizedBox(height: 12),
            ],
            Text(
              slide.hookLine ?? copy.scrollHookDefault,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.75),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Text(
                    flipped ? slide.answer : slide.prompt,
                    key: ValueKey(flipped),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: flipped ? 22 : 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              flipped ? copy.scrollTapTerm : copy.scrollTapReveal,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealBody extends StatelessWidget {
  final ScrollSlide slide;
  final bool flipped;
  final SkulMateCopy copy;
  final VoidCallback onTap;

  const _RevealBody({
    required this.slide,
    required this.flipped,
    required this.copy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 88, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (slide.gameTitle?.isNotEmpty == true) _DeckChip(slide.gameTitle!),
            Row(
              children: [
                if (slide.emoji != null) ...[
                  Text(slide.emoji!, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 8),
                ],
                Text(
                  flipped
                      ? copy.scrollRevealAction.toUpperCase()
                      : copy.scrollTermLabel.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Text(
                    flipped ? slide.answer : slide.prompt,
                    key: ValueKey(flipped),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: flipped ? 22 : 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              flipped ? copy.scrollTapTerm : copy.scrollTapReveal,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListenBody extends StatelessWidget {
  final ScrollSlide slide;
  final bool flipped;
  final SkulMateCopy copy;
  final VoidCallback onTap;
  final VoidCallback? onListen;

  const _ListenBody({
    required this.slide,
    required this.flipped,
    required this.copy,
    required this.onTap,
    this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 72, 88, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (slide.gameTitle?.isNotEmpty == true) _DeckChip(slide.gameTitle!),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.headphones_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    copy.scrollListenMode,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Text(
                    flipped ? slide.answer : slide.prompt,
                    key: ValueKey(flipped),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: flipped ? 22 : 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: onListen,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      copy.scrollPlayAloud,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _McqBody extends StatelessWidget {
  final ScrollSlide slide;
  final SkulMateCopy copy;
  final int? selected;
  final ValueChanged<int> onSelect;

  const _McqBody({
    required this.slide,
    required this.copy,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 72, 88, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (slide.gameTitle?.isNotEmpty == true) _DeckChip(slide.gameTitle!),
          Text(
            copy.scrollQuickCheck.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.prompt,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: slide.options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final option = slide.options[i];
                final isSelected = selected == i;
                final answered = selected != null;
                final isCorrect =
                    option.toLowerCase() == slide.answer.toLowerCase();
                Color? border;
                Color? fill;
                if (answered && isSelected) {
                  border = isCorrect
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFF87171);
                  fill = border.withValues(alpha: 0.25);
                } else if (answered && isCorrect) {
                  border = const Color(0xFF4ADE80);
                  fill = border.withValues(alpha: 0.2);
                }

                return GestureDetector(
                  onTap: answered ? null : () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: fill ?? Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: border ?? Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      option,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchBody extends StatelessWidget {
  final ScrollSlide slide;
  final SkulMateCopy copy;
  final bool revealed;
  final VoidCallback onReveal;

  const _MatchBody({
    required this.slide,
    required this.copy,
    required this.revealed,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 72, 88, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (slide.gameTitle?.isNotEmpty == true) _DeckChip(slide.gameTitle!),
          Text(
            copy.scrollMatchLabel.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const Spacer(),
          _MatchChip(label: slide.matchLeft ?? slide.prompt, accent: true),
          const SizedBox(height: 16),
          Icon(
            Icons.swap_vert_rounded,
            color: Colors.white.withValues(alpha: 0.6),
            size: 32,
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: revealed ? 1 : 0.35,
            duration: const Duration(milliseconds: 300),
            child: _MatchChip(
              label: slide.matchRight ?? slide.answer,
              accent: false,
            ),
          ),
          const Spacer(),
          if (!revealed)
            Center(
              child: FilledButton(
                onPressed: onReveal,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                child: Text(
                  copy.scrollRevealMatch,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MatchChip extends StatelessWidget {
  final String label;
  final bool accent;

  const _MatchChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CelebrateBody extends StatelessWidget {
  final ScrollSlide slide;
  final SkulMateCopy copy;
  final bool isLastSlide;
  final VoidCallback? onContinue;

  const _CelebrateBody({
    required this.slide,
    required this.copy,
    this.isLastSlide = false,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text(
              slide.celebrateTitle ?? copy.scrollCelebrateTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              slide.celebrateBody ?? copy.scrollCelebrateBody,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4A1D7A),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              child: Text(
                isLastSlide ? copy.scrollDone : copy.scrollKeepGoing,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckChip extends StatelessWidget {
  final String title;

  const _DeckChip(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;

  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              shape: BoxShape.circle,
              border: Border.all(
                color: (accent ?? Colors.white).withValues(alpha: 0.35),
              ),
            ),
            child: Icon(icon, color: accent ?? Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
