/// Resolves tutor-facing display fields for trial session requesters.
class TrialRequesterDisplay {
  TrialRequesterDisplay._();

  static bool _hasMeaningfulProfile(Map<String, dynamic> profile) {
    final fullName = profile['full_name']?.toString().trim() ?? '';
    final email = profile['email']?.toString().trim() ?? '';
    final hasName = fullName.isNotEmpty &&
        fullName.toLowerCase() != 'user' &&
        fullName.toLowerCase() != 'null' &&
        fullName.toLowerCase() != 'student' &&
        fullName.toLowerCase() != 'parent';
    final hasEmail = email.isNotEmpty &&
        email.toLowerCase() != 'user' &&
        email.toLowerCase() != 'null';
    return hasName || hasEmail;
  }

  static Map<String, dynamic>? _normalizeProfile(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    final profile = Map<String, dynamic>.from(raw);
    return _hasMeaningfulProfile(profile) ? profile : null;
  }

  /// Profile map used for [BookingRequest.fromTrialSession] display fields.
  static Map<String, dynamic> resolveDisplayProfile(
    Map<String, dynamic> trialJson, {
    Map<String, dynamic>? requesterProfile,
    Map<String, dynamic>? learnerProfile,
    Map<String, dynamic>? parentProfile,
  }) {
    final parentId = trialJson['parent_id'] as String?;
    final isParentBooking = parentId != null && parentId.isNotEmpty;

    final requester = _normalizeProfile(requesterProfile);
    final parent = _normalizeProfile(parentProfile);
    final learner = _normalizeProfile(learnerProfile);

    if (isParentBooking) {
      if (parent != null) {
        return {...parent, 'user_type': 'parent'};
      }
      if (requester != null) {
        return {...requester, 'user_type': 'parent'};
      }
      return {'user_type': 'parent'};
    }

    if (requester != null) return requester;
    if (learner != null) return learner;
    return {'user_type': 'learner'};
  }

  /// Name + avatar for tutor session cards (sync; uses pre-batched profiles).
  static Map<String, Object?> resolveSessionCardFields(
    Map<String, dynamic> trialJson,
    Map<String, Map<String, dynamic>> profilesById,
  ) {
    final parentId = trialJson['parent_id'] as String?;
    final requesterId = trialJson['requester_id'] as String?;
    final learnerId = trialJson['learner_id'] as String?;
    final isParentBooking = parentId != null && parentId.isNotEmpty;

    String studentName = isParentBooking ? 'Parent' : 'Student';
    String? studentAvatar;
    String? requesterType = isParentBooking ? 'parent' : null;

    void applyProfile(Map<String, dynamic>? prof) {
      if (prof == null) return;
      requesterType ??= prof['user_type'] as String?;
      final fullName = prof['full_name'] as String?;
      if (fullName != null &&
          fullName.trim().isNotEmpty &&
          fullName.toLowerCase() != 'user' &&
          fullName.toLowerCase() != 'null' &&
          fullName.toLowerCase() != 'student' &&
          fullName.toLowerCase() != 'parent') {
        studentName = fullName.trim();
      } else {
        final email = prof['email'] as String?;
        if (email != null && email.trim().isNotEmpty) {
          final emailName = email.split('@').first.trim();
          if (emailName.isNotEmpty &&
              emailName.toLowerCase() != 'user' &&
              emailName.toLowerCase() != 'student' &&
              emailName.toLowerCase() != 'parent') {
            studentName =
                emailName[0].toUpperCase() + emailName.substring(1);
          }
        }
      }
      studentAvatar ??= prof['avatar_url'] as String?;
    }

    if (isParentBooking && parentId != null && parentId.isNotEmpty) {
      applyProfile(profilesById[parentId]);
      requesterType = 'parent';
    }

    if (studentName == 'Parent' || studentName == 'Student') {
      if (requesterId != null && requesterId.isNotEmpty) {
        applyProfile(profilesById[requesterId]);
      }
    }

    if (!isParentBooking &&
        (studentName == 'Student' || studentName == 'Parent') &&
        learnerId != null &&
        learnerId.isNotEmpty) {
      applyProfile(profilesById[learnerId]);
    }

    if (isParentBooking) {
      requesterType = 'parent';
    }

    return {
      'student_name': studentName,
      'student_avatar_url': studentAvatar,
      'requester_type': requesterType,
    };
  }
}
