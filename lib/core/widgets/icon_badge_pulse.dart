import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Rounded-square icon shell + unread count badge with pulse on increment.
class IconBadgePulse extends StatefulWidget {
  final int count;
  final Widget icon;
  final VoidCallback? onTap;

  const IconBadgePulse({
    super.key,
    required this.count,
    required this.icon,
    this.onTap,
  });

  @override
  State<IconBadgePulse> createState() => _IconBadgePulseState();
}

class _IconBadgePulseState extends State<IconBadgePulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _lastCount = widget.count;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(IconBadgePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > _lastCount) {
      _pulseController.forward(from: 0);
    }
    _lastCount = widget.count;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.softCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.softBorder),
          ),
          child: widget.icon,
        ),
        if (widget.count > 0)
          Positioned(
            right: -5,
            top: -5,
            child: ScaleTransition(
              scale: _pulseScale,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Center(
                  child: Text(
                    widget.count > 99 ? '99+' : '${widget.count}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.onTap == null) return child;
    return GestureDetector(onTap: widget.onTap, child: child);
  }
}
