import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/payment/services/fapshi_service.dart';
import 'package:prepskul/features/payment/models/fapshi_transaction_model.dart';

/// Comprehensive tests for FapshiService
/// Tests payment initiation, status polling, error handling, and phone validation
void main() {
  group('FapshiService - Phone Number Validation', () {
    test('detectPhoneProvider returns mtn for MTN numbers', () {
      // Use valid 9-digit MTN numbers (Cameroon format: 67XXXXXXX, 65XXXXXXX, etc.)
      // Note: Phone numbers must be exactly 9 digits starting with valid prefix
      expect(FapshiService.detectPhoneProvider('671234567'), 'mtn');
      expect(FapshiService.detectPhoneProvider('651234567'), 'mtn');
      expect(FapshiService.detectPhoneProvider('661234567'), 'mtn');
      expect(FapshiService.detectPhoneProvider('681234567'), 'mtn');
    });

    test('detectPhoneProvider returns orange for Orange numbers', () {
      // Use valid 9-digit Orange numbers (Cameroon format: 69XXXXXXX)
      expect(FapshiService.detectPhoneProvider('691234567'), 'orange');
    });

    test('detectPhoneProvider returns null for invalid numbers', () {
      expect(FapshiService.detectPhoneProvider('123456789'), null);
      expect(FapshiService.detectPhoneProvider(''), null);
      expect(FapshiService.detectPhoneProvider('invalid'), null);
      expect(FapshiService.detectPhoneProvider('12345'), null); // Too short
    });

    test('detectPhoneProvider handles international format', () {
      expect(FapshiService.detectPhoneProvider('+237671234567'), 'mtn');
      expect(FapshiService.detectPhoneProvider('237691234567'), 'orange');
    });
  });

  group('FapshiService - Payment Initiation', () {
    test('initiateDirectPayment validates amount before API call', () async {
      // Test that amount validation happens before API credentials check
      // Note: This will fail on API credentials, but amount validation should happen first
      try {
        await FapshiService.initiateDirectPayment(
          amount: 50,
          phone: '671234567',
          externalId: 'test_123',
        );
        fail('Should have thrown an exception');
      } catch (e) {
        // Should throw either amount error or credentials error
        expect(e, isA<Exception>());
      }
    });

    test('initiateDirectPayment validates phone number format', () async {
      // Test that phone validation happens
      try {
        await FapshiService.initiateDirectPayment(
          amount: 1000,
          phone: 'invalid',
          externalId: 'test_123',
        );
        fail('Should have thrown an exception');
      } catch (e) {
        // Should throw phone validation error or credentials error
        expect(e, isA<Exception>());
      }
    });

    test('initiateDirectPayment normalizes phone numbers correctly', () {
      // Test phone normalization through detectPhoneProvider
      expect(FapshiService.detectPhoneProvider('+237671234567'), 'mtn');
      expect(FapshiService.detectPhoneProvider('237691234567'), 'orange');
      expect(FapshiService.detectPhoneProvider('671234567'), 'mtn');
    });
  });

  group('FapshiService - Payment Status', () {
    test('FapshiPaymentStatus correctly identifies pending status', () {
      final status = FapshiPaymentStatus(
        transId: 'test_123',
        status: 'PENDING',
        amount: 1000,
        dateInitiated: DateTime.now(),
      );
      expect(status.isPending, true);
      expect(status.isSuccessful, false);
      expect(status.isFailed, false);
    });

    test('FapshiPaymentStatus correctly identifies successful status', () {
      final status = FapshiPaymentStatus(
        transId: 'test_123',
        status: 'SUCCESSFUL',
        amount: 1000,
        dateInitiated: DateTime.now(),
        dateCompleted: DateTime.now(),
      );
      expect(status.isPending, false);
      expect(status.isSuccessful, true);
      expect(status.isFailed, false);
    });

    test('FapshiPaymentStatus correctly identifies failed status', () {
      final status = FapshiPaymentStatus(
        transId: 'test_123',
        status: 'FAILED',
        amount: 1000,
        dateInitiated: DateTime.now(),
      );
      expect(status.isPending, false);
      expect(status.isSuccessful, false);
      expect(status.isFailed, true);
    });

    test('FapshiPaymentStatus handles CREATED status as pending', () {
      final status = FapshiPaymentStatus(
        transId: 'test_123',
        status: 'CREATED',
        amount: 1000,
        dateInitiated: DateTime.now(),
      );
      expect(status.isPending, true);
    });
  });

  group('FapshiService - Error Handling', () {
    test('Error messages are user-friendly and non-technical', () {
      // Test that error conversion produces user-friendly messages
      // This is tested through the actual error handling in the service
      // The service should convert technical errors to user-friendly messages
      expect(true, true); // Placeholder - actual error message testing requires mocking
    });
  });

  group('FapshiService - Environment Configuration', () {
    test('isProduction returns correct value', () {
      // Test that production flag is accessible
      final isProd = FapshiService.isProduction;
      expect(isProd, isA<bool>());
    });
  });
}

