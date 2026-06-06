import 'package:flutter/material.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/booking/services/availability_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

/// Step 3: Time Grid Selector
///
/// Beautiful calendar-style time grid (like trial booking)
/// Shows available time slots per day
/// Groups by Afternoon/Evening
/// User picks one time for each selected day
class TimeGridSelector extends StatefulWidget {
  final Map<String, dynamic> tutor;
  final List<String> selectedDays;
  final Map<String, String>? initialTimes;
  final Function(Map<String, String>) onTimesSelected;

  const TimeGridSelector({
    Key? key,
    required this.tutor,
    required this.selectedDays,
    this.initialTimes,
    required this.onTimesSelected,
  }) : super(key: key);

  @override
  State<TimeGridSelector> createState() => _TimeGridSelectorState();
}

class _TimeGridSelectorState extends State<TimeGridSelector> {
  Map<String, String> _selectedTimes = {};
  int _currentDayIndex = 0;
  bool _isLoading = false;
  
  // Loaded from service
  List<String> _availableSlots = [];
  
  // Grouped slots
  List<String> _afternoonSlots = [];
  List<String> _eveningSlots = [];

  @override
  void initState() {
    super.initState();
    _selectedTimes = widget.initialTimes ?? {};
    _loadAvailability();
  }

  @override
  void didUpdateWidget(TimeGridSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDays != widget.selectedDays) {
      // Reset index if days changed significantly
      _currentDayIndex = 0;
      _loadAvailability();
    }
  }

  String get _currentDay {
    if (widget.selectedDays.isEmpty) return '';
    return widget.selectedDays[_currentDayIndex];
  }

  Future<void> _loadAvailability() async {
    if (_currentDay.isEmpty) return;
    
    safeSetState(() {
      _isLoading = true;
      _afternoonSlots = [];
      _eveningSlots = [];
    });

    try {
      final tutorId = widget.tutor['user_id'] ?? widget.tutor['id'];
      // For recurring sessions, we check generic day availability (no specific date)
      final slots = await AvailabilityService.getAvailableTimesForDay(
        tutorId: tutorId,
        day: _currentDay,
      );

      // Sort slots chronologically
      slots.sort((a, b) {
        return _parseTime(a).compareTo(_parseTime(b));
      });

      // Group slots
      final afternoon = <String>[];
      final evening = <String>[];

      for (final slot in slots) {
        final time = _parseTime(slot);
        // Afternoon: < 6 PM (18:00)
        if (time.hour < 18) {
          afternoon.add(slot);
        } else {
          evening.add(slot);
        }
      }

      if (mounted) {
        safeSetState(() {
          _availableSlots = slots;
          _afternoonSlots = afternoon;
          _eveningSlots = evening;
          _isLoading = false;
        });
      }
    } catch (e) {
      LogService.debug('Error loading availability: $e');
      if (mounted) {
        safeSetState(() => _isLoading = false);
      }
    }
  }

  /// Parse "09:00" or "3:00 PM" into hour/minute (same rules as trial booking).
  ({int hour, int minute})? _parseHourMinute(String slot) {
    try {
      final normalized = slot.trim().toUpperCase();
      int hour;
      int minute;

      if (normalized.contains('AM') || normalized.contains('PM')) {
        final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)').firstMatch(normalized);
        if (match == null) return null;
        hour = int.parse(match.group(1)!);
        minute = int.parse(match.group(2)!);
        final meridian = match.group(3)!;
        if (meridian == 'PM' && hour != 12) hour += 12;
        if (meridian == 'AM' && hour == 12) hour = 0;
      } else {
        final parts = normalized.split(':');
        if (parts.length < 2) return null;
        hour = int.tryParse(parts[0]) ?? 0;
        minute = int.tryParse(parts[1].split(' ')[0]) ?? 0;
      }

      return (hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
    } catch (_) {
      return null;
    }
  }

  DateTime _parseTime(String timeStr) {
    final parsed = _parseHourMinute(timeStr);
    final now = DateTime.now();
    if (parsed == null) {
      return DateTime(now.year, now.month, now.day);
    }
    return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
  }

  bool _isPastSlotForToday(String slot) {
    final now = DateTime.now();
    final todayName = _getDayName(now.weekday).toLowerCase();
    if (_currentDay.toLowerCase() != todayName) return false;

    final parsed = _parseHourMinute(slot);
    if (parsed == null) return false;

    final slotTime = DateTime(
      now.year,
      now.month,
      now.day,
      parsed.hour,
      parsed.minute,
    );
    return !slotTime.isAfter(now);
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      default:
        return '';
    }
  }

  void _selectTime(String time) {
    safeSetState(() {
      _selectedTimes[_currentDay] = time;
    });
    widget.onTimesSelected(_selectedTimes);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedDays.isEmpty) {
      return Center(child: Text('Please select days first'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Select time for $_currentDay',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the best time for this day',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Day tabs (tappable – switch day without Next Day button)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: widget.selectedDays.asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value;
                final abbreviation = day.substring(0, 3);
                final isActive = index == _currentDayIndex;
                final hasTime = _selectedTimes.containsKey(day);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (index != _currentDayIndex) {
                        safeSetState(() => _currentDayIndex = index);
                        _loadAvailability();
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.primaryColor
                            : (hasTime ? Colors.green[100] : Colors.transparent),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        abbreviation,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : (hasTime ? Colors.green[700] : Colors.grey[600]),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else ...[
            // Afternoon slots
            if (_afternoonSlots.isNotEmpty) ...[
              Text(
                'Afternoon (12 PM - 6 PM)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              _buildTimeGrid(_afternoonSlots),
              const SizedBox(height: 32),
            ],

            // Evening slots
            if (_eveningSlots.isNotEmpty) ...[
              Text(
                'Evening (6 PM - 10 PM)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              _buildTimeGrid(_eveningSlots),
              const SizedBox(height: 24),
            ],
            
            if (_afternoonSlots.isEmpty && _eveningSlots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No available slots for this day',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ),
          ],

          const SizedBox(height: 24),
          // Hint: tap day tabs to switch; Continue is active when all days have a time selected
          if (widget.selectedDays.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Tap a day above to pick its time. Continue when every day has a time.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeGrid(List<String> timeSlots) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.8,
      ),
      itemCount: timeSlots.length,
      itemBuilder: (context, index) {
        final time = timeSlots[index];
        return _buildTimeSlot(time);
      },
    );
  }

  Widget _buildTimeSlot(String time) {
    // Disable times already in the past when the selected weekday is today.
    final isPastForToday = _isPastSlotForToday(time);
    final isSelected = !isPastForToday && _selectedTimes[_currentDay] == time;

    return GestureDetector(
      onTap: isPastForToday ? null : () => _selectTime(time),
      child: Container(
        decoration: BoxDecoration(
          color: isPastForToday
              ? Colors.grey[200]
              : isSelected
                  ? AppTheme.primaryColor
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPastForToday
                ? Colors.grey[300]!
                : isSelected
                    ? AppTheme.primaryColor
                    : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                time,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isPastForToday
                      ? Colors.grey[500]
                      : isSelected
                          ? Colors.white
                          : Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}