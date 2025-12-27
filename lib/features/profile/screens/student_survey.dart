import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/data/app_data.dart';
import 'package:prepskul/data/survey_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../tutor/screens/instruction_screen.dart';
import '../../../core/widgets/confetti_celebration.dart';

class StudentSurvey extends StatefulWidget {
  const StudentSurvey({Key? key}) : super(key: key);

  @override
  State<StudentSurvey> createState() => _StudentSurveyState();
}

class _StudentSurveyState extends State<StudentSurvey> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Basic Student Information
  String? _studentName; // Kept for backward compatibility but not shown in UI
  DateTime? _studentDateOfBirth;
  String? _studentGender;

  // Date of Birth fields
  String? _selectedDay;
  String? _selectedMonth;
  final TextEditingController _yearController = TextEditingController();

  // Location Information
  String? _selectedCity;
  String? _selectedQuarter;
  String? _customQuarter;
  List<String> _availableQuarters = [];
  bool _isCustomQuarter = false;

  // Learning Path
  String? _selectedLearningPath;

  // Academic Tutoring specific
  String? _selectedEducationLevel;
  String? _selectedClass;
  String? _selectedStream;
  List<String> _selectedSubjects = [];
  final TextEditingController _universityCoursesController =
      TextEditingController();

  // Skill Development specific
  String? _selectedSkillCategory;
  List<String> _selectedSkills = [];

  // Exam Preparation specific
  String? _selectedExamType;
  String? _selectedSpecificExam;
  List<String> _examSubjects = [];

  // Preferences
  int _minBudget = 20000;
  int _maxBudget = 55000;
  String? _tutorGenderPreference;
  String? _tutorQualificationPreference;
  String? _preferredLocation;
  String? _preferredSchedule;
  List<String> _learningStyles = [];
  String? _confidenceLevel;
  List<String> _learningGoals = [];
  List<String> _challenges = [];
  bool _paymentPolicyAgreed = false;

  List<SurveyStep> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializeSteps();
    // Load name from database FIRST, then load saved data
    // This ensures name is available before UI renders
    _loadStudentNameFromProfile().then((_) {
      // After name is loaded, load any saved survey data
    _loadSavedData();
    });
  }

  @override
  void dispose() {
    _universityCoursesController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  /// Show beautiful survey completion dialog
  Future<void> _showSurveyCompletionDialog() async {
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
                  'Survey Completed! 🎉',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Thank you for completing your profile!\nWe\'ll use this information to find the perfect tutor for you.',
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
                      'Get Started',
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

  // Auto-save functionality
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'currentStep': _currentStep,
      'studentName': _studentName,
      'studentDateOfBirth': _studentDateOfBirth?.toIso8601String(),
      'selectedDay': _selectedDay,
      'selectedMonth': _selectedMonth,
      'selectedYear': _yearController.text.isNotEmpty
          ? int.tryParse(_yearController.text)
          : null,
      'studentGender': _studentGender,
      'selectedCity': _selectedCity,
      'selectedQuarter': _selectedQuarter,
      'customQuarter': _customQuarter,
      'isCustomQuarter': _isCustomQuarter,
      'selectedLearningPath': _selectedLearningPath,
      'selectedEducationLevel': _selectedEducationLevel,
      'selectedClass': _selectedClass,
      'selectedStream': _selectedStream,
      'selectedSubjects': _selectedSubjects,
      'universityCourses': _universityCoursesController.text,
      'selectedSkillCategory': _selectedSkillCategory,
      'selectedSkills': _selectedSkills,
      'selectedExamType': _selectedExamType,
      'selectedSpecificExam': _selectedSpecificExam,
      'examSubjects': _examSubjects,
      'minBudget': _minBudget,
      'maxBudget': _maxBudget,
      'tutorGenderPreference': _tutorGenderPreference,
      'tutorQualificationPreference': _tutorQualificationPreference,
      'preferredLocation': _preferredLocation,
      'preferredSchedule': _preferredSchedule,
      'learningStyles': _learningStyles,
      'confidenceLevel': _confidenceLevel,
      'learningGoals': _learningGoals,
      'challenges': _challenges,
      'paymentPolicyAgreed': _paymentPolicyAgreed,
    };
    await prefs.setString('student_survey_data', jsonEncode(data));
    LogService.success('Auto-saved student survey data');
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDataString = prefs.getString('student_survey_data');

    if (savedDataString != null) {
      try {
        final data = jsonDecode(savedDataString) as Map<String, dynamic>;
        safeSetState(() {
          _currentStep = data['currentStep'] ?? 0;
          _studentName = data['studentName']; // Keep for backward compatibility
          if (data['studentDateOfBirth'] != null) {
            _studentDateOfBirth = DateTime.parse(data['studentDateOfBirth']);
            // Populate day, month, year fields from loaded date
            _selectedDay = _studentDateOfBirth!.day.toString().padLeft(2, '0');
            _selectedMonth = _studentDateOfBirth!.month.toString().padLeft(
              2,
              '0',
            );
            _yearController.text = _studentDateOfBirth!.year.toString();
          } else {
            // Also check if day/month/year are saved separately
            _selectedMonth = data['selectedMonth'];
            if (data['selectedYear'] != null) {
              _yearController.text = data['selectedYear'].toString();
            }
            // Set day after month/year are set, so validation can work
            final savedDay = data['selectedDay'];
            if (savedDay != null) {
              // Validate that the saved day is valid for the current month/year
              final availableDays = _getDaysForMonth();
              if (availableDays.contains(savedDay)) {
                _selectedDay = savedDay;
              } else if (availableDays.isNotEmpty) {
                // If saved day is not valid, use the last valid day
                _selectedDay = availableDays.last;
              } else {
                _selectedDay = null;
              }
            }
            _updateDateOfBirth();
          }
          _studentGender = data['studentGender'];
          _selectedCity = data['selectedCity'];
          _selectedQuarter = data['selectedQuarter'];
          _customQuarter = data['customQuarter'];
          _isCustomQuarter = data['isCustomQuarter'] ?? false;
          _selectedLearningPath = data['selectedLearningPath'];
          _selectedEducationLevel = data['selectedEducationLevel'];
          _selectedClass = data['selectedClass'];
          _selectedStream = data['selectedStream'];
          _selectedSubjects = List<String>.from(data['selectedSubjects'] ?? []);
          _universityCoursesController.text = data['universityCourses'] ?? '';
          _selectedSkillCategory = data['selectedSkillCategory'];
          _selectedSkills = List<String>.from(data['selectedSkills'] ?? []);
          _selectedExamType = data['selectedExamType'];
          _selectedSpecificExam = data['selectedSpecificExam'];
          _examSubjects = List<String>.from(data['examSubjects'] ?? []);
          _minBudget = data['minBudget'] ?? 20000;
          _maxBudget = data['maxBudget'] ?? 55000;
          _tutorGenderPreference = data['tutorGenderPreference'];
          _tutorQualificationPreference = data['tutorQualificationPreference'];
          _preferredLocation = data['preferredLocation'];
          _preferredSchedule = data['preferredSchedule'];
          // Handle both old single value and new list format
          if (data['learningStyles'] != null) {
            _learningStyles = List<String>.from(data['learningStyles'] ?? []);
          } else if (data['learningStyle'] != null) {
            // Migrate old single value to list
            _learningStyles = [data['learningStyle'] as String];
          }
          _confidenceLevel = data['confidenceLevel'];
          _learningGoals = List<String>.from(data['learningGoals'] ?? []);
          _challenges = List<String>.from(data['challenges'] ?? []);
          _paymentPolicyAgreed = data['paymentPolicyAgreed'] ?? false;
        });

        // Update quarters if city is selected
        if (_selectedCity != null) {
          _availableQuarters = AppData.cities[_selectedCity!] ?? [];
        }

        // Rebuild steps based on loaded learning path
        if (_selectedLearningPath != null) {
          _updateSteps();
        }

        LogService.debug(
          '✅ Loaded saved student survey data - resuming at step $_currentStep',
        );

        // Jump to saved step
        if (_currentStep > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pageController.jumpToPage(_currentStep);
          });
        }
      } catch (e) {
        LogService.warning('Error loading saved data: $e');
      }
    }
  }

  /// Load student name from profile to avoid redundant entry
  Future<void> _loadStudentNameFromProfile() async {
    try {
      // Only pre-populate if name is still empty (user hasn't typed anything)
      if (_studentName != null && _studentName!.isNotEmpty) {
        LogService.info('[NAME_LOAD] Name already set, skipping pre-population');
        return;
      }

      // Add a small delay to ensure Supabase is fully initialized
      await Future.delayed(const Duration(milliseconds: 100));

      // Get user ID directly from Supabase auth (more reliable than SharedPreferences)
      final authUser = SupabaseService.currentUser;
      if (authUser == null) {
        LogService.warning('[NAME_LOAD] No authenticated user found');
        return;
      }

      final userId = authUser.id;
      final userEmail = authUser.email;

      // Try to load profile from database using userId
      Map<String, dynamic>? userProfile;
      try {
        final profileResponse = await SupabaseService.client
            .from('profiles')
            .select('full_name, email')
            .eq('id', userId)
            .maybeSingle();

        userProfile = profileResponse;
        LogService.debug(
          '🔍 [NAME_LOAD] Profile lookup by userId: ${userProfile?['full_name']}',
        );
      } catch (e) {
        LogService.warning('[NAME_LOAD] Error loading profile by userId: $e');
      }

      // If profile doesn't exist, try to create it or find by email
      if (userProfile == null && userEmail != null) {
        try {
          // Try to find profile by email
          final emailProfileResponse = await SupabaseService.client
              .from('profiles')
              .select('full_name, email, id')
              .eq('email', userEmail)
              .maybeSingle();

          if (emailProfileResponse != null) {
            userProfile = emailProfileResponse;
            LogService.debug(
              '🔍 [NAME_LOAD] Found profile by email: ${userProfile['full_name']}',
            );
          } else {
            // Profile doesn't exist - try to create it
            LogService.warning('[NAME_LOAD] Profile not found, attempting to create...');
            try {
              // Get stored signup data as fallback
              final prefs = await SharedPreferences.getInstance();
              final storedName = prefs.getString('signup_full_name');
              final storedRole = prefs.getString('signup_user_role');

              // Try to get user role from various sources
              String? userRole =
                  storedRole ??
                  authUser.userMetadata?['user_type']?.toString() ??
                  authUser.userMetadata?['user_role']?.toString();

              // Create profile with available data
              await SupabaseService.client.from('profiles').upsert({
                'id': userId,
                'email': userEmail,
                'full_name':
                    storedName ?? authUser.userMetadata?['full_name'] ?? 'User',
                'phone_number': authUser.phone,
                'user_type':
                    userRole ??
                    'student', // Use stored role or default to student
                'avatar_url': null,
                'survey_completed': false,
                'is_admin': false,
              }, onConflict: 'id');

              // Fetch the created profile
              final newProfileResponse = await SupabaseService.client
                  .from('profiles')
                  .select('full_name, email')
                  .eq('id', userId)
                  .maybeSingle();

              userProfile = newProfileResponse;
              LogService.success('[NAME_LOAD] Profile created for user: $userId');
            } catch (createError) {
              LogService.warning('[NAME_LOAD] Error creating profile: $createError');
            }
          }
        } catch (e) {
          LogService.warning('[NAME_LOAD] Error in email lookup/profile creation: $e');
        }
      }

      // If we have a profile with a name, use it
      if (userProfile != null &&
          userProfile['full_name'] != null &&
          userProfile['full_name'].toString().trim().isNotEmpty &&
          userProfile['full_name'].toString().trim() != 'User') {
        final profileName = userProfile['full_name'].toString().trim();
        // Only set if still empty (check again after async operations)
        if (_studentName == null || _studentName!.isEmpty) {
        safeSetState(() {
            _studentName = profileName;
            // Name loaded from profile
        });
        LogService.success('Pre-populated student name from profile: $_studentName');
          return;
        } else {
          LogService.debug(
            'ℹ️ [NAME_LOAD] Name was set while loading, skipping pre-population',
          );
          return;
        }
      }

      // If not in profile, try to load from stored signup data
      final prefs = await SharedPreferences.getInstance();
      final storedName = prefs.getString('signup_full_name');
      if (storedName != null && storedName.trim().isNotEmpty) {
        // Only set if still empty
        if (_studentName == null || _studentName!.isEmpty) {
          safeSetState(() {
            _studentName = storedName.trim();
            // Name loaded from stored signup data
            // Mark as pre-populated
          });
          LogService.debug(
            '✅ Pre-populated student name from stored signup data: $_studentName',
          );
        }
        return;
      }

      // If not in stored signup data, try to load from current user session
      if (_studentName == null || _studentName!.isEmpty) {
        final currentUser = await AuthService.getCurrentUser();
        final sessionName = currentUser['fullName'] as String?;
        if (sessionName != null &&
            sessionName.trim().isNotEmpty &&
            sessionName.trim() != 'User') {
          safeSetState(() {
            _studentName = sessionName.trim();
            // Name loaded from session
            // Mark as pre-populated
          });
          LogService.success('Pre-populated student name from session: $_studentName');
          return;
        }
      }

      // If still not found, try to load from Supabase Auth user metadata
      if (_studentName == null || _studentName!.isEmpty) {
        final authUser = SupabaseService.currentUser;
        if (authUser != null && authUser.userMetadata?['full_name'] != null) {
          final metadataName = authUser.userMetadata!['full_name'] as String;
          if (metadataName.trim().isNotEmpty && metadataName.trim() != 'User') {
            safeSetState(() {
              _studentName = metadataName.trim();
              // Name loaded from auth metadata
              // Mark as pre-populated
            });
            LogService.debug(
              '✅ Pre-populated student name from auth metadata: $_studentName',
            );
            return;
          }
        }
      }

      // Try to get from SupabaseService directly
      try {
        final supabaseUser = SupabaseService.currentUser;
        if (supabaseUser != null) {
          // Try email as fallback identifier
          final email = supabaseUser.email;
          if (email != null && email.isNotEmpty) {
            // Try to fetch profile by email
            final profileResponse = await SupabaseService.client
                .from('profiles')
                .select('full_name')
                .eq('email', email)
                .maybeSingle();

            if (profileResponse != null &&
                profileResponse['full_name'] != null &&
                profileResponse['full_name'].toString().trim().isNotEmpty &&
                profileResponse['full_name'].toString().trim() != 'User') {
              final fetchedName = profileResponse['full_name']
                  .toString()
                  .trim();
              // Only set if still empty (check again after async database call)
              if (_studentName == null || _studentName!.isEmpty) {
                safeSetState(() {
                  _studentName = fetchedName;
                  // Name loaded from email lookup
                  // Mark as pre-populated
                });
                LogService.debug(
                  '✅ Pre-populated student name from email lookup: $_studentName',
                );
              }
              return;
            }
          }
        }
      } catch (e) {
        LogService.warning('Error in email lookup for name: $e');
      }

      // Debug: Print all attempted sources
      LogService.debug('[NAME_LOAD] Attempted sources:');
      LogService.debug('  - Profile: ${userProfile?['full_name']}');
      final debugPrefs = await SharedPreferences.getInstance();
      LogService.debug('  - Stored signup: ${debugPrefs.getString('signup_full_name')}');
      final debugCurrentUser = await AuthService.getCurrentUser();
      LogService.debug('  - Session: ${debugCurrentUser['fullName']}');
      final debugAuthUserForLogging = SupabaseService.currentUser;
      LogService.debug(
        '  - Auth metadata: ${debugAuthUserForLogging?.userMetadata?['full_name']}',
      );
      LogService.debug('  - Auth email: ${debugAuthUserForLogging?.email}');
      LogService.debug(
        '⚠️ Could not find student name in profile, stored data, session, or metadata',
      );
    } catch (e) {
      LogService.warning('Could not load student name from profile: $e');
      // Continue without pre-population - user can enter manually
    }
  }

  void _initializeSteps() {
    _steps = [
      const SurveyStep(
        title: 'Tell us about yourself',
        subtitle: 'Basic student information',
      ),
      const SurveyStep(
        title: 'What do you want to learn?',
        subtitle: 'Choose your learning path',
      ),
    ];
  }

  void _updateSteps() {
    safeSetState(() {
      _steps = [
        const SurveyStep(
          title: 'Tell us about yourself',
          subtitle: 'Basic student information',
        ),
        const SurveyStep(
          title: 'What do you want to learn?',
          subtitle: 'Choose your learning path',
        ),
      ];

      // Add dynamic steps based on learning path
      if (_selectedLearningPath != null) {
        _addDynamicSteps();
      }

      // Add location, preferences and review
      _steps.addAll([
        const SurveyStep(title: 'Location', subtitle: 'Where are you located?'),
        const SurveyStep(
          title: 'Tutor Qualification',
          subtitle: 'What level of tutor qualification would you prefer?',
        ),
        const SurveyStep(
          title: 'Tutor Gender',
          subtitle: 'Do you have a gender preference?',
        ),
        const SurveyStep(
          title: 'Learning Location',
          subtitle: 'Where should the sessions take place?',
        ),
        const SurveyStep(
          title: 'Schedule Preference',
          subtitle: 'When would you like sessions?',
        ),
        const SurveyStep(
          title: 'Learning Style',
          subtitle: 'How do you prefer to learn?',
        ),
        const SurveyStep(
          title: 'Confidence Level',
          subtitle: 'How confident are you in this subject/skill?',
        ),
        const SurveyStep(
          title: 'Learning Goals',
          subtitle: 'What do you want to achieve?',
        ),
        const SurveyStep(
          title: 'Budget Range',
          subtitle:
              'What\'s your monthly budget for tutoring? Drag the handles to adjust your budget range',
        ),
        const SurveyStep(
          title: 'Review & Confirm',
          subtitle: 'Please review all information',
        ),
      ]);
    });
  }

  void _addDynamicSteps() {
    if (_selectedLearningPath == null) return;

    final programConfig = SurveyConfig.getProgramConfig(_selectedLearningPath!);
    if (programConfig == null) return;

    for (String step in programConfig.steps) {
      switch (step) {
        case 'education_level':
          _steps.add(
            const SurveyStep(
              title: 'Education Level',
              subtitle: 'Select your current education level',
            ),
          );
          break;
        case 'class_selection':
          if (_selectedEducationLevel != null) {
            _steps.add(
              const SurveyStep(
                title: 'Class Selection',
                subtitle: 'Select your current class',
              ),
            );
          }
          break;
        case 'stream_selection':
          if (_selectedEducationLevel != null) {
            final levelConfig = SurveyConfig.getEducationLevelConfig(
              _selectedEducationLevel!,
            );
            if (levelConfig?.hasStreams == true) {
              _steps.add(
                const SurveyStep(
                  title: 'Stream Selection',
                  subtitle: 'Select your stream (if applicable)',
                ),
              );
            }
          }
          break;
        case 'subjects_selection':
          _steps.add(
            const SurveyStep(
              title: 'Subjects of Interest',
              subtitle: 'Select subjects you need help with',
            ),
          );
          break;
        case 'skill_category':
          _steps.add(
            const SurveyStep(
              title: 'Skill Category',
              subtitle: 'Select the skill category',
            ),
          );
          break;
        case 'specific_skills':
          _steps.add(
            const SurveyStep(
              title: 'Specific Skills',
              subtitle: 'Select all that apply',
            ),
          );
          break;
        case 'exam_type':
          _steps.add(
            const SurveyStep(
              title: 'Which type of exam are you preparing for?',
              subtitle: 'Select the exam category',
            ),
          );
          break;
        case 'specific_exam':
          _steps.add(
            const SurveyStep(
              title: 'Which specific exam?',
              subtitle: 'Select the exact exam',
            ),
          );
          break;
        case 'exam_subjects':
          _steps.add(
            const SurveyStep(
              title: 'Which subjects for this exam?',
              subtitle: 'Select all that apply',
            ),
          );
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent going back to auth screens
        if (_currentStep > 0) {
          _previousStep();
          return false;
        }
        // Show confirmation dialog if on first page
        return await _showExitDialog(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Learner Survey',
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: AppTheme.neutral50,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(45),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${((_currentStep + 1) / _steps.length * 100).toInt()}% Complete',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.neutral50,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.cloud_done,
                            color: AppTheme.neutral50,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Auto-saved',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.neutral50,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // const SizedBox(height: 12),
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 20.0),
                //   child: ClipRRect(
                //     borderRadius: BorderRadius.circular(10),
                //     child: LinearProgressIndicator(
                //       value: (_currentStep + 1) / _steps.length,
                //       backgroundColor: AppTheme.neutral50.withOpacity(0.3),
                //       valueColor: const AlwaysStoppedAnimation<Color>(
                //         AppTheme.neutral50,
                //       ),
                //       minHeight: 6,
                //     ),
                //   ),
                // ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  safeSetState(() {
                    _currentStep = index;
                  });
                  _saveData(); // Auto-save when step changes
                },
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return _buildStep(_steps[index], index);
                },
              ),
            ),

            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Future<bool> _showExitDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Exit Survey?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Your progress will be lost. Are you sure you want to exit?',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: AppTheme.textMedium),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Exit',
                  style: GoogleFonts.poppins(color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildStep(SurveyStep step, int stepIndex) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            step.title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 6),

          // Subtitle
          Text(
            step.subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 16),

          // Content based on step
          Expanded(
            child: SingleChildScrollView(child: _buildStepContent(stepIndex)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(int stepIndex) {
    // Get the current step to determine what to show
    final step = _steps[stepIndex];

    // Check by title to determine what to show
    if (step.title == 'Tell us about yourself') {
      return _buildStudentInfo();
    } else if (step.title == 'What do you want to learn?' ||
        step.title == 'Choose your learning path') {
      return _buildLearningPathSelection();
    } else if (step.title == 'What\'s your education level?' ||
        step.title == 'Education Level') {
      return _buildEducationLevelSelection();
    } else if (step.title.contains('are you in?') ||
        step.title == 'Class Selection') {
      return _buildClassSelection();
    } else if (step.title == 'What\'s your stream?' ||
        step.title == 'Stream Selection') {
      return _buildStreamSelection();
    } else if (step.title == 'Which subjects do you need help with?' ||
        step.title == 'Subjects of Interest') {
      return _buildSubjectSelection();
    } else if (step.title == 'What type of skills are you interested in?' ||
        step.title == 'Skill Category') {
      return _buildSkillCategorySelection();
    } else if (step.title == 'Which specific skills?' ||
        step.title == 'Specific Skills') {
      return _buildSpecificSkillsSelection();
    } else if (step.title == 'Which type of exam are you preparing for?') {
      return _buildExamTypeSelection();
    } else if (step.title == 'Which specific exam?') {
      return _buildSpecificExamSelection();
    } else if (step.title == 'Which subjects for this exam?') {
      return _buildExamSubjectsSelection();
    } else if (step.title == 'Tutor Qualification') {
      return _buildTutorQualification();
    } else if (step.title == 'Tutor Gender') {
      return _buildTutorGenderPreference();
    } else if (step.title == 'Learning Location') {
      return _buildLearningLocation();
    } else if (step.title == 'Schedule Preference') {
      return _buildSchedulePreference();
    } else if (step.title == 'Learning Style') {
      return _buildLearningStyle();
    } else if (step.title == 'Confidence Level') {
      return _buildConfidenceLevel();
    } else if (step.title == 'Location' ||
        step.title == 'Where are you located?') {
      return _buildLocation();
    } else if (step.title == 'Learning Goals') {
      return _buildLearningGoals();
    } else if (step.title == 'Budget Range' ||
        step.title == 'What\'s your budget per session?') {
      return _buildBudgetRange();
    } else if (step.title == 'Review & Confirm') {
      return _buildReview();
    }

    return const SizedBox();
  }

  Widget _buildStudentInfo() {
    return Column(
      children: [
        // Name field removed - already collected during signup
        _buildDateField(),
        const SizedBox(height: 20),
        _buildDropdownField(
          label: 'Gender',
          value: _studentGender,
          items: ['Male', 'Female', 'Other'],
          onChanged: (value) => safeSetState(() => _studentGender = value),
          isRequired: true,
        ),
      ],
    );
  }

  /// Update date of birth from day/month/year fields
  void _updateDateOfBirth() {
    if (_selectedDay != null &&
        _selectedMonth != null &&
        _yearController.text.isNotEmpty) {
      try {
        final day = int.parse(_selectedDay!);
        final month = int.parse(_selectedMonth!);
        final year = int.parse(_yearController.text);

        // Validate year (reasonable range: 1930 to current year)
        final currentYear = DateTime.now().year;
        if (year < 1930 || year > currentYear) {
          _studentDateOfBirth = null;
          return;
        }

        // Validate day based on month (DateTime(year, month + 1, 0) gives last day of month)
        final daysInMonth = DateTime(year, month + 1, 0).day;
        if (day < 1 || day > daysInMonth) {
          _studentDateOfBirth = null;
          return;
        }

        // Validate that date is not in the future
        final selectedDate = DateTime(year, month, day);
        if (selectedDate.isAfter(DateTime.now())) {
          _studentDateOfBirth = null;
          return;
        }

        safeSetState(() {
          _studentDateOfBirth = selectedDate;
        });
        _saveData();
      } catch (e) {
        LogService.warning('Error parsing date: $e');
        _studentDateOfBirth = null;
      }
    } else {
      _studentDateOfBirth = null;
    }
  }

  /// Get list of days based on selected month and year
  List<String> _getDaysForMonth() {
    if (_selectedMonth == null || _yearController.text.isEmpty) {
      return List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'));
    }

    try {
      final month = int.parse(_selectedMonth!);
      final year = int.parse(_yearController.text);
      // DateTime(year, month + 1, 0) gives the last day of the specified month
      final daysInMonth = DateTime(year, month + 1, 0).day;
      return List.generate(
        daysInMonth,
        (i) => (i + 1).toString().padLeft(2, '0'),
      );
    } catch (e) {
      return List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'));
    }
  }

  /// Get a valid day value for the current month/year
  /// Returns null if no valid day, or the selected day if valid, or adjusts to max valid day
  String? _getValidDayValue() {
    if (_selectedDay == null) {
      return null;
    }

    final availableDays = _getDaysForMonth();
    if (availableDays.contains(_selectedDay)) {
      return _selectedDay;
    }

    // If selected day is not valid, return the last valid day or null
    if (availableDays.isNotEmpty) {
      return availableDays.last;
    }

    return null;
  }

  Widget _buildDateField() {
    // Calculate age if date is selected
    int? age;
    String? ageText;
    if (_studentDateOfBirth != null) {
      final today = DateTime.now();
      age = today.year - _studentDateOfBirth!.year;
      if (today.month < _studentDateOfBirth!.month ||
          (today.month == _studentDateOfBirth!.month &&
              today.day < _studentDateOfBirth!.day)) {
        age--;
      }
      ageText = 'Age: $age years old';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Date of Birth',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: GoogleFonts.poppins(
                color: AppTheme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Three input fields in a row - aligned with consistent styling
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day dropdown
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _getValidDayValue(),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  hintText: 'Day',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textLight,
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
                ),
                dropdownColor: Colors.white,
                menuMaxHeight: 300,
                items: _getDaysForMonth().map((day) {
                  return DropdownMenuItem(
                    value: day,
                    child: Text(
                      day,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textDark,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  safeSetState(() {
                    _selectedDay = value;
                  });
                  _updateDateOfBirth();
                },
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textDark,
                ),
                isExpanded: true,
              ),
            ),
            const SizedBox(width: 12),
            // Month dropdown
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedMonth,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  hintText: 'Month',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textLight,
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
                ),
                dropdownColor: Colors.white,
                menuMaxHeight: 300,
                items: List.generate(12, (i) {
                  final month = (i + 1).toString().padLeft(2, '0');
                  final monthNames = [
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'May',
                    'Jun',
                    'Jul',
                    'Aug',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dec',
                  ];
                  return DropdownMenuItem(
                    value: month,
                    child: Text(
                      monthNames[i],
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textDark,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  safeSetState(() {
                    _selectedMonth = value;
                    // Reset day if it's invalid for the new month
                    if (_selectedDay != null) {
                      final availableDays = _getDaysForMonth();
                      if (!availableDays.contains(_selectedDay)) {
                        // If selected day is not valid, set to last valid day or null
                        _selectedDay = availableDays.isNotEmpty
                            ? availableDays.last
                            : null;
                      }
                    }
                  });
                  _updateDateOfBirth();
                },
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textDark,
                ),
                isExpanded: true,
              ),
                ),
                const SizedBox(width: 12),
            // Year text input
                Expanded(
              child: TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  hintText: 'Year',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textLight,
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
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                      '${_yearController.text.length}/4',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ),
                ),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textDark,
                ),
                maxLength: 4,
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                onChanged: (value) {
                  // Only allow digits
                  if (value.isNotEmpty && !RegExp(r'^\d+$').hasMatch(value)) {
                    _yearController.text = value.replaceAll(
                      RegExp(r'[^\d]'),
                      '',
                    );
                    _yearController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _yearController.text.length),
                    );
                    return;
                  }
                  safeSetState(() {
                    // Validate day when year changes
                    if (_selectedDay != null) {
                      final availableDays = _getDaysForMonth();
                      if (!availableDays.contains(_selectedDay)) {
                        // If selected day is not valid, set to last valid day or null
                        _selectedDay = availableDays.isNotEmpty
                            ? availableDays.last
                            : null;
                      }
                    }
                  });
                  _updateDateOfBirth();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return null; // Required validation is handled elsewhere
                  }
                  final year = int.tryParse(value);
                  if (year == null) {
                    return 'Invalid year';
                  }
                  final currentYear = DateTime.now().year;
                  if (year < 1930 || year > currentYear) {
                    return 'Year must be between 1930 and $currentYear';
                  }
                  return null;
                },
                  ),
                ),
              ],
            ),
        // Show age if date is valid
        if (ageText != null) ...[
          const SizedBox(height: 8),
          Text(
            ageText,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildDropdownField(
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
        buildDropdownField(
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
            value: _customQuarter,
            onChanged: (value) => safeSetState(() => _customQuarter = value),
            isRequired: true,
          ),
        ],
      ],
    );
  }

  Widget _buildLearningGoals() {
    return Column(
      children: [
        _buildMultiSelectField(
          title: 'What are your main learning goals?',
          options: SurveyConfig.learningGoals,
          selectedValues: _learningGoals,
          onSelectionChanged: (values) =>
              safeSetState(() => _learningGoals = values),
        ),
        const SizedBox(height: 16),
        _buildMultiSelectField(
          title: 'What are your biggest learning challenges?',
          options: SurveyConfig.learningChallenges,
          selectedValues: _challenges,
          onSelectionChanged: (values) => safeSetState(() => _challenges = values),
        ),
      ],
    );
  }

  Widget _buildReview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal Information Card
          _buildReviewCard(
            title: 'Personal Information',
            icon: Icons.person_outline,
            children: [
              // Name field removed - already collected during signup
              if (_studentDateOfBirth != null)
                _buildReviewItem(
                  'Date of Birth',
                  '${_studentDateOfBirth!.day}/${_studentDateOfBirth!.month}/${_studentDateOfBirth!.year}',
                ),
              _buildReviewItem('Gender', _studentGender),
            ],
          ),
          const SizedBox(height: 16),

          // Location Card
          _buildReviewCard(
            title: 'Location',
            icon: Icons.location_on_outlined,
            children: [
              if (_selectedCity != null)
                _buildReviewItem('City', _selectedCity),
              if (_isCustomQuarter && _customQuarter != null)
                _buildReviewItem('Quarter', _customQuarter)
              else if (_selectedQuarter != null)
                _buildReviewItem('Quarter', _selectedQuarter),
            ],
          ),
          const SizedBox(height: 16),

          // Learning Path Card
          _buildReviewCard(
            title: 'Learning Path',
            icon: Icons.school_outlined,
            children: [
              _buildReviewItem('Learning Path', _selectedLearningPath),
              if (_selectedEducationLevel != null)
                _buildReviewItem('Education Level', _selectedEducationLevel),
              if (_selectedClass != null)
                _buildReviewItem('Class', _selectedClass),
              if (_selectedStream != null)
                _buildReviewItem('Stream', _selectedStream),
              if (_selectedSubjects.isNotEmpty)
                _buildReviewItem('Subjects', _selectedSubjects.join(', ')),
              if (_selectedSkillCategory != null)
                _buildReviewItem('Skill Category', _selectedSkillCategory),
              if (_selectedSkills.isNotEmpty)
                _buildReviewItem('Skills', _selectedSkills.join(', ')),
              if (_selectedExamType != null)
                _buildReviewItem('Exam Type', _selectedExamType),
              if (_selectedSpecificExam != null)
                _buildReviewItem('Specific Exam', _selectedSpecificExam),
              if (_examSubjects.isNotEmpty)
                _buildReviewItem('Exam Subjects', _examSubjects.join(', ')),
            ],
          ),
          const SizedBox(height: 16),

          // Preferences Card
          _buildReviewCard(
            title: 'Preferences',
            icon: Icons.tune_outlined,
            children: [
              _buildReviewItem('Min Budget', '$_minBudget XAF'),
              _buildReviewItem('Max Budget', '$_maxBudget XAF'),
              _buildReviewItem(
                'Tutor Gender Preference',
                _tutorGenderPreference,
              ),
              _buildReviewItem('Preferred Location', _preferredLocation),
              _buildReviewItem('Preferred Schedule', _preferredSchedule),
              _buildReviewItem(
                'Learning Style(s)',
                _learningStyles.isNotEmpty
                    ? _learningStyles.join(', ')
                    : 'Not selected',
              ),
              _buildReviewItem('Confidence Level', _confidenceLevel),
            ],
          ),
          const SizedBox(height: 16),

          // Goals & Challenges Card
          if (_learningGoals.isNotEmpty || _challenges.isNotEmpty)
            _buildReviewCard(
              title: 'Goals & Challenges',
              icon: Icons.flag_outlined,
              children: [
                if (_learningGoals.isNotEmpty)
                  _buildReviewItem('Learning Goals', _learningGoals.join(', ')),
                if (_challenges.isNotEmpty)
                  _buildReviewItem('Challenges', _challenges.join(', ')),
              ],
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildReviewCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.softCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.softBorder),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String title, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectField({
    required String title,
    required List<String> options,
    required List<String> selectedValues,
    required ValueChanged<List<String>> onSelectionChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.start,
          children: options.map((option) {
            final isSelected = selectedValues.contains(option);
            return GestureDetector(
              onTap: () {
                final current = List<String>.from(selectedValues);
                if (current.contains(option)) {
                  current.remove(option);
                } else {
                  current.add(option);
                }
                onSelectionChanged(current);
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

  Widget buildDropdownField({
    required String label,
    String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.softBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.softBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isRequired = false,
  }) {
    return buildDropdownField(
      label: label,
      value: value,
      items: items,
      onChanged: onChanged,
      isRequired: isRequired,
    );
  }

  Widget _buildLearningPathSelection() {
    final programs = SurveyConfig.getProgramsForUserType('student');
    return Column(
      children: programs.map((program) {
        final config = SurveyConfig.getProgramConfig(program);
        final isSelected = _selectedLearningPath == program;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: _buildOptionCard(
            title: program,
            subtitle: config?.description,
            isSelected: isSelected,
            onTap: () {
              safeSetState(() {
                _selectedLearningPath = program;
                _resetDynamicFields();
                _updateSteps();
              });
              _saveData(); // Auto-save when learning path changes
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEducationLevelSelection() {
    return Column(
      children: SurveyConfig.educationLevels.keys.map((level) {
        final isSelected = _selectedEducationLevel == level;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: _buildOptionCard(
            title: level,
            isSelected: isSelected,
            onTap: () {
              safeSetState(() {
                _selectedEducationLevel = level;
                _selectedClass = null;
                _selectedStream = null;
                _updateSteps();
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildClassSelection() {
    if (_selectedEducationLevel == null) return const SizedBox();

    final levelConfig = SurveyConfig.getEducationLevelConfig(
      _selectedEducationLevel!,
    );
    if (levelConfig == null) return const SizedBox();

    return Column(
      children: levelConfig.classes.map((cls) {
        final isSelected = _selectedClass == cls;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: _buildOptionCard(
            title: cls,
            isSelected: isSelected,
            onTap: () {
              safeSetState(() {
                _selectedClass = cls;
                _selectedStream = null;
                _updateSteps();
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStreamSelection() {
    if (_selectedEducationLevel == null) return const SizedBox();

    final levelConfig = SurveyConfig.getEducationLevelConfig(
      _selectedEducationLevel!,
    );
    if (levelConfig?.hasStreams != true || levelConfig?.streams == null) {
      return const SizedBox();
    }

    return Column(
      children: levelConfig!.streams!.map((stream) {
        final isSelected = _selectedStream == stream;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: _buildOptionCard(
            title: stream,
            subtitle: SurveyConfig.getStreamDescription(stream),
            isSelected: isSelected,
            onTap: () {
              safeSetState(() {
                _selectedStream = stream;
                _updateSteps();
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubjectSelection() {
    // Check if university level - show text input instead
    if ((_selectedEducationLevel?.toLowerCase().contains('university') ??
            false) ||
        (_selectedEducationLevel?.toLowerCase().contains('higher education') ??
            false)) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.softCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.school,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'University Courses',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter each course on a new line\nExample:\nIntroduction to Microeconomics\nCalculus II\nOrganic Chemistry',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _universityCoursesController,
              maxLines: 8,
              onChanged: (value) {
                safeSetState(() {
                  // Split by newline and filter empty lines
                  _selectedSubjects = value
                      .split('\n')
                      .where((line) => line.trim().isNotEmpty)
                      .toList();
                });
              },
              decoration: InputDecoration(
                hintText:
                    'Type your courses here...\n\nIntroduction to Psychology\nLinear Algebra\nBusiness Statistics',
                hintStyle: GoogleFonts.poppins(
                  color: AppTheme.textLight,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: AppTheme.softCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.softBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.softBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textDark,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedSubjects.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_selectedSubjects.length} course(s) added',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
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

    // Regular subject selection for other education levels
    // Check if education level is selected
    if (_selectedEducationLevel == null || _selectedEducationLevel!.isEmpty) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.softCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please select your education level first to see available subjects.',
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

    // Check if stream is required but not selected
    final isStreamRequired = SurveyConfig.isStreamRequired(
      _selectedEducationLevel!,
    );
    final levelConfig = SurveyConfig.getEducationLevelConfig(
      _selectedEducationLevel!,
    );
    final hasStreams = levelConfig?.hasStreams == true;

    // Get subjects based on education level and stream
    final subjects = SurveyConfig.getSubjectsForEducationLevel(
      _selectedEducationLevel!,
      _selectedStream,
    );

    // If stream is required but not selected, show helpful message
    if (isStreamRequired &&
        hasStreams &&
        (_selectedStream == null || _selectedStream!.isEmpty)) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.school, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select a stream to see stream-specific subjects',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You can also select from all available subjects below, then filter by stream if needed.',
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
              ),
              const SizedBox(height: 16),
              if (subjects.isNotEmpty) ...[
                Text(
                  'Available Subjects (${subjects.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ] +
            subjects.map((subject) {
              final isSelected = _selectedSubjects.contains(subject);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: _buildOptionCard(
                  title: subject,
                  isSelected: isSelected,
                  onTap: () {
                    safeSetState(() {
                      if (isSelected) {
                        _selectedSubjects.remove(subject);
                      } else {
                        _selectedSubjects.add(subject);
                      }
                    });
                  },
                ),
              );
            }).toList(),
      );
    }

    // Stream is selected or not required - show subjects normally
    if (subjects.isEmpty) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.softCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.textMedium, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No subjects available for this education level. Please select a different level.',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: subjects.map((subject) {
        final isSelected = _selectedSubjects.contains(subject);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: _buildOptionCard(
            title: subject,
            isSelected: isSelected,
            onTap: () {
              safeSetState(() {
                if (isSelected) {
                  _selectedSubjects.remove(subject);
                } else {
                  _selectedSubjects.add(subject);
                }
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillCategorySelection() {
    return Column(
      children: SurveyConfig.skillAreas.keys.map((category) {
        final isSelected = _selectedSkillCategory == category;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: _buildOptionCard(
            title: category,
            isSelected: isSelected,
            onTap: () {
              safeSetState(() {
                _selectedSkillCategory = category;
                _selectedSkills = [];
                _updateSteps();
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpecificSkillsSelection() {
    if (_selectedSkillCategory == null) return const SizedBox();

    final skills = SurveyConfig.skillAreas[_selectedSkillCategory] ?? [];
    return Column(
      children: skills.map((skill) {
        final isSelected = _selectedSkills.contains(skill);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: _buildOptionCard(
            title: skill,
            isSelected: isSelected,
            onTap: () {
              safeSetState(() {
                if (isSelected) {
                  _selectedSkills.remove(skill);
                } else {
                  _selectedSkills.add(skill);
                }
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExamTypeSelection() {
    return Column(
      children: SurveyConfig.examTypes.keys.map((type) {
        final config = SurveyConfig.getExamTypeConfig(type);
        final isSelected = _selectedExamType == type;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: _buildOptionCard(
            title: type,
            subtitle: config?.description,
            isSelected: isSelected,
            onTap: () {
              safeSetState(() {
                _selectedExamType = type;
                _selectedSpecificExam = null;
                _examSubjects = [];
                _updateSteps();
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpecificExamSelection() {
    if (_selectedExamType == null) return const SizedBox();

    final exams = SurveyConfig.getExamsForType(_selectedExamType!);
    return Column(
      children: exams.map((exam) {
        final isSelected = _selectedSpecificExam == exam;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: _buildOptionCard(
            title: exam,
            isSelected: isSelected,
            onTap: () {
              safeSetState(() {
                _selectedSpecificExam = exam;
                _examSubjects = [];
                _updateSteps();
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExamSubjectsSelection() {
    if (_selectedSpecificExam == null) return const SizedBox();

    final subjects = SurveyConfig.getSubjectsForExam(_selectedSpecificExam!);
    return Column(
      children: subjects.map((subject) {
        final isSelected = _examSubjects.contains(subject);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: _buildOptionCard(
            title: subject,
            isSelected: isSelected,
            onTap: () {
              safeSetState(() {
                if (isSelected) {
                  _examSubjects.remove(subject);
                } else {
                  _examSubjects.add(subject);
                }
              });
            },
          ),
        );
      }).toList(),
    );
  }

  // Individual step methods for single questions per page
  Widget _buildBudgetRange() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text(
        //   'What is your budget range per month?',
        //   style: GoogleFonts.poppins(
        //     fontSize: 16,
        //     fontWeight: FontWeight.w600,
        //     color: AppTheme.textDark,
        //   ),
        // ),
        Text(
          '$_minBudget XAF - $_maxBudget XAF',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'per month',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 24),

        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            rangeThumbShape: _RoundedRectangleRangeSliderThumbShape(
              enabledThumbRadius: 18.0,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 28.0),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 18.0),
          ),
          child: RangeSlider(
          values: RangeValues(_minBudget.toDouble(), _maxBudget.toDouble()),
          min: 20000,
          max: 55000,
          divisions: 35,
          activeColor: AppTheme.primaryColor,
          inactiveColor: AppTheme.softBorder,
          onChanged: (RangeValues values) {
            safeSetState(() {
              _minBudget = values.start.round();
              _maxBudget = values.end.round();
            });
          },
          overlayColor: WidgetStateProperty.all(
            AppTheme.primaryColor.withOpacity(0.1),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Information Card (moved below budget selection)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'About Tutoring Costs',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'The cost of tutoring sessions depends on several factors, including:',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              ...[
                'Tutor\'s qualifications and experience',
                'Subject difficulty and level',
                'Distance for in-person sessions (if applicable)',
                'Length of sessions',
              ].map(
                (factor) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          factor,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Once you submit your request, we will provide a list of tutors with their hourly rates that fit your preferences. You can review the options and choose the tutor whose price works best for you.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textDark,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Payment Policy Agreement Checkbox
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _paymentPolicyAgreed
                ? AppTheme.primaryColor.withOpacity(0.05)
                : AppTheme.softCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _paymentPolicyAgreed
                  ? AppTheme.primaryColor
                  : AppTheme.softBorder,
              width: _paymentPolicyAgreed ? 2 : 1,
            ),
          ),
                child: Row(
                  children: [
              Checkbox(
                value: _paymentPolicyAgreed,
                onChanged: (value) {
                  safeSetState(() {
                    _paymentPolicyAgreed = value ?? false;
                  });
                },
                activeColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textDark,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Payment Policy',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = _showPaymentPolicy,
                    ),
                      const TextSpan(text: ' *'),
                  ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTutorGenderPreference() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title/subtitle are shown in _buildStep, so no need to repeat here
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.start,
          children: SurveyConfig.tutorGenderPreferences.map((option) {
            bool isSelected = _tutorGenderPreference == option;
            return GestureDetector(
              onTap: () => safeSetState(() => _tutorGenderPreference = option),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
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
                        size: 18,
                      ),
                    if (isSelected) const SizedBox(width: 6),
                    Text(
                      option,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
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

  Widget _buildTutorQualification() {
    final qualifications = [
      {
        'value': 'university_student',
        'label': 'University student tutor',
        'description': 'Affordable, close in age, relatable',
      },
      {
        'value': 'graduate',
        'label': 'Graduate tutor',
        'description': 'Has completed university, more experience',
      },
      {
        'value': 'professional',
        'label': 'Experienced Professional tutor',
        'description': 'Trained and certified school teachers',
      },
      {
        'value': 'no_preference',
        'label': 'No Preferences',
        'description': 'I just want someone who can teach well',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title/subtitle are shown in _buildStep, so no need to repeat here
        const SizedBox(height: 8),
        ...qualifications.map((qual) {
          bool isSelected = _tutorQualificationPreference == qual['value'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () =>
                  safeSetState(() => _tutorQualificationPreference = qual['value']),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.softBorder,
                    width: isSelected ? 2 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
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
                              : AppTheme.softBorder,
                          width: 2,
                        ),
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.white,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            qual['label'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            qual['description'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConfidenceLevel() {
    final confidenceLevels = [
      {
        'value': 'beginner',
        'label': 'Beginner',
        'description': 'Just starting, needs foundational help',
      },
      {
        'value': 'intermediate',
        'label': 'Intermediate',
        'description': 'Has some knowledge, needs improvement',
      },
      {
        'value': 'advanced',
        'label': 'Advanced',
        'description': 'Strong foundation, needs refinement',
      },
      {
        'value': 'struggling',
        'label': 'Struggling',
        'description': 'Falling behind, needs intensive support',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title/subtitle are shown in _buildStep, so no need to repeat here
        const SizedBox(height: 8),
        ...confidenceLevels.map((level) {
          bool isSelected = _confidenceLevel == level['value'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => safeSetState(() => _confidenceLevel = level['value']),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.softBorder,
                    width: isSelected ? 2 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
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
                              : AppTheme.softBorder,
                          width: 2,
                        ),
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.white,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level['label'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            level['description'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLearningLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title/subtitle are shown in _buildStep, so no need to repeat here
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.start,
          children: SurveyConfig.learningModes.map((option) {
            bool isSelected = _preferredLocation == option;
            return GestureDetector(
              onTap: () => safeSetState(() => _preferredLocation = option),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
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
                        size: 18,
                      ),
                    if (isSelected) const SizedBox(width: 6),
                    Text(
                      option,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
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

  Widget _buildSchedulePreference() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title/subtitle are shown in _buildStep, so no need to repeat here
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.start,
          children: SurveyConfig.schedulePreferences.map((option) {
            bool isSelected = _preferredSchedule == option;
            return GestureDetector(
              onTap: () => safeSetState(() => _preferredSchedule = option),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
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
                        size: 18,
                      ),
                    if (isSelected) const SizedBox(width: 6),
                    Text(
                      option,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
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

  Widget _buildLearningStyle() {
    final learningStyles = [
      {
        'value': 'Visual',
        'label': 'Visual',
        'description': 'Learn best by seeing images, diagrams, and visual aids',
      },
      {
        'value': 'Auditory',
        'label': 'Auditory',
        'description': 'Learn best by listening and discussing concepts',
      },
      {
        'value': 'Kinesthetic',
        'label': 'Kinesthetic',
        'description': 'Learn best by doing hands-on activities and practice',
      },
      {
        'value': 'Reading/Writing',
        'label': 'Reading/Writing',
        'description': 'Learn best by reading and writing notes',
      },
      {
        'value': 'Mixed',
        'label': 'Mixed',
        'description': 'A combination of different learning styles',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...learningStyles.map((style) {
          bool isSelected = _learningStyles.contains(style['value']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () {
                safeSetState(() {
                  if (isSelected) {
                    _learningStyles.remove(style['value']);
                  } else {
                    _learningStyles.add(style['value'] as String);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.softBorder,
                    width: isSelected ? 2 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
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
                              : AppTheme.softBorder,
                          width: 2,
                        ),
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.white,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                        color: Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    Text(
                            style['label'] as String,
                      style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            style['description'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
                  ],
        ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    String? value,
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: AppTheme.textLight,
              fontSize: 12,
            ),
            filled: true,
            fillColor: AppTheme.softCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.softBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.softBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.softBorder,
            width: isSelected ? 2 : 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.softBorder,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          // Circular back button (only show if not on first step)
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
                icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
                onPressed: _previousStep,
                padding: EdgeInsets.zero,
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          // Next/Complete button - Beautiful rounded style
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _canProceed() ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canProceed()
                      ? AppTheme.primaryColor
                      : AppTheme.neutral200,
                  foregroundColor: _canProceed()
                      ? Colors.white
                      : AppTheme.textLight,
                  elevation: _canProceed() ? 2 : 0,
                  shadowColor: _canProceed()
                      ? AppTheme.primaryColor.withOpacity(0.3)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  _currentStep == _steps.length - 1 ? 'Complete' : 'Next',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    // Use title-based checking to handle dynamic step insertion
    final step = _steps[_currentStep];

    if (step.title == 'Tell us about yourself') {
      // Name is only required if the field is shown (name doesn't exist in DB)
      // If name exists in DB, field is hidden and name is not required
      // Name field removed - already collected during signup
      // Only require date of birth and gender
      return _studentDateOfBirth != null && _studentGender != null;
    } else if (step.title == 'What do you want to learn?' ||
        step.title == 'Choose your learning path') {
      return _selectedLearningPath != null;
    } else if (step.title == 'What\'s your education level?' ||
        step.title == 'Education Level') {
      return _selectedEducationLevel != null;
    } else if (step.title.contains('are you in?') ||
        step.title == 'Class Selection') {
      return _selectedClass != null;
    } else if (step.title == 'What\'s your stream?' ||
        step.title == 'Stream Selection') {
      return _selectedStream != null;
    } else if (step.title == 'Which subjects do you need help with?' ||
        step.title == 'Subjects of Interest') {
      return _selectedSubjects.isNotEmpty;
    } else if (step.title == 'What type of skills are you interested in?' ||
        step.title == 'Skill Category') {
      return _selectedSkillCategory != null;
    } else if (step.title == 'Which specific skills?' ||
        step.title == 'Specific Skills') {
      return _selectedSkills.isNotEmpty;
    } else if (step.title == 'Which type of exam are you preparing for?') {
      return _selectedExamType != null;
    } else if (step.title == 'Which specific exam?') {
      return _selectedSpecificExam != null;
    } else if (step.title == 'Which subjects for this exam?') {
      return _examSubjects.isNotEmpty;
    } else if (step.title == 'Budget Range' ||
        step.title == 'What\'s your budget per session?') {
      // Budget range always has a default value, but payment policy agreement is required
      return _paymentPolicyAgreed;
    } else if (step.title == 'Tutor Qualification') {
      return _tutorQualificationPreference != null;
    } else if (step.title == 'Tutor Gender') {
      return _tutorGenderPreference != null;
    } else if (step.title == 'Learning Location') {
      return _preferredLocation != null;
    } else if (step.title == 'Schedule Preference') {
      return _preferredSchedule != null;
    } else if (step.title == 'Learning Style') {
      return _learningStyles.isNotEmpty;
    } else if (step.title == 'Confidence Level') {
      return _confidenceLevel != null;
    } else if (step.title == 'Location' ||
        step.title == 'Where are you located?') {
      return _selectedCity != null &&
          (_selectedQuarter != null ||
              (_isCustomQuarter &&
                  _customQuarter != null &&
                  _customQuarter!.isNotEmpty));
    } else if (step.title == 'Learning Goals') {
      return _learningGoals.isNotEmpty;
    } else if (step.title == 'Review & Confirm') {
      return true; // Review step - always can proceed
    }

    return false;
  }

  void _resetDynamicFields() {
    _selectedEducationLevel = null;
    _selectedClass = null;
    _selectedStream = null;
    _selectedSubjects = [];
    _selectedSkillCategory = null;
    _selectedSkills = [];
    _selectedExamType = null;
    _selectedSpecificExam = null;
    _examSubjects = [];
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeSurvey();
    }
  }

  void _showPaymentPolicy() {
    const paymentPolicyContent =
        '''All payments for tutoring sessions are made through PrepSkul.

Sessions are paid for before the start of the learning period.

If a session needs to be rescheduled, please notify PrepSkul at least 6 hours in advance.

If a session is cancelled late or missed without notice, that session may still be charged.

If you have concerns or are not satisfied with a session, you may report it to PrepSkul within 24 hours.

PrepSkul handles tutor payments only after session confirmation, ensuring your learning experience is protected and monitored.

No direct payments should be made to tutors outside the platform.''';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InstructionScreen(
          title: 'Payment Policy Agreement',
          content: paymentPolicyContent,
          icon: Icons.policy_outlined,
        ),
      ),
    );
  }

  Future<void> _completeSurvey() async {
    try {
      LogService.info('Student Survey submission started...');

      // Show loading indicator
      if (!mounted) return;
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
                  'Saving your preferences...',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Get current user
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Prepare survey data to save to learner_profiles
      final surveyData = <String, dynamic>{
        // Location
        'city': _selectedCity,
        'quarter': _isCustomQuarter ? _customQuarter : _selectedQuarter,
        // Learning Path
        'learning_path': _selectedLearningPath,
        // Academic Tutoring
        if (_selectedLearningPath == 'Academic Tutoring') ...{
          'education_level': _selectedEducationLevel,
          'class_level': _selectedClass,
          'stream': _selectedStream,
          'subjects':
              (_selectedSubjects != null && _selectedSubjects.isNotEmpty)
              ? _selectedSubjects
              : null,
          'university_courses':
              _universityCoursesController.text.trim().isNotEmpty
              ? _universityCoursesController.text.trim()
              : null,
        },
        // Skill Development
        if (_selectedLearningPath == 'Skill Development') ...{
          'skill_category': _selectedSkillCategory,
          'skills': (_selectedSkills != null && _selectedSkills.isNotEmpty)
              ? _selectedSkills
              : null,
        },
        // Exam Preparation
        if (_selectedLearningPath == 'Exam Preparation') ...{
          'exam_type': _selectedExamType,
          'specific_exam': _selectedSpecificExam,
          'exam_subjects': (_examSubjects != null && _examSubjects.isNotEmpty)
              ? _examSubjects
              : null,
        },
        // Preferences
        'budget_min': _minBudget,
        'budget_max': _maxBudget,
        'tutor_gender_preference': _tutorGenderPreference,
        'tutor_qualification_preference': _tutorQualificationPreference,
        'preferred_location': _preferredLocation,
        'preferred_schedule': _preferredSchedule != null
            ? [_preferredSchedule!]
            : null,
        'learning_styles': _learningStyles.isNotEmpty
            ? _learningStyles
            : null, // TEXT[] array
        'confidence_level': _confidenceLevel,
        'learning_goals': _learningGoals.isNotEmpty ? _learningGoals : null,
        'challenges': _challenges.isNotEmpty ? _challenges : null,
        'payment_policy_agreed': _paymentPolicyAgreed,
      };

      // Save to database
      await SurveyRepository.saveStudentSurvey(userId, surveyData);

      // Get user profile for notification
      final userProfile = await SupabaseService.client
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      final userName = userProfile?['full_name'] as String? ?? 'Student';

      // Notify admins about survey completion
      try {
        await NotificationHelperService.notifyAdminsAboutSurveyCompletion(
          userId: userId,
          userType: 'student',
          userName: userName,
          learningPath: _selectedLearningPath ?? '',
          surveyDetails: {
            'subjects': surveyData['subjects'],
            'skills': surveyData['skills'],
            'exam_type': surveyData['exam_type'],
            'city': surveyData['city'],
            'budget_min': surveyData['budget_min'],
            'budget_max': surveyData['budget_max'],
          },
        );
      } catch (e) {
        LogService.warning('Error notifying admins about survey: $e');
        // Don't block survey completion if notification fails
      }

      // Clear saved onboarding data to prevent resuming on restart
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('student_survey_data');
      await prefs.setBool('survey_completed', true);
      LogService.success('Cleared saved student survey data after submission');

      LogService.success('Student survey saved successfully!');

      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show beautiful success dialog with confetti
      if (!mounted) return;
      await _showSurveyCompletionDialog();

      // Wait a bit for confetti animation before navigating
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to student dashboard
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/student-nav');
    } catch (e) {
      LogService.error('Error saving student survey: $e');

      // Close loading dialog if open
      if (mounted) Navigator.of(context).pop();

      // Show error dialog
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Error',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Failed to save survey. Please try again.\n\nError: $e',
            style: GoogleFonts.poppins(),
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
    }
  }
}

/// Custom range slider thumb shape with rounded rectangle instead of circle
class _RoundedRectangleRangeSliderThumbShape extends RangeSliderThumbShape {
  const _RoundedRectangleRangeSliderThumbShape({
    this.enabledThumbRadius = 12.0,
    this.disabledThumbRadius = 8.0,
  });

  final double enabledThumbRadius;
  final double disabledThumbRadius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(
      isEnabled ? enabledThumbRadius : disabledThumbRadius,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = true,
    bool isOnTop = false,
    TextDirection textDirection = TextDirection.ltr,
    required SliderThemeData sliderTheme,
    Thumb thumb = Thumb.start,
    bool isPressed = false,
  }) {
    final Canvas canvas = context.canvas;
    final ColorTween colorTween = ColorTween(
      begin: sliderTheme.disabledThumbColor,
      end: sliderTheme.thumbColor,
    );
    final ColorTween borderColorTween = ColorTween(
      begin: sliderTheme.disabledThumbColor,
      end: isPressed
          ? sliderTheme.thumbColor?.withOpacity(0.8)
          : sliderTheme.thumbColor,
    );

    final Color color = colorTween.evaluate(enableAnimation)!;
    final Color borderColor = borderColorTween.evaluate(enableAnimation)!;

    final double radius = isEnabled ? enabledThumbRadius : disabledThumbRadius;

    // Create rounded rectangle instead of circle
    final RRect thumbRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
      Radius.circular(radius * 0.4), // Rounded corners (40% of radius)
    );

    // Draw shadow/elevation
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    canvas.drawRRect(thumbRect.shift(const Offset(0, 2)), shadowPaint);

    // Draw border
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(thumbRect, borderPaint);

    // Draw fill
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRRect(thumbRect, fillPaint);
  }
}

class SurveyStep {
  final String title;
  final String subtitle;

  const SurveyStep({required this.title, required this.subtitle});
}
