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

  // Helper to parse "3:00 PM" to DateTime (using dummy date)
  DateTime _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPM = parts[1].toUpperCase() == 'PM';

      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      return DateTime.now();
    }
  }

  void _selectTime(String time) {
    safeSetState(() {
      _selectedTimes[_currentDay] = time;
    });
    widget.onTimesSelected(_selectedTimes);
  }

  void _nextDay() {
    if (_currentDayIndex < widget.selectedDays.length - 1) {
      safeSetState(() => _currentDayIndex++);
      _loadAvailability();
    }
  }

  void _previousDay() {
    if (_currentDayIndex > 0) {
      safeSetState(() => _currentDayIndex--);
      _loadAvailability();
    }
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

          // Day progress indicator
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

          // Selected time indicator
          if (_selectedTimes.containsKey(_currentDay))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 20, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  Text(
                    '✓ Selected: $_currentDay ${_selectedTimes[_currentDay]}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.green[900],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // Navigation buttons
          if (widget.selectedDays.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentDayIndex > 0)
                  TextButton.icon(
                    onPressed: _previousDay,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: Text(
                      'Previous Day',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  )
                else
                  const SizedBox(),
                if (_currentDayIndex < widget.selectedDays.length - 1 &&
                    _selectedTimes.containsKey(_currentDay))
                  ElevatedButton.icon(
                    onPressed: _nextDay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(
                      'Next Day',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
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
    // Availability is already filtered by the service, so all displayed slots are available
    final isSelected = _selectedTimes[_currentDay] == time;

    return GestureDetector(
      onTap: () => _selectTime(time),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
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
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
