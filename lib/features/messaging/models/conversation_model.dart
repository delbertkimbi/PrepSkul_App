/// Conversation Model
/// 
/// Represents a conversation between a student/parent and tutor
class Conversation {
  final String id;
  final String studentId;
  final String tutorId;
  
  // Context linking (one of these will be set)
  final String? trialSessionId;
  final String? bookingRequestId;
  final String? recurringSessionId;
  final String? individualSessionId;
  
  // Lifecycle
  final String status; // active, expired, closed, blocked
  final DateTime? expiresAt;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  
  // Denormalized data for display
  final String? otherUserName;
  final String? otherUserAvatarUrl;
  final int unreadCount;
  final String? lastMessagePreview;
  final DateTime? lastMessageTime;
  final DateTime? otherUserLastSeen; // For active status tracking

  Conversation({
    required this.id,
    required this.studentId,
    required this.tutorId,
    this.trialSessionId,
    this.bookingRequestId,
    this.recurringSessionId,
    this.individualSessionId,
    required this.status,
    this.expiresAt,
    this.lastMessageAt,
    required this.createdAt,
    this.otherUserName,
    this.otherUserAvatarUrl,
    this.unreadCount = 0,
    this.lastMessagePreview,
    this.lastMessageTime,
    this.otherUserLastSeen,
  });

  /// Create from JSON (from Supabase)
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      tutorId: json['tutor_id'] as String,
      trialSessionId: json['trial_session_id'] as String?,
      bookingRequestId: json['booking_request_id'] as String?,
      recurringSessionId: json['recurring_session_id'] as String?,
      individualSessionId: json['individual_session_id'] as String?,
      status: json['status'] as String? ?? 'active',
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      otherUserName: json['other_user_name'] as String?,
      otherUserAvatarUrl: json['other_user_avatar_url'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'] as String)
          : null,
      otherUserLastSeen: json['other_user_last_seen'] != null
          ? DateTime.parse(json['other_user_last_seen'] as String)
          : null,
    );
  }

  /// Check if other user is currently active (online within last 5 minutes)
  bool get isOtherUserActive {
    if (otherUserLastSeen == null) return false;
    final now = DateTime.now();
    final difference = now.difference(otherUserLastSeen!);
    return difference.inMinutes < 5; // Active if seen within last 5 minutes
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'tutor_id': tutorId,
      'trial_session_id': trialSessionId,
      'booking_request_id': bookingRequestId,
      'recurring_session_id': recurringSessionId,
      'individual_session_id': individualSessionId,
      'status': status,
      'expires_at': expiresAt?.toIso8601String(),
      'last_message_at': lastMessageAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Check if conversation is active
  bool get isActive => status == 'active' && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  /// Get the other user's ID (student or tutor)
  String getOtherUserId(String currentUserId) {
    return currentUserId == studentId ? tutorId : studentId;
  }
}

