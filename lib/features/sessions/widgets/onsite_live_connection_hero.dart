import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Animated tutor ↔ student connection shown during live onsite sessions.
class OnsiteLiveConnectionHero extends StatefulWidget {
  final String tutorName;
  final String? tutorAvatarUrl;
  final String studentName;
  final String? studentAvatarUrl;
  final String? subject;
  final Duration elapsed;

  const OnsiteLiveConnectionHero({
    super.key,
    required this.tutorName,
    this.tutorAvatarUrl,
    required this.studentName,
    this.studentAvatarUrl,
    this.subject,
    this.elapsed = Duration.zero,
  });

  @override
  State<OnsiteLiveConnectionHero> createState() => _OnsiteLiveConnectionHeroState();
}

class _OnsiteLiveConnectionHeroState extends State<OnsiteLiveConnectionHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return 'Just started';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryDark,
            AppTheme.primaryColor,
            AppTheme.primaryLight.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingDot(animation: _pulse),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (widget.elapsed > Duration.zero)
                Text(
                  _formatElapsed(widget.elapsed),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: const Size(double.infinity, 72),
                    painter: _ConnectionArcPainter(progress: _pulse.value),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _PartyAvatar(
                          name: widget.tutorName,
                          avatarUrl: widget.tutorAvatarUrl,
                          label: 'Tutor',
                          ringColor: AppTheme.skyBlue,
                        ),
                        _PartyAvatar(
                          name: widget.studentName,
                          avatarUrl: widget.studentAvatarUrl,
                          label: 'Student',
                          ringColor: AppTheme.softYellow,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 28,
                    child: Transform.scale(
                      scale: 0.85 + (_pulse.value * 0.15),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: Icon(
                          Icons.link_rounded,
                          color: Colors.white.withValues(alpha: 0.95),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Session in progress',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (widget.subject != null && widget.subject!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.subject!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.78),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  final Animation<double> animation;

  const _PulsingDot({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.accentGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGreen.withValues(alpha: 0.4 + animation.value * 0.3),
                blurRadius: 6 + animation.value * 4,
                spreadRadius: animation.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PartyAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String label;
  final Color ringColor;

  const _PartyAvatar({
    required this.name,
    this.avatarUrl,
    required this.label,
    required this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ringColor.withValues(alpha: 0.85), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: ringColor.withValues(alpha: 0.35),
                blurRadius: 12,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl!)
                : null,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name.split(' ').first,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.65),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ConnectionArcPainter extends CustomPainter {
  final double progress;

  _ConnectionArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width * 0.22, size.height * 0.55);
    final end = Offset(size.width * 0.78, size.height * 0.55);
    final mid = Offset(size.width * 0.5, size.height * 0.1);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);

    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, basePaint);

    final metric = path.computeMetrics().first;
    final len = metric.length;
    final dashEnd = len * (0.35 + progress * 0.5);
    final extract = metric.extractPath(0, dashEnd.clamp(0, len));

    final activePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(extract, activePaint);

    for (var i = 0; i < 3; i++) {
      final t = ((progress + i * 0.33) % 1.0);
      final tan = metric.getTangentForOffset(len * t);
      if (tan != null) {
        canvas.drawCircle(
          tan.position,
          3,
          Paint()..color = AppTheme.accentGreen.withValues(alpha: 0.9),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
