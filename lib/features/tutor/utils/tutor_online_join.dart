/// Tutor classroom join rules for online individual/group sessions.
class TutorOnlineJoin {
  /// In-app Agora join. A Google Meet link is not required.
  static bool shouldShowJoinAction({
    required String? location,
    required String? status,
    String? meetLink,
  }) {
    final isOnline = (location ?? '').toLowerCase() == 'online';
    final normalized = (status ?? '').toLowerCase();
    return isOnline &&
        (normalized == 'scheduled' || normalized == 'in_progress');
  }
}
