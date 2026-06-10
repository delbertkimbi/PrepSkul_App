import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/booking/models/upcoming_session_item.dart';

/// Vertical timeline of upcoming sessions (Preply "Up next").
class UpNextSessionsTimeline extends StatelessWidget {
  final List<UpcomingSessionItem> sessions;
  final void Function(UpcomingSessionItem item)? onSessionTap;
  final VoidCallback? onViewAll;

  const UpNextSessionsTimeline({
    super.key,
    required this.sessions,
    this.onSessionTap,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.length <= 1) return const SizedBox.shrink();

    final visible = sessions.skip(1).take(2).toList();
    final remaining = sessions.length - 1 - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Up next',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const Spacer(),
            if (remaining > 0 && onViewAll != null)
              TextButton(
                onPressed: onViewAll,
                child: Text(
                  '$remaining more',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ...visible.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == visible.length - 1;
          return _TimelineRow(
            item: item,
            showLine: !isLast,
            onTap: onSessionTap != null ? () => onSessionTap!(item) : null,
          );
        }),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final UpcomingSessionItem item;
  final bool showLine;
  final VoidCallback? onTap;

  const _TimelineRow({
    required this.item,
    required this.showLine,
    this.onTap,
  });

  String _formatRange(DateTime start) {
    final end = start.add(const Duration(minutes: 50));
    final day = DateFormat('EEE, MMM d').format(start);
    final from = DateFormat('HH:mm').format(start);
    final to = DateFormat('HH:mm').format(end);
    return '$day · $from–$to';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.25),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    if (showLine)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatRange(item.scheduledStart),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.subject} with ${item.tutorName}',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
                    ),
                    if (!showLine) const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
