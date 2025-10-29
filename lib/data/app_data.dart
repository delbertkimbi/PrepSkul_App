class AppData {
  // All cities and their quarters
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
      'Mokolo',
      'Mendong',
      'Emana',
      'Efoulan',
      'Nlongkak',
      'Essos',
      'Mvog-Ada',
      'Mvog-Betsi',
      'Nkol-Eton',
      'Nkol-Afeme',
      'Melen',
      'Nkomkana',
      'Mbankomo',
      'Olembe',
      'Nsam',
      'Mvog-Mbi',
      'Etoa-Meki',
      'Nkoldongo',
      'Cité Verte',
      'Biyem-Assi',
      'Etoug-Ebe',
    ],
    'Bamenda': [
      'Commercial Avenue',
      'Food Market',
      'Up Station',
      'Mankon',
      'Nkwen',
      'Bambui',
      'Mankon Town',
      'Ntamulung',
      'Ntarinkon',
      'Nkwen Town',
      'Bambui Town',
      'Atuakom',
      'Nkwen Station',
      'Commercial Center',
    ],
    'Bafoussam': [
      'Centre',
      'Banengo',
      'Toumi',
      'Toukoum',
      'Bamougoum',
      'Foumban',
      'Bamendjinda',
      'Bamboutos',
      'Banengo Center',
      'Toumi Center',
    ],
    'Garoua': [
      'Centre',
      'Roumdé Adjia',
      'Djamboutou',
      'Pitoa',
      'Roumdé',
      'Djamboutou Center',
      'Pitoa Center',
    ],
    'Maroua': [
      'Centre',
      'Djarengol',
      'Doualaré',
      'Domayo',
      'Djarengol Center',
      'Doualaré Center',
    ],
    'Ngaoundéré': [
      'Centre',
      'Djalingo',
      'Dang',
      'Djalingo Center',
      'Dang Center',
    ],
    'Bertoua': ['Centre', 'Mbankomo', 'Mbankomo Center'],
    'Ebolowa': ['Centre', 'Mvangan', 'Mvangan Center'],
    'Kumba': [
      'Centre',
      'Fiango',
      'Mile 1',
      'Mile 2',
      'Mile 3',
      'Mile 4',
      'Fiango Center',
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
    'Dschang': [
      'Centre',
      'Dschang Ville',
      'Mengong',
      'Fongo-Tongo',
      'Fontem',
      'Foumbot',
      'Koutaba',
      'Mbouda',
    ],
    'Foumban': [
      'Centre',
      'Palais Royal',
      'Quartier Hausa',
      'Quartier Bamoun',
      'Quartier Peulh',
      'Mankon',
      'Njindare',
      'Njinka',
    ],
    'Nkongsamba': [
      'Centre',
      'Nkongsamba Ville',
      'Melong',
      'Loum',
      'Manjo',
      'Pouma',
      'Nlonako',
    ],
    'Kribi': [
      'Centre',
      'Kribi Plage',
      'Kribi Port',
      'Lolodorf',
      'Akonolinga',
      'Mvangan',
      'Mengong',
    ],
    'Edéa': [
      'Centre',
      'Edéa Ville',
      'Dibombari',
      'Pouma',
      'Melong',
      'Nkongsamba',
    ],
    'Mbalmayo': [
      'Centre',
      'Mbalmayo Ville',
      'Ngoumou',
      'Mbankomo',
      'Obala',
      'Monatele',
    ],
    'Sangmelima': [
      'Centre',
      'Sangmelima Ville',
      'Mvangan',
      'Ebolowa',
      'Akonolinga',
      'Lolodorf',
    ],
    'Mamfe': [
      'Centre',
      'Mamfe Ville',
      'Akwaya',
      'Eyumojock',
      'Bakassi',
      'Mundemba',
    ],
  };

  // All programs
  static const List<String> programs = [
    'Exam Preparation',
    'Academic Tutoring',
    'Skill Development',
  ];

  // Exam Types for Exam Preparation
  static const List<String> examTypes = [
    'Common Entrance',
    'Concours 6ème',
    'BEPC',
    'GCE O-Level',
    'Probatoire',
    'Baccalauréat',
    'GCE A-Level',
    'SAT',
    'IELTS',
    'TOEFL',
    'Concours ENS',
    'Engineering Concours',
    'Medical Concours',
    'Other',
  ];

  // All subjects
  static const List<String> subjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'French',
    'History',
    'Geography',
    'Economics',
    'Computer Science',
    'Art',
    'Music',
  ];

  // All exams
  static const List<String> exams = [
    'Primary 6 Exam (CEPE)',
    'Primary 6 Exam (FSLC)',
    'BEPC',
    'GCE O-Level',
    'Baccalauréat',
    'GCE A-Level',
    'Concours ENS',
    'Concours Polytechnique',
    'Concours Médecine',
    'SAT',
    'TOEFL',
    'IELTS',
    'GRE',
  ];

  // All skills
  static const List<String> skills = [
    'Web Development',
    'Python Programming',
    'Java Programming',
    'Mobile App Development',
    'Graphic Design',
    'Video Editing',
    'Photography',
    'Drawing & Sketching',
    'Painting',
    'Piano',
    'Guitar',
    'Voice Training',
    'Public Speaking',
    'Tailoring & Fashion Design',
    'Hair Styling',
    'Makeup Artistry',
    'Cooking & Baking',
    'Leadership Skills',
    'Communication Skills',
    'Business Planning',
    'Financial Literacy',
  ];

  // Grade levels - Cameroon Education System
  static const List<String> gradeLevels = [
    'Nursery School',
    'Class 1',
    'Class 2',
    'Class 3',
    'Class 4',
    'Class 5',
    'Class 6',
    'Form 1',
    'Form 2',
    'Form 3',
    'Form 4',
    'Form 5',
    'High School',
    'University',
  ];

  // Learning modes
  static const List<String> learningModes = [
    'Online Learning',
    'In-Person Learning',
    'Hybrid Learning',
  ];

  // Session durations
  static const List<String> sessionDurations = [
    '30 minutes',
    '45 minutes',
    '60 minutes',
    '90 minutes',
  ];

  // Session frequencies
  static const List<String> sessionFrequencies = [
    'Once a week',
    'Twice a week',
    'Three times a week',
    'Daily',
    'As needed',
  ];

  // Availability times
  static const List<String> availabilityTimes = [
    'Monday Morning',
    'Monday Afternoon',
    'Monday Evening',
    'Tuesday Morning',
    'Tuesday Afternoon',
    'Tuesday Evening',
    'Wednesday Morning',
    'Wednesday Afternoon',
    'Wednesday Evening',
    'Thursday Morning',
    'Thursday Afternoon',
    'Thursday Evening',
    'Friday Morning',
    'Friday Afternoon',
    'Friday Evening',
    'Saturday Morning',
    'Saturday Afternoon',
    'Saturday Evening',
    'Sunday Morning',
    'Sunday Afternoon',
    'Sunday Evening',
  ];

  // Budget ranges
  static const List<String> budgetRanges = [
    '< 3,000 XAF',
    '3,000–5,000 XAF',
    '5,000–8,000 XAF',
    '8,000–12,000 XAF',
    '12,000+ XAF',
  ];

  // Tutor types
  static const List<String> tutorTypes = [
    'Certified teacher',
    'University student',
    'Professional tutor',
    'Industry expert',
    'No preference',
  ];

  // Teaching styles
  static const List<String> teachingStyles = [
    'Structured lesson plans',
    'Interactive discussions',
    'Hands-on practice',
    'Visual demonstrations',
    'Step-by-step guidance',
    'Encouraging and patient',
    'Challenging and rigorous',
  ];

  // Learning styles
  static const List<String> learningStyles = [
    'Visual learning (diagrams, charts)',
    'Auditory learning (listening, discussion)',
    'Kinesthetic learning (hands-on, practice)',
    'Reading/Writing learning',
    'Interactive learning',
    'Self-paced learning',
    'Group learning',
  ];

  // Primary goals
  static const List<String> primaryGoals = [
    'Improve grades',
    'Prepare for exams',
    'Learn new skills',
    'Career development',
    'Personal enrichment',
    'Remedial support',
    'Advanced learning',
  ];

  // Parent-specific questions
  static const List<String> parentQuestions = [
    'What is your child\'s biggest academic challenge?',
    'How does your child prefer to learn?',
    'What motivates your child most?',
    'Does your child have any learning difficulties?',
    'What are your expectations from tutoring?',
    'How involved do you want to be in the learning process?',
    'What is your preferred communication method with tutors?',
    'Does your child have any special requirements?',
  ];

  // Learner-specific questions
  static const List<String> learnerQuestions = [
    'What subjects do you find most challenging?',
    'What is your preferred learning style?',
    'What motivates you to learn?',
    'How do you prefer to receive feedback?',
    'What are your learning goals?',
    'Do you prefer individual or group learning?',
    'What time of day do you learn best?',
    'Do you have any learning preferences or requirements?',
  ];

  // Start timelines
  static const List<String> startTimelines = [
    'Within 1 week',
    '1–2 weeks',
    '1 month',
    'Flexible',
  ];

  // Cameroonian Education System Structure
  static const Map<String, dynamic> educationSystem = {
    'primary': {
      'name': 'Primary School',
      'duration': '6 years',
      'classes': [
        'Class 1',
        'Class 2',
        'Class 3',
        'Class 4',
        'Class 5',
        'Class 6',
      ],
      'exams': {
        'anglophone': ['First School Leaving Certificate (FSLC)'],
        'francophone': ['Certificat d\'études primaires (CEP)'],
      },
      'subjects': {
        'anglophone': [
          'Mathematics',
          'English',
          'French',
          'Environmental Education',
          'Science',
          'Social Studies',
          'Drawing',
          'ICT',
        ],
        'francophone': [
          'Mathématiques',
          'Français',
          'Anglais',
          'Éducation civique',
          'Sciences',
          'Histoire-Géographie',
          'Dessin',
          'Informatique',
        ],
      },
    },
    'lower_secondary': {
      'name': 'Lower Secondary',
      'duration': {'anglophone': '5 years', 'francophone': '4 years'},
      'classes': {
        'anglophone': ['Form 1', 'Form 2', 'Form 3', 'Form 4', 'Form 5'],
        'francophone': ['Sixième', 'Cinquième', 'Quatrième', 'Troisième'],
      },
      'exams': {
        'anglophone': ['Cameroon GCE Ordinary Level (O/L)'],
        'francophone': ['Brevet d\'Etudes du Premier Cycle (BEPC)'],
      },
      'subjects': {
        'anglophone': [
          'Mathematics',
          'Physics',
          'Chemistry',
          'Biology',
          'English',
          'French',
          'History',
          'Geography',
          'Economics',
          'ICT',
        ],
        'francophone': [
          'Mathématiques',
          'Sciences de la vie et de la terre',
          'Physique-Chimie',
          'Français',
          'Anglais',
          'Histoire-Géographie',
          'Informatique',
        ],
      },
    },
    'upper_secondary': {
      'name': 'Upper Secondary / High School',
      'duration': {'anglophone': '2 years', 'francophone': '3 years'},
      'classes': {
        'anglophone': ['Lower Sixth', 'Upper Sixth'],
        'francophone': ['Seconde', 'Première', 'Terminale'],
      },
      'exams': {
        'anglophone': ['Cameroon GCE Advanced Level (A/L)'],
        'francophone': ['Baccalauréat Général', 'Baccalauréat Technique'],
      },
      'streams': {
        'anglophone': {
          'Arts': [
            'English Literature',
            'French',
            'History',
            'Geography',
            'Economics',
          ],
          'Sciences': ['Mathematics', 'Chemistry', 'Physics', 'Biology', 'ICT'],
          'Commercial': [
            'Accounting',
            'Commerce',
            'Economics',
            'Business Studies',
          ],
        },
        'francophone': {
          'Series A - Lettres': [
            'Lettres-Philosophie',
            'Français',
            'Anglais',
            'Histoire',
            'Géographie',
          ],
          'Series C - Sciences': [
            'Mathématiques',
            'Sciences Physiques',
            'Chimie',
            'Anglais',
          ],
          'Series TI - Technologies': [
            'Informatique',
            'Mathématiques',
            'Anglais',
            'Français',
          ],
        },
      },
    },
    'higher_education': {
      'name': 'Higher Education',
      'cycles': ['Licence/Bachelor', 'Master', 'Doctorate'],
      'entrance_exams': [
        'University Entrance',
        'Engineering Concours',
        'Medical Concours',
        'ENS Entrance',
        'International University Entrance',
      ],
    },
  };

  // Skill Development Areas
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

  // Helper methods
  static List<String> getCities() => cities.keys.toList();

  static List<String> getQuartersForCity(String city) => cities[city] ?? [];

  // Education system helper methods
  static List<String> getSubjectsForLevel(
    String level,
    String system, {
    String? stream,
  }) {
    if (level == 'primary') {
      return educationSystem['primary']['subjects'][system] ?? [];
    } else if (level == 'lower_secondary') {
      return educationSystem['lower_secondary']['subjects'][system] ?? [];
    } else if (level == 'upper_secondary') {
      if (stream != null) {
        return educationSystem['upper_secondary']['streams'][system][stream] ??
            [];
      }
      // Return all subjects from all streams
      List<String> allSubjects = [];
      educationSystem['upper_secondary']['streams'][system].values.forEach((
        streamSubjects,
      ) {
        allSubjects.addAll(streamSubjects);
      });
      return allSubjects.toSet().toList();
    }
    return [];
  }

  static List<String> getExamsForLevel(String level, String system) {
    if (level == 'primary') {
      return educationSystem['primary']['exams'][system] ?? [];
    } else if (level == 'lower_secondary') {
      return educationSystem['lower_secondary']['exams'][system] ?? [];
    } else if (level == 'upper_secondary') {
      return educationSystem['upper_secondary']['exams'][system] ?? [];
    } else if (level == 'higher_education') {
      return educationSystem['higher_education']['entrance_exams'] ?? [];
    }
    return [];
  }

  static List<String> getSpecializationsForTutoringArea(
    String area,
    List<String> selectedLevels,
  ) {
    List<String> specializations = [];

    if (area == 'Academic Tutoring') {
      // Get subjects based on selected levels
      for (String level in selectedLevels) {
        if (level == 'Primary School') {
          specializations.addAll(getSubjectsForLevel('primary', 'anglophone'));
          specializations.addAll(getSubjectsForLevel('primary', 'francophone'));
        } else if (level == 'Secondary School') {
          specializations.addAll(
            getSubjectsForLevel('lower_secondary', 'anglophone'),
          );
          specializations.addAll(
            getSubjectsForLevel('lower_secondary', 'francophone'),
          );
        } else if (level == 'High School') {
          specializations.addAll(
            getSubjectsForLevel('upper_secondary', 'anglophone'),
          );
          specializations.addAll(
            getSubjectsForLevel('upper_secondary', 'francophone'),
          );
        }
      }
    } else if (area == 'Exam Preparation') {
      // Get exams based on selected levels
      for (String level in selectedLevels) {
        if (level == 'Primary School') {
          specializations.addAll(getExamsForLevel('primary', 'anglophone'));
          specializations.addAll(getExamsForLevel('primary', 'francophone'));
        } else if (level == 'Secondary School') {
          specializations.addAll(
            getExamsForLevel('lower_secondary', 'anglophone'),
          );
          specializations.addAll(
            getExamsForLevel('lower_secondary', 'francophone'),
          );
        } else if (level == 'High School') {
          specializations.addAll(
            getExamsForLevel('upper_secondary', 'anglophone'),
          );
          specializations.addAll(
            getExamsForLevel('upper_secondary', 'francophone'),
          );
        } else if (level == 'International Exams') {
          specializations.addAll([
            'SAT',
            'TOEFL',
            'IELTS',
            'GRE',
            'GMAT',
            'DELF',
            'DALF',
          ]);
        } else if (level == 'Concours Preparation') {
          specializations.addAll([
            'Engineering Concours',
            'Medical Concours',
            'ENS Entrance',
            'Police Concours',
            'Customs Concours',
          ]);
        }
      }
    } else if (area == 'Skill Development') {
      // Get skills from all categories
      skillAreas.values.forEach((skills) => specializations.addAll(skills));
    }

    return specializations.toSet().toList(); // Remove duplicates
  }
}
