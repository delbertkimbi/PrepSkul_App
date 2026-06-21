import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/discovery/utils/schedule_time_utils.dart';

/// Availability summary card on tutor profile; full slots on schedule screen.
class TutorSchedulePreview extends StatelessWidget {
  final Map<String, dynamic> availability;
  final VoidCallback? onViewAll;

  const TutorSchedulePreview({
    super.key,
    required this.availability,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final days = ScheduleTimeUtils.orderedDays(availability);
    if (days.isEmpty) {
      return Text(
        'Schedule not available',
        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
      );
    }

    final daysSummary = ScheduleTimeUtils.availabilityDaysSummary(availability);
    final periodsSummary =
        ScheduleTimeUtils.availabilityPeriodsSummary(availability);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 18,
                color: AppTheme.textDark,
              ),
              const SizedBox(width: 8),
              Text(
                'Availability',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            daysSummary,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textDark,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            periodsSummary,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textDark,
              height: 1.45,
            ),
          ),
          if (onViewAll != null) ...[
            const SizedBox(height: 14),
            Center(
              child: InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See complete schedule',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
