import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/discovery/utils/schedule_time_utils.dart';

/// Reusable day block for tutor availability (preview + full schedule).
class TutorScheduleDaySection extends StatelessWidget {
  final String day;
  final List<String> times;
  final int? maxSlots;
  final bool compact;
  final bool inSlider;

  const TutorScheduleDaySection({
    super.key,
    required this.day,
    required this.times,
    this.maxSlots,
    this.compact = false,
    this.inSlider = false,
  });

  @override
  Widget build(BuildContext context) {
    final visibleTimes = maxSlots == null
        ? times
        : times.take(maxSlots!).toList();
    final hiddenCount = maxSlots == null
        ? 0
        : (times.length - visibleTimes.length).clamp(0, times.length);

    return Container(
      width: double.infinity,
      height: inSlider ? double.infinity : null,
      margin: inSlider
          ? EdgeInsets.zero
          : EdgeInsets.only(bottom: compact ? 10 : 12),
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        compact ? 12 : 14,
        compact ? 12 : 16,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day,
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              Text(
                '${times.length} ${times.length == 1 ? 'slot' : 'slots'}',
                style: GoogleFonts.poppins(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...visibleTimes.map(_timeChip),
              if (hiddenCount > 0) _moreChip(hiddenCount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeChip(String time) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        time,
        style: GoogleFonts.poppins(
          fontSize: compact ? 12 : 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _moreChip(int count) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Text(
        '+$count more',
        style: GoogleFonts.poppins(
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textMedium,
        ),
      ),
    );
  }
}

/// Build ordered day sections from a schedule map.
List<Widget> buildTutorScheduleDaySections(
  Map<String, dynamic> schedule, {
  int? maxDays,
  int? maxSlotsPerDay,
  bool compact = false,
}) {
  final days = ScheduleTimeUtils.orderedDays(schedule);
  final previewDays = maxDays == null ? days : days.take(maxDays).toList();

  return previewDays.map((day) {
    final raw = schedule[day];
    final times = ScheduleTimeUtils.sorted(raw is List ? raw : [raw]);
    return TutorScheduleDaySection(
      day: day,
      times: times,
      maxSlots: maxSlotsPerDay,
      compact: compact,
    );
  }).toList();
}
