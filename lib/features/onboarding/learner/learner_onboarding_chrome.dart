import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

class OnboardPalette {
  static const cream = Color(0xFFF4F7FB);
  static const sheet = Color(0xFFFEFEFE);
  static BoxDecoration page = const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFE8F6FE),
        Color(0xFFF4F7FB),
        Color(0xFFFEF9C3),
      ],
      stops: [0, 0.45, 1],
    ),
  );

  static BoxDecoration neumorph({required bool selected, Color? fill}) {
    return BoxDecoration(
      color: selected
          ? AppTheme.skyBlueLight
          : (fill ?? sheet),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: selected ? AppTheme.skyBlue : Colors.white,
        width: selected ? 2 : 1.4,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.95),
          offset: const Offset(-5, -5),
          blurRadius: 10,
        ),
        BoxShadow(
          color: AppTheme.primaryColor.withValues(alpha: selected ? 0.16 : 0.10),
          offset: const Offset(6, 8),
          blurRadius: selected ? 18 : 14,
        ),
      ],
    );
  }
}

class OnboardRail extends StatelessWidget {
  const OnboardRail({super.key, required this.count, required this.at, required this.label});
  final int count;
  final int at;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == count - 1 ? 0 : 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    height: i == at ? 8 : 6,
                    decoration: BoxDecoration(
                      color: i < at
                          ? AppTheme.skyBlue
                          : i == at
                              ? AppTheme.softYellow
                              : AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
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
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: OnboardPalette.neumorph(selected: false),
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
    this.artColor,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final Color? artColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.015 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: OnboardPalette.neumorph(selected: selected),
            child: Row(
              children: [
                leading ??
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: (artColor ?? AppTheme.skyBlue).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        selected ? Icons.check_rounded : Icons.circle_outlined,
                        color: artColor ?? AppTheme.primaryColor,
                      ),
                    ),
                const SizedBox(width: 12),
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
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: AppTheme.skyBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
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
  const OnboardPrimaryButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.28),
              offset: const Offset(0, 10),
              blurRadius: 18,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
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
    final colors = [
      AppTheme.skyBlue,
      AppTheme.softYellow,
      AppTheme.primaryColor,
      AppTheme.accentBlue,
    ];
    final color = colors[seed.hashCode.abs() % colors.length];
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.28 : 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        seed.substring(0, 1).toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: color == AppTheme.softYellow ? AppTheme.primaryColor : color,
        ),
      ),
    );
  }
}
