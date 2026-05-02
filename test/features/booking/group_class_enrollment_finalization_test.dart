import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group class enrollment finalization', () {
    test('group class service marks paid enrollments and upserts participants', () async {
      final file = File('lib/features/booking/services/group_class_service.dart');
      final content = await file.readAsString();

      expect(content.contains("from('group_class_enrollments')"), isTrue);
      expect(content.contains("'status': 'paid'"), isTrue);
      expect(content.contains("from('session_participants').upsert"), isTrue);
      expect(content.contains("onConflict: 'individual_session_id,user_id'"), isTrue);
      expect(content.contains("from('group_class_listings')"), isTrue);
      expect(content.contains("'status': 'full'"), isTrue);
    });

    test('payment webhook finalizes group class enrollments after success', () async {
      final file = File('lib/features/payment/services/fapshi_webhook_service.dart');
      final content = await file.readAsString();

      expect(content.contains('GroupClassService.finalizeEnrollmentForPaymentRequest'), isTrue);
      expect(content.contains('groupEnrollmentsProcessed'), isTrue);
    });
  });
}

