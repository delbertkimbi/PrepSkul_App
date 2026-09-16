import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/primar/presentation/mascot.dart';
import 'package:prepskul/features/skulmate/widgets/skulmate_surface_styles.dart';

/// PrepSkul marketplace chrome — white, deep-blue header, sky/yellow accents.
class OnboardPalette {
  static const sheet = Color(0xFFFFFFFF);

  static BoxDecoration get page => SkulMateSurfaceStyles.softScreenGradient();

  static BoxDecoration card({required bool selected}) {
    return BoxDecoration(
      color: selected ? AppTheme.skyBlueLight : Colors.white,
      borderRadius: BorderRadius.circular(SkulMateSurfaceStyles.homeCardRadius),
      border: Border.all(
        color: selected
            ? AppTheme.skyBlue.withValues(alpha: 0.7)
            : AppTheme.softBorder.withValues(alpha: 0.9),
      ),
      boxShadow: SkulMateSurfaceStyles.homeCardShadow(compact: true),
    );
  }
}

Widget prepMate({required Mood mood, double size = 96}) {
  return Mate(
    mood: mood,
    size: size,
    ink: AppTheme.primaryColor,
    body: AppTheme.skyBlue,
    belly: AppTheme.skyBlueLight,
    accent: AppTheme.softYellow,
  );
}

class PrepSkulWordmark extends StatelessWidget {
  const PrepSkulWordmark({super.key, this.onDark = false});
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : AppTheme.primaryColor;
    return Text(
      'PrepSkul',
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.3,
      ),
    );
  }
}

class OnboardRail extends StatelessWidget {
  const OnboardRail({
    super.key,
    required this.count,
    required this.at,
    required this.label,
  });
  final int count;
  final int at;
  final String label;

  @override
  Widget build(BuildContext context) {
    final progress = count == 0 ? 0.0 : (at + 1) / count;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 4,
                width: double.infinity,
                child: Stack(
                  children: [
                    const ColoredBox(
                      color: Color(0x1A1B2C4F),
                      child: SizedBox.expand(),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                      height: 4,
                      color: AppTheme.skyBlue,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMedium,
          ),
        ),
      ],
    );
  }
}

class OnboardBubble extends StatelessWidget {
  const OnboardBubble({super.key, required this.title, this.note});
  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: OnboardPalette.card(selected: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(
              note!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.textMedium,
              ),
            ),
          ],
        ],
      ),
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
    this.leading,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.01 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: OnboardPalette.card(selected: selected),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: selected ? 1 : 0,
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.skyBlue,
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
  });
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: Colors.white24,
        child: Ink(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.22),
                offset: const Offset(0, 8),
                blurRadius: 16,
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardGlyph extends StatelessWidget {
  const OnboardGlyph({super.key, required this.seed, this.selected = false});
  final String seed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.skyBlue.withValues(alpha: selected ? 0.28 : 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        seed.substring(0, 1).toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}
