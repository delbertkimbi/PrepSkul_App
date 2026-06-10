/// Resolve a human-readable tutor name from profile + tutor_profiles data.
class TutorDisplayNameUtils {
  TutorDisplayNameUtils._();

  static bool looksLikePersonName(String value) {
    final s = value.trim();
    if (s.length < 2 || s.length > 40) return false;
    if (looksLikeSubjectOrExam(s)) return false;

    final lower = s.toLowerCase();
    const blocked = [
      'committed',
      'motivated',
      'dedicated',
      'passionate',
      'experienced',
      'qualified',
      'hello',
      'i am',
      "i'm",
      'providing',
      'helping',
      'teaching',
      'apps',
      'tutor',
      'unknown',
      'user',
      'educator',
    ];
    if (blocked.any((b) => lower == b || lower.startsWith('$b '))) {
      return false;
    }
    if (lower.contains(' students') || lower.contains(' education')) {
      return false;
    }
    if (lower.endsWith(' tutor')) return false;

    final words = s.split(RegExp(r'\s+'));
    if (words.isEmpty || words.length > 4) return false;

    // Require at least one token that looks like a name part (not all digits/symbols).
    final hasNameToken = words.any(
      (w) => RegExp(r"^[A-Za-z][A-Za-z'\-]{1,}$").hasMatch(w),
    );
    return hasNameToken;
  }

  /// True when text looks like a subject, exam, or program — not a person.
  static bool looksLikeSubjectOrExam(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) return true;

    const markers = [
      'gce',
      'o/l',
      'a/l',
      'fslc',
      'concours',
      'baccalauréat',
      'baccalaureat',
      'ordinary level',
      'advanced level',
      'leaving certificate',
      'first school',
      'sat',
      'dalf',
      'ielts',
      'toefl',
      'ens entrance',
      'medical concours',
      'engineering concours',
      'web development',
      'mobile app',
      'computer science',
      'graphic design',
      'video editing',
      'digital marketing',
      'ui/ux',
      'data science',
      'project management',
      'microsoft office',
      'public speaking',
      'creative writing',
      'music instrument',
      'cameroon gce',
    ];

    if (markers.any((m) => lower.contains(m))) return true;
    if (lower.endsWith(' tutor')) return true;

    // Subject tags often use parentheses, slashes, or ampersands.
    if (RegExp(r'[\(\)/&]').hasMatch(lower)) return true;

    return false;
  }

  static bool isInvalidStoredName(String? value, {String? subject}) {
    if (value == null || value.trim().isEmpty) return true;
    final trimmed = value.trim();
    if (!looksLikePersonName(trimmed)) return true;
    if (subject != null &&
        subject.trim().isNotEmpty &&
        trimmed.toLowerCase() == subject.trim().toLowerCase()) {
      return true;
    }
    final firstSubject = subject?.trim();
    if (firstSubject != null &&
        firstSubject.isNotEmpty &&
        trimmed.toLowerCase().startsWith(firstSubject.toLowerCase())) {
      return true;
    }
    return false;
  }

  static String? extractNameFromBio(String? bio) {
    if (bio == null || bio.isEmpty) return null;
    final patterns = [
      RegExp(
        r"Hello[!.]?\s*(?:my name is|I am|I'm)\s+([A-Za-z][A-Za-z\s'\-]{1,35})",
        caseSensitive: false,
      ),
      RegExp(
        r"(?:my name is|I am|I'm)\s+([A-Za-z][A-Za-z\s'\-]{1,35})",
        caseSensitive: false,
      ),
      RegExp(
        r"(?:Hello[!.]?\s*)?(?:my name is|I am|I'm)\s+([A-Za-z][A-Za-z\s'\-]{1,35})",
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(bio);
      final candidate = match?.group(1)?.trim();
      if (candidate != null && looksLikePersonName(candidate)) {
        return _trimAfterRoleWords(candidate);
      }
    }
    return null;
  }

  static String _trimAfterRoleWords(String candidate) {
    final lower = candidate.toLowerCase();
    for (final stop in [' and ', ' with ', ' a ', ' an ', ' who ', ',']) {
      final idx = lower.indexOf(stop);
      if (idx > 2) return candidate.substring(0, idx).trim();
    }
    return candidate;
  }

  static String? nameFromEmail(String? email) {
    if (email == null || !email.contains('@')) return null;
    final local = email.split('@').first.trim();
    if (local.length < 2) return null;

    const generic = ['info', 'contact', 'admin', 'tutor', 'user', 'test'];
    if (generic.contains(local.toLowerCase())) return null;

    final parts = local
        .replaceAll(RegExp(r'[._\-+\d]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((p) => p.length >= 2)
        .toList();
    if (parts.isEmpty) return null;

    final candidate = parts
        .map(
          (p) => p.length == 1
              ? p.toUpperCase()
              : '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}',
        )
        .join(' ');

    if (looksLikePersonName(candidate)) return candidate;
    return null;
  }

  static String resolve(
    Map<String, dynamic> tutor, [
    Map<String, dynamic>? profile,
  ]) {
    final subjects = tutor['subjects'] ?? tutor['specializations'];
    final firstSubject = subjects is List && subjects.isNotEmpty
        ? subjects.first.toString().trim()
        : null;

    final fromProfile = profile?['full_name']?.toString().trim();
    if (!isInvalidStoredName(fromProfile, subject: firstSubject)) {
      return fromProfile!;
    }

    final ps = tutor['personal_statement']?.toString() ??
        tutor['bio']?.toString() ??
        tutor['motivation']?.toString();
    final fromBio = extractNameFromBio(ps);
    if (fromBio != null) return fromBio;

    final fromEmail = nameFromEmail(profile?['email']?.toString());
    if (fromEmail != null) return fromEmail;

    final userId = tutor['user_id']?.toString() ??
        tutor['id']?.toString() ??
        '';
    if (userId.length >= 4) {
      return 'Tutor ${userId.substring(0, 4).toUpperCase()}';
    }
    return 'PrepSkul Tutor';
  }

  /// Short label for list cards (first + last when 3+ parts).
  static String cardLabel(
    Map<String, dynamic> tutor, [
    Map<String, dynamic>? profile,
  ]) {
    final full = resolve(tutor, profile);
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.length > 2) {
      return '${parts[0]} ${parts[1]}';
    }
    return full;
  }
}
