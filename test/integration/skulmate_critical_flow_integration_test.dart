import 'package:flutter_test/flutter_test.dart';

// P1 critical-flow harness (see docs/P1_CRITICAL_INTEGRATION_TEST_PLAN.md).
// Model-level coverage: test/features/skulmate/models/game_model_test.dart
// To un-skip: wire Supabase test project (or mocks), SkulMate API base URL,
// and test credentials via dart-define / env — never commit secrets.

void main() {
  group('SkulMate critical flow integration', () {
    testWidgets(
      'login -> upload -> generate -> play -> results smoke path',
      (tester) async {
        // Implement: pump app with test config → sign in → SkulMate upload tab →
        // trigger generation (mock or sandbox) → assert navigation to play/results.
      },
      skip: true,
    );
  });
}

