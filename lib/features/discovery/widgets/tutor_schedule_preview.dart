import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/discovery/utils/schedule_time_utils.dart';
import 'package:prepskul/features/discovery/widgets/tutor_schedule_day_section.dart';

/// Horizontal day-slider preview on tutor profile; full week on [TutorScheduleScreen].
class TutorSchedulePreview extends StatefulWidget {
  final Map<String, dynamic> availability;
  final int maxSlotsPerDay;
  final VoidCallback? onViewAll;

  const TutorSchedulePreview({
    super.key,
    required this.availability,
    this.maxSlotsPerDay = 4,
    this.onViewAll,
  });

  @override
  State<TutorSchedulePreview> createState() => _TutorSchedulePreviewState();
}

class _TutorSchedulePreviewState extends State<TutorSchedulePreview> {
  static const double _cardHeight = 132;
  static const double _viewportFraction = 0.88;

  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: _viewportFraction);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = ScheduleTimeUtils.orderedDays(widget.availability);
    if (days.isEmpty) {
      return Text(
        'Schedule not available',
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _cardHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: days.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final day = days[index];
              final raw = widget.availability[day];
              final times = ScheduleTimeUtils.sorted(
                raw is List ? raw : [raw],
              );
              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 6,
                  right: index == days.length - 1 ? 0 : 6,
                ),
                child: TutorScheduleDaySection(
                  day: day,
                  times: times,
                  maxSlots: widget.maxSlotsPerDay,
                  compact: true,
                  inSlider: true,
                ),
              );
            },
          ),
        ),
        if (days.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(days.length, (index) {
              final active = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.primaryColor
                      : AppTheme.neutral200,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
        if (widget.onViewAll != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: widget.onViewAll,
            child: Row(
              children: [
                Text(
                  'View full schedule',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
