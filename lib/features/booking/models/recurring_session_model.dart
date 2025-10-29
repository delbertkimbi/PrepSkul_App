import 'package:prepskul/features/booking/models/booking_request_model.dart';

/// RecurringSession Model
///
/// Represents an approved, ongoing tutoring arrangement
/// Created when a booking request is approved
class RecurringSession {
  final String id;
  final String requestId; // Original booking request ID
  final String studentId;
  final String tutorId;
  final int frequency; // Sessions per week
  final List<String> days;
  final Map<String, String> times;
  final String location;
  final String? address;
  final String paymentPlan;
  final double monthlyTotal;
  final DateTime startDate;
  final DateTime? endDate; // null = ongoing
  final String status; // active, paused, completed, cancelled
  final DateTime createdAt;
  final DateTime? lastSessionDate;
  final int totalSessionsCompleted;
  final double totalRevenue;

  // Student/Parent info
  final String studentName;
  final String? studentAvatarUrl;
  final String studentType;

  // Tutor info
  final String tutorName;
  final String? tutorAvatarUrl;
  final double tutorRating;

  RecurringSession({
    required this.id,
    required this.requestId,
    required this.studentId,
    required this.tutorId,
    required this.frequency,
    required this.days,
    required this.times,
    required this.location,
    this.address,
    required this.paymentPlan,
    required this.monthlyTotal,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.createdAt,
    this.lastSessionDate,
    this.totalSessionsCompleted = 0,
    this.totalRevenue = 0.0,
    required this.studentName,
    this.studentAvatarUrl,
    required this.studentType,
    required this.tutorName,
    this.tutorAvatarUrl,
    required this.tutorRating,
  });

  /// Create from Supabase JSON
  factory RecurringSession.fromJson(Map<String, dynamic> json) {
    return RecurringSession(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      studentId: json['student_id'] as String,
      tutorId: json['tutor_id'] as String,
      frequency: json['frequency'] as int,
      days: List<String>.from(json['days'] as List),
      times: Map<String, String>.from(json['times'] as Map),
      location: json['location'] as String,
      address: json['address'] as String?,
      paymentPlan: json['payment_plan'] as String,
      monthlyTotal: (json['monthly_total'] as num).toDouble(),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastSessionDate: json['last_session_date'] != null
          ? DateTime.parse(json['last_session_date'] as String)
          : null,
      totalSessionsCompleted: json['total_sessions_completed'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      studentName: json['student_name'] as String,
      studentAvatarUrl: json['student_avatar_url'] as String?,
      studentType: json['student_type'] as String,
      tutorName: json['tutor_name'] as String,
      tutorAvatarUrl: json['tutor_avatar_url'] as String?,
      tutorRating: (json['tutor_rating'] as num).toDouble(),
    );
  }

  /// Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'student_id': studentId,
      'tutor_id': tutorId,
      'frequency': frequency,
      'days': days,
      'times': times,
      'location': location,
      'address': address,
      'payment_plan': paymentPlan,
      'monthly_total': monthlyTotal,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'last_session_date': lastSessionDate?.toIso8601String(),
      'total_sessions_completed': totalSessionsCompleted,
      'total_revenue': totalRevenue,
      'student_name': studentName,
      'student_avatar_url': studentAvatarUrl,
      'student_type': studentType,
      'tutor_name': tutorName,
      'tutor_avatar_url': tutorAvatarUrl,
      'tutor_rating': tutorRating,
    };
  }

  /// Create from approved booking request
  factory RecurringSession.fromBookingRequest(
    BookingRequest request, {
    required String id,
    required DateTime startDate,
  }) {
    return RecurringSession(
      id: id,
      requestId: request.id,
      studentId: request.studentId,
      tutorId: request.tutorId,
      frequency: request.frequency,
      days: request.days,
      times: request.times,
      location: request.location,
      address: request.address,
      paymentPlan: request.paymentPlan,
      monthlyTotal: request.monthlyTotal,
      startDate: startDate,
      status: 'active',
      createdAt: DateTime.now(),
      studentName: request.studentName,
      studentAvatarUrl: request.studentAvatarUrl,
      studentType: request.studentType,
      tutorName: request.tutorName,
      tutorAvatarUrl: request.tutorAvatarUrl,
      tutorRating: request.tutorRating,
    );
  }

  /// Check if session is active
  bool get isActive => status == 'active';

  /// Check if session is paused
  bool get isPaused => status == 'paused';

  /// Check if session is completed
  bool get isCompleted => status == 'completed';

  /// Check if session is cancelled
  bool get isCancelled => status == 'cancelled';

  /// Calculate expected sessions per month
  int get expectedSessionsPerMonth => frequency * 4;

  /// Calculate revenue per session
  double get revenuePerSession =>
      totalSessionsCompleted > 0 ? totalRevenue / totalSessionsCompleted : 0.0;

  /// Copy with updated fields
  RecurringSession copyWith({
    String? status,
    DateTime? endDate,
    DateTime? lastSessionDate,
    int? totalSessionsCompleted,
    double? totalRevenue,
  }) {
    return RecurringSession(
      id: id,
      requestId: requestId,
      studentId: studentId,
      tutorId: tutorId,
      frequency: frequency,
      days: days,
      times: times,
      location: location,
      address: address,
      paymentPlan: paymentPlan,
      monthlyTotal: monthlyTotal,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt,
      lastSessionDate: lastSessionDate ?? this.lastSessionDate,
      totalSessionsCompleted:
          totalSessionsCompleted ?? this.totalSessionsCompleted,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      studentName: studentName,
      studentAvatarUrl: studentAvatarUrl,
      studentType: studentType,
      tutorName: tutorName,
      tutorAvatarUrl: tutorAvatarUrl,
      tutorRating: tutorRating,
    );
  }
}

