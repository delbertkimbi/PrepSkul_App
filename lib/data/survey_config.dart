import 'app_data.dart';

/// Centralized configuration for all survey flows
/// This ensures consistency across tutors, students, and parents
class SurveyConfig {
  // User types and their available programs
  static const Map<String, List<String>> userTypePrograms = {
    'tutor': ['Academic Tutoring', 'Skill Development', 'Exam Preparation'],
    'student': ['Academic Tutoring', 'Skill Development', 'Exam Preparation'],
    'parent': ['Academic Tutoring', 'Skill Development', 'Exam Preparation'],
  };

  // Program-specific configurations
  static const Map<String, ProgramConfig> programConfigs = {
    'Academic Tutoring': ProgramConfig(
      name: 'Academic Tutoring',
      description: 'Get help with school subjects',
      icon: '📚',
      steps: [
        'education_level',
        'class_selection',
        'stream_selection',
        'subjects_selection',
      ],
      requiredFields: ['education_level', 'subjects'],
    ),
    'Skill Development': ProgramConfig(
      name: 'Skill Development',
      description: 'Learn practical skills for the future',
      icon: '🛠️',
      steps: ['skill_category', 'specific_skills'],
      requiredFields: ['skill_category', 'specific_skills'],
    ),
    'Exam Preparation': ProgramConfig(
      name: 'Exam Preparation',
      description: 'Prepare for specific exams',
      icon: '📝',
      steps: ['exam_type', 'specific_exam', 'exam_subjects'],
      requiredFields: ['exam_type', 'specific_exam', 'exam_subjects'],
    ),
  };

  // Education levels with their configurations
  static const Map<String, EducationLevelConfig> educationLevels = {
    'Primary School': EducationLevelConfig(
      name: 'Primary School',
      classes: [
        'Class 1',
        'Class 2',
        'Class 3',
        'Class 4',
        'Class 5',
        'Class 6',
      ],
      hasStreams: false,
      system: 'primary',
    ),
    'Secondary School': EducationLevelConfig(
      name: 'Secondary School',
      classes: ['Form 1', 'Form 2', 'Form 3', 'Form 4', 'Form 5'],
      hasStreams: true,
      streams: ['Science', 'Arts', 'Commercial'],
      system: 'lower_secondary',
    ),
    'High School': EducationLevelConfig(
      name: 'High School',
      classes: ['Lower Sixth', 'Upper Sixth'],
      hasStreams: true,
      streams: ['Science', 'Arts', 'Commercial'],
      system: 'upper_secondary',
    ),
    'University': EducationLevelConfig(
      name: 'University',
      classes: ['Year 1', 'Year 2', 'Year 3', 'Year 4', 'Masters', 'PhD'],
      hasStreams: false,
      system: 'higher_education',
    ),
  };

  // Exam types and their configurations
  static const Map<String, ExamTypeConfig> examTypes = {
    'Regional Exams': ExamTypeConfig(
      name: 'Regional Exams',
      description: 'Local and national exams',
      exams: [
        'Common Entrance',
        'GCE O-Level',
        'GCE A-Level',
        'BEPC',
        'Baccalauréat',
        'Probatoire',
      ],
    ),
    'International Exams': ExamTypeConfig(
      name: 'International Exams',
      description: 'Global standardized tests',
      exams: ['SAT', 'ACT', 'IELTS', 'TOEFL', 'IGCSE', 'IB'],
    ),
    'Concours': ExamTypeConfig(
      name: 'Concours',
      description: 'Competitive entrance exams',
      exams: [
        'Medical Concours',
        'Engineering Concours',
        'ENS Entrance',
        'Police Concours',
        'Customs Concours',
      ],
    ),
  };

  // Exam-specific subject mappings
  static const Map<String, List<String>> examSubjects = {
    'Common Entrance': [
      'Mathematics',
      'English',
      'French',
      'General Knowledge',
    ],
    'GCE O-Level': [
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
      'English',
      'French',
      'History',
      'Geography',
    ],
    'GCE A-Level': [
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
      'English Literature',
      'French',
      'History',
      'Geography',
      'Economics',
    ],
    'SAT': ['Mathematics', 'English', 'Reading', 'Writing'],
    'IELTS': ['Listening', 'Reading', 'Writing', 'Speaking'],
    'TOEFL': ['Listening', 'Reading', 'Writing', 'Speaking'],
  };

  // Stream descriptions
  static const Map<String, String> streamDescriptions = {
    'Science': 'Mathematics, Physics, Chemistry, Biology',
    'Arts': 'English, French, History, Geography, Literature',
    'Commercial': 'Accounting, Commerce, Economics, Business Studies',
  };

  // Budget ranges
  static const List<String> budgetRanges = [
    '< 3,000 XAF',
    '3,000-5,000 XAF',
    '5,000-8,000 XAF',
    '8,000-12,000 XAF',
    '12,000+ XAF',
  ];

  // Tutor preferences
  static const List<String> tutorGenderPreferences = [
    'No Preference',
    'Male',
    'Female',
  ];

  static const List<String> tutorExperienceLevels = [
    'Any Level',
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert',
  ];

  // Learning preferences
  static const List<String> learningModes = ['Online', 'In-Person', 'Hybrid'];

  static const List<String> learningStyles = [
    'Visual',
    'Auditory',
    'Kinesthetic',
    'Reading/Writing',
    'Mixed',
  ];

  static const List<String> schedulePreferences = [
    'Morning',
    'Afternoon',
    'Evening',
    'Weekend',
    'Flexible',
  ];

  // Learning goals and challenges
  static const List<String> learningGoals = [
    'Improve Grades',
    'Prepare for Exams',
    'Build Confidence',
    'Develop Study Skills',
    'Catch Up on Missed Topics',
    'Advanced Learning',
    'Test Preparation',
    'Homework Help',
  ];

  static const List<String> learningChallenges = [
    'Understanding Concepts',
    'Time Management',
    'Concentration',
    'Test Anxiety',
    'Organization',
    'Motivation',
    'Specific Subjects',
    'None',
  ];

  // Learning needs
  static const List<String> learningNeeds = [
    'ADHD Support',
    'Dyslexia Support',
    'Learning Disability',
    'Gifted & Talented',
    'English as Second Language',
    'Behavioral Support',
    'None',
  ];

  // Skill areas (from AppData)
  static const Map<String, List<String>> skillAreas = {
    'Digital & Tech Skills': [
      'Web Development',
      'Mobile App Development',
      'Data Science',
      'Cybersecurity',
      'Graphic Design',
      'UI/UX Design',
      'Digital Marketing',
    ],
    'Creative & Arts Skills': [
      'Drawing',
      'Painting',
      'Music Instrument',
      'Photography',
      'Video Editing',
      'Creative Writing',
      'Dance',
    ],
    'Life & Career Skills': [
      'Public Speaking',
      'Entrepreneurship',
      'Time Management',
      'Financial Literacy',
      'Leadership',
      'Communication',
      'Project Management',
    ],
    'Language Skills': [
      'English Language',
      'French Language',
      'Spanish',
      'German',
      'Chinese',
      'Arabic',
      'Portuguese',
    ],
    'Professional Skills': [
      'Microsoft Office',
      'Project Management',
      'Business Writing',
      'Customer Service',
      'Sales',
      'Marketing',
      'Human Resources',
    ],
  };

  // Cities and quarters (from AppData)
  static const Map<String, List<String>> cities = {
    'Buea': [
      'Molyko',
      'Muea',
      'Tole',
      'Malingo',
      'Bokwaongo',
      'Bonduma',
      'Soppo',
      'Mile 17',
      'Mile 16',
      'Mile 14',
      'Great Soppo',
      'Small Soppo',
      'Bwitingi',
      'Bova',
      'Bokova',
      'Wonakanda',
      'Likoko Membea',
      'Likoko',
    ],
    'Douala': [
      'Akwa',
      'Bonanjo',
      'Bonapriso',
      'Deido',
      'New Bell',
      'Pk8',
      'Pk12',
      'Pk16',
      'Pk20',
      'Pk24',
      'Makepe',
      'Kotto',
      'Logbaba',
      'Ndokotti',
      'Bessengue',
      'Bassa',
      'Bepanda',
      'Cité des Palmiers',
      'Cité Cicam',
      'Wouri',
      'Bonendale',
      'Pk32',
      'Pk36',
    ],
    'Yaoundé': [
      'Centre',
      'Bastos',
      'Messa',
      'Emana',
      'Efoulan',
      'Mvog-Ada',
      'Mvog-Betsi',
      'Mvog-Mbi',
      'Mvog-Atangana',
      'Mvog-Fouda',
      'Mvog-Mballa',
      'Mvog-Nyong',
      'Mvog-Tsala',
      'Mvog-Wamba',
      'Mvog-Yaoundé',
      'Mvog-Zamba',
      'Mvog-Zing',
      'Mvog-Zou',
      'Mvog-Zoua',
      'Mvog-Zoué',
      'Mvog-Zouéa',
      'Mvog-Zouéé',
    ],
    'Limbe': [
      'Centre',
      'Down Beach',
      'Up Station',
      'Mile 1',
      'Mile 2',
      'Mile 3',
      'Mile 4',
      'Mile 5',
      'Bota',
      'Idenau',
      'Bakingili',
      'Batoke',
      'Mokunda',
      'Fako',
      'Mungo',
    ],
    'Kumba': [
      'Centre',
      'Fiango',
      'Mile 1',
      'Mile 2',
      'Mile 3',
      'Mile 4',
      'Fiango Center',
    ],
  };

  // Helper methods
  static List<String> getProgramsForUserType(String userType) {
    return userTypePrograms[userType] ?? [];
  }

  static ProgramConfig? getProgramConfig(String program) {
    return programConfigs[program];
  }

  static EducationLevelConfig? getEducationLevelConfig(String level) {
    return educationLevels[level];
  }

  static ExamTypeConfig? getExamTypeConfig(String examType) {
    return examTypes[examType];
  }

  static List<String> getSubjectsForEducationLevel(
    String level,
    String? stream,
  ) {
    final config = getEducationLevelConfig(level);
    if (config == null) return [];

    if (config.system == 'primary') {
      return AppData.getSubjectsForLevel('primary', 'anglophone');
    } else if (config.system == 'lower_secondary') {
      return AppData.getSubjectsForLevel('lower_secondary', 'anglophone');
    } else if (config.system == 'upper_secondary') {
      // For upper_secondary (High School), show subjects based on stream if selected
      // Otherwise, show all subjects from all streams
      if (stream != null && stream.isNotEmpty) {
        // Stream selected - return stream-specific subjects
        return AppData.getSubjectsForLevel(
          'upper_secondary',
          'anglophone',
          stream: stream,
        );
      } else {
        // No stream selected - return all subjects from all streams (merged)
        // This allows users to see subjects before selecting a stream
        return AppData.getSubjectsForLevel('upper_secondary', 'anglophone');
      }
    }
    return [];
  }
  
  /// Check if stream is required for a given education level
  static bool isStreamRequired(String level) {
    final config = getEducationLevelConfig(level);
    return config?.hasStreams == true;
  }

  static List<String> getSubjectsForExam(String exam) {
    return examSubjects[exam] ?? AppData.subjects;
  }

  static List<String> getExamsForType(String examType) {
    final config = getExamTypeConfig(examType);
    return config?.exams ?? [];
  }

  static String getStreamDescription(String stream) {
    return streamDescriptions[stream] ?? '';
  }

  static bool isFieldRequired(String program, String field) {
    final config = getProgramConfig(program);
    return config?.requiredFields.contains(field) ?? false;
  }

  static List<String> getStepsForProgram(String program) {
    final config = getProgramConfig(program);
    return config?.steps ?? [];
  }
}

/// Configuration for a specific program
class ProgramConfig {
  final String name;
  final String description;
  final String icon;
  final List<String> steps;
  final List<String> requiredFields;

  const ProgramConfig({
    required this.name,
    required this.description,
    required this.icon,
    required this.steps,
    required this.requiredFields,
  });
}

/// Configuration for education levels
class EducationLevelConfig {
  final String name;
  final List<String> classes;
  final bool hasStreams;
  final List<String>? streams;
  final String system;

  const EducationLevelConfig({
    required this.name,
    required this.classes,
    required this.hasStreams,
    this.streams,
    required this.system,
  });
}

/// Configuration for exam types
class ExamTypeConfig {
  final String name;
  final String description;
  final List<String> exams;

  const ExamTypeConfig({
    required this.name,
    required this.description,
    required this.exams,
  });
}
