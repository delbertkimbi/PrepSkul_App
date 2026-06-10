import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/discovery/utils/schedule_time_utils.dart';
import 'package:prepskul/features/discovery/widgets/tutor_schedule_day_section.dart';

/// Full tutor availability — vertical day sections with readable time chips.
class TutorScheduleScreen extends StatelessWidget {
  final Map<String, dynamic> tutor;
  final Map<String, dynamic>? availability;

  const TutorScheduleScreen({
    super.key,
    required this.tutor,
    this.availability,
  });

  String get _tutorName {
    final profile = tutor['profiles'] as Map<String, dynamic>?;
    return (profile?['full_name'] as String?) ??
        (tutor['full_name'] as String?) ??
        (tutor['name'] as String?) ??
        'Tutor';
  }

  @override
  Widget build(BuildContext context) {
    final schedule =
        availability ?? tutor['combined_availability'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Available Schedule',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        foregroundColor: AppTheme.textDark,
      ),
      backgroundColor: AppTheme.softBackground,
      body: schedule == null || schedule.isEmpty
          ? _buildEmptyState()
          : _buildScheduleList(schedule),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Schedule Not Available',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This tutor has not set their availability yet.',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleList(Map<String, dynamic> schedule) {
    final days = ScheduleTimeUtils.orderedDays(schedule);
    if (days.isEmpty) return _buildEmptyState();

    final totalSlots = days.fold<int>(0, (sum, day) {
      final raw = schedule[day];
      final list = raw is List ? raw : [raw];
      return sum + list.length;
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.softBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tutorName,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Weekly availability · $totalSlots open ${totalSlots == 1 ? 'slot' : 'slots'}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Times shown in your local timezone',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...buildTutorScheduleDaySections(schedule),
      ],
    );
  }
}
