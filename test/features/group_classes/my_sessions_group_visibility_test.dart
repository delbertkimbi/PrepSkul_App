import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('My Sessions group-class visibility', () {
    test('individual session service includes session_participants sessions', () async {
      final file = File('lib/features/booking/services/individual_session_service.dart');
      final content = await file.readAsString();

      expect(content.contains("from('session_participants')"), isTrue);
      expect(content.contains("individual_sessions("), isTrue);
      expect(content.contains("eq('user_id', userId)"), isTrue);
    });

    test('individual session service includes paid group class enrollment sessions', () async {
      final file = File('lib/features/booking/services/individual_session_service.dart');
      final content = await file.readAsString();

      expect(content.contains("from('group_class_enrollments')"), isTrue);
      expect(content.contains("group_class_listings(individual_session_id)"), isTrue);
      expect(content.contains("eq('status', 'paid')"), isTrue);
      expect(content.contains('paidGroupSessionIds'), isTrue);
    });
  });
}

