import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group class DB runtime checks artifact', () {
    test('runtime SQL check file exists with core validations', () async {
      final file = File('docs/GROUP_CLASSES_DB_RUNTIME_CHECKS.sql');
      final content = await file.readAsString();

      expect(content.contains('group_class_listings'), isTrue);
      expect(content.contains('group_class_enrollments'), isTrue);
      expect(content.contains('idx_group_class_listings_share_token'), isTrue);
      expect(content.contains('group_class_enrollments_unique_listing_user'), isTrue);
      expect(content.contains('pg_policies'), isTrue);
      expect(content.contains('session_participants'), isTrue);
    });
  });
}

