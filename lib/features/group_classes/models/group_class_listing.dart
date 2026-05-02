class GroupClassListing {
  const GroupClassListing({
    required this.id,
    required this.tutorId,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.durationMinutes,
    required this.capacity,
    required this.pricePerSeat,
    required this.status,
    this.flyerImageUrl,
    this.tutorAvatarUrl,
    this.subject,
    this.classType = 'one_time',
    this.learningFocus,
    this.scheduleEndAt,
    this.meetingDays = const <String>[],
    this.currencyCode = 'XAF',
    this.publishedAt,
    this.shareToken,
    this.approvalStatus = 'pending',
  });

  final String id;
  final String tutorId;
  final String title;
  final String description;
  final String? flyerImageUrl;
  final String? tutorAvatarUrl;
  final String? subject;
  final String classType;
  final String? learningFocus;
  final DateTime? scheduleEndAt;
  final List<String> meetingDays;
  final DateTime startsAt;
  final int durationMinutes;
  final int capacity;
  final double pricePerSeat;
  final String currencyCode;
  final String status;
  final DateTime? publishedAt;
  final String? shareToken;
  final String approvalStatus;

  factory GroupClassListing.fromJson(Map<String, dynamic> json) {
    return GroupClassListing(
      id: (json['id'] ?? '').toString(),
      tutorId: (json['tutor_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      flyerImageUrl: json['flyer_image_url']?.toString(),
      tutorAvatarUrl: _readTutorAvatarUrl(json),
      subject: json['subject']?.toString(),
      classType: (json['class_type'] ?? 'one_time').toString(),
      learningFocus: json['learning_focus']?.toString(),
      scheduleEndAt: json['schedule_end_at'] != null
          ? DateTime.tryParse(json['schedule_end_at'].toString())
          : null,
      meetingDays: (json['meeting_days'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      startsAt: DateTime.parse((json['starts_at'] ?? '').toString()),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      pricePerSeat: (json['price_per_seat'] as num?)?.toDouble() ?? 0,
      currencyCode: (json['currency_code'] ?? 'XAF').toString(),
      status: (json['status'] ?? 'draft').toString(),
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'].toString())
          : null,
      shareToken: json['share_token']?.toString(),
      approvalStatus: (json['approval_status'] ?? 'pending').toString(),
    );
  }

  static String? _readTutorAvatarUrl(Map<String, dynamic> json) {
    final direct = json['tutor_avatar_url']?.toString();
    if (direct != null && direct.isNotEmpty && direct != 'null') return direct;

    final nested = json['profiles'];
    if (nested is Map<String, dynamic>) {
      final avatar = nested['avatar_url']?.toString();
      if (avatar != null && avatar.isNotEmpty && avatar != 'null') return avatar;
    }
    return null;
  }
}

