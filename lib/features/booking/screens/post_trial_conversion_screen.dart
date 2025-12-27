import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:prepskul/features/booking/services/booking_service.dart';
import 'package:prepskul/features/booking/services/trial_session_service.dart' hide LogService;
import 'package:prepskul/features/booking/widgets/location_selector.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/core/services/error_handler_service.dart';

/// Post-Trial Conversion Screen
///
/// Allows students to convert a completed trial session into a recurring booking
/// Pre-fills data from the trial session

class PostTrialConversionScreen extends StatefulWidget {
  final TrialSession trialSession;
  final Map<String, dynamic> tutor;

  const PostTrialConversionScreen({
    Key? key,
    required this.trialSession,
    required this.tutor,
  }) : super(key: key);

  @override
  State<PostTrialConversionScreen> createState() =>
      _PostTrialConversionScreenState();
}

class _PostTrialConversionScreenState extends State<PostTrialConversionScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Pre-filled from trial
  int _selectedFrequency = 2; // Default: 2x per week
  List<String> _selectedDays = [];
  Map<String, String> _selectedTimes = {};
  String _selectedLocation = 'online';
  String? _onsiteAddress;
  String? _locationDescription;
  String? _selectedPaymentPlan;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _prefillFromTrial();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Pre-fill data from trial session
  void _prefillFromTrial() {
    safeSetState(() {
      // Use trial location
      _selectedLocation = widget.trialSession.location;

      // Default to 2x per week (can be changed)
      _selectedFrequency = 2;

      // Pre-fill the day and time from trial
      final trialDay = _getDayName(widget.trialSession.scheduledDate);
      _selectedDays = [trialDay];
      _selectedTimes = {trialDay: widget.trialSession.scheduledTime};
    });
  }

  /// Get day name from date
  String _getDayName(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[date.weekday - 1];
  }

  /// Navigate to next step
  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      safeSetState(() {
        _currentStep++;
      });
    }
  }

  /// Navigate to previous step
  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      safeSetState(() {
        _currentStep--;
      });
    }
  }

  /// Submit conversion request
  Future<void> _submitConversion() async {
    if (_selectedPaymentPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a payment plan',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    safeSetState(() {
      _isSubmitting = true;
    });

    try {
      // Calculate pricing
      final pricing = PricingService.calculateFromTutorData(widget.tutor);
      final perSession = pricing['perSession'] as double;
      final sessionsPerMonth = _selectedFrequency * 4;
      final monthlyTotal = perSession * sessionsPerMonth;

      // Create booking request
      await BookingService.createBookingRequest(
        tutorId: widget.tutor['user_id'] ?? widget.tutor['id'],
        frequency: _selectedFrequency,
        days: _selectedDays,
        times: _selectedTimes,
        location: _selectedLocation,
        address: _onsiteAddress,
        locationDescription: _locationDescription,
        paymentPlan: _selectedPaymentPlan!,
        monthlyTotal: monthlyTotal,
      );

      // Mark trial as converted
      await TrialSessionService.markAsConverted(
        widget.trialSession.id,
        '', // Will be updated when booking is approved
      );

      if (!mounted) return;

      // Show success and navigate
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Booking request sent! The tutor will review and approve.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      safeSetState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Convert to Regular Booking',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),

          // Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1Frequency(),
                _buildStep2Days(),
                _buildStep3Location(),
                _buildStep4Review(),
              ],
            ),
          ),

          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: List.generate(_totalSteps, (index) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: index <= _currentStep
                    ? AppTheme.primaryColor
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1Frequency() {
    final pricing = PricingService.calculateFromTutorData(widget.tutor);
    final perSession = pricing['perSession'] as double;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How often would you like sessions?',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on your trial session',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // Frequency options
          ...[1, 2, 3, 4].map((freq) {
            final sessionsPerMonth = freq * 4;
            final monthlyTotal = perSession * sessionsPerMonth;
            final isSelected = _selectedFrequency == freq;

            return GestureDetector(
              onTap: () => safeSetState(() => _selectedFrequency = freq),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey[400]!,
                          width: 2,
                        ),
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${freq}x per week',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${monthlyTotal.toStringAsFixed(0)} XAF per month',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStep2Days() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select session days',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose at least ${_selectedFrequency} day(s)',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // Day selection grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: days.map((day) {
              final isSelected = _selectedDays.contains(day);
              final hasTime = _selectedTimes.containsKey(day);

              return GestureDetector(
                onTap: () {
                  safeSetState(() {
                    if (isSelected) {
                      _selectedDays.remove(day);
                      _selectedTimes.remove(day);
                    } else {
                      if (_selectedDays.length < _selectedFrequency) {
                        _selectedDays.add(day);
                        // Pre-fill time from trial if it's the same day
                        if (day ==
                            _getDayName(widget.trialSession.scheduledDate)) {
                          _selectedTimes[day] =
                              widget.trialSession.scheduledTime;
                        } else {
                          _selectedTimes[day] =
                              widget.trialSession.scheduledTime;
                        }
                      }
                    }
                  });
                },
                child: Container(
                  width: (MediaQuery.of(context).size.width - 64) / 3,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        day.substring(0, 3),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.black,
                        ),
                      ),
                      if (hasTime) ...[
                        const SizedBox(height: 4),
                        Text(
                          _selectedTimes[day]!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Location() {
    return LocationSelector(
      tutor: widget.tutor,
      initialLocation: _selectedLocation,
      initialAddress: _onsiteAddress,
      initialLocationDescription: _locationDescription,
      onLocationSelected: (location, address, locationDescription) {
        safeSetState(() {
          _selectedLocation = location;
          _onsiteAddress = address;
          _locationDescription = locationDescription;
        });
      },
    );
  }

  Widget _buildStep4Review() {
    final pricing = PricingService.calculateFromTutorData(widget.tutor);
    final perSession = pricing['perSession'] as double;
    final sessionsPerMonth = _selectedFrequency * 4;
    final monthlyTotal = perSession * sessionsPerMonth;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Payment Plan',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 32),

          // Summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryRow('Subject', widget.trialSession.subject),
                _buildSummaryRow(
                  'Frequency',
                  '${_selectedFrequency}x per week',
                ),
                _buildSummaryRow('Days', _selectedDays.join(', ')),
                _buildSummaryRow('Location', _selectedLocation.toUpperCase()),
                const Divider(height: 32),
                _buildSummaryRow(
                  'Per session',
                  '${perSession.toStringAsFixed(0)} XAF',
                ),
                _buildSummaryRow(
                  'Monthly total',
                  '${monthlyTotal.toStringAsFixed(0)} XAF',
                  isTotal: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Payment plan selection
          Text(
            'Payment Plan',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          ...['monthly', 'biweekly', 'weekly'].map((plan) {
            final isSelected = _selectedPaymentPlan == plan;
            final planAmount = plan == 'monthly'
                ? monthlyTotal
                : plan == 'biweekly'
                ? monthlyTotal / 2
                : monthlyTotal / 4;

            return GestureDetector(
              onTap: () => safeSetState(() => _selectedPaymentPlan = plan),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey[400]!,
                          width: 2,
                        ),
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        plan.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Text(
                      '${planAmount.toStringAsFixed(0)} XAF',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 20 : 14,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: isTotal ? AppTheme.primaryColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
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
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Back',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _currentStep == _totalSteps - 1
                  ? (_isSubmitting ? null : _submitConversion)
                  : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _currentStep == _totalSteps - 1
                          ? 'Submit Request'
                          : 'Next',
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
    );
  }
}
