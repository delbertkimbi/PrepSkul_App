import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_set_state.dart';
import '../../../core/services/log_service.dart';
import '../../../data/app_data.dart';
import '../../../core/widgets/image_picker_bottom_sheet.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/survey_repository.dart';
import '../../../core/services/profile_completion_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/tutor_onboarding_progress_service.dart';
import '../../../core/widgets/confetti_celebration.dart';
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

  // Debounce timer for saving progress
  Timer? _saveDebounceTimer;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _customQuarterController.addListener(() {
      safeSetState(() {
        _customQuarter = _customQuarterController.text;
      });
    });
    _loadAuthMethod();
    _initializeAndLoadData();
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
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

  Future<void> _loadAuthMethod() async {
    final prefs = await SharedPreferences.getInstance();
    safeSetState(() {
      _authMethod =
          prefs.getString('auth_method') ?? 'phone'; // Default to phone
    });
  }

  // Initialize and load data from database
  Future<void> _initializeAndLoadData() async {
    try {
      final user = await AuthService.getCurrentUser();
      _userId = user['userId'] as String?;
      
      // Check if we should jump to a specific step
      final jumpToStep = widget.basicInfo['jumpToStep'] as int?;
      if (jumpToStep != null && jumpToStep >= 0 && jumpToStep < _totalSteps) {
        _currentStep = jumpToStep;
      }
      
      await _loadSavedData();
      
      // Jump to specific step if requested
      if (jumpToStep != null && jumpToStep >= 0 && jumpToStep < _totalSteps) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.jumpToPage(jumpToStep);
        });
      }
    } catch (e) {
      LogService.error('Error initializing: $e');
      // Fallback to old SharedPreferences method
      await _loadSavedData();
    }
  }

  // Auto-save functionality - saves to database with debouncing
  Future<void> _saveData({bool immediate = false}) async {
    if (_userId == null) {
      // Try to get userId if not set
      try {
        final user = await AuthService.getCurrentUser();
        _userId = user['userId'] as String?;
      } catch (e) {
        LogService.warning('Cannot save: userId not available');
        return;
      }
    }

    // Cancel existing timer
    _saveDebounceTimer?.cancel();

    if (immediate) {
      await _saveToDatabase();
    } else {
      // Debounce: wait 1 second before saving
      _saveDebounceTimer = Timer(const Duration(seconds: 1), () {
        _saveToDatabase();
      });
    }
  }

  // Save current step data to database
  Future<void> _saveToDatabase() async {
    if (_userId == null) return;

    try {
      // Prepare step data for current step
      final stepData = _getCurrentStepData();

      // Save to database
      await TutorOnboardingProgressService.saveStepProgress(
        _userId!,
        _currentStep,
        stepData,
      );

      // Also save all progress data
      final allStepData = _getAllStepData();
      final completedSteps = _getCompletedSteps();
      
      await TutorOnboardingProgressService.saveAllProgress(
        _userId!,
        allStepData,
        _currentStep,
        completedSteps,
      );

      LogService.success('Auto-saved step $_currentStep to database');
    } catch (e) {
      LogService.error('Error saving to database: $e');
    }
  }

  // Save progress and navigate to dashboard (for Save Progress button)
  // Similar to skip onboarding, but saves the progress made so far
  // User can continue later from where they left off
  // CRITICAL: For approved tutors editing their profile, also save to tutor_profiles table
  Future<void> _saveProgress() async {
    if (_userId == null) return;

    try {
      // Cancel any pending debounced saves
      _saveDebounceTimer?.cancel();

      // Save current step data immediately
      final stepData = _getCurrentStepData();
      await TutorOnboardingProgressService.saveStepProgress(
        _userId!,
        _currentStep,
        stepData,
      );

      // Save all progress data
      final allStepData = _getAllStepData();
      final completedSteps = _getCompletedSteps();
      
      await TutorOnboardingProgressService.saveAllProgress(
        _userId!,
        allStepData,
        _currentStep,
        completedSteps,
      );

      // CRITICAL FIX: For approved tutors editing their profile, also save to tutor_profiles table
      // This ensures changes are immediately reflected in the database
      // Check if tutor is approved (either from widget or by checking database)
      final isEditMode = widget.basicInfo['needsImprovement'] == true;
      bool saveToDatabaseSuccess = false;
      bool hasPendingUpdate = false;
      bool isApprovedTutor = false;
      
      // Check tutor status from database to determine if they're approved
      if (_userId != null) {
        try {
          final tutorProfile = await SupabaseService.client
              .from('tutor_profiles')
              .select('status')
              .eq('user_id', _userId!)
              .maybeSingle();
          
          final tutorStatus = tutorProfile?['status'] as String?;
          isApprovedTutor = tutorStatus == 'approved';
          
          LogService.info('📊 Tutor status check - isEditMode: $isEditMode, tutorStatus: $tutorStatus, isApprovedTutor: $isApprovedTutor');
        } catch (e) {
          LogService.warning('Could not check tutor status: $e');
        }
      }
      
      // For approved tutors, ALWAYS save to database (even if not in edit mode from widget)
      // This ensures Save Progress button works for approved tutors
      if (isEditMode || isApprovedTutor) {
        try {
          LogService.info('💾 Saving tutor profile changes to database for approved tutor...');
          
          // Get complete tutor data (all fields)
          final tutorData = _prepareTutorData();
          
          // Get contact info (email or phone) for saveTutorSurvey
          String? contactInfo;
          try {
            final user = await AuthService.getCurrentUser();
            final userEmail = user['email'] as String?;
            final userPhone = user['phone'] as String?;
            contactInfo = userEmail ?? userPhone;
          } catch (e) {
            LogService.warning('Could not get contact info: $e');
          }
          
          // Save to tutor_profiles table using SurveyRepository
          // This ensures availability and all other fields are saved correctly
          LogService.info('💾 Calling SurveyRepository.saveTutorSurvey for user: $_userId');
          await SurveyRepository.saveTutorSurvey(
            _userId!,
            tutorData,
            contactInfo, // Contact info (email or phone)
          );
          
          // Wait a moment for database to update
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Check if the save resulted in a pending update
          final tutorProfile = await SupabaseService.client
              .from('tutor_profiles')
              .select('has_pending_update, status')
              .eq('user_id', _userId!)
              .maybeSingle();
          
          hasPendingUpdate = tutorProfile?['has_pending_update'] as bool? ?? false;
          final currentStatus = tutorProfile?['status'] as String?;
          
          LogService.info('📊 After save - status: $currentStatus, has_pending_update: $hasPendingUpdate');
          
          if (currentStatus == 'approved' && !hasPendingUpdate) {
            LogService.warning('⚠️ WARNING: Tutor is approved but has_pending_update is FALSE. This should be TRUE after editing!');
            // Try to set it manually as a fallback
            try {
              await SupabaseService.client
                  .from('tutor_profiles')
                  .update({'has_pending_update': true})
                  .eq('user_id', _userId!);
              hasPendingUpdate = true;
              LogService.info('✅ Manually set has_pending_update to TRUE as fallback');
            } catch (fallbackError) {
              LogService.error('❌ Failed to set has_pending_update manually: $fallbackError');
            }
          }
          
          saveToDatabaseSuccess = true;
          
          LogService.success('✅ Tutor profile changes saved to database successfully. has_pending_update: $hasPendingUpdate');
        } catch (e, stackTrace) {
          LogService.error('❌ Error saving tutor profile to database: $e');
          LogService.error('Stack trace: $stackTrace');
          saveToDatabaseSuccess = false;
        }
      }

      LogService.success('Progress saved successfully');

      // Show appropriate message based on save result
      if (mounted) {
        if (isEditMode || isApprovedTutor) {
          if (saveToDatabaseSuccess) {
            if (hasPendingUpdate) {
              // Changes saved and marked as pending update
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Update submitted for review',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 4),
                ),
              );
            } else {
              // Changes saved successfully (shouldn't happen for approved tutors, but handle it)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Changes saved successfully!',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: AppTheme.accentGreen,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            // Save to database failed - but still show update submitted message for approved tutors
            if (isApprovedTutor) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Update submitted for review',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 4),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Progress saved, but changes may not be reflected. Please try again.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          // Not edit mode - just show success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Progress saved successfully!',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppTheme.accentGreen,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        // Always navigate to tutor dashboard after saving (for both approved and non-approved)
        // Wait longer for pending update message (4 seconds) vs success (2 seconds)
        final delayDuration = (isEditMode || isApprovedTutor) && hasPendingUpdate 
            ? const Duration(seconds: 4) 
            : const Duration(milliseconds: 500);
            
        Future.delayed(delayDuration, () {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/tutor-nav',
              (route) => false,
            );
          }
        });
      }
    } catch (e) {
      LogService.error('Error saving progress: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving progress. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Save progress and navigate to dashboard
  Future<void> _saveProgressAndExit() async {
    if (_userId == null) return;

    try {
      // Cancel any pending debounced saves
      _saveDebounceTimer?.cancel();

      // Save current step data immediately
      final stepData = _getCurrentStepData();
      await TutorOnboardingProgressService.saveStepProgress(
        _userId!,
        _currentStep,
        stepData,
      );

      // Save all progress data
      final allStepData = _getAllStepData();
      final completedSteps = _getCompletedSteps();
      
      await TutorOnboardingProgressService.saveAllProgress(
        _userId!,
        allStepData,
        _currentStep,
        completedSteps,
      );

      LogService.success('Progress saved before exiting to dashboard');

      // Navigate to tutor dashboard
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/tutor-nav');
      }
    } catch (e) {
      LogService.error('Error saving progress before exit: $e');
      // Still navigate even if save fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Progress saved. You can continue later.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pushReplacementNamed(context, '/tutor-nav');
      }
    }
  }

  // Get data for current step
  Map<String, dynamic> _getCurrentStepData() {
    switch (_currentStep) {
      case 0: // Contact Information
        return {
      'email': _emailController.text,
          'phone': _phoneController.text,
        };
      case 1: // Academic Background
        return {
      'selectedEducation': _selectedEducation,
      'institution': _institutionController.text,
      'fieldOfStudy': _fieldOfStudyController.text,
      'hasTraining': _hasTraining,
        };
      case 2: // Location
        return {
      'selectedCity': _selectedCity,
      'selectedQuarter': _selectedQuarter,
      'customQuarter': _customQuarter,
        };
      case 3: // Teaching Focus
        return {
      'selectedTutoringAreas': _selectedTutoringAreas,
      'selectedLearnerLevels': _selectedLearnerLevels,
        };
      case 4: // Specializations
        return {
      'selectedSpecializations': _selectedSpecializations,
          'customSpecialization': _customSpecializationController.text,
        };
      case 5: // Experience
        return {
      'hasExperience': _hasExperience,
      'experienceDuration': _experienceDuration,
          'previousOrganization': _previousOrganizationController.text,
          'taughtLevels': _taughtLevels,
      'motivation': _motivationController.text,
        };
      case 6: // Teaching Style
        return {
      'preferredMode': _preferredMode,
      'teachingApproaches': _teachingApproaches,
      'preferredSessionType': _preferredSessionType,
          'handlesMultipleLearners': _handlesMultipleLearners,
      'hoursPerWeek': _hoursPerWeek,
        };
      case 7: // Digital Readiness
        return {
          'devices': _devices,
          'hasInternet': _hasInternet,
          'teachingTools': _teachingTools,
          'hasMaterials': _hasMaterials,
          'wantsTraining': _wantsTraining,
        };
      case 8: // Availability
        return {
          'tutoringAvailability': _tutoringAvailability,
          'testSessionAvailability': _testSessionAvailability,
        };
      case 9: // Expectations
        return {
      'expectedRate': _expectedRate,
          'pricingFactors': _pricingFactors,
        };
      case 10: // Payment
        return {
          'paymentMethod': _paymentMethod,
          'paymentNumber': _paymentNumberController.text,
          'paymentName': _paymentNameController.text,
          'bankDetails': _bankDetailsController.text,
      'agreesToPaymentPolicy': _agreesToPaymentPolicy,
        };
      case 11: // Verification
        return {
          'profilePhotoUrl': _profilePhotoUrl,
          'idCardFrontUrl': _idCardFrontUrl,
          'idCardBackUrl': _idCardBackUrl,
          'certificateUrls': _certificateUrls,
      'agreesToVerification': _agreesToVerification,
    };
      case 12: // Media Links
        return {
          'socialMediaLinks': _socialMediaLinks,
          'videoLink': _videoLinkController.text,
        };
      case 13: // Personal Statement
        return {
          'personalStatement': _statementController.text,
          'finalAgreements': _finalAgreements,
        };
      default:
        return {};
    }
  }

  // Get all step data
  Map<String, dynamic> _getAllStepData() {
    final allData = <String, dynamic>{};
    for (int i = 0; i < _totalSteps; i++) {
      final originalStep = _currentStep;
      _currentStep = i;
      allData[i.toString()] = _getCurrentStepData();
      _currentStep = originalStep;
    }
    return allData;
  }

  // Get completed steps
  List<int> _getCompletedSteps() {
    final completed = <int>[];
    for (int i = 0; i < _totalSteps; i++) {
      if (_isStepComplete(i)) {
        completed.add(i);
      }
    }
    return completed;
  }

  // Check if a step is complete
  bool _isStepComplete(int step) {
    switch (step) {
      case 0:
        if (_authMethod == 'email') {
          return _phoneController.text.trim().replaceAll(RegExp(r'[\s\-]'), '').length >= 9;
        } else {
          return _emailController.text.trim().isNotEmpty && _isValidEmail(_emailController.text.trim());
        }
      case 1:
        return _selectedEducation != null &&
            _institutionController.text.isNotEmpty &&
            _fieldOfStudyController.text.isNotEmpty;
      case 2:
        return _selectedCity != null &&
            (_selectedQuarter != null || (_isCustomQuarter && _customQuarter != null && _customQuarter!.isNotEmpty));
      case 3:
        return _selectedTutoringAreas.isNotEmpty && _selectedLearnerLevels.isNotEmpty;
      case 4:
        return _selectedSpecializations.isNotEmpty;
      case 5:
        final motivationText = _motivationController.text.trim();
        final hasValidMotivation = motivationText.isNotEmpty && motivationText.length >= 20;
        if (_hasExperience) {
          return _experienceDuration != null &&
              _previousOrganizationController.text.trim().isNotEmpty &&
              _taughtLevels.isNotEmpty &&
              hasValidMotivation;
        } else {
          return hasValidMotivation;
        }
      case 6:
        return _preferredMode != null &&
            _teachingApproaches.isNotEmpty &&
            _preferredSessionType != null &&
            _hoursPerWeek != null;
      case 7:
        return true; // No required fields
      case 8:
        bool hasTutoringSlots = false;
        bool hasTestSlots = false;
        for (var daySlots in _tutoringAvailability.values) {
          if (daySlots.isNotEmpty) {
            hasTutoringSlots = true;
            break;
          }
        }
        for (var daySlots in _testSessionAvailability.values) {
          if (daySlots.isNotEmpty) {
            hasTestSlots = true;
            break;
          }
        }
        return hasTutoringSlots && hasTestSlots;
      case 9:
        return _expectedRate != null && _expectedRate!.isNotEmpty;
      case 10:
        if (_paymentMethod == null || _paymentMethod!.isEmpty || !_agreesToPaymentPolicy) {
          return false;
        }
        if (_paymentMethod == 'MTN Mobile Money' || _paymentMethod == 'Orange Money') {
          return _paymentNumberController.text.isNotEmpty && _paymentNameController.text.isNotEmpty;
        } else if (_paymentMethod == 'Bank Transfer') {
          return _bankDetailsController.text.isNotEmpty;
        }
        return true;
      case 11:
        if (!_agreesToVerification) return false;
        List<String> requiredDocs = ['profile_picture', 'id_front', 'id_back', 'last_certificate'];
        if (_selectedEducation != null && ['Bachelors', 'Master\'s', 'Doctorate', 'PHD'].contains(_selectedEducation)) {
          requiredDocs.add('degree_certificate');
        }
        if (_hasTraining) {
          requiredDocs.add('training_certificate');
        }
        for (String docType in requiredDocs) {
          if (!_uploadedDocuments.containsKey(docType)) {
            return false;
          }
        }
        return true;
      case 12:
        bool hasSocialLink = _socialMediaLinks.values.any((link) => link.isNotEmpty);
        bool hasVideoLink = _videoLinkController.text.trim().isNotEmpty && _isValidYouTubeUrl(_videoLinkController.text.trim());
        return hasSocialLink && hasVideoLink;
      case 13:
        return _finalAgreements.values.every((agreed) => agreed == true);
      default:
        return false;
    }
  }

  Future<void> _loadSavedData() async {
    // CRITICAL FIX: Always fetch fresh data from database for approved tutors
    // Don't rely on cached existingData - it might be stale after saves
    if (_userId != null) {
      try {
        // Always fetch the latest tutor profile from database
        LogService.info('Fetching latest tutor profile data from database...');
        final tutorResponse = await SupabaseService.client
            .from('tutor_profiles')
            .select('*')
            .eq('user_id', _userId!)
            .maybeSingle();
        
        if (tutorResponse != null) {
          LogService.success('✅ Loaded fresh tutor profile data from database');
          await _loadFromDatabaseData(tutorResponse);
          return;
        } else {
          LogService.warning('No tutor profile found in database');
        }
      } catch (e) {
        LogService.error('Error fetching fresh tutor profile: $e');
        // Fall through to try other methods
      }
    }

    // Fallback: Try loading from progress service
    if (_userId != null) {
      try {
        final progress = await TutorOnboardingProgressService.loadProgress(_userId!);
        if (progress != null) {
          await _loadFromProgressData(progress);
          return;
        }
      } catch (e) {
        LogService.warning('Error loading from progress service: $e');
      }
    }

    // Fallback: Use existingData if provided (for first-time users)
    final existingData =
        widget.basicInfo['existingData'] as Map<String, dynamic>?;
    if (existingData != null) {
      LogService.info('Using provided existingData as fallback');
      await _loadFromDatabaseData(existingData);
      return;
    }

    // Final fallback: SharedPreferences for backward compatibility
    final prefs = await SharedPreferences.getInstance();
    final savedDataString = prefs.getString('tutor_onboarding_data');

    if (savedDataString != null) {
      try {
        final data = jsonDecode(savedDataString) as Map<String, dynamic>;
        await _loadFromSharedPreferencesData(data);
      } catch (e) {
        LogService.warning('Error loading saved data: $e');
      }
    }
  }

  // Load data from progress service
  Future<void> _loadFromProgressData(Map<String, dynamic> progress) async {
    try {
      final stepData = progress['step_data'] as Map<String, dynamic>? ?? {};
      final currentStepFromDb = progress['current_step'] as int? ?? 0;
      final completedSteps = progress['completed_steps'] as List<dynamic>? ?? [];

      // Load data from each step
      for (int step = 0; step < _totalSteps; step++) {
        final stepKey = step.toString();
        final data = stepData[stepKey] as Map<String, dynamic>?;
        if (data == null) continue;

        await _loadStepData(step, data);
      }

      // Find first incomplete step
      int firstIncompleteStep = 0;
      for (int i = 0; i < _totalSteps; i++) {
        if (!completedSteps.contains(i) && !_isStepComplete(i)) {
          firstIncompleteStep = i;
          break;
        }
      }

        safeSetState(() {
        _currentStep = firstIncompleteStep;
      });

      // Update quarters if city is selected
      if (_selectedCity != null) {
        _availableQuarters = AppData.cities[_selectedCity!] ?? [];
      }

      LogService.success('Loaded progress from database - resuming at step $_currentStep');

      // Jump to saved step
      if (_currentStep > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.jumpToPage(_currentStep);
        });
      }
    } catch (e) {
      LogService.warning('Error loading from progress data: $e');
    }
  }

  // Load data for a specific step
  Future<void> _loadStepData(int step, Map<String, dynamic> data) async {
    switch (step) {
      case 0:
          _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        break;
      case 1:
          _selectedEducation = data['selectedEducation'];
          _institutionController.text = data['institution'] ?? '';
          _fieldOfStudyController.text = data['fieldOfStudy'] ?? '';
          _hasTraining = data['hasTraining'] ?? false;
        break;
      case 2:
          _selectedCity = data['selectedCity'];
          _selectedQuarter = data['selectedQuarter'];
          _customQuarter = data['customQuarter'];
        if (data['selectedQuarter'] == null && data['customQuarter'] != null) {
          _isCustomQuarter = true;
        }
        break;
      case 3:
        _selectedTutoringAreas = List<String>.from(data['selectedTutoringAreas'] ?? []);
        _selectedLearnerLevels = List<String>.from(data['selectedLearnerLevels'] ?? []);
        break;
      case 4:
        _selectedSpecializations = List<String>.from(data['selectedSpecializations'] ?? []);
        _customSpecializationController.text = data['customSpecialization'] ?? '';
        break;
      case 5:
        _hasExperience = data['hasExperience'] ?? false;
        _experienceDuration = data['experienceDuration'];
        _previousOrganizationController.text = data['previousOrganization'] ?? '';
        _taughtLevels = List<String>.from(data['taughtLevels'] ?? []);
        _motivationController.text = data['motivation'] ?? '';
        break;
      case 6:
        _preferredMode = data['preferredMode'];
        _teachingApproaches = List<String>.from(data['teachingApproaches'] ?? []);
        _preferredSessionType = data['preferredSessionType'];
        _handlesMultipleLearners = data['handlesMultipleLearners'] ?? false;
        _hoursPerWeek = data['hoursPerWeek'];
        break;
      case 7:
        _devices = List<String>.from(data['devices'] ?? []);
        _hasInternet = data['hasInternet'] ?? false;
        _teachingTools = List<String>.from(data['teachingTools'] ?? []);
        _hasMaterials = data['hasMaterials'] ?? false;
        _wantsTraining = data['wantsTraining'] ?? false;
        break;
      case 8:
        if (data['tutoringAvailability'] != null) {
          _tutoringAvailability = Map<String, List<String>>.from(
            (data['tutoringAvailability'] as Map).map(
              (k, v) => MapEntry(k.toString(), List<String>.from(v)),
            ),
          );
        }
        if (data['testSessionAvailability'] != null) {
          _testSessionAvailability = Map<String, List<String>>.from(
            (data['testSessionAvailability'] as Map).map(
              (k, v) => MapEntry(k.toString(), List<String>.from(v)),
            ),
          );
        }
        break;
      case 9:
        _expectedRate = data['expectedRate'];
        _pricingFactors = List<String>.from(data['pricingFactors'] ?? []);
        break;
      case 10:
        _paymentMethod = data['paymentMethod'];
        _paymentNumberController.text = data['paymentNumber'] ?? '';
        _paymentNameController.text = data['paymentName'] ?? '';
        _bankDetailsController.text = data['bankDetails'] ?? '';
        _agreesToPaymentPolicy = data['agreesToPaymentPolicy'] ?? false;
        break;
      case 11:
        _profilePhotoUrl = data['profilePhotoUrl'];
        _idCardFrontUrl = data['idCardFrontUrl'];
        _idCardBackUrl = data['idCardBackUrl'];
        if (data['certificateUrls'] != null) {
          _certificateUrls = Map<String, String>.from(data['certificateUrls']);
        }
        _agreesToVerification = data['agreesToVerification'] ?? false;
        // Also update _uploadedDocuments
        if (_profilePhotoUrl != null) _uploadedDocuments['profile_picture'] = _profilePhotoUrl!;
        if (_idCardFrontUrl != null) _uploadedDocuments['id_front'] = _idCardFrontUrl!;
        if (_idCardBackUrl != null) _uploadedDocuments['id_back'] = _idCardBackUrl!;
        if (_certificateUrls['last_certificate'] != null) {
          _uploadedDocuments['last_certificate'] = _certificateUrls['last_certificate']!;
        }
        break;
      case 12:
        if (data['socialMediaLinks'] != null) {
          _socialMediaLinks = Map<String, String>.from(data['socialMediaLinks']);
        }
        _videoLinkController.text = data['videoLink'] ?? '';
        break;
      case 13:
        _statementController.text = data['personalStatement'] ?? '';
        if (data['finalAgreements'] != null) {
          _finalAgreements = Map<String, bool>.from(
            (data['finalAgreements'] as Map).map(
              (k, v) => MapEntry(k.toString(), v == true || v == 'true'),
            ),
          );
        }
        break;
    }
  }

  // Load from SharedPreferences (backward compatibility)
  Future<void> _loadFromSharedPreferencesData(Map<String, dynamic> data) async {
    safeSetState(() {
      _currentStep = data['currentStep'] ?? 0;
      _emailController.text = data['email'] ?? '';
      _selectedEducation = data['selectedEducation'];
      _institutionController.text = data['institution'] ?? '';
      _fieldOfStudyController.text = data['fieldOfStudy'] ?? '';
      _hasTraining = data['hasTraining'] ?? false;
      _selectedCity = data['selectedCity'];
      _selectedQuarter = data['selectedQuarter'];
      _customQuarter = data['customQuarter'];
      _selectedTutoringAreas = List<String>.from(data['selectedTutoringAreas'] ?? []);
      _selectedLearnerLevels = List<String>.from(data['selectedLearnerLevels'] ?? []);
      _selectedSpecializations = List<String>.from(data['selectedSpecializations'] ?? []);
          _hasExperience = data['hasExperience'] ?? false;
          _experienceDuration = data['experienceDuration'];
          _motivationController.text = data['motivation'] ?? '';
          _preferredMode = data['preferredMode'];
      _teachingApproaches = List<String>.from(data['teachingApproaches'] ?? []);
          _preferredSessionType = data['preferredSessionType'];
          _hoursPerWeek = data['hoursPerWeek'];
          _paymentMethod = data['paymentMethod'];
          _expectedRate = data['expectedRate'];
          _agreesToPaymentPolicy = data['agreesToPaymentPolicy'] ?? false;
          _agreesToVerification = data['agreesToVerification'] ?? false;
        });

        if (_selectedCity != null) {
          _availableQuarters = AppData.cities[_selectedCity!] ?? [];
        }

        if (_currentStep > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pageController.jumpToPage(_currentStep);
          });
    }
  }

  /// Load data from database (tutor profile) - prefills all fields
  Future<void> _loadFromDatabaseData(Map<String, dynamic> data) async {
    try {
      // Fetch phone and email from profiles table
      final userId = data['user_id'] as String?;
      Map<String, dynamic>? profileData;
      if (userId != null) {
        try {
          final profileResponse = await SupabaseService.client
              .from('profiles')
              .select('email, phone_number')
              .eq('id', userId)
              .maybeSingle();
          profileData = profileResponse;
        } catch (e) {
          LogService.warning('Error fetching profile data: $e');
        }
      }

      safeSetState(() {
        // Email and Phone from profiles table
        _emailController.text =
            profileData?['email']?.toString() ??
            data['email']?.toString() ??
            '';
        _phoneController.text =
            profileData?['phone_number']?.toString() ??
            data['phone_number']?.toString() ??
            '';

        // Academic Background
        _selectedEducation =
            data['highest_education'] ?? data['selected_education'];
        _institutionController.text = data['institution']?.toString() ?? '';
        _fieldOfStudyController.text = data['field_of_study']?.toString() ?? '';
        _hasTraining = data['has_training'] ?? false;

        // Location
        _selectedCity = data['city'];
        _selectedQuarter = data['quarter'];
        _customQuarter = data['custom_quarter']?.toString() ?? '';
        if (_selectedCity != null) {
          _availableQuarters = AppData.cities[_selectedCity!] ?? [];
        }

        // Teaching Focus
        _selectedTutoringAreas = List<String>.from(
          data['tutoring_areas'] ?? data['selected_tutoring_areas'] ?? [],
        );
        _selectedLearnerLevels = List<String>.from(
          data['learner_levels'] ?? data['selected_learner_levels'] ?? [],
        );
        _selectedSpecializations = List<String>.from(
          data['specializations'] ?? data['selected_specializations'] ?? [],
        );

        // Experience
        _hasExperience =
            data['has_experience'] ?? data['teaching_experience'] ?? false;
        _experienceDuration =
            data['teaching_duration'] ?? data['experience_duration'];
        _motivationController.text =
            data['motivation']?.toString() ?? data['bio']?.toString() ?? '';
        // Previous organization - try multiple field names
        if (data['previous_organization'] != null) {
          _previousOrganizationController.text = data['previous_organization'].toString();
        } else if (data['previous_roles'] != null) {
          if (data['previous_roles'] is List && (data['previous_roles'] as List).isNotEmpty) {
            _previousOrganizationController.text = (data['previous_roles'] as List).first.toString();
          } else if (data['previous_roles'] is String && (data['previous_roles'] as String).isNotEmpty) {
            _previousOrganizationController.text = data['previous_roles'] as String;
          }
        } else if (data['previous_tutoring_organization'] != null) {
          _previousOrganizationController.text = data['previous_tutoring_organization'].toString();
        }

        // Taught levels - handle JSON parsing
        if (data['taught_levels'] != null) {
          final levels = data['taught_levels'] is String
              ? jsonDecode(data['taught_levels'])
              : data['taught_levels'];
          if (levels is List) {
            _taughtLevels = List<String>.from(levels);
          }
        }

        // Teaching Style & Availability
        _preferredMode = data['preferred_mode']?.toString();

        // Teaching approaches - handle JSON parsing
        if (data['teaching_approaches'] != null) {
          final approaches = data['teaching_approaches'] is String
              ? jsonDecode(data['teaching_approaches'])
              : data['teaching_approaches'];
          if (approaches is List) {
            _teachingApproaches = List<String>.from(approaches);
          }
        }

        _preferredSessionType = data['preferred_session_type']?.toString();
        _hoursPerWeek = data['hours_per_week']?.toString();
        _handlesMultipleLearners = data['handles_multiple_learners'] ?? false;

        // CRITICAL: Always start with empty availability to ensure we load fresh data
        _tutoringAvailability = {};
        _testSessionAvailability = {};
        
        // IMPORTANT: availability_schedule is what students see, so prioritize it
        // Load from availability_schedule first (this is what gets saved and what students see)
        if (data['availability_schedule'] != null) {
          final availability = data['availability_schedule'];
          if (availability != null) {
            // Handle both JSON string and Map
            final availabilityMap = availability is String
                ? jsonDecode(availability) as Map<String, dynamic>?
                : availability as Map<String, dynamic>?;
            
            if (availabilityMap != null && availabilityMap.isNotEmpty) {
              // Load from availability_schedule (this is what students see)
              availabilityMap.forEach((key, value) {
                final dayKey = key.toString();
                final normalizedDay = dayKey.isNotEmpty
                    ? dayKey[0].toUpperCase() + dayKey.substring(1).toLowerCase()
                    : dayKey;
              final timeSlots = value is List 
                  ? List<String>.from(value.map((v) => v.toString()))
                  : (value != null ? [value.toString()] : <String>[]);
                // Only add day if it has time slots (empty lists are valid - means no availability)
                _tutoringAvailability[normalizedDay] = timeSlots;
              });
              LogService.debug(
                '✅ Loaded availability from availability_schedule: ${_tutoringAvailability.keys.toList()}',
              );
            } else if (availabilityMap != null && availabilityMap.isEmpty) {
              // Empty map means no availability set - this is valid
              LogService.debug('ℹ️ availability_schedule is empty (no time slots set)');
            }
          }
        }
        
        // Fallback: Load from tutoring_availability if availability_schedule is not set
        if (_tutoringAvailability.isEmpty && data['tutoring_availability'] != null) {
          final availability = data['tutoring_availability'] is String
              ? jsonDecode(data['tutoring_availability'])
              : data['tutoring_availability'];
          if (availability is Map && availability.isNotEmpty) {
            // Normalize day names to match UI (capitalize first letter)
            availability.forEach((key, value) {
              final dayKey = key.toString();
              // Normalize to "Monday", "Tuesday", etc.
              final normalizedDay = dayKey.isNotEmpty
                  ? dayKey[0].toUpperCase() + dayKey.substring(1).toLowerCase()
                  : dayKey;
              final timeSlots = value is List 
                  ? List<String>.from(value.map((v) => v.toString()))
                  : (value != null ? [value.toString()] : <String>[]);
              _tutoringAvailability[normalizedDay] = timeSlots;
            });
            LogService.debug(
              '✅ Loaded tutoring availability: ${_tutoringAvailability.keys.toList()}',
            );
          }
        }
        
        // Also check test_session_availability if needed
        if (data['test_session_availability'] != null) {
          final testAvailability = data['test_session_availability'] is String
              ? jsonDecode(data['test_session_availability'])
              : data['test_session_availability'];
          if (testAvailability is Map && testAvailability.isNotEmpty) {
            // Normalize day names to match UI
            testAvailability.forEach((key, value) {
              final dayKey = key.toString();
              final normalizedDay = dayKey.isNotEmpty
                  ? dayKey[0].toUpperCase() + dayKey.substring(1).toLowerCase()
                  : dayKey;
              final timeSlots = value is List 
                  ? List<String>.from(value.map((v) => v.toString()))
                  : (value != null ? [value.toString()] : <String>[]);
              _testSessionAvailability[normalizedDay] = timeSlots;
            });
          }
        }
        
        LogService.info(
          '📅 Final loaded availability - Days with slots: ${_tutoringAvailability.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toList()}, '
          'Days without slots: ${_tutoringAvailability.entries.where((e) => e.value.isEmpty).map((e) => e.key).toList()}',
        );

        // Digital Readiness
        if (data['devices'] != null) {
          final devices = data['devices'] is String
              ? jsonDecode(data['devices'])
              : data['devices'];
          if (devices is List) {
            _devices = List<String>.from(devices);
          }
        }
        _hasInternet = data['has_internet'] ?? false;
        if (data['teaching_tools'] != null) {
          final tools = data['teaching_tools'] is String
              ? jsonDecode(data['teaching_tools'])
              : data['teaching_tools'];
          if (tools is List) {
            _teachingTools = List<String>.from(tools);
          }
        }
        _hasMaterials = data['has_materials'] ?? false;
        _wantsTraining = data['wants_training'] ?? false;

        // Payment
        _paymentMethod = data['payment_method'];
        _expectedRate =
            data['expected_rate']?.toString() ??
            data['hourly_rate']?.toString();

        // Pricing factors
        if (data['pricing_factors'] != null) {
          final factors = data['pricing_factors'] is String
              ? jsonDecode(data['pricing_factors'])
              : data['pricing_factors'];
          if (factors is List) {
            _pricingFactors = List<String>.from(factors);
          }
        }

        // Payment details (if stored as JSON)
        if (data['payment_details'] != null) {
          final paymentDetails = data['payment_details'] is String
              ? jsonDecode(data['payment_details'])
              : data['payment_details'];
          _paymentNumberController.text =
              paymentDetails['phone']?.toString() ??
              paymentDetails['account_number']?.toString() ??
              '';
          _paymentNameController.text =
              paymentDetails['name']?.toString() ?? '';
          _bankDetailsController.text =
              paymentDetails['bank_name']?.toString() ??
              paymentDetails['bank_details']?.toString() ??
              '';
        }

        // Verification
        _videoLinkController.text =
            data['video_intro']?.toString() ??
            data['video_link']?.toString() ??
            '';

        // Document URLs - Set both variables and _uploadedDocuments
        _profilePhotoUrl = data['profile_photo_url']?.toString();
        _idCardFrontUrl = data['id_card_front_url']?.toString();
        _idCardBackUrl = data['id_card_back_url']?.toString();

        // Also populate _uploadedDocuments for UI (CRITICAL: Must be done for images to display)
        if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty) {
          _uploadedDocuments['profile_picture'] = _profilePhotoUrl!;
          LogService.success('Loaded profile photo URL: $_profilePhotoUrl');
        }
        if (_idCardFrontUrl != null && _idCardFrontUrl!.isNotEmpty) {
          _uploadedDocuments['id_front'] = _idCardFrontUrl!;
          LogService.success('Loaded ID front URL: $_idCardFrontUrl');
        }
        if (_idCardBackUrl != null && _idCardBackUrl!.isNotEmpty) {
          _uploadedDocuments['id_back'] = _idCardBackUrl!;
          LogService.success('Loaded ID back URL: $_idCardBackUrl');
        }

        // Social media links
        if (data['social_media_links'] != null) {
          final socialLinks = data['social_media_links'] is String
              ? jsonDecode(data['social_media_links'])
              : data['social_media_links'];
          if (socialLinks is Map) {
            _socialMediaLinks = {};
            socialLinks.forEach((key, value) {
              // Normalize platform names to match UI (capitalize properly)
              final platformKey = key.toString();
              // Handle common variations
              String normalizedKey = platformKey;
              if (platformKey.toLowerCase() == 'linkedin') {
                normalizedKey = 'LinkedIn';
              } else if (platformKey.toLowerCase() == 'youtube') {
                normalizedKey = 'YouTube';
              } else if (platformKey.toLowerCase() == 'facebook') {
                normalizedKey = 'Facebook';
              } else if (platformKey.toLowerCase() == 'instagram') {
                normalizedKey = 'Instagram';
              } else {
                // Capitalize first letter
                normalizedKey = platformKey.isNotEmpty
                    ? platformKey[0].toUpperCase() +
                          platformKey.substring(1).toLowerCase()
                    : platformKey;
              }
              _socialMediaLinks[normalizedKey] = value.toString();
            });
            LogService.success('Loaded social media links: $_socialMediaLinks');
          }
        } else if (data['social_links'] != null) {
          // Try legacy field
          final socialLinks = data['social_links'] is String
              ? jsonDecode(data['social_links'])
              : data['social_links'];
          if (socialLinks is Map) {
            _socialMediaLinks = {};
            socialLinks.forEach((key, value) {
              final platformKey = key.toString();
              String normalizedKey = platformKey;
              if (platformKey.toLowerCase() == 'linkedin') {
                normalizedKey = 'LinkedIn';
              } else if (platformKey.toLowerCase() == 'youtube') {
                normalizedKey = 'YouTube';
              } else {
                normalizedKey = platformKey.isNotEmpty
                    ? platformKey[0].toUpperCase() +
                          platformKey.substring(1).toLowerCase()
                    : platformKey;
              }
              _socialMediaLinks[normalizedKey] = value.toString();
            });
            LogService.debug(
              '✅ Loaded social media links from legacy field: $_socialMediaLinks',
            );
          }
        }

        // Certificates - Load from certificates_urls (CRITICAL: Must load for certificates to display)
        // Clear old certificate entries first to avoid duplicates
        _certificateUrls.clear();
        if (data['certificates_urls'] != null) {
          final certs = data['certificates_urls'] is String
              ? jsonDecode(data['certificates_urls'])
              : data['certificates_urls'];
          LogService.debug('📜 Loading certificates: $certs');
          if (certs is List && certs.isNotEmpty) {
            // Only use the LAST certificate URL (most recent upload) for "last_certificate"
            // This replaces any previous certificates when a tutor re-uploads
            final lastCertUrl = certs.last.toString();
            _certificateUrls['last_certificate'] = lastCertUrl;
            _uploadedDocuments['last_certificate'] = lastCertUrl;
            LogService.debug(
              '✅ Loaded latest certificate URL: $lastCertUrl (replacing ${certs.length - 1} previous certificate(s))',
            );
            // Clear old numbered certificate entries - we only keep the latest
          } else if (certs is Map) {
            // If it's a map, only keep 'last_certificate' if it exists, ignore numbered certificates
            final lastCert = certs['last_certificate']?.toString();
            if (lastCert != null && lastCert.isNotEmpty) {
              _certificateUrls['last_certificate'] = lastCert;
              _uploadedDocuments['last_certificate'] = lastCert;
              LogService.success('Loaded certificate: last_certificate = $lastCert');
            }
          }
        } else {
          LogService.warning('No certificates_urls found in data');
        }

        // Personal Statement
        _statementController.text =
            data['personal_statement']?.toString() ?? '';

        // Set agreements to true if profile exists (they've agreed before)
        _agreesToPaymentPolicy = data['payment_agreement'] ?? true;
        _agreesToVerification = data['verification_agreement'] ?? true;

        // Final agreements (if stored separately)
        if (data['final_agreements'] != null) {
          final agreements = data['final_agreements'] is String
              ? jsonDecode(data['final_agreements'])
              : data['final_agreements'];
          if (agreements is Map) {
            _finalAgreements = Map<String, bool>.from(
              agreements.map(
                (key, value) =>
                    MapEntry(key.toString(), value == true || value == 'true'),
              ),
            );
          }
        } else {
          // If no agreements stored, set defaults to true (they've agreed before)
          _finalAgreements = {
            'professionalism': true,
            'dedication': true,
            'payment_understanding': true,
            'no_external_payments': true,
            'truthful_information': true,
          };
        }
      });

      LogService.success('Loaded existing tutor profile data - all fields prefilled');

      // Show a message that data is prefilled
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Your existing profile data has been loaded. Please review and update as needed.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      LogService.warning('Error loading from database data: $e');
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
  Map<String, bool> _finalAgreements = {
    'professionalism': false,
    'dedication': false,
    'payment_understanding': false,
    'no_external_payments': false,
    'truthful_information': false,
  };

  // File uploads
  String? _profilePhotoUrl;
  String? _idCardFrontUrl;
  String? _idCardBackUrl;
  Map<String, String> _certificateUrls =
      {}; // key: certificate name, value: URL

  // Personal Statement
  final _statementController = TextEditingController();

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
    // Accept all YouTube URL formats including Shorts
    final youtubeRegex = RegExp(
      r'^(https?:\/\/)?(www\.)?(youtube\.com\/(watch\?v=|embed\/|shorts\/)|youtu\.be\/).+$',
      caseSensitive: false,
    );
    return youtubeRegex.hasMatch(url);
  }

  bool _isValidPhoneNumber(String phone) {
    if (phone.isEmpty) return false;
    // Remove any spaces or dashes
    String cleanPhone = phone.replaceAll(RegExp(r'[\s\-]'), '');

    // Handle country code
    if (cleanPhone.startsWith('+237')) {
      cleanPhone = cleanPhone.substring(4); // Remove +237
    } else if (cleanPhone.startsWith('237')) {
      cleanPhone = cleanPhone.substring(3); // Remove 237
    } else if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1); // Remove leading 0
    }

    // Should be exactly 9 digits (Cameroon phone number)
    return RegExp(r'^[0-9]{9}$').hasMatch(cleanPhone);
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return true; // Optional field
    // Use Uri.parse for robust URL validation that handles query parameters, fragments, etc.
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
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
        automaticallyImplyLeading: true, // Enable back button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () async {
            // Save progress before navigating back
            await _saveData(immediate: true);
            if (mounted) {
              // Check if we should go to dashboard or previous screen
              final needsImprovement = widget.basicInfo['needsImprovement'] == true;
              if (needsImprovement) {
                // If editing, go back to dashboard
                Navigator.pushReplacementNamed(context, '/tutor-nav');
              } else {
                // If new onboarding, go back normally
                Navigator.of(context).pop();
              }
            }
          },
        ),
        title: Text(
          'Tutor Onboarding',
          style: GoogleFonts.poppins(
            fontSize: 14,
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
                    // Check if this is edit mode (needs improvement or existing data)
                    Builder(
                      builder: (context) {
                        final isEditMode = widget.basicInfo['needsImprovement'] == true ||
                            widget.basicInfo['existingData'] != null;
                        return TextButton.icon(
                          onPressed: _saveProgress,
                          icon: Icon(
                            isEditMode ? Icons.edit_outlined : Icons.save_outlined,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          label: Text(
                            isEditMode ? 'Save Changes' : 'Save Progress',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                              decoration: TextDecoration.underline,
                              decorationColor: AppTheme.primaryColor,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        );
                      },
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
          safeSetState(() {
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
                      ? (_canProceedFromCurrentStep()
                            ? _submitApplication
                            : null)
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
                      fontSize: 14,
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

                    // Handle country code
                    if (phone.startsWith('+237')) {
                      phone = phone.substring(4); // Remove +237
                    } else if (phone.startsWith('237')) {
                      phone = phone.substring(3); // Remove 237
                    } else if (phone.startsWith('0')) {
                      phone = phone.substring(1); // Remove leading 0
                    }

                    // Validate: should be exactly 9 digits
                    if (!RegExp(r'^[0-9]{9}$').hasMatch(phone)) {
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
            onSelectionChanged: (value) {
              safeSetState(() => _selectedEducation = value);
              _saveData();
            },
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
            onChanged: (value) {
              safeSetState(() => _hasTraining = value);
              _saveData();
            },
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
              safeSetState(() {
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
              safeSetState(() {
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
            onSelectionChanged: (values) {
              safeSetState(() => _selectedTutoringAreas = values);
              _saveData();
            },
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
            onSelectionChanged: (values) {
              safeSetState(() => _selectedLearnerLevels = values);
              _saveData();
            },
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
                safeSetState(() => _selectedSpecializations = values),
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
                  onSelectionChanged: (values) {
                    safeSetState(() => _selectedSpecializations = values);
                    _saveData();
                  },
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
            onChanged: (value) {
              safeSetState(() => _hasExperience = value);
              _saveData();
            },
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
                  safeSetState(() => _experienceDuration = value),
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
                  safeSetState(() => _taughtLevels = values),
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
                safeSetState(() => _preferredMode = value),
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
                safeSetState(() => _teachingApproaches = values),
            isSingleSelection: false,
          ),

          const SizedBox(height: 24),

          // Session Type Selection Cards
          _buildSelectionCards(
            title: 'Preferred Session Type',
            options: ['One-on-one', 'Small Groups (2-5)', 'Larger Groups'],
            selectedValue: _preferredSessionType,
            onSelectionChanged: (value) =>
                safeSetState(() => _preferredSessionType = value),
            isSingleSelection: true,
          ),

          const SizedBox(height: 24),

          // Multiple Learners Toggle
          _buildToggleOption(
            title: 'Open to handling multiple learners at once?',
            value: _handlesMultipleLearners,
            onChanged: (value) =>
                safeSetState(() => _handlesMultipleLearners = value),
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
                safeSetState(() => _hoursPerWeek = value),
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
            onSelectionChanged: (values) {
              safeSetState(() => _devices = values);
              _saveData();
            },
            isSingleSelection: false,
          ),

          const SizedBox(height: 24),

          // Internet Connection Toggle
          _buildToggleOption(
            title: 'Reliable internet connection for online sessions?',
            value: _hasInternet,
            onChanged: (value) {
              safeSetState(() => _hasInternet = value);
              _saveData();
            },
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
                safeSetState(() => _teachingTools = values),
            isSingleSelection: false,
          ),

          const SizedBox(height: 24),

          // Materials Toggle
          _buildToggleOption(
            title: 'Access to teaching materials (notes, slides, PDFs)?',
            value: _hasMaterials,
            onChanged: (value) {
              safeSetState(() => _hasMaterials = value);
              _saveData();
            },
            icon: Icons.folder,
          ),

          const SizedBox(height: 24),

          // Training Interest Toggle
          _buildToggleOption(
            title: 'Interested in free digital teaching training?',
            value: _wantsTraining,
            onChanged: (value) {
              safeSetState(() => _wantsTraining = value);
              _saveData();
            },
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => safeSetState(() => _selectedServiceType = 'tutoring'),
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Tutoring Sessions',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _selectedServiceType == 'tutoring'
                                ? Colors.white
                                : AppTheme.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Online & Physical',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _selectedServiceType == 'tutoring'
                                ? Colors.white.withOpacity(0.8)
                                : AppTheme.textMedium,
                          ),
                          textAlign: TextAlign.center,
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
                    safeSetState(() => _selectedServiceType = 'test_sessions'),
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
            fontSize: 14,
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
                  onTap: () => safeSetState(() => _selectedDay = day),
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
                            fontSize: 14,
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
            Expanded(
              child: Text(
                label,
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) {
            final isSelected =
                currentAvailability[day]?.contains(slot) ?? false;

            return GestureDetector(
              onTap: () {
                safeSetState(() {
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
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? iconColor.withOpacity(0.15)
                      : AppTheme.softCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? iconColor
                        : AppTheme.softBorder,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  slot,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? iconColor
                        : AppTheme.textMedium,
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
            title: 'Expected Rate Per Session',
            options: [
              '2,000 – 3,000 XAF',
              '3,000 – 4,000 XAF',
              '4,000 – 5,000 XAF',
              'Above 5,000 XAF',
            ],
            selectedValue: _expectedRate,
            onSelectionChanged: (value) =>
                safeSetState(() => _expectedRate = value),
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
                  fontSize: 14,
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
            onSelectionChanged: (value) =>
                safeSetState(() => _paymentMethod = value),
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
            fontSize: 14,
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
              safeSetState(() => _pricingFactors = values),
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
                    safeSetState(() => _agreesToPaymentPolicy = value ?? false),
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
            onChanged: (value) {
              safeSetState(() => _agreesToVerification = value);
              _saveData();
            },
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
            fontSize: 14,
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
                  onTap: () => safeSetState(() => _selectedDocumentType = docType),
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
                        fontSize: 14,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preview (compact)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.softCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.softBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildDocumentPreview(docType),
                  ),
                ),
                const SizedBox(width: 12),
                // Success message and reupload button (vertical)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Document uploaded successfully',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _uploadDocument(docType),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reupload'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _uploadDocument(docType),
                icon: const Icon(Icons.cloud_upload),
                label: Text(
                  doc['title'] == 'Last Official Certificate'
                      ? 'Upload Last Certificate'
                      : 'Upload ${doc['title']}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
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

  Widget _buildDocumentPreview(String docType) {
    // Check multiple sources for the URL
    String? uploadedUrl = _uploadedDocuments[docType] as String?;

    // If not found in _uploadedDocuments, check specific variables
    if (uploadedUrl == null || uploadedUrl.isEmpty) {
      switch (docType) {
        case 'profile_picture':
          uploadedUrl = _profilePhotoUrl;
          break;
        case 'id_front':
          uploadedUrl = _idCardFrontUrl;
          break;
        case 'id_back':
          uploadedUrl = _idCardBackUrl;
          break;
        case 'last_certificate':
          uploadedUrl = _certificateUrls['last_certificate'];
          break;
      }
      // Update _uploadedDocuments if found
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        _uploadedDocuments[docType] = uploadedUrl;
      }
    }

    if (uploadedUrl == null || uploadedUrl.isEmpty) {
      return Container(
        color: AppTheme.softCard,
        child: Center(
          child: Icon(
            _getDocumentIcon(docType),
            size: 48,
            color: AppTheme.textMedium,
          ),
        ),
      );
    }

    // Check if file is an image (by extension or URL pattern)
    final isImage = _isImageFile(uploadedUrl);

    if (isImage) {
      // Show image preview with click to enlarge
      return GestureDetector(
        onTap: () => _showFullScreenImage(uploadedUrl!),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              uploadedUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                LogService.error('Error loading image $uploadedUrl: $error');
                return _buildFileIcon(docType);
              },
            ),
          ],
        ),
      );
    } else {
      // Show icon for non-image files
      return _buildFileIcon(docType);
    }
  }

  Widget _buildFileIcon(String docType) {
    // Determine icon based on document type and file extension
    IconData icon;
    Color iconColor = AppTheme.primaryColor;

    // Check if we have a URL to determine file type
    final uploadedUrl = _uploadedDocuments[docType] as String?;
    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
      final lowerUrl = uploadedUrl.toLowerCase();
      if (lowerUrl.contains('.pdf')) {
        icon = Icons.picture_as_pdf;
        iconColor = Colors.red[700]!;
      } else if (lowerUrl.contains('.doc') || lowerUrl.contains('.docx')) {
        icon = Icons.description;
        iconColor = Colors.blue[700]!;
      } else if (lowerUrl.contains('.jpg') ||
          lowerUrl.contains('.jpeg') ||
          lowerUrl.contains('.png') ||
          lowerUrl.contains('.gif')) {
        // Should not reach here if image, but just in case
        icon = Icons.image;
        iconColor = Colors.green[700]!;
      } else {
        icon = Icons.insert_drive_file;
      }
    } else {
      // Default icons based on document type
      if (docType.contains('certificate')) {
        icon = Icons.description;
      } else if (docType.contains('id')) {
        icon = Icons.badge;
      } else if (docType.contains('profile')) {
        icon = Icons.person;
      } else {
        icon = Icons.insert_drive_file;
      }
    }

    return Container(
      color: AppTheme.softCard,
      child: Center(child: Icon(icon, size: 48, color: iconColor)),
    );
  }

  bool _isImageFile(String url) {
    final lowerUrl = url.toLowerCase();
    // Remove query parameters for checking extension
    final urlWithoutQuery = lowerUrl.split('?').first;
    return urlWithoutQuery.endsWith('.jpg') ||
        urlWithoutQuery.endsWith('.jpeg') ||
        urlWithoutQuery.endsWith('.png') ||
        urlWithoutQuery.endsWith('.gif') ||
        urlWithoutQuery.endsWith('.webp') ||
        urlWithoutQuery.endsWith('.bmp') ||
        // Also check for common image URL patterns (Supabase storage)
        lowerUrl.contains('/image/') ||
        lowerUrl.contains('image/upload');
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Material(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
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
                  fontSize: 14,
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
                        safeSetState(() {
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
            fontSize: 14,
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
                    safeSetState(() {
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
            fontSize: 14,
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
              return 'Please enter a valid YouTube URL (e.g., youtube.com/watch?v=... or youtube.com/shorts/...)';
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
                                'To complete your application, please share a short introductory video (1–3 minutes). This helps us and potential learners get to know you better — your teaching style, confidence, and communication approach. Don\'t worry, it\'s not an exam. Just be yourself!\n\n✅ What to do:\n\n1. Record a short video (1–3 minutes) introducing yourself in landscape orientation (horizontal, like Cameroon\'s landscape).\n2. Answer the 5 guiding questions below.\n3. Upload the video to YouTube as a regular video (NOT a YouTube Short).\n4. Set the video to Unlisted visibility.\n5. Paste your video link in the field below.\n\n📹 Important Video Requirements:\n\n• Record in LANDSCAPE orientation (horizontal, width > height)\n• Upload as a REGULAR YouTube video (not a YouTube Short)\n• Video should be 1–3 minutes long\n• Make sure you\'re well-lit and the audio is clear\n\nNeed help uploading your video on YouTube?\n\n1. Open YouTube and sign in.\n2. Tap the "+" icon → Upload a video (NOT "Create a Short").\n3. Choose your video file.\n4. Under "Visibility," select Unlisted (so only people with the link can see it).\n5. Make sure it\'s uploaded as a regular video, not a Short.\n6. Copy the link and paste it below.\n\nGuiding Questions for the Video:\n\n1. Who are you, and what subjects or skills do you teach best?\n2. Why do you enjoy teaching or tutoring?\n3. What makes your approach unique or effective?\n4. How do you help learners overcome challenges or build confidence?\n5. Why do you think you\'d be a great fit for PrepSkul?',
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
    final allAccepted = _finalAgreements.values.every(
      (agreed) => agreed == true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(0.1),
                AppTheme.primaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: allAccepted
                  ? AppTheme.primaryColor.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                allAccepted ? Icons.check_circle : Icons.info_outline,
                color: allAccepted ? Colors.green : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Final Agreements',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              if (allAccepted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'All Accepted',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
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

        if (!allAccepted) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please accept all agreements to submit your application',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                          fontSize: 14,
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: GoogleFonts.poppins(
                  fontSize: 14,
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
            safeSetState(() {});
            // Save to database
            _saveData();
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
    final isChecked = _finalAgreements[key] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isChecked
            ? AppTheme.primaryColor.withOpacity(0.05)
            : AppTheme.softCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isChecked
              ? AppTheme.primaryColor.withOpacity(0.5)
              : AppTheme.softBorder,
          width: isChecked ? 2 : 1,
        ),
        boxShadow: isChecked
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isChecked ? AppTheme.primaryColor : AppTheme.softBorder,
                width: 2,
              ),
              color: isChecked ? AppTheme.primaryColor : Colors.transparent,
            ),
            child: Checkbox(
              value: isChecked,
              onChanged: (value) {
                safeSetState(() {
                  _finalAgreements[key] = value ?? false;
                });
                _saveData();
              },
              activeColor: AppTheme.primaryColor,
              checkColor: Colors.white,
              shape: const CircleBorder(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isChecked ? FontWeight.w600 : FontWeight.w500,
                color: AppTheme.textDark,
                height: 1.5,
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
        // Mark current step as complete
        if (_userId != null) {
          TutorOnboardingProgressService.markStepComplete(_userId!, _currentStep);
        }
        
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        // Auto-save after moving to next step (immediate save)
        _saveData(immediate: true);
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
        // Must agree to all final agreements
        return _finalAgreements.values.every((agreed) => agreed == true);
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

      safeSetState(() {
        _uploadedDocuments[documentType] = uploadedUrl;

        // Also update specific URL variables for database storage
        switch (documentType) {
          case 'profile_picture':
            _profilePhotoUrl = uploadedUrl;
            break;
          case 'id_front':
            _idCardFrontUrl = uploadedUrl;
            break;
          case 'id_back':
            _idCardBackUrl = uploadedUrl;
            break;
          case 'last_certificate':
          case 'degree_certificate':
          case 'training_certificate':
            // Store certificate URLs
            _certificateUrls[documentType] = uploadedUrl;
            break;
        }
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

      // Auto-save after document upload (immediate save)
      _saveData(immediate: true);
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
    safeSetState(() {
      _statementController.text = statement;
    });
  }

  /// Create dynamic bio for tutor cards (starts with subjects, no "Hello!")
  /// This is used in discovery cards and should be engaging and dynamic
  String _createDynamicBio() {
    final parts = <String>[];

    // Start with subjects/specializations (most engaging for cards)
    if (_selectedSpecializations.isNotEmpty) {
      final subjects = _selectedSpecializations.join(', ');
      parts.add('Specializes in $subjects');
    } else if (_selectedTutoringAreas.isNotEmpty) {
      final areas = _selectedTutoringAreas.join(' and ');
      parts.add('Specializes in $areas');
    }

    // Add experience if available
    if (_hasExperience && _experienceDuration != null) {
      parts.add(
        'with ${_experienceDuration!.toLowerCase()} of teaching experience',
      );
    }

    // Add learner levels
    if (_selectedLearnerLevels.isNotEmpty) {
      parts.add(
        'working with ${_selectedLearnerLevels.join(' and ').toLowerCase()} students',
      );
    }

    // Add motivation if provided (their personal touch)
    if (_motivationController.text.isNotEmpty) {
      final motivation = _motivationController.text.trim();
      parts.add(motivation);
    }

    // If no parts, create a basic bio
    if (parts.isEmpty) {
      return 'Passionate educator committed to helping students achieve their academic goals.';
    }

    return parts.join('. ') + '.';
  }

  /// Create personal statement for detail page (starts with personal info, more dynamic)
  /// This is the full bio shown in the tutor's detail page "About" section
  String _createPersonalStatement() {
    final parts = <String>[];
    
    // Start with the most unique/personal information first
    
    // 1. Start with subjects/specializations (most specific and engaging)
    if (_selectedSpecializations.isNotEmpty) {
      final subjects = _selectedSpecializations.join(', ');
      parts.add('I specialize in $subjects');
    } else if (_selectedTutoringAreas.isNotEmpty) {
      final areas = _selectedTutoringAreas.join(' and ');
      parts.add('I specialize in $areas');
    }
    
    // 2. Add experience (shows credibility)
    if (_hasExperience && _experienceDuration != null) {
      parts.add('with ${_experienceDuration!.toLowerCase()} of teaching experience');
    }
    
    // 3. Add education (builds trust)
    if (_selectedEducation != null) {
      final education = _selectedEducation!.toLowerCase();
      if (education.contains('phd') || education.contains('doctorate')) {
        final eduText = education.replaceAll('education', '').trim();
        parts.add('holding a $eduText');
      } else if (education.contains('master')) {
        final eduText = education.replaceAll('education', '').trim();
        parts.add('with a $eduText degree');
      } else {
        final eduText = education.replaceAll('education', '').trim();
        parts.add('with $eduText education');
      }
    }
    
    // 4. Add learner levels (shows who they work with)
    if (_selectedLearnerLevels.isNotEmpty) {
      parts.add('working with ${_selectedLearnerLevels.join(' and ').toLowerCase()} students');
    }
    
    // 5. Incorporate motivation early (their personal touch - most important!)
    if (_motivationController.text.isNotEmpty) {
      final motivation = _motivationController.text.trim();
      // Capitalize first letter if needed
      final formattedMotivation = motivation.substring(0, 1).toUpperCase() + 
          (motivation.length > 1 ? motivation.substring(1) : '');
      parts.add(formattedMotivation);
    }
    
    // Build the statement dynamically
    String statement = '';
    
    if (parts.isNotEmpty) {
      // Start with the first part (usually subjects/specializations)
      statement = parts[0];
      
      // Add remaining parts with appropriate connectors
      for (int i = 1; i < parts.length; i++) {
        if (i == 1 && parts.length > 2) {
          // Second part: use comma if there are more parts
          statement += ', ${parts[i]}';
        } else if (i == parts.length - 1) {
          // Last part: use period
          statement += '. ${parts[i]}.';
        } else {
          // Middle parts: use comma
          statement += ', ${parts[i]}';
        }
      }
      
      // If we only had one part, add period
      if (parts.length == 1) {
        statement += '.';
      }
    } else {
      // Fallback if no information available
      statement = 'Passionate educator committed to helping students achieve their academic goals.';
    }
    
    // Add closing commitment statement (only if we have personal info)
    if (parts.isNotEmpty) {
      statement += ' I am committed to providing quality education and helping students achieve their academic goals.';
    }
    
    return statement;
  }

  Future<void> _submitApplication() async {
    // First check if all final agreements are accepted
    final allAgreementsAccepted = _finalAgreements.values.every(
      (agreed) => agreed == true,
    );

    if (!allAgreementsAccepted) {
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Agreements Required',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Please accept all final agreements before submitting your application.',
            style: GoogleFonts.poppins(fontSize: 14),
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

      // Get current user ID and auth info
      final userInfo = await AuthService.getCurrentUser();
      final userId = userInfo['userId'];

      // Get authenticated user from Supabase for email/phone
      final supabaseUser = SupabaseService.client.auth.currentUser;
      String? authEmail = supabaseUser?.email;
      String? authPhone = supabaseUser?.phone;

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
      } else if (_authMethod == 'phone' && authPhone != null) {
        // Use auth phone if available
        phoneNumber = authPhone;
      }

      // Save to database (pass email or phone based on auth method)
      // Priority: onboarding input > auth user data
      String? contactInfo;
      if (_authMethod == 'email') {
        // Email auth: prefer phone from onboarding, fallback to auth email
        contactInfo = phoneNumber ?? authEmail ?? _emailController.text.trim();
      } else {
        // Phone auth: prefer email from onboarding, fallback to auth phone
        contactInfo = _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : authPhone ?? phoneNumber;
      }

      await SurveyRepository.saveTutorSurvey(
        userId,
        tutorData,
        contactInfo, // Email if phone auth, phone if email auth
      );

      // Mark onboarding as complete
      await TutorOnboardingProgressService.markOnboardingComplete(userId);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success dialog with confetti
      if (mounted) {
        await _showCompletionDialog();

        // Navigate to tutor dashboard
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/tutor-nav', (route) => false);
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      LogService.debug('Error submitting application: $e');

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

  Map<String, dynamic> _prepareTutorData() {
    // Extract document URLs from _uploadedDocuments if specific variables are null
    final profilePhotoUrl =
        _profilePhotoUrl ?? (_uploadedDocuments['profile_picture'] as String?);
    final idCardFrontUrl =
        _idCardFrontUrl ?? (_uploadedDocuments['id_front'] as String?);
    final idCardBackUrl =
        _idCardBackUrl ?? (_uploadedDocuments['id_back'] as String?);

    // Collect certificate URLs - only use the latest certificate (last_certificate)
    // This ensures we replace old certificates instead of creating duplicates
    final List<String> certificateUrls = [];

    // Priority: Use 'last_certificate' from _certificateUrls or _uploadedDocuments
    final lastCertUrl =
        _certificateUrls['last_certificate'] ??
        (_uploadedDocuments['last_certificate'] as String?);

    if (lastCertUrl != null && lastCertUrl.isNotEmpty) {
      certificateUrls.add(lastCertUrl);
      LogService.success('Adding latest certificate to submission: $lastCertUrl');
    } else {
      // Fallback: Check other certificate types only if last_certificate doesn't exist
      ['degree_certificate', 'training_certificate'].forEach((docType) {
        final url =
            _certificateUrls[docType] ??
            (_uploadedDocuments[docType] as String?);
        if (url != null && url.isNotEmpty && !certificateUrls.contains(url)) {
          certificateUrls.add(url);
        }
      });
    }

    // Prepare payment details based on payment method
    Map<String, dynamic> paymentDetails = {};
    if (_paymentMethod == 'MTN Mobile Money' ||
        _paymentMethod == 'Orange Money') {
      paymentDetails = {
        'phone': _paymentNumberController.text,
        'name': _paymentNameController.text,
        'account_type': _paymentMethod,
      };
    } else if (_paymentMethod == 'Bank Transfer') {
      paymentDetails = {
        'bank_details': _bankDetailsController.text,
        'account_type': _paymentMethod,
      };
    }

    // Build the data map
    final Map<String, dynamic> tutorData = {
      // Personal Info
      // Note: email is saved separately to profiles table, not tutor_profiles
      'profile_photo_url': profilePhotoUrl,
      'city': _selectedCity,
      'quarter': _selectedQuarter ?? _customQuarter,
      // Bio: Dynamic bio for cards (starts with subjects, no "Hello!")
      'bio': _createDynamicBio(),
      // Motivation: Raw motivation text (for reference)
      'motivation': _motivationController.text,
      // Academic Background
      'highest_education': _selectedEducation,
      'institution': _institutionController.text,
      'field_of_study': _fieldOfStudyController.text,
      'has_training': _hasTraining,

      // Experience
      'has_teaching_experience': _hasExperience,
      'has_experience': _hasExperience,
      'teaching_duration': _experienceDuration,
      'previous_roles':
          _hasExperience &&
              _previousOrganizationController.text.trim().isNotEmpty
          ? [
              _previousOrganizationController.text.trim(),
            ] // Convert organization to list
          : [],
      'taught_levels': _taughtLevels, // Save taught levels
      // Tutoring Details
      'tutoring_areas': _selectedTutoringAreas,
      'learner_levels': _selectedLearnerLevels,
      'specializations': _selectedSpecializations,
      'personal_statement': _statementController.text,

      // Teaching Style & Preferences
      'preferred_mode': _preferredMode,
      'teaching_approaches': _teachingApproaches,
      'preferred_session_type': _preferredSessionType,
      'handles_multiple_learners': _handlesMultipleLearners,

      // Availability - Store BOTH separately for admin dashboard
      // IMPORTANT: Always save availability_schedule (used by students when booking)
      // Even if empty, save it to ensure updates work for approved tutors
      'hours_per_week': _hoursPerWeek,
      'tutoring_availability': _tutoringAvailability.isNotEmpty
          ? _tutoringAvailability
          : null,
      'test_session_availability': _testSessionAvailability.isNotEmpty
          ? _testSessionAvailability
          : null,
      // CRITICAL: availability_schedule is what students see when booking
      // Always save this field, even if empty, to ensure updates work
      'availability_schedule': _tutoringAvailability.isNotEmpty
          ? _tutoringAvailability
          : {}, // Save empty map if no availability (allows clearing)
      'availability': _tutoringAvailability.isNotEmpty
          ? _tutoringAvailability
          : {}, // Also save as 'availability' for completion check
      // Digital Readiness
      'devices': _devices,
      'has_internet': _hasInternet,
      'teaching_tools': _teachingTools,
      'has_materials': _hasMaterials,
      'wants_training': _wantsTraining,

      // Payment
      'payment_method': _paymentMethod,
      'expected_rate': _expectedRate,
      'hourly_rate': _expectedRate != null
          ? _parseExpectedRate(_expectedRate!)
          : null,
      'payment_details': paymentDetails,
      'payment_agreement': _agreesToPaymentPolicy,
      'pricing_factors': _pricingFactors,

      // Verification
      'id_card_front_url': idCardFrontUrl,
      'id_card_back_url': idCardBackUrl,
      'id_card_url': idCardFrontUrl, // Legacy field for compatibility
      'video_url': _videoLinkController.text, // Primary field
      'video_link': _videoLinkController.text,
      'video_intro': _videoLinkController.text,
      'social_media_links': _socialMediaLinks,
      'social_links': _socialMediaLinks, // Legacy field
      'verification_agreement': _agreesToVerification,
      'final_agreements': _finalAgreements, // Store all final agreements
      // Status - Always pending on submission (admin reviews)
      // Note: If status was 'rejected' or 'needs_improvement', it will be set to 'pending' in SurveyRepository
      'status': 'pending',
    };

    // Add certificates_urls only if not empty (to avoid database errors if column doesn't exist yet)
    // Use unique URLs to avoid duplicates
    final uniqueCertificateUrls = certificateUrls.toSet().toList();
    if (uniqueCertificateUrls.isNotEmpty) {
      tutorData['certificates_urls'] = uniqueCertificateUrls;
    }

    return tutorData;
  }

  /// Parse expected rate string (e.g., "3,000 – 4,000 XAF") to a single numeric value
  /// Returns the first number in the range, or null if parsing fails
  double? _parseExpectedRate(String rateString) {
    try {
      // Remove currency text and extra whitespace
      String cleaned = rateString.replaceAll('XAF', '').trim();
      
      // Handle "Above X" format
      if (cleaned.toLowerCase().contains('above')) {
        // Extract the number after "above"
        final match = RegExp(r'above\s*([\d,]+)', caseSensitive: false).firstMatch(cleaned);
        if (match != null) {
          final numberStr = match.group(1)?.replaceAll(',', '') ?? '';
          return double.tryParse(numberStr);
        }
        return null;
      }
      
      // Handle range format (e.g., "3,000 – 4,000" or "3000-4000")
      // Extract the first number from the range
      final numbers = RegExp(r'([\d,]+)').allMatches(cleaned);
      if (numbers.isNotEmpty) {
        // Get the first number and remove commas
        final firstNumberStr = numbers.first.group(1)?.replaceAll(',', '') ?? '';
        final parsed = double.tryParse(firstNumberStr);
        if (parsed != null && parsed >= 1000 && parsed <= 50000) {
          return parsed;
        }
      }
      
      // Fallback: try to parse the entire string after removing non-digits
      final fallback = cleaned.replaceAll(RegExp(r'[^\d.]'), '');
      if (fallback.isNotEmpty) {
        final parsed = double.tryParse(fallback);
        // Validate the parsed value is within acceptable range
        if (parsed != null && parsed >= 1000 && parsed <= 50000) {
          return parsed;
        }
      }
      
      return null;
    } catch (e) {
      LogService.error('Error parsing expected rate: $e');
      return null;
    }
  }

  /// Show beautiful completion dialog with confetti
  Future<void> _showCompletionDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfettiCelebration(
        autoStart: true,
        duration: const Duration(seconds: 4),
        particleCount: 60,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon with animation
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 50,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Application Submitted! 🎉',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your tutor profile has been submitted successfully!\nOur team will review it and get back to you soon.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.95),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'Go to Dashboard',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


