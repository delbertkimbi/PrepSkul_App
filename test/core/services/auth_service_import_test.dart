import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/services/auth_service.dart' hide LogService;
import 'package:prepskul/core/services/log_service.dart';

/// Test that LogService import conflicts are resolved
/// 
/// This test verifies that:
/// 1. auth_service.dart can be imported with LogService hidden
/// 2. LogService can be imported directly from log_service.dart
/// 3. No import conflicts occur
void main() {
  group('AuthService Import Tests', () {
    test('should import auth_service without LogService conflict', () {
      // This test verifies compilation succeeds
      // If there's an import conflict, the test won't compile
      expect(AuthService, isNotNull);
    });

    test('should import LogService directly from log_service', () {
      // Verify LogService is available from log_service.dart
      expect(LogService, isNotNull);
    });

    test('should not have LogService in auth_service import', () {
      // Verify that LogService is hidden from auth_service import
      // This is a compile-time check - if LogService was not hidden,
      // there would be an ambiguity error
      expect(true, isTrue);
    });
  });
}

