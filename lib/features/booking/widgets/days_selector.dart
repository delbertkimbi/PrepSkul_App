import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';

/// Step 2: Days Selector
///
/// Calendar-style grid for selecting which days work best
/// Shows tutor's available days
/// Pre-fills from survey data
/// Validates that user selects correct number of days based on frequency
class DaysSelector extends StatefulWidget {
  final Map<String, dynamic> tutor;
  final int requiredDays; // Based on frequency from Step 1
  final List<String>? initialDays;
  final Function(List<String>) onDaysSelected;

  const DaysSelector({
    Key? key,
    required this.tutor,
    required this.requiredDays,
    this.initialDays,
    required this.onDaysSelected,
  }) : super(key: key);

  @override
  State<DaysSelector> createState() => _DaysSelectorState();
}

class _DaysSelectorState extends State<DaysSelector> {
  final List<String> _allDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  List<String> _selectedDays = [];
  Set<String> _tutorAvailableDays = {};

  @override
  void initState() {
    super.initState();
    _loadTutorAvailability();
    _selectedDays = widget.initialDays ?? [];
  }

  void _loadTutorAvailability() {
    // Parse tutor's available schedule
    // For demo, using available_schedule array
    // In production, this would parse actual availability data
    final availableSchedule = widget.tutor['available_schedule'] as List?;

    if (availableSchedule != null) {
      for (final schedule in availableSchedule) {
        final scheduleStr = schedule.toString().toLowerCase();
        // Parse schedule strings like "Weekday evenings", "Weekends"
        if (scheduleStr.contains('weekday')) {
          _tutorAvailableDays.addAll([
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
          ]);
        }
        if (scheduleStr.contains('weekend')) {
          _tutorAvailableDays.addAll(['Saturday', 'Sunday']);
        }
      }
    }

    // Fallback: If no availability data, assume all days available
    if (_tutorAvailableDays.isEmpty) {
      _tutorAvailableDays = Set.from(_allDays);
    }
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        if (_selectedDays.length < widget.requiredDays) {
          _selectedDays.add(day);
        } else {
          // Replace oldest selection
          _selectedDays.removeAt(0);
          _selectedDays.add(day);
        }
      }
    });
    widget.onDaysSelected(_selectedDays);
  }

  bool _isDayAvailable(String day) {
    return _tutorAvailableDays.contains(day);
  }

  bool _isDaySelected(String day) {
    return _selectedDays.contains(day);
  }

  @override
  Widget build(BuildContext context) {
    final daysRemaining = widget.requiredDays - _selectedDays.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Which days work best?',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select ${widget.requiredDays} day${widget.requiredDays > 1 ? 's' : ''} for your sessions',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Tutor's availability info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: Colors.green[700]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tutor is available: ${_tutorAvailableDays.join(', ')}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.green[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Days grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: _allDays.length,
            itemBuilder: (context, index) {
              final day = _allDays[index];
              return _buildDayCard(day);
            },
          ),
          const SizedBox(height: 24),

          // Selection status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: daysRemaining == 0
                  ? Colors.green[50]
                  : AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: daysRemaining == 0
                    ? Colors.green[200]!
                    : AppTheme.primaryColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  daysRemaining == 0 ? Icons.check_circle : Icons.info_outline,
                  size: 20,
                  color: daysRemaining == 0
                      ? Colors.green[700]
                      : AppTheme.primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    daysRemaining == 0
                        ? '✓ Perfect! ${widget.requiredDays} ${widget.requiredDays > 1 ? 'days' : 'day'} selected'
                        : 'Select $daysRemaining more ${daysRemaining > 1 ? 'days' : 'day'}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: daysRemaining == 0
                          ? Colors.green[900]
                          : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_selectedDays.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Selected: ${_selectedDays.join(', ')}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayCard(String day) {
    final isAvailable = _isDayAvailable(day);
    final isSelected = _isDaySelected(day);
    final abbreviation = day.substring(0, 3); // Mon, Tue, Wed, etc.

    return GestureDetector(
      onTap: isAvailable ? () => _toggleDay(day) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : (isAvailable ? Colors.white : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
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
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              abbreviation,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : (isAvailable ? Colors.black : Colors.grey[400]),
              ),
            ),
            if (!isAvailable || isSelected) ...[
              const SizedBox(width: 4),
              if (!isAvailable)
                Icon(Icons.block, size: 14, color: Colors.grey[400])
              else if (isSelected)
                const Icon(Icons.check_circle, size: 14, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}
