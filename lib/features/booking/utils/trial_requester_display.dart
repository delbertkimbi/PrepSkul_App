import '../models/booking_request_model.dart';

/// Consistent requester / learner labels for tutor-facing trial & booking UI.
class TrialRequesterDisplay {
  TrialRequesterDisplay._();

  static bool isGenericName(String? name) {
    if (name == null || name.trim().isEmpty) return true;
    final lower = name.trim().toLowerCase();
    return lower == 'student' ||
        lower == 'parent' ||
        lower == 'user' ||
        lower == 'null' ||
        lower == 'learner';
  }

  static bool isParentBooking({
    required String studentType,
    String? parentId,
    String? learnerId,
    List<String>? learnerLabels,
  }) {
    final type = studentType.toLowerCase();
    if (type == 'parent') return true;
    if (parentId != null &&
        parentId.isNotEmpty &&
        learnerId != null &&
        learnerId.isNotEmpty &&
        parentId != learnerId) {
      return true;
    }
    if (learnerLabels != null && learnerLabels.isNotEmpty && type != 'learner') {
      return true;
    }
    return false;
  }

  static String roleLabel(String studentType, {bool? isParent}) {
    final parent = isParent ?? studentType.toLowerCase() == 'parent';
    return parent ? 'Parent' : 'Student';
  }

  static String nameFromProfile(Map<String, dynamic>? profile) {
    if (profile == null || profile.isEmpty) return 'Student';
    final fullName = profile['full_name'] as String?;
    if (!isGenericName(fullName)) return fullName!.trim();

    final email = profile['email'] as String?;
    if (email != null && email.contains('@')) {
      final local = email.split('@').first.trim();
      if (!isGenericName(local)) {
        return local[0].toUpperCase() + local.substring(1);
      }
    }

    final userType = profile['user_type'] as String?;
    if (userType == 'parent') return 'Parent';
    return 'Student';
  }

  static String resolveRequesterName({
    required String storedName,
    Map<String, dynamic>? requesterProfile,
    Map<String, dynamic>? parentProfile,
    Map<String, dynamic>? learnerProfile,
    required bool isParent,
  }) {
    if (!isGenericName(storedName)) return storedName.trim();

    for (final profile in [requesterProfile, parentProfile, learnerProfile]) {
      final name = nameFromProfile(profile);
      if (!isGenericName(name)) return name;
    }

    return isParent ? 'Parent' : 'Student';
  }

  static String resolveStudentTypeFromTrialJson(
    Map<String, dynamic> json,
    Map<String, dynamic> displayProfile,
  ) {
    final parentId = json['parent_id'] as String?;
    final learnerId = json['learner_id'] as String?;
    if (parentId != null &&
        parentId.isNotEmpty &&
        learnerId != null &&
        learnerId.isNotEmpty &&
        parentId != learnerId) {
      return 'parent';
    }

    final profileType = (displayProfile['user_type'] as String?)?.toLowerCase();
    if (profileType == 'parent') return 'parent';
    if (profileType == 'learner' || profileType == 'student') return 'learner';

    final labels = json['learner_labels'] ?? json['learner_label'];
    if (labels != null && parentId != null && parentId.isNotEmpty) {
      return 'parent';
    }

    return 'learner';
  }

  static ({String name, String role, List<String> learners}) forBookingRequest(
    BookingRequest request,
  ) {
    final isParent = isParentBooking(
      studentType: request.studentType,
      learnerId: request.studentId,
      learnerLabels: request.learnerLabels,
    );
    final name = resolveRequesterName(
      storedName: request.studentName,
      isParent: isParent,
    );
    return (
      name: name,
      role: roleLabel(request.studentType, isParent: isParent),
      learners: request.learnerLabels ?? const [],
    );
  }

  static String? primaryLearnerName(BookingRequest request) {
    final labels = request.learnerLabels;
    if (labels == null || labels.isEmpty) return null;
    return labels.first;
  }
}
