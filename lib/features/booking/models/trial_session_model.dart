/// Model for trial session requests
///
/// Matches the trial_sessions table in Supabase
class TrialSession {
  final String id;
  final String tutorId;
  final String learnerId;
  final String? parentId;
  final String requesterId;

  // Session Details
  final String subject;
  final DateTime scheduledDate;
  final String scheduledTime; // e.g., "14:00"
  final int durationMinutes; // 30 or 60
  final String location; // 'online' or 'onsite'

  // Trial Details
  final String? trialGoal;
  final String? learnerChallenges;
  final String? learnerLevel;

  // Status
  final String
  status; // pending, approved, rejected, scheduled, completed, cancelled, no_show
  final String? tutorResponseNotes;
  final String? rejectionReason;

  // Payment
  final double trialFee;
  final String paymentStatus; // unpaid, paid, refunded
  final String? paymentId;
  final String? meetLink;

  // Multi-learner support (optional)
  final String? bookingGroupId; // Deprecated for trials - kept for backward compat
  final String? learnerLabel; // Single learner name (for backward compat)
  final List<String>? learnerLabels; // Array of learner names when parent books for multiple children

  // Outcome
  final bool convertedToRecurring;
  final String? recurringSessionId;

  // Timestamps
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime? updatedAt;

  TrialSession({
    required this.id,
    required this.tutorId,
    required this.learnerId,
    this.parentId,
    required this.requesterId,
    required this.subject,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.durationMinutes,
    required this.location,
    this.trialGoal,
    this.learnerChallenges,
    this.learnerLevel,
    this.status = 'pending',
    this.tutorResponseNotes,
    this.rejectionReason,
    required this.trialFee,
    this.paymentStatus = 'unpaid',
    this.paymentId,
    this.meetLink,
    this.bookingGroupId,
    this.learnerLabel,
    this.learnerLabels,
    this.convertedToRecurring = false,
    this.recurringSessionId,
    required this.createdAt,
    this.respondedAt,
    this.updatedAt,
  });

  /// Create from JSON (from Supabase)
  factory TrialSession.fromJson(Map<String, dynamic> json) {
    return TrialSession(
      id: json['id'] as String,
      tutorId: json['tutor_id'] as String,
      learnerId: json['learner_id'] as String,
      parentId: json['parent_id'] as String?,
      requesterId: json['requester_id'] as String,
      subject: json['subject'] as String,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      scheduledTime: json['scheduled_time'] as String,
      durationMinutes: json['duration_minutes'] as int,
      location: json['location'] as String,
      trialGoal: json['trial_goal'] as String?,
      learnerChallenges: json['learner_challenges'] as String?,
      learnerLevel: json['learner_level'] as String?,
      status: json['status'] as String? ?? 'pending',
      tutorResponseNotes: json['tutor_response_notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      trialFee: (json['trial_fee'] as num).toDouble(),
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      paymentId: json['payment_id'] as String?,
      meetLink: json['meet_link'] as String?,
      bookingGroupId: json['booking_group_id'] as String?,
      learnerLabel: json['learner_label'] as String?,
      convertedToRecurring: json['converted_to_recurring'] as bool? ?? false,
      recurringSessionId: json['recurring_session_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert to JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tutor_id': tutorId,
      'learner_id': learnerId,
      'parent_id': parentId,
      'requester_id': requesterId,
      'subject': subject,
      'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
      'scheduled_time': scheduledTime,
      'duration_minutes': durationMinutes,
      'location': location,
      'trial_goal': trialGoal,
      'learner_challenges': learnerChallenges,
      'learner_level': learnerLevel,
      'status': status,
      'tutor_response_notes': tutorResponseNotes,
      'rejection_reason': rejectionReason,
      'trial_fee': trialFee,
      'payment_status': paymentStatus,
      'payment_id': paymentId,
      'meet_link': meetLink,
      if (bookingGroupId != null) 'booking_group_id': bookingGroupId,
      if (learnerLabel != null) 'learner_label': learnerLabel,
      if (learnerLabels != null) 'learner_labels': learnerLabels,
      'converted_to_recurring': convertedToRecurring,
      'recurring_session_id': recurringSessionId,
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Helper getters for status checks
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isScheduled => status == 'scheduled';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  /// Format duration for display
  String get formattedDuration {
    if (durationMinutes == 30) return '30 minutes';
    if (durationMinutes == 60) return '1 hour';
    return '$durationMinutes minutes';
  }

  /// Format date for display
  String get formattedDate {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[scheduledDate.month - 1]} ${scheduledDate.day}, ${scheduledDate.year}';
  }

  /// Format time for display
  String get formattedTime {
    final parts = scheduledTime.split(':');
    if (parts.length < 2) return scheduledTime;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];

    if (hour == 0) return '12:$minute AM';
    if (hour < 12) return '$hour:$minute AM';
    if (hour == 12) return '12:$minute PM';
    return '${hour - 12}:$minute PM';
  }

  /// Copy with method for updates
  TrialSession copyWith({
    String? id,
    String? tutorId,
    String? learnerId,
    String? parentId,
    String? requesterId,
    String? subject,
    DateTime? scheduledDate,
    String? scheduledTime,
    int? durationMinutes,
    String? location,
    String? trialGoal,
    String? learnerChallenges,
    String? learnerLevel,
    String? status,
    String? tutorResponseNotes,
    String? rejectionReason,
    double? trialFee,
    String? paymentStatus,
    String? paymentId,
    String? meetLink,
    bool? convertedToRecurring,
    String? recurringSessionId,
    DateTime? createdAt,
    DateTime? respondedAt,
    DateTime? updatedAt,
  }) {
    return TrialSession(
      id: id ?? this.id,
      tutorId: tutorId ?? this.tutorId,
      learnerId: learnerId ?? this.learnerId,
      parentId: parentId ?? this.parentId,
      requesterId: requesterId ?? this.requesterId,
      subject: subject ?? this.subject,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      location: location ?? this.location,
      trialGoal: trialGoal ?? this.trialGoal,
      learnerChallenges: learnerChallenges ?? this.learnerChallenges,
      learnerLevel: learnerLevel ?? this.learnerLevel,
      status: status ?? this.status,
      tutorResponseNotes: tutorResponseNotes ?? this.tutorResponseNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      trialFee: trialFee ?? this.trialFee,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentId: paymentId ?? this.paymentId,
      meetLink: meetLink ?? this.meetLink,
      convertedToRecurring: convertedToRecurring ?? this.convertedToRecurring,
      recurringSessionId: recurringSessionId ?? this.recurringSessionId,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
