import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart';
import 'package:table_calendar/table_calendar.dart';

/// Book Trial Session Screen
///
/// Simple, clean UI for booking a trial session with a tutor:
/// - Calendar for date selection
/// - Time slots (based on tutor availability)
/// - Duration selector (30/60 minutes)
/// - Subject selection
/// - Trial goal/reason input
///
/// Trial sessions are typically online for now
class BookTrialSessionScreen extends StatefulWidget {
  final Map<String, dynamic> tutor;

  const BookTrialSessionScreen({
    Key? key,
    required this.tutor,
  }) : super(key: key);

  @override
  State<BookTrialSessionScreen> createState() => _BookTrialSessionScreenState();
}

class _BookTrialSessionScreenState extends State<BookTrialSessionScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  String? _selectedTime;
  int _selectedDuration = 60; // Default: 60 minutes
  String? _selectedSubject;
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _challengesController = TextEditingController();

  // Available time slots (demo data - will be dynamic based on tutor availability)
  final List<String> _availableTimeSlots = [
    '09:00', '10:00', '11:00',
    '14:00', '15:00', '16:00', '17:00',
    '18:00', '19:00', '20:00',
  ];

  // Trial fee based on duration
  double get _trialFee => _selectedDuration == 30 ? 2000.0 : 3500.0;

  bool _canSubmit() {
    return _selectedTime != null &&
        _selectedSubject != null &&
        _goalController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _goalController.dispose();
    _challengesController.dispose();
    super.dispose();
  }

  Future<void> _submitTrialRequest() async {
    if (!_canSubmit()) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Sending trial request...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await TrialSessionService.createTrialRequest(
        tutorId: widget.tutor['user_id'] ?? widget.tutor['id'],
        subject: _selectedSubject!,
        scheduledDate: _selectedDate,
        scheduledTime: _selectedTime!,
        durationMinutes: _selectedDuration,
        location: 'online', // Trial sessions are typically online
        trialGoal: _goalController.text.trim(),
        learnerChallenges: _challengesController.text.trim().isNotEmpty
            ? _challengesController.text.trim()
            : null,
      );

      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      // Show success
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      // Show error
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[600], size: 28),
              const SizedBox(width: 12),
              Text(
                'Request Failed',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Text(
            'Unable to send your trial request. Please try again.',
            style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Try Again',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Go back
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: Text(
                'Go Back',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 60,
                color: Colors.green[600],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Trial Request Sent!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your trial session request has been sent to ${widget.tutor['full_name']}!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close booking screen

                  // Navigate to Requests tab
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/student-nav',
                    (route) => false,
                    arguments: {'initialTab': 2}, // Requests tab
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'View My Requests',
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

  @override
  Widget build(BuildContext context) {
    final tutorSubjects = widget.tutor['subjects'] as List? ?? [];
    final subjects = tutorSubjects.map((s) => s.toString()).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Book Trial Session',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tutor info card
            _buildTutorCard(),
            const SizedBox(height: 24),

            // Subject selection
            _buildSection(
              title: 'Select Subject',
              required: true,
              child: _buildSubjectSelector(subjects),
            ),
            const SizedBox(height: 24),

            // Duration selector
            _buildSection(
              title: 'Session Duration',
              required: true,
              child: _buildDurationSelector(),
            ),
            const SizedBox(height: 24),

            // Calendar
            _buildSection(
              title: 'Select Date',
              required: true,
              child: _buildCalendar(),
            ),
            const SizedBox(height: 24),

            // Time slots
            _buildSection(
              title: 'Select Time',
              required: true,
              child: _buildTimeSlots(),
            ),
            const SizedBox(height: 24),

            // Trial goal
            _buildSection(
              title: 'What would you like to achieve in this trial session?',
              required: true,
              child: _buildTextInput(
                controller: _goalController,
                hint: 'e.g., Understand quadratic equations, improve pronunciation...',
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 24),

            // Challenges (optional)
            _buildSection(
              title: 'Any specific challenges? (Optional)',
              required: false,
              child: _buildTextInput(
                controller: _challengesController,
                hint: 'e.g., I struggle with problem-solving...',
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 24),

            // Pricing summary
            _buildPricingSummary(),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit() ? _submitTrialRequest : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: Text(
                  'Send Trial Request',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: AssetImage(
              widget.tutor['avatar_url'] ?? 'assets/images/prepskul_profile.png',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tutor['full_name'] ?? 'Tutor',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber[700]),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.tutor['rating'] ?? 4.8}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (widget.tutor['is_verified'] == true) ...[
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required bool required,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildSubjectSelector(List<String> subjects) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: subjects.map((subject) {
        final isSelected = _selectedSubject == subject;
        return GestureDetector(
          onTap: () => setState(() => _selectedSubject = subject),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
              ),
            ),
            child: Text(
              subject,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDurationSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildDurationOption(30, '30 min', '2,000 XAF'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDurationOption(60, '1 hour', '3,500 XAF'),
        ),
      ],
    );
  }

  Widget _buildDurationOption(int minutes, String label, String price) {
    final isSelected = _selectedDuration == minutes;
    return GestureDetector(
      onTap: () => setState(() => _selectedDuration = minutes),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppTheme.primaryColor : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TableCalendar(
        firstDay: DateTime.now(),
        lastDay: DateTime.now().add(const Duration(days: 60)),
        focusedDay: _focusedDate,
        selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDate = selectedDay;
            _focusedDate = focusedDay;
          });
        },
        calendarFormat: CalendarFormat.month,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSlots() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableTimeSlots.map((time) {
        final isSelected = _selectedTime == time;
        return GestureDetector(
          onTap: () => setState(() => _selectedTime = time),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
              ),
            ),
            child: Text(
              _formatTime(time),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatTime(String time24) {
    final parts = time24.split(':');
    final hour = int.parse(parts[0]);
    if (hour == 0) return '12:${parts[1]} AM';
    if (hour < 12) return '$hour:${parts[1]} AM';
    if (hour == 12) return '12:${parts[1]} PM';
    return '${hour - 12}:${parts[1]} PM';
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: (value) => setState(() {}), // Trigger rebuild for button state
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[400],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        style: GoogleFonts.poppins(fontSize: 14),
      ),
    );
  }

  Widget _buildPricingSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Trial Session Fee',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Text(
            '${_trialFee.toStringAsFixed(0)} XAF',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

