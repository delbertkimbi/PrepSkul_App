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
import 'instruction_screen.dart';

class TutorOnboardingScreen extends StatefulWidget {
  final Map<String, dynamic> basicInfo;

  const TutorOnboardingScreen({super.key, required this.basicInfo});

  @override
  State<TutorOnboardingScreen> createState() => _TutorOnboardingScreenState();
}

class _TutorOnboardingScreenState extends State<TutorOnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  int _currentStep = 0;
  int _totalSteps = 14; // Split Payment & Expectations into two steps

  @override
  void initState() {
    super.initState();
    _customQuarterController.addListener(() {
      setState(() {
        _customQuarter = _customQuarterController.text;
      });
    });

    // Add listeners for payment fields to auto-save
    _paymentNumberController.addListener(() => _saveData());
    _paymentNameController.addListener(() => _saveData());
    _bankDetailsController.addListener(() => _saveData());

    _loadAuthMethod();
    _loadSavedData();
  }

  Future<void> _loadAuthMethod() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authMethod =
          prefs.getString('auth_method') ?? 'phone'; // Default to phone
    });
  }

  // Auto-save functionality - Save ALL fields locally
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'currentStep': _currentStep,
      // Contact Information
      'email': _emailController.text,
      'phone': _phoneController.text,
      'authMethod': _authMethod,
      // Academic Background
      'selectedEducation': _selectedEducation,
      'institution': _institutionController.text,
      'fieldOfStudy': _fieldOfStudyController.text,
      'hasTraining': _hasTraining,
      // Location
      'selectedCity': _selectedCity,
      'selectedQuarter': _selectedQuarter,
      'customQuarter': _customQuarter,
      // Teaching Focus
      'selectedTutoringAreas': _selectedTutoringAreas,
      'selectedLearnerLevels': _selectedLearnerLevels,
      // Specializations
      'selectedSpecializations': _selectedSpecializations,
      // Experience
      'hasExperience': _hasExperience,
      'experienceDuration': _experienceDuration,
      'previousOrganization': _previousOrganizationController.text,
      'taughtLevels': _taughtLevels,
      'motivation': _motivationController.text,
      // Teaching Style
      'preferredMode': _preferredMode,
      'teachingApproaches': _teachingApproaches,
      'preferredSessionType': _preferredSessionType,
      'handlesMultipleLearners': _handlesMultipleLearners,
      'hoursPerWeek': _hoursPerWeek,
      // Digital Readiness
      'devices': _devices,
      'hasInternet': _hasInternet,
      'teachingTools': _teachingTools,
      'hasMaterials': _hasMaterials,
      'wantsTraining': _wantsTraining,
      // Availability
      'tutoringAvailability': _tutoringAvailability,
      'testSessionAvailability': _testSessionAvailability,
      // Payment
      'paymentMethod': _paymentMethod,
      'paymentNumber': _paymentNumberController.text,
      'paymentName': _paymentNameController.text,
      'bankDetails': _bankDetailsController.text,
      'expectedRate': _expectedRate,
      'pricingFactors': _pricingFactors,
      'agreesToPaymentPolicy': _agreesToPaymentPolicy,
      // Verification
      'agreesToVerification': _agreesToVerification,
      'videoLink': _videoLinkController.text,
      'socialMediaLinks': _socialMediaLinks,
      // Personal Statement
      'statement': _statementController.text,
      // Affirmations
      'affirmations': _affirmations,
      // Document URLs (from _uploadedDocuments)
      'uploadedDocuments': _uploadedDocuments,
      // Legacy URLs (for backward compatibility)
      'profilePhotoUrl': _profilePhotoUrl,
      'idCardFrontUrl': _idCardFrontUrl,
      'idCardBackUrl': _idCardBackUrl,
    };
    await prefs.setString('tutor_onboarding_data', jsonEncode(data));
    print('✅ Auto-saved tutor onboarding data (comprehensive)');
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDataString = prefs.getString('tutor_onboarding_data');

    if (savedDataString != null) {
      try {
        final data = jsonDecode(savedDataString) as Map<String, dynamic>;
        setState(() {
          _currentStep = data['currentStep'] ?? 0;
          // Contact Information
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _authMethod = data['authMethod'] ?? 'phone';
          // Academic Background
          _selectedEducation = data['selectedEducation'];
          _institutionController.text = data['institution'] ?? '';
          _fieldOfStudyController.text = data['fieldOfStudy'] ?? '';
          _hasTraining = data['hasTraining'] ?? false;
          // Location
          _selectedCity = data['selectedCity'];
          _selectedQuarter = data['selectedQuarter'];
          _customQuarter = data['customQuarter'] ?? '';
          // Teaching Focus
          _selectedTutoringAreas = List<String>.from(
            data['selectedTutoringAreas'] ?? [],
          );
          _selectedLearnerLevels = List<String>.from(
            data['selectedLearnerLevels'] ?? [],
          );
          // Specializations
          _selectedSpecializations = List<String>.from(
            data['selectedSpecializations'] ?? [],
          );
          // Experience
          _hasExperience = data['hasExperience'] ?? false;
          _experienceDuration = data['experienceDuration'];
          _previousOrganizationController.text =
              data['previousOrganization'] ?? '';
          _taughtLevels = List<String>.from(data['taughtLevels'] ?? []);
          _motivationController.text = data['motivation'] ?? '';
          // Teaching Style
          _preferredMode = data['preferredMode'];
          _teachingApproaches = List<String>.from(
            data['teachingApproaches'] ?? [],
          );
          _preferredSessionType = data['preferredSessionType'];
          _handlesMultipleLearners = data['handlesMultipleLearners'] ?? false;
          _hoursPerWeek = data['hoursPerWeek'];
          // Digital Readiness
          _devices = List<String>.from(data['devices'] ?? []);
          _hasInternet = data['hasInternet'] ?? false;
          _teachingTools = List<String>.from(data['teachingTools'] ?? []);
          _hasMaterials = data['hasMaterials'] ?? false;
          _wantsTraining = data['wantsTraining'] ?? false;
          // Availability
          if (data['tutoringAvailability'] != null) {
            _tutoringAvailability = Map<String, List<String>>.from(
              (data['tutoringAvailability'] as Map).map(
                (key, value) =>
                    MapEntry(key.toString(), List<String>.from(value as List)),
              ),
            );
          }
          if (data['testSessionAvailability'] != null) {
            _testSessionAvailability = Map<String, List<String>>.from(
              (data['testSessionAvailability'] as Map).map(
                (key, value) =>
                    MapEntry(key.toString(), List<String>.from(value as List)),
              ),
            );
          }
          // Payment
          _paymentMethod = data['paymentMethod'];
          _paymentNumberController.text = data['paymentNumber'] ?? '';
          _paymentNameController.text = data['paymentName'] ?? '';
          _bankDetailsController.text = data['bankDetails'] ?? '';
          _expectedRate = data['expectedRate'];
          _pricingFactors = List<String>.from(data['pricingFactors'] ?? []);
          _agreesToPaymentPolicy = data['agreesToPaymentPolicy'] ?? false;
          // Verification
          _agreesToVerification = data['agreesToVerification'] ?? false;
          _videoLinkController.text = data['videoLink'] ?? '';
          if (data['socialMediaLinks'] != null) {
            _socialMediaLinks = Map<String, String>.from(
              (data['socialMediaLinks'] as Map).map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              ),
            );
          }
          // Personal Statement
          _statementController.text = data['statement'] ?? '';
          // Affirmations
          if (data['affirmations'] != null) {
            _affirmations = Map<String, bool>.from(
              (data['affirmations'] as Map).map(
                (key, value) => MapEntry(key.toString(), value as bool),
              ),
            );
          }
          // Document URLs
          if (data['uploadedDocuments'] != null) {
            _uploadedDocuments = Map<String, dynamic>.from(
              (data['uploadedDocuments'] as Map).map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            );
          }
          // Legacy URLs (for backward compatibility)
          _profilePhotoUrl = data['profilePhotoUrl'];
          _idCardFrontUrl = data['idCardFrontUrl'];
          _idCardBackUrl = data['idCardBackUrl'];
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
  final _phoneController = TextEditingController();
  String? _authMethod; // 'email' or 'phone'

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
  final Map<int, TabController> _specializationTabControllers = {};

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
  String _selectedDay = 'Monday'; // Currently selected day for availability
  String _selectedDocumentType =
      'profile_picture'; // Currently selected document type

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
      resizeToAvoidBottomInset: true,
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
          preferredSize: const Size.fromHeight(40),
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
              // const SizedBox(height: 4),
              // Padding(
              //   padding: const EdgeInsets.symmetric(horizontal: 20),
              //   child: Text(
              //     'Your progress is automatically saved. You can continue anytime.',
              //     style: GoogleFonts.poppins(
              //       fontSize: 11,
              //       color: AppTheme.textLight,
              //       fontStyle: FontStyle.italic,
              //     ),
              //     textAlign: TextAlign.center,
              //   ),
              // ),
              // const SizedBox(height: 8),
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
          _buildSpecializationsStep(),
          _buildExperienceStep(),
          _buildTeachingStyleStep(),
          _buildDigitalReadinessStep(),
          _buildAvailabilityStep(),
          _buildExpectationsStep(), // Step 9: Expected rate + pricing factors
          _buildPaymentStep(), // Step 10: Payment method + details
          _buildVerificationStep(),
          _buildMediaLinksStep(),
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
                      ? (_areAllAgreementsChecked() ? _submitApplication : null)
                      : _canProceedFromCurrentStep()
                      ? _nextStep
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentStep == _totalSteps - 1
                        ? (_areAllAgreementsChecked()
                              ? AppTheme.primaryColor
                              : AppTheme.neutral200)
                        : (_canProceedFromCurrentStep()
                              ? AppTheme.primaryColor
                              : AppTheme.neutral200),
                    foregroundColor: _currentStep == _totalSteps - 1
                        ? (_areAllAgreementsChecked()
                              ? Colors.white
                              : AppTheme.textLight)
                        : (_canProceedFromCurrentStep()
                              ? Colors.white
                              : AppTheme.textLight),
                    elevation:
                        (_currentStep == _totalSteps - 1
                            ? _areAllAgreementsChecked()
                            : _canProceedFromCurrentStep())
                        ? 2
                        : 0,
                    shadowColor:
                        (_currentStep == _totalSteps - 1
                            ? _areAllAgreementsChecked()
                            : _canProceedFromCurrentStep())
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
            _authMethod == 'email'
                ? 'We need your phone number for important notifications'
                : 'We need your email for important notifications',
            _authMethod == 'email'
                ? Icons.phone_outlined
                : Icons.email_outlined,
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
                    _authMethod == 'email'
                        ? 'We\'ll send your approval status and important updates to this phone number'
                        : 'We\'ll send your approval status and important updates to this email',
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

          // Phone or Email Input (based on auth method)
          _authMethod == 'email'
              ? _buildInputField(
                  controller: _phoneController,
                  label: 'Phone Number(WhatsApp)',
                  hint: '6 53 30 19 97',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    // Format phone number
                    String phone = value.trim().replaceAll(
                      RegExp(r'[\s\-]'),
                      '',
                    );
                    if (phone.startsWith('0')) {
                      phone = phone.substring(1);
                    }
                    if (!_isValidPhoneNumber(phone)) {
                      return 'Please enter a valid phone number (9 digits)';
                    }
                    return null;
                  },
                )
              : _buildInputField(
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
        ],
      ),
    );
  }

  // NEW STEP: Specializations with tabs
  Widget _buildSpecializationsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Specializations',
            'What subjects can you teach?',
            Icons.school,
            hasRequiredFields: true,
          ),
          const SizedBox(height: 32),

          // Show specializations with tabs
          if (_selectedTutoringAreas.isNotEmpty &&
              _selectedLearnerLevels.isNotEmpty)
            _buildDynamicSpecializations(),

          // Show message if prerequisites not met
          if (_selectedTutoringAreas.isEmpty || _selectedLearnerLevels.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please select tutoring areas and learner levels in the previous step first.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.orange[900],
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

  Widget _buildDynamicSpecializations() {
    Map<String, List<String>> categorizedSpecs =
        _getCategorizedSpecializations();

    // If only one category, show simple list
    if (categorizedSpecs.length <= 1) {
      List<String> specializationOptions = _getSpecializationOptions();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // All specializations in one grid
          _buildSelectionChips(
            options: specializationOptions,
            selectedValue: _selectedSpecializations,
            onSelectionChanged: (values) =>
                setState(() => _selectedSpecializations = values),
          ),

          const SizedBox(height: 24),

          // Custom Specialization Input
          _buildInputField(
            controller: _customSpecializationController,
            label: 'Other Specializations',
            hint: 'Add here (comma-separated)',
            icon: Icons.add_circle_outline,
          ),
        ],
      );
    }

    // Multiple categories - create tab controller for them
    late TabController tabController;
    if (_specializationTabControllers.containsKey(categorizedSpecs.length)) {
      tabController = _specializationTabControllers[categorizedSpecs.length]!;
      if (tabController.length != categorizedSpecs.length) {
        tabController.dispose();
        tabController = TabController(
          length: categorizedSpecs.length,
          vsync: this,
        );
        _specializationTabControllers[categorizedSpecs.length] = tabController;
      }
    } else {
      tabController = TabController(
        length: categorizedSpecs.length,
        vsync: this,
      );
      _specializationTabControllers[categorizedSpecs.length] = tabController;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Segmented Control Style Tabs
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: tabController,
            isScrollable: false,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textMedium,
            indicator: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            labelStyle: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            tabs: categorizedSpecs.keys.map((category) {
              // Convert category names to two lines ONLY when there are 3 tabs
              String displayText = category;
              if (categorizedSpecs.length == 3) {
                if (category == 'AcademicTutoring') {
                  displayText = 'Academic\nTutoring';
                } else if (category == 'ExamPreparation') {
                  displayText = 'Exam\nPreparation';
                } else if (category == 'SkillDevelopment') {
                  displayText = 'Skill\nDevelopment';
                }
              }
              return Tab(
                child: Text(
                  displayText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 10),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // Tab Views with specializations
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: tabController,
            children: categorizedSpecs.entries.map((entry) {
              return SingleChildScrollView(
                child: _buildSelectionChips(
                  options: entry.value,
                  selectedValue: _selectedSpecializations,
                  onSelectionChanged: (values) =>
                      setState(() => _selectedSpecializations = values),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 24),

        // Custom Specialization Input
        _buildInputField(
          controller: _customSpecializationController,
          label: 'Other Specializations',
          hint: 'Add here (comma-separated)',
          icon: Icons.add_circle_outline,
        ),
      ],
    );
  }

  /// Get specializations categorized by tutoring area
  Map<String, List<String>> _getCategorizedSpecializations() {
    Map<String, List<String>> categorized = {};

    for (String area in _selectedTutoringAreas) {
      List<String> specs = AppData.getSpecializationsForTutoringArea(
        area,
        _selectedLearnerLevels,
      );

      if (specs.isNotEmpty) {
        // Use area as category name
        String categoryName = area.replaceAll(' ', '');
        categorized[categoryName] = specs.toSet().toList();
      }
    }

    return categorized;
  }

  /// Build selection chips for tab view
  Widget _buildSelectionChips({
    required List<String> options,
    required List<String> selectedValue,
    required Function(List<String>) onSelectionChanged,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.map((option) {
        final isSelected = selectedValue.contains(option);
        return GestureDetector(
          onTap: () {
            final newSelection = List<String>.from(selectedValue);
            if (isSelected) {
              newSelection.remove(option);
            } else {
              newSelection.add(option);
            }
            onSelectionChanged(newSelection);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.add_circle_outline,
                  size: isSelected ? 18 : 16,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  option,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputField(
                controller: _motivationController,
                label: 'What motivates you to teach?',
                hint:
                    'Tell us what drives your passion for teaching... (at least 20 characters)',
                icon: Icons.psychology,
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              // Validation message
              Builder(
                builder: (context) {
                  final motivationText = _motivationController.text.trim();
                  if (motivationText.isEmpty) {
                    return Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Motivation is required',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    );
                  } else if (motivationText.length < 20) {
                    return Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Please write at least 20 characters (${motivationText.length}/20)',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              // Show missing fields if has experience
              if (_hasExperience) ...[
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    List<String> missingFields = [];
                    if (_experienceDuration == null) {
                      missingFields.add('Teaching duration');
                    }
                    if (_previousOrganizationController.text.trim().isEmpty) {
                      missingFields.add('Previous organization');
                    }
                    if (_taughtLevels.isEmpty) {
                      missingFields.add('Levels taught');
                    }
                    if (missingFields.isNotEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Please complete:',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange[900],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...missingFields.map(
                                    (field) => Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        '• $field',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.orange[900],
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
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ],
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

    // Grouped time ranges for better UX
    final List<String> morningSlots = [
      '6:00 AM',
      '7:00 AM',
      '8:00 AM',
      '9:00 AM',
      '10:00 AM',
      '11:00 AM',
    ];

    final List<String> afternoonSlots = [
      '12:00 PM',
      '1:00 PM',
      '2:00 PM',
      '3:00 PM',
      '4:00 PM',
      '5:00 PM',
    ];

    final List<String> eveningSlots = [
      '6:00 PM',
      '7:00 PM',
      '8:00 PM',
      '9:00 PM',
      '10:00 PM',
      '11:00 PM',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set your weekly availability',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select the time slots when you\'re available each day',
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 20),

        // Day selector tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: days.map((day) {
              final currentAvailability = _getCurrentAvailability();
              final selectedSlots = currentAvailability[day] ?? [];
              final isSelected = day == _selectedDay;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : (selectedSlots.isNotEmpty
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : AppTheme.softCard),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : (selectedSlots.isNotEmpty
                                  ? AppTheme.primaryColor
                                  : AppTheme.softBorder),
                        width: isSelected || selectedSlots.isNotEmpty ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          day.substring(0, 3),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : (selectedSlots.isNotEmpty
                                      ? AppTheme.primaryColor
                                      : AppTheme.textDark),
                          ),
                        ),
                        if (selectedSlots.isNotEmpty && !isSelected) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),

        // Day content card for selected day only
        Builder(
          builder: (context) {
            final day = _selectedDay;
            final currentAvailability = _getCurrentAvailability();
            final selectedSlots = currentAvailability[day] ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selectedSlots.isNotEmpty
                      ? AppTheme.primaryColor
                      : AppTheme.softBorder,
                  width: selectedSlots.isNotEmpty ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selectedSlots.isNotEmpty
                              ? AppTheme.primaryColor
                              : AppTheme.softCard,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          day,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: selectedSlots.isNotEmpty
                                ? Colors.white
                                : AppTheme.textDark,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (selectedSlots.isNotEmpty)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Morning time slots
                  _buildTimeSlotSection(
                    'Morning',
                    morningSlots,
                    day,
                    Icons.wb_sunny_outlined,
                    Colors.orange,
                  ),
                  const SizedBox(height: 16),

                  // Afternoon time slots
                  _buildTimeSlotSection(
                    'Afternoon',
                    afternoonSlots,
                    day,
                    Icons.wb_twilight_outlined,
                    Colors.amber,
                  ),
                  const SizedBox(height: 16),

                  // Evening time slots
                  _buildTimeSlotSection(
                    'Evening',
                    eveningSlots,
                    day,
                    Icons.nightlight_outlined,
                    Colors.indigo,
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // Helper text
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You can select multiple time slots per day. Students will see these as your available times.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotSection(
    String label,
    List<String> slots,
    String day,
    IconData icon,
    Color iconColor,
  ) {
    final currentAvailability = _getCurrentAvailability();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) {
            final isSelected =
                currentAvailability[day]?.contains(slot) ?? false;

            return GestureDetector(
              onTap: () {
                setState(() {
                  final currentAvailability = _getCurrentAvailability();
                  currentAvailability[day] ??= [];
                  if (isSelected) {
                    currentAvailability[day]!.remove(slot);
                  } else {
                    currentAvailability[day]!.add(slot);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.softCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.softBorder,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  slot,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Map<String, List<String>> _getCurrentAvailability() {
    return _selectedServiceType == 'tutoring'
        ? _tutoringAvailability
        : _testSessionAvailability;
  }

  Widget _buildExpectationsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Payment Expectations',
            'Set your expected rate and pricing factors',
            Icons.trending_up,
          ),
          const SizedBox(height: 32),

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
            onSelectionChanged: (value) {
              setState(() => _expectedRate = value);
              _saveData(); // Auto-save when rate changes
            },
            isSingleSelection: true,
          ),

          const SizedBox(height: 24),

          // Detailed Pricing Factors
          _buildDetailedPricingFactors(),
        ],
      ),
    );
  }

  Widget _buildPaymentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Payment Method',
            'How would you like to receive payments?',
            Icons.payment,
          ),
          const SizedBox(height: 32),

          // Payment Method Selection Cards with info icon
          Row(
            children: [
              Text(
                'Payment Method',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InstructionScreen(
                        title: 'Payment Method Instructions',
                        icon: Icons.payment,
                        content:
                            'Choose how you would like to receive payments from PrepSkul.\n\nMTN Mobile Money:\n\n• Enter your 9-digit MTN Mobile Money number\n• Ensure the number is registered and active\n• Provide the exact name on the account\n\nOrange Money:\n\n• Enter your 9-digit Orange Money number\n• Ensure the number is registered and active\n• Provide the exact name on the account\n\nBank Transfer:\n\n• Provide your complete bank account details\n• Include: Account Number, Bank Name, and Account Holder Name\n• Ensure all information is accurate for transfers\n\nAll payment methods are secure and payments are processed monthly.',
                      ),
                    ),
                  );
                },
                child: Icon(
                  Icons.info_outline,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          _buildSelectionCards(
            title: '',
            options: ['MTN Mobile Money', 'Orange Money', 'Bank Transfer'],
            selectedValue: _paymentMethod,
            onSelectionChanged: (value) {
              setState(() => _paymentMethod = value);
              _saveData(); // Auto-save when payment method changes
            },
            isSingleSelection: true,
          ),

          const SizedBox(height: 24),

          // Dynamic Payment Details based on method
          if (_paymentMethod != null) _buildDynamicPaymentDetails(),

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
          onSelectionChanged: (values) {
            setState(() => _pricingFactors = values);
            _saveData(); // Auto-save when pricing factors change
          },
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InstructionScreen(
                    title: 'PrepSkul Payment Process',
                    icon: Icons.payment,
                    content:
                        'Please note:\n\n1) All payments from learners are handled securely through PrepSkul.\n\n2) After each confirmed session, tutor earnings first appear in a Pending Balance for verification.\n\n3) Once the session is confirmed and no issues are reported, the amount moves to your Active Balance.\n\n4) Tutors can withdraw from their Active Balance at the end of each month.\n\nIn case of complaints or cancellations, PrepSkul may review and adjust payments fairly for all parties.',
                  ),
                ),
              );
            },
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
        ],
      ),
    );
  }

  Widget _buildMediaLinksStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Media & Links',
            'Add your social media links and video introduction',
            Icons.link,
          ),
          const SizedBox(height: 32),

          // Info box with instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
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
                    Expanded(
                      child: Text(
                        'Instructions',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• You must add at least 1 social media link\n• You must include a valid YouTube video link\n• These help learners get to know you better',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textMedium,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Social Media Links with Icons
          _buildSocialMediaLinks(),

          const SizedBox(height: 32),

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

    // Always add last official certificate (for any education level)
    // This can be a transcript, diploma, certificate slip, etc.
    requiredDocs.add({
      'type': 'last_certificate',
      'title': 'Last Official Certificate',
      'description':
          'Your latest official certificate (slip, transcript, or diploma)',
    });

    // Make sure _selectedDocumentType is valid
    if (!requiredDocs.any((doc) => doc['type'] == _selectedDocumentType)) {
      _selectedDocumentType = requiredDocs.first['type']!;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Required Documents',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select a document type and upload',
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 20),

        // Document type selector tabs (horizontal slider)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: requiredDocs.map((doc) {
              final docType = doc['type']!;
              final isUploaded = _uploadedDocuments[docType] != null;
              final isSelected = docType == _selectedDocumentType;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDocumentType = docType),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : (isUploaded
                                ? AppTheme.primaryColor.withOpacity(0.1)
                                : AppTheme.softCard),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : (isUploaded
                                  ? AppTheme.primaryColor
                                  : AppTheme.softBorder),
                        width: isSelected || isUploaded ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getDocumentIcon(docType),
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : (isUploaded
                                    ? AppTheme.primaryColor
                                    : AppTheme.textDark),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          doc['title']!.length > 15
                              ? doc['title']!.substring(0, 12) + '...'
                              : doc['title']!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : (isUploaded
                                      ? AppTheme.primaryColor
                                      : AppTheme.textDark),
                          ),
                        ),
                        if (isUploaded && !isSelected) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),

        // Selected document upload card
        _buildSelectedDocumentUploadCard(
          requiredDocs.firstWhere(
            (doc) => doc['type'] == _selectedDocumentType,
          ),
        ),
      ],
    );
  }

  /// Build upload preview thumbnail (image or PDF icon)
  Widget _buildUploadPreview(String docType) {
    final uploadedUrl = _uploadedDocuments[docType];
    if (uploadedUrl == null) return const SizedBox.shrink();

    // Document types that are typically PDFs/non-images
    final isDocumentType = [
      'degree_certificate',
      'training_certificate',
      'last_certificate',
    ].contains(docType);

    // Document types that are typically images
    final isImageType = [
      'profile_picture',
      'id_front',
      'id_back',
    ].contains(docType);

    // Check URL extension to determine file type
    final urlLower = uploadedUrl.toString().toLowerCase();
    final isPdfUrl = urlLower.contains('.pdf');
    final isImageUrl =
        urlLower.contains('.jpg') ||
        urlLower.contains('.jpeg') ||
        urlLower.contains('.png') ||
        urlLower.contains('.gif') ||
        urlLower.contains('.webp');

    // Determine if we should show image or document icon
    final shouldShowImage =
        (isImageType && !isPdfUrl) ||
        (isImageUrl && !isPdfUrl && !isDocumentType);

    if (shouldShowImage) {
      // Show image thumbnail
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.softBorder, width: 1),
          color: Colors.white,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            uploadedUrl.toString(),
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // If image fails to load, show document icon instead
              return _buildDocumentIcon();
            },
          ),
        ),
      );
    } else {
      // Show PDF/document icon for PDFs and other documents
      return _buildDocumentIcon();
    }
  }

  /// Build document icon widget (for PDFs and other non-image documents)
  Widget _buildDocumentIcon() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.softBorder, width: 1),
        color: AppTheme.softCard,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf, color: Colors.red[600], size: 32),
          const SizedBox(height: 4),
          Text(
            'PDF',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDocumentUploadCard(Map<String, dynamic> doc) {
    final docType = doc['type']!;
    final isUploaded = _uploadedDocuments[docType] != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUploaded ? AppTheme.primaryColor : AppTheme.softBorder,
          width: isUploaded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUploaded ? AppTheme.primaryColor : AppTheme.softCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getDocumentIcon(docType),
                  color: isUploaded ? Colors.white : AppTheme.primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['title']!,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doc['description']!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUploaded)
                Icon(
                  Icons.check_circle,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Upload preview or upload button
          if (isUploaded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.softCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.softBorder),
              ),
              child: Row(
                children: [
                  // Image preview thumbnail
                  _buildUploadPreview(docType),
                  const SizedBox(width: 16),
                  // Success message and reupload button in a column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Success message
                        Row(
                          children: [
                            // Icon(
                            //   Icons.check_circle,
                            //   color: Colors.green,
                            //   size: 20,
                            // ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Document uploaded successfully',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Reupload button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _uploadDocument(docType),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Reupload'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _uploadDocument(docType),
                icon: const Icon(Icons.cloud_upload),
                label: Text(
                  // For certificate types, use generic "Upload Document" text
                  (docType == 'last_certificate' ||
                          docType == 'degree_certificate' ||
                          docType == 'training_certificate')
                      ? 'Upload Document'
                      : 'Upload ${doc['title']}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
      case 'last_certificate':
        return Icons.workspace_premium;
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
                'Social Media & Professional Links',
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
                            color: AppTheme.primaryColor,
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
        const SizedBox(height: 8),
        Text(
          'This helps us and potential learners get to know you better',
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textMedium),
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InstructionScreen(
                            title: 'Video Introduction Instructions',
                            icon: Icons.video_call,
                            content:
                                'To complete your application, please share a short introductory video (1–3 minutes). This helps us and potential learners get to know you better — your teaching style, confidence, and communication approach. Don\'t worry, it\'s not an exam. Just be yourself!\n\n✅ What to do:\n\n1. Record a short video (1–3 minutes) introducing yourself.\n2. Answer the 5 guiding questions below.\n3. Upload the video to YouTube (Unlisted)\n4. Paste your video link in the field below.\n\nNeed help uploading your video on YouTube?\n\n1. Open YouTube and sign in.\n2. Tap the "+" icon → Upload a video.\n3. Choose your video.\n4. Under "Visibility," select Unlisted (so only people with the link can see it).\n5. Copy the link and paste it below.\n\nGuiding Questions for the Video:\n\n1. Who are you, and what subjects or skills do you teach best?\n2. Why do you enjoy teaching or tutoring?\n3. What makes your approach unique or effective?\n4. How do you help learners overcome challenges or build confidence?\n5. Why do you think you\'d be a great fit for PrepSkul?',
                          ),
                        ),
                      );
                    },
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
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
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.softCard,
                  borderRadius: BorderRadius.circular(10),
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
                        size: 18,
                      ),
                    if (isSelected) const SizedBox(width: 6),
                    Text(
                      option,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
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
                  color: AppTheme.primaryColor,
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
            fontSize: 15,
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
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
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
          const SizedBox(width: 10),
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
      case 0: // Contact Information
        // Validate based on auth method
        if (_authMethod == 'email') {
          return _phoneController.text
                  .trim()
                  .replaceAll(RegExp(r'[\s\-]'), '')
                  .length >=
              9;
        } else {
          return _emailController.text.trim().isNotEmpty &&
              _isValidEmail(_emailController.text.trim());
        }
      case 1: // Academic Background
        return _selectedEducation != null &&
            _institutionController.text.isNotEmpty &&
            _fieldOfStudyController.text.isNotEmpty;
      case 2: // Location
        return _selectedCity != null &&
            (_selectedQuarter != null ||
                (_isCustomQuarter &&
                    _customQuarter != null &&
                    _customQuarter!.isNotEmpty));
      case 3: // Teaching Focus
        return _selectedTutoringAreas.isNotEmpty &&
            _selectedLearnerLevels.isNotEmpty;
      case 4: // Specializations
        return _selectedSpecializations.isNotEmpty;
      case 5: // Experience
        // Motivation is always required with minimum length
        final motivationText = _motivationController.text.trim();
        final hasValidMotivation =
            motivationText.isNotEmpty && motivationText.length >= 20;

        if (_hasExperience) {
          // If they have experience, require all experience fields + motivation
          return _experienceDuration != null &&
              _previousOrganizationController.text.trim().isNotEmpty &&
              _taughtLevels.isNotEmpty &&
              hasValidMotivation;
        } else {
          // If no experience, just require motivation
          return hasValidMotivation;
        }
      case 6: // Teaching Style
        return _preferredMode != null &&
            _teachingApproaches.isNotEmpty &&
            _preferredSessionType != null &&
            _hoursPerWeek != null;
      case 7: // Digital Readiness - _hasInternet defaults to false, so no validation needed
        return true; // No required fields
      case 8: // Availability
        // Must have at least 1 tutoring slot and 1 test session slot
        // Check that both service types have at least one day with time slots
        bool hasTutoringSlots = false;
        bool hasTestSlots = false;

        // Check tutoring availability
        for (var daySlots in _tutoringAvailability.values) {
          if (daySlots.isNotEmpty) {
            hasTutoringSlots = true;
            break;
          }
        }

        // Check test session availability
        for (var daySlots in _testSessionAvailability.values) {
          if (daySlots.isNotEmpty) {
            hasTestSlots = true;
            break;
          }
        }

        return hasTutoringSlots && hasTestSlots;
      case 9: // Expectations - Must select expected rate
        if (_expectedRate == null || _expectedRate!.isEmpty) {
          return false;
        }
        return true;
      case 10: // Payment - All fields are required
        // Must select payment method
        if (_paymentMethod == null || _paymentMethod!.isEmpty) {
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
      case 11: // Verification
        // Must agree to verification
        if (!_agreesToVerification) {
          return false;
        }

        // Check that all required documents are uploaded
        List<String> requiredDocTypes = [
          'profile_picture',
          'id_front',
          'id_back',
          'last_certificate',
        ];

        // Add degree certificate if applicable
        if (_selectedEducation != null &&
            [
              'Bachelors',
              'Master\'s',
              'Doctorate',
              'PHD',
            ].contains(_selectedEducation)) {
          requiredDocTypes.add('degree_certificate');
        }

        // Add training certificate if applicable
        if (_hasTraining) {
          requiredDocTypes.add('training_certificate');
        }

        // Check all required documents are uploaded
        for (String docType in requiredDocTypes) {
          if (!_uploadedDocuments.containsKey(docType)) {
            return false;
          }
        }

        return true;
      case 12: // Media Links
        // Must have at least 1 social media link and valid YouTube video
        bool hasSocialLink = _socialMediaLinks.values.any(
          (link) => link.isNotEmpty,
        );
        bool hasVideoLink =
            _videoLinkController.text.trim().isNotEmpty &&
            _isValidYouTubeUrl(_videoLinkController.text.trim());
        return hasSocialLink && hasVideoLink;
      case 13: // Personal Statement
        // Check if all affirmations are checked
        return _areAllAgreementsChecked();
      default:
        return true;
    }
  }

  /// Check if all final agreements/affirmations are checked
  bool _areAllAgreementsChecked() {
    // Check all 5 affirmations
    return _affirmations['professionalism'] == true &&
        _affirmations['dedication'] == true &&
        _affirmations['payment_understanding'] == true &&
        _affirmations['no_external_payments'] == true &&
        _affirmations['truthful_information'] == true;
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
      // Show image picker bottom sheet (returns XFile or File)
      final dynamic pickedFile = await showModalBottomSheet(
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
      // DEBUG: Use test user ID if not authenticated
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] ?? 'test-user-123'; // DEBUG MODE

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
              Expanded(
                child: Text(
                  'Upload failed: ${e.toString().replaceAll('Exception: ', '')}',
                  style: GoogleFonts.poppins(),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
                          color: AppTheme.primaryColor,
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

      // Format phone if needed
      String? phoneNumber;
      if (_authMethod == 'email' && _phoneController.text.isNotEmpty) {
        String phone = _phoneController.text.trim().replaceAll(
          RegExp(r'[\s\-]'),
          '',
        );
        if (phone.startsWith('0')) {
          phone = phone.substring(1);
        }
        phoneNumber = '+237$phone';
      }

      // Save to database (pass email or phone based on auth method)
      String? contactInfo = _authMethod == 'email'
          ? phoneNumber
          : _emailController.text.trim();

      await SurveyRepository.saveTutorSurvey(
        userId,
        tutorData,
        contactInfo, // Email if phone auth, phone if email auth
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
            content: Text(
              'Error submitting application: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  /// Extract numeric value from hourly rate string like "3,000 – 4,000 XAF"
  /// Returns the midpoint or a reasonable value for "Above 5,000 XAF"
  double? _extractHourlyRateValue(String rateString) {
    try {
      // Remove commas and "XAF" text
      final cleanString = rateString
          .replaceAll(',', '')
          .replaceAll('XAF', '')
          .trim();

      // Handle "Above 5,000" case
      if (cleanString.toLowerCase().contains('above')) {
        final numbers = RegExp(r'\d+').allMatches(cleanString);
        if (numbers.isNotEmpty) {
          final baseValue = double.parse(numbers.first.group(0)!);
          return baseValue * 1.2; // 20% above the base
        }
        return 6000.0; // Default for "Above 5,000"
      }

      // Extract all numbers from range like "3000 – 4000"
      final numbers = RegExp(r'\d+').allMatches(cleanString);
      if (numbers.length >= 2) {
        final min = double.parse(numbers.first.group(0)!);
        final max = double.parse(numbers.last.group(0)!);
        return (min + max) / 2; // Return midpoint
      } else if (numbers.length == 1) {
        return double.parse(numbers.first.group(0)!);
      }
    } catch (e) {
      print('⚠️ Error parsing hourly rate: $e');
    }
    return null;
  }

  Map<String, dynamic> _prepareTutorData() {
    // Combine both availability maps
    final combinedAvailability = <String, List<String>>{};
    _tutoringAvailability.forEach((day, times) {
      combinedAvailability[day] = times;
    });

    // Get document URLs from _uploadedDocuments (primary source) or fallback to individual variables
    final profilePhotoUrl =
        _uploadedDocuments['profile_picture'] as String? ?? _profilePhotoUrl;
    final idCardFrontUrl =
        _uploadedDocuments['id_front'] as String? ?? _idCardFrontUrl;
    final idCardBackUrl =
        _uploadedDocuments['id_back'] as String? ?? _idCardBackUrl;

    // Prepare previous roles - include organization if provided
    final previousRoles =
        _hasExperience && _previousOrganizationController.text.trim().isNotEmpty
        ? [_previousOrganizationController.text.trim()]
        : [];

    // Prepare payment details - ensure it's not empty if payment method is selected
    Map<String, dynamic> paymentDetails = {};
    if (_paymentMethod == 'MTN Mobile Money' ||
        _paymentMethod == 'Orange Money') {
      // Both require phone and name
      if (_paymentNumberController.text.trim().isNotEmpty &&
          _paymentNameController.text.trim().isNotEmpty) {
        paymentDetails = {
          'phone': _paymentNumberController.text.trim(),
          'name': _paymentNameController.text.trim(),
        };
      }
    } else if (_paymentMethod == 'Bank Transfer') {
      if (_bankDetailsController.text.trim().isNotEmpty) {
        paymentDetails = {'bank_details': _bankDetailsController.text.trim()};
      }
    }

    // If payment method is selected but details are missing, still include method in map
    // This helps with validation but won't pass final validation
    if (paymentDetails.isEmpty && _paymentMethod != null) {
      paymentDetails = {'method': _paymentMethod}; // Temporary marker
    }

    return {
      // Personal Info
      // Note: email is saved separately to profiles table, not tutor_profiles
      'profile_photo_url': profilePhotoUrl,
      'city': _selectedCity,
      'quarter': _selectedQuarter ?? _customQuarter,
      'bio': _motivationController.text.trim().isNotEmpty
          ? _motivationController.text.trim()
          : null, // Use motivation as bio
      // Academic Background
      'highest_education': _selectedEducation,
      'institution': _institutionController.text.trim(),
      'field_of_study': _fieldOfStudyController.text.trim(),
      'certifications': _certificateUrls.isNotEmpty
          ? _certificateUrls
          : null, // JSONB format
      'certifications_array': _certificateUrls.isNotEmpty
          ? _certificateUrls.values.toList()
          : null, // TEXT[] format
      // Experience
      'has_teaching_experience': _hasExperience,
      'teaching_duration': _experienceDuration,
      'previous_roles': previousRoles, // Include organization name if provided
      'motivation': _motivationController.text.trim(),

      // Tutoring Details
      'tutoring_areas': _selectedTutoringAreas,
      'learner_levels': _selectedLearnerLevels,
      'specializations': _selectedSpecializations,
      'personal_statement': _statementController.text.trim(),

      // Availability
      'hours_per_week': _hoursPerWeek,
      'availability': combinedAvailability,

      // Payment
      'payment_method': _paymentMethod,
      'hourly_rate': _expectedRate != null
          ? _extractHourlyRateValue(_expectedRate!)
          : null,
      // Only include payment_details if it has actual data (not just method marker)
      'payment_details':
          paymentDetails.containsKey('method') && paymentDetails.length == 1
          ? <String, dynamic>{} // Return empty map if only method marker
          : paymentDetails,
      'payment_agreement': _agreesToPaymentPolicy,

      // Verification
      'id_card_front_url': idCardFrontUrl,
      'id_card_back_url': idCardBackUrl,
      'video_link': _videoLinkController.text.trim(),
      'video_url': _videoLinkController.text
          .trim(), // Also map to existing video_url column
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
    _phoneController.dispose();
    _customQuarterController.dispose();
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
    // Dispose all tab controllers
    for (var controller in _specializationTabControllers.values) {
      controller.dispose();
    }
    _specializationTabControllers.clear();
    super.dispose();
  }
}
