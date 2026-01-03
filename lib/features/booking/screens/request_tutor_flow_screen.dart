import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/auth_service.dart' hide LogService;
import 'package:prepskul/core/localization/app_localizations.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/services/error_handler_service.dart';
import 'package:prepskul/features/booking/services/tutor_request_service.dart';
import 'package:prepskul/data/app_data.dart';
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
  List<String> _userSubjects = []; // User's subjects from survey (pre-selected)
  List<String> _availableSubjects =
      []; // All available subjects for user's niche
  String? _educationLevel;
  List<String> _selectedRequirements =
      []; // Changed from text field to multi-select

  // Step 2: Tutor Preferences
  String? _tutorGender;
  String? _tutorQualification;
  String? _teachingMode; // online, onsite, hybrid
  int _minBudget = 20000;  // Monthly budget (XAF)
  int _maxBudget = 100000;  // Monthly budget (XAF)

  // Step 3: Schedule & Location
  List<String> _preferredDays = [];
  String? _preferredTime;
  String? _location;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _locationDescriptionController =
      TextEditingController();

  // Step 4: Additional Details
  String? _requestReason; // Selected reason for requesting tutor
  final TextEditingController _customReasonController = TextEditingController();
  String _urgency = 'normal'; // urgent, normal, flexible

  @override
  void initState() {
    super.initState();
    _prefillFromData();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _locationDescriptionController.dispose();
    _customReasonController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Pre-fill data from search filters or survey
  Future<void> _prefillFromData() async {
    if (widget.prefillData != null) {
      safeSetState(() {
        _selectedSubjects = List<String>.from(
          widget.prefillData!['subjects'] ?? [],
        );
        _userSubjects = List<String>.from(_selectedSubjects);
        _educationLevel = widget.prefillData!['education_level'];
        _teachingMode = widget.prefillData!['teaching_mode'];
        _location = widget.prefillData!['location'];
        if (_location != null) {
          _locationController.text = _location!;
        }
      });
      _loadAvailableSubjects();
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
          // Get user's subjects/skills from survey based on learning path
          final learningPath = surveyData['learning_path']?.toString();
          List<String> userSubjects = [];
          
          if (learningPath == 'Academic Tutoring') {
            // For academic tutoring, use subjects
            userSubjects = List<String>.from(surveyData['subjects'] ?? []);
          } else if (learningPath == 'Skill Development') {
            // For skill development, use skills
            userSubjects = List<String>.from(surveyData['skills'] ?? []);
          } else if (learningPath == 'Exam Preparation') {
            // For exam preparation, use exam_subjects
            userSubjects = List<String>.from(surveyData['exam_subjects'] ?? []);
          } else {
            // Fallback to subjects if learning path not set
            userSubjects = List<String>.from(surveyData['subjects'] ?? []);
            // Also check skills as fallback
            if (userSubjects.isEmpty) {
              userSubjects = List<String>.from(surveyData['skills'] ?? []);
            }
          }

          // Map education level from survey to display format
          String? educationLevel = _mapEducationLevel(surveyData);

          // Get system (anglophone/francophone) - default to anglophone
          final system = surveyData['system'] ?? 'anglophone';
          final stream = surveyData['stream'];
          final eduLevel = surveyData['education_level'];

          // Load available subjects based on user's niche
          List<String> availableSubjects = [];
          if (eduLevel != null) {
            String levelKey = _mapEducationLevelToKey(eduLevel.toString());
            availableSubjects = AppData.getSubjectsForLevel(
              levelKey,
              system.toString(),
              stream: stream?.toString(),
            );
          }

          // If no subjects found from education level, try to use user's subjects
          // or fall back to defaults
          if (availableSubjects.isEmpty && userSubjects.isNotEmpty) {
            // Use user's subjects as the base list
            availableSubjects = List<String>.from(userSubjects);
          }
          
                    // Prioritize user's subjects from survey
          // Only use generic subjects if BOTH user's subjects AND available subjects are empty
          if (availableSubjects.isEmpty && userSubjects.isEmpty) {
            availableSubjects = [
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
          }
          
          // If user has subjects but no available subjects, use user's subjects as available
          if (availableSubjects.isEmpty && userSubjects.isNotEmpty) {
            availableSubjects = List<String>.from(userSubjects);
          }
safeSetState(() {
            _userSubjects = userSubjects;
            _selectedSubjects = List<String>.from(
              userSubjects,
            ); // Pre-select user's subjects

            // Combine user's subjects/skills with available subjects
            // CRITICAL: User's selected subjects MUST appear FIRST
            final Set<String> allSubjectsSet = {};
            
            // Step 1: Add user's selected subjects/skills FIRST (these are pre-selected)
            for (var subject in userSubjects) {
              if (subject != null && subject.toString().trim().isNotEmpty) {
                allSubjectsSet.add(subject.toString().trim());
              }
            }
            
            // Step 2: Add available subjects from user's niche (education level/stream)
            for (var subject in availableSubjects) {
              if (subject != null && subject.toString().trim().isNotEmpty) {
                allSubjectsSet.add(subject.toString().trim());
              }
            }
            
            // Step 3: Build final list with user's subjects FIRST, then others alphabetically
            final List<String> finalSubjectsList = [];
            
            // Add user's subjects FIRST (in the order they were selected)
            for (var subject in userSubjects) {
              final subjectStr = subject.toString().trim();
              if (subjectStr.isNotEmpty && allSubjectsSet.contains(subjectStr) && !finalSubjectsList.contains(subjectStr)) {
                finalSubjectsList.add(subjectStr);
              }
            }
            
            // Add other available subjects (alphabetically sorted)
            final otherSubjects = allSubjectsSet
                .where((s) => !userSubjects.contains(s))
                .toList()
              ..sort();
            finalSubjectsList.addAll(otherSubjects);
            
            // If still empty, add defaults
            if (finalSubjectsList.isEmpty) {
              finalSubjectsList.addAll([
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
              ]);
            }
            
            _availableSubjects = finalSubjectsList;
            _educationLevel = educationLevel;
            
            // Pre-fill specific requirements from survey
            final specificReqs = surveyData?['specific_requirements'];
            final learningGoals = surveyData?['learning_goals'];
            final challenges = surveyData?['challenges'];
            
            if (specificReqs != null) {
              if (specificReqs is List) {
                _selectedRequirements = List<String>.from(specificReqs);
              } else if (specificReqs is String) {
                _selectedRequirements = specificReqs.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              }
            } else if (learningGoals != null && learningGoals is List) {
              _selectedRequirements = List<String>.from(learningGoals);
            } else if (challenges != null && challenges is List) {
              _selectedRequirements = List<String>.from(challenges);
            }
            _minBudget = ((surveyData?['budget_min'] as num?)?.toInt() ?? 20000).clamp(2000, 200000);  // Monthly budget default
            _maxBudget = ((surveyData?['budget_max'] as num?)?.toInt() ?? 100000).clamp(2000, 200000);  // Monthly budget default
            _tutorGender = surveyData?['tutor_gender_preference']?.toString();
            _tutorQualification = surveyData?['tutor_qualification_preference']
                ?.toString();
            _teachingMode = surveyData?['preferred_location']?.toString();

            final city = surveyData?['city']?.toString();
            final quarter = surveyData?['quarter']?.toString();
            if (city != null && quarter != null) {
              final street = surveyData?['street']?.toString();
              final streetStr = street != null && street.isNotEmpty
                  ? ', $street'
                  : '';
              _location = '$city, $quarter$streetStr';
              _locationController.text = _location!;
            }

            // Pre-fill location description if available
            final locationDesc = surveyData?['location_description']
                ?.toString();
            if (locationDesc != null && locationDesc.isNotEmpty) {
              _locationDescriptionController.text = locationDesc;
            } else {
              final additionalInfo = surveyData?['additional_address_info']
                  ?.toString();
              if (additionalInfo != null && additionalInfo.isNotEmpty) {
                _locationDescriptionController.text = additionalInfo;
              }
            }
          });
        } else {
          // No survey data, use default subjects
          _loadAvailableSubjects();
        }
      } catch (e) {
        LogService.debug('Error prefilling from survey: $e');
        _loadAvailableSubjects();
      }
    }
  }

  /// Load available subjects based on education level
  void _loadAvailableSubjects() {
    if (_availableSubjects.isEmpty) {
      // Default subjects list
      _availableSubjects = [
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
    }
  }

  /// Map education level from survey to display format
  String? _mapEducationLevel(Map<String, dynamic> surveyData) {
    // First check if class_level is available (more specific)
    final classLevel = surveyData['class_level']?.toString() ?? 
                       surveyData['class']?.toString();
    
    // Then check education_level
    final eduLevel = surveyData['education_level']?.toString() ??
                    surveyData['selected_education_level']?.toString();
    
    // Prefer class_level if available, otherwise use education_level
    final levelToMap = classLevel ?? eduLevel;
    
    if (levelToMap == null) return null;

    // Normalize the education level (trim and lowercase for comparison)
    final normalized = levelToMap.trim().toLowerCase();

    // Map survey education level to request tutor format
    // Handle various formats that might come from survey
    final levelMap = {
      // Primary School
      'primary school': 'Primary School',
      'primary': 'Primary School',
      'primary_school': 'Primary School',
      'primary-school': 'Primary School',

      // Form 1-3
      'form 1-3': 'Form 1-3',
      'form 1 - 3': 'Form 1-3',
      'form1-3': 'Form 1-3',
      'lower_secondary': 'Form 1-3',
      'lower secondary': 'Form 1-3',
      'form 1 to 3': 'Form 1-3',

      // O-Level
      'form 4-5 (o-level)': 'Form 4-5 (O-Level)',
      'form 4-5': 'Form 4-5 (O-Level)',
      'form 4 - 5': 'Form 4-5 (O-Level)',
      'form4-5': 'Form 4-5 (O-Level)',
      'o-level': 'Form 4-5 (O-Level)',
      'o level': 'Form 4-5 (O-Level)',
      'olevel': 'Form 4-5 (O-Level)',
      'ordinary level': 'Form 4-5 (O-Level)',

      // Lower Sixth
      'lower sixth': 'Lower Sixth',
      'lower_sixth': 'Lower Sixth',
      'lower-sixth': 'Lower Sixth',
      'lower 6': 'Lower Sixth',
      'lower6': 'Lower Sixth',

      // Upper Sixth (A-Level)
      'upper sixth (a-level)': 'Upper Sixth (A-Level)',
      'upper sixth': 'Upper Sixth (A-Level)',
      'upper_sixth': 'Upper Sixth (A-Level)',
      'upper-sixth': 'Upper Sixth (A-Level)',
      'upper 6': 'Upper Sixth (A-Level)',
      'upper6': 'Upper Sixth (A-Level)',
      'a-level': 'Upper Sixth (A-Level)',
      'a level': 'Upper Sixth (A-Level)',
      'alevel': 'Upper Sixth (A-Level)',
      'advanced level': 'Upper Sixth (A-Level)',
      'upper_secondary': 'Upper Sixth (A-Level)',
      'upper secondary': 'Upper Sixth (A-Level)',

      // University
      'university': 'University',
      'higher_education': 'University',
      'higher education': 'University',
      'college': 'University',
      'tertiary': 'University',
    };

    // Try exact match first, then normalized match
    return levelMap[eduLevel] ?? levelMap[normalized] ?? eduLevel;
  }

  /// Map education level display to data key
  String _mapEducationLevelToKey(String level) {
    final keyMap = {
      'Primary School': 'primary',
      'Form 1-3': 'lower_secondary',
      'Form 4-5 (O-Level)': 'lower_secondary',
      'Lower Sixth': 'upper_secondary',
      'Upper Sixth (A-Level)': 'upper_secondary',
      'University': 'higher_education',
    };
    return keyMap[level] ?? 'primary';
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
              onPageChanged: (index) => safeSetState(() => _currentStep = index),
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
                          ? AppLocalizations.of(context)!.requestTutorSubmitRequest
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
    // Use available subjects - user's selected subjects will be first
    // This list is already properly ordered from _prefillFromData
    final subjects = _availableSubjects.isNotEmpty
        ? _availableSubjects
        : [
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
    
    // Debug: Print to verify user's subjects are first
    if (_userSubjects.isNotEmpty) {
      LogService.debug('📚 User\'s selected subjects (should appear first): ${_userSubjects}');
      LogService.debug('📚 Available subjects list: ${subjects.take(10).toList()}');
    }

    final levels = [
      'Primary School',
      'Form 1-3',
      'Form 4-5 (O-Level)',
      'Lower Sixth',
      'Upper Sixth (A-Level)',
      'University',
    ];

    // Get requirement options
    final requirementOptions = _getRequirementOptions();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
            'What subject do you need help with?',
            style: GoogleFonts.poppins(
                    fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
                    height: 1.2,
            ),
                ),
              ),
            ],
          ),
          if (_userSubjects.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.15),
                    AppTheme.primaryColor.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pre-filled from your profile',
                      style: GoogleFonts.poppins(
                            fontSize: 13,
                        color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'You can add more subjects if needed',
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
            ),
          ],
          if (_userSubjects.isEmpty) ...[
            const SizedBox(height: 12),
          Text(
              'Select all subjects you need tutoring for',
            style: GoogleFonts.poppins(
                fontSize: 15,
              color: AppTheme.textMedium,
                fontWeight: FontWeight.w500,
            ),
          ),
          ],
          const SizedBox(height: 24),

          // Subjects - Modern colorful chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: subjects.map((subject) {
              final isSelected = _selectedSubjects.contains(subject);
              final isUserSubject = _userSubjects.contains(subject);
              
              // Color scheme based on selection
              final colors = _getSubjectColors(subject, isSelected, isUserSubject);
              
              return InkWell(
                onTap: () {
                  safeSetState(() {
                    if (isSelected) {
                      _selectedSubjects.remove(subject);
                    } else {
                      _selectedSubjects.add(subject);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: colors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                    : null,
                    color: isSelected ? null : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? colors[0]
                          : (isUserSubject
                              ? AppTheme.primaryColor.withOpacity(0.3)
                              : Colors.grey[300]!),
                      width: isSelected ? 0 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colors[0].withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                    : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUserSubject && isSelected)
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      if (isUserSubject && isSelected) const SizedBox(width: 6),
                      Text(
                        subject,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Education Level - Modern card selection
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.school_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context)!.requestTutorEducationLevel,
            style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
            ],
          ),
          const SizedBox(height: 16),
          ...levels.map((level) {
            final isSelected = _educationLevel == level;
            final icon = _getEducationLevelIcon(level);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => safeSetState(() => _educationLevel = level),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.grey[300]!,
                      width: isSelected ? 0 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.2)
                              : AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? Colors.white : AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                    level,
                    style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                      color: AppTheme.primaryColor,
                            size: 18,
                          ),
                    ),
                ],
              ),
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 24),

          // Specific Requirements - Modern design
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context)!.requestTutorSpecificRequirements,
            style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.requestTutorSelectAll,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: requirementOptions.map((req) {
              final isSelected = _selectedRequirements.contains(req['value']);
              final reqColors = _getRequirementColors(req['value'] as String, isSelected);
              
              return InkWell(
                onTap: () {
                  safeSetState(() {
                    if (isSelected) {
                      _selectedRequirements.remove(req['value'] as String);
                    } else {
                      _selectedRequirements.add(req['value'] as String);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: reqColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? reqColors[0]
                          : Colors.grey[300]!,
                      width: isSelected ? 0 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: reqColors[0].withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (req['icon'] != null) ...[
                      Icon(
                        req['icon'] as IconData,
                          size: 18,
                          color: isSelected ? Colors.white : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        req['label'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Colors.white,
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

  /// Get color scheme for subject chips
  List<Color> _getSubjectColors(String subject, bool isSelected, bool isUserSubject) {
    if (!isSelected) return [Colors.grey, Colors.grey];
    
    // Different color gradients for different subjects
    final subjectLower = subject.toLowerCase();
    if (subjectLower.contains('math') || subjectLower.contains('physics')) {
      return [Colors.blue[600]!, Colors.blue[400]!];
    } else if (subjectLower.contains('chem') || subjectLower.contains('bio')) {
      return [Colors.green[600]!, Colors.green[400]!];
    } else if (subjectLower.contains('english') || subjectLower.contains('french')) {
      return [Colors.purple[600]!, Colors.purple[400]!];
    } else if (subjectLower.contains('computer') || subjectLower.contains('science')) {
      return [Colors.orange[600]!, Colors.orange[400]!];
    } else {
      return [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.7)];
    }
  }

  /// Get icon for education level
  IconData _getEducationLevelIcon(String level) {
    if (level.contains('Primary')) {
      return Icons.child_care_rounded;
    } else if (level.contains('Form 1-3')) {
      return Icons.school_rounded;
    } else if (level.contains('O-Level')) {
      return Icons.assignment_rounded;
    } else if (level.contains('Lower Sixth')) {
      return Icons.menu_book_rounded;
    } else if (level.contains('A-Level')) {
      return Icons.workspace_premium_rounded;
    } else if (level.contains('University')) {
      return Icons.school_rounded;
    }
    return Icons.school_rounded;
  }

  /// Get color scheme for requirement chips
  List<Color> _getRequirementColors(String value, bool isSelected) {
    if (!isSelected) return [Colors.grey, Colors.grey];
    
    switch (value) {
      case 'exam_preparation':
        return [Colors.red[600]!, Colors.red[400]!];
      case 'gce_exams':
        return [Colors.blue[600]!, Colors.blue[400]!];
      case 'homework_help':
        return [Colors.green[600]!, Colors.green[400]!];
      case 'catch_up':
        return [Colors.orange[600]!, Colors.orange[400]!];
      case 'difficult_topic':
        return [Colors.purple[600]!, Colors.purple[400]!];
      case 'improve_grades':
        return [Colors.teal[600]!, Colors.teal[400]!];
      default:
        return [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.7)];
    }
  }

  List<Map<String, dynamic>> _getRequirementOptions() {
    return [
      {
        'value': 'exam_preparation',
        'label': 'Exam Preparation',
        'icon': Icons.assignment_turned_in,
      },
      {'value': 'gce_exams', 'label': 'GCE Exams', 'icon': Icons.school},
      {
        'value': 'homework_help',
        'label': 'Homework Help',
        'icon': Icons.edit_note,
      },
      {
        'value': 'catch_up',
        'label': 'Catch Up on Missed Lessons',
        'icon': Icons.schedule,
      },
      {
        'value': 'difficult_topic',
        'label': 'Struggling with Topic',
        'icon': Icons.help_outline,
      },
      {
        'value': 'improve_grades',
        'label': 'Improve Grades',
        'icon': Icons.trending_up,
      },
      {
        'value': 'advanced_learning',
        'label': 'Advanced Learning',
        'icon': Icons.lightbulb_outline,
      },
      {'value': 'test_practice', 'label': 'Test Practice', 'icon': Icons.quiz},
      {
        'value': 'project_help',
        'label': 'Project Help',
        'icon': Icons.folder_special,
      },
      {
        'value': 'study_skills',
        'label': 'Study Skills',
        'icon': Icons.menu_book,
      },
    ];
  }

  Widget _buildStep2Preferences() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.requestTutorTutorPreferences,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.requestTutorHelpFindMatch,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 32),

          // Teaching Mode
          _buildSectionTitle(AppLocalizations.of(context)!.requestTutorTeachingMode),
          const SizedBox(height: 12),
          _buildOptionCard(
            icon: Icons.laptop_mac,
            title: 'Online',
            subtitle: 'Virtual sessions via video call',
            isSelected: _teachingMode == 'online',
            onTap: () => safeSetState(() => _teachingMode = 'online'),
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            icon: Icons.home,
            title: 'Onsite',
            subtitle: 'In-person at your location',
            isSelected: _teachingMode == 'onsite',
            onTap: () => safeSetState(() => _teachingMode = 'onsite'),
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            icon: Icons.sync_alt,
            title: 'Hybrid',
            subtitle: 'Mix of online and onsite',
            isSelected: _teachingMode == 'hybrid',
            onTap: () => safeSetState(() => _teachingMode = 'hybrid'),
          ),
          const SizedBox(height: 32),

          // Budget Range
          _buildSectionTitle(AppLocalizations.of(context)!.requestTutorBudgetRange),
          Text(
            AppLocalizations.of(context)!.requestTutorPerMonth,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
            ),
          ),
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
            values: RangeValues(_minBudget.toDouble().clamp(2000.0, 200000.0), _maxBudget.toDouble().clamp(2000.0, 200000.0)),
            min: 2000,
            max: 200000,  // Monthly budget range
            divisions: 36,
            activeColor: AppTheme.primaryColor,
            onChanged: (values) {
              safeSetState(() {
                _minBudget = values.start.toInt();
                _maxBudget = values.end.toInt();
              });
            },
          ),
          const SizedBox(height: 24),

          // Gender Preference
          _buildSectionTitle(AppLocalizations.of(context)!.requestTutorGenderPreference),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: ['Male', 'Female', 'No Preference'].map((gender) {
              final isSelected = _tutorGender == gender;
              return ChoiceChip(
                label: Text(gender),
                selected: isSelected,
                onSelected: (selected) {
                  safeSetState(() => _tutorGender = selected ? gender : null);
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
          _buildSectionTitle(AppLocalizations.of(context)!.requestTutorQualification),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                [
                  'Student Tutor',
                  'Graduate',
                  'Professional',
                  'No Preference',
                ].map((qual) {
                  final isSelected = _tutorQualification == qual;
                  return ChoiceChip(
                    label: Text(qual),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(
                        () => _tutorQualification = selected ? qual : null,
                      );
                    },
                    selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textDark,
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
            AppLocalizations.of(context)!.requestTutorScheduleLocation,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.requestTutorWhenWhere,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 32),

          // Preferred Days
          _buildSectionTitle(AppLocalizations.of(context)!.requestTutorPreferredDays),
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
                  safeSetState(() {
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
          _buildSectionTitle(AppLocalizations.of(context)!.requestTutorPreferredTime),
          const SizedBox(height: 12),
          ...times.map((time) {
            return RadioListTile<String>(
              value: time,
              groupValue: _preferredTime,
              onChanged: (value) => safeSetState(() => _preferredTime = value),
              title: Text(time, style: GoogleFonts.poppins(fontSize: 14)),
              activeColor: AppTheme.primaryColor,
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
          const SizedBox(height: 32),

          // Location
          _buildSectionTitle(AppLocalizations.of(context)!.requestTutorLocation),
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
          const SizedBox(height: 16),
          TextField(
            controller: _locationDescriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.requestTutorLocationDescription,
              hintText:
                  'Add landmarks, nearby buildings, or clear directions to help the tutor find your location easily',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[400],
              ),
              prefixIcon: Icon(
                Icons.description_outlined,
                color: AppTheme.primaryColor,
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
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewItem('Subjects', _selectedSubjects.join(', ')),
                const Divider(height: 24),
                _buildReviewItem('Level', _educationLevel ?? 'Not specified'),
                if (_selectedRequirements.isNotEmpty) ...[
                  const Divider(height: 24),
                  _buildReviewItem(
                    'Requirements',
                    _selectedRequirements
                        .map((r) {
                          final options = _getRequirementOptions();
                          final option = options.firstWhere(
                            (o) => o['value'] == r,
                            orElse: () => {'label': r, 'value': r},
                          );
                          return option['label'] as String;
                        })
                        .join(', '),
                  ),
                ],
                const Divider(height: 24),
                _buildReviewItem(
                  'Teaching Mode',
                  _teachingMode?.toUpperCase() ?? '',
                ),
                const Divider(height: 24),
                _buildReviewItem(
                  'Budget',
                  '$_minBudget - $_maxBudget XAF per month',
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
          _buildSectionTitle(AppLocalizations.of(context)!.requestTutorUrgency),
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
              onChanged: (value) => safeSetState(() => _urgency = value!),
              title: Text(
                labels[urgencyLevel]!,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              activeColor: AppTheme.primaryColor,
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
          const SizedBox(height: 24),

          // Why do you need a tutor? (Optional)
          _buildSectionTitle('Why do you need a tutor? (Optional)'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
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
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select a reason to help us find the best tutor for you',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Reason options
          ..._getRequestReasonOptions().map((reason) {
            final isSelected = _requestReason == reason['value'];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: _buildOptionCard(
                icon: reason['icon'] as IconData,
                title: reason['title'] as String,
                subtitle: reason['subtitle'] as String?,
                isSelected: isSelected,
                onTap: () {
                  safeSetState(() {
                    _requestReason = reason['value'] as String;
                    if (_requestReason != 'other') {
                      _customReasonController.clear();
                    }
                  });
                },
              ),
            );
          }).toList(),
          // Custom reason text field (only if "Other" is selected)
          if (_requestReason == 'other') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customReasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Please specify',
                hintText: 'Tell us why you need a tutor...',
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
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
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
    String? subtitle,
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
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[200],
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 24),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getRequestReasonOptions() {
    return [
      {
        'value': 'exam_preparation',
        'title': 'Exam Preparation',
        'subtitle': 'Preparing for upcoming exams or tests',
        'icon': Icons.assignment,
      },
      {
        'value': 'improve_grades',
        'title': 'Improve Grades',
        'subtitle': 'Want to boost academic performance',
        'icon': Icons.trending_up,
      },
      {
        'value': 'catch_up',
        'title': 'Catch Up on Missed Lessons',
        'subtitle': 'Need to cover missed school work',
        'icon': Icons.schedule,
      },
      {
        'value': 'difficult_subject',
        'title': 'Struggling with Subject',
        'subtitle': 'Finding a particular subject challenging',
        'icon': Icons.help_outline,
      },
      {
        'value': 'advanced_learning',
        'title': 'Advanced Learning',
        'subtitle': 'Want to go beyond school curriculum',
        'icon': Icons.school,
      },
      {
        'value': 'homework_help',
        'title': 'Homework Help',
        'subtitle': 'Need regular assistance with assignments',
        'icon': Icons.edit_note,
      },
      {
        'value': 'study_skills',
        'title': 'Study Skills & Techniques',
        'subtitle': 'Want to improve learning methods',
        'icon': Icons.lightbulb_outline,
      },
      {
        'value': 'other',
        'title': 'Other',
        'subtitle': 'Have a different reason',
        'icon': Icons.more_horiz,
      },
    ];
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
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textDark),
          ),
        ),
      ],
    );
  }

  Future<void> _submitRequest() async {
    // Validate required fields before submission
    if (_selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least one subject',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_educationLevel == null || _educationLevel!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select an education level',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      // Navigate back to step 1
      safeSetState(() => _currentStep = 0);
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (_teachingMode == null || _teachingMode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a teaching mode',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      // Navigate back to step 2
      safeSetState(() => _currentStep = 1);
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (_preferredDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least one preferred day',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      // Navigate back to step 3
      safeSetState(() => _currentStep = 2);
      _pageController.animateToPage(
        2,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (_preferredTime == null || _preferredTime!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a preferred time',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      // Navigate back to step 3
      safeSetState(() => _currentStep = 2);
      _pageController.animateToPage(
        2,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a location',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      // Navigate back to step 3
      safeSetState(() => _currentStep = 2);
      _pageController.animateToPage(
        2,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

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
        specificRequirements: _selectedRequirements.isNotEmpty
            ? _selectedRequirements
                  .map((r) {
                    final options = _getRequirementOptions();
                    final option = options.firstWhere(
                      (o) => o['value'] == r,
                      orElse: () => {'label': r, 'value': r},
                    );
                    return option['label'] as String;
                  })
                  .join(', ')
            : '',
        teachingMode: _teachingMode!,
        budgetMin: _minBudget,
        budgetMax: _maxBudget,
        tutorGender: _tutorGender,
        tutorQualification: _tutorQualification,
        preferredDays: _preferredDays,
        preferredTime: _preferredTime!,
        location: _locationController.text.trim(),
        locationDescription: null,  // Column doesn't exist in DB, storing in additional_notes instead
        urgency: _urgency,
        additionalNotes: () {
          String notes = '';
          if (_requestReason == 'other') {
            notes = _customReasonController.text.trim();
          } else if (_requestReason != null) {
            final reasonOption = _getRequestReasonOptions().firstWhere(
              (r) => r['value'] == _requestReason,
              orElse: () => {'title': _requestReason ?? 'Other', 'value': _requestReason},
            );
            notes = reasonOption['title'] as String;
          }
          // Append location description if provided (for hybrid/onsite)
          if (_locationDescriptionController.text.trim().isNotEmpty) {
            if (notes.isNotEmpty) notes += '\n\n';
            notes += 'Location Description: ' + _locationDescriptionController.text.trim();
          }
          return notes.isEmpty ? null : notes;
        }(),
      );

      // Send WhatsApp notification to PrepSkul team
      await _sendWhatsAppNotification(requestId);

      // Close loading
      if (mounted) Navigator.pop(context);

      // Show success
      _showSuccessDialog();
    } catch (e) {
      LogService.error('Error submitting request: $e');
      LogService.error('Error details: ${e.toString()}');
      LogService.error('Stack trace: ${StackTrace.current}');

      // Close loading
      if (mounted) Navigator.pop(context);

      // Show error with more details
      if (mounted) {
        final errorMessage = e.toString().contains('not authenticated')
            ? 'You are not logged in. Please log in and try again.'
            : e.toString().contains('network') ||
                  e.toString().contains('connection')
            ? 'Network error. Please check your connection and try again.'
            : 'Failed to submit request: ${e.toString().length > 100 ? e.toString().substring(0, 100) + "..." : e.toString()}';

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[300], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              errorMessage,
              style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
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
    final userId = userProfile?['id'] ?? userProfile?['userId'] ?? 'Unknown';
    final userName = userProfile?['full_name'] ?? 'User';
    final userPhone = userProfile?['phone_number'] ?? 'Not provided';
    
    // Get user type for personalized message
    final userType = userProfile?['user_type']?.toString() ?? 'user';
    final isParent = userType == 'parent';
    
    // Get survey data for additional context
    Map<String, dynamic>? surveyData;
    String? childName;
    String? city;
    String? quarter;
    String? learningPath;
    String? classLevel;
    String? stream;
    List<String>? surveySubjects;
    List<String>? learningGoals;
    List<String>? challenges;
    
    try {
      if (isParent) {
        surveyData = await SurveyRepository.getParentSurvey(userId);
        childName = surveyData?['child_name'] as String?;
        city = surveyData?['city'] as String?;
        quarter = surveyData?['quarter'] as String?;
        learningPath = surveyData?['learning_path'] as String?;
        classLevel = surveyData?['class'] as String?;
        stream = surveyData?['stream'] as String?;
        surveySubjects = (surveyData?['subjects'] as List?)?.cast<String>();
        learningGoals = (surveyData?['learning_goals'] as List?)?.cast<String>();
        challenges = (surveyData?['challenges'] as List?)?.cast<String>();
      } else {
        surveyData = await SurveyRepository.getStudentSurvey(userId);
        city = surveyData?['city'] as String?;
        quarter = surveyData?['quarter'] as String?;
        learningPath = surveyData?['learning_path'] as String?;
        classLevel = surveyData?['class'] as String?;
        stream = surveyData?['stream'] as String?;
        surveySubjects = (surveyData?['subjects'] as List?)?.cast<String>();
        learningGoals = (surveyData?['learning_goals'] as List?)?.cast<String>();
        challenges = (surveyData?['challenges'] as List?)?.cast<String>();
      }
    } catch (e) {
      LogService.debug('Could not load survey data for WhatsApp message: $e');
    }
    
    // Build personalized greeting
    String greeting;
    if (isParent && childName != null && childName.isNotEmpty) {
      greeting = 'Hello PrepSkul,\n\nI am looking for a tutor for my child, $childName.';
    } else if (isParent) {
      greeting = 'Hello PrepSkul,\n\nI am looking for a tutor for my child.';
    } else {
      greeting = 'Hello PrepSkul,\n\nI am looking for a personal tutor.';
    }
    
    // Build message sections
    final buffer = StringBuffer();
    buffer.writeln(greeting);
    buffer.writeln();
    buffer.writeln('Here are the details:');
    buffer.writeln();
    
    // Personal Information
    buffer.writeln('👤 *About Me:*');
    if (isParent && childName != null && childName.isNotEmpty) {
      buffer.writeln('• My name: $userName');
      buffer.writeln('• My child\'s name: $childName');
    } else {
      buffer.writeln('• My name: $userName');
    }
    buffer.writeln('• Phone: $userPhone');
    buffer.writeln('• My User ID: $userId');
    buffer.writeln();
    
    // Location (from survey if available)
    if (city != null || quarter != null || _locationController.text.isNotEmpty) {
      buffer.writeln('📍 *Location:*');
      if (city != null) buffer.writeln('• City: $city');
      if (quarter != null) buffer.writeln('• Quarter: $quarter');
      if (_locationController.text.isNotEmpty && _locationController.text != city && _locationController.text != quarter) {
        buffer.writeln('• Preferred location: ${_locationController.text}');
      }
      buffer.writeln();
    }
    
    // Learning Details
    buffer.writeln('📚 *Learning Details:*');
    if (learningPath != null) {
      buffer.writeln('• Learning path: $learningPath');
    }
    if (_educationLevel != null) {
      buffer.writeln('• Education level: $_educationLevel');
    }
    if (classLevel != null) {
      buffer.writeln('• Class: $classLevel');
    }
    if (stream != null) {
      buffer.writeln('• Stream: $stream');
    }
    if (_selectedSubjects.isNotEmpty) {
      buffer.writeln('• Subjects needed: ${_selectedSubjects.join(', ')}');
    } else if (surveySubjects != null && surveySubjects.isNotEmpty) {
      buffer.writeln('• Subjects: ${surveySubjects.join(', ')}');
    }
    if (_selectedRequirements.isNotEmpty) {
      final requirements = _selectedRequirements.map((r) {
        final options = _getRequirementOptions();
        final option = options.firstWhere(
          (o) => o['value'] == r,
          orElse: () => {'label': r, 'value': r},
        );
        return option['label'] as String;
      }).join(', ');
      buffer.writeln('• Specific requirements: $requirements');
    }
    buffer.writeln();
    
    // Learning Goals & Challenges (from survey)
    if (learningGoals != null && learningGoals.isNotEmpty) {
      buffer.writeln('🎯 *Learning Goals:*');
      for (final goal in learningGoals) {
        buffer.writeln('• $goal');
      }
      buffer.writeln();
    }
    
    if (challenges != null && challenges.isNotEmpty) {
      buffer.writeln('⚠️ *Challenges:*');
      for (final challenge in challenges) {
        buffer.writeln('• $challenge');
      }
      buffer.writeln();
    }
    
    // Tutor Preferences
    buffer.writeln('👨‍🏫 *Tutor Preferences:*');
    if (_teachingMode != null) {
      final teachingMode = _teachingMode!;
      buffer.writeln('• Teaching mode: ${teachingMode.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')}');
    }
    buffer.writeln('• Budget: ${_minBudget.toStringAsFixed(0)} - ${_maxBudget.toStringAsFixed(0)} XAF per month');
    if (_tutorGender != null) {
      buffer.writeln('• Preferred gender: $_tutorGender');
    }
    if (_tutorQualification != null) {
      buffer.writeln('• Preferred qualification: $_tutorQualification');
    }
    buffer.writeln();
    
    // Schedule
    buffer.writeln('📅 *Schedule:*');
    if (_preferredDays.isNotEmpty) {
      buffer.writeln('• Preferred days: ${_preferredDays.join(', ')}');
    }
    if (_preferredTime != null) {
      buffer.writeln('• Preferred time: $_preferredTime');
    }
    buffer.writeln();
    
    // Urgency
    if (_urgency != 'normal') {
      buffer.writeln('⚡ *Urgency:*');
      buffer.writeln('• ${_urgency.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')}');
      buffer.writeln();
    }
    
    // Additional Notes
    if (_requestReason != null) {
      buffer.writeln('💬 *Additional Information:*');
      final reason = _requestReason == 'other' 
          ? (_customReasonController.text.trim().isNotEmpty ? _customReasonController.text.trim() : 'Other')
          : _getRequestReasonOptions().firstWhere(
              (r) => r['value'] == _requestReason,
              orElse: () => {'title': _requestReason ?? 'Other', 'value': _requestReason},
            )['title'];
      buffer.writeln('• $reason');
      buffer.writeln();
    }
    
    // Request ID
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Request ID: $requestId');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();
    buffer.writeln('I would appreciate your help in finding a suitable tutor. Thank you! 🙏');
    
    final message = buffer.toString();

    final whatsappUrl = Uri.parse(
      'https://wa.me/237653301997?text=${Uri.encodeComponent(message)}',
    );

          // Show dialog to ask if user wants to send WhatsApp message
      if (mounted) {
        final shouldSend = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              AppLocalizations.of(context)!.requestTutorSendWhatsApp,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              AppLocalizations.of(context)!.requestTutorWhatsAppPrompt,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  AppLocalizations.of(context)!.requestTutorSkip,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: Text(
                  AppLocalizations.of(context)!.requestTutorSend,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ) ?? false;
        
        if (shouldSend) {
          try {
            if (await canLaunchUrl(whatsappUrl)) {
              await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not open WhatsApp'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } catch (e) {
            LogService.debug('Could not launch WhatsApp: \$e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not open WhatsApp'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
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
                  Navigator.pop(context); // Close request flow screen
                  // User stays in the app - they can navigate to requests themselves
                  // The request will appear in their requests section
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.requestTutorDone,
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
