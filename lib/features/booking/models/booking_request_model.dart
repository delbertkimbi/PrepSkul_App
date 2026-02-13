import 'package:intl/intl.dart';

/// BookingRequest Model
///
/// Represents a booking request from student/parent to tutor
/// Status: pending, approved, rejected, modified
class BookingRequest {
  final String id;
  final String studentId;
  final String tutorId;
  final int frequency; // Sessions per week
  final List<String> days; // e.g., ['Monday', 'Wednesday']
  final Map<String, String> times; // e.g., {'Monday': '4:00 PM'}
  final String location; // online, onsite, hybrid
  final String? address;
  final String? locationDescription; // Brief description for onsite/hybrid
  final String paymentPlan; // monthly, biweekly, weekly
  final double monthlyTotal;
  final String status; // pending, approved, rejected
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? tutorResponse; // Optional message from tutor
  final String? rejectionReason;
  final bool hasConflict;
  final String? conflictDetails;
  
  // Payment status (loaded upfront to avoid flickering)
  final String? paymentStatus; // pending, paid, failed, expired, cancelled
  final String? paymentRequestId; // ID of the payment request

  // Trial Session specific fields
  final bool isTrial;
  final String? subject;
  final int? durationMinutes;
  final String? trialGoal;
  final String? learnerChallenges;
  final DateTime? scheduledDate;

  // Student/Parent info (denormalized for easy display)
  final String studentName;
  final String? studentAvatarUrl;
  final String studentType; // student or parent

  // Multi-learner support (for parent bookings)
  final List<String>? learnerLabels; // Array of learner names when parent books for multiple children
  final Map<String, Map<String, dynamic>>? learnerAcceptanceStatus; // Per-learner acceptance status: {"Emma": {"status": "accepted", "reason": null, "responded_at": "..."}}
  /// Per-learner subjects (learner name -> list of subjects). Set when parent/learner selects subjects in booking flow.
  final Map<String, List<String>>? learnerSubjects;

  // Transportation cost (for onsite sessions)
  final double? estimatedTransportationCost; // Estimated transportation cost per session

  // Tutor info (denormalized for easy display)
  final String tutorName;
  final String? tutorAvatarUrl;
  final double tutorRating;
  final bool tutorIsVerified;

  BookingRequest({
    required this.id,
    required this.studentId,
    required this.tutorId,
    required this.frequency,
    required this.days,
    required this.times,
    required this.location,
    this.address,
    this.locationDescription,
    required this.paymentPlan,
    required this.monthlyTotal,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.tutorResponse,
    this.rejectionReason,
    this.hasConflict = false,
    this.conflictDetails,
    this.paymentStatus,
    this.paymentRequestId,
    this.isTrial = false,
    this.subject,
    this.durationMinutes,
    this.trialGoal,
    this.learnerChallenges,
    this.scheduledDate,
    required this.studentName,
    this.studentAvatarUrl,
    required this.studentType,
    this.learnerLabels,
    this.learnerAcceptanceStatus,
    this.learnerSubjects,
    this.estimatedTransportationCost,
    required this.tutorName,
    this.tutorAvatarUrl,
    required this.tutorRating,
    required this.tutorIsVerified,
  });

  /// Parse learner_labels from API (handles List<dynamic>, JSONB array)
  static List<String>? _parseLearnerLabels(dynamic value) {
    if (value == null) return null;
    if (value is! List) return null;
    final list = value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    return list.isEmpty ? null : list;
  }

  /// Parse learner_subjects from API (JSONB: {"Learner Name": ["Math", "Physics"]})
  static Map<String, List<String>>? _parseLearnerSubjects(dynamic value) {
    if (value == null || value is! Map) return null;
    final map = <String, List<String>>{};
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final val = entry.value;
      if (val is List) {
        map[key] = val.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      }
    }
    return map.isEmpty ? null : map;
  }

  /// Create from Supabase JSON (Booking Requests table)
  factory BookingRequest.fromJson(Map<String, dynamic> json) {
    return BookingRequest(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      tutorId: json['tutor_id'] as String,
      frequency: json['frequency'] as int,
      days: List<String>.from(json['days'] as List),
      times: Map<String, String>.from(json['times'] as Map),
      location: json['location'] as String,
      address: json['address'] as String?,
      locationDescription: json['location_description'] as String?,
      paymentPlan: json['payment_plan'] as String,
      monthlyTotal: (json['monthly_total'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      tutorResponse: json['tutor_response'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      hasConflict: json['has_conflict'] as bool? ?? false,
      conflictDetails: json['conflict_details'] as String?,
      paymentStatus: json['payment_status'] as String?,
      paymentRequestId: json['payment_request_id'] as String?,
      isTrial: false,
      studentName: json['student_name'] as String,
      studentAvatarUrl: json['student_avatar_url'] as String?,
      studentType: json['student_type'] as String,
      learnerLabels: _parseLearnerLabels(json['learner_labels']),
      learnerAcceptanceStatus: json['learner_acceptance_status'] != null
          ? Map<String, Map<String, dynamic>>.from(
              (json['learner_acceptance_status'] as Map).map(
                (key, value) => MapEntry(
                  key.toString(),
                  Map<String, dynamic>.from(value as Map),
                ),
              ),
            )
          : null,
      learnerSubjects: _parseLearnerSubjects(json['learner_subjects']),
      estimatedTransportationCost: json['estimated_transportation_cost'] != null
          ? (json['estimated_transportation_cost'] as num).toDouble()
          : null,
      tutorName: json['tutor_name'] as String,
      tutorAvatarUrl: json['tutor_avatar_url'] as String?,
      tutorRating: (json['tutor_rating'] as num).toDouble(),
      tutorIsVerified: json['tutor_is_verified'] as bool,
    );
  }

  /// Create from Supabase JSON (Trial Sessions table)
  factory BookingRequest.fromTrialSession(
    Map<String, dynamic> json,
    Map<String, dynamic> studentProfile,
    Map<String, dynamic>? tutorProfile,
  ) {
    DateTime date;
    try {
      date = DateTime.parse(json['scheduled_date'] as String);
    } catch (e) {
      date = DateTime.now(); // Fallback
    }
    
    final dayName = DateFormat('EEEE').format(date);
    final time = json['scheduled_time'] as String? ?? 'Time pending';
    
    return BookingRequest(
      id: json['id'] as String,
      studentId: json['learner_id'] as String, // Mapped from learner_id
      tutorId: json['tutor_id'] as String,
      frequency: 1,
      days: [dayName],
      times: {dayName: time},
      location: json['location'] as String? ?? 'online',
      address: json['address'] as String?,
      locationDescription: json['location_description'] as String?,
      paymentPlan: 'Trial Session',
      monthlyTotal: (json['price'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String,
      createdAt: DateTime.tryParse(json['created_at'] as String) ?? DateTime.now(),
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'] as String)
          : null,
      // Trial specific mappings
      isTrial: true,
      subject: json['subject'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      trialGoal: json['trial_goal'] as String?,
      learnerChallenges: json['learner_challenges'] as String?,
      scheduledDate: date,
      // Student info from joined profile - prefer full_name, then email, then generic fallback
      // Never use "User" - always show meaningful name or email
      studentName: _extractStudentNameFromProfile(studentProfile),
      studentAvatarUrl: studentProfile['avatar_url'] ?? studentProfile['profile_photo_url'],
      studentType: studentProfile['user_type'] ?? 'learner',
      // Multi-learner: from trial_sessions.learner_labels or learner_label (single)
      learnerLabels: _parseLearnerLabels(json['learner_labels']) ??
          (json['learner_label'] != null && (json['learner_label'] as String).trim().isNotEmpty
              ? [(json['learner_label'] as String).trim()]
              : null),
      learnerSubjects: _parseLearnerSubjects(json['learner_subjects']),
      learnerAcceptanceStatus: null,
      // Tutor info
      tutorName: tutorProfile?['full_name'] ?? 'Tutor',
      tutorAvatarUrl: tutorProfile?['avatar_url'] ?? tutorProfile?['profile_photo_url'],
      tutorRating: 0.0, 
      tutorIsVerified: false,
    );
  }

  /// Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'student_id': studentId,
      'tutor_id': tutorId,
      'frequency': frequency,
      'days': days,
      'times': times,
      'location': location,
      'address': address,
      'location_description': locationDescription,
      'payment_plan': paymentPlan,
      'monthly_total': monthlyTotal,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'tutor_response': tutorResponse,
      'rejection_reason': rejectionReason,
      'has_conflict': hasConflict,
      'conflict_details': conflictDetails,
      'student_name': studentName,
      'student_avatar_url': studentAvatarUrl,
      'student_type': studentType,
      if (learnerLabels != null) 'learner_labels': learnerLabels,
      if (learnerSubjects != null) 'learner_subjects': learnerSubjects,
      if (estimatedTransportationCost != null) 'estimated_transportation_cost': estimatedTransportationCost,
      'tutor_name': tutorName,
      'tutor_avatar_url': tutorAvatarUrl,
      'tutor_rating': tutorRating,
      'tutor_is_verified': tutorIsVerified,
    };
    
    // For trial sessions, include learner_id and trial-specific fields
    if (isTrial) {
      json['is_trial'] = true;
      json['learner_id'] = studentId; // For trial sessions, studentId is the learner_id
      json['subject'] = subject;
      json['duration_minutes'] = durationMinutes;
      json['trial_goal'] = trialGoal;
      json['learner_challenges'] = learnerChallenges;
      if (scheduledDate != null) {
        json['scheduled_date'] = scheduledDate!.toIso8601String().split('T')[0];
      }
    }
    
    return json;
  }

  /// Create a copy with updated fields
  BookingRequest copyWith({
    String? status,
    DateTime? respondedAt,
    String? tutorResponse,
    String? rejectionReason,
  }) {
    return BookingRequest(
      id: id,
      studentId: studentId,
      tutorId: tutorId,
      frequency: frequency,
      days: days,
      times: times,
      location: location,
      address: address,
      paymentPlan: paymentPlan,
      monthlyTotal: monthlyTotal,
      status: status ?? this.status,
      createdAt: createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      tutorResponse: tutorResponse ?? this.tutorResponse,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      hasConflict: hasConflict,
      conflictDetails: conflictDetails,
      studentName: studentName,
      studentAvatarUrl: studentAvatarUrl,
      studentType: studentType,
      learnerLabels: learnerLabels,
      learnerAcceptanceStatus: learnerAcceptanceStatus,
      learnerSubjects: learnerSubjects,
      estimatedTransportationCost: estimatedTransportationCost,
      tutorName: tutorName,
      tutorAvatarUrl: tutorAvatarUrl,
      tutorRating: tutorRating,
      tutorIsVerified: tutorIsVerified,
      isTrial: isTrial,
      subject: subject,
      durationMinutes: durationMinutes,
      trialGoal: trialGoal,
      learnerChallenges: learnerChallenges,
      scheduledDate: scheduledDate,
    );
  }

  /// Extract student name from profile, with proper fallbacks
  /// Never returns "User" - always returns meaningful identifier
  static String _extractStudentNameFromProfile(Map<String, dynamic> studentProfile) {
    // Handle null or empty profile - check if it has any meaningful data
    final hasFullName = studentProfile['full_name'] != null && 
                       studentProfile['full_name'].toString().trim().isNotEmpty &&
                       studentProfile['full_name'].toString().toLowerCase() != 'user' &&
                       studentProfile['full_name'].toString().toLowerCase() != 'null';
    final hasEmail = studentProfile['email'] != null && 
                    studentProfile['email'].toString().trim().isNotEmpty &&
                    studentProfile['email'].toString().toLowerCase() != 'null';
    
    // If profile is truly empty (no name, no email), return generic based on type
    if (!hasFullName && !hasEmail) {
      final userType = studentProfile['user_type'] as String? ?? 'learner';
      return userType == 'parent' ? 'Parent' : 'Student';
    }
    
    // Try full_name first
    if (hasFullName) {
      final fullName = studentProfile['full_name'].toString().trim();
      if (fullName.isNotEmpty && 
          fullName.toLowerCase() != 'user' &&
          fullName.toLowerCase() != 'null') {
        return fullName;
      }
    }
    
    // Try email as fallback
    if (hasEmail) {
      final email = studentProfile['email'].toString().trim();
      // Extract name from email if possible (before @)
      final emailName = email.split('@').first.trim();
      if (emailName.isNotEmpty && 
          emailName.toLowerCase() != 'user' &&
          emailName.toLowerCase() != 'null') {
        // Capitalize first letter for better display
        if (emailName.length > 1) {
          return emailName[0].toUpperCase() + emailName.substring(1);
        }
        return emailName;
      }
    }
    
    // Final fallback - determine type and return appropriate default
    final userType = studentProfile['user_type'] as String? ?? 'learner';
    return userType == 'parent' ? 'Parent' : 'Student';
  }

  /// Check if request is pending
  bool get isPending => status == 'pending';

  /// Check if request is approved
  bool get isApproved => status == 'approved';

  /// Check if request is rejected
  bool get isRejected => status == 'rejected';

  /// Get formatted time range for display
  String getTimeRange() {
    if (times.isEmpty) return 'Not set';

    List<String> formatted = [];
    for (final raw in times.values) {
      formatted.add(_formatTimeString(raw));
    }
    return formatted.join(', ');
  }

  /// Get days summary
  String getDaysSummary() {
    return days.join(', ');
  }

  /// Check if this is a multi-learner booking
  bool get isMultiLearner => learnerLabels != null && learnerLabels!.isNotEmpty;

  /// Get acceptance status for a specific learner
  String? getLearnerStatus(String learnerName) {
    if (learnerAcceptanceStatus == null) return null;
    return learnerAcceptanceStatus![learnerName]?['status'] as String?;
  }

  /// Get rejection reason for a specific learner
  String? getLearnerRejectionReason(String learnerName) {
    if (learnerAcceptanceStatus == null) return null;
    return learnerAcceptanceStatus![learnerName]?['reason'] as String?;
  }

  /// Get subjects for a specific learner (from per-learner selection or single subject for trial)
  List<String> getLearnerSubjects(String learnerName) {
    if (learnerSubjects != null && learnerSubjects![learnerName] != null && learnerSubjects![learnerName]!.isNotEmpty) {
      return learnerSubjects![learnerName]!;
    }
    if (subject != null && subject!.trim().isNotEmpty) return [subject!.trim()];
    return [];
  }

  /// Check if all learners have been responded to (accepted or declined)
  bool get allLearnersResponded {
    if (!isMultiLearner) return true; // Not a multi-learner booking
    if (learnerAcceptanceStatus == null) return false;
    
    for (final learnerName in learnerLabels!) {
      final status = getLearnerStatus(learnerName);
      if (status == null || status == 'pending') {
        return false;
      }
    }
    return true;
  }

  /// Get count of accepted learners
  int get acceptedLearnersCount {
    if (!isMultiLearner || learnerAcceptanceStatus == null) return 0;
    
    int count = 0;
    for (final learnerName in learnerLabels!) {
      if (getLearnerStatus(learnerName) == 'accepted') {
        count++;
      }
    }
    return count;
  }

  /// Get count of declined learners
  int get declinedLearnersCount {
    if (!isMultiLearner || learnerAcceptanceStatus == null) return 0;
    
    int count = 0;
    for (final learnerName in learnerLabels!) {
      if (getLearnerStatus(learnerName) == 'declined') {
        count++;
      }
    }
    return count;
  }

  /// Try to format raw time strings (e.g. "09:00:00") into user-friendly "9:00 AM"
  String _formatTimeString(String raw) {
    try {
      final trimmed = raw.trim();
      DateTime parsed;

      if (RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(trimmed)) {
        parsed = DateFormat('HH:mm:ss').parse(trimmed);
      } else if (RegExp(r'^\d{2}:\d{2}$').hasMatch(trimmed)) {
        parsed = DateFormat('HH:mm').parse(trimmed);
      } else {
        // Already formatted like "4:00 PM" or some custom text
        return trimmed;
      }

      return DateFormat.jm().format(parsed); // e.g. "9:00 AM"
    } catch (_) {
      return raw;
    }
  }
}
