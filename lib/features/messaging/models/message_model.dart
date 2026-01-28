/// Message Model
/// 
/// Represents a single message in a conversation
class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  
  // Read receipts
  final bool isRead;
  final DateTime? readAt;
  
  // Moderation
  final bool isFiltered;
  final String? filterReason;
  final String moderationStatus; // pending, approved, flagged
  
  // Metadata
  final DateTime createdAt;
  
  // Denormalized data for display
  final String? senderName;
  final String? senderAvatarUrl;
  final bool isCurrentUser;
  
  // Reply functionality
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderName;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.isRead = false,
    this.readAt,
    this.isFiltered = false,
    this.filterReason,
    this.moderationStatus = 'approved',
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
    this.isCurrentUser = false,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderName,
  });

  /// Create from JSON (from Supabase)
  factory Message.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final senderId = json['sender_id'] as String;
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: senderId,
      content: json['content'] as String,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      isFiltered: json['is_filtered'] as bool? ?? false,
      filterReason: json['filter_reason'] as String?,
      moderationStatus: json['moderation_status'] as String? ?? 'approved',
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: json['sender_name'] as String?,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      isCurrentUser: currentUserId != null && senderId == currentUserId,
      replyToMessageId: json['reply_to_message_id'] as String?,
      replyToContent: json['reply_to_content'] as String?,
      replyToSenderName: json['reply_to_sender_name'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'is_filtered': isFiltered,
      'filter_reason': filterReason,
      'moderation_status': moderationStatus,
      'created_at': createdAt.toIso8601String(),
      'reply_to_message_id': replyToMessageId,
      'reply_to_content': replyToContent,
      'reply_to_sender_name': replyToSenderName,
    };
  }

  /// Create a copy with updated fields
  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    bool? isRead,
    DateTime? readAt,
    bool? isFiltered,
    String? filterReason,
    String? moderationStatus,
    DateTime? createdAt,
    String? senderName,
    String? senderAvatarUrl,
    bool? isCurrentUser,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      isFiltered: isFiltered ?? this.isFiltered,
      filterReason: filterReason ?? this.filterReason,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
    );
  }
}

