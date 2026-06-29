import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import 'skulmate_surface_styles.dart';

/// Mood-board game surfaces: deep blue header, white stage, feedback banners.
class GameDeepBlueHeader extends StatelessWidget {
  final String progressLabel;
  final double progressValue;
  final int xpEarned;
  final Widget? trailing;
  final Widget? mascot;

  const GameDeepBlueHeader({
    super.key,
    required this.progressLabel,
    required this.progressValue,
    required this.xpEarned,
    this.trailing,
    this.mascot,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progressValue.clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (mascot != null) ...[
                mascot!,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  progressLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: AppTheme.softYellow,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$xpEarned XP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: safeProgress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              color: AppTheme.skyBlue,
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded play area card.
class GameWhiteStage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const GameWhiteStage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

enum GameFeedbackTone { success, error, neutral }

/// Bottom feedback strip (Match It / puzzle).
class GameFeedbackBanner extends StatelessWidget {
  final GameFeedbackTone tone;
  final String message;

  const GameFeedbackBanner({
    super.key,
    required this.tone,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (tone) {
      GameFeedbackTone.success => (
          AppTheme.accentGreen.withValues(alpha: 0.12),
          const Color(0xFF166534),
          Icons.check_circle_rounded,
        ),
      GameFeedbackTone.error => (
          AppTheme.gameNudgeBg,
          AppTheme.gameNudgeFg,
          Icons.autorenew_rounded,
        ),
      GameFeedbackTone.neutral => (
          AppTheme.neutral100,
          AppTheme.textMedium,
          Icons.info_outline_rounded,
        ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: message.isEmpty
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : Container(
              key: ValueKey(message),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: fg.withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Flat in-game panel — hairline border, no heavy elevation.
class GameFlatPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GameFlatPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.softBorder.withValues(alpha: 0.95),
        ),
      ),
      child: child,
    );
  }
}

/// Minimal stats ribbon — sits on white under the light app bar (no extra card).
class GameStatsRibbon extends StatelessWidget {
  final String progressLabel;
  final double progressValue;
  final int xpEarned;
  final String? trailingChip;
  final String? streakLabel;
  final Color? progressColor;

  const GameStatsRibbon({
    super.key,
    required this.progressLabel,
    required this.progressValue,
    required this.xpEarned,
    this.trailingChip,
    this.streakLabel,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progressValue.clamp(0.0, 1.0);
    final barColor = progressColor ?? AppTheme.skyBlue;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: safeProgress),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: AppTheme.neutral100,
                  color: barColor,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  progressLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMedium,
                  ),
                ),
              ),
              if (streakLabel != null) ...[
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 14,
                  color: AppTheme.softYellow.withValues(alpha: 0.95),
                ),
                const SizedBox(width: 2),
                Text(
                  streakLabel!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (trailingChip != null) ...[
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 3),
                Text(
                  trailingChip!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              _XpChip(xp: xpEarned),
            ],
          ),
        ],
      ),
    );
  }
}

/// Brief edge glow on correct (green) or wrong (red) actions.
class GameEdgeFlash extends StatefulWidget {
  final int trigger;
  final bool success;

  const GameEdgeFlash({
    super.key,
    required this.trigger,
    required this.success,
  });

  @override
  State<GameEdgeFlash> createState() => _GameEdgeFlashState();
}

class _GameEdgeFlashState extends State<GameEdgeFlash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.trigger > 0) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant GameEdgeFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trigger <= 0) return const SizedBox.shrink();

    final color =
        widget.success ? AppTheme.accentGreen : AppTheme.gameNudgeGlow;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = (1 - _controller.value).clamp(0.0, 1.0);
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: color.withValues(alpha: (widget.success ? 0.45 : 0.28) * t),
                width: widget.success ? 3 : 2,
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

/// Minimal inline HUD — lives inside scroll content, not a separate bar.
class GameInlineHud extends StatelessWidget {
  final String progressLabel;
  final double progressValue;
  final int xpEarned;
  final String? trailingChip;
  final String? streakLabel;
  final Color? progressColor;

  const GameInlineHud({
    super.key,
    required this.progressLabel,
    required this.progressValue,
    required this.xpEarned,
    this.trailingChip,
    this.streakLabel,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progressValue.clamp(0.0, 1.0);
    final barColor = progressColor ?? AppTheme.skyBlue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                progressLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            if (streakLabel != null) ...[
              _MiniChip(
                icon: Icons.local_fire_department_rounded,
                label: streakLabel!,
                iconColor: AppTheme.softYellow,
                background: AppTheme.softYellowLight,
              ),
              const SizedBox(width: 6),
            ],
            if (trailingChip != null) ...[
              _MiniChip(
                icon: Icons.timer_outlined,
                label: trailingChip!,
                iconColor: AppTheme.primaryColor,
                background: AppTheme.primaryColor.withValues(alpha: 0.07),
              ),
              const SizedBox(width: 6),
            ],
            _XpChip(xp: xpEarned),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: safeProgress),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: AppTheme.neutral100,
                color: barColor,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color background;

  const _MiniChip({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _XpChip extends StatelessWidget {
  final int xp;

  const _XpChip({required this.xp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.softYellowLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.softYellow.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 13, color: AppTheme.softYellow),
          const SizedBox(width: 2),
          Text(
            '$xp',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Brief green pulse overlay on a correct match.
class GameMatchPulse extends StatefulWidget {
  final int trigger;

  const GameMatchPulse({super.key, required this.trigger});

  @override
  State<GameMatchPulse> createState() => _GameMatchPulseState();
}

class _GameMatchPulseState extends State<GameMatchPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.trigger > 0) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant GameMatchPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trigger <= 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return CustomPaint(
            painter: _PulsePainter(progress: t),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;

  _PulsePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height * 0.38);
    final radius = 40.0 + progress * 120;
    final paint = Paint()
      ..color = AppTheme.accentGreen.withValues(alpha: (1 - progress) * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Sleek white stats strip — sits below the deep-blue app bar (no double-blue stack).
class GameSleekHud extends StatelessWidget {
  final String progressLabel;
  final double progressValue;
  final int xpEarned;
  final String? trailingChip;
  final Color? progressColor;

  const GameSleekHud({
    super.key,
    required this.progressLabel,
    required this.progressValue,
    required this.xpEarned,
    this.trailingChip,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progressValue.clamp(0.0, 1.0);
    final barColor = progressColor ?? AppTheme.skyBlue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.softBorder.withValues(alpha: 0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  progressLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              if (trailingChip != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    trailingChip!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.softYellowLight,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTheme.softYellow.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: AppTheme.softYellow,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$xpEarned XP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: safeProgress,
              minHeight: 5,
              backgroundColor: AppTheme.neutral200,
              color: barColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating "+N XP" burst when the player earns points.
class GameXpBurst extends StatefulWidget {
  final int amount;
  final int trigger;

  const GameXpBurst({
    super.key,
    required this.amount,
    required this.trigger,
  });

  @override
  State<GameXpBurst> createState() => _GameXpBurstState();
}

class _GameXpBurstState extends State<GameXpBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.25, curve: Curves.easeOut),
        reverseCurve: const Interval(0.55, 1, curve: Curves.easeIn),
      ),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: const Offset(0, -0.6),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    if (widget.trigger > 0) _play();
  }

  @override
  void didUpdateWidget(covariant GameXpBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      _play();
    }
  }

  void _play() {
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trigger <= 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final opacity = _controller.value < 0.55
              ? _fade.value
              : 1 - ((_controller.value - 0.55) / 0.45);
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: SlideTransition(
              position: _slide,
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppTheme.stitchYellowGradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppTheme.softYellow.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: AppTheme.textDark),
              Text(
                '${widget.amount} XP',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary game CTA (deep blue or stitch yellow).
class GamePrimaryCta extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool useYellow;

  const GamePrimaryCta({
    super.key,
    required this.label,
    this.onPressed,
    this.useYellow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: useYellow
            ? SkulMateSurfaceStyles.puzzlePrimaryButton(
                enabled: onPressed != null,
              )
            : SkulMateSurfaceStyles.sheetPrimaryButton(
                enabled: onPressed != null,
              ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
