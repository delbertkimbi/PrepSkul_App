import 'package:flutter/material.dart';
import 'package:prepskul/core/theme/app_theme.dart';

import 'skulmate_mascot_media_widget.dart';

/// Hero mascot with gentle float animation and a soft circular ground shadow.
class SkulMateHeroMascot extends StatefulWidget {
  final SkulMateMascotState state;

  const SkulMateHeroMascot({
    super.key,
    this.state = SkulMateMascotState.encouraging,
  });

  @override
  State<SkulMateHeroMascot> createState() => _SkulMateHeroMascotState();
}

class _SkulMateHeroMascotState extends State<SkulMateHeroMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: 0, end: -7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 144,
      child: AnimatedBuilder(
        animation: _float,
        builder: (context, child) {
          final lift = -_float.value;
          final shadowScale = 1 - (lift / 28);

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 6,
                child: Transform.scale(
                  scale: shadowScale.clamp(0.72, 1.0),
                  child: Container(
                    width: 52,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: AppTheme.textDark.withValues(alpha: 0.1),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.textDark.withValues(alpha: 0.14),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, _float.value),
                child: child,
              ),
            ],
          );
        },
        child: SizedBox(
          width: 132,
          height: 132,
          child: SkulMateMascotMediaWidget(
            state: widget.state,
            showFrame: false,
            preferStaticImage: true,
          ),
        ),
      ),
    );
  }
}
