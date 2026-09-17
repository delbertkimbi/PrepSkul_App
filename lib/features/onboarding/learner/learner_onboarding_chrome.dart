import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/alive_mate.dart';

TextStyle onboardFont({
  double size = 16,
  FontWeight weight = FontWeight.w800,
  Color color = AppTheme.primaryColor,
  double height = 1.25,
}) {
  return GoogleFonts.nunito(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

TextStyle onboardDisplay({
  double size = 22,
  FontWeight weight = FontWeight.w600,
  Color color = AppTheme.primaryColor,
}) {
  return GoogleFonts.fredoka(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.14,
    letterSpacing: -0.2,
  );
}

class OnboardPalette {
  static const cream = Color(0xFFFAF8F3);

  static BoxDecoration get page => const BoxDecoration(
        color: cream,
      );

  static BoxDecoration card({required bool selected}) {
    return BoxDecoration(
      color: selected ? AppTheme.skyBlueLight : Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: selected ? AppTheme.skyBlue : AppTheme.primaryColor.withValues(alpha: 0.16),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: selected ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.18),
          blurRadius: 0,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

Widget prepMate({required Mood mood, double size = 96}) {
  return AliveMate(mood: mood, size: size);
}

class PrepSkulWordmark extends StatelessWidget {
  const PrepSkulWordmark({super.key, this.onDark = false});
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      'PrepSkul',
      textAlign: TextAlign.center,
      style: onboardDisplay(
        size: 30,
        color: onDark ? Colors.white : AppTheme.primaryColor,
      ),
    );
  }
}

class OnboardTopBar extends StatelessWidget {
  const OnboardTopBar({
    super.key,
    required this.progress,
    required this.onBack,
  });
  final double progress;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left_rounded, size: 32),
          color: AppTheme.primaryColor,
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 16,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      const ColoredBox(
                        color: Color(0x1F1B2C4F),
                        child: SizedBox.expand(),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                        decoration: const BoxDecoration(
                          color: AppTheme.skyBlue,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

class OnboardSpeech extends StatefulWidget {
  const OnboardSpeech({
    super.key,
    required this.title,
    this.note,
    this.tail = true,
    this.onTyped,
  });
  final String title;
  final String? note;
  final bool tail;
  final VoidCallback? onTyped;

  @override
  State<OnboardSpeech> createState() => _OnboardSpeechState();
}

class _OnboardSpeechState extends State<OnboardSpeech> {
  int _shown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant OnboardSpeech oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    _shown = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduce = MediaQuery.disableAnimationsOf(context);
      if (reduce || widget.title.isEmpty) {
        setState(() => _shown = widget.title.length);
        widget.onTyped?.call();
        return;
      }
      _timer = Timer.periodic(const Duration(milliseconds: 36), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_shown >= widget.title.length) {
          timer.cancel();
          widget.onTyped?.call();
          return;
        }
        setState(() => _shown++);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _shown >= widget.title.length;
    final visible = widget.title.substring(0, _shown.clamp(0, widget.title.length));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.primaryColor, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x381E3A8A), offset: Offset(0, 6), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: visible, style: onboardDisplay(size: 22)),
                if (!done)
                  TextSpan(
                    text: '|',
                    style: onboardDisplay(size: 22, color: AppTheme.primaryColor),
                  ),
              ],
            ),
          ),
          if (done && widget.note != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.note!,
              style: onboardFont(
                size: 13,
                weight: FontWeight.w700,
                color: AppTheme.textMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OnboardAsk extends StatefulWidget {
  const OnboardAsk({
    super.key,
    required this.title,
    required this.mood,
    required this.child,
    this.note,
  });
  final String title;
  final String? note;
  final Mood mood;
  final Widget child;

  @override
  State<OnboardAsk> createState() => _OnboardAskState();
}

class _OnboardAskState extends State<OnboardAsk> {
  bool _typed = false;

  @override
  void didUpdateWidget(covariant OnboardAsk oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      _typed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mood = _typed ? widget.mood : Mood.talk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            prepMate(mood: mood, size: 108),
            const SizedBox(width: 10),
            Expanded(
              child: OnboardSpeech(
                title: widget.title,
                note: widget.note,
                onTyped: () {
                  if (mounted && !_typed) setState(() => _typed = true);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedOpacity(
          opacity: _typed ? 1 : 0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: _typed ? Offset.zero : const Offset(0, 0.06),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            child: IgnorePointer(ignoring: !_typed, child: widget.child),
          ),
        ),
      ],
    );
  }
}

class OnboardChoice extends StatelessWidget {
  const OnboardChoice({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.glyph,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? glyph;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 0.99 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: OnboardPalette.card(selected: selected),
            child: Row(
              children: [
                OnboardGlyph(seed: glyph ?? title, selected: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: onboardDisplay(size: 18)),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: onboardFont(
                            size: 12,
                            weight: FontWeight.w800,
                            color: AppTheme.skyBlue,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardPrimaryButton extends StatelessWidget {
  const OnboardPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.primaryColor : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled
              ? const [
                  BoxShadow(color: AppTheme.primaryDark, offset: Offset(0, 7), blurRadius: 0),
                ]
              : const [
                  BoxShadow(color: Color(0xFFA8B3C4), offset: Offset(0, 2), blurRadius: 0),
                ],
        ),
        child: Text(
          label.toUpperCase(),
          style: onboardDisplay(size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class OnboardGlyph extends StatelessWidget {
  const OnboardGlyph({super.key, required this.seed, this.selected = false});
  final String seed;
  final bool selected;

  static const _flags = <String, String>{
    'en': '🇬🇧',
    'gb': '🇬🇧',
    'fr': '🇫🇷',
    'fr_country': '🇫🇷',
    'cm-francophone': '🇫🇷',
    'cm-anglophone': '🇬🇧',
    'cm': '🇨🇲',
    'ng': '🇳🇬',
    'gh': '🇬🇭',
    'ke': '🇰🇪',
    'ci': '🇨🇮',
    'za': '🇿🇦',
    'us': '🇺🇸',
    'global': '🌍',
  };

  static const _art = <String, String>{
    'student': 'assets/onboard/art/tile-backpack.png',
    'parent': 'assets/onboard/art/tile-heart.png',
    'maths': 'assets/onboard/art/tile-maths.png',
    'french': 'assets/onboard/art/tile-pencil.png',
    'english': 'assets/onboard/art/tile-book.png',
    'cs': 'assets/onboard/art/tile-laptop.png',
    'pct': 'assets/onboard/art/tile-flask.png',
    'svt': 'assets/onboard/art/tile-leaf.png',
    'physics': 'assets/onboard/art/tile-flask.png',
    'chemistry': 'assets/onboard/art/tile-flask.png',
    'biology': 'assets/onboard/art/tile-leaf.png',
    'geography': 'assets/onboard/art/tile-globe.png',
    'literature': 'assets/onboard/art/tile-book.png',
    'economics': 'assets/onboard/art/tile-maths.png',
    'histgeo': 'assets/onboard/art/tile-globe.png',
    'philo': 'assets/onboard/art/tile-book.png',
    'bepc': 'assets/onboard/art/tile-medal.png',
    'bac': 'assets/onboard/art/tile-medal.png',
    'gce': 'assets/onboard/art/tile-pencil.png',
    'probatoire': 'assets/onboard/art/tile-medal.png',
    'ng-waec': 'assets/onboard/art/tile-medal.png',
    'gh-wassce': 'assets/onboard/art/tile-medal.png',
    'ke-cbc': 'assets/onboard/art/tile-medal.png',
    'za-nsc': 'assets/onboard/art/tile-medal.png',
    'fr-bac': 'assets/onboard/art/tile-medal.png',
    'gb-gcse': 'assets/onboard/art/tile-medal.png',
    'us-k12': 'assets/onboard/art/tile-medal.png',
    'global-open': 'assets/onboard/art/tile-globe.png',
  };

  static const _paper = <String, Color>{
    'student': Color(0xFFDBEAFE),
    'parent': Color(0xFFFEF9C3),
    'maths': Color(0xFFFEF3C7),
    'french': Color(0xFFFCE7F3),
    'english': Color(0xFFDBEAFE),
    'cs': Color(0xFFE0E7FF),
    'pct': Color(0xFFE0F2FE),
    'svt': Color(0xFFD1FAE5),
    'physics': Color(0xFFE0F2FE),
    'chemistry': Color(0xFFFCE7F3),
    'biology': Color(0xFFD1FAE5),
    'geography': Color(0xFFFEF3C7),
    'literature': Color(0xFFFCE7F3),
    'economics': Color(0xFFD1FAE5),
    'histgeo': Color(0xFFFFEDD5),
    'philo': Color(0xFFF3E8FF),
    'bepc': Color(0xFFFEF9C3),
    'bac': Color(0xFFDBEAFE),
    'gce': Color(0xFFD1FAE5),
    'probatoire': Color(0xFFE0F2FE),
    'ng-waec': Color(0xFFD1FAE5),
    'gh-wassce': Color(0xFFFEF3C7),
    'ke-cbc': Color(0xFFDBEAFE),
    'za-nsc': Color(0xFFE0F2FE),
    'fr-bac': Color(0xFFE0E7FF),
    'gb-gcse': Color(0xFFDBEAFE),
    'us-k12': Color(0xFFFEE2E2),
    'global-open': Color(0xFFF3E8FF),
  };

  @override
  Widget build(BuildContext context) {
    final flag = _flags[seed];
    final art = _art[seed];
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: flag != null ? Colors.white : (_paper[seed] ?? const Color(0xFFE0F2FE)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: selected ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.18),
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: flag != null
          ? Text(flag, style: const TextStyle(fontSize: 26, height: 1))
          : art != null
              ? Padding(
                  padding: const EdgeInsets.all(5),
                  child: Image.asset(
                    art,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                )
              : const Text('✨', style: TextStyle(fontSize: 22)),
    );
  }
}
