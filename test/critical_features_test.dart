import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Critical Features Test Suite
void main() {
  group('Critical Features Test Suite', () {
    group('1. Error Handling', () {
      test('ErrorHandler provides user-friendly messages', () {
        final networkError = Exception('Failed to fetch');
        final networkMessage = ErrorHandler.getUserFriendlyMessage(networkError);
        expect(networkMessage, contains('Network error'));
      });
    });
  });
}
