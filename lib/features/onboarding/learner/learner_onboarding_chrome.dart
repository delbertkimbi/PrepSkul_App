import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/alive_mate.dart';

export 'package:prepskul/core/widgets/alive_mate.dart' show AliveMate, Mood;

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

  static BoxDecoration get page => const BoxDecoration(color: cream);

  static BoxDecoration card({required bool selected}) {
    return BoxDecoration(
      color: selected ? AppTheme.skyBlueLight : Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: selected
            ? AppTheme.skyBlue
            : AppTheme.primaryColor.withValues(alpha: 0.16),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: selected
              ? AppTheme.primaryColor
              : AppTheme.primaryColor.withValues(alpha: 0.18),
          blurRadius: 0,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration get paperCard => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppTheme.primaryColor, width: 2),
    boxShadow: const [
      BoxShadow(color: Color(0x381E3A8A), offset: Offset(0, 5), blurRadius: 0),
    ],
  );

  static BoxDecoration get paperField => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: AppTheme.primaryColor.withValues(alpha: 0.22),
      width: 2,
    ),
  );
}

InputDecoration paperFieldDecoration({
  String? hintText,
  Widget? suffixIcon,
  String? labelText,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(
      color: AppTheme.primaryColor.withValues(alpha: 0.22),
      width: 2,
    ),
  );
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    hintStyle: onboardFont(
      size: 14,
      weight: FontWeight.w600,
      color: AppTheme.textLight,
    ),
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffixIcon,
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  );
}

AppBar paperAppBar({
  String? title,
  Widget? titleWidget,
  List<Widget>? actions,
  Widget? leading,
  PreferredSizeWidget? bottom,
  bool automaticallyImplyLeading = true,
  bool centerTitle = false,
}) {
  return AppBar(
    automaticallyImplyLeading: automaticallyImplyLeading,
    backgroundColor: OnboardPalette.cream,
    surfaceTintColor: OnboardPalette.cream,
    elevation: 0,
    leading: leading,
    centerTitle: centerTitle,
    title: titleWidget ?? Text(title ?? '', style: onboardDisplay(size: 22)),
    actions: actions,
    bottom: bottom,
    iconTheme: const IconThemeData(color: AppTheme.primaryColor),
  );
}

class AuthPaperHeader extends StatelessWidget {
  const AuthPaperHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.mood = Mood.idle,
    this.extra,
  });

  final String title;
  final String? subtitle;
  final Mood mood;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Column(
        children: [
          prepMate(mood: mood, size: 88),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: onboardDisplay(size: 28),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: onboardFont(
                size: 15,
                weight: FontWeight.w700,
                color: AppTheme.textMedium,
                height: 1.35,
              ),
            ),
          ],
          if (extra != null) ...[const SizedBox(height: 6), extra!],
        ],
      ),
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
    this.onListen,
    this.listenLabel = 'Listen',
    this.voiceEnabled = true,
  });
  final String title;
  final String? note;
  final bool tail;
  final VoidCallback? onTyped;
  final Future<void> Function()? onListen;
  final String listenLabel;
  final bool voiceEnabled;

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
    final visible = widget.title.substring(
      0,
      _shown.clamp(0, widget.title.length),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.primaryColor, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x381E3A8A),
            offset: Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: visible, style: onboardDisplay(size: 22)),
                      if (!done)
                        TextSpan(
                          text: '|',
                          style: onboardDisplay(
                            size: 22,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.onListen != null)
                IconButton(
                  tooltip: widget.listenLabel,
                  onPressed: widget.onListen,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  color: AppTheme.primaryColor,
                  icon: Icon(
                    widget.voiceEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_outlined,
                    size: 23,
                  ),
                ),
            ],
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
    this.speaking,
    this.note,
    this.onListen,
    this.listenLabel = 'Listen',
    this.voiceEnabled = true,
  });
  final String title;
  final String? note;
  final Mood mood;
  final ValueNotifier<bool>? speaking;
  final Widget child;
  final Future<void> Function()? onListen;
  final String listenLabel;
  final bool voiceEnabled;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.speaking != null)
              ValueListenableBuilder<bool>(
                valueListenable: widget.speaking!,
                builder: (context, speaking, _) => prepMate(
                  mood: speaking && widget.voiceEnabled ? Mood.talk : widget.mood,
                  size: 108,
                ),
              )
            else
              prepMate(mood: widget.mood, size: 108),
            const SizedBox(width: 10),
            Expanded(
              child: OnboardSpeech(
                title: widget.title,
                note: widget.note,
                onListen: widget.onListen,
                listenLabel: widget.listenLabel,
                voiceEnabled: widget.voiceEnabled,
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
    this.busy = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !busy;
    return GestureDetector(
      onTap: active ? onTap : null,
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
                  BoxShadow(
                    color: AppTheme.primaryDark,
                    offset: Offset(0, 7),
                    blurRadius: 0,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0xFFA8B3C4),
                    offset: Offset(0, 2),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label.toUpperCase(),
                style: onboardDisplay(size: 20, color: Colors.white),
              ),
      ),
    );
  }
}

class OnboardPaperButton extends StatelessWidget {
  const OnboardPaperButton({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
  });
  final String label;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primaryColor, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x381E3A8A),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: onboardFont(size: 16, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Human photo on paper, Mate overlapping. Both, not one over the other.
class OnboardPeopleMateStage extends StatelessWidget {
  const OnboardPeopleMateStage({
    super.key,
    required this.photoAsset,
    required this.mood,
    this.flipMate = true,
  });

  final String photoAsset;
  final Mood mood;
  final bool flipMate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 300,
        height: 248,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Align(
              alignment: const Alignment(-0.55, -0.1),
              child: Container(
                width: 176,
                height: 176,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTheme.primaryColor, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x381E3A8A),
                      offset: Offset(0, 8),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Image.asset(
                    photoAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return ColoredBox(
                        color: AppTheme.skyBlueLight,
                        child: Center(child: prepMate(mood: mood, size: 96)),
                      );
                    },
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.72, 0.55),
              child: AliveMate(mood: mood, size: 132, flip: flipMate),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardGlyph extends StatelessWidget {
  const OnboardGlyph({
    super.key,
    required this.seed,
    this.selected = false,
    this.size = 48,
  });
  final String seed;
  final bool selected;
  final double size;

  static const _flagCodes = <String, String>{
    'en': 'gb',
    'fr': 'fr',
    'gb_country': 'gb',
    'fr_country': 'fr',
    'cm_country': 'cm',
    'ng_country': 'ng',
    'gh_country': 'gh',
    'ke_country': 'ke',
    'ci_country': 'ci',
    'za_country': 'za',
    'us_country': 'us',
  };

  static const _languageLabels = <String, String>{
    'en': 'EN',
    'fr': 'FR',
    'cm-francophone': 'FR',
    'cm-anglophone': 'EN',
  };

  static const _art = <String, String>{
    'student': 'assets/onboard/art/tile-backpack.webp',
    'parent': 'assets/onboard/art/tile-heart.webp',
    'maths': 'assets/onboard/art/tile-maths.webp',
    'french': 'assets/onboard/art/tile-pencil.webp',
    'english': 'assets/onboard/art/tile-book.webp',
    'cs': 'assets/onboard/art/tile-laptop.webp',
    'pct': 'assets/onboard/art/tile-flask.webp',
    'svt': 'assets/onboard/art/tile-leaf.webp',
    'physics': 'assets/onboard/art/tile-flask.webp',
    'chemistry': 'assets/onboard/art/tile-flask.webp',
    'biology': 'assets/onboard/art/tile-leaf.webp',
    'geography': 'assets/onboard/art/tile-globe.webp',
    'literature': 'assets/onboard/art/tile-book.webp',
    'economics': 'assets/onboard/art/tile-maths.webp',
    'histgeo': 'assets/onboard/art/tile-globe.webp',
    'philo': 'assets/onboard/art/tile-book.webp',
    'bepc': 'assets/onboard/art/tile-medal.webp',
    'bac': 'assets/onboard/art/tile-medal.webp',
    'gce': 'assets/onboard/art/tile-pencil.webp',
    'probatoire': 'assets/onboard/art/tile-medal.webp',
    'ng-waec': 'assets/onboard/art/tile-medal.webp',
    'gh-wassce': 'assets/onboard/art/tile-medal.webp',
    'ke-cbc': 'assets/onboard/art/tile-medal.webp',
    'za-nsc': 'assets/onboard/art/tile-medal.webp',
    'fr-bac': 'assets/onboard/art/tile-medal.webp',
    'gb-gcse': 'assets/onboard/art/tile-medal.webp',
    'us-k12': 'assets/onboard/art/tile-medal.webp',
    'global-open': 'assets/onboard/art/tile-globe.webp',
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
    final flagCode = _flagCodes[seed];
    final language = _languageLabels[seed];
    final art = _art[seed];
    final borderWidth = size < 32 ? 1.4 : 2.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: flagCode != null
            ? Colors.white
            : (_paper[seed] ?? const Color(0xFFE0F2FE)),
        borderRadius: BorderRadius.circular(size * 0.29),
        border: Border.all(color: AppTheme.primaryColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withValues(alpha: 0.18),
            offset: Offset(0, size * 0.0625),
            blurRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: flagCode != null
          ? Padding(
              padding: EdgeInsets.all(size * 0.1),
              child: CustomPaint(
                painter: _OnboardFlagPainter(flagCode),
                child: SizedBox(width: size * 0.8, height: size * 0.53),
              ),
            )
          : language != null
          ? Text(
              language,
              style: onboardDisplay(
                size: size * 0.34,
                color: AppTheme.primaryColor,
              ),
            )
          : art != null
          ? Padding(
              padding: EdgeInsets.all(size * 0.1),
              child: Image.asset(
                art,
                fit: BoxFit.contain,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                cacheHeight: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                filterQuality: FilterQuality.low,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.school_rounded,
                  color: AppTheme.primaryColor,
                  size: size * 0.58,
                ),
              ),
            )
          : Icon(
              seed == 'global_country'
                  ? Icons.public_rounded
                  : Icons.auto_awesome_rounded,
              color: AppTheme.primaryColor,
              size: size * 0.54,
            ),
    );
  }
}

/// Tiny vector flags avoid platform-dependent emoji glyphs and load instantly.
class _OnboardFlagPainter extends CustomPainter {
  const _OnboardFlagPainter(this.code);
  final String code;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()..style = PaintingStyle.fill;
    void rect(Color color, double x, double y, double width, double height) {
      p.color = color;
      canvas.drawRect(Rect.fromLTWH(x, y, width, height), p);
    }

    void star(Color color, Offset center, double radius) {
      final path = Path();
      for (var i = 0; i < 10; i++) {
        final angle = -pi / 2 + i * pi / 5;
        final r = i.isEven ? radius : radius * 0.42;
        final point = Offset(
          center.dx + cos(angle) * r,
          center.dy + sin(angle) * r,
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      p.color = color;
      canvas.drawPath(path, p);
    }

    const navy = Color(0xFF17233F);
    const red = Color(0xFFCE1126);
    const green = Color(0xFF078A4B);
    const yellow = Color(0xFFFFD21E);
    const blue = Color(0xFF123B9A);
    switch (code) {
      case 'cm':
        rect(green, 0, 0, w / 3, h);
        rect(red, w / 3, 0, w / 3, h);
        rect(yellow, 2 * w / 3, 0, w / 3, h);
        star(yellow, Offset(w / 2, h / 2), h * 0.24);
      case 'ng':
        rect(green, 0, 0, w / 3, h);
        rect(Colors.white, w / 3, 0, w / 3, h);
        rect(green, 2 * w / 3, 0, w / 3, h);
      case 'ci':
        rect(const Color(0xFFF77F00), 0, 0, w / 3, h);
        rect(Colors.white, w / 3, 0, w / 3, h);
        rect(green, 2 * w / 3, 0, w / 3, h);
      case 'fr':
        rect(blue, 0, 0, w / 3, h);
        rect(Colors.white, w / 3, 0, w / 3, h);
        rect(red, 2 * w / 3, 0, w / 3, h);
      case 'gh':
        rect(red, 0, 0, w, h / 3);
        rect(yellow, 0, h / 3, w, h / 3);
        rect(green, 0, 2 * h / 3, w, h / 3);
        star(navy, Offset(w / 2, h / 2), h * 0.22);
      case 'ke':
        rect(Colors.black, 0, 0, w, h * 0.29);
        rect(Colors.white, 0, h * 0.29, w, h * 0.08);
        rect(red, 0, h * 0.37, w, h * 0.28);
        rect(Colors.white, 0, h * 0.65, w, h * 0.08);
        rect(green, 0, h * 0.73, w, h * 0.27);
        p.color = Colors.black;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w / 2, h / 2),
            width: w * 0.24,
            height: h * 0.55,
          ),
          p,
        );
        p.color = red;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w / 2, h / 2),
            width: w * 0.12,
            height: h * 0.43,
          ),
          p,
        );
      case 'za':
        rect(const Color(0xFFDE3831), 0, 0, w, h / 2);
        rect(const Color(0xFF002395), 0, h / 2, w, h / 2);
        p.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, h * .38, w, h * .24), p);
        p.color = const Color(0xFF007A4D);
        final y = Path()
          ..moveTo(0, h * .3)
          ..lineTo(w * .58, h * .3)
          ..lineTo(w, h * .5)
          ..lineTo(w * .58, h * .7)
          ..lineTo(0, h * .7)
          ..lineTo(w * .38, h * .5)
          ..close();
        canvas.drawPath(y, p);
        p.color = const Color(0xFFFFB612);
        final gold = Path()
          ..moveTo(0, h * .18)
          ..lineTo(w * .53, h * .18)
          ..lineTo(w, h * .5)
          ..lineTo(w * .53, h * .82)
          ..lineTo(0, h * .82)
          ..lineTo(w * .39, h * .5)
          ..close();
        canvas.drawPath(gold, p);
        p.color = Colors.black;
        final black = Path()
          ..moveTo(0, h * .27)
          ..lineTo(w * .45, h * .27)
          ..lineTo(w * .86, h * .5)
          ..lineTo(w * .45, h * .73)
          ..lineTo(0, h * .73)
          ..lineTo(w * .34, h * .5)
          ..close();
        canvas.drawPath(black, p);
      case 'gb':
        rect(blue, 0, 0, w, h);
        p.color = Colors.white;
        p.strokeWidth = h * 0.26;
        canvas.drawLine(Offset(0, 0), Offset(w, h), p);
        canvas.drawLine(Offset(w, 0), Offset(0, h), p);
        p.color = red;
        p.strokeWidth = h * 0.1;
        canvas.drawLine(Offset(0, 0), Offset(w, h), p);
        canvas.drawLine(Offset(w, 0), Offset(0, h), p);
        rect(Colors.white, w * .42, 0, w * .16, h);
        rect(Colors.white, 0, h * .38, w, h * .24);
        rect(red, w * .46, 0, w * .08, h);
        rect(red, 0, h * .44, w, h * .12);
      case 'us':
        for (var i = 0; i < 13; i++) {
          rect(i.isEven ? red : Colors.white, 0, h * i / 13, w, h / 13 + 0.5);
        }
        rect(blue, 0, 0, w * .48, h * .56);
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 4; col++) {
            p.color = Colors.white;
            canvas.drawCircle(
              Offset(w * (.08 + col * .09), h * (.1 + row * .16)),
              h * .025,
              p,
            );
          }
        }
    }
  }

  @override
  bool shouldRepaint(covariant _OnboardFlagPainter oldDelegate) =>
      oldDelegate.code != code;
}
