import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/services/auth_service.dart' hide LogService;
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/features/discovery/screens/find_tutors_screen.dart';
import 'package:prepskul/features/profile/screens/profile_screen.dart';
import 'package:prepskul/core/navigation/route_guards.dart';
import 'package:prepskul/features/dashboard/screens/student_home_screen.dart';

/// Integration test to verify LogService import conflicts are resolved
/// 
/// This test verifies that:
/// 1. All files can import auth_service.dart without LogService conflicts
/// 2. LogService can be imported directly from log_service.dart
/// 3. No ambiguity errors occur
void main() {
  group('Import Conflicts Integration Tests', () {
    test('should import auth_service without LogService conflict', () {
      // Verify AuthService is available
      expect(AuthService, isNotNull);
    });

    test('should import LogService directly from log_service', () {
      // Verify LogService is available from log_service.dart
      expect(LogService, isNotNull);
    });

    test('should compile find_tutors_screen without conflicts', () {
      // If this compiles, the import conflict is resolved
      expect(FindTutorsScreen, isNotNull);
    });

    test('should compile profile_screen without conflicts', () {
      // If this compiles, the import conflict is resolved
      expect(ProfileScreen, isNotNull);
    });

    test('should compile route_guards without conflicts', () {
      // If this compiles, the import conflict is resolved
      // Note: RouteGuards might not be directly testable, but import should work
      expect(true, isTrue);
    });

    test('should compile student_home_screen without conflicts', () {
      // If this compiles, the import conflict is resolved
      expect(StudentHomeScreen, isNotNull);
    });

    test('should use LogService without ambiguity', () {
      // Verify LogService can be used without ambiguity
      // This test passes if compilation succeeds
      expect(() => LogService.info('Test'), returnsNormally);
    });
  });
}

