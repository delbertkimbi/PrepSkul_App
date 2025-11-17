import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart';
import 'package:prepskul/features/booking/services/availability_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

/// Book Trial Session Screen - Multi-step Flow
///
/// 3-Step wizard for booking a trial session:
/// 1. Subject & Duration
/// 2. Date & Time
/// 3. Goals & Review
class BookTrialSessionScreen extends StatefulWidget {
  final Map<String, dynamic> tutor;

  const BookTrialSessionScreen({Key? key, required this.tutor})
    : super(key: key);

  @override
  State<BookTrialSessionScreen> createState() => _BookTrialSessionScreenState();
}

class _BookTrialSessionScreenState extends State<BookTrialSessionScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 3;

  // Step 1: Subject & Duration
  String? _selectedSubject;
  int _selectedDuration = 60; // Default: 60 minutes

  // Step 2: Date & Time
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  String? _selectedTime;

  // Step 3: Goals
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _challengesController = TextEditingController();

  // Available time slots (will be loaded from tutor's schedule)
  List<String> _availableTimeSlots = [
    '09:00',
    '10:00',
    '11:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
  ];

  // Blocked time slots for the selected date (from tutor's existing sessions)
  List<String> _blockedTimeSlots = [];
  String? _conflictMessage; // Message about tutor's other commitments
  bool _isLoadingSchedule = false;

  double _trialFee = 3500.0; // Default, will be loaded from database
  bool _isLoadingPrice = false;

  // Location data (prefilled from survey)
  String _selectedLocation = 'online'; // Default to online
  String? _onsiteAddress;
  String? _locationDescription;

  @override
  void initState() {
    super.initState();
    _prefillFromSurvey();
    _loadTrialPricing();
    _loadTutorSchedule();
  }

  /// Load trial session pricing from database
  Future<void> _loadTrialPricing() async {
    try {
      setState(() => _isLoadingPrice = true);
      final price = await PricingService.getTrialSessionPrice(
        _selectedDuration,
      );
      if (mounted) {
        setState(() {
          _trialFee = price.toDouble();
          _isLoadingPrice = false;
        });
      }
    } catch (e) {
      print('⚠️ Error loading trial pricing: $e');
      if (mounted) {
        setState(() => _isLoadingPrice = false);
      }
      // Keep default value on error
    }
  }

  /// Load tutor's schedule and blocked time slots
  Future<void> _loadTutorSchedule() async {
    try {
      setState(() => _isLoadingSchedule = true);
      final tutorId =
          widget.tutor['user_id'] as String? ?? widget.tutor['id'] as String?;
      if (tutorId == null) {
        print('⚠️ No tutor ID found');
        return;
      }

      // Get the day name for the selected date
      final dayName = DateFormat('EEEE').format(_selectedDate);

      // Get blocked time slots for this tutor
      final blockedSlots = await AvailabilityService.getBlockedTimeSlots(
        tutorId,
      );
      final dayBlockedSlots = blockedSlots[dayName] ?? [];

      // Get available times for this day (filters out blocked slots)
      final availableTimes = await AvailabilityService.getAvailableTimesForDay(
        tutorId: tutorId,
        day: dayName,
      );

      // Convert available times to 24-hour format for display
      final availableSlots24h = availableTimes.map((time) {
        // Convert "4:00 PM" to "16:00"
        try {
          final timeParts = time.split(' ');
          final hourMin = timeParts[0].split(':');
          var hour = int.parse(hourMin[0]);
          final minute = hourMin.length > 1 ? int.parse(hourMin[1]) : 0;
          final isPM =
              timeParts.length > 1 && timeParts[1].toUpperCase() == 'PM';

          if (isPM && hour != 12) hour += 12;
          if (!isPM && hour == 12) hour = 0;

          return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        } catch (e) {
          return time; // Return original if parsing fails
        }
      }).toList();

      // Build conflict message if there are blocked slots
      String? conflictMsg;
      if (dayBlockedSlots.isNotEmpty) {
        conflictMsg =
            'Tutor has another student at ${dayBlockedSlots.join(', ')}';
      }

      if (mounted) {
        setState(() {
          _blockedTimeSlots = dayBlockedSlots;
          _conflictMessage = conflictMsg;
          // Update available slots if we got real data
          if (availableSlots24h.isNotEmpty) {
            _availableTimeSlots = availableSlots24h;
          }
          _isLoadingSchedule = false;
        });
      }
    } catch (e) {
      print('⚠️ Error loading tutor schedule: $e');
      if (mounted) {
        setState(() => _isLoadingSchedule = false);
      }
      // Keep default slots on error
    }
  }

  /// Pre-fill data from survey if available
  Future<void> _prefillFromSurvey() async {
    try {
      final userProfile = await AuthService.getUserProfile();
      if (userProfile == null) return;

      final userType = userProfile['user_type'] as String?;
      if (userType == null) return;

      Map<String, dynamic>? surveyData;

      if (userType == 'student') {
        surveyData = await SurveyRepository.getStudentSurvey(userProfile['id']);
      } else if (userType == 'parent') {
        surveyData = await SurveyRepository.getParentSurvey(userProfile['id']);
      }

      if (surveyData != null && mounted) {
        setState(() {
          // Pre-fill location preference
          final preferredLocation = surveyData?['preferred_location'];
          if (preferredLocation != null) {
            _selectedLocation = preferredLocation.toString();
          }

          // Pre-fill address (if onsite)
          final city = surveyData?['city'];
          final quarter = surveyData?['quarter'];
          if (city != null && quarter != null) {
            final street = surveyData?['street'];
            final streetStr = street != null ? ', ${street.toString()}' : '';
            _onsiteAddress =
                '${city.toString()}, ${quarter.toString()}$streetStr';
            print('✅ Pre-filled trial session address: $_onsiteAddress');
          }

          // Pre-fill location description if available
          final locationDesc = surveyData?['location_description'];
          if (locationDesc != null) {
            _locationDescription = locationDesc.toString();
          } else {
            final additionalInfo = surveyData?['additional_address_info'];
            if (additionalInfo != null) {
              _locationDescription = additionalInfo.toString();
            }
          }
        });
      }
    } catch (e) {
      print('⚠️ Could not load survey data for trial session prefill: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _goalController.dispose();
    _challengesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: // Subject & Duration
        return _selectedSubject != null;
      case 1: // Date & Time
        return _selectedTime != null;
      case 2: // Goals
        return _goalController.text.trim().isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _submitTrialRequest() async {
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
        location: _selectedLocation,
        address: _onsiteAddress,
        locationDescription: _locationDescription,
        trialGoal: _goalController.text.trim(),
        learnerChallenges: _challengesController.text.trim().isNotEmpty
            ? _challengesController.text.trim()
            : null,
      );

      if (!mounted) return;
      Navigator.pop(context);
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
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
                  Navigator.pop(context);
                  Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/student-nav',
                    (route) => false,
                    arguments: {'initialTab': 2},
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

  void _showErrorDialog([String? errorMessage]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.primaryColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Request Failed',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
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
              Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Book Trial Session',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            Text(
              'Step ${_currentStep + 1} of $_totalSteps',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / _totalSteps,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
                minHeight: 6,
              ),
            ),
          ),
          // Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSubjectAndDuration(),
                _buildDateAndTime(),
                _buildGoalsAndReview(),
              ],
            ),
          ),
          // Navigation buttons
          Container(
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
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppTheme.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Back',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _canProceed()
                        ? (_currentStep == _totalSteps - 1
                              ? _submitTrialRequest
                              : _nextStep)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Text(
                      _currentStep == _totalSteps - 1
                          ? 'Send Request'
                          : 'Continue',
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
        ],
      ),
    );
  }

  // STEP 1: Subject & Duration
  Widget _buildSubjectAndDuration() {
    final tutorSubjects = widget.tutor['subjects'] as List? ?? [];
    final subjects = tutorSubjects.map((s) => s.toString()).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tutor card
          _buildTutorCard(),
          const SizedBox(height: 24),

          // Subject selection
          Text(
            'Select Subject',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose what you want to learn',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: subjects.map((subject) {
              final isSelected = _selectedSubject == subject;
              return GestureDetector(
                onTap: () => setState(() => _selectedSubject = subject),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    subject,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Duration selection
          Text(
            'Session Duration',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How long would you like the trial?',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDurationOption(30, '30 min', '2,000 XAF')),
              const SizedBox(width: 12),
              Expanded(child: _buildDurationOption(60, '1 hour', '3,500 XAF')),
            ],
          ),
        ],
      ),
    );
  }

  // STEP 2: Date & Time
  Widget _buildDateAndTime() {
    return SingleChildScrollView(
      physics:
          const AlwaysScrollableScrollPhysics(), // Ensure scrolling is always enabled
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Date',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'When would you like the trial session?',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          // Calendar container with visual indicator below
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: const BoxConstraints(
                  maxHeight: 380, // Constrain calendar height
                ),
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
                      _selectedTime = null; // Reset time when date changes
                    });
                    _loadTutorSchedule(); // Reload schedule for new date
                  },
                  calendarFormat: CalendarFormat.month,
                  // Disable calendar's internal scrolling to allow parent scroll
                  pageJumpingEnabled: true,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month',
                  },
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
              ),
              // Visual indicator at bottom of calendar to show more content below
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0),
                        Colors.white.withOpacity(0.8),
                        Colors.white,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: AppTheme.primaryColor.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Scroll for time slots',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.primaryColor.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Clear section divider with hint
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select a time slot below',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Select Time',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a time that works for you',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          _isLoadingSchedule
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTimeSlots.map((time) {
                    final isSelected = _selectedTime == time;
                    final formattedTime = _formatTime(time);
                    // Check if this time slot is blocked
                    final isBlocked = _blockedTimeSlots.any((blocked) {
                      // Convert blocked time to match format
                      try {
                        final blockedParts = blocked.split(' ');
                        final blockedHourMin = blockedParts[0].split(':');
                        var blockedHour = int.parse(blockedHourMin[0]);
                        final blockedMin = blockedHourMin.length > 1
                            ? int.parse(blockedHourMin[1])
                            : 0;
                        final isPM =
                            blockedParts.length > 1 &&
                            blockedParts[1].toUpperCase() == 'PM';
                        if (isPM && blockedHour != 12) blockedHour += 12;
                        if (!isPM && blockedHour == 12) blockedHour = 0;
                        final blocked24h =
                            '${blockedHour.toString().padLeft(2, '0')}:${blockedMin.toString().padLeft(2, '0')}';
                        return blocked24h == time;
                      } catch (e) {
                        return false;
                      }
                    });

                    return GestureDetector(
                      onTap: isBlocked
                          ? null
                          : () => setState(() => _selectedTime = time),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isBlocked
                              ? Colors.grey[200]
                              : (isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.white),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isBlocked
                                ? Colors.grey[300]!
                                : (isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.grey[300]!),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isBlocked)
                              Icon(
                                Icons.block,
                                size: 16,
                                color: Colors.grey[400],
                              )
                            else
                              const SizedBox.shrink(),
                            if (isBlocked) const SizedBox(width: 4),
                            Text(
                              formattedTime,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isBlocked
                                    ? Colors.grey[400]
                                    : (isSelected
                                          ? Colors.white
                                          : Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

          // Show conflict message if tutor has other commitments
          if (_conflictMessage != null && _conflictMessage!.isNotEmpty) ...[
            const SizedBox(height: 16),
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
                      'Note: $_conflictMessage',
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
        ],
      ),
    );
  }

  // STEP 3: Goals & Review
  Widget _buildGoalsAndReview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trial Session Goals',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Help the tutor prepare for your session',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // Goal input
          Text(
            'What would you like to achieve? *',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: _goalController,
              maxLines: 3,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText:
                    'e.g., Understand quadratic equations, improve pronunciation...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),

          // Challenges input
          Text(
            'Any specific challenges? (Optional)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: _challengesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g., I struggle with problem-solving...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),

          // Review summary
          Text(
            'Review Details',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildReviewRow('Tutor', widget.tutor['full_name'] ?? 'Tutor'),
                const Divider(height: 24),
                _buildReviewRow('Subject', _selectedSubject ?? '-'),
                const Divider(height: 24),
                _buildReviewRow(
                  'Duration',
                  _selectedDuration == 30 ? '30 minutes' : '1 hour',
                ),
                const Divider(height: 24),
                _buildReviewRow(
                  'Date',
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                ),
                const Divider(height: 24),
                _buildReviewRow(
                  'Time',
                  _selectedTime != null ? _formatTime(_selectedTime!) : '-',
                ),
                const Divider(height: 24),
                _buildReviewRow('Location', 'Online'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pricing
          Container(
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
                _isLoadingPrice
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        '${_trialFee.toStringAsFixed(0)} XAF',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get tutor avatar image - handles both network URLs and asset paths
  ImageProvider? _getTutorAvatarImage() {
    final avatarUrl =
        widget.tutor['avatar_url'] ?? widget.tutor['profile_photo_url'];

    if (avatarUrl == null || avatarUrl.toString().isEmpty) {
      return null;
    }

    final urlString = avatarUrl.toString();

    // Check if it's a network URL
    if (urlString.startsWith('http://') ||
        urlString.startsWith('https://') ||
        urlString.startsWith('//')) {
      return NetworkImage(urlString);
    }

    // Otherwise, treat as asset path
    return AssetImage(urlString);
  }

  Widget _buildTutorCard() {
    final avatarImage = _getTutorAvatarImage();
    final tutorName = widget.tutor['full_name'] ?? 'Tutor';

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
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: avatarImage,
            onBackgroundImageError: avatarImage != null
                ? (exception, stackTrace) {
                    // Image failed to load, will show fallback
                  }
                : null,
            child: avatarImage == null
                ? Text(
                    tutorName.isNotEmpty ? tutorName[0].toUpperCase() : 'T',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  )
                : null,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                    if (widget.tutor['is_verified'] == true) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: AppTheme.primaryColor,
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

  Widget _buildDurationOption(int minutes, String label, String price) {
    final isSelected = _selectedDuration == minutes;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedDuration = minutes);
        _loadTrialPricing(); // Reload pricing when duration changes
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.white,
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

  Widget _buildReviewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
}
