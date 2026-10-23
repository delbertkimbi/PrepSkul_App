/// A return greeting belongs to a fresh launch after a meaningful absence.
class LearnerReturnPolicy {
  static const minimumAbsence = Duration(minutes: 30);
  static bool shouldWelcome({required int now, required int? lastActive}) =>
      lastActive != null && now - lastActive >= minimumAbsence.inMilliseconds;
}
