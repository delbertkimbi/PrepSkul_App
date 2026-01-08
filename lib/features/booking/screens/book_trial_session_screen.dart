import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/auth_service.dart' hide LogService;
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/core/services/tutor_service.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart' hide LogService;
import 'package:prepskul/features/booking/services/availability_service.dart';
import 'package:prepskul/features/booking/utils/session_date_utils.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';

/// Book Trial Session Screen - Multi-step Flow
///
/// 3-Step wizard for booking a trial session:
/// 1. Subject & Duration
/// 2. Date & Time
/// 3. Goals & Review
class BookTrialSessionScreen extends StatefulWidget {
  final Map<String, dynamic> tutor;
  final String? rescheduleSessionId; // ID of the session being rescheduled
  final bool isReschedule; // Flag to indicate this is a reschedule request
  final String? rescheduleReason; // Reason for rescheduling (for date change requests)

  const BookTrialSessionScreen({
    Key? key, 
    required this.tutor,
    this.rescheduleSessionId,
    this.isReschedule = false,
    this.rescheduleReason,
  }) : super(key: key);

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
  double _basePrice = 3500.0; // Base price without discount
  bool _isLoadingPrice = false;
  bool _discountApplied = false; // Track if user clicked "Get Discount"
  Map<int, Map<String, dynamic>> _pricingDetails = {}; // Stores pricing details for each duration

  // Location data (prefilled from survey)
  String _selectedLocation = 'online'; // Default to online
  String? _onsiteAddress;
  String? _locationDescription;
  
  // Confetti controller for celebrations
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    if (widget.isReschedule && widget.rescheduleSessionId != null) {
      _loadOriginalSessionData();
    } else {
    _prefillFromSurvey();
    }
    _loadTrialPricing();
    _loadTutorSchedule();
  }
  
  /// Load original session data when rescheduling
  Future<void> _loadOriginalSessionData() async {
    try {
      if (widget.rescheduleSessionId == null) return;
      
      final session = await TrialSessionService.getTrialSessionById(widget.rescheduleSessionId!);
      if (session != null && mounted) {
        safeSetState(() {
          // Pre-fill form with original session data
          _selectedSubject = session.subject;
          _selectedDuration = session.durationMinutes;
          _selectedDate = session.scheduledDate;
          _selectedTime = session.scheduledTime;
          _selectedLocation = session.location;
          _goalController.text = session.trialGoal ?? '';
          _challengesController.text = session.learnerChallenges ?? '';
        });
      }
    } catch (e) {
      LogService.warning('Error loading original session data: $e');
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pageController.dispose();
    _goalController.dispose();
    _challengesController.dispose();
    super.dispose();
  }

  /// Load trial session pricing from database
  Future<void> _loadTrialPricing() async {
    try {
      safeSetState(() => _isLoadingPrice = true);
      
      // Load detailed pricing for all durations first
      final details = await PricingService.getTrialSessionPricingWithDetails();
      
      // Get price for currently selected duration
      final currentPricing = details[_selectedDuration];
      final basePrice = currentPricing != null 
          ? (currentPricing['basePrice'] as double) 
          : (_selectedDuration == 30 ? 2000.0 : 3500.0);
      // Start with base price (discount will be applied later if user clicks button)
      final initialPrice = basePrice;

      if (mounted) {
        safeSetState(() {
          _pricingDetails = details;
          _basePrice = basePrice;
          _trialFee = initialPrice; // Show base price initially
          _discountApplied = false; // Reset discount state
          _isLoadingPrice = false;
        });
      }
    } catch (e) {
      LogService.warning('Error loading trial pricing: $e');
      if (mounted) {
        safeSetState(() => _isLoadingPrice = false);
      }
      // Keep default value on error
    }
  }

  /// Load tutor's schedule and blocked time slots
  Future<void> _loadTutorSchedule() async {
    try {
      safeSetState(() => _isLoadingSchedule = true);
      final tutorId =
          widget.tutor['user_id'] as String? ?? widget.tutor['id'] as String?;
      if (tutorId == null) {
        LogService.warning('No tutor ID found');
        return;
      }

      // Get the day name for the selected date
      final dayName = DateFormat('EEEE').format(_selectedDate);

      // Get available times for this day (filters out blocked slots)
      final availableTimes = await AvailabilityService.getAvailableTimesForDay(
        tutorId: tutorId,
        day: dayName,
        date: _selectedDate, // Pass specific date for precise checking
      );

      // Convert available times to 24-hour format for display
      final availableSlots24h = availableTimes.map((time) {
        // Normalize time format
        try {
          // ... (existing normalization logic)
          return time; // Or better normalization
        } catch (e) {
          return time;
        }
      }).toList();

      // Build conflict message if there are blocked slots
      String? conflictMsg;
      // Note: With precise checking, getAvailableTimesForDay already filters blocked slots.
      // If we want to show specific conflicts, we'd need to call getBlockedTimesForDate separately.
      // For now, we just show available slots.
      
      if (availableTimes.isEmpty) {
        conflictMsg = 'No available slots for this date.';
      }

      if (mounted) {
        safeSetState(() {
          _conflictMessage = conflictMsg;
          _availableTimeSlots = availableTimes.isNotEmpty ? availableTimes : [];
          _isLoadingSchedule = false;
        });
      }
    } catch (e) {
      LogService.warning('Error loading tutor schedule: $e');
      if (mounted) {
        safeSetState(() => _isLoadingSchedule = false);
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
        safeSetState(() {
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
            LogService.success('Pre-filled trial session address: $_onsiteAddress');
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
      LogService.warning('Could not load survey data for trial session prefill: $e');
    }
  }


  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      safeSetState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      safeSetState(() => _currentStep--);
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
                widget.isReschedule && widget.rescheduleSessionId != null
                    ? 'Updating trial request...'
                    : 'Sending trial request...',
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
      // If rescheduling, ALWAYS modify the existing session (don't create new)
      // This applies to all cases: pending, expired, cancelled, approved unpaid, AND paid sessions that have passed
      if (widget.isReschedule && widget.rescheduleSessionId != null) {
        try {
          final existingSession = await TrialSessionService.getTrialSessionById(widget.rescheduleSessionId!);
          final paymentStatus = existingSession.paymentStatus.toLowerCase();
          final isPaid = paymentStatus == 'paid' || paymentStatus == 'completed';
          final isTimePassed = SessionDateUtils.isSessionExpired(existingSession);
          
          // Determine modification reason based on session state
          String? modificationReason;
          if (existingSession.status == 'pending') {
            modificationReason = null; // No reason needed for pending
          } else if (isPaid && isTimePassed) {
            modificationReason = 'Request to reschedule a missed paid session';
          } else if (isPaid && !isTimePassed) {
            // Paid but not yet passed - this shouldn't happen, but handle it
            modificationReason = 'Request to reschedule a paid session';
          } else {
            modificationReason = 'Request to reschedule a missed/expired session';
          }
          
          // ALWAYS modify the existing session - never create a new one
          await TrialSessionService.modifyTrialSession(
            sessionId: widget.rescheduleSessionId!,
            scheduledDate: _selectedDate,
            scheduledTime: _selectedTime!,
            durationMinutes: _selectedDuration,
            location: _selectedLocation,
            address: _onsiteAddress,
            locationDescription: _locationDescription,
            trialGoal: _goalController.text.trim().isNotEmpty ? _goalController.text.trim() : null,
            learnerChallenges: _challengesController.text.trim().isNotEmpty ? _challengesController.text.trim() : null,
            modificationReason: modificationReason,
          );
          
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Trial session updated successfully. Waiting for tutor approval.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return to previous screen
          return;
        } catch (e) {
          LogService.warning('Could not modify existing session, error: $e');
          // If modification fails, show error instead of silently creating new request
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update session: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      
      // Use the trial goal as-is (don't append reschedule notes to user-facing fields)
      // Reschedule information is handled separately via rescheduleSessionId parameter
      final trialGoal = _goalController.text.trim().isNotEmpty 
          ? _goalController.text.trim() 
          : null;
      
      await TrialSessionService.createTrialRequest(
        tutorId: widget.tutor['user_id'] ?? widget.tutor['id'],
        subject: _selectedSubject!,
        scheduledDate: _selectedDate,
        scheduledTime: _selectedTime!,
        durationMinutes: _selectedDuration,
        location: _selectedLocation,
        address: _onsiteAddress,
        locationDescription: _locationDescription,
        trialGoal: trialGoal,
        learnerChallenges: _challengesController.text.trim().isNotEmpty
            ? _challengesController.text.trim()
            : null,
        overrideTrialFee: _trialFee, // Use the current fee (may include discount if applied)
        rescheduleSessionId: widget.rescheduleSessionId, // Pass reschedule session ID
      );

      if (!mounted) return;
      Navigator.pop(context);
      _showSuccessDialog(_discountApplied);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Apply discount when user clicks "Get Discount" button
  void _applyDiscount() {
    final currentPricing = _pricingDetails[_selectedDuration];
    if (currentPricing != null && currentPricing['hasDiscount'] == true) {
      final finalPrice = currentPricing['finalPrice'] as double;
      safeSetState(() {
        _trialFee = finalPrice;
        _discountApplied = true;
      });
      
      // Trigger confetti celebration
      _confettiController.play();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.celebration, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Discount applied! You saved ${PricingService.formatPrice(_basePrice - finalPrice)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessDialog(bool hadDiscount) {
    // Play confetti if discount was applied
    if (hadDiscount) {
      _confettiController.play();
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Stack(
        children: [
          // Confetti overlay
          if (hadDiscount)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: 3.14 / 2, // Down
                maxBlastForce: 5,
                minBlastForce: 2,
                emissionFrequency: 0.05,
                numberOfParticles: 50,
                gravity: 0.1,
                shouldLoop: false,
              ),
            ),
          AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                    color: hadDiscount 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                    hadDiscount ? Icons.celebration : Icons.check_circle,
                size: 60,
                    color: hadDiscount ? Colors.orange[600] : Colors.green[600],
              ),
            ),
            const SizedBox(height: 20),
            Text(
                  hadDiscount ? '🎉 Discount Applied!' : 'Trial Request Sent!',
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
                // Show discounted price if discount was applied
                if (hadDiscount) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Original Price:',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              PricingService.formatPrice(_basePrice),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[600],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your Price:',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.green[800],
                              ),
                            ),
                            Text(
                              PricingService.formatPrice(_trialFee),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'You saved ${PricingService.formatPrice(_basePrice - _trialFee)}!',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                      _confettiController.stop();
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
        ],
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
              widget.isReschedule ? 'Reschedule Trial Session' : 'Book Trial Session',
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
      body: Stack(
        children: [
          Column(
            children: [
              // Reschedule banner
              if (widget.isReschedule)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    border: Border(
                      left: BorderSide(
                        color: AppTheme.primaryColor,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rescheduling Missed Session',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You are requesting to reschedule a missed trial session. The tutor will be notified and can approve or suggest an alternative time.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
          // Confetti overlay (for discount celebration)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2, // Down
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
              shouldLoop: false,
            ),
          ),
        ],
      ),
    );
  }

  // STEP 1: Subject & Duration
  Widget _buildSubjectAndDuration() {
    // Use the helper function to normalize subjects (handles subjects/specializations, JSON strings, etc.)
    final subjects = TutorService.normalizeTutorSubjects(widget.tutor);

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
          subjects.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This tutor has not specified any subjects yet. Please contact the tutor directly or try booking a different tutor.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: subjects.map((subject) {
                    final isSelected = _selectedSubject == subject;
                    return GestureDetector(
                      onTap: () => safeSetState(() => _selectedSubject = subject),
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
          // Calendar container (Simplified)
          Container(
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
                safeSetState(() {
                  _selectedDate = selectedDay;
                  _focusedDate = focusedDay;
                  _selectedTime = null; // Reset time when date changes
                });
                _loadTutorSchedule(); // Reload schedule for new date
              },
              calendarFormat: CalendarFormat.month,
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
                          : () => safeSetState(() => _selectedTime = time),
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
              onChanged: (value) => safeSetState(() {}),
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

          // Pricing with discount option
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
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
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                              // ALWAYS show original price (strikethrough) at top if discount is available
                          if (_pricingDetails[_selectedDuration]?['hasDiscount'] == true)
                            Text(
                                  PricingService.formatPrice(_basePrice),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                              if (_pricingDetails[_selectedDuration]?['hasDiscount'] == true)
                                const SizedBox(height: 4),
                              // Show discounted price if discount available (even before clicking), otherwise show base price
                          Text(
                                PricingService.formatPrice(
                                  _pricingDetails[_selectedDuration]?['hasDiscount'] == true && !_discountApplied
                                      ? (_pricingDetails[_selectedDuration]?['finalPrice'] as double? ?? _basePrice)
                                      : _trialFee
                                ),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                                  color: _pricingDetails[_selectedDuration]?['hasDiscount'] == true
                                      ? Colors.green[700]  // Always green if discount available
                                      : AppTheme.primaryColor,
                                ),
                              ),
                              // Show savings message if discount available
                              if (_pricingDetails[_selectedDuration]?['hasDiscount'] == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _discountApplied
                                        ? 'You saved ${PricingService.formatPrice(_basePrice - _trialFee)}!'
                                        : 'Save ${PricingService.formatPrice(_basePrice - (_pricingDetails[_selectedDuration]?['finalPrice'] as double? ?? _basePrice))}!',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[700],
                                    ),
                            ),
                          ),
                        ],
                      ),
              ],
                ),
                // Discount button (only show if discount available and not yet applied)
                if (!_discountApplied && _pricingDetails[_selectedDuration]?['hasDiscount'] == true) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _applyDiscount(),
                      icon: const Icon(Icons.local_offer, size: 18),
                      label: Text(
                        'Get Discount',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
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
    final rating = (widget.tutor['rating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = (widget.tutor['total_reviews'] as num?)?.toInt() ?? 0;
    final subjects = TutorService.normalizeTutorSubjects(widget.tutor);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
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
                          color: AppTheme.primaryColor,
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
                      tutorName,
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
                          rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (rating > 0 && totalReviews > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '($totalReviews)',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        if (widget.tutor['is_verified'] == true || widget.tutor['status'] == 'approved') ...[
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
          // Subjects
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: subjects.take(5).map((subject) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subject,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDurationOption(int minutes, String label, String fallbackPrice) {
    final isSelected = _selectedDuration == minutes;
    
    // Get pricing details for this duration
    final details = _pricingDetails[minutes];
    final basePrice = details != null ? (details['basePrice'] as double) : null;
    final finalPrice = details != null ? (details['finalPrice'] as double) : null;
    final hasDiscount = details != null ? (details['hasDiscount'] as bool) : false;
    
    // Determine display price - always use basePrice if available, otherwise fallback
    String displayPrice = fallbackPrice;
    double? actualBasePrice;
    if (basePrice != null) {
      actualBasePrice = basePrice;
      displayPrice = PricingService.formatPrice(basePrice);
    } else {
      // Try to parse fallback price to get numeric value
      try {
        final cleanPrice = fallbackPrice.replaceAll(RegExp(r'[^\d.]'), '');
        actualBasePrice = double.tryParse(cleanPrice);
      } catch (e) {
        // Ignore parsing errors
      }
    }
    
    // Calculate savings if discount exists
    double? savings;
    if (hasDiscount && basePrice != null && finalPrice != null) {
      savings = basePrice - finalPrice;
    }

    return GestureDetector(
      onTap: () {
        safeSetState(() {
          _selectedDuration = minutes;
          _discountApplied = false; // Reset discount when changing duration
          
          // Update both base price and trial fee (always start with base price)
          if (details != null) {
            _basePrice = details['basePrice'] as double;
            _trialFee = details['basePrice'] as double; // Show base price initially
          }
        });
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
            const SizedBox(height: 6),
            // Always show original price (strikethrough) if discount exists, then discounted price
            // Check if there's actually a discount (basePrice > finalPrice) even if flag might be wrong
            if (basePrice != null && finalPrice != null && basePrice > finalPrice) ...[
              // Original price (strikethrough) - always show when discount exists
              Text(
                PricingService.formatPrice(basePrice),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                  decoration: TextDecoration.lineThrough,
                  decorationThickness: 2,
                ),
              ),
              const SizedBox(height: 4),
              // Discounted price (green, larger)
              Text(
                PricingService.formatPrice(finalPrice),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.green[700],
                ),
              ),
              if (savings != null && savings > 0) ...[
                const SizedBox(height: 2),
                Text(
                  'Save ${PricingService.formatPrice(savings)}!',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[600],
                ),
              ),
            ],
            ] else if (basePrice != null) ...[
              // No discount - show regular price
              Text(
                PricingService.formatPrice(basePrice),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
                ),
              ),
            ] else ...[
              // Fallback to displayPrice if basePrice is null
            Text(
              displayPrice,
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
                ),
              ),
            ],
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

  String _formatTime(String time) {
    // Handle already formatted times (e.g., "7:00 PM" or "7:00 PM AM")
    if (time.contains('AM') || time.contains('PM')) {
      // Remove duplicate AM/PM if present
      String cleaned = time.trim();
      if (cleaned.endsWith(' AM AM') || cleaned.endsWith(' PM PM') || 
          cleaned.endsWith(' AM PM') || cleaned.endsWith(' PM AM')) {
        final parts = cleaned.split(' ');
        if (parts.length >= 3) {
          cleaned = '${parts[0]} ${parts[1]}';
        }
      }
      
      // Extract time and AM/PM
      final timeMatch = RegExp(r'(\d{1,2}:\d{2})\s*(AM|PM)').firstMatch(cleaned);
      if (timeMatch != null && timeMatch.groupCount >= 2) {
        return '${timeMatch.group(1)} ${timeMatch.group(2)}';
      }
      return cleaned.trim();
    }
    
    // Handle 24-hour format (e.g., "19:00")
    try {
      final parts = time.split(':');
      if (parts.length < 2) return time;
      
      final hour = int.parse(parts[0]);
      final minute = parts[1].split(' ')[0];
      
      if (hour == 0) return '12:$minute AM';
      if (hour < 12) return '$hour:$minute AM';
      if (hour == 12) return '12:$minute PM';
      return '${hour - 12}:$minute PM';
    } catch (e) {
      return time;
    }
  }

}
