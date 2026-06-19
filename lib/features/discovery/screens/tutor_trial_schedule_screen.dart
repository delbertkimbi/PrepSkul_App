import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/features/booking/screens/book_trial_session_screen.dart';
import 'package:prepskul/features/booking/services/availability_service.dart';
import 'package:prepskul/features/discovery/utils/schedule_time_utils.dart';

/// Preply-style trial schedule picker — 30 min slots, then straight into booking.
class TutorTrialScheduleScreen extends StatefulWidget {
  final Map<String, dynamic> tutor;
  final Map<String, dynamic> availability;

  const TutorTrialScheduleScreen({
    super.key,
    required this.tutor,
    required this.availability,
  });

  @override
  State<TutorTrialScheduleScreen> createState() =>
      _TutorTrialScheduleScreenState();
}

class _TutorTrialScheduleScreenState extends State<TutorTrialScheduleScreen> {
  static const int _trialDurationMinutes = 30;

  late final List<DateTime> _availableDates;
  late int _selectedDateIndex;
  late final ScrollController _dateScrollController;

  String? _selectedTime;
  List<String> _availableTimes = [];
  bool _loadingSlots = false;

  String? get _tutorId =>
      widget.tutor['user_id'] as String? ?? widget.tutor['id'] as String?;

  DateTime get _selectedDate => _availableDates[_selectedDateIndex];

  @override
  void initState() {
    super.initState();
    _availableDates =
        ScheduleTimeUtils.upcomingAvailableDates(widget.availability);
    _selectedDateIndex = ScheduleTimeUtils.initialSelectedDateIndex(
      widget.availability,
      _availableDates,
    );
    _dateScrollController = ScrollController();
    _loadSlotsForSelectedDate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSlotsForSelectedDate() async {
    final tutorId = _tutorId;
    if (tutorId == null) return;

    final dayName = DateFormat('EEEE').format(_selectedDate);
    final raw = widget.availability[dayName];
    final templateSlots = ScheduleTimeUtils.sorted(raw is List ? raw : [raw]);

    safeSetState(() {
      _loadingSlots = true;
      _selectedTime = null;
    });

    try {
      final available = await AvailabilityService.getAvailableTimesForDay(
        tutorId: tutorId,
        day: dayName,
        date: _selectedDate,
      );
      if (!mounted) return;
      safeSetState(() {
        _availableTimes = available;
        _loadingSlots = false;
      });
    } catch (_) {
      if (!mounted) return;
      safeSetState(() {
        _availableTimes = templateSlots;
        _loadingSlots = false;
      });
    }
  }

  void _selectDateIndex(int index) {
    if (index < 0 || index >= _availableDates.length) return;
    safeSetState(() => _selectedDateIndex = index);
    _loadSlotsForSelectedDate();
    _scrollToSelectedDate();
  }

  void _shiftDate(int delta) {
    _selectDateIndex(_selectedDateIndex + delta);
  }

  void _scrollToSelectedDate() {
    if (!_dateScrollController.hasClients) return;
    const itemWidth = 46.0;
    const spacing = 6.0;
    final offset = (_selectedDateIndex * (itemWidth + spacing)) - 40;
    _dateScrollController.animateTo(
      offset.clamp(0.0, _dateScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Map<String, List<String>> _groupedSlots() {
    final morning = <String>[];
    final afternoon = <String>[];
    final evening = <String>[];

    for (final time in _availableTimes) {
      final minutes = ScheduleTimeUtils.toMinutes(time);
      if (minutes < 12 * 60) {
        morning.add(time);
      } else if (minutes < 17 * 60) {
        afternoon.add(time);
      } else {
        evening.add(time);
      }
    }

    return {
      if (morning.isNotEmpty) 'Morning': morning,
      if (afternoon.isNotEmpty) 'Afternoon': afternoon,
      if (evening.isNotEmpty) 'Evening': evening,
    };
  }

  String _formatSlotLabel(String raw) {
    try {
      final parsed = DateFormat('HH:mm').parse(raw);
      return DateFormat('h:mm a').format(parsed);
    } catch (_) {
      return raw;
    }
  }

  void _continueToBooking(String time) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookTrialSessionScreen(
          tutor: widget.tutor,
          preselectedDate: _selectedDate,
          preselectedTime: time,
          skipScheduleStep: true,
          lockTrialDurationMinutes: _trialDurationMinutes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_availableDates.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          foregroundColor: AppTheme.primaryColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This tutor has no open schedule yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppTheme.textMedium,
              ),
            ),
          ),
        ),
      );
    }

    final grouped = _groupedSlots();
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedDate);
    final tz = DateTime.now().timeZoneName;
    final canGoBack = _selectedDateIndex > 0;
    final canGoForward = _selectedDateIndex < _availableDates.length - 1;
    final selectedIsToday = ScheduleTimeUtils.isToday(_selectedDate);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        foregroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '30 min trial session',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Meet your tutor and discuss your learning goals.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.neutral100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.softBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '30 min',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              'Trial on PrepSkul',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.textMedium,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          monthLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      if (selectedIsToday)
                        Text(
                          'Today',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _DateNavButton(
                        icon: Icons.chevron_left,
                        enabled: canGoBack,
                        onTap: () => _shiftDate(-1),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 72,
                          child: ListView.separated(
                            controller: _dateScrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: _availableDates.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final day = _availableDates[index];
                              final isSelected = index == _selectedDateIndex;

                              return GestureDetector(
                                onTap: () => _selectDateIndex(index),
                                child: Column(
                                  children: [
                                    Text(
                                      DateFormat('EEE').format(day),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AppTheme.textDark
                                            : AppTheme.textMedium,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${day.day}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Colors.white
                                              : AppTheme.textDark,
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
                      _DateNavButton(
                        icon: Icons.chevron_right,
                        enabled: canGoForward,
                        onTap: () => _shiftDate(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'In your time zone, $tz',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_loadingSlots)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (grouped.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No open slots on this day. Try another date.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    )
                  else
                    ...grouped.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  entry.key == 'Morning'
                                      ? Icons.wb_sunny_outlined
                                      : entry.key == 'Afternoon'
                                          ? Icons.wb_twilight_outlined
                                          : Icons.nightlight_round_outlined,
                                  size: 18,
                                  color: AppTheme.textMedium,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.key,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: entry.value.map((slot) {
                                final selected = _selectedTime == slot;
                                return SizedBox(
                                  width:
                                      (MediaQuery.sizeOf(context).width - 60) /
                                          2,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      safeSetState(() => _selectedTime = slot);
                                      _continueToBooking(slot);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: selected
                                          ? AppTheme.primaryColor
                                              .withOpacity(0.06)
                                          : Colors.white,
                                      foregroundColor: selected
                                          ? AppTheme.primaryColor
                                          : AppTheme.textDark,
                                      side: BorderSide(
                                        color: selected
                                            ? AppTheme.primaryColor
                                            : AppTheme.softBorder,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      _formatSlotLabel(slot),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _DateNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppTheme.neutral100 : AppTheme.neutral100.withOpacity(0.5),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppTheme.textDark : AppTheme.textLight,
          ),
        ),
      ),
    );
  }
}
