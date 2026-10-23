/// Search only tutor-published teaching fields, with explicit subject aliases.
class TutorSearch {
  static String normalize(String value) {
    var text = value.toLowerCase();
    const accents = {
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'à': 'a',
      'â': 'a',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ù': 'u',
      'û': 'u',
      'ç': 'c',
    };
    accents.forEach((a, b) => text = text.replaceAll(a, b));
    text = text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    const aliases = {
      'math': 'mathematics',
      'maths': 'mathematics',
      'mathematic': 'mathematics',
      'mathematiques': 'mathematics',
      'mathematique': 'mathematics',
      'matematics': 'mathematics',
      'anglais': 'english',
      'francais': 'french',
      'physique': 'physics',
      'chimie': 'chemistry',
      'biologie': 'biology',
      'computing': 'computer',
      'ict': 'computer',
      'informatique': 'computer',
    };
    return text
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => aliases[w] ?? w)
        .join(' ')
        .replaceAll('o level', 'ordinary level')
        .replaceAll('a level', 'advanced level');
  }

  static bool matches(Map<String, dynamic> tutor, String query) {
    final terms = normalize(query)
        .split(' ')
        .where(
          (w) =>
              w.isNotEmpty &&
              !{
                'tutor',
                'teacher',
                'teach',
                'for',
                'in',
                'the',
                'a',
                'an',
              }.contains(w),
        )
        .toList();
    if (terms.isEmpty) return true;
    final haystack = normalize(
      [
        for (final key in [
          'full_name',
          'subjects',
          'bio',
          'personal_statement',
          'education_level',
          'education_levels',
          'exam_type',
          'exams',
          'exam_preparation',
          'specializations',
          'curriculum',
          'curriculums',
          'teaching_levels',
          'city',
          'country',
        ])
          if (tutor[key] != null)
            tutor[key] is List
                ? (tutor[key] as List).join(' ')
                : tutor[key].toString(),
      ].join(' '),
    );
    final words = haystack.split(' ');
    return terms.every(
      (term) => words.any(
        (word) =>
            word == term ||
            word.startsWith(term) ||
            (term.length >= 5 && _oneEdit(term, word)),
      ),
    );
  }

  static bool _oneEdit(String a, String b) {
    if ((a.length - b.length).abs() > 1) return false;
    int i = 0, j = 0, edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length >= b.length) i++;
      if (b.length >= a.length) j++;
    }
    return edits + (a.length - i) + (b.length - j) <= 1;
  }
}
