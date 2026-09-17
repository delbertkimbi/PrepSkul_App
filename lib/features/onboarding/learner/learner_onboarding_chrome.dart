import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/features/primar/presentation/mascot.dart';
import 'package:prepskul/features/primar/presentation/primar_theme.dart';

TextStyle onboardFont({
  double size = 16,
  FontWeight weight = FontWeight.w800,
  Color color = PrimarTheme.navy,
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
  FontWeight weight = FontWeight.w700,
  Color color = PrimarTheme.navy,
}) {
  return GoogleFonts.baloo2(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.14,
    letterSpacing: -0.2,
  );
}

class OnboardPalette {
  static const cream = Color(0xFFF6F1E4);

  static BoxDecoration get page => const BoxDecoration(
        color: cream,
      );

  static BoxDecoration card({required bool selected}) {
    return BoxDecoration(
      color: selected ? PrimarTheme.tintTeal : Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: selected ? PrimarTheme.teal : PrimarTheme.navy.withValues(alpha: 0.16),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: selected ? PrimarTheme.teal : PrimarTheme.navy.withValues(alpha: 0.18),
          blurRadius: 0,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

Widget prepMate({required Mood mood, double size = 96}) {
  return Mate(
    mood: mood,
    size: size,
    ink: PrimarTheme.navy,
    body: PrimarTheme.blue,
    belly: PrimarTheme.teal,
    accent: PrimarTheme.yellow,
  );
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
        color: onDark ? Colors.white : PrimarTheme.navy,
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
          color: PrimarTheme.navy,
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
                          gradient: LinearGradient(
                            colors: [PrimarTheme.yellow, PrimarTheme.teal],
                          ),
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

class OnboardSpeech extends StatelessWidget {
  const OnboardSpeech({super.key, required this.title, this.note, this.tail = true});
  final String title;
  final String? note;
  final bool tail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PrimarTheme.navy, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x381E3A8A), offset: Offset(0, 6), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: onboardDisplay(size: 22)),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: onboardFont(
                size: 13,
                weight: FontWeight.w700,
                color: PrimarTheme.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OnboardAsk extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            prepMate(mood: mood, size: 108),
            const SizedBox(width: 10),
            Expanded(child: OnboardSpeech(title: title, note: note)),
          ],
        ),
        const SizedBox(height: 18),
        child,
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
                            color: PrimarTheme.teal,
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
          color: enabled ? PrimarTheme.teal : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled
              ? const [
                  BoxShadow(color: Color(0xFF0E9384), offset: Offset(0, 7), blurRadius: 0),
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

  static const _art = <String, (Color, String)>{
    'en': (Color(0xFFFEF3C7), 'assets/onboard/art/tile-en.png'),
    'fr': (Color(0xFFCCFBF1), 'assets/onboard/art/tile-fr.png'),
    'student': (Color(0xFFDBEAFE), 'assets/onboard/art/tile-backpack.png'),
    'parent': (Color(0xFFFEF9C3), 'assets/onboard/art/tile-heart.png'),
    'cm': (Color(0xFFD1FAE5), 'assets/onboard/art/tile-cm.png'),
    'ng': (Color(0xFFD1FAE5), 'assets/onboard/art/tile-globe.png'),
    'gh': (Color(0xFFFEF3C7), 'assets/onboard/art/tile-globe.png'),
    'ke': (Color(0xFFDBEAFE), 'assets/onboard/art/tile-globe.png'),
    'ci': (Color(0xFFFCE7F3), 'assets/onboard/art/tile-globe.png'),
    'za': (Color(0xFFE0F2FE), 'assets/onboard/art/tile-globe.png'),
    'gb': (Color(0xFFDBEAFE), 'assets/onboard/art/tile-en.png'),
    'us': (Color(0xFFFEE2E2), 'assets/onboard/art/tile-globe.png'),
    'global': (Color(0xFFF3E8FF), 'assets/onboard/art/tile-globe.png'),
    'maths': (Color(0xFFFEF3C7), 'assets/onboard/art/tile-maths.png'),
    'french': (Color(0xFFFCE7F3), 'assets/onboard/art/tile-pencil.png'),
    'english': (Color(0xFFDBEAFE), 'assets/onboard/art/tile-book.png'),
    'cs': (Color(0xFFE0E7FF), 'assets/onboard/art/tile-laptop.png'),
    'pct': (Color(0xFFE0F2FE), 'assets/onboard/art/tile-flask.png'),
    'svt': (Color(0xFFD1FAE5), 'assets/onboard/art/tile-leaf.png'),
    'physics': (Color(0xFFE0F2FE), 'assets/onboard/art/tile-flask.png'),
    'chemistry': (Color(0xFFFCE7F3), 'assets/onboard/art/tile-flask.png'),
    'biology': (Color(0xFFD1FAE5), 'assets/onboard/art/tile-leaf.png'),
    'cm-francophone': (Color(0xFFCCFBF1), 'assets/onboard/art/tile-book.png'),
    'cm-anglophone': (Color(0xFFDBEAFE), 'assets/onboard/art/tile-book.png'),
  };

  @override
  Widget build(BuildContext context) {
    final art = _art[seed] ?? (const Color(0xFFE0F2FE), 'assets/onboard/art/tile-globe.png');
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: art.$1,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: selected ? PrimarTheme.navy : PrimarTheme.navy.withValues(alpha: 0.18),
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Transform.scale(
        scale: 1.35,
        child: Image.asset(art.$2, fit: BoxFit.cover, filterQuality: FilterQuality.high),
      ),
    );
  }
}
