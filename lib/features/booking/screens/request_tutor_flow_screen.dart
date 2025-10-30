import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/features/booking/services/tutor_request_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Request Tutor Flow Screen
///
/// Multi-step form to request a tutor that's not available on the platform
/// Sends notification to PrepSkul team via WhatsApp and creates a trackable request
class RequestTutorFlowScreen extends StatefulWidget {
  final Map<String, dynamic>? prefillData; // From search/filters

  const RequestTutorFlowScreen({Key? key, this.prefillData}) : super(key: key);

  @override
  State<RequestTutorFlowScreen> createState() => _RequestTutorFlowScreenState();
}

class _RequestTutorFlowScreenState extends State<RequestTutorFlowScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Step 1: Subject & Level
  List<String> _selectedSubjects = [];
  String? _educationLevel;
  final TextEditingController _requirementsController = TextEditingController();

  // Step 2: Tutor Preferences
  String? _tutorGender;
  String? _tutorQualification;
  String? _teachingMode; // online, onsite, hybrid
  int _minBudget = 2500;
  int _maxBudget = 15000;

  // Step 3: Schedule & Location
  List<String> _preferredDays = [];
  String? _preferredTime;
  String? _location;
  final TextEditingController _locationController = TextEditingController();

  // Step 4: Additional Details
  final TextEditingController _additionalNotesController = TextEditingController();
  String _urgency = 'normal'; // urgent, normal, flexible

  @override
  void initState() {
    super.initState();
    _prefillFromData();
  }

  @override
  void dispose() {
    _requirementsController.dispose();
    _locationController.dispose();
    _additionalNotesController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Pre-fill data from search filters or survey
  Future<void> _prefillFromData() async {
    if (widget.prefillData != null) {
      setState(() {
        _selectedSubjects = List<String>.from(
          widget.prefillData!['subjects'] ?? [],
        );
        _educationLevel = widget.prefillData!['education_level'];
        _teachingMode = widget.prefillData!['teaching_mode'];
        _location = widget.prefillData!['location'];
        if (_location != null) {
          _locationController.text = _location!;
        }
      });
    } else {
      // Try to pre-fill from survey
      try {
        final userProfile = await AuthService.getUserProfile();
        final userType = userProfile?['user_type'];
        
        Map<String, dynamic>? surveyData;
        if (userType == 'student') {
          surveyData = await SurveyRepository.getStudentSurvey(
            userProfile?['id'],
          );
        } else if (userType == 'parent') {
          surveyData = await SurveyRepository.getParentSurvey(
            userProfile?['id'],
          );
        }

        if (surveyData != null && mounted) {
          setState(() {
            _selectedSubjects = List<String>.from(
              surveyData!['subjects'] ?? [],
            );
            _educationLevel = surveyData['education_level'];
            _minBudget = surveyData['budget_min'] ?? 2500;
            _maxBudget = surveyData['budget_max'] ?? 15000;
            _tutorGender = surveyData['tutor_gender_preference'];
            _tutorQualification = surveyData['tutor_qualification_preference'];
            _teachingMode = surveyData['preferred_location'];
            
            if (surveyData['city'] != null && surveyData['quarter'] != null) {
              _location = '${surveyData['city']}, ${surveyData['quarter']}';
              _locationController.text = _location!;
            }
          });
        }
      } catch (e) {
        print('Error prefilling from survey: $e');
      }
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
      case 0: // Subject & Level
        return _selectedSubjects.isNotEmpty && _educationLevel != null;
      case 1: // Preferences
        return _teachingMode != null;
      case 2: // Schedule & Location
        return _preferredDays.isNotEmpty && 
               _preferredTime != null && 
               _locationController.text.isNotEmpty;
      case 3: // Review
        return true;
      default:
        return false;
    }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request a Tutor',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: List.generate(_totalSteps, (index) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(
                      right: index < _totalSteps - 1 ? 8 : 0,
                    ),
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
          ),

          // Page view
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentStep = index),
              children: [
                _buildStep1SubjectLevel(),
                _buildStep2Preferences(),
                _buildStep3ScheduleLocation(),
                _buildStep4Review(),
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
                            ? _submitRequest
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
                          ? 'Submit Request'
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

  Widget _buildStep1SubjectLevel() {
    final subjects = [
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
      'English',
      'French',
      'Computer Science',
      'Economics',
      'Geography',
      'History',
    ];

    final levels = [
      'Primary School',
      'Form 1-3',
      'Form 4-5 (O-Level)',
      'Lower Sixth',
      'Upper Sixth (A-Level)',
      'University',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What subject do you need help with?',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select all subjects you need tutoring for',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 24),

          // Subjects
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: subjects.map((subject) {
              final isSelected = _selectedSubjects.contains(subject);
              return FilterChip(
                selected: isSelected,
                label: Text(subject),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSubjects.add(subject);
                    } else {
                      _selectedSubjects.remove(subject);
                    }
                  });
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                checkmarkColor: AppTheme.primaryColor,
                labelStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Education Level
          Text(
            'Education Level',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          ...levels.map((level) {
            return RadioListTile<String>(
              value: level,
              groupValue: _educationLevel,
              onChanged: (value) => setState(() => _educationLevel = value),
              title: Text(
                level,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              activeColor: AppTheme.primaryColor,
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
          const SizedBox(height: 24),

          // Specific Requirements
          Text(
            'Specific Requirements (Optional)',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _requirementsController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g., Need help preparing for GCE exams...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Preferences() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tutor Preferences',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help us find the perfect match for you',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 32),

          // Teaching Mode
          _buildSectionTitle('Teaching Mode *'),
          const SizedBox(height: 12),
          _buildOptionCard(
            icon: Icons.laptop_mac,
            title: 'Online',
            subtitle: 'Virtual sessions via video call',
            isSelected: _teachingMode == 'online',
            onTap: () => setState(() => _teachingMode = 'online'),
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            icon: Icons.home,
            title: 'Onsite',
            subtitle: 'In-person at your location',
            isSelected: _teachingMode == 'onsite',
            onTap: () => setState(() => _teachingMode = 'onsite'),
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            icon: Icons.sync_alt,
            title: 'Hybrid',
            subtitle: 'Mix of online and onsite',
            isSelected: _teachingMode == 'hybrid',
            onTap: () => setState(() => _teachingMode = 'hybrid'),
          ),
          const SizedBox(height: 32),

          // Budget Range
          _buildSectionTitle('Budget Range'),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${_minBudget.toInt()} XAF',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Spacer(),
              Text(
                '${_maxBudget.toInt()} XAF',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          RangeSlider(
            values: RangeValues(_minBudget.toDouble(), _maxBudget.toDouble()),
            min: 2000,
            max: 20000,
            divisions: 36,
            activeColor: AppTheme.primaryColor,
            onChanged: (values) {
              setState(() {
                _minBudget = values.start.toInt();
                _maxBudget = values.end.toInt();
              });
            },
          ),
          const SizedBox(height: 24),

          // Gender Preference
          _buildSectionTitle('Gender Preference (Optional)'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: ['Male', 'Female', 'No Preference'].map((gender) {
              final isSelected = _tutorGender == gender;
              return ChoiceChip(
                label: Text(gender),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _tutorGender = selected ? gender : null);
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Qualification
          _buildSectionTitle('Tutor Qualification (Optional)'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ['Student Tutor', 'Graduate', 'Professional', 'No Preference']
                .map((qual) {
              final isSelected = _tutorQualification == qual;
              return ChoiceChip(
                label: Text(qual),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _tutorQualification = selected ? qual : null);
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3ScheduleLocation() {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final times = [
      'Morning (6AM - 12PM)',
      'Afternoon (12PM - 6PM)',
      'Evening (6PM - 10PM)',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule & Location',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When and where would you like the sessions?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 32),

          // Preferred Days
          _buildSectionTitle('Preferred Days *'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: days.map((day) {
              final isSelected = _preferredDays.contains(day);
              return FilterChip(
                selected: isSelected,
                label: Text(day),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _preferredDays.add(day);
                    } else {
                      _preferredDays.remove(day);
                    }
                  });
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                checkmarkColor: AppTheme.primaryColor,
                labelStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textDark,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Preferred Time
          _buildSectionTitle('Preferred Time *'),
          const SizedBox(height: 12),
          ...times.map((time) {
            return RadioListTile<String>(
              value: time,
              groupValue: _preferredTime,
              onChanged: (value) => setState(() => _preferredTime = value),
              title: Text(
                time,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              activeColor: AppTheme.primaryColor,
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
          const SizedBox(height: 32),

          // Location
          _buildSectionTitle('Location *'),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              hintText: 'e.g., Yaoundé, Bastos',
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              prefixIcon: Icon(Icons.location_on, color: AppTheme.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Review() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Your Request',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure everything looks good',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 32),

          // Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewItem('Subjects', _selectedSubjects.join(', ')),
                const Divider(height: 24),
                _buildReviewItem('Level', _educationLevel ?? 'Not specified'),
                if (_requirementsController.text.isNotEmpty) ...[
                  const Divider(height: 24),
                  _buildReviewItem('Requirements', _requirementsController.text),
                ],
                const Divider(height: 24),
                _buildReviewItem('Teaching Mode', _teachingMode?.toUpperCase() ?? ''),
                const Divider(height: 24),
                _buildReviewItem(
                  'Budget',
                  '$_minBudget - $_maxBudget XAF per session',
                ),
                const Divider(height: 24),
                _buildReviewItem('Days', _preferredDays.join(', ')),
                const Divider(height: 24),
                _buildReviewItem('Time', _preferredTime ?? ''),
                const Divider(height: 24),
                _buildReviewItem('Location', _locationController.text),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Urgency
          _buildSectionTitle('How urgent is this request?'),
          const SizedBox(height: 12),
          ...['urgent', 'normal', 'flexible'].map((urgencyLevel) {
            final labels = {
              'urgent': 'Urgent - Need tutor within 1-2 days',
              'normal': 'Normal - Within this week',
              'flexible': 'Flexible - Whenever available',
            };
            return RadioListTile<String>(
              value: urgencyLevel,
              groupValue: _urgency,
              onChanged: (value) => setState(() => _urgency = value!),
              title: Text(
                labels[urgencyLevel]!,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              activeColor: AppTheme.primaryColor,
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
          const SizedBox(height: 24),

          // Additional Notes
          _buildSectionTitle('Additional Notes (Optional)'),
          const SizedBox(height: 12),
          TextField(
            controller: _additionalNotesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Any other information that might help us find the perfect tutor...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.textDark,
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMedium,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitRequest() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Submitting your request...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Create request in database
      final requestId = await TutorRequestService.createRequest(
        subjects: _selectedSubjects,
        educationLevel: _educationLevel!,
        specificRequirements: _requirementsController.text,
        teachingMode: _teachingMode!,
        budgetMin: _minBudget,
        budgetMax: _maxBudget,
        tutorGender: _tutorGender,
        tutorQualification: _tutorQualification,
        preferredDays: _preferredDays,
        preferredTime: _preferredTime!,
        location: _locationController.text,
        urgency: _urgency,
        additionalNotes: _additionalNotesController.text,
      );

      // Send WhatsApp notification to PrepSkul team
      await _sendWhatsAppNotification(requestId);

      // Close loading
      if (mounted) Navigator.pop(context);

      // Show success
      _showSuccessDialog();
    } catch (e) {
      print('Error submitting request: $e');
      
      // Close loading
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Error',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Failed to submit request. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _sendWhatsAppNotification(String requestId) async {
    final userProfile = await AuthService.getUserProfile();
    final userName = userProfile?['full_name'] ?? 'User';
    final userPhone = userProfile?['phone_number'] ?? 'Not provided';

    final message = '''
🎓 *New Tutor Request* 

*Request ID:* $requestId
*From:* $userName ($userPhone)

*Subjects:* ${_selectedSubjects.join(', ')}
*Level:* $_educationLevel
*Teaching Mode:* ${_teachingMode?.toUpperCase()}
*Budget:* $_minBudget - $_maxBudget XAF/session

*Schedule:*
- Days: ${_preferredDays.join(', ')}
- Time: $_preferredTime

*Location:* ${_locationController.text}

*Urgency:* ${_urgency.toUpperCase()}

${_requirementsController.text.isNotEmpty ? '*Requirements:*\n${_requirementsController.text}\n\n' : ''}${_additionalNotesController.text.isNotEmpty ? '*Additional Notes:*\n${_additionalNotesController.text}\n\n' : ''}---
Please find a tutor for this user as soon as possible.
''';

    final whatsappUrl = Uri.parse(
      'https://wa.me/237653301997?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Could not launch WhatsApp: $e');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Request Submitted!',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We\'ve received your request and will find the perfect tutor for you. You\'ll be notified once we have a match!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textMedium,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close request flow
                  // Navigate to Requests tab
                  Navigator.pushReplacementNamed(
                    context,
                    '/student-nav',
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
                    fontSize: 15,
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

