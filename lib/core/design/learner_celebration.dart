import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:prepskul/core/widgets/alive_mate.dart';
import 'learner_design.dart';

/// The original animated Mate, surrounded by a short celebratory star burst.
class LearnerCelebration extends StatefulWidget {
  const LearnerCelebration({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<LearnerCelebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<LearnerCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  final audio = AudioPlayer();
  @override
  void initState() {
    super.initState();
    motion.forward();
    motion.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
      try {
        await audio.setVolume(.22);
        await audio.play(AssetSource('audio/music/mate_twinkle.wav'));
      } catch (_) {
        /* Browser autoplay can be blocked. */
      }
    });
  }

  @override
  void dispose() {
    motion.dispose();
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Welcome back',
    button: true,
    child: GestureDetector(
      onTap: widget.onDone,
      child: ColoredBox(
        color: LearnerDesign.canvas,
        child: Center(
          child: AnimatedBuilder(
            animation: motion,
            builder: (context, _) {
              final t = MediaQuery.disableAnimationsOf(context)
                  ? 1.0
                  : Curves.easeOutCubic.transform(motion.value);
              return SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: .8 + .2 * t,
                      child: const AliveMate(mood: Mood.cheer, size: 180),
                    ),
                    for (var i = 0; i < 8; i++)
                      Transform.translate(
                        offset: Offset(
                          math.cos(i * math.pi / 4) * (35 + 75 * t),
                          math.sin(i * math.pi / 4) * (35 + 75 * t),
                        ),
                        child: Transform.rotate(
                          angle: t * (i.isEven ? .4 : -.4),
                          child: Icon(
                            Icons.star_rounded,
                            size: i.isEven ? 28 : 18,
                            color: i.isEven
                                ? const Color(0xFFFFCB35)
                                : const Color(0xFF8BD2F4),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
