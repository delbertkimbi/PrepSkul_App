import 'dart:async' show unawaited;
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import '../l10n/skulmate_copy.dart';
import 'skulmate_mascot_media_widget.dart';

/// Gizmo-style loading chrome — mascot + pill progress on a light surface.
class SkulMateSessionLoadingView extends StatefulWidget {
  final String title;
  final String? subtitle;

  const SkulMateSessionLoadingView({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  State<SkulMateSessionLoadingView> createState() =>
      _SkulMateSessionLoadingViewState();
}

class _SkulMateSessionLoadingViewState extends State<SkulMateSessionLoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.softBackground,
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 120,
                  height: 120,
                  child: SkulMateMascotMediaWidget(
                    state: SkulMateMascotState.thinking,
                    showFrame: false,
                    preferStaticImage: true,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      height: 1.4,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final barWidth = width * 0.72;
                        final offset =
                            (width - barWidth) * _progressController.value;
                        return Container(
                          height: 8,
                          width: width,
                          decoration: BoxDecoration(
                            color: AppTheme.accentPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Stack(
                            children: [
                              Positioned(
                                left: offset,
                                child: Container(
                                  width: barWidth,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentPurple,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Celebration sheet shown when a scroll (or study) session completes.
class SkulMateSessionCompleteSheet extends StatefulWidget {
  final String title;
  final String body;
  final String doneLabel;
  final String? secondaryLabel;
  final VoidCallback onDone;
  final VoidCallback? onSecondary;

  const SkulMateSessionCompleteSheet({
    super.key,
    required this.title,
    required this.body,
    required this.doneLabel,
    this.secondaryLabel,
    required this.onDone,
    this.onSecondary,
  });

  @override
  State<SkulMateSessionCompleteSheet> createState() =>
      _SkulMateSessionCompleteSheetState();
}

class _SkulMateSessionCompleteSheetState extends State<SkulMateSessionCompleteSheet>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confetti;
  late AnimationController _scaleController;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _scale = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    _scaleController.forward();
    unawaited(Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _confetti.play();
    }));
  }

  @override
  void dispose() {
    _confetti.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textDark.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: ScaleTransition(
                  scale: _scale,
                  child: const SizedBox(
                    width: 88,
                    height: 88,
                    child: SkulMateMascotMediaWidget(
                      state: SkulMateMascotState.celebration,
                      showFrame: false,
                      preferStaticImage: true,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.body,
                      style: GoogleFonts.plusJakartaSans(
                        height: 1.45,
                        color: AppTheme.textMedium,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: widget.onDone,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        widget.doneLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (widget.secondaryLabel != null &&
                        widget.onSecondary != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: widget.onSecondary,
                        child: Text(widget.secondaryLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirection: -pi / 2,
            maxBlastForce: 18,
            minBlastForce: 8,
            emissionFrequency: 0.04,
            numberOfParticles: 14,
            gravity: 0.12,
            colors: const [
              AppTheme.accentPurple,
              AppTheme.accentGreen,
              AppTheme.skyBlue,
              AppTheme.accentOrange,
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows the scroll session complete sheet modally.
Future<void> showSkulMateSessionCompleteSheet({
  required BuildContext context,
  required SkulMateCopy copy,
  required int reviewed,
  required int known,
  required VoidCallback onDone,
  VoidCallback? onKeepGoing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SkulMateSessionCompleteSheet(
      title: copy.scrollSessionEndTitle,
      body: copy.scrollSessionEndBody(reviewed, known),
      doneLabel: copy.scrollDone,
      secondaryLabel: onKeepGoing != null ? copy.scrollKeepGoing : null,
      onDone: () {
        Navigator.pop(ctx);
        onDone();
      },
      onSecondary: onKeepGoing != null
          ? () {
              Navigator.pop(ctx);
              onKeepGoing();
            }
          : null,
    ),
  );
}

/// Full-screen streak-style completion over the scroll gradient.
class SkulMateScrollCompletionOverlay extends StatefulWidget {
  final List<Color> gradientColors;
  final String title;
  final String body;
  final String doneLabel;
  final VoidCallback onDone;

  const SkulMateScrollCompletionOverlay({
    super.key,
    required this.gradientColors,
    required this.title,
    required this.body,
    required this.doneLabel,
    required this.onDone,
  });

  @override
  State<SkulMateScrollCompletionOverlay> createState() =>
      _SkulMateScrollCompletionOverlayState();
}

class _SkulMateScrollCompletionOverlayState
    extends State<SkulMateScrollCompletionOverlay>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confetti;
  late AnimationController _scaleController;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _scale = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    _scaleController.forward();
    unawaited(Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _confetti.play();
    }));
  }

  @override
  void dispose() {
    _confetti.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.gradientColors,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const SkulMateMascotMediaWidget(
                        state: SkulMateMascotState.celebration,
                        showFrame: false,
                        preferStaticImage: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.body,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.45,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onDone,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: widget.gradientColors.last,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        widget.doneLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: pi / 2,
              maxBlastForce: 22,
              minBlastForce: 10,
              emissionFrequency: 0.05,
              numberOfParticles: 28,
              gravity: 0.14,
              colors: const [
                Colors.white,
                AppTheme.accentGreen,
                AppTheme.accentOrange,
                AppTheme.skyBlue,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
