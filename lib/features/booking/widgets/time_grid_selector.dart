import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Step 3: Time Grid Selector
///
/// Beautiful calendar-style time grid (like trial booking)
/// Shows available time slots per day
/// Groups by Afternoon/Evening
/// Shows conflicts (tutor has another student)
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

  // Available time slots (in production, this would come from tutor's availability)
  final List<String> _afternoonSlots = [
    '12:00 PM',
    '12:30 PM',
    '1:00 PM',
    '1:30 PM',
    '2:00 PM',
    '2:30 PM',
    '3:00 PM',
    '3:30 PM',
    '4:00 PM',
    '4:30 PM',
    '5:00 PM',
    '5:30 PM',
  ];

  final List<String> _eveningSlots = [
    '6:00 PM',
    '6:30 PM',
    '7:00 PM',
    '7:30 PM',
    '8:00 PM',
    '8:30 PM',
    '9:00 PM',
    '9:30 PM',
  ];

  // Slots that are already booked (demo data)
  final Map<String, List<String>> _conflictSlots = {
    'Monday': ['4:00 PM', '4:30 PM'],
    'Wednesday': ['3:00 PM'],
  };

  @override
  void initState() {
    super.initState();
    _selectedTimes = widget.initialTimes ?? {};
  }

  String get _currentDay {
    return widget.selectedDays[_currentDayIndex];
  }

  bool _isSlotAvailable(String time) {
    return !(_conflictSlots[_currentDay]?.contains(time) ?? false);
  }

  void _selectTime(String time) {
    setState(() {
      _selectedTimes[_currentDay] = time;
    });
    widget.onTimesSelected(_selectedTimes);
  }

  void _nextDay() {
    if (_currentDayIndex < widget.selectedDays.length - 1) {
      setState(() => _currentDayIndex++);
    }
  }

  void _previousDay() {
    if (_currentDayIndex > 0) {
      setState(() => _currentDayIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
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

          // Afternoon slots
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

          // Evening slots
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

          // Conflict warning (if any)
          if (_conflictSlots[_currentDay]?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: 18,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Note: Tutor has another student at ${_conflictSlots[_currentDay]!.join(', ')}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

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
    final isAvailable = _isSlotAvailable(time);
    final isSelected = _selectedTimes[_currentDay] == time;

    return GestureDetector(
      onTap: isAvailable ? () => _selectTime(time) : null,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : (isAvailable ? Colors.white : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isAvailable ? Colors.grey[300]! : Colors.grey[200]!),
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
          child: isAvailable
              ? FittedBox(
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
                )
              : Icon(Icons.block, size: 16, color: Colors.grey[400]),
        ),
      ),
    );
  }
}
