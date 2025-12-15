import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/error_handler_service.dart';
import 'package:intl/intl.dart';

/// Beautiful session booking screen with time slot selection
/// Based on tutor's availability
class BookSessionScreen extends StatefulWidget {
  final Map<String, dynamic> tutor;

  const BookSessionScreen({Key? key, required this.tutor}) : super(key: key);

  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> {
  // Selected duration
  String _selectedDuration = '50 min';

  // Selected date
  DateTime _selectedDate = DateTime.now();

  // Selected time slot
  String? _selectedTimeSlot;

  // Loading state
  bool _isLoading = false;

  // Get dates for the week
  List<DateTime> get _weekDates {
    final today = DateTime.now();
    return List.generate(7, (index) => today.add(Duration(days: index)));
  }

  // Get available time slots based on tutor availability
  List<String> get _availableTimeSlots {
    // For demo, return standard slots
    // In production, parse tutor availability and generate slots dynamically
    // final availability = widget.tutor['availability'] as String? ?? '';
    return [
      '3:00 PM',
      '3:30 PM',
      '4:00 PM',
      '4:30 PM',
      '5:00 PM',
      '5:30 PM',
      '6:00 PM',
      '8:00 PM',
      '8:30 PM',
      '9:00 PM',
      '11:00 PM',
    ];
  }

  // Get afternoon slots (12pm - 6pm)
  List<String> get _afternoonSlots {
    return _availableTimeSlots.where((slot) => _isAfternoon(slot)).toList();
  }

  // Get evening slots (6pm onwards)
  List<String> get _eveningSlots {
    return _availableTimeSlots.where((slot) => !_isAfternoon(slot)).toList();
  }

  bool _isAfternoon(String timeSlot) {
    final hour = _parseHour(timeSlot);
    return hour >= 12 && hour < 18;
  }

  int _parseHour(String timeSlot) {
    // Parse "3:00 PM" -> 15
    final parts = timeSlot.split(':');
    int hour = int.parse(parts[0]);
    final isPM = timeSlot.contains('PM');

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    return hour;
  }

  Future<void> _bookSession() async {
    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }

    safeSetState(() => _isLoading = true);

    try {
      // TODO: Implement actual booking logic
      // - Create lesson record in Supabase
      // - Send notification to tutor
      // - Send confirmation to student

      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Session request sent to ${widget.tutor['full_name']}!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) safeSetState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hourlyRate = (widget.tutor['hourly_rate'] ?? 5000) as num;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedDuration == '25 min' ? '25 min lesson' : '50 min lesson',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            Text(
              'To discuss your level and learning plan',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Duration selector
                  _buildDurationSelector(),

                  const Divider(height: 1),

                  // Calendar
                  _buildCalendar(),

                  const Divider(height: 1),

                  // Time zone info
                  _buildTimeZoneInfo(),

                  // Time slots
                  _buildTimeSlots(),
                ],
              ),
            ),
          ),

          // Bottom action bar
          _buildBottomBar(hourlyRate),
        ],
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(child: _buildDurationButton('25 min')),
          const SizedBox(width: 12),
          Expanded(child: _buildDurationButton('50 min')),
        ],
      ),
    );
  }

  Widget _buildDurationButton(String duration) {
    final isSelected = _selectedDuration == duration;

    return GestureDetector(
      onTap: () {
        safeSetState(() {
          _selectedDuration = duration;
          _selectedTimeSlot = null; // Reset time slot
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : AppTheme.softBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.textDark : AppTheme.softBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            duration,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppTheme.textDark : AppTheme.textMedium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_selectedDate),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              TextButton(
                onPressed: () {
                  safeSetState(() => _selectedDate = DateTime.now());
                },
                child: Text(
                  'Today',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _weekDates.length,
              itemBuilder: (context, index) {
                final date = _weekDates[index];
                final isSelected =
                    DateFormat('yyyy-MM-dd').format(date) ==
                    DateFormat('yyyy-MM-dd').format(_selectedDate);
                final isToday =
                    DateFormat('yyyy-MM-dd').format(date) ==
                    DateFormat('yyyy-MM-dd').format(DateTime.now());

                return GestureDetector(
                  onTap: () {
                    safeSetState(() {
                      _selectedDate = date;
                      _selectedTimeSlot = null; // Reset time slot
                    });
                  },
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.softBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(date),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textMedium,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('d').format(date),
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textDark,
                          ),
                        ),
                        if (isToday && !isSelected)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeZoneInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: AppTheme.softBackground.withOpacity(0.5),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 16, color: AppTheme.textLight),
          const SizedBox(width: 8),
          Text(
            'In your time zone, Africa/Douala (GMT +1:00)',
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlots() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Afternoon slots
          if (_afternoonSlots.isNotEmpty) ...[
            _buildTimePeriodHeader('Afternoon', Icons.wb_sunny_outlined),
            const SizedBox(height: 12),
            _buildSlotGrid(_afternoonSlots),
            const SizedBox(height: 24),
          ],

          // Evening slots
          if (_eveningSlots.isNotEmpty) ...[
            _buildTimePeriodHeader('Evening', Icons.nights_stay_outlined),
            const SizedBox(height: 12),
            _buildSlotGrid(_eveningSlots),
          ],
        ],
      ),
    );
  }

  Widget _buildTimePeriodHeader(String period, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textMedium),
        const SizedBox(width: 8),
        Text(
          period,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSlotGrid(List<String> slots) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: slots.map((slot) {
        final isSelected = _selectedTimeSlot == slot;

        return GestureDetector(
          onTap: () {
            safeSetState(() => _selectedTimeSlot = slot);
          },
          child: Container(
            width: (MediaQuery.of(context).size.width - 64) / 2,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : AppTheme.softBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                slot,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar(num hourlyRate) {
    final duration = _selectedDuration == '25 min' ? 0.5 : 1.0;
    final totalCost = (hourlyRate * duration).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Cost',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textMedium,
                  ),
                ),
                Text(
                  '${(totalCost / 1000).toStringAsFixed(1)}k XAF',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _bookSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Request Session',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
