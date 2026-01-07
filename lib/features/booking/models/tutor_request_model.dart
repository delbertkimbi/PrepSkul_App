/// Model for tutor requests (custom tutor not available on platform)
class TutorRequest {
  final String id;
  final String requesterId;
  final List<String> subjects;
  final String educationLevel;
  final String? specificRequirements;
  final String teachingMode;
  final int budgetMin;
  final int budgetMax;
  final String? tutorGender;
  final String? tutorQualification;
  final List<String> preferredDays;
  final String preferredTime;
  final String location;
  final String? locationDescription;
  final String urgency;
  final String? additionalNotes;
  final String status; // pending, in_progress, matched, closed
  final String? matchedTutorId;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? matchedAt;
  final DateTime? updatedAt;

  // Denormalized user data
  final String? requesterName;
  final String? requesterPhone;
  final String? requesterType;

  TutorRequest({
    required this.id,
    required this.requesterId,
    required this.subjects,
    required this.educationLevel,
    this.specificRequirements,
    required this.teachingMode,
    required this.budgetMin,
    required this.budgetMax,
    this.tutorGender,
    this.tutorQualification,
    required this.preferredDays,
    required this.preferredTime,
    required this.location,
    this.locationDescription,
    required this.urgency,
    this.additionalNotes,
    required this.status,
    this.matchedTutorId,
    this.adminNotes,
    required this.createdAt,
    this.matchedAt,
    this.updatedAt,
    this.requesterName,
    this.requesterPhone,
    this.requesterType,
  });

  factory TutorRequest.fromJson(Map<String, dynamic> json) {
    return TutorRequest(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      subjects: List<String>.from(json['subjects'] as List),
      educationLevel: json['education_level'] as String,
      specificRequirements: json['specific_requirements'] as String?,
      teachingMode: json['teaching_mode'] as String,
      budgetMin: json['budget_min'] as int,
      budgetMax: json['budget_max'] as int,
      tutorGender: json['tutor_gender'] as String?,
      tutorQualification: json['tutor_qualification'] as String?,
      preferredDays: List<String>.from(json['preferred_days'] as List),
      preferredTime: json['preferred_time'] as String,
      location: json['location'] as String,
      locationDescription: json['location_description'] as String?,
      urgency: json['urgency'] as String,
      additionalNotes: json['additional_notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      matchedTutorId: json['matched_tutor_id'] as String?,
      adminNotes: json['admin_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      matchedAt: json['matched_at'] != null
          ? DateTime.parse(json['matched_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      requesterName: json['requester_name'] as String?,
      requesterPhone: json['requester_phone'] as String?,
      requesterType: json['requester_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester_id': requesterId,
      'subjects': subjects,
      'education_level': educationLevel,
      'specific_requirements': specificRequirements,
      'teaching_mode': teachingMode,
      'budget_min': budgetMin,
      'budget_max': budgetMax,
      'tutor_gender': tutorGender,
      'tutor_qualification': tutorQualification,
      'preferred_days': preferredDays,
      'preferred_time': preferredTime,
      'location': location,
      'location_description': locationDescription,
      'urgency': urgency,
      'additional_notes': additionalNotes,
      'status': status,
      'matched_tutor_id': matchedTutorId,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'matched_at': matchedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'requester_name': requesterName,
      'requester_phone': requesterPhone,
      'requester_type': requesterType,
    };
  }

  // Helper getters
  bool get isPending => status == 'pending';
  bool get isInProgress => status == 'in_progress';
  bool get isMatched => status == 'matched';
  bool get isClosed => status == 'closed';

  String get formattedBudget => '$budgetMin - $budgetMax XAF';
  String get formattedSubjects => subjects.join(', ');
  String get formattedDays => preferredDays.join(', ');

  /// Get formatted education level without "(O-Level)" or "(A-Level)" suffixes
  String get formattedEducationLevel {
    return educationLevel
        .replaceAll(' (O-Level)', '')
        .replaceAll(' (A-Level)', '')
        .replaceAll('(O-Level)', '')
        .replaceAll('(A-Level)', '');
  }

  String get urgencyLabel {
    switch (urgency) {
      case 'urgent':
        return 'Urgent';
      case 'normal':
        return 'Normal';
      case 'flexible':
        return 'Flexible';
      default:
        return urgency;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'matched':
        return 'Matched';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }
}