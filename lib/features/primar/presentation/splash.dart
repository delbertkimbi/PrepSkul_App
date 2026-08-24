import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../services/primar_voice.dart';
import 'mascot.dart';
import 'paper_decor.dart';
import 'primar_theme.dart';

/// The welcome.
///
/// Mate lands, the paper drops in behind him, and the wordmark arrives. It runs
/// about two and a half seconds and then gets out of the way — a splash a child
/// sees every single day has to be a greeting, not a toll gate.
///
/// Every element here is drawn and animated on device. Nothing waits on a
/// network, so the app opens the same way during a shutdown as it does on
/// wifi.
class PrimarSplash extends StatefulWidget {
  const PrimarSplash({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<PrimarSplash> createState() => _PrimarSplashState();
}

class _PrimarSplashState extends State<PrimarSplash> with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final ConfettiController _confetti;

  Mood _mood = Mood.idle;
  Timer? _leave;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _confetti = ConfettiController(duration: const Duration(milliseconds: 900));

    // Mate waits a beat before jumping. The pause is what makes the jump read
    // as a decision rather than a page-load artefact.
    Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(() => _mood = Mood.cheer);
      _confetti.play();
      PrimarVoice.instance.chime(Sfx.finish);
    });

    _leave = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _leave?.cancel();
    _intro.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimarTheme.paper,
      body: PaperGround(
        child: GestureDetector(
          // A child who has seen it a hundred times can skip it.
          onTap: () {
            _leave?.cancel();
            widget.onDone();
          },
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: AnimatedBuilder(
              animation: _intro,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_intro.value);
                final wordmark = ((_intro.value - 0.45) / 0.55).clamp(0.0, 1.0);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.45),
                      child: ConfettiWidget(
                        confettiController: _confetti,
                        blastDirectionality: BlastDirectionality.explosive,
                        emissionFrequency: 0.05,
                        numberOfParticles: 12,
                        maxBlastForce: 13,
                        minBlastForce: 6,
                        gravity: 0.3,
                        colors: const [
                          PrimarTheme.blue,
                          PrimarTheme.yellow,
                          PrimarTheme.teal,
                          PrimarTheme.purple,
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Two doodles that swing out as Mate lands.
                        Transform.translate(
                          offset: Offset(0, -10 * (1 - t)),
                          child: Opacity(
                            opacity: t,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Doodle(
                                  kind: DoodleKind.sparkle,
                                  size: 20 + 8 * t,
                                  color: PrimarTheme.yellow,
                                  angle: -0.4 * (1 - t),
                                ),
                                const SizedBox(width: 88),
                                Doodle(
                                  kind: DoodleKind.star,
                                  size: 20 + 8 * t,
                                  color: PrimarTheme.teal,
                                  angle: 0.4 * (1 - t),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Mate(mood: _mood, size: 150),
                        const SizedBox(height: 10),
                        // A strip of tape, dropping in slightly late so the
                        // wordmark reads as being stuck onto the page.
                        Transform.translate(
                          offset: Offset(0, -26 * (1 - wordmark)),
                          child: Opacity(
                            opacity: wordmark,
                            child: const TapeStrip(width: 96, tone: TapeTone.kraft),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.86 + 0.14 * wordmark,
                          child: Opacity(
                            opacity: wordmark,
                            child: const ColorWordmark(
                              words: [
                                ('Skul', PrimarTheme.navy),
                                ('Mate', PrimarTheme.blue),
                              ],
                              size: 36,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
