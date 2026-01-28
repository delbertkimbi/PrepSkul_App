import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/auth_service.dart' hide LogService;
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/error_handler_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/features/booking/services/booking_service.dart';
import 'package:prepskul/features/booking/widgets/frequency_selector.dart';
import 'package:prepskul/features/booking/widgets/days_selector.dart';
import 'package:prepskul/features/booking/widgets/time_grid_selector.dart';
import 'package:prepskul/features/booking/widgets/location_selector.dart';
import 'package:prepskul/features/booking/widgets/flexible_session_location_selector.dart';
import 'package:prepskul/features/booking/widgets/booking_review.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';

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
  final int _totalSteps = 6;

  // Booking data collected through the flow
  int? _selectedFrequency; // Sessions per week
  List<String> _selectedDays = []; // e.g., ["Monday", "Wednesday"]
  Map<String, String> _selectedTimes = {}; // e.g., {"Monday": "3:00 PM"}
  String? _selectedLocation; // online, onsite, hybrid
  String? _onsiteAddress;
  String? _locationDescription; // Brief description for onsite/hybrid
  Map<String, String> _sessionLocations = {}; // {"Monday-3:00 PM": "onsite"}
  Map<String, Map<String, String?>> _locationDetails = {}; // {"Monday-3:00 PM": {"address": "...", "coordinates": "..."}}
  String? _selectedPaymentPlan; // monthly, biweekly, weekly

  @override
  void initState() {
    super.initState();
    _prefillFromSurvey();
  }

  /// Pre-fill data from survey if available
  Future<void> _prefillFromSurvey() async {
    // First try to use passed survey data
    if (widget.surveyData != null) {
      _applyPrefillData(widget.surveyData!);
      return;
    }

    // Otherwise fetch from database
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
          _applyPrefillData(surveyData!);
        });
      }
    } catch (e) {
      LogService.warning('Could not load survey data for prefill', e);
    }
  }

  /// Apply survey data to prefill booking form
  void _applyPrefillData(Map<String, dynamic> survey) {
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
      final street = survey['street'] != null ? ', ${survey['street']}' : '';
      _onsiteAddress = '${survey['city']}, ${survey['quarter']}$street';
      LogService.success('Pre-filled address', _onsiteAddress);
    }

    // Pre-fill location description if available
    if (survey['location_description'] != null) {
      _locationDescription = survey['location_description'] as String;
    } else if (survey['additional_address_info'] != null) {
      _locationDescription = survey['additional_address_info'] as String;
    }
  }

  void _nextStep() {
    // Validate current step before proceeding
    if (!_canProceed()) {
      // Show error message for location step if address is missing
      if (_currentStep == 3 && 
          _selectedLocation == 'onsite' &&
          (_onsiteAddress == null || _onsiteAddress!.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter your address to continue with onsite sessions',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // Calculate next step - skip step 4 (flexible session selector) if location is not hybrid
    int nextStep = _currentStep + 1;
    final wasSkipping = nextStep == 4 && _selectedLocation != 'hybrid';
    if (wasSkipping) {
      // Skip flexible step (4) if not hybrid, go directly to review (5)
      nextStep = 5;
      LogService.info('📍 Skipping flexible step (4) - location is $_selectedLocation, going to review (5)');
    }
    
    if (nextStep < _totalSteps) {
      safeSetState(() {
        _currentStep = nextStep;
      });
      // Use jumpToPage for immediate navigation when skipping steps to avoid showing empty step 4
      if (wasSkipping) {
        // Direct jump when skipping from step 3 to 5
        _pageController.jumpToPage(nextStep);
      } else {
        _pageController.animateToPage(
          nextStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      // Calculate previous step - skip flexible step if not hybrid
      int prevStep = _currentStep - 1;
      final wasSkipping = prevStep == 4 && _selectedLocation != 'hybrid';
      if (wasSkipping) {
        // Skip flexible step (4) if not hybrid, go back to location (3)
        prevStep = 3;
        LogService.info('📍 Skipping flexible step (4) on back - location is $_selectedLocation, going to location (3)');
      }
      
      safeSetState(() {
        _currentStep = prevStep;
      });
      // Use jumpToPage for immediate navigation when skipping steps to avoid showing empty step 4
      if (wasSkipping) {
        // Direct jump when skipping from step 5 to 3
        _pageController.jumpToPage(prevStep);
      } else {
        _pageController.animateToPage(
          prevStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  double _getProgressValue() {
    // Adjust progress to account for skipped flexible step
    final effectiveSteps = _selectedLocation == 'hybrid' ? _totalSteps : _totalSteps - 1;
    final effectiveStep = _currentStep > 4 && _selectedLocation != 'hybrid' 
        ? _currentStep - 1 
        : _currentStep;
    return (effectiveStep + 1) / effectiveSteps;
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
        if (_selectedLocation == null) return false;
        // Only onsite requires address (hybrid/flexible doesn't need address upfront)
        if (_selectedLocation == 'onsite') {
          return _onsiteAddress != null && _onsiteAddress!.trim().isNotEmpty;
        }
        // For online or hybrid/flexible, no address needed upfront
        return true;
      case 4: // Flexible Session Location Selector (only for hybrid)
        if (_selectedLocation != 'hybrid') return true; // Skip validation if not hybrid
        return _sessionLocations.length == _selectedDays.length;
      case 5: // Review
        return _selectedPaymentPlan != null;
      default:
        return false;
    }
  }

  /// Build PageView children dynamically based on location selection
  List<Widget> _buildPageViewChildren() {
    return [
      // Step 0: Frequency Selector
      FrequencySelector(
        tutor: widget.tutor,
        initialFrequency: _selectedFrequency,
        onFrequencySelected: (frequency) {
          safeSetState(() {
            _selectedFrequency = frequency;
            // Reset days/times if frequency changes
            if (_selectedDays.length > frequency) {
              _selectedDays = _selectedDays.take(frequency).toList();
              _selectedTimes.clear();
            }
          });
        },
      ),

      // Step 1: Days Selector
      DaysSelector(
        tutor: widget.tutor,
        requiredDays: _selectedFrequency ?? 1,
        initialDays: _selectedDays,
        onDaysSelected: (days) {
          safeSetState(() {
            _selectedDays = days;
            // Clear times for days that were removed
            _selectedTimes.removeWhere((day, time) => !days.contains(day));
          });
        },
      ),

      // Step 2: Time Grid Selector
      TimeGridSelector(
        tutor: widget.tutor,
        selectedDays: _selectedDays,
        initialTimes: _selectedTimes,
        onTimesSelected: (times) {
          safeSetState(() => _selectedTimes = times);
        },
      ),

      // Step 3: Location Selector
      LocationSelector(
        tutor: widget.tutor,
        initialLocation: _selectedLocation,
        initialAddress: _onsiteAddress,
        initialLocationDescription: _locationDescription,
        onLocationSelected: (location, address, locationDescription) {
          safeSetState(() {
            _selectedLocation = location;
            _onsiteAddress = address;
            _locationDescription = locationDescription;
            // If not hybrid, clear session locations
            if (location != 'hybrid') {
              _sessionLocations.clear();
              _locationDetails.clear();
            }
          });
        },
      ),

      // Step 4: Flexible Session Location Selector (only shown if hybrid selected)
      _selectedLocation == 'hybrid'
          ? FlexibleSessionLocationSelector(
              selectedDays: _selectedDays,
              selectedTimes: _selectedTimes,
              initialSessionLocations: _sessionLocations,
              initialLocationDetails: _locationDetails,
              onLocationsSelected: (sessionLocations, locationDetails) {
                safeSetState(() {
                  _sessionLocations = sessionLocations;
                  _locationDetails = locationDetails;
                });
              },
            )
          : Container(
              // Empty container for non-hybrid - navigation will skip this step
              // This should never be visible as navigation skips this step
              color: Colors.white,
              child: Center(
                child: Text(
                  'Loading review...',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),

      // Step 5: Booking Review
      BookingReview(
        tutor: widget.tutor,
        frequency: _selectedFrequency ?? 1,
        selectedDays: _selectedDays,
        selectedTimes: _selectedTimes,
        location: _selectedLocation ?? 'online',
        address: _onsiteAddress,
        locationDescription: _locationDescription,
        sessionLocations: _sessionLocations,
        locationDetails: _locationDetails,
        initialPaymentPlan: _selectedPaymentPlan,
        onPaymentPlanSelected: (plan) {
          safeSetState(() => _selectedPaymentPlan = plan);
        },
      ),
    ];
  }

  Future<void> _submitBookingRequest() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
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
                'Sending request...',
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
      // Calculate pricing
      final pricing = PricingService.calculateFromTutorData(widget.tutor);
      final perSession = pricing['perSession'] as double;
      final sessionsPerMonth = _selectedFrequency! * 4;
      final monthlyTotal = perSession * sessionsPerMonth;

      // Create booking request in database
      await BookingService.createBookingRequest(
        tutorId: widget.tutor['user_id'] ?? widget.tutor['id'],
        frequency: _selectedFrequency!,
        days: _selectedDays,
        times: _selectedTimes,
        location: _selectedLocation!,
        address: _onsiteAddress,
        locationDescription: _locationDescription,
        paymentPlan: _selectedPaymentPlan!,
        monthlyTotal: monthlyTotal,
      );

      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      // Show success
      _showSuccessDialog();
    } catch (e) {
      LogService.error('Error creating booking request', e);
      // Error details logged in LogService.error above
      // Stack trace logged in LogService.error above

      if (!mounted) return;
      Navigator.pop(context);

      // Check if this is an existing booking request error
      final errorString = e.toString();
      if (errorString.contains('EXISTING_BOOKING_REQUEST')) {
        // Extract request ID from error message
        final requestIdMatch = RegExp(r'requestId=([a-f0-9-]+)').firstMatch(errorString);
        final requestId = requestIdMatch?.group(1);
        
        // Extract message (everything after the second colon)
        final messageMatch = RegExp(r'EXISTING_BOOKING_REQUEST:requestId=[^:]+:(.+)').firstMatch(errorString);
        final message = messageMatch?.group(1) ?? 'You already have an existing booking with this tutor.';
        
        _showExistingBookingDialog(message, requestId);
      } else {
        // Use ErrorHandlerService for other errors
        ErrorHandlerService.showError(
          context,
          e,
          'Failed to send booking request. Please try again.',
        );
      }
    }
  }

  void _showExistingBookingDialog(String message, String? requestId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Existing Booking',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 12,
            height: 1.5,
            color: Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (requestId != null)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close booking flow screen
                
                // Navigate to student navigation with requests tab and highlight the request
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/student-nav',
                    (route) => false,
                    arguments: {
                      'initialTab': 2, // Requests tab
                      'highlightRequestId': requestId, // Highlight this request
                    },
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'View Session',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
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
              padding: const EdgeInsets.all(14),
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
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your booking request has been sent to ${widget.tutor['full_name']}!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
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
                  Navigator.pop(context); // Close booking flow

                  // Navigate to MainNavigation with Requests tab (index 2)
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/student-nav',
                    (route) => false,
                    arguments: {'initialTab': 2}, // Tab 2 = Requests
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'View My Requests',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: LinearProgressIndicator(
            value: _getProgressValue(),
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe
        children: _buildPageViewChildren(),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(18),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Back',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
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
                      fontSize: 12,
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