import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group class join deep-link wiring', () {
    test('main deep link handler supports /join/class/:token', () async {
      final file = File('lib/main.dart');
      final content = await file.readAsString();

      expect(content.contains("path.startsWith('/join/class/')"), isTrue);
      expect(content.contains('GroupClassApiService.resolveJoinToken'), isTrue);
      expect(content.contains('AgoraVideoSessionScreen('), isTrue);
      expect(content.contains('GroupClassesDiscoveryScreen'), isTrue);
    });

    test('group class api service exposes resolveJoinToken', () async {
      final file = File('lib/features/group_classes/services/group_class_api_service.dart');
      final content = await file.readAsString();

      expect(content.contains('resolveJoinToken(String token)'), isTrue);
      expect(content.contains('/group-classes/join/'), isTrue);
      expect(content.contains("'Authorization': 'Bearer \$accessToken'"), isTrue);
    });

    test('share token migration exists', () async {
      final migration = File('supabase/migrations/080_group_class_share_tokens.sql');
      final content = await migration.readAsString();
      expect(content.contains('ADD COLUMN IF NOT EXISTS share_token'), isTrue);
      expect(content.contains('idx_group_class_listings_share_token'), isTrue);
    });
  });
}

