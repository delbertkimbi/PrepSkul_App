import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/app_data.dart';
import '../../../core/widgets/image_picker_bottom_sheet.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/survey_repository.dart';
import '../../../core/services/profile_completion_service.dart';

class TutorOnboardingScreen extends StatefulWidget {
  final Map<String, dynamic> basicInfo;

  const TutorOnboardingScreen({super.key, required this.basicInfo});

  @override
  State<TutorOnboardingScreen> createState() => _TutorOnboardingScreenState();
}

class _TutorOnboardingScreenState extends State<TutorOnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentStep = 0;
  int _totalSteps = 11; // Added email step

  @override
  void initState() {
    super.initState();
    _customQuarterController.addListener(() {
      setState(() {
        _customQuarter = _customQuarterController.text;
      });
    });
    _loadSavedData();
  }

  // Auto-save functionality
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'currentStep': _currentStep,
      'email': _emailController.text,
      'selectedEducation': _selectedEducation,
      'institution': _institutionController.text,
      'fieldOfStudy': _fieldOfStudyController.text,
      'hasTraining': _hasTraining,
      'selectedCity': _selectedCity,
      'selectedQuarter': _selectedQuarter,
      'customQuarter': _customQuarter,
      'selectedTutoringAreas': _selectedTutoringAreas,
      'selectedLearnerLevels': _selectedLearnerLevels,
      'selectedSpecializations': _selectedSpecializations,
      'hasExperience': _hasExperience,
      'experienceDuration': _experienceDuration,
      'motivation': _motivationController.text,
      'preferredMode': _preferredMode,
      'teachingApproaches': _teachingApproaches,
      'preferredSessionType': _preferredSessionType,
      'hoursPerWeek': _hoursPerWeek,
      'paymentMethod': _paymentMethod,
      'expectedRate': _expectedRate,
      'agreesToPaymentPolicy': _agreesToPaymentPolicy,
      'agreesToVerification': _agreesToVerification,
    };
    await prefs.setString('tutor_onboarding_data', jsonEncode(data));
    print('✅ Auto-saved tutor onboarding data');
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDataString = prefs.getString('tutor_onboarding_data');

    if (savedDataString != null) {
      try {
        final data = jsonDecode(savedDataString) as Map<String, dynamic>;
        setState(() {
          _currentStep = data['currentStep'] ?? 0;
          _emailController.text = data['email'] ?? '';
          _selectedEducation = data['selectedEducation'];
          _institutionController.text = data['institution'] ?? '';
          _fieldOfStudyController.text = data['fieldOfStudy'] ?? '';
          _hasTraining = data['hasTraining'] ?? false;
          _selectedCity = data['selectedCity'];
          _selectedQuarter = data['selectedQuarter'];
          _customQuarter = data['customQuarter'];
          _selectedTutoringAreas = List<String>.from(
            data['selectedTutoringAreas'] ?? [],
          );
          _selectedLearnerLevels = List<String>.from(
            data['selectedLearnerLevels'] ?? [],
          );
          _selectedSpecializations = List<String>.from(
            data['selectedSpecializations'] ?? [],
          );
          _hasExperience = data['hasExperience'] ?? false;
          _experienceDuration = data['experienceDuration'];
          _motivationController.text = data['motivation'] ?? '';
          _preferredMode = data['preferredMode'];
          _teachingApproaches = List<String>.from(
            data['teachingApproaches'] ?? [],
          );
          _preferredSessionType = data['preferredSessionType'];
          _hoursPerWeek = data['hoursPerWeek'];
          _paymentMethod = data['paymentMethod'];
          _expectedRate = data['expectedRate'];
          _agreesToPaymentPolicy = data['agreesToPaymentPolicy'] ?? false;
          _agreesToVerification = data['agreesToVerification'] ?? false;
        });

        // Update quarters if city is selected
        if (_selectedCity != null) {
          _availableQuarters = AppData.cities[_selectedCity!] ?? [];
        }

        print(
          '✅ Loaded saved tutor onboarding data - resuming at step $_currentStep',
        );

        // Jump to saved step
        if (_currentStep > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pageController.jumpToPage(_currentStep);
          });
        }
      } catch (e) {
        print('⚠️ Error loading saved data: $e');
      }
    }
  }

  // Contact Information
  final _emailController = TextEditingController();

  // Academic Background
  String? _selectedEducation;
  final _institutionController = TextEditingController();
  final _fieldOfStudyController = TextEditingController();
  bool _hasTraining = false;

  // Location Information
  String? _selectedCity;
  String? _selectedQuarter;
  String? _customQuarter;
  List<String> _availableQuarters = [];
  bool _isCustomQuarter = false;
  final _customQuarterController = TextEditingController();

  // Teaching Focus
  List<String> _selectedTutoringAreas = [];
  List<String> _selectedLearnerLevels = [];
  List<String> _selectedSpecializations = [];
  final _customSpecializationController = TextEditingController();

  // Experience
  bool _hasExperience = false;
  String? _experienceDuration;
  final _previousOrganizationController = TextEditingController();
  List<String> _taughtLevels = [];
  final _motivationController = TextEditingController();

  // Teaching Style & Availability
  String? _preferredMode;
  List<String> _teachingApproaches = [];
  String? _preferredSessionType;
  bool _handlesMultipleLearners = false;
  String? _hoursPerWeek;
  Map<String, List<String>> _tutoringAvailability =
      {}; // Day -> List of time ranges
  Map<String, List<String>> _testSessionAvailability =
      {}; // Day -> List of time ranges
  String _selectedServiceType = 'tutoring'; // 'tutoring' or 'test_sessions'

  // Digital Readiness
  List<String> _devices = [];
  bool _hasInternet = false;
  List<String> _teachingTools = [];
  bool _hasMaterials = false;
  bool _wantsTraining = false;

  // Payment
  String? _paymentMethod;
  final _paymentNumberController = TextEditingController();
  final _paymentNameController = TextEditingController();
  final _bankDetailsController = TextEditingController();
  String? _expectedRate;
  List<String> _pricingFactors = [];
  bool _agreesToPaymentPolicy = false;

  // Verification
  bool _agreesToVerification = false;
  Map<String, String> _socialMediaLinks = {}; // Platform -> Link
  final _videoLinkController = TextEditingController();

  // File uploads
  File? _profilePhotoFile;
  String? _profilePhotoUrl;
  bool _isUploadingProfilePhoto = false;

  File? _idCardFrontFile;
  String? _idCardFrontUrl;
  bool _isUploadingIdCardFront = false;

  File? _idCardBackFile;
  String? _idCardBackUrl;
  bool _isUploadingIdCardBack = false;

  Map<String, File> _certificateFiles =
      {}; // key: certificate name, value: File
  Map<String, String> _certificateUrls =
      {}; // key: certificate name, value: URL
  Map<String, bool> _uploadingCertificates = {}; // track upload progress

  // Personal Statement
  final _statementController = TextEditingController();

  // Affirmations
  Map<String, bool> _affirmations = {
    'professionalism': false,
    'dedication': false,
    'payment_understanding': false,
    'no_external_payments': false,
    'truthful_information': false,
  };

  // Document uploads
  Map<String, dynamic> _uploadedDocuments = {};

  // Validation helpers
  bool _isValidEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(
      r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$',
      caseSensitive: false,
    );
    return emailRegex.hasMatch(email);
  }

  bool _isValidYouTubeUrl(String url) {
    if (url.isEmpty) return true; // Optional field
    final youtubeRegex = RegExp(
      r'^(https?:\/\/)?(www\.)?(youtube\.com\/(watch\?v=|embed\/)|youtu\.be\/).+$',
      caseSensitive: false,
    );
    return youtubeRegex.hasMatch(url);
  }

  bool _isValidPhoneNumber(String phone) {
    if (phone.isEmpty) return false;
    // Remove any spaces or dashes
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-]'), '');
    // Should be 9 digits (Cameroon phone number)
    return RegExp(r'^\d{9}$').hasMatch(cleanPhone);
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return true; // Optional field
    final urlRegex = RegExp(
      r'^(https?:\/\/)?([\w\-]+(\.[\w\-]+)+)(\/[\w\-\.\/]*)?$',
      caseSensitive: false,
    );
    return urlRegex.hasMatch(url);
  }

  String? _getUrlError(String url, String platform) {
    if (url.isEmpty) return null;

    if (!_isValidUrl(url)) {
      return 'Please enter a valid $platform URL';
    }

    // Platform-specific validation
    switch (platform.toLowerCase()) {
      case 'facebook':
        if (!url.contains('facebook.com')) {
          return 'Please enter a valid Facebook profile URL';
        }
        break;
      case 'linkedin':
        if (!url.contains('linkedin.com')) {
          return 'Please enter a valid LinkedIn profile URL';
        }
        break;
      case 'twitter':
        if (!url.contains('twitter.com') && !url.contains('x.com')) {
          return 'Please enter a valid Twitter/X profile URL';
        }
        break;
      case 'instagram':
        if (!url.contains('instagram.com')) {
          return 'Please enter a valid Instagram profile URL';
        }
        break;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Tutor Onboarding',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${((_currentStep + 1) / _totalSteps * 100).round()}% Complete',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_done,
                          size: 16,
                          color: AppTheme.textMedium,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Auto-saved',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Your progress is automatically saved. You can continue anytime.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.textLight,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentStep + 1) / _totalSteps,
                backgroundColor: AppTheme.softBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
                minHeight: 4,
              ),
            ],
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentStep = index;
          });
        },
        children: [
          _buildContactInformationStep(),
          _buildAcademicBackgroundStep(),
          _buildLocationStep(),
          _buildTeachingFocusStep(),
          _buildExperienceStep(),
          _buildTeachingStyleStep(),
          _buildDigitalReadinessStep(),
          _buildAvailabilityStep(),
          _buildPaymentStep(),
          _buildVerificationStep(),
          _buildPersonalStatementStep(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Back Button - Circular
            if (_currentStep > 0)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.softBorder, width: 1.5),
                ),
                child: IconButton(
                  onPressed: _previousStep,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppTheme.textDark,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),

            if (_currentStep > 0) const SizedBox(width: 12),

            // Next Button - Beautiful rounded style like login/signup
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _currentStep == _totalSteps - 1
                      ? _submitApplication
                      : _canProceedFromCurrentStep()
                      ? _nextStep
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceedFromCurrentStep()
                        ? AppTheme.primaryColor
                        : AppTheme.neutral200,
                    foregroundColor: _canProceedFromCurrentStep()
                        ? Colors.white
                        : AppTheme.textLight,
                    elevation: _canProceedFromCurrentStep() ? 2 : 0,
                    shadowColor: _canProceedFromCurrentStep()
                        ? AppTheme.primaryColor.withOpacity(0.3)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    _currentStep == _totalSteps - 1
                        ? 'Submit Application'
                        : 'Next',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInformationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Contact Information',
            'We need your email for important notifications',
            Icons.email_outlined,
            hasRequiredFields: true,
          ),
          const SizedBox(height: 32),

          // Info box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'We\'ll send your approval status and important updates to this email',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textDark,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Email Input
          _buildInputField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'Enter your email (e.g., tutor@example.com)',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              if (!_isValidEmail(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAcademicBackgroundStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Academic Background',
            'Tell us about your education',
            Icons.school,
            hasRequiredFields: true,
          ),
          const SizedBox(height: 32),

          // Education Level Selection Cards
          _buildSelectionCards(
            title: 'Highest Level of Education',
            options: [
              'Ordinary Level',
              'Advanced Level',
              'HND',
              'Bachelors',
              'Master\'s',
              'Doctorate',
              'PHD',
            ],
            selectedValue: _selectedEducation,
            onSelectionChanged: (value) =>
                setState(() => _selectedEducation = value),
            isSingleSelection: true,
          ),

          const SizedBox(height: 24),

          // Institution Input
          _buildInputField(
            controller: _institutionController,
            label: 'Institution attending/attended',
            hint: 'Enter your institution name',
            icon: Icons.business,
          ),

          const SizedBox(height: 24),

          // Field of Study Input
          _buildInputField(
            controller: _fieldOfStudyController,
            label: 'Field of Study',
            hint: 'Enter your field of study',
            icon: Icons.book,
          ),

          const SizedBox(height: 24),

          // Training Toggle
          _buildToggleOption(
            title: 'Have you received tutor training or certification before?',
            value: _hasTraining,
            onChanged: (value) => setState(() => _hasTraining = value),
            icon: Icons.verified,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Location',
            'Where are you located?',
            Icons.location_on,
            hasRequiredFields: true,
          ),
          const SizedBox(height: 30),
          _buildDropdownField(
            label: 'City',
            value: _selectedCity,
            items: AppData.cities.keys.toList(),
            onChanged: (value) {
              setState(() {
                _selectedCity = value;
                _selectedQuarter = null;
                _customQuarter = null;
                _isCustomQuarter = false;
                _availableQuarters = value != null
                    ? AppData.cities[value] ?? []
                    : [];
              });
            },
            isRequired: true,
          ),
          const SizedBox(height: 20),
          _buildDropdownField(
            label: 'Quarter/Neighborhood',
            value: _isCustomQuarter ? 'Other' : _selectedQuarter,
            items: [..._availableQuarters, 'Other'],
            onChanged: (value) {
              setState(() {
                if (value == 'Other') {
                  _isCustomQuarter = true;
                  _selectedQuarter = null;
                } else {
                  _isCustomQuarter = false;
                  _selectedQuarter = value;
                  _customQuarter = null;
                }
              });
            },
            isRequired: true,
          ),
          if (_isCustomQuarter) ...[
            const SizedBox(height: 20),
            _buildInputField(
              label: 'Enter Quarter/Neighborhood',
              hint: 'Type your quarter or neighborhood',
              controller: _customQuarterController,
              icon: Icons.location_on,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeachingFocusStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Teaching Focus',
            'What do you want to teach?',
            Icons.category,
            hasRequiredFields: true,
          ),
          const SizedBox(height: 32),

          // Tutoring Areas Selection Cards
          _buildSelectionCards(
            title: 'Areas of Tutoring',
            options: [
              'Academic Tutoring',
              'Skill Development',
              'Exam Preparation',
            ],
            selectedValue: _selectedTutoringAreas,
            onSelectionChanged: (values) =>
                setState(() => _selectedTutoringAreas = values),
            isSingleSelection: false,
          ),

          const SizedBox(height: 24),

          // Learner Levels Selection Cards
          _buildSelectionCards(
            title: 'Learner Levels',
            options: [
              'Primary School',
              'Secondary School',
              'High School',
              'University',
              'International Exams',
              'Concours Preparation',
            ],
            selectedValue: _selectedLearnerLevels,
            onSelectionChanged: (values) =>
                setState(() => _selectedLearnerLevels = values),
            isSingleSelection: false,
          ),

          const SizedBox(height: 24),

          // Dynamic Specializations based on selections
          if (_selectedTutoringAreas.isNotEmpty &&
              _selectedLearnerLevels.isNotEmpty)
            _buildDynamicSpecializations(),
        ],
      ),
    );
  }

  Widget _buildDynamicSpecializations() {
    List<String> specializationOptions = _getSpecializationOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSelectionCards(
          title: 'Specializations',
          options: specializationOptions,
          selectedValue: _selectedSpecializations,
          onSelectionChanged: (values) =>
              setState(() => _selectedSpecializations = values),
          isSingleSelection: false,
        ),

        const SizedBox(height: 16),

        // Custom Specialization Input
        _buildInputField(
          controller: _customSpecializationController,
          label: 'Other Specializations',
          hint: 'Add your own specializations (comma-separated)',
          icon: Icons.add_circle_outline,
        ),
      ],
    );
  }

  List<String> _getSpecializationOptions() {
    List<String> options = [];

    for (String area in _selectedTutoringAreas) {
      // Use the new education system data
      options.addAll(
        AppData.getSpecializationsForTutoringArea(area, _selectedLearnerLevels),
      );
    }

    // Remove duplicates and limit to reasonable number
    options = options.toSet().toList();
    if (options.length > 25) {
      options = options.take(25).toList();
    }

    return options;
  }

  Widget _buildExperienceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Experience & Qualification',
            'Tell us about your teaching experience',
            Icons.work,
          ),
          const SizedBox(height: 32),

          // Experience Toggle
          _buildToggleOption(
            title: 'Do you have previous tutoring or teaching experience?',
            value: _hasExperience,
            onChanged: (value) => setState(() => _hasExperience = value),
            icon: Icons.work_history,
          ),

          if (_hasExperience) ...[
            const SizedBox(height: 24),

            // Experience Duration Selection Cards
            _buildSelectionCards(
              title: 'How long have you been teaching?',
              options: [
                'Less than 1 year',
                '1–3 years',
                '3–5 years',
                'Over 5 years',
              ],
              selectedValue: _experienceDuration,
              onSelectionChanged: (value) =>
                  setState(() => _experienceDuration = value),
              isSingleSelection: true,
            ),

            const SizedBox(height: 24),

            // Previous Organization Input
            _buildInputField(
              controller: _previousOrganizationController,
              label: 'Previous Organization',
              hint: 'Where have you tutored before?',
              icon: Icons.business_center,
            ),

            const SizedBox(height: 24),

            // Taught Levels Selection Cards
            _buildSelectionCards(
              title: 'Levels You\'ve Taught',
              options: [
                'Primary',
                'Secondary',
                'High School',
                'University',
                'Adult Learners',
                'Exam Prep',
              ],
              selectedValue: _taughtLevels,
              onSelectionChanged: (values) =>
                  setState(() => _taughtLevels = values),
              isSingleSelection: false,
            ),
          ],

          const SizedBox(height: 24),

          // Motivation Input
          _buildInputField(
            controller: _motivationController,
            label: 'What motivates you to teach?',
            hint: 'Tell us what drives your passion for teaching...',
            icon: Icons.psychology,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTeachingStyleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Teaching Style & Preferences',
            'How do you prefer to teach?',
            Icons.psychology,
          ),
          const SizedBox(height: 32),

          // Preferred Mode Selection Cards
          _buildSelectionCards(
            title: 'Preferred Teaching Mode',
            options: ['Online Only', 'In Person', 'Both Online & In Person'],
            selectedValue: _preferredMode,
            onSelectionChanged: (value) =>
                setState(() => _preferredMode = value),
            isSingleSelection: true,
          ),

          const SizedBox(height: 24),

          // Teaching Approaches Selection Cards
          _buildSelectionCards(
            title: 'Teaching Approach',
            options: [
              'One-on-one Guidance',
              'Group Teaching',
              'Interactive Demos',
              'Theory Focused',
              'Digital Tools',
            ],
            selectedValue: _teachingApproaches,
            onSelectionChanged: (values) =>
                setState(() => _teachingApproaches = values),
            isSingleSelection: false,
          ),

          const SizedBox(height: 24),

          // Session Type Selection Cards
          _buildSelectionCards(
            title: 'Preferred Session Type',
            options: ['One-on-one', 'Small Groups (2-5)', 'Larger Groups'],
            selectedValue: _preferredSessionType,
            onSelectionChanged: (value) =>
                setState(() => _preferredSessionType = value),
            isSingleSelection: true,
          ),

          const SizedBox(height: 24),

          // Multiple Learners Toggle
          _buildToggleOption(
            title: 'Open to handling multiple learners at once?',
            value: _handlesMultipleLearners,
            onChanged: (value) =>
                setState(() => _handlesMultipleLearners = value),
            icon: Icons.people,
          ),

          const SizedBox(height: 24),

          // Hours Per Week Selection Cards
          _buildSelectionCards(
            title: 'Hours Per Week',
            options: [
              '1-5 hours',
              '6-10 hours',
              '11-15 hours',
              '16-20 hours',
              '20+ hours',
            ],
            selectedValue: _hoursPerWeek,
            onSelectionChanged: (value) =>
                setState(() => _hoursPerWeek = value),
            isSingleSelection: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalReadinessStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Digital Readiness',
            'Tell us about your digital setup',
            Icons.devices,
          ),
          const SizedBox(height: 32),

          // Devices Selection Cards
          _buildSelectionCards(
            title: 'Devices You Use',
            options: [
              'Laptop/Computer',
              'Tablet',
              'Smartphone',
              'Desktop Computer',
            ],
            selectedValue: _devices,
            onSelectionChanged: (values) => setState(() => _devices = values),
            isSingleSelection: false,
          ),

          const SizedBox(height: 24),

          // Internet Connection Toggle
          _buildToggleOption(
            title: 'Reliable internet connection for online sessions?',
            value: _hasInternet,
            onChanged: (value) => setState(() => _hasInternet = value),
            icon: Icons.wifi,
          ),

          const SizedBox(height: 24),

          // Teaching Tools Selection Cards
          _buildSelectionCards(
            title: 'Online Teaching Tools',
            options: [
              'Zoom',
              'Google Meet',
              'Microsoft Teams',
              'Skype',
              'WhatsApp Video',
              'Other',
            ],
            selectedValue: _teachingTools,
            onSelectionChanged: (values) =>
                setState(() => _teachingTools = values),
            isSingleSelection: false,
          ),

          const SizedBox(height: 24),

          // Materials Toggle
          _buildToggleOption(
            title: 'Access to teaching materials (notes, slides, PDFs)?',
            value: _hasMaterials,
            onChanged: (value) => setState(() => _hasMaterials = value),
            icon: Icons.folder,
          ),

          const SizedBox(height: 24),

          // Training Interest Toggle
          _buildToggleOption(
            title: 'Interested in free digital teaching training?',
            value: _wantsTraining,
            onChanged: (value) => setState(() => _wantsTraining = value),
            icon: Icons.school,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Availability & Services',
            'Set your available times for different services',
            Icons.calendar_today,
          ),
          const SizedBox(height: 32),

          // Service Type Selection
          _buildServiceTypeSelection(),

          const SizedBox(height: 24),

          // Availability Calendar
          _buildAvailabilityCalendar(),

          const SizedBox(height: 24),

          // Business Model Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'How it works:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Test Sessions: Trial sessions for students/parents to evaluate if you\'re a good fit. Mainly online and free for tutors. Onsite test sessions available when requested with extra compensation.\n• Tutoring Sessions: Regular teaching sessions (online & physical) with direct learner-tutor matching and payment.\n• Test sessions help students/parents assess your teaching style and compatibility before committing to regular sessions.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Service Type',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedServiceType = 'tutoring'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selectedServiceType == 'tutoring'
                        ? AppTheme.primaryColor
                        : AppTheme.softCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedServiceType == 'tutoring'
                          ? AppTheme.primaryColor
                          : AppTheme.softBorder,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.school,
                        color: _selectedServiceType == 'tutoring'
                            ? Colors.white
                            : AppTheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tutoring Sessions',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _selectedServiceType == 'tutoring'
                              ? Colors.white
                              : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Online & Physical',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _selectedServiceType == 'tutoring'
                              ? Colors.white.withOpacity(0.8)
                              : AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _selectedServiceType = 'test_sessions'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selectedServiceType == 'test_sessions'
                        ? AppTheme.primaryColor
                        : AppTheme.softCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedServiceType == 'test_sessions'
                          ? AppTheme.primaryColor
                          : AppTheme.softBorder,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.quiz,
                        color: _selectedServiceType == 'test_sessions'
                            ? Colors.white
                            : AppTheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Test Sessions',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _selectedServiceType == 'test_sessions'
                              ? Colors.white
                              : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Trial Sessions',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _selectedServiceType == 'test_sessions'
                              ? Colors.white.withOpacity(0.8)
                              : AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailabilityCalendar() {
    List<String> days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    List<String> timeRanges = [
      '6:00 AM - 9:00 AM',
      '9:00 AM - 12:00 PM',
      '12:00 PM - 3:00 PM',
      '3:00 PM - 6:00 PM',
      '6:00 PM - 9:00 PM',
      '9:00 PM - 12:00 AM',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select your available times for ${_selectedServiceType == 'tutoring' ? 'Tutoring' : 'Test Sessions'}',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedServiceType == 'tutoring'
              ? 'Set your availability for regular tutoring sessions (online & physical)'
              : 'Set your availability for trial sessions where students/parents can evaluate your teaching style',
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 20),

        // Better Mobile-Friendly Time Selection with Synchronized Scrolling
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.softBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                // Time Ranges Header - Now scrolls with content
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          'Day',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      ...timeRanges.map(
                        (timeRange) => Container(
                          width: 100,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            timeRange,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Days and availability checkboxes - All in one scrollable row
                ...days.map(
                  (day) => Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.softBorder.withOpacity(0.5),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            day,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        ...timeRanges.map(
                          (timeRange) => Container(
                            width: 100,
                            child: Center(
                              child: Checkbox(
                                value:
                                    _getCurrentAvailability()[day]?.contains(
                                      timeRange,
                                    ) ??
                                    false,
                                onChanged: (value) {
                                  setState(() {
                                    final currentAvailability =
                                        _getCurrentAvailability();
                                    currentAvailability[day] ??= [];
                                    if (value == true) {
                                      currentAvailability[day]!.add(timeRange);
                                    } else {
                                      currentAvailability[day]!.remove(
                                        timeRange,
                                      );
                                    }
                                  });
                                },
                                activeColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, List<String>> _getCurrentAvailability() {
    return _selectedServiceType == 'tutoring'
        ? _tutoringAvailability
        : _testSessionAvailability;
  }

  Widget _buildPaymentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Payment & Expectations',
            'Tell us about your payment preferences',
            Icons.payment,
          ),
          const SizedBox(height: 32),

          // Payment Method Selection Cards
          _buildSelectionCards(
            title: 'Payment Method',
            options: ['MTN Mobile Money', 'Orange Money', 'Bank Transfer'],
            selectedValue: _paymentMethod,
            onSelectionChanged: (value) =>
                setState(() => _paymentMethod = value),
            isSingleSelection: true,
          ),

          const SizedBox(height: 24),

          // Dynamic Payment Details based on method
          if (_paymentMethod != null) _buildDynamicPaymentDetails(),

          const SizedBox(height: 24),

          // Expected Rate Selection Cards
          _buildSelectionCards(
            title: 'Expected Rate Per Hour',
            options: [
              '2,000 – 3,000 XAF',
              '3,000 – 4,000 XAF',
              '4,000 – 5,000 XAF',
              'Above 5,000 XAF',
            ],
            selectedValue: _expectedRate,
            onSelectionChanged: (value) =>
                setState(() => _expectedRate = value),
            isSingleSelection: true,
          ),

          const SizedBox(height: 24),

          // Detailed Pricing Factors
          _buildDetailedPricingFactors(),

          const SizedBox(height: 24),

          // Payment Policy Agreement
          _buildPaymentPolicyAgreement(),
        ],
      ),
    );
  }

  Widget _buildDynamicPaymentDetails() {
    switch (_paymentMethod) {
      case 'MTN Mobile Money':
        return Column(
          children: [
            _buildInputField(
              controller: _paymentNumberController,
              label: 'MTN Mobile Money Number',
              hint: 'Enter your MTN MoMo number (9 digits)',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your mobile money number';
                }
                if (!_isValidPhoneNumber(value)) {
                  return 'Please enter a valid 9-digit phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _paymentNameController,
              label: 'Account Name',
              hint: 'Name on the account',
              icon: Icons.person,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the account name';
                }
                if (value.length < 3) {
                  return 'Name must be at least 3 characters';
                }
                return null;
              },
            ),
          ],
        );
      case 'Orange Money':
        return Column(
          children: [
            _buildInputField(
              controller: _paymentNumberController,
              label: 'Orange Money Number',
              hint: 'Enter your Orange Money number (9 digits)',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your mobile money number';
                }
                if (!_isValidPhoneNumber(value)) {
                  return 'Please enter a valid 9-digit phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _paymentNameController,
              label: 'Account Name',
              hint: 'Name on the account',
              icon: Icons.person,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the account name';
                }
                if (value.length < 3) {
                  return 'Name must be at least 3 characters';
                }
                return null;
              },
            ),
          ],
        );
      case 'Bank Transfer':
        return _buildInputField(
          controller: _bankDetailsController,
          label: 'Bank Details',
          hint: 'Account Number, Bank Name, Account Holder Name',
          icon: Icons.account_balance,
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your bank details';
            }
            if (value.length < 10) {
              return 'Please provide complete bank details';
            }
            return null;
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDetailedPricingFactors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What factors influence your pricing?',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),

        // Primary Factors
        _buildSelectionCards(
          title: 'Primary Factors',
          options: [
            'Subject Difficulty Level',
            'Student Grade Level',
            'Session Duration',
            'Preparation Time Required',
          ],
          selectedValue: _pricingFactors,
          onSelectionChanged: (values) =>
              setState(() => _pricingFactors = values),
          isSingleSelection: false,
        ),

        const SizedBox(height: 16),

        // Additional Considerations
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.softCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.softBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Additional Considerations:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Travel distance for in-person sessions\n• Specialized materials needed\n• Exam preparation intensity\n• Group vs individual sessions',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentPolicyAgreement() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _agreesToPaymentPolicy,
                onChanged: (value) =>
                    setState(() => _agreesToPaymentPolicy = value ?? false),
                activeColor: AppTheme.primaryColor,
              ),
              Expanded(
                child: Text(
                  'I understand and agree to PrepSkul\'s payment process',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showPaymentProcessInfo(),
            child: Text(
              'View payment process details',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.primaryColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Verification & Credentials',
            'Upload required documents',
            Icons.verified_user,
            hasRequiredFields: true,
          ),
          const SizedBox(height: 32),

          // Dynamic Document Upload based on education level
          _buildDynamicDocumentUpload(),

          const SizedBox(height: 24),

          // Verification Agreement Toggle
          _buildToggleOption(
            title:
                'I agree for PrepSkul to verify my credentials and background',
            value: _agreesToVerification,
            onChanged: (value) => setState(() => _agreesToVerification = value),
            icon: Icons.verified_user,
          ),

          const SizedBox(height: 24),

          // Social Media Links with Icons
          _buildSocialMediaLinks(),

          const SizedBox(height: 24),

          // Video Introduction
          _buildVideoIntroduction(),
        ],
      ),
    );
  }

  Widget _buildDynamicDocumentUpload() {
    List<Map<String, String>> requiredDocs = [];

    // Always require profile picture and ID
    requiredDocs.add({
      'type': 'profile_picture',
      'title': 'Clear Profile Picture',
      'description': 'A clear, professional photo of yourself',
    });
    requiredDocs.add({
      'type': 'id_front',
      'title': 'ID Card Front',
      'description': 'Front side of your national ID card',
    });
    requiredDocs.add({
      'type': 'id_back',
      'title': 'ID Card Back',
      'description': 'Back side of your national ID card',
    });

    // Add documents based on education level
    if (_selectedEducation != null &&
        [
          'Bachelors',
          'Master\'s',
          'Doctorate',
          'PHD',
        ].contains(_selectedEducation)) {
      requiredDocs.add({
        'type': 'degree_certificate',
        'title': 'Degree Certificate',
        'description': 'Your degree certificate or transcript',
      });
    }

    // Add training certificate if they have training
    if (_hasTraining) {
      requiredDocs.add({
        'type': 'training_certificate',
        'title': 'Training Certificate',
        'description': 'Your teacher/tutor training certificate',
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required Documents',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),

        ...requiredDocs.map((doc) => _buildDocumentUploadCard(doc)),
      ],
    );
  }

  Widget _buildDocumentUploadCard(Map<String, dynamic> doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getDocumentIcon(doc['type']!),
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['title']!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      doc['description']!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _uploadDocument(doc['type']!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _uploadedDocuments[doc['type']] != null
                      ? 'Reupload'
                      : 'Upload',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (_uploadedDocuments[doc['type']] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '✓ ${_uploadedDocuments[doc['type']]['name']}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getDocumentIcon(String type) {
    switch (type) {
      case 'profile_picture':
        return Icons.person;
      case 'id_front':
      case 'id_back':
        return Icons.credit_card;
      case 'degree_certificate':
        return Icons.school;
      case 'training_certificate':
        return Icons.verified;
      default:
        return Icons.description;
    }
  }

  Widget _buildSocialMediaLinks() {
    List<Map<String, dynamic>> socialPlatforms = [
      {
        'name': 'LinkedIn',
        'icon': Icons.business,
        'placeholder': 'https://linkedin.com/in/yourprofile',
      },
      {
        'name': 'Facebook',
        'icon': Icons.facebook,
        'placeholder': 'https://facebook.com/yourprofile',
      },
      {
        'name': 'Instagram',
        'icon': Icons.camera_alt,
        'placeholder': 'https://instagram.com/yourprofile',
      },
      {
        'name': 'YouTube',
        'icon': Icons.video_library,
        'placeholder': 'https://youtube.com/channel/yourchannel',
      },
      {
        'name': 'Portfolio Website',
        'icon': Icons.web,
        'placeholder': 'https://yourportfolio.com',
      },
    ];

    List<String> addedLinks = _socialMediaLinks.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Social Media & Professional Links (Optional)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _showSocialMediaSelection(socialPlatforms),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (addedLinks.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.softCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Text(
              'No social media links added yet. Click the + button to add.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textMedium,
              ),
            ),
          )
        else
          ...addedLinks.map((platformName) {
            final platform = socialPlatforms.firstWhere(
              (p) => p['name'] == platformName,
            );
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      platform['icon'],
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _socialMediaLinks[platformName] ?? '',
                      onChanged: (value) {
                        setState(() {
                          _socialMediaLinks[platformName] = value;
                        });
                      },
                      keyboardType: TextInputType.url,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return null; // Optional field
                        }
                        return _getUrlError(value, platformName);
                      },
                      decoration: InputDecoration(
                        labelText: platform['name'],
                        hintText: platform['placeholder'],
                        hintStyle: GoogleFonts.poppins(
                          color: AppTheme.textLight,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: AppTheme.softCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.softBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.softBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                        errorStyle: GoogleFonts.poppins(fontSize: 10),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _showSocialMediaSelection(List<Map<String, dynamic>> platforms) {
    List<String> availablePlatforms = platforms
        .where((p) => !_socialMediaLinks.containsKey(p['name']))
        .map((p) => p['name'] as String)
        .toList();

    if (availablePlatforms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All social media platforms have been added'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Social Media Link',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availablePlatforms
              .map(
                (platformName) => ListTile(
                  onTap: () {
                    setState(() {
                      _socialMediaLinks[platformName] = '';
                    });
                    Navigator.pop(context);
                  },
                  leading: const Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(
                    platformName,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildVideoIntroduction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Video Introduction',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.textMedium.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Optional',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppTheme.textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'This helps us and potential learners get to know you better',
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 16),

        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your responses are automatically saved. You can add your video later from your profile.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildInputField(
          controller: _videoLinkController,
          label: 'YouTube Video Link',
          hint: 'Paste your YouTube video link here',
          icon: Icons.video_call,
          keyboardType: TextInputType.url,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return null; // Optional field
            }
            if (!_isValidYouTubeUrl(value)) {
              return 'Please enter a valid YouTube URL (e.g., youtube.com/watch?v=...)';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Detailed Instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.softCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.softBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Video Instructions',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showDetailedVideoInstructions(),
                    child: Text(
                      'View detailed instructions',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Record a 1-3 minute video introducing yourself and your teaching style.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalStatementStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Personal Statement',
            'Review and edit your profile description',
            Icons.edit_note,
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.softCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generated Profile Description',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This description will be displayed on your profile. You can edit it to better reflect your teaching style and experience.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _statementController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText:
                  'Your personal statement will be generated based on your responses...',
              hintStyle: GoogleFonts.poppins(
                color: AppTheme.textLight,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppTheme.softCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.softBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textDark),
          ),

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _generatePersonalStatement,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Generate Personal Statement',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Final Affirmations
          _buildFinalAffirmations(),
        ],
      ),
    );
  }

  Widget _buildFinalAffirmations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Final Agreements',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),

        _buildAffirmationToggle(
          key: 'professionalism',
          title:
              'I agree to maintain professionalism, punctuality, and respect in all interactions',
        ),

        _buildAffirmationToggle(
          key: 'dedication',
          title:
              'I will deliver lessons with dedication using approved materials and methods',
        ),

        _buildAffirmationToggle(
          key: 'payment_understanding',
          title: 'I understand that payments are processed through PrepSkul',
        ),

        _buildAffirmationToggle(
          key: 'no_external_payments',
          title:
              'I will not arrange sessions or accept payments outside the platform',
        ),

        _buildAffirmationToggle(
          key: 'truthful_information',
          title: 'I confirm that all information provided is true and accurate',
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    String subtitle,
    IconData icon, {
    bool hasRequiredFields = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (hasRequiredFields) ...[
                      const SizedBox(width: 8),
                      Text(
                        '*',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                if (hasRequiredFields) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Fields marked with * are required',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                      fontStyle: FontStyle.italic,
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

  Widget _buildSelectionCards({
    required String title,
    required List<String> options,
    required dynamic selectedValue,
    required Function(dynamic) onSelectionChanged,
    required bool isSingleSelection,
  }) {
    return Column(
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
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options.map((option) {
            bool isSelected = isSingleSelection
                ? selectedValue == option
                : (selectedValue as List<String>).contains(option);

            return GestureDetector(
              onTap: () {
                if (isSingleSelection) {
                  onSelectionChanged(option);
                } else {
                  List<String> currentValues = List.from(selectedValue);
                  if (currentValues.contains(option)) {
                    currentValues.remove(option);
                  } else {
                    currentValues.add(option);
                  }
                  onSelectionChanged(currentValues);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.softCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.softBorder,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    if (isSelected) const SizedBox(width: 8),
                    Text(
                      option,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    String? value,
    required List<String> items,
    required Function(String?) onChanged,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            if (isRequired) ...[
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
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.softCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.softBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.softBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          autovalidateMode: validator != null
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          validator: validator,
          onChanged: (value) {
            // Trigger rebuild to update button state
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: AppTheme.textLight,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppTheme.softCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.softBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.softBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            errorStyle: GoogleFonts.poppins(fontSize: 11),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleOption({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildAffirmationToggle({required String key, required String title}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _affirmations[key] ?? false,
            onChanged: (value) {
              setState(() {
                _affirmations[key] = value ?? false;
              });
            },
            activeColor: AppTheme.primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      // Validate current step before proceeding
      if (_canProceedFromCurrentStep()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        // Auto-save after moving to next step
        _saveData();
      }
    }
  }

  bool _canProceedFromCurrentStep() {
    switch (_currentStep) {
      case 0: // Academic Background - Certification is optional, so _hasTraining doesn't need to be true
        return _selectedEducation != null &&
            _institutionController.text.isNotEmpty &&
            _fieldOfStudyController.text.isNotEmpty;
      case 1: // Location
        return _selectedCity != null &&
            (_selectedQuarter != null ||
                (_isCustomQuarter &&
                    _customQuarter != null &&
                    _customQuarter!.isNotEmpty));
      case 2: // Teaching Focus
        return _selectedTutoringAreas.isNotEmpty &&
            _selectedLearnerLevels.isNotEmpty &&
            _selectedSpecializations.isNotEmpty;
      case 3: // Experience - _hasExperience defaults to false, only validate if true
        if (_hasExperience) {
          return _experienceDuration != null;
        }
        return _motivationController
            .text
            .isNotEmpty; // Motivation is always required
      case 4: // Teaching Style
        return _preferredMode != null &&
            _teachingApproaches.isNotEmpty &&
            _preferredSessionType != null &&
            _hoursPerWeek != null;
      case 5: // Digital Readiness - _hasInternet defaults to false, so no validation needed
        return true; // No required fields
      case 6: // Availability
        return _tutoringAvailability.isNotEmpty;
      case 7: // Payment - All fields are required
        // Must select payment method
        if (_paymentMethod == null || _paymentMethod!.isEmpty) {
          return false;
        }

        // Must select expected rate
        if (_expectedRate == null || _expectedRate!.isEmpty) {
          return false;
        }

        // Must agree to payment policy
        if (!_agreesToPaymentPolicy) {
          return false;
        }

        // Must provide payment details based on method
        if (_paymentMethod == 'MTN Mobile Money' ||
            _paymentMethod == 'Orange Money') {
          return _paymentNumberController.text.isNotEmpty &&
              _paymentNameController.text.isNotEmpty;
        } else if (_paymentMethod == 'Bank Transfer') {
          return _bankDetailsController.text.isNotEmpty;
        }

        return true;
      case 8: // Verification
        return _agreesToVerification;
      case 9: // Personal Statement
        return true; // No required fields
      default:
        return true;
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _uploadDocument(String documentType) async {
    try {
      // Show image picker bottom sheet
      final File? pickedFile = await showModalBottomSheet<File>(
        context: context,
        builder: (context) => const ImagePickerBottomSheet(),
      );

      if (pickedFile == null) return;

      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text('Uploading $documentType...', style: GoogleFonts.poppins()),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          duration: const Duration(seconds: 30),
        ),
      );

      // Get user ID
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] ?? 'unknown';

      // Upload to Supabase Storage
      final String uploadedUrl = await StorageService.uploadDocument(
        userId: userId,
        documentFile: pickedFile,
        documentType: documentType.toLowerCase().replaceAll(' ', '_'),
      );

      setState(() {
        _uploadedDocuments[documentType] = uploadedUrl;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '$documentType uploaded successfully!',
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      // Auto-save after document upload
      _saveData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Upload failed: ${e.toString()}',
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _showPaymentProcessInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'PrepSkul Payment Process',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please note:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '1) All payments from learners are handled securely through PrepSkul.\n\n2) After each confirmed session, tutor earnings first appear in a Pending Balance for verification.\n\n3) Once the session is confirmed and no issues are reported, the amount moves to your Active Balance.\n\n4) Tutors can withdraw from their Active Balance at the end of each month.\n\nIn case of complaints or cancellations, PrepSkul may review and adjust payments fairly for all parties.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textMedium,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
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

  void _showDetailedVideoInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Video Introduction Instructions',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To complete your application, please share a short introductory video (1–3 minutes). This helps us and potential learners get to know you better — your teaching style, confidence, and communication approach. Don\'t worry, it\'s not an exam. Just be yourself!',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                '✅ What to do:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Record a short video (1–3 minutes) introducing yourself.\n2. Answer the 5 guiding questions below.\n3. Upload the video to YouTube (Unlisted)\n4. Paste your video link in the field below.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textDark,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Need help uploading your video on YouTube?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Open YouTube and sign in.\n2. Tap the "+" icon → Upload a video.\n3. Choose your video.\n4. Under "Visibility," select Unlisted (so only people with the link can see it).\n5. Copy the link and paste it below.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textDark,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Guiding Questions for the Video:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Who are you, and what subjects or skills do you teach best?\n2. Why do you enjoy teaching or tutoring?\n3. What makes your approach unique or effective?\n4. How do you help learners overcome challenges or build confidence?\n5. Why do you think you\'d be a great fit for PrepSkul?',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textDark,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
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

  void _generatePersonalStatement() {
    // Generate personal statement based on user responses
    String statement = _createPersonalStatement();
    setState(() {
      _statementController.text = statement;
    });
  }

  String _createPersonalStatement() {
    String statement = 'Hello! I am a passionate educator with ';

    if (_selectedEducation != null) {
      statement += '${_selectedEducation!.toLowerCase()} education ';
    }

    if (_hasExperience && _experienceDuration != null) {
      statement +=
          'and ${_experienceDuration!.toLowerCase()} of teaching experience. ';
    } else {
      statement += 'and I am excited to start my teaching journey. ';
    }

    if (_selectedTutoringAreas.isNotEmpty) {
      statement +=
          'I specialize in ${_selectedTutoringAreas.join(' and ').toLowerCase()}, ';
    }

    if (_selectedLearnerLevels.isNotEmpty) {
      statement +=
          'working with ${_selectedLearnerLevels.join(' and ').toLowerCase()} students. ';
    }

    if (_selectedSpecializations.isNotEmpty) {
      statement +=
          'My areas of expertise include ${_selectedSpecializations.join(', ').toLowerCase()}. ';
    }

    if (_motivationController.text.isNotEmpty) {
      statement += '${_motivationController.text} ';
    }

    statement +=
        'I am committed to providing quality education and helping students achieve their academic goals.';

    return statement;
  }

  Future<void> _submitApplication() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );

    try {
      // Prepare tutor profile data
      final tutorData = _prepareTutorData();

      // Calculate completion status
      final completionStatus =
          ProfileCompletionService.calculateTutorCompletion(tutorData);

      // Check if profile is 100% complete
      if (!completionStatus.isComplete) {
        // Close loading dialog
        Navigator.of(context).pop();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Incomplete Profile',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please complete all required sections before submitting:',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const SizedBox(height: 12),
                ...completionStatus.sections.where((s) => !s.isComplete).map((
                  section,
                ) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.title,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (section.missingFields.isNotEmpty)
                                Text(
                                  'Missing: ${section.missingFields.map((f) => f.label).join(', ')}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
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
        return;
      }

      // Get current user ID
      final userInfo = await AuthService.getCurrentUser();
      final userId = userInfo['userId'];

      // Save to database (pass email separately)
      await SurveyRepository.saveTutorSurvey(
        userId,
        tutorData,
        _emailController.text.trim(),
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to tutor dashboard
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/tutor-nav', (route) => false);
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      print('Error submitting application: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _prepareTutorData() {
    // Combine both availability maps
    final combinedAvailability = <String, List<String>>{};
    _tutoringAvailability.forEach((day, times) {
      combinedAvailability[day] = times;
    });

    return {
      // Personal Info
      // Note: email is saved separately to profiles table, not tutor_profiles
      'profile_photo_url': _profilePhotoUrl,
      'city': _selectedCity,
      'quarter': _selectedQuarter ?? _customQuarter,
      'about_me': _motivationController.text, // Use motivation as about me
      // Academic Background
      'highest_education': _selectedEducation,
      'institution': _institutionController.text,
      'field_of_study': _fieldOfStudyController.text,
      'certifications': _certificateUrls.isNotEmpty ? [_certificateUrls] : [],

      // Experience
      'has_teaching_experience': _hasExperience,
      'teaching_duration': _experienceDuration,
      'previous_roles': [], // Not collected in current form
      'motivation': _motivationController.text,

      // Tutoring Details
      'tutoring_areas': _selectedTutoringAreas,
      'learner_levels': _selectedLearnerLevels,
      'specializations': _selectedSpecializations,
      'personal_statement': _statementController.text,

      // Availability
      'hours_per_week': _hoursPerWeek,
      'availability': combinedAvailability,

      // Payment
      'payment_method': _paymentMethod,
      'hourly_rate': _expectedRate != null
          ? double.tryParse(_expectedRate!)
          : null,
      'payment_details': {
        if (_paymentMethod == 'Mobile Money') ...{
          'phone': _paymentNumberController.text,
          'name': _paymentNameController.text,
        },
        if (_paymentMethod == 'Bank Transfer')
          'bank_details': _bankDetailsController.text,
      },
      'payment_agreement': _agreesToPaymentPolicy,

      // Verification
      'id_card_front_url': _idCardFrontUrl,
      'id_card_back_url': _idCardBackUrl,
      'video_link': _videoLinkController.text,
      'social_links': _socialMediaLinks,
      'verification_agreement': _agreesToVerification,
      
      // Status - Always pending on submission (admin reviews)
      'status': 'pending',
    };
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _institutionController.dispose();
    _fieldOfStudyController.dispose();
    _customSpecializationController.dispose();
    _previousOrganizationController.dispose();
    _motivationController.dispose();
    _paymentNumberController.dispose();
    _paymentNameController.dispose();
    _bankDetailsController.dispose();
    _videoLinkController.dispose();
    _statementController.dispose();
    _customQuarterController.dispose();
    super.dispose();
  }
}
