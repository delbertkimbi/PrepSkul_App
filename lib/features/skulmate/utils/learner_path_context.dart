/// Gates exam/framework labels to the learner's actual class and exam path.
class LearnerPathContext {
  LearnerPathContext._();

  static LearnerPathProfile? fromParentLearner(Map<String, dynamic>? row) {
    if (row == null) return null;
    return LearnerPathProfile(
      educationLevel: row['education_level']?.toString(),
      classLevel: row['class_level']?.toString(),
      examType: row['exam_type']?.toString(),
      specificExam: row['specific_exam']?.toString(),
      learningPath: row['learning_path']?.toString(),
    );
  }

  static bool isExamTrackLearner(LearnerPathProfile? profile) {
    if (profile == null) return false;

    final path = _norm(profile.learningPath);
    if (path.contains('skill') ||
        path.contains('hobby') ||
        path.contains('university')) {
      return false;
    }

    final examBlob = [profile.examType, profile.specificExam]
        .map(_norm)
        .where((s) => s.isNotEmpty)
        .join(' ');
    if (examBlob.isNotEmpty && !_nonExamValues.contains(examBlob)) {
      if (RegExp(
        r'gce|waec|bepc|probatoire|bac|sat|ielts|toefl|o.?level|a.?level|jamb|neco',
      ).hasMatch(examBlob)) {
        return true;
      }
    }

    final level = _norm(profile.classLevel ?? profile.educationLevel);
    if (level.isEmpty) return false;

    return RegExp(
      r'form\s*[4-7]|upper\s*six|lower\s*six|u6|l6|terminale|première|premiere|seconde',
    ).hasMatch(level) ||
        RegExp(r'exam|examen|bac|gce|waec').hasMatch(level);
  }

  static bool frameworkMatchesProfile(
    String frameworkId,
    LearnerPathProfile? profile,
  ) {
    if (!isExamTrackLearner(profile)) return false;
    if (frameworkId == 'open_learning') return false;

    final examBlob = [
      profile?.examType,
      profile?.specificExam,
      profile?.classLevel,
      profile?.educationLevel,
    ].map(_norm).where((s) => s.isNotEmpty).join(' ');

    final patterns = _frameworkPatterns[frameworkId];
    if (patterns == null) return true;
    if (examBlob.isEmpty) return true;
    return patterns.any((p) => p.hasMatch(examBlob));
  }

  static String? learnerContextLine(LearnerPathProfile? profile, bool french) {
    if (profile == null) return null;

    final classLevel = profile.classLevel?.trim();
    if (classLevel != null && classLevel.isNotEmpty) {
      return french ? 'Niveau : $classLevel' : 'Level: $classLevel';
    }

    final education = profile.educationLevel?.trim();
    if (education != null && education.isNotEmpty) {
      return french ? 'Parcours : $education' : 'Path: $education';
    }

    if (_norm(profile.learningPath).contains('skill')) {
      return french ? 'Apprentissage libre' : 'Skills learning';
    }
    return null;
  }

  static String readinessTitle(LearnerPathProfile? profile, bool french) {
    if (isExamTrackLearner(profile)) {
      return french
          ? 'Préparation (estimation)'
          : 'Exam readiness (estimate)';
    }
    return french ? 'Progression d\'apprentissage' : 'Learning progress';
  }

  static String readinessDisclaimer(LearnerPathProfile? profile, bool french) {
    if (isExamTrackLearner(profile)) {
      return french
          ? 'Basé sur SkulMate — pas un score officiel d\'examen.'
          : 'Based on SkulMate games — not an official exam score.';
    }
    return french
        ? 'Basé sur les jeux SkulMate de votre enfant.'
        : 'Based on your child\'s SkulMate revision games.';
  }

  static String? parentFrameworkLabel({
    required String? frameworkId,
    required LearnerPathProfile? profile,
    required bool french,
  }) {
    if (frameworkId == null || frameworkId.isEmpty) return null;
    if (!frameworkMatchesProfile(frameworkId, profile)) return null;

    const labels = {
      'cm_gce_ol': ('GCE O Level', 'GCE niveau O'),
      'cm_gce_al': ('GCE A Level', 'GCE niveau A'),
      'cm_francophone': ('Francophone secondary', 'Secondaire francophone'),
      'waec': ('WAEC', 'WAEC'),
      'open_learning': ('Open learning', 'Apprentissage libre'),
      'steam': ('STEAM', 'STEAM'),
    };
    final hit = labels[frameworkId];
    if (hit == null) return null;
    return french ? hit.$2 : hit.$1;
  }

  static String _norm(String? value) => (value ?? '').toLowerCase().trim();

  static const _nonExamValues = {
    '',
    'none',
    'n/a',
    'na',
    'not applicable',
    'no exam',
    'general',
    'skills',
    'hobby',
    'university',
  };

  static final Map<String, List<RegExp>> _frameworkPatterns = {
    'cm_gce_ol': [
      RegExp(r'gce.*o|ordinary|o level|o-level|form\s*5'),
    ],
    'cm_gce_al': [
      RegExp(r'gce.*a|advanced|a level|a-level|upper six|lower six|u6|l6'),
    ],
    'waec': [RegExp(r'waec|neco|jamb')],
    'cm_francophone': [
      RegExp(r'bepc|probatoire|francophone|bac|seconde|première|premiere'),
    ],
    'steam': [RegExp(r'steam|skill|coding|tech')],
  };
}

class LearnerPathProfile {
  final String? educationLevel;
  final String? classLevel;
  final String? examType;
  final String? specificExam;
  final String? learningPath;

  const LearnerPathProfile({
    this.educationLevel,
    this.classLevel,
    this.examType,
    this.specificExam,
    this.learningPath,
  });
}
