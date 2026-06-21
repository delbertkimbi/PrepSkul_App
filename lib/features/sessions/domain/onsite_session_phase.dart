/// Progressive onsite session UI — one primary focus per lifecycle stage.
enum OnsiteSessionPhase {
  /// Before the 1h pre-start presence window.
  upcoming,

  /// Inside presence window; tutor should check in.
  readyToCheckIn,

  /// Checked in and teaching (scheduled or in_progress).
  onSite,

  /// Session finished or checked out.
  done,
}

class OnsiteSessionPhaseResolver {
  OnsiteSessionPhaseResolver._();

  static const Duration presenceBeforeStart = Duration(hours: 1);
  static const Duration presenceAfterStart = Duration(hours: 2);

  static DateTime? presenceWindowStart(DateTime? scheduledStart) =>
      scheduledStart?.subtract(presenceBeforeStart);

  static DateTime? presenceWindowEnd(DateTime? scheduledStart) =>
      scheduledStart?.add(presenceAfterStart);

  static bool isWithinPresenceWindow(DateTime? scheduledStart) {
    if (scheduledStart == null) return false;
    final now = DateTime.now();
    final start = presenceWindowStart(scheduledStart)!;
    final end = presenceWindowEnd(scheduledStart)!;
    return !now.isBefore(start) && now.isBefore(end);
  }

  static OnsiteSessionPhase resolve({
    required String sessionStatus,
    required DateTime? scheduledStart,
    required bool hasCheckedIn,
    required bool hasCheckedOut,
  }) {
    final status = sessionStatus.toLowerCase();
    if (hasCheckedOut ||
        status == 'completed' ||
        status == 'cancelled' ||
        status == 'evaluated') {
      return OnsiteSessionPhase.done;
    }
    if (hasCheckedIn) return OnsiteSessionPhase.onSite;
    if (isWithinPresenceWindow(scheduledStart)) {
      return OnsiteSessionPhase.readyToCheckIn;
    }
    return OnsiteSessionPhase.upcoming;
  }

  /// Human-readable next step for tutors (list cards, detail headers).
  static String tutorNextStepLabel({
    required OnsiteSessionPhase phase,
    required DateTime? scheduledStart,
    required bool hasSelfie,
  }) {
    switch (phase) {
      case OnsiteSessionPhase.upcoming:
        if (scheduledStart == null) {
          return 'On-site • check in opens 1h before start';
        }
        final opens = presenceWindowStart(scheduledStart)!;
        return 'Check-in opens ${ _shortTime(opens) }';
      case OnsiteSessionPhase.readyToCheckIn:
        return 'Tap to check in at the location';
      case OnsiteSessionPhase.onSite:
        if (!hasSelfie) return 'On site • take a selfie with your student';
        return 'On site • tap for session details';
      case OnsiteSessionPhase.done:
        return 'Session complete';
    }
  }

  /// Human-readable next step for learners on onsite session cards.
  static String studentNextStepLabel({
    required OnsiteSessionPhase phase,
    required DateTime? scheduledStart,
    required bool tutorHasCheckedIn,
  }) {
    switch (phase) {
      case OnsiteSessionPhase.upcoming:
        return 'On-site session • tutor check-in opens 1h before start';
      case OnsiteSessionPhase.readyToCheckIn:
        return 'Your tutor can check in soon';
      case OnsiteSessionPhase.onSite:
        return tutorHasCheckedIn
            ? 'Your tutor has arrived on site'
            : 'On-site session in progress';
      case OnsiteSessionPhase.done:
        return 'On-site session complete';
    }
  }

  static String _shortTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (day == today) return 'today at $time';
    if (day == today.add(const Duration(days: 1))) return 'tomorrow at $time';
    return 'on ${dt.month}/${dt.day} at $time';
  }
}
