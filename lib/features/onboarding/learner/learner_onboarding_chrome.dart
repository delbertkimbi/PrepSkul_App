import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/primar/presentation/mascot.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_mascot_media_widget.dart';

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

class OnboardPalette {
  static const cream = Color(0xFFFFF8EC);

  static BoxDecoration get page => const BoxDecoration(color: cream);

  static BoxDecoration card({required bool selected}) {
    return BoxDecoration(
      color: selected ? AppTheme.skyBlueLight : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: selected ? AppTheme.skyBlue : const Color(0x241B2C4F),
        width: 3,
      ),
      boxShadow: [
        BoxShadow(
          color: selected
              ? AppTheme.softYellow.withValues(alpha: 0.55)
              : AppTheme.primaryColor.withValues(alpha: 0.08),
          offset: const Offset(3, 4),
        ),
      ],
    );
  }
}

Widget prepMate({required Mood mood, double size = 96, bool round = false}) {
  final state = switch (mood) {
    Mood.thinking => SkulMateMascotState.thinking,
    Mood.cheer => SkulMateMascotState.celebration,
    Mood.encourage => SkulMateMascotState.encouraging,
    Mood.idle || Mood.happy => SkulMateMascotState.encouraging,
  };
  return ClipRRect(
    borderRadius: BorderRadius.circular(round ? 999 : 32),
    child: SkulMateMascotMediaWidget(
      state: state,
      width: size,
      height: round ? size : size * 0.92,
      showFrame: false,
      loop: true,
      autoplay: true,
      preferStaticImage: false,
    ),
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
      style: onboardFont(
        size: 26,
        weight: FontWeight.w900,
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
                          gradient: LinearGradient(
                            colors: [AppTheme.softYellow, AppTheme.skyBlue],
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
        border: Border.all(color: AppTheme.primaryColor, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x1F1B2C4F), offset: Offset(4, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: onboardFont(size: 18, weight: FontWeight.w800)),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
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
            prepMate(mood: mood, size: 92, round: true),
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
                      Text(title, style: onboardFont(size: 16)),
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
          color: enabled ? AppTheme.skyBlue : AppTheme.neutral400,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? const [
                  BoxShadow(color: Color(0xFF0369A1), offset: Offset(0, 6)),
                ]
              : null,
        ),
        child: Text(
          label.toUpperCase(),
          style: onboardFont(size: 16, weight: FontWeight.w900, color: Colors.white),
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
    'en': (Color(0xFFDBEAFE), '🇬🇧'),
    'fr': (Color(0xFFFCE7F3), '🇫🇷'),
    'student': (Color(0xFFE0F2FE), '🎒'),
    'parent': (Color(0xFFFEF9C3), '💛'),
    'cm': (Color(0xFFD1FAE5), '🇨🇲'),
    'ng': (Color(0xFFD1FAE5), '🇳🇬'),
    'gh': (Color(0xFFFEF3C7), '🇬🇭'),
    'ke': (Color(0xFFDBEAFE), '🇰🇪'),
    'ci': (Color(0xFFFCE7F3), '🇨🇮'),
    'za': (Color(0xFFE0F2FE), '🇿🇦'),
    'gb': (Color(0xFFDBEAFE), '🇬🇧'),
    'us': (Color(0xFFFEE2E2), '🇺🇸'),
    'global': (Color(0xFFF3E8FF), '🌍'),
    'maths': (Color(0xFFFEF3C7), '➗'),
    'french': (Color(0xFFFCE7F3), '📝'),
    'english': (Color(0xFFDBEAFE), '📖'),
    'cs': (Color(0xFFE0E7FF), '💻'),
  };

  @override
  Widget build(BuildContext context) {
    final art = _art[seed] ?? (AppTheme.skyBlueLight, '✨');
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: art.$1,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(art.$2, style: const TextStyle(fontSize: 22)),
    );
  }
}
