import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/sessions/domain/agora_session_uid.dart';

void main() {
  test('matches PrepSkul_Web generateSessionUID (sample vectors)', () {
    expect(
      agoraNumericUidForSessionRole(
        sessionId: 'sess-1',
        userId: 'user-uuid-abc',
        role: 'tutor',
      ),
      1957573472,
    );
    expect(
      agoraNumericUidForSessionRole(
        sessionId: 'sess-1',
        userId: 'user-uuid-abc',
        role: 'learner',
      ),
      1046811547,
    );
    expect(
      agoraNumericUidForSessionRole(
        sessionId: 'sess-1',
        userId: 'user-uuid-def',
        role: 'tutor',
      ),
      131184835,
    );
  });
}
