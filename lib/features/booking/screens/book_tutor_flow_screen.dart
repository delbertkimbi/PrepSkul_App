import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/features/booking/widgets/frequency_selector.dart';
import 'package:prepskul/features/booking/widgets/days_selector.dart';
import 'package:prepskul/features/booking/widgets/time_grid_selector.dart';
import 'package:prepskul/features/booking/widgets/location_selector.dart';
import 'package:prepskul/features/booking/widgets/booking_review.dart';

/// Multi-step wizard for booking a tutor for recurring sessions
///
/// Flow:
/// 1. Session Frequency (1x, 2x, 3x per week)
/// 2. Days Selection (which days work best)
/// 3. Time Selection (specific times per day)
/// 4. Location Preference (online/onsite/hybrid)
/// 5. Review & Payment Plan (summary and payment options)
class BookTutorFlowScreen extends StatefulWidget {
  final Map<String, dynamic> tutor;
  final Map<String, dynamic>? surveyData; // For smart prefilling

  const BookTutorFlowScreen({Key? key, required this.tutor, this.surveyData})
    : super(key: key);

  @override
  State<BookTutorFlowScreen> createState() => _BookTutorFlowScreenState();
}

class _BookTutorFlowScreenState extends State<BookTutorFlowScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Booking data collected through the flow
  int? _selectedFrequency; // Sessions per week
  List<String> _selectedDays = []; // e.g., ["Monday", "Wednesday"]
  Map<String, String> _selectedTimes = {}; // e.g., {"Monday": "3:00 PM"}
  String? _selectedLocation; // online, onsite, hybrid
  String? _onsiteAddress;
  String? _selectedPaymentPlan; // monthly, biweekly, weekly

  @override
  void initState() {
    super.initState();
    _prefillFromSurvey();
  }

  /// Pre-fill data from survey if available
  void _prefillFromSurvey() {
    if (widget.surveyData == null) return;

    final survey = widget.surveyData!;

    // Pre-fill frequency
    if (survey['preferred_session_frequency'] != null) {
      _selectedFrequency = survey['preferred_session_frequency'] as int;
    }

    // Pre-fill days
    if (survey['preferred_schedule'] != null) {
      final schedule = survey['preferred_schedule'];
      if (schedule is Map && schedule['days'] != null) {
        _selectedDays = List<String>.from(schedule['days']);
      }
    }

    // Pre-fill location
    if (survey['preferred_location'] != null) {
      _selectedLocation = survey['preferred_location'] as String;
    }

    // Pre-fill address (if onsite)
    if (survey['city'] != null && survey['quarter'] != null) {
      _onsiteAddress = '${survey['city']}, ${survey['quarter']}';
    }
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
      case 0: // Frequency
        return _selectedFrequency != null;
      case 1: // Days
        return _selectedDays.isNotEmpty &&
            _selectedDays.length == _selectedFrequency;
      case 2: // Times
        return _selectedTimes.length == _selectedDays.length;
      case 3: // Location
        return _selectedLocation != null &&
            (_selectedLocation != 'onsite' || _onsiteAddress != null);
      case 4: // Review
        return _selectedPaymentPlan != null;
      default:
        return false;
    }
  }

  Future<void> _submitBookingRequest() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // TODO: Save to database
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      // Show success
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
              'Request Sent!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your booking request has been sent to ${widget.tutor['full_name']}!',
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
                  Navigator.pop(context); // Go back to tutor detail
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Done',
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (_currentStep > 0) {
              _previousStep();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Book Regular Sessions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe
        children: [
          // Step 1: Frequency Selector
          FrequencySelector(
            tutor: widget.tutor,
            initialFrequency: _selectedFrequency,
            onFrequencySelected: (frequency) {
              setState(() {
                _selectedFrequency = frequency;
                // Reset days/times if frequency changes
                if (_selectedDays.length > frequency) {
                  _selectedDays = _selectedDays.take(frequency).toList();
                  _selectedTimes.clear();
                }
              });
            },
          ),

          // Step 2: Days Selector
          DaysSelector(
            tutor: widget.tutor,
            requiredDays: _selectedFrequency ?? 1,
            initialDays: _selectedDays,
            onDaysSelected: (days) {
              setState(() {
                _selectedDays = days;
                // Clear times for days that were removed
                _selectedTimes.removeWhere((day, time) => !days.contains(day));
              });
            },
          ),

          // Step 3: Time Grid Selector
          TimeGridSelector(
            tutor: widget.tutor,
            selectedDays: _selectedDays,
            initialTimes: _selectedTimes,
            onTimesSelected: (times) {
              setState(() => _selectedTimes = times);
            },
          ),

          // Step 4: Location Selector
          LocationSelector(
            tutor: widget.tutor,
            initialLocation: _selectedLocation,
            initialAddress: _onsiteAddress,
            onLocationSelected: (location, address) {
              setState(() {
                _selectedLocation = location;
                _onsiteAddress = address;
              });
            },
          ),

          // Step 5: Booking Review
          BookingReview(
            tutor: widget.tutor,
            frequency: _selectedFrequency ?? 1,
            selectedDays: _selectedDays,
            selectedTimes: _selectedTimes,
            location: _selectedLocation ?? 'online',
            address: _onsiteAddress,
            initialPaymentPlan: _selectedPaymentPlan,
            onPaymentPlanSelected: (plan) {
              setState(() => _selectedPaymentPlan = plan);
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
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
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousStep,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                            ? _submitBookingRequest
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
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
