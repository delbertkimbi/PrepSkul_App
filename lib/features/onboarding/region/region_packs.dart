class Bilingual {
  const Bilingual({required this.en, required this.fr});
  final String en;
  final String fr;
  String t(String locale) => locale.toLowerCase().startsWith('fr') ? fr : en;
}

class RegionOption {
  const RegionOption({required this.id, required this.label});
  final String id;
  final Bilingual label;
}

class RegionLevel extends RegionOption {
  const RegionLevel({
    required super.id,
    required super.label,
    required this.educationLevel,
  });
  final String educationLevel;
}

class RegionSystem {
  const RegionSystem({
    required this.id,
    required this.label,
    required this.levels,
    required this.exams,
    required this.subjects,
  });
  final String id;
  final Bilingual label;
  final List<RegionLevel> levels;
  final List<RegionOption> exams;
  final List<RegionOption> subjects;
}

class RegionPack {
  const RegionPack({
    required this.id,
    required this.countryCode,
    required this.label,
    required this.cities,
    required this.systems,
    required this.interests,
  });
  final String id;
  final String countryCode;
  final Bilingual label;
  final List<RegionOption> cities;
  final List<RegionSystem> systems;
  final List<RegionOption> interests;
}

const _cmFrSubjects = [
  RegionOption(id: 'maths', label: Bilingual(en: 'Mathematics', fr: 'Mathématiques')),
  RegionOption(id: 'french', label: Bilingual(en: 'French', fr: 'Français')),
  RegionOption(id: 'english', label: Bilingual(en: 'English', fr: 'Anglais')),
  RegionOption(id: 'pct', label: Bilingual(en: 'Physics-Chemistry', fr: 'Physique-Chimie')),
  RegionOption(id: 'svt', label: Bilingual(en: 'Life & Earth sciences', fr: 'SVT')),
  RegionOption(id: 'histgeo', label: Bilingual(en: 'History-Geography', fr: 'Histoire-Géo')),
  RegionOption(id: 'philo', label: Bilingual(en: 'Philosophy', fr: 'Philosophie')),
  RegionOption(id: 'cs', label: Bilingual(en: 'Computer science', fr: 'Informatique')),
  RegionOption(id: 'other', label: Bilingual(en: 'Something else', fr: 'Autre chose')),
];

const _cmEnSubjects = [
  RegionOption(id: 'maths', label: Bilingual(en: 'Mathematics', fr: 'Mathématiques')),
  RegionOption(id: 'english', label: Bilingual(en: 'English', fr: 'Anglais')),
  RegionOption(id: 'french', label: Bilingual(en: 'French', fr: 'Français')),
  RegionOption(id: 'physics', label: Bilingual(en: 'Physics', fr: 'Physique')),
  RegionOption(id: 'chemistry', label: Bilingual(en: 'Chemistry', fr: 'Chimie')),
  RegionOption(id: 'biology', label: Bilingual(en: 'Biology', fr: 'Biologie')),
  RegionOption(id: 'geography', label: Bilingual(en: 'Geography', fr: 'Géographie')),
  RegionOption(id: 'literature', label: Bilingual(en: 'Literature', fr: 'Littérature')),
  RegionOption(id: 'economics', label: Bilingual(en: 'Economics', fr: 'Économie')),
  RegionOption(id: 'cs', label: Bilingual(en: 'Computer science', fr: 'Informatique')),
  RegionOption(id: 'other', label: Bilingual(en: 'Something else', fr: 'Autre chose')),
];

const africaInterests = [
  RegionOption(id: 'football', label: Bilingual(en: 'Football', fr: 'Football')),
  RegionOption(id: 'music', label: Bilingual(en: 'Music', fr: 'Musique')),
  RegionOption(id: 'gospel', label: Bilingual(en: 'Gospel / choir', fr: 'Gospel / chorale')),
  RegionOption(id: 'gaming', label: Bilingual(en: 'Gaming', fr: 'Jeux vidéo')),
  RegionOption(id: 'coding', label: Bilingual(en: 'Coding', fr: 'Code')),
  RegionOption(id: 'art', label: Bilingual(en: 'Art', fr: 'Art')),
  RegionOption(id: 'cooking', label: Bilingual(en: 'Cooking', fr: 'Cuisine')),
  RegionOption(id: 'business', label: Bilingual(en: 'Business / hustle', fr: 'Business')),
  RegionOption(id: 'faith', label: Bilingual(en: 'Faith', fr: 'Foi')),
  RegionOption(id: 'reading', label: Bilingual(en: 'Reading', fr: 'Lecture')),
  RegionOption(id: 'dance', label: Bilingual(en: 'Dance', fr: 'Danse')),
];

const cameroonFrancophone = RegionSystem(
  id: 'cm-francophone',
  label: Bilingual(
    en: 'Francophone (BEPC / Probatoire / Bac)',
    fr: 'Francophone (BEPC / Probatoire / Bac)',
  ),
  levels: [
    RegionLevel(id: 'sil', label: Bilingual(en: 'SIL', fr: 'SIL'), educationLevel: 'Primary School'),
    RegionLevel(id: 'cp', label: Bilingual(en: 'CP', fr: 'CP'), educationLevel: 'Primary School'),
    RegionLevel(id: 'ce1', label: Bilingual(en: 'CE1', fr: 'CE1'), educationLevel: 'Primary School'),
    RegionLevel(id: 'ce2', label: Bilingual(en: 'CE2', fr: 'CE2'), educationLevel: 'Primary School'),
    RegionLevel(id: 'cm1', label: Bilingual(en: 'CM1', fr: 'CM1'), educationLevel: 'Primary School'),
    RegionLevel(id: 'cm2', label: Bilingual(en: 'CM2', fr: 'CM2'), educationLevel: 'Primary School'),
    RegionLevel(id: '6eme', label: Bilingual(en: '6ème', fr: '6ème'), educationLevel: 'Secondary School'),
    RegionLevel(id: '5eme', label: Bilingual(en: '5ème', fr: '5ème'), educationLevel: 'Secondary School'),
    RegionLevel(id: '4eme', label: Bilingual(en: '4ème', fr: '4ème'), educationLevel: 'Secondary School'),
    RegionLevel(id: '3eme', label: Bilingual(en: '3ème', fr: '3ème'), educationLevel: 'Secondary School'),
    RegionLevel(id: '2nde', label: Bilingual(en: '2nde', fr: '2nde'), educationLevel: 'High School'),
    RegionLevel(id: '1ere', label: Bilingual(en: '1ère', fr: '1ère'), educationLevel: 'High School'),
    RegionLevel(id: 'terminale', label: Bilingual(en: 'Terminale', fr: 'Terminale'), educationLevel: 'High School'),
    RegionLevel(id: 'uni', label: Bilingual(en: 'University', fr: 'Université'), educationLevel: 'University'),
  ],
  exams: [
    RegionOption(id: 'none', label: Bilingual(en: 'No exam this year', fr: 'Pas d’examen cette année')),
    RegionOption(id: 'bepc', label: Bilingual(en: 'BEPC', fr: 'BEPC')),
    RegionOption(id: 'probatoire', label: Bilingual(en: 'Probatoire', fr: 'Probatoire')),
    RegionOption(id: 'bac', label: Bilingual(en: 'Baccalauréat', fr: 'Baccalauréat')),
    RegionOption(id: 'concours', label: Bilingual(en: 'Concours', fr: 'Concours')),
  ],
  subjects: _cmFrSubjects,
);

const cameroonAnglophone = RegionSystem(
  id: 'cm-anglophone',
  label: Bilingual(
    en: 'Anglophone (GCE O / A Level)',
    fr: 'Anglophone (GCE O / A Level)',
  ),
  levels: [
    RegionLevel(id: 'class1', label: Bilingual(en: 'Class 1', fr: 'Class 1'), educationLevel: 'Primary School'),
    RegionLevel(id: 'class2', label: Bilingual(en: 'Class 2', fr: 'Class 2'), educationLevel: 'Primary School'),
    RegionLevel(id: 'class3', label: Bilingual(en: 'Class 3', fr: 'Class 3'), educationLevel: 'Primary School'),
    RegionLevel(id: 'class4', label: Bilingual(en: 'Class 4', fr: 'Class 4'), educationLevel: 'Primary School'),
    RegionLevel(id: 'class5', label: Bilingual(en: 'Class 5', fr: 'Class 5'), educationLevel: 'Primary School'),
    RegionLevel(id: 'class6', label: Bilingual(en: 'Class 6', fr: 'Class 6'), educationLevel: 'Primary School'),
    RegionLevel(id: 'form1', label: Bilingual(en: 'Form 1', fr: 'Form 1'), educationLevel: 'Secondary School'),
    RegionLevel(id: 'form2', label: Bilingual(en: 'Form 2', fr: 'Form 2'), educationLevel: 'Secondary School'),
    RegionLevel(id: 'form3', label: Bilingual(en: 'Form 3', fr: 'Form 3'), educationLevel: 'Secondary School'),
    RegionLevel(id: 'form4', label: Bilingual(en: 'Form 4', fr: 'Form 4'), educationLevel: 'Secondary School'),
    RegionLevel(id: 'form5', label: Bilingual(en: 'Form 5', fr: 'Form 5'), educationLevel: 'Secondary School'),
    RegionLevel(id: 'l6', label: Bilingual(en: 'Lower Sixth', fr: 'Lower Sixth'), educationLevel: 'High School'),
    RegionLevel(id: 'u6', label: Bilingual(en: 'Upper Sixth', fr: 'Upper Sixth'), educationLevel: 'High School'),
    RegionLevel(id: 'uni', label: Bilingual(en: 'University', fr: 'Université'), educationLevel: 'University'),
  ],
  exams: [
    RegionOption(id: 'none', label: Bilingual(en: 'No exam this year', fr: 'Pas d’examen cette année')),
    RegionOption(id: 'ce', label: Bilingual(en: 'Common Entrance', fr: 'Common Entrance')),
    RegionOption(id: 'gce-o', label: Bilingual(en: 'GCE O-Level', fr: 'GCE O-Level')),
    RegionOption(id: 'gce-a', label: Bilingual(en: 'GCE A-Level', fr: 'GCE A-Level')),
    RegionOption(id: 'concours', label: Bilingual(en: 'Concours', fr: 'Concours')),
  ],
  subjects: _cmEnSubjects,
);

const regionPacks = [
  RegionPack(
    id: 'cm',
    countryCode: 'CM',
    label: Bilingual(en: 'Cameroon', fr: 'Cameroun'),
    cities: [
      RegionOption(id: 'yaounde', label: Bilingual(en: 'Yaoundé', fr: 'Yaoundé')),
      RegionOption(id: 'douala', label: Bilingual(en: 'Douala', fr: 'Douala')),
      RegionOption(id: 'bamenda', label: Bilingual(en: 'Bamenda', fr: 'Bamenda')),
      RegionOption(id: 'bafoussam', label: Bilingual(en: 'Bafoussam', fr: 'Bafoussam')),
      RegionOption(id: 'buea', label: Bilingual(en: 'Buea', fr: 'Buea')),
      RegionOption(id: 'garoua', label: Bilingual(en: 'Garoua', fr: 'Garoua')),
      RegionOption(id: 'other', label: Bilingual(en: 'Another city', fr: 'Une autre ville')),
    ],
    systems: [cameroonFrancophone, cameroonAnglophone],
    interests: africaInterests,
  ),
  RegionPack(
    id: 'ng',
    countryCode: 'NG',
    label: Bilingual(en: 'Nigeria', fr: 'Nigeria'),
    cities: [
      RegionOption(id: 'lagos', label: Bilingual(en: 'Lagos', fr: 'Lagos')),
      RegionOption(id: 'abuja', label: Bilingual(en: 'Abuja', fr: 'Abuja')),
      RegionOption(id: 'ph', label: Bilingual(en: 'Port Harcourt', fr: 'Port Harcourt')),
      RegionOption(id: 'other', label: Bilingual(en: 'Another city', fr: 'Une autre ville')),
    ],
    systems: [
      RegionSystem(
        id: 'ng-waec',
        label: Bilingual(en: 'WAEC / NECO / JAMB', fr: 'WAEC / NECO / JAMB'),
        levels: [
          RegionLevel(id: 'jss1', label: Bilingual(en: 'JSS 1', fr: 'JSS 1'), educationLevel: 'Secondary School'),
          RegionLevel(id: 'jss3', label: Bilingual(en: 'JSS 3', fr: 'JSS 3'), educationLevel: 'Secondary School'),
          RegionLevel(id: 'ss1', label: Bilingual(en: 'SS 1', fr: 'SS 1'), educationLevel: 'High School'),
          RegionLevel(id: 'ss2', label: Bilingual(en: 'SS 2', fr: 'SS 2'), educationLevel: 'High School'),
          RegionLevel(id: 'ss3', label: Bilingual(en: 'SS 3', fr: 'SS 3'), educationLevel: 'High School'),
          RegionLevel(id: 'uni', label: Bilingual(en: 'University', fr: 'Université'), educationLevel: 'University'),
        ],
        exams: [
          RegionOption(id: 'none', label: Bilingual(en: 'No exam this year', fr: 'Pas d’examen cette année')),
          RegionOption(id: 'waec', label: Bilingual(en: 'WAEC', fr: 'WAEC')),
          RegionOption(id: 'neco', label: Bilingual(en: 'NECO', fr: 'NECO')),
          RegionOption(id: 'jamb', label: Bilingual(en: 'JAMB / UTME', fr: 'JAMB / UTME')),
        ],
        subjects: _cmEnSubjects,
      ),
    ],
    interests: africaInterests,
  ),
  RegionPack(
    id: 'gh',
    countryCode: 'GH',
    label: Bilingual(en: 'Ghana', fr: 'Ghana'),
    cities: [
      RegionOption(id: 'accra', label: Bilingual(en: 'Accra', fr: 'Accra')),
      RegionOption(id: 'kumasi', label: Bilingual(en: 'Kumasi', fr: 'Kumasi')),
      RegionOption(id: 'other', label: Bilingual(en: 'Another city', fr: 'Une autre ville')),
    ],
    systems: [
      RegionSystem(
        id: 'gh-wassce',
        label: Bilingual(en: 'BECE / WASSCE', fr: 'BECE / WASSCE'),
        levels: [
          RegionLevel(id: 'jhs1', label: Bilingual(en: 'JHS 1', fr: 'JHS 1'), educationLevel: 'Secondary School'),
          RegionLevel(id: 'shs1', label: Bilingual(en: 'SHS 1', fr: 'SHS 1'), educationLevel: 'High School'),
          RegionLevel(id: 'shs3', label: Bilingual(en: 'SHS 3', fr: 'SHS 3'), educationLevel: 'High School'),
          RegionLevel(id: 'uni', label: Bilingual(en: 'University', fr: 'Université'), educationLevel: 'University'),
        ],
        exams: [
          RegionOption(id: 'none', label: Bilingual(en: 'No exam this year', fr: 'Pas d’examen cette année')),
          RegionOption(id: 'bece', label: Bilingual(en: 'BECE', fr: 'BECE')),
          RegionOption(id: 'wassce', label: Bilingual(en: 'WASSCE', fr: 'WASSCE')),
        ],
        subjects: _cmEnSubjects,
      ),
    ],
    interests: africaInterests,
  ),
  RegionPack(
    id: 'ke',
    countryCode: 'KE',
    label: Bilingual(en: 'Kenya', fr: 'Kenya'),
    cities: [
      RegionOption(id: 'nairobi', label: Bilingual(en: 'Nairobi', fr: 'Nairobi')),
      RegionOption(id: 'mombasa', label: Bilingual(en: 'Mombasa', fr: 'Mombasa')),
      RegionOption(id: 'other', label: Bilingual(en: 'Another city', fr: 'Une autre ville')),
    ],
    systems: [
      RegionSystem(
        id: 'ke-cbc',
        label: Bilingual(en: 'CBC / KCSE', fr: 'CBC / KCSE'),
        levels: [
          RegionLevel(id: 'g7', label: Bilingual(en: 'Grade 7', fr: 'Grade 7'), educationLevel: 'Secondary School'),
          RegionLevel(id: 'g10', label: Bilingual(en: 'Grade 10', fr: 'Grade 10'), educationLevel: 'High School'),
          RegionLevel(id: 'g12', label: Bilingual(en: 'Grade 12', fr: 'Grade 12'), educationLevel: 'High School'),
          RegionLevel(id: 'uni', label: Bilingual(en: 'University', fr: 'Université'), educationLevel: 'University'),
        ],
        exams: [
          RegionOption(id: 'none', label: Bilingual(en: 'No exam this year', fr: 'Pas d’examen cette année')),
          RegionOption(id: 'kcse', label: Bilingual(en: 'KCSE', fr: 'KCSE')),
        ],
        subjects: _cmEnSubjects,
      ),
    ],
    interests: africaInterests,
  ),
  RegionPack(
    id: 'ci',
    countryCode: 'CI',
    label: Bilingual(en: 'Côte d’Ivoire', fr: 'Côte d’Ivoire'),
    cities: [
      RegionOption(id: 'abidjan', label: Bilingual(en: 'Abidjan', fr: 'Abidjan')),
      RegionOption(id: 'other', label: Bilingual(en: 'Another city', fr: 'Une autre ville')),
    ],
    systems: [cameroonFrancophone],
    interests: africaInterests,
  ),
  RegionPack(
    id: 'za',
    countryCode: 'ZA',
    label: Bilingual(en: 'South Africa', fr: 'Afrique du Sud'),
    cities: [
      RegionOption(id: 'jhb', label: Bilingual(en: 'Johannesburg', fr: 'Johannesburg')),
      RegionOption(id: 'cpt', label: Bilingual(en: 'Cape Town', fr: 'Le Cap')),
      RegionOption(id: 'other', label: Bilingual(en: 'Another city', fr: 'Une autre ville')),
    ],
    systems: [
      RegionSystem(
        id: 'za-nsc',
        label: Bilingual(en: 'CAPS / NSC (Matric)', fr: 'CAPS / NSC (Matric)'),
        levels: [
          RegionLevel(id: 'g10', label: Bilingual(en: 'Grade 10', fr: 'Grade 10'), educationLevel: 'High School'),
          RegionLevel(id: 'g12', label: Bilingual(en: 'Grade 12 (Matric)', fr: 'Grade 12 (Matric)'), educationLevel: 'High School'),
          RegionLevel(id: 'uni', label: Bilingual(en: 'University', fr: 'Université'), educationLevel: 'University'),
        ],
        exams: [
          RegionOption(id: 'none', label: Bilingual(en: 'No exam this year', fr: 'Pas d’examen cette année')),
          RegionOption(id: 'nsc', label: Bilingual(en: 'NSC / Matric', fr: 'NSC / Matric')),
        ],
        subjects: _cmEnSubjects,
      ),
    ],
    interests: africaInterests,
  ),
  RegionPack(
    id: 'fr',
    countryCode: 'FR',
    label: Bilingual(en: 'France', fr: 'France'),
    cities: [],
    systems: [
      RegionSystem(
        id: 'fr-bac',
        label: Bilingual(en: 'Collège / Lycée / Bac', fr: 'Collège / Lycée / Bac'),
        levels: cameroonFrancophone.levels,
        exams: [
          RegionOption(id: 'none', label: Bilingual(en: 'No exam this year', fr: 'Pas d’examen cette année')),
          RegionOption(id: 'brevet', label: Bilingual(en: 'Brevet', fr: 'Brevet')),
          RegionOption(id: 'bac', label: Bilingual(en: 'Baccalauréat', fr: 'Baccalauréat')),
        ],
        subjects: _cmFrSubjects,
      ),
    ],
    interests: africaInterests,
  ),
  RegionPack(
    id: 'gb',
    countryCode: 'GB',
    label: Bilingual(en: 'United Kingdom', fr: 'Royaume-Uni'),
    cities: [],
    systems: [
      RegionSystem(
        id: 'gb-gcse',
        label: Bilingual(en: 'GCSE / A-Level', fr: 'GCSE / A-Level'),
        levels: [
          RegionLevel(id: 'y10', label: Bilingual(en: 'Year 10', fr: 'Year 10'), educationLevel: 'Secondary School'),
          RegionLevel(id: 'y11', label: Bilingual(en: 'Year 11', fr: 'Year 11'), educationLevel: 'Secondary School'),
          RegionLevel(id: 'y12', label: Bilingual(en: 'Year 12', fr: 'Year 12'), educationLevel: 'High School'),
          RegionLevel(id: 'y13', label: Bilingual(en: 'Year 13', fr: 'Year 13'), educationLevel: 'High School'),
          RegionLevel(id: 'uni', label: Bilingual(en: 'University', fr: 'Université'), educationLevel: 'University'),
        ],
        exams: [
          RegionOption(id: 'none', label: Bilingual(en: 'No exam this year', fr: 'Pas d’examen cette année')),
          RegionOption(id: 'gcse', label: Bilingual(en: 'GCSE', fr: 'GCSE')),
          RegionOption(id: 'alevel', label: Bilingual(en: 'A-Level', fr: 'A-Level')),
        ],
        subjects: _cmEnSubjects,
      ),
    ],
    interests: africaInterests,
  ),
  RegionPack(
    id: 'us',
    countryCode: 'US',
    label: Bilingual(en: 'United States', fr: 'États-Unis'),
    cities: [],
    systems: [
      RegionSystem(
        id: 'us-k12',
        label: Bilingual(en: 'US grades / SAT / AP', fr: 'Classes US / SAT / AP'),
        levels: [
          RegionLevel(id: 'g9', label: Bilingual(en: '9th grade', fr: '9e année'), educationLevel: 'High School'),
          RegionLevel(id: 'g11', label: Bilingual(en: '11th grade', fr: '11e année'), educationLevel: 'High School'),
          RegionLevel(id: 'g12', label: Bilingual(en: '12th grade', fr: '12e année'), educationLevel: 'High School'),
          RegionLevel(id: 'uni', label: Bilingual(en: 'College / university', fr: 'Université'), educationLevel: 'University'),
        ],
        exams: [
          RegionOption(id: 'none', label: Bilingual(en: 'No exam this year', fr: 'Pas d’examen cette année')),
          RegionOption(id: 'sat', label: Bilingual(en: 'SAT / ACT', fr: 'SAT / ACT')),
          RegionOption(id: 'ap', label: Bilingual(en: 'AP', fr: 'AP')),
        ],
        subjects: _cmEnSubjects,
      ),
    ],
    interests: africaInterests,
  ),
  RegionPack(
    id: 'global',
    countryCode: 'ZZ',
    label: Bilingual(en: 'Somewhere else', fr: 'Ailleurs'),
    cities: [],
    systems: [
      RegionSystem(
        id: 'global-open',
        label: Bilingual(en: 'School / university / skills', fr: 'École / université / compétences'),
        levels: [
          RegionLevel(id: 'primary', label: Bilingual(en: 'Primary', fr: 'Primaire'), educationLevel: 'Primary School'),
          RegionLevel(id: 'secondary', label: Bilingual(en: 'Secondary', fr: 'Secondaire'), educationLevel: 'Secondary School'),
          RegionLevel(id: 'high', label: Bilingual(en: 'High school', fr: 'Lycée'), educationLevel: 'High School'),
          RegionLevel(id: 'uni', label: Bilingual(en: 'University', fr: 'Université'), educationLevel: 'University'),
        ],
        exams: [
          RegionOption(id: 'none', label: Bilingual(en: 'No exam this year', fr: 'Pas d’examen cette année')),
          RegionOption(id: 'other', label: Bilingual(en: 'A local / other exam', fr: 'Un examen local')),
        ],
        subjects: _cmEnSubjects,
      ),
    ],
    interests: africaInterests,
  ),
];

RegionPack packById(String? id) {
  return regionPacks.firstWhere(
    (p) => p.id == id,
    orElse: () => regionPacks.first,
  );
}

RegionSystem systemById(RegionPack pack, String? id) {
  return pack.systems.firstWhere(
    (s) => s.id == id,
    orElse: () => pack.systems.first,
  );
}

const examWhenOptions = [
  RegionOption(id: 'year-plus', label: Bilingual(en: 'More than a year away', fr: 'Dans plus d’un an')),
  RegionOption(id: '6-12', label: Bilingual(en: '6 to 12 months', fr: 'Dans 6 à 12 mois')),
  RegionOption(id: '3-6', label: Bilingual(en: '3 to 6 months', fr: 'Dans 3 à 6 mois')),
  RegionOption(id: 'soon', label: Bilingual(en: 'Less than 3 months', fr: 'Dans moins de 3 mois')),
];

const paceOptions = [
  RegionOption(id: 'steady', label: Bilingual(en: 'Slow and steady. Show me why', fr: 'Lent et clair. Montre-moi pourquoi')),
  RegionOption(id: 'balanced', label: Bilingual(en: 'A balanced pace', fr: 'Un rythme équilibré')),
  RegionOption(id: 'fast', label: Bilingual(en: 'Move fast and challenge me', fr: 'Va vite et challenge-moi')),
];

const channelOptions = [
  RegionOption(id: 'voice', label: Bilingual(en: 'I like speaking it out', fr: 'J’aime le dire à voix haute')),
  RegionOption(id: 'type', label: Bilingual(en: 'I prefer typing', fr: 'Je préfère écrire')),
  RegionOption(id: 'mix', label: Bilingual(en: 'Depends where I am', fr: 'Ça dépend d’où je suis')),
];

const examFeelOptions = [
  RegionOption(id: 'calm', label: Bilingual(en: 'I stay calm on exam day', fr: 'Je reste calme le jour J')),
  RegionOption(id: 'settle', label: Bilingual(en: 'Nervous at first, then I settle', fr: 'Nerveux au début, puis ça va')),
  RegionOption(id: 'block', label: Bilingual(en: 'Nerves eat what I actually know', fr: 'Le stress cache ce que je sais')),
  RegionOption(id: 'cram', label: Bilingual(en: 'I cram the night before', fr: 'Je bachote la veille')),
];
