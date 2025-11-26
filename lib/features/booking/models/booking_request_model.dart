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
    this.isTrial = false,
    this.subject,
    this.durationMinutes,
    this.trialGoal,
    this.learnerChallenges,
    this.scheduledDate,
    required this.studentName,
    this.studentAvatarUrl,
    required this.studentType,
    required this.tutorName,
    this.tutorAvatarUrl,
    required this.tutorRating,
    required this.tutorIsVerified,
  });

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
      isTrial: false,
      studentName: json['student_name'] as String,
      studentAvatarUrl: json['student_avatar_url'] as String?,
      studentType: json['student_type'] as String,
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
      studentName: (studentProfile['full_name'] as String?)
              ?.trim()
              .isNotEmpty == true
          ? (studentProfile['full_name'] as String).trim()
          : ((studentProfile['email'] as String?)?.trim().isNotEmpty == true
              ? (studentProfile['email'] as String).trim()
              : 'Student'),
      studentAvatarUrl: studentProfile['avatar_url'] ?? studentProfile['profile_photo_url'],
      studentType: studentProfile['user_type'] ?? 'learner',
      // Tutor info
      tutorName: tutorProfile?['full_name'] ?? 'Tutor',
      tutorAvatarUrl: tutorProfile?['avatar_url'] ?? tutorProfile?['profile_photo_url'],
      tutorRating: 0.0, 
      tutorIsVerified: false,
    );
  }

  /// Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
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
      'tutor_name': tutorName,
      'tutor_avatar_url': tutorAvatarUrl,
      'tutor_rating': tutorRating,
      'tutor_is_verified': tutorIsVerified,
      // Note: Trial fields are not saved to booking_requests table usually
    };
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
