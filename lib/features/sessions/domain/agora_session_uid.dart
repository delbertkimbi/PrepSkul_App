/// Deterministic Agora numeric UID for a user in a lesson channel.
///
/// Must stay in sync with [generateSessionUID] in
/// `PrepSkul_Web/lib/services/agora/token-generator.ts`.
int agoraNumericUidForSessionRole({
  required String sessionId,
  required String userId,
  required String role,
}) {
  assert(
    role == 'tutor' || role == 'learner',
    'role must be tutor or learner (matches token API)',
  );
  final uidString = '${sessionId}_${userId}_$role';
  var hash = 0;
  for (var i = 0; i < uidString.length; i++) {
    final char = uidString.codeUnitAt(i);
    // JavaScript applies 32-bit signed truncation on each bitwise/arithmetic step.
    hash = (((hash << 5) - hash) + char).toSigned(32);
  }
  final absHash = hash == -2147483648 ? 2147483648 : hash.abs();
  return absHash % 2147483647;
}
