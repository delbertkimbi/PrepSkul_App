// Full child profile screen with multi-step flow (same as ParentSurvey but child-focused)
// Collects all child-specific information for accurate tutor matching

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/parent_learners_service.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/data/app_data.dart';
import 'package:prepskul/data/survey_config.dart';
import 'dart:convert';

class SurveyStep {
  final String title;
  final String subtitle;

  const SurveyStep({
    required this.title,
    required this.subtitle,
  });
}

class AddChildProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? existingChild;
  final String parentId;

  const AddChildProfileScreen({
    Key? key,
    this.existingChild,
    required this.parentId,
  }) : super(key: key);

  @override
  State<AddChildProfileScreen> createState() => _AddChildProfileScreenState();
}

class _AddChildProfileScreenState extends State<AddChildProfileScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Child Information
  String? _childName;
  DateTime? _childDateOfBirth;
  String? _childGender;
  String? _relationshipToChild;

  // Date of Birth fields
  String? _selectedDay;
  String? _selectedMonth;
  final TextEditingController _yearController = TextEditingController();

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
  String? _tutorGenderPreference;
  String? _tutorQualificationPreference;
  String? _preferredLocation;
  String? _preferredSchedule;
  String? _childConfidenceLevel;
  List<String> _learningGoals = [];
  List<String> _challenges = [];

  List<SurveyStep> _steps = [];

  @override
  void initState() {
    super.initState();
    _loadExistingChild();
    _initializeSteps();
    // If editing existing child, update steps to show all relevant steps based on loaded data
    if (widget.existingChild != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateSteps();
      });
    }
  }

  @override
  void dispose() {
    _universityCoursesController.dispose();
    _yearController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _loadExistingChild() {
    if (widget.existingChild != null) {
      final child = widget.existingChild!;
      _childName = child['name'] as String?;
      if (child['date_of_birth'] != null) {
        _childDateOfBirth = DateTime.parse(child['date_of_birth'] as String);
        _selectedDay = _childDateOfBirth!.day.toString().padLeft(2, '0');
        _selectedMonth = _childDateOfBirth!.month.toString().padLeft(2, '0');
        _yearController.text = _childDateOfBirth!.year.toString();
      }
      _childGender = child['gender'] as String?;
      _relationshipToChild = child['relationship_to_child'] as String?;
      _selectedLearningPath = child['learning_path'] as String?;
      _selectedEducationLevel = child['education_level'] as String?;
      _selectedClass = child['class_level'] as String?;
      _selectedStream = child['stream'] as String?;
      if (child['subjects'] != null) {
        _selectedSubjects = List<String>.from(child['subjects'] as List);
      }
      _universityCoursesController.text = child['university_courses'] as String? ?? '';
      _selectedSkillCategory = child['skill_category'] as String?;
      if (child['skills'] != null) {
        _selectedSkills = List<String>.from(child['skills'] as List);
      }
      _selectedExamType = child['exam_type'] as String?;
      _selectedSpecificExam = child['specific_exam'] as String?;
      if (child['exam_subjects'] != null) {
        _examSubjects = List<String>.from(child['exam_subjects'] as List);
      }
      _tutorGenderPreference = child['tutor_gender_preference'] as String?;
      _tutorQualificationPreference = child['tutor_qualification_preference'] as String?;
      _preferredLocation = child['preferred_location'] as String?;
      if (child['preferred_schedule'] != null) {
        final schedule = child['preferred_schedule'] as List;
        _preferredSchedule = schedule.isNotEmpty ? schedule[0] as String : null;
      }
      _childConfidenceLevel = child['confidence_level'] as String?;
      if (child['learning_goals'] != null) {
        _learningGoals = List<String>.from(child['learning_goals'] as List);
      }
      if (child['challenges'] != null) {
        _challenges = List<String>.from(child['challenges'] as List);
      }
    }
  }

  void _initializeSteps() {
    _steps = [
      const SurveyStep(
        title: 'Tell us about your child',
        subtitle: 'Basic child information',
      ),
      const SurveyStep(
        title: 'What does your child want to learn?',
        subtitle: 'Choose the learning path',
      ),
    ];
  }

  void _updateSteps() {
    setState(() {
      _steps = [
        const SurveyStep(
          title: 'Tell us about your child',
          subtitle: 'Basic child information',
        ),
        const SurveyStep(
          title: 'What does your child want to learn?',
          subtitle: 'Choose the learning path',
        ),
      ];

      // Add dynamic steps based on learning path
      if (_selectedLearningPath != null) {
        _addDynamicSteps();
      }

      // Add preferences and review (no location/budget - those are parent-level)
      _steps.addAll([
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
          title: 'Confidence Level',
          subtitle: 'How confident is your child in this subject/skill?',
        ),
        const SurveyStep(
          title: 'Learning Goals',
          subtitle: 'What does your child need help with?',
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

    if (_selectedLearningPath == 'Academic Tutoring') {
      _steps.add(const SurveyStep(
        title: 'What\'s your child\'s education level?',
        subtitle: 'Select the education level',
      ));
      if (_selectedEducationLevel != null) {
        final config = SurveyConfig.educationLevels[_selectedEducationLevel];
        if (config != null && config.classes.isNotEmpty) {
          _steps.add(const SurveyStep(
            title: 'What class is your child in?',
            subtitle: 'Select the class',
          ));
        }
        if (_selectedEducationLevel == 'High School' && _selectedClass != null) {
          _steps.add(const SurveyStep(
            title: 'What\'s your child\'s stream?',
            subtitle: 'Select the stream',
          ));
        }
        if (_selectedStream != null || _selectedEducationLevel != 'High School') {
          _steps.add(const SurveyStep(
            title: 'Which subjects does your child need help with?',
            subtitle: 'Select all that apply',
          ));
        }
      }
    } else if (_selectedLearningPath == 'Skill Development') {
      _steps.add(const SurveyStep(
        title: 'What type of skills is your child interested in?',
        subtitle: 'Select a category',
      ));
      if (_selectedSkillCategory != null) {
        _steps.add(const SurveyStep(
          title: 'Which specific skills?',
          subtitle: 'Select all that apply',
        ));
      }
    } else if (_selectedLearningPath == 'Exam Preparation') {
      _steps.add(const SurveyStep(
        title: 'Which type of exam is your child preparing for?',
        subtitle: 'Select the exam type',
      ));
      if (_selectedExamType != null) {
        _steps.add(const SurveyStep(
          title: 'Which specific exam?',
          subtitle: 'Select the specific exam',
        ));
      }
      if (_selectedSpecificExam != null) {
        _steps.add(const SurveyStep(
          title: 'Which subjects for this exam?',
          subtitle: 'Select all that apply',
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 0) {
          _previousStep();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
            onPressed: () {
              if (_currentStep > 0) {
                _previousStep();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            widget.existingChild != null ? 'Edit Child Profile' : 'Add Child Profile',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Column(
              children: [
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentStep + 1) / _steps.length,
                  backgroundColor: AppTheme.neutral200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                  minHeight: 4,
                ),
                const SizedBox(height: 1),
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
                  setState(() {
                    _currentStep = index;
                  });
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
              fontSize: 14,
              color: AppTheme.textMedium,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 24),

          // Content based on step
          Expanded(
            child: SingleChildScrollView(child: _buildStepContent(stepIndex)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(int stepIndex) {
    final step = _steps[stepIndex];

    if (step.title == 'Tell us about your child') {
      return _buildChildInfo();
    } else if (step.title == 'What does your child want to learn?') {
      return _buildLearningPathSelection();
    } else if (step.title == 'What\'s your child\'s education level?' ||
        step.title == 'Education Level') {
      return _buildEducationLevelSelection();
    } else if (step.title.contains('is your child in?') ||
        step.title == 'Class Selection') {
      return _buildClassSelection();
    } else if (step.title == 'What\'s your child\'s stream?' ||
        step.title == 'Stream Selection') {
      return _buildStreamSelection();
    } else if (step.title == 'Which subjects does your child need help with?' ||
        step.title == 'Subjects of Interest') {
      return _buildSubjectSelection();
    } else if (step.title ==
            'What type of skills is your child interested in?' ||
        step.title == 'Skill Category') {
      return _buildSkillCategorySelection();
    } else if (step.title == 'Which specific skills?' ||
        step.title == 'Specific Skills') {
      return _buildSpecificSkillsSelection();
    } else if (step.title ==
            'Which type of exam is your child preparing for?' ||
        step.title == 'Which type of exam are you preparing for?') {
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
    } else if (step.title == 'Confidence Level') {
      return _buildConfidenceLevel();
    } else if (step.title == 'Learning Goals') {
      return _buildLearningGoals();
    } else if (step.title == 'Review & Confirm') {
      return _buildReview();
    }

    return const SizedBox();
  }

  Widget _buildChildInfo() {
    return Column(
      children: [
        _buildInputField(
          label: 'Child\'s Name',
          hint: 'Enter your child\'s full name',
          value: _childName,
          onChanged: (value) => setState(() => _childName = value),
          isRequired: true,
        ),
        const SizedBox(height: 20),
        _buildDateField(),
        const SizedBox(height: 20),
        _buildDropdownField(
          label: 'Gender',
          value: _childGender,
          items: ['Male', 'Female', 'Other'],
          onChanged: (value) => setState(() => _childGender = value),
          isRequired: true,
        ),
        const SizedBox(height: 20),
        _buildDropdownField(
          label: 'Your Relationship to Child',
          value: _relationshipToChild,
          items: ['Parent', 'Guardian', 'Family Member', 'Other'],
          onChanged: (value) => setState(() => _relationshipToChild = value),
          isRequired: true,
        ),
      ],
    );
  }

  void _updateDateOfBirth() {
    if (_selectedDay != null &&
        _selectedMonth != null &&
        _yearController.text.isNotEmpty) {
      try {
        final day = int.parse(_selectedDay!);
        final month = int.parse(_selectedMonth!);
        final year = int.parse(_yearController.text);

        final currentYear = DateTime.now().year;
        if (year < 1930 || year > currentYear) {
          _childDateOfBirth = null;
          return;
        }

        final daysInMonth = DateTime(year, month + 1, 0).day;
        if (day < 1 || day > daysInMonth) {
          _childDateOfBirth = null;
          return;
        }

        final selectedDate = DateTime(year, month, day);
        if (selectedDate.isAfter(DateTime.now())) {
          _childDateOfBirth = null;
          return;
        }

        setState(() {
          _childDateOfBirth = selectedDate;
        });
      } catch (e) {
        LogService.warning('Error parsing date: $e');
        _childDateOfBirth = null;
      }
    } else {
      _childDateOfBirth = null;
    }
  }

  List<String> _getDaysForMonth() {
    if (_selectedMonth == null || _yearController.text.isEmpty) {
      return List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'));
    }

    try {
      final month = int.parse(_selectedMonth!);
      final year = int.parse(_yearController.text);
      final daysInMonth = DateTime(year, month + 1, 0).day;
      return List.generate(
        daysInMonth,
        (i) => (i + 1).toString().padLeft(2, '0'),
      );
    } catch (e) {
      return List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'));
    }
  }

  String? _getValidDayValue() {
    if (_selectedDay == null) {
      return null;
    }

    final availableDays = _getDaysForMonth();
    if (availableDays.contains(_selectedDay)) {
      return _selectedDay;
    }

    if (availableDays.isNotEmpty) {
      return availableDays.last;
    }

    return null;
  }

  Widget _buildDateField() {
    int? age;
    String? ageText;
    if (_childDateOfBirth != null) {
      final today = DateTime.now();
      age = today.year - _childDateOfBirth!.year;
      if (today.month < _childDateOfBirth!.month ||
          (today.month == _childDateOfBirth!.month &&
              today.day < _childDateOfBirth!.day)) {
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
              'Child\'s Date of Birth',
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  setState(() {
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
                  setState(() {
                    _selectedMonth = value;
                    if (_selectedDay != null) {
                      final availableDays = _getDaysForMonth();
                      if (!availableDays.contains(_selectedDay)) {
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
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                onChanged: (value) {
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
                  setState(() {
                    if (_selectedDay != null) {
                      final availableDays = _getDaysForMonth();
                      if (!availableDays.contains(_selectedDay)) {
                        _selectedDay = availableDays.isNotEmpty
                            ? availableDays.last
                            : null;
                      }
                    }
                  });
                  _updateDateOfBirth();
                },
              ),
            ),
          ],
        ),
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

  Widget _buildInputField({
    required String label,
    required String hint,
    String? value,
    required ValueChanged<String> onChanged,
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
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textDark,
          ),
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

  Widget _buildLearningPathSelection() {
    final programs = SurveyConfig.getProgramsForUserType('parent');
    return Column(
      children: programs.map((program) {
        final config = SurveyConfig.getProgramConfig(program);
        final isSelected = _selectedLearningPath == program;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            title: program,
            subtitle: config?.description,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedLearningPath = program;
                _resetDynamicFields();
                _updateSteps();
              });
            },
          ),
        );
      }).toList(),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.softCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.softBorder,
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
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textLight,
                  width: 2,
                ),
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
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
          ],
        ),
      ),
    );
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

  Widget _buildEducationLevelSelection() {
    return Column(
      children: SurveyConfig.educationLevels.keys.map((level) {
        final isSelected = _selectedEducationLevel == level;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            title: level,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedEducationLevel = level;
                _selectedClass = null;
                _selectedStream = null;
                _selectedSubjects = [];
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
    final config = SurveyConfig.educationLevels[_selectedEducationLevel];
    if (config == null || config.classes.isEmpty) return const SizedBox();

    return Column(
      children: config.classes.map((classLevel) {
        final isSelected = _selectedClass == classLevel;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            title: classLevel,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedClass = classLevel;
                if (_selectedEducationLevel != 'High School') {
                  _selectedStream = null;
                }
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
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            title: stream,
            subtitle: SurveyConfig.getStreamDescription(stream),
            isSelected: isSelected,
            onTap: () {
              setState(() {
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
              padding: const EdgeInsets.all(16),
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
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'University Courses',
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
                setState(() {
                  // Split by newline and filter empty lines
                  _selectedSubjects = value
                      .split('\n')
                      .where((line) => line.trim().isNotEmpty)
                      .toList();
                });
              },
              decoration: InputDecoration(
                hintText:
                    'Type courses here...\n\nIntroduction to Psychology\nLinear Algebra\nBusiness Statistics',
                hintStyle: GoogleFonts.poppins(
                  color: AppTheme.textLight,
                  fontSize: 14,
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
                fontSize: 14,
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
                    const SizedBox(width: 8),
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
    final subjects = SurveyConfig.getSubjectsForEducationLevel(
      _selectedEducationLevel!,
      _selectedStream,
    );

    return Column(
      children: subjects.map((subject) {
        final isSelected = _selectedSubjects.contains(subject);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            title: subject,
            isSelected: isSelected,
            onTap: () {
              setState(() {
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
            fontSize: 14,
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
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: AppTheme.primaryColor,
                          size: 14,
                        ),
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

  Widget _buildSkillCategorySelection() {
    return Column(
      children: SurveyConfig.skillAreas.keys.map((category) {
        final isSelected = _selectedSkillCategory == category;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            title: category,
            isSelected: isSelected,
            onTap: () {
              setState(() {
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
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            title: skill,
            isSelected: isSelected,
            onTap: () {
              setState(() {
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
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            title: type,
            subtitle: config?.description,
            isSelected: isSelected,
            onTap: () {
              setState(() {
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
    if (exams.isEmpty) return const SizedBox();

    return Column(
      children: exams.map((exam) {
        final isSelected = _selectedSpecificExam == exam;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            title: exam,
            isSelected: isSelected,
            onTap: () {
              setState(() {
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
    if (subjects.isEmpty) return const SizedBox();

    return _buildMultiSelectField(
      title: 'Which subjects for this exam?',
      options: subjects,
      selectedValues: _examSubjects,
      onSelectionChanged: (values) => setState(() => _examSubjects = values),
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

    // Title and subtitle are already shown in _buildStep
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...qualifications.map((qual) {
          bool isSelected = _tutorQualificationPreference == qual['value'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () =>
                  setState(() => _tutorQualificationPreference = qual['value']),
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
                      width: 18,
                      height: 18,
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
                              size: 12,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
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
                          const SizedBox(height: 2),
                          Text(
                            qual['description'] as String,
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
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTutorGenderPreference() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.start,
          children: SurveyConfig.tutorGenderPreferences.map((option) {
            bool isSelected = _tutorGenderPreference == option;
            return GestureDetector(
              onTap: () => setState(() => _tutorGenderPreference = option),
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

  Widget _buildLearningLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.start,
          children: SurveyConfig.learningModes.map((option) {
            bool isSelected = _preferredLocation == option;
            return GestureDetector(
              onTap: () => setState(() => _preferredLocation = option),
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

  Widget _buildSchedulePreference() {
    return Column(
      children: SurveyConfig.schedulePreferences.map((schedule) {
        final isSelected = _preferredSchedule == schedule;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            title: schedule,
            isSelected: isSelected,
            onTap: () => setState(() => _preferredSchedule = schedule),
          ),
        );
      }).toList(),
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

    // Title and subtitle are already shown in _buildStep, so we don't need to repeat them here
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...confidenceLevels.map((level) {
          bool isSelected = _childConfidenceLevel == level['value'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () =>
                  setState(() => _childConfidenceLevel = level['value']),
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
                      width: 18,
                      height: 18,
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
                              size: 12,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
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
                          const SizedBox(height: 2),
                          Text(
                            level['description'] as String,
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
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLearningGoals() {
    return Column(
      children: [
        _buildMultiSelectField(
          title: 'What are your child\'s main learning goals?',
          options: SurveyConfig.learningGoals,
          selectedValues: _learningGoals,
          onSelectionChanged: (values) =>
              setState(() => _learningGoals = values),
        ),
        const SizedBox(height: 24),
        _buildMultiSelectField(
          title: 'What are your child\'s biggest learning challenges?',
          options: SurveyConfig.learningChallenges,
          selectedValues: _challenges,
          onSelectionChanged: (values) => setState(() => _challenges = values),
        ),
      ],
    );
  }

  Widget _buildReview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReviewCard(
            title: 'Child Information',
            icon: Icons.child_care_outlined,
            children: [
              _buildReviewItem('Child\'s Name', _childName),
              if (_childDateOfBirth != null)
                _buildReviewItem(
                  'Date of Birth',
                  '${_childDateOfBirth!.day}/${_childDateOfBirth!.month}/${_childDateOfBirth!.year}',
                ),
              _buildReviewItem('Gender', _childGender),
              _buildReviewItem('Relationship', _relationshipToChild),
            ],
          ),
          const SizedBox(height: 16),
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
              if (_universityCoursesController.text.isNotEmpty)
                _buildReviewItem('University Courses', _universityCoursesController.text),
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
          _buildReviewCard(
            title: 'Preferences',
            icon: Icons.tune_outlined,
            children: [
              _buildReviewItem(
                'Tutor Gender Preference',
                _tutorGenderPreference,
              ),
              _buildReviewItem('Preferred Location', _preferredLocation),
              _buildReviewItem('Preferred Schedule', _preferredSchedule),
              _buildReviewItem('Confidence Level', _childConfidenceLevel),
              _buildReviewItem(
                'Tutor Qualification',
                _tutorQualificationPreference,
              ),
            ],
          ),
          const SizedBox(height: 16),
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
        borderRadius: BorderRadius.circular(16),
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
                    fontSize: 16,
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
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textDark,
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
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.softBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: _currentStep == 0 ? 1 : 1,
              child: ElevatedButton(
                onPressed: _canProceed() ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor: AppTheme.softBorder,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentStep == _steps.length - 1 ? 'Save' : 'Next',
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

  bool _canProceed() {
    final step = _steps[_currentStep];

    if (step.title == 'Tell us about your child') {
      return _childName != null &&
          _childName!.isNotEmpty &&
          _childDateOfBirth != null &&
          _childGender != null &&
          _relationshipToChild != null;
    } else if (step.title == 'What does your child want to learn?') {
      return _selectedLearningPath != null;
    } else if (step.title == 'What\'s your child\'s education level?' ||
        step.title == 'Education Level') {
      return _selectedEducationLevel != null;
    } else if (step.title.contains('is your child in?') ||
        step.title == 'Class Selection') {
      return _selectedClass != null;
    } else if (step.title == 'What\'s your child\'s stream?' ||
        step.title == 'Stream Selection') {
      return _selectedStream != null;
    } else if (step.title == 'Which subjects does your child need help with?' ||
        step.title == 'Subjects of Interest') {
      return _selectedSubjects.isNotEmpty || _universityCoursesController.text.isNotEmpty;
    } else if (step.title ==
            'What type of skills is your child interested in?' ||
        step.title == 'Skill Category') {
      return _selectedSkillCategory != null;
    } else if (step.title == 'Which specific skills?' ||
        step.title == 'Specific Skills') {
      return _selectedSkills.isNotEmpty;
    } else if (step.title ==
            'Which type of exam is your child preparing for?' ||
        step.title == 'Which type of exam are you preparing for?') {
      return _selectedExamType != null;
    } else if (step.title == 'Which specific exam?') {
      return _selectedSpecificExam != null;
    } else if (step.title == 'Which subjects for this exam?') {
      return _examSubjects.isNotEmpty;
    } else if (step.title == 'Tutor Qualification') {
      return _tutorQualificationPreference != null;
    } else if (step.title == 'Tutor Gender') {
      return _tutorGenderPreference != null;
    } else if (step.title == 'Learning Location') {
      return _preferredLocation != null;
    } else if (step.title == 'Schedule Preference') {
      return _preferredSchedule != null;
    } else if (step.title == 'Confidence Level') {
      return _childConfidenceLevel != null;
    } else if (step.title == 'Learning Goals') {
      return _learningGoals.isNotEmpty;
    } else if (step.title == 'Review & Confirm') {
      return true;
    }

    return false;
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
      _saveChildProfile();
    }
  }

  Future<void> _saveChildProfile() async {
    try {
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
                  'Saving child profile...',
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

      // Get display order for new child
      final existingLearners = await ParentLearnersService.getLearners(widget.parentId);
      final displayOrder = existingLearners.length;

      if (widget.existingChild != null) {
        // Update existing child
        await ParentLearnersService.updateLearner(
          learnerId: widget.existingChild!['id'] as String,
          parentId: widget.parentId,
          name: _childName,
          educationLevel: _selectedEducationLevel,
          classLevel: _selectedClass,
          dateOfBirth: _childDateOfBirth,
          gender: _childGender,
          relationshipToChild: _relationshipToChild,
          learningPath: _selectedLearningPath,
          stream: _selectedStream,
          subjects: _selectedSubjects.isNotEmpty ? _selectedSubjects : null,
          universityCourses: _universityCoursesController.text.trim().isNotEmpty
              ? _universityCoursesController.text.trim()
              : null,
          skillCategory: _selectedSkillCategory,
          skills: _selectedSkills.isNotEmpty ? _selectedSkills : null,
          examType: _selectedExamType,
          specificExam: _selectedSpecificExam,
          examSubjects: _examSubjects.isNotEmpty ? _examSubjects : null,
          confidenceLevel: _childConfidenceLevel,
          learningGoals: _learningGoals.isNotEmpty ? _learningGoals : null,
          challenges: _challenges.isNotEmpty ? _challenges : null,
          tutorGenderPreference: _tutorGenderPreference,
          tutorQualificationPreference: _tutorQualificationPreference,
          preferredLocation: _preferredLocation,
          preferredSchedule: _preferredSchedule != null ? [_preferredSchedule!] : null,
        );
      } else {
        // Add new child
        await ParentLearnersService.addLearner(
          parentId: widget.parentId,
          name: _childName!,
          educationLevel: _selectedEducationLevel,
          classLevel: _selectedClass,
          displayOrder: displayOrder,
          dateOfBirth: _childDateOfBirth,
          gender: _childGender,
          relationshipToChild: _relationshipToChild,
          learningPath: _selectedLearningPath,
          stream: _selectedStream,
          subjects: _selectedSubjects.isNotEmpty ? _selectedSubjects : null,
          universityCourses: _universityCoursesController.text.trim().isNotEmpty
              ? _universityCoursesController.text.trim()
              : null,
          skillCategory: _selectedSkillCategory,
          skills: _selectedSkills.isNotEmpty ? _selectedSkills : null,
          examType: _selectedExamType,
          specificExam: _selectedSpecificExam,
          examSubjects: _examSubjects.isNotEmpty ? _examSubjects : null,
          confidenceLevel: _childConfidenceLevel,
          learningGoals: _learningGoals.isNotEmpty ? _learningGoals : null,
          challenges: _challenges.isNotEmpty ? _challenges : null,
          tutorGenderPreference: _tutorGenderPreference,
          tutorQualificationPreference: _tutorQualificationPreference,
          preferredLocation: _preferredLocation,
          preferredSchedule: _preferredSchedule != null ? [_preferredSchedule!] : null,
        );
      }

      LogService.success('Child profile saved successfully!');

      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingChild != null
                ? 'Child profile updated successfully!'
                : 'Child profile added successfully!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate back
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      LogService.error('Error saving child profile: $e');

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
            'Failed to save child profile. Please try again.\n\nError: $e',
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
