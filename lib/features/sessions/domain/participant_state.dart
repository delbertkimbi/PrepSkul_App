class ParticipantState {
  const ParticipantState({
    required this.uid,
    this.videoMuted = false,
    this.audioMuted = false,
    this.videoReady = false,
    this.screenSharing = false,
    this.userLeft = false,
    this.connectionUnstable = false,
    this.screenOff = false,
    this.lastActivityAt,
  });

  final int uid;
  final bool videoMuted;
  final bool audioMuted;
  final bool videoReady;
  final bool screenSharing;
  final bool userLeft;
  final bool connectionUnstable;
  final bool screenOff;
  final DateTime? lastActivityAt;

  ParticipantState copyWith({
    bool? videoMuted,
    bool? audioMuted,
    bool? videoReady,
    bool? screenSharing,
    bool? userLeft,
    bool? connectionUnstable,
    bool? screenOff,
    DateTime? lastActivityAt,
  }) {
    return ParticipantState(
      uid: uid,
      videoMuted: videoMuted ?? this.videoMuted,
      audioMuted: audioMuted ?? this.audioMuted,
      videoReady: videoReady ?? this.videoReady,
      screenSharing: screenSharing ?? this.screenSharing,
      userLeft: userLeft ?? this.userLeft,
      connectionUnstable: connectionUnstable ?? this.connectionUnstable,
      screenOff: screenOff ?? this.screenOff,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }
}

