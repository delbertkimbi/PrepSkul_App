import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/auth_service.dart' hide LogService;
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/error_handler_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/core/services/parent_learners_service.dart';
import 'package:prepskul/core/services/transportation_cost_service.dart';
import 'package:prepskul/features/booking/services/booking_service.dart';
import 'package:prepskul/features/booking/services/abandoned_booking_service.dart';
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
  
  // Parent context for multi-learner bookings
  bool _isParent = false;
  List<Map<String, dynamic>> _parentLearners = [];
  bool _parentContextLoaded = false; // Wait for this before showing flow to avoid frequency flash
  Set<String> _selectedLearnerIds = {}; // Selected learner IDs (children + optionally parent)
  bool _hasLevelMismatch = false; // Track if selected learners have different education levels
  
  // Always show "Who is this for?" step for parents (so child selection comes before frequency)
  int get _totalSteps {
    if (!_isParent) return 6;
    return 7; // Always 7 steps for parents: Who is this for? + Frequency + Days + Times + Location + optional Flexible + Review
  }
  
  bool get _shouldShowWhoIsThisFor => _isParent; // Show for all parents, not just 2+ learners

  // Booking data collected through the flow
  int? _selectedFrequency; // Sessions per week
  DateTime? _reviewStepReachedAt; // Track when review step was reached for timing check
  List<String> _selectedDays = []; // e.g., ["Monday", "Wednesday"]
  Map<String, String> _selectedTimes = {}; // e.g., {"Monday": "3:00 PM"}
  String? _selectedLocation; // online, onsite, hybrid
  String? _onsiteAddress;
  String? _locationDescription; // Brief description for onsite/hybrid
  Map<String, String> _sessionLocations = {}; // {"Monday-3:00 PM": "onsite"}
  Map<String, Map<String, String?>> _locationDetails = {}; // {"Monday-3:00 PM": {"address": "...", "coordinates": "..."}}
  String? _selectedPaymentPlan; // monthly, biweekly, weekly
  double? _estimatedTransportationCost; // Estimated transportation cost for onsite sessions

  @override
  void initState() {
    super.initState();
    _prefillFromSurvey();
    _loadParentContext();
  }

  /// Load user type and parent learners for "Who is this for?" step
  Future<void> _loadParentContext() async {
    try {
      final profile = await AuthService.getUserProfile();
      final userType = profile?['user_type'] as String?;
      final isParent = userType == 'parent';
      if (!isParent || !mounted) {
        if (mounted) safeSetState(() => _parentContextLoaded = true);
        return;
      }
      final user = await AuthService.getCurrentUser();
      final parentId = user['userId'] as String?;
      if (parentId == null) {
        if (mounted) safeSetState(() => _parentContextLoaded = true);
        return;
      }
      final list = await ParentLearnersService.getLearners(parentId);
      if (mounted) {
        safeSetState(() {
          _isParent = true;
          _parentLearners = list;
          _parentContextLoaded = true;
        });
      }
    } catch (e) {
      LogService.warning('Could not load parent context: $e');
      if (mounted) safeSetState(() => _parentContextLoaded = true);
    }
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
      final stepOffset = _shouldShowWhoIsThisFor ? 1 : 0;
      final locationStep = 3 + stepOffset;
      if (_currentStep == locationStep && 
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
    
    // Calculate next step - skip flexible session selector if location is not hybrid
    int nextStep = _currentStep + 1;
    final stepOffset = _shouldShowWhoIsThisFor ? 1 : 0;
    final flexibleStep = 4 + stepOffset;
    final reviewStep = 5 + stepOffset;
    final wasSkipping = nextStep == flexibleStep && _selectedLocation != 'hybrid';
    if (wasSkipping) {
      // Skip flexible step if not hybrid, go directly to review
      nextStep = reviewStep;
      LogService.info('📍 Skipping flexible step ($flexibleStep) - location is $_selectedLocation, going to review ($reviewStep)');
    }
    
    if (nextStep < _totalSteps) {
      safeSetState(() {
        _currentStep = nextStep;
        // Track when review step is reached for timing check
        if (nextStep == reviewStep) {
          _reviewStepReachedAt = DateTime.now();
        }
      });
      // Use jumpToPage for immediate navigation when skipping steps to avoid showing empty step
      if (wasSkipping) {
        // Direct jump when skipping flexible step
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
      final stepOffset = _shouldShowWhoIsThisFor ? 1 : 0;
      final flexibleStep = 4 + stepOffset;
      final locationStep = 3 + stepOffset;
      final wasSkipping = prevStep == flexibleStep && _selectedLocation != 'hybrid';
      if (wasSkipping) {
        // Skip flexible step if not hybrid, go back to location
        prevStep = locationStep;
        LogService.info('📍 Skipping flexible step ($flexibleStep) on back - location is $_selectedLocation, going to location ($locationStep)');
      }
      
      safeSetState(() {
        _currentStep = prevStep;
      });
      // Use jumpToPage for immediate navigation when skipping steps to avoid showing empty step
      if (wasSkipping) {
        // Direct jump when skipping flexible step
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
    final stepOffset = _shouldShowWhoIsThisFor ? 1 : 0;
    final flexibleStep = 4 + stepOffset;
    final effectiveSteps = _selectedLocation == 'hybrid' ? _totalSteps : _totalSteps - 1;
    final effectiveStep = _currentStep > flexibleStep && _selectedLocation != 'hybrid' 
        ? _currentStep - 1 
        : _currentStep;
    return (effectiveStep + 1) / effectiveSteps;
  }

  bool _canProceed() {
    // Adjust step index based on whether "Who is this for?" is shown (step 0 = Who when parent)
    final stepOffset = _shouldShowWhoIsThisFor ? -1 : 0;
    final effectiveStep = _currentStep + stepOffset;
    
    switch (effectiveStep) {
      case -1: // Who is this for? (only shown when _shouldShowWhoIsThisFor is true)
        if (!_shouldShowWhoIsThisFor) return true; // Skip validation if not showing
        return _selectedLearnerIds.isNotEmpty; // At least one selection required
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
        if (_sessionLocations.length != _selectedDays.length) return false;
        // If any session is onsite, all onsite sessions must have a non-empty address
        for (final e in _sessionLocations.entries) {
          if (e.value == 'onsite') {
            final addr = _locationDetails[e.key]?['address']?.trim();
            if (addr == null || addr.isEmpty) return false;
          }
        }
        return true;
      case 5: // Review
        // Require payment plan selection AND minimum display time (1-2 seconds)
        if (_selectedPaymentPlan == null) return false;
        if (_reviewStepReachedAt == null) return false; // Haven't reached review step yet
        final timeSinceReview = DateTime.now().difference(_reviewStepReachedAt!);
        return timeSinceReview.inSeconds >= 1; // Require at least 1 second before allowing continue
      default:
        return false;
    }
  }

  /// Build PageView children dynamically based on location selection
  List<Widget> _buildPageViewChildren() {
    final children = <Widget>[];
    
    // Step 0: Who is this for? (only for parents with 2+ learners)
    if (_shouldShowWhoIsThisFor) {
      children.add(_buildWhoIsThisFor());
    }
    
    // Step 1 (or 0 if not showing "Who is this for?"): Frequency Selector
    children.add(
      FrequencySelector(
        tutor: widget.tutor,
        initialFrequency: _selectedFrequency,
        showMultiLearnerHint: _isParent && _parentLearners.length == 1,
        learnerCount: _isParent ? _selectedLearnerIds.length : null, // Pass learner count to adapt pricing
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
    );

    // Step 2 (or 1 if not showing "Who is this for?"): Days Selector
    children.add(
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
    );

    // Step 3 (or 2 if not showing "Who is this for?"): Time Grid Selector
    children.add(
      TimeGridSelector(
        tutor: widget.tutor,
        selectedDays: _selectedDays,
        initialTimes: _selectedTimes,
        onTimesSelected: (times) {
          safeSetState(() => _selectedTimes = times);
        },
      ),
    );

    // Step 4 (or 3 if not showing "Who is this for?"): Location Selector
    children.add(
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
    );

    // Step 5 (or 4 if not showing "Who is this for?"): Flexible Session Location Selector (only shown if hybrid selected)
    children.add(
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
    );

    // Step 6 (or 5 if not showing "Who is this for?"): Booking Review
    children.add(
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
        estimatedTransportationCost: _estimatedTransportationCost,
        learnerCount: _isParent ? _selectedLearnerIds.length : null, // Pass learner count for pricing display
      ),
    );
    
    return children;
  }

  /// Build "Who is this for?" step for parents
  Widget _buildWhoIsThisFor() {
    // Build list of selectable options: children first, then parent last
    final selectableOptions = <Map<String, dynamic>>[];
    
    // Add all children first
    selectableOptions.addAll(_parentLearners.map((learner) => {
      'id': learner['id']?.toString() ?? '',
      'name': learner['name']?.toString() ?? 'Learner',
      'isParent': false,
    }));
    
    // Add parent as an option last (for cases where parent is booking for themselves)
    // This allows parents to book sessions for themselves if needed
    selectableOptions.add({
      'id': 'parent',
      'name': 'Me (Parent)',
      'isParent': true,
    });
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select who will attend these sessions',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can select one or more children',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          
          // Level compatibility message (non-blocking)
          if (_hasLevelMismatch) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The selected children have different education levels. The tutor will adapt the sessions accordingly.',
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
          
          const SizedBox(height: 24),
          
          // List of selectable options (parent + children)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: selectableOptions.length,
            itemBuilder: (context, index) {
              final option = selectableOptions[index];
              final optionId = option['id'] as String;
              final optionName = option['name'] as String;
              final isSelected = _selectedLearnerIds.contains(optionId);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    safeSetState(() {
                      if (isSelected) {
                        _selectedLearnerIds.remove(optionId);
                      } else {
                        _selectedLearnerIds.add(optionId);
                      }
                      // Check for level compatibility after selection (only for children)
                      if (!option['isParent']) {
                        _checkLevelCompatibility();
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Checkbox (rounded square, not circle)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6), // Rounded square
                            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : Colors.grey[400]!,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            optionName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Check if selected learners have different education levels
  void _checkLevelCompatibility() {
    // Filter out 'parent' ID and get only selected children
    final selectedChildIds = _selectedLearnerIds.where((id) => id != 'parent').toList();
    
    if (selectedChildIds.isEmpty || selectedChildIds.length < 2) {
      safeSetState(() {
        _hasLevelMismatch = false;
      });
      return;
    }

    final selectedLearners = _parentLearners
        .where((l) => selectedChildIds.contains(l['id']?.toString()))
        .toList();

    if (selectedLearners.length < 2) {
      safeSetState(() {
        _hasLevelMismatch = false;
      });
      return;
    }

    // Get unique education levels from selected learners
    final educationLevels = selectedLearners
        .map((l) => l['education_level']?.toString() ?? '')
        .where((level) => level.isNotEmpty)
        .toSet();

    // Check if there are different levels
    final hasMismatch = educationLevels.length > 1;

    safeSetState(() {
      _hasLevelMismatch = hasMismatch;
    });
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
      // Calculate pricing with multi-learner discounts if applicable
      final pricing = PricingService.calculateFromTutorData(widget.tutor);
      final perSession = pricing['perSession'] as double;
      final sessionsPerMonth = _selectedFrequency! * 4;
      
      // Apply multi-learner discounts if parent selected multiple children
      List<String>? learnerLabels;
      double monthlyTotal;
      if (_isParent && _selectedLearnerIds.isNotEmpty) {
        // Filter out 'parent' ID and get only selected children
        final selectedChildIds = _selectedLearnerIds.where((id) => id != 'parent').toList();
        final selectedLearners = _parentLearners
            .where((l) => selectedChildIds.contains(l['id']?.toString()))
            .toList();
        
        // Build learner labels: include parent name if selected, then children names
        final labels = <String>[];
        if (_selectedLearnerIds.contains('parent')) {
          final userProfile = await AuthService.getUserProfile();
          final parentName = userProfile?['full_name'] as String? ?? 'Parent';
          labels.add(parentName);
        }
        labels.addAll(selectedLearners.map((l) => l['name']?.toString() ?? 'Learner'));
        
        // Count total learners (parent + children)
        final totalLearnerCount = labels.length;
        
        // Only set learnerLabels if multiple learners (parent + children or multiple children)
        if (totalLearnerCount > 1) {
          learnerLabels = labels;
          
          // Calculate total with multi-learner discounts
          final baseMonthlyTotal = perSession * sessionsPerMonth;
          monthlyTotal = await PricingService.calculateMultiLearnerMonthlyTotal(
            baseMonthlyTotal: baseMonthlyTotal,
            learnerCount: totalLearnerCount,
          );
        } else {
          // Single learner - no discount
          monthlyTotal = perSession * sessionsPerMonth;
        }
      } else {
        // Student or parent booking for themselves - no discount
        monthlyTotal = perSession * sessionsPerMonth;
      }

      // Use pre-calculated transportation cost (calculated when location was selected)
      // If not calculated yet, calculate now
      double? estimatedTransportationCost = _estimatedTransportationCost;
      if (estimatedTransportationCost == null && (_selectedLocation == 'onsite' || _selectedLocation == 'hybrid')) {
        if (_selectedLocation == 'onsite' && _onsiteAddress != null && _onsiteAddress!.isNotEmpty) {
          // Single onsite address - calculate once
          final tutorHomeAddress = widget.tutor['home_address'] as String?;
          final tutorCity = widget.tutor['city'] as String?;
          
          estimatedTransportationCost = await TransportationCostService.calculateTransportationCost(
            tutorHomeAddress: tutorHomeAddress,
            onsiteAddress: _onsiteAddress!,
            tutorCity: tutorCity,
          );
        } else if (_selectedLocation == 'hybrid' && _locationDetails.isNotEmpty) {
          // Hybrid: Calculate for each onsite session, then average
          // For now, use first onsite address as estimate (will be recalculated per session)
          String? firstOnsiteAddress;
          for (final detail in _locationDetails.values) {
            final sessionLocation = detail['location'] as String?;
            if (sessionLocation == 'onsite') {
              firstOnsiteAddress = detail['address'] as String?;
              if (firstOnsiteAddress != null && firstOnsiteAddress.isNotEmpty) {
                break;
              }
            }
          }
          
          if (firstOnsiteAddress != null && firstOnsiteAddress.isNotEmpty) {
            final tutorHomeAddress = widget.tutor['home_address'] as String?;
            final tutorCity = widget.tutor['city'] as String?;
            
            estimatedTransportationCost = await TransportationCostService.calculateTransportationCost(
              tutorHomeAddress: tutorHomeAddress,
              onsiteAddress: firstOnsiteAddress,
              tutorCity: tutorCity,
            );
          }
        }
      }

      // Create booking request in database
      final tutorId = widget.tutor['user_id'] ?? widget.tutor['id'];
      await BookingService.createBookingRequest(
        tutorId: tutorId,
        frequency: _selectedFrequency!,
        days: _selectedDays,
        times: _selectedTimes,
        location: _selectedLocation!,
        address: _onsiteAddress,
        locationDescription: _locationDescription,
        paymentPlan: _selectedPaymentPlan!,
        monthlyTotal: monthlyTotal,
        learnerLabels: learnerLabels,
        estimatedTransportationCost: estimatedTransportationCost,
        sessionLocations: _selectedLocation == 'hybrid' ? _sessionLocations : null,
        locationDetails: _selectedLocation == 'hybrid' ? _locationDetails : null,
      );

      // Mark abandoned booking as completed
      try {
        final user = await AuthService.getCurrentUser();
        final userId = user['userId'] as String?;
        if (userId != null && tutorId != null) {
          await AbandonedBookingService.markAsCompleted(
            userId: userId,
            tutorId: tutorId.toString(),
            bookingType: 'normal',
          );
        }
      } catch (e) {
        // Silently fail - marking as completed is not critical
      }

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
        bottom: _parentContextLoaded
            ? PreferredSize(
                preferredSize: const Size.fromHeight(8),
                child: LinearProgressIndicator(
                  value: _getProgressValue(),
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              )
            : null,
      ),
      body: _parentContextLoaded
          ? PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: _buildPageViewChildren(),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Loading…',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _parentContextLoaded
          ? Container(
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
      )
          : null,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}