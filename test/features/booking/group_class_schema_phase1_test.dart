import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group class schema phase 1', () {
    test('migration creates listings and enrollments tables', () async {
      final migration = File(
        'supabase/migrations/079_group_class_listings_and_enrollments.sql',
      );
      final content = await migration.readAsString();

      expect(
        content.contains(
          'CREATE TABLE IF NOT EXISTS public.group_class_listings',
        ),
        isTrue,
      );
      expect(
        content.contains(
          'CREATE TABLE IF NOT EXISTS public.group_class_enrollments',
        ),
        isTrue,
      );
      expect(
        content.contains(
          'CONSTRAINT group_class_enrollments_unique_listing_user UNIQUE (listing_id, user_id)',
        ),
        isTrue,
      );
    });

    test('migration enables RLS and policies for listings and enrollments', () async {
      final migration = File(
        'supabase/migrations/079_group_class_listings_and_enrollments.sql',
      );
      final content = await migration.readAsString();

      expect(
        content.contains('ALTER TABLE public.group_class_listings ENABLE ROW LEVEL SECURITY'),
        isTrue,
      );
      expect(
        content.contains('ALTER TABLE public.group_class_enrollments ENABLE ROW LEVEL SECURITY'),
        isTrue,
      );
      expect(content.contains('CREATE POLICY group_class_listings_read_published'), isTrue);
      expect(content.contains('CREATE POLICY group_class_listings_insert_own'), isTrue);
      expect(content.contains('CREATE POLICY group_class_enrollments_select_own'), isTrue);
      expect(content.contains('CREATE POLICY group_class_enrollments_insert_own'), isTrue);
    });
  });
}

