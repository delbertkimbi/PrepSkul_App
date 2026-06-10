import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Circular countdown ring showing time until session start.
///
/// When [bookingWindowStart] and [bookingWindowEnd] are set, the ring fill
/// reflects progress through the overall booking period (first booked day →
/// last session day). Otherwise falls back to a 7-day window before start.
class SessionStartCountdownRing extends StatelessWidget {
  final DateTime? sessionStart;
  final DateTime? bookingWindowStart;
  final DateTime? bookingWindowEnd;
  final double size;

  const SessionStartCountdownRing({
    super.key,
    required this.sessionStart,
    this.bookingWindowStart,
    this.bookingWindowEnd,
    this.size = 88,
  });

  static ({DateTime? windowStart, DateTime? windowEnd}) bookingWindowFromRecurring(
    Map<String, dynamic>? recurring,
    DateTime sessionStart,
  ) {
    DateTime? parseDay(dynamic value) {
      if (value == null) return null;
      try {
        final raw = value.toString().split('T').first;
        final parts = raw.split('-');
        if (parts.length != 3) return null;
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      } catch (_) {
        return null;
      }
    }

    final windowStart = parseDay(recurring?['start_date']);
    final lastCompleted = parseDay(recurring?['last_session_date']);
    final sessionDay = DateTime(
      sessionStart.year,
      sessionStart.month,
      sessionStart.day,
    );

    var windowEnd = lastCompleted;
    if (windowEnd == null || windowEnd.isBefore(sessionDay)) {
      windowEnd = sessionDay;
    }
    if (windowStart != null && !windowEnd.isAfter(windowStart)) {
      windowEnd = sessionDay.isAfter(windowStart) ? sessionDay : windowStart;
    }

    return (windowStart: windowStart, windowEnd: windowEnd);
  }

  double _progressPercent(DateTime now, Duration remaining) {
    final bookingStart = bookingWindowStart;
    final bookingEnd = bookingWindowEnd;
    if (bookingStart != null &&
        bookingEnd != null &&
        bookingEnd.isAfter(bookingStart)) {
      final totalMinutes = bookingEnd.difference(bookingStart).inMinutes;
      if (totalMinutes > 0) {
        final elapsed = now.difference(bookingStart).inMinutes.clamp(0, totalMinutes);
        return (elapsed / totalMinutes).clamp(0.05, 0.98);
      }
    }

    const window = Duration(days: 7);
    final windowRemaining = remaining > window ? window : remaining;
    return 1 - (windowRemaining.inMinutes / window.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    if (sessionStart == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final remaining = sessionStart!.difference(now);
    if (remaining.isNegative) {
      return _ring(
        percent: 1,
        center: Text(
          'Now',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }

    final percent = _progressPercent(now, remaining);

    return _ring(
      percent: percent.clamp(0.05, 0.98),
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _label(remaining),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            'to start',
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring({required double percent, required Widget center}) {
    return CircularPercentIndicator(
      radius: size / 2,
      lineWidth: 6,
      percent: percent,
      animation: true,
      animateFromLastPercent: true,
      circularStrokeCap: CircularStrokeCap.round,
      progressColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
      center: center,
    );
  }

  String _label(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'Soon';
  }
}
