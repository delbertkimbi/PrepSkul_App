import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/survey_repository.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/data/app_data.dart';
import 'package:prepskul/data/survey_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentSurvey extends StatefulWidget {
  const StudentSurvey({Key? key}) : super(key: key);

  @override
  State<StudentSurvey> createState() => _StudentSurveyState();
}

class _StudentSurveyState extends State<StudentSurvey> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Basic Student Information
  String? _studentName;
  DateTime? _studentDateOfBirth;
  String? _studentGender;

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
  String? _learningStyle;
  String? _confidenceLevel;
  List<String> _learningGoals = [];
  List<String> _challenges = [];

  List<SurveyStep> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializeSteps();
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
    setState(() {
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
          subtitle: 'What\'s your budget per session?',
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
                          fontSize: 14,
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
                const SizedBox(height: 8),
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
                  style: GoogleFonts.poppins(color: Colors.red),
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
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            step.subtitle,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppTheme.textMedium,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 40),

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
        _buildInputField(
          label: 'Your Name',
          hint: 'Enter your full name',
          value: _studentName,
          onChanged: (value) => setState(() => _studentName = value),
          isRequired: true,
        ),
        const SizedBox(height: 20),
        _buildDateField(),
        const SizedBox(height: 20),
        _buildDropdownField(
          label: 'Gender',
          value: _studentGender,
          items: ['Male', 'Female', 'Other'],
          onChanged: (value) => setState(() => _studentGender = value),
          isRequired: true,
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Date of Birth',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate:
                  _studentDateOfBirth ??
                  DateTime.now().subtract(const Duration(days: 365 * 10)),
              firstDate: DateTime(1930, 1, 1), // Allow dates from 1930 onwards
              lastDate: DateTime.now(), // Today is the latest date
            );
            if (date != null) {
              setState(() => _studentDateOfBirth = date);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: AppTheme.softCard,
              border: Border.all(color: AppTheme.softBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: AppTheme.textMedium,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _studentDateOfBirth != null
                        ? '${_studentDateOfBirth!.day}/${_studentDateOfBirth!.month}/${_studentDateOfBirth!.year}'
                        : 'Select your date of birth',
                    style: GoogleFonts.poppins(
                      color: _studentDateOfBirth != null
                          ? AppTheme.textDark
                          : AppTheme.textLight,
                      fontSize: 14,
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

  Widget _buildLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildDropdownField(
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
        buildDropdownField(
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
            value: _customQuarter,
            onChanged: (value) => setState(() => _customQuarter = value),
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
              setState(() => _learningGoals = values),
        ),
        const SizedBox(height: 24),
        _buildMultiSelectField(
          title: 'What are your biggest learning challenges?',
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
          Text(
            'Review & Confirm',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please review all information',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 24),

          // Personal Information Card
          _buildReviewCard(
            title: 'Personal Information',
            icon: Icons.person_outline,
            children: [
              _buildReviewItem('Name', _studentName),
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
              _buildReviewItem('Learning Style', _learningStyle),
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
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
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontSize: 16,
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
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            title: cls,
            isSelected: isSelected,
            onTap: () {
              setState(() {
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
                    'Type your courses here...\n\nIntroduction to Psychology\nLinear Algebra\nBusiness Statistics',
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
    return Column(
      children: subjects.map((subject) {
        final isSelected = _examSubjects.contains(subject);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            title: subject,
            isSelected: isSelected,
            onTap: () {
              setState(() {
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
        Text(
          'What\'s your budget?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 24),

        Text(
          '$_minBudget XAF - $_maxBudget XAF',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'per month',
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 24),

        RangeSlider(
          values: RangeValues(_minBudget.toDouble(), _maxBudget.toDouble()),
          min: 20000,
          max: 55000,
          divisions: 7,
          activeColor: AppTheme.primaryColor,
          inactiveColor: AppTheme.softBorder,
          onChanged: (RangeValues values) {
            setState(() {
              _minBudget = values.start.round();
              _maxBudget = values.end.round();
            });
          },
        ),

        const SizedBox(height: 16),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: [
            _buildQuickBudgetButton('20k - 30k XAF', 20000, 30000),
            _buildQuickBudgetButton('30k - 40k XAF', 30000, 40000),
            _buildQuickBudgetButton('40k - 50k XAF', 40000, 50000),
            _buildQuickBudgetButton('50k - 55k XAF', 50000, 55000),
          ],
        ),

        const SizedBox(height: 24),

        // Information Card (moved below budget selection)
        Container(
          padding: const EdgeInsets.all(16),
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
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'About Tutoring Costs',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
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
              const SizedBox(height: 8),
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
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _showPaymentPolicy,
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'View Payment Policy',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
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
        Text(
          'Tutor Gender Preference',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Do you have a gender preference for your tutor?',
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.start,
          children: SurveyConfig.tutorGenderPreferences.map((option) {
            bool isSelected = _tutorGenderPreference == option;
            return GestureDetector(
              onTap: () => setState(() => _tutorGenderPreference = option),
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
        Text(
          'Tutor Qualification Preference',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'What level of tutor qualification would you prefer?',
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 24),
        ...qualifications.map((qual) {
          bool isSelected = _tutorQualificationPreference == qual['value'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () =>
                  setState(() => _tutorQualificationPreference = qual['value']),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.softBorder,
                    width: isSelected ? 2 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            blurRadius: 8,
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
                              fontSize: 15,
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
        Text(
          'Confidence Level',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'How confident are you in this subject/skill?',
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 24),
        ...confidenceLevels.map((level) {
          bool isSelected = _confidenceLevel == level['value'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => setState(() => _confidenceLevel = level['value']),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.softBorder,
                    width: isSelected ? 2 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            blurRadius: 8,
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
                              fontSize: 15,
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
        Text(
          'Learning Location',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Where would you prefer to have your sessions?',
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.start,
          children: SurveyConfig.learningModes.map((option) {
            bool isSelected = _preferredLocation == option;
            return GestureDetector(
              onTap: () => setState(() => _preferredLocation = option),
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

  Widget _buildSchedulePreference() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schedule Preference',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'When do you prefer to have your learning sessions?',
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.start,
          children: SurveyConfig.schedulePreferences.map((option) {
            bool isSelected = _preferredSchedule == option;
            return GestureDetector(
              onTap: () => setState(() => _preferredSchedule = option),
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

  Widget _buildLearningStyle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learning Style',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'How do you learn best?',
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.start,
          children: SurveyConfig.learningStyles.map((option) {
            bool isSelected = _learningStyle == option;
            return GestureDetector(
              onTap: () => setState(() => _learningStyle = option),
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

  Widget _buildQuickBudgetButton(String label, int min, int max) {
    bool isSelected = _minBudget == min && _maxBudget == max;

    return GestureDetector(
      onTap: () {
        setState(() {
          _minBudget = min;
          _maxBudget = max;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.softCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.softBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textDark,
          ),
        ),
      ),
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
        const SizedBox(height: 8),
        TextField(
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.softBorder,
            width: isSelected ? 2 : 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
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
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
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
                        fontSize: 14,
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
                    fontSize: 16,
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
      return _studentName != null &&
          _studentName!.isNotEmpty &&
          _studentDateOfBirth != null &&
          _studentGender != null;
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
      return true; // Budget range always has a default value
    } else if (step.title == 'Tutor Qualification') {
      return _tutorQualificationPreference != null;
    } else if (step.title == 'Tutor Gender') {
      return _tutorGenderPreference != null;
    } else if (step.title == 'Learning Location') {
      return _preferredLocation != null;
    } else if (step.title == 'Schedule Preference') {
      return _preferredSchedule != null;
    } else if (step.title == 'Learning Style') {
      return _learningStyle != null;
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.policy_outlined,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Payment Policy Agreement',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: AppTheme.textMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPolicyPoint(
                          'All payments for tutoring sessions are made through PrepSkul.',
                        ),
                        _buildPolicyPoint(
                          'Sessions are paid for before the start of the learning period.',
                        ),
                        _buildPolicyPoint(
                          'If a session needs to be rescheduled, please notify PrepSkul at least 6 hours in advance.',
                        ),
                        _buildPolicyPoint(
                          'If a session is cancelled late or missed without notice, that session may still be charged.',
                        ),
                        _buildPolicyPoint(
                          'If you have concerns or are not satisfied with a session, you may report it to PrepSkul within 24 hours.',
                        ),
                        _buildPolicyPoint(
                          'PrepSkul handles tutor payments only after session confirmation, ensuring your learning experience is protected and monitored.',
                        ),
                        _buildPolicyPoint(
                          'No direct payments should be made to tutors outside the platform.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Got it',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPolicyPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeSurvey() async {
    try {
      print('📝 Student Survey submission started...');

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
                    fontSize: 14,
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
          'subjects': _selectedSubjects,
          'university_courses': _universityCoursesController.text,
        },
        // Skill Development
        if (_selectedLearningPath == 'Skill Development') ...{
          'skill_category': _selectedSkillCategory,
          'skills': _selectedSkills,
        },
        // Exam Preparation
        if (_selectedLearningPath == 'Exam Preparation') ...{
          'exam_type': _selectedExamType,
          'specific_exam': _selectedSpecificExam,
          'exam_subjects': _examSubjects,
        },
        // Preferences
        'budget_min': _minBudget,
        'budget_max': _maxBudget,
        'tutor_gender_preference': _tutorGenderPreference,
        'tutor_qualification_preference': _tutorQualificationPreference,
        'preferred_location': _preferredLocation,
        'preferred_schedule': _preferredSchedule,
        'learning_style': _learningStyle,
        'confidence_level': _confidenceLevel,
        'learning_goals': _learningGoals,
        'challenges': _challenges,
      };

      // Save to database
      await SurveyRepository.saveStudentSurvey(userId, surveyData);

      // Mark survey as completed locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('survey_completed', true);

      print('✅ Student survey saved successfully!');

      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      // Navigate to student dashboard
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/student-nav');
    } catch (e) {
      print('❌ Error saving student survey: $e');

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

class SurveyStep {
  final String title;
  final String subtitle;

  const SurveyStep({required this.title, required this.subtitle});
}
