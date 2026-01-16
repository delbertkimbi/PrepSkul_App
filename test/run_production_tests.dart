/// Production Deployment Test Runner
/// 
/// Runs all tests related to production deployment features:
/// - Screen sharing with data stream notifications
/// - Production payment webhook detection
/// - Payment confirmation flow
/// 
/// Usage: flutter test test/run_production_tests.dart

import 'package:flutter_test/flutter_test.dart';

// Import test files
import 'features/sessions/screen_sharing_test.dart' as screen_sharing_test;
import 'features/sessions/agora_screen_sharing_integration_test.dart' as screen_sharing_integration_test;
import 'features/payment/payment_webhook_production_test.dart' as payment_webhook_test;
import 'features/payment/payment_confirmation_screen_test.dart' as payment_confirmation_test;
import 'features/payment/payment_simulation_production_test.dart' as payment_production_test;

void main() {
  group('🚀 Production Deployment Tests', () {
    group('🖥️ Screen Sharing Tests', () {
      screen_sharing_test.main();
    });

    group('🖥️ Screen Sharing Integration Tests', () {
      screen_sharing_integration_test.main();
    });

    group('💰 Payment Webhook Tests', () {
      payment_webhook_test.main();
    });

    group('💰 Payment Confirmation Tests', () {
      payment_confirmation_test.main();
    });

    group('💰 Payment Production Tests', () {
      payment_production_test.main();
    });
  });
}

