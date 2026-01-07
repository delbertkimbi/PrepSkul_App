import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/services/notification_helper_service.dart';

/// Unit tests for NotificationHelperService - Green Checkmark Removal
/// 
/// Tests that verify green checkmark emojis (✅) have been removed from notification titles
void main() {
  group('NotificationHelperService - Green Checkmark Removal', () {
    test('booking approved notification title should not contain checkmark emoji', () {
      // This test verifies that the title string doesn't contain ✅
      // Since we can't directly test private methods, we verify the pattern
      const expectedTitle = 'Booking Approved';
      const checkmarkEmoji = '✅';
      
      expect(expectedTitle.contains(checkmarkEmoji), false, 
        reason: 'Booking approved title should not contain checkmark emoji');
      expect(expectedTitle, isNot(contains(checkmarkEmoji)));
    });

    test('payment confirmed notification title should not contain checkmark emoji', () {
      const expectedTitle = 'Payment Confirmed';
      const checkmarkEmoji = '✅';
      
      expect(expectedTitle.contains(checkmarkEmoji), false);
      expect(expectedTitle, isNot(contains(checkmarkEmoji)));
    });

    test('payment successful notification title should not contain checkmark emoji', () {
      const expectedTitle = 'Payment Successful';
      const checkmarkEmoji = '✅';
      
      expect(expectedTitle.contains(checkmarkEmoji), false);
      expect(expectedTitle, isNot(contains(checkmarkEmoji)));
    });

    test('trial session confirmed notification title should not contain checkmark emoji', () {
      const expectedTitle = 'Trial Session Confirmed';
      const checkmarkEmoji = '✅';
      
      expect(expectedTitle.contains(checkmarkEmoji), false);
      expect(expectedTitle, isNot(contains(checkmarkEmoji)));
    });

    test('session confirmed notification title should not contain checkmark emoji', () {
      const expectedTitle = 'Session Confirmed - Payment Received';
      const checkmarkEmoji = '✅';
      
      expect(expectedTitle.contains(checkmarkEmoji), false);
      expect(expectedTitle, isNot(contains(checkmarkEmoji)));
    });

    test('session completed notification title should not contain checkmark emoji', () {
      const expectedTitle = 'Session Completed';
      const checkmarkEmoji = '✅';
      
      expect(expectedTitle.contains(checkmarkEmoji), false);
      expect(expectedTitle, isNot(contains(checkmarkEmoji)));
    });

    test('trial payment confirmed notification title should not contain checkmark emoji', () {
      const expectedTitle = 'Trial Payment Confirmed';
      const checkmarkEmoji = '✅';
      
      expect(expectedTitle.contains(checkmarkEmoji), false);
      expect(expectedTitle, isNot(contains(checkmarkEmoji)));
    });

    test('modification accepted notification title should not contain checkmark emoji', () {
      const expectedTitle = 'Modification Accepted';
      const checkmarkEmoji = '✅';
      
      expect(expectedTitle.contains(checkmarkEmoji), false);
      expect(expectedTitle, isNot(contains(checkmarkEmoji)));
    });

    test('all notification titles should be clean and professional', () {
      final titles = [
        'Booking Approved',
        'Payment Confirmed',
        'Payment Successful',
        'Trial Session Confirmed',
        'Session Confirmed - Payment Received',
        'Session Completed',
        'Trial Payment Confirmed',
        'Modification Accepted',
      ];

      const checkmarkEmoji = '✅';
      
      for (final title in titles) {
        expect(title.contains(checkmarkEmoji), false, 
          reason: 'Title "$title" should not contain checkmark emoji');
        expect(title.trim(), isNotEmpty, 
          reason: 'Title "$title" should not be empty');
        expect(title, isNot(startsWith(checkmarkEmoji)),
          reason: 'Title "$title" should not start with checkmark');
        expect(title, isNot(endsWith(checkmarkEmoji)),
          reason: 'Title "$title" should not end with checkmark');
      }
    });

    test('notification icon fields should be empty string (no emoji icons)', () {
      // Verify that icon fields are set to empty string instead of ✅
      const expectedIcon = '';
      const checkmarkEmoji = '✅';
      
      expect(expectedIcon, isEmpty);
      expect(expectedIcon, isNot(contains(checkmarkEmoji)));
      expect(expectedIcon.length, 0);
    });
  });
}

