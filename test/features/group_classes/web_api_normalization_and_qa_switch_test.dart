import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web API normalization and QA quick switch wiring', () {
    test('AppConfig includes web API normalization and QA env keys', () async {
      final content = await File('lib/core/config/app_config.dart').readAsString();

      expect(content.contains("replaceAll('://app.prepskul.com', '://www.prepskul.com')"), isTrue);
      expect(content.contains('enableQaQuickSwitch'), isTrue);
      expect(content.contains('QA_QUICK_SWITCH_ENABLED'), isTrue);
      expect(content.contains('QA_SESSION_JOIN_BYPASS_ENABLED'), isTrue);
      expect(content.contains('QA_TUTOR_PHONE'), isTrue);
      expect(content.contains('QA_LEARNER_PHONE'), isTrue);
      expect(content.contains('QA_OBSERVER_PHONE'), isTrue);
    });

    test('Login screen exposes QA quick switch panel in dev', () async {
      final content = await File(
        'lib/features/auth/screens/beautiful_login_screen.dart',
      ).readAsString();

      expect(content.contains('QA Quick Switch (dev)'), isTrue);
      expect(content.contains('Tutor QA'), isTrue);
      expect(content.contains('Learner QA'), isTrue);
      expect(content.contains('Unpaid QA'), isTrue);
      expect(content.contains('_quickLogin('), isTrue);
    });
  });
}

