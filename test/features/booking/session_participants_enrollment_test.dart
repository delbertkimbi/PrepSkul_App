import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Session participants enrollment pipeline', () {
    test('trial session service upserts participant rows idempotently', () async {
      final file = File('lib/features/booking/services/trial_session_service.dart');
      final content = await file.readAsString();

      expect(content.contains("from('session_participants').upsert("), isTrue);
      expect(content.contains("onConflict: 'trial_session_id,user_id'"), isTrue);
      expect(content.contains("onConflict: 'individual_session_id,user_id'"), isTrue);
    });

    test('recurring session service upserts generated session participants', () async {
      final file = File('lib/features/booking/services/recurring_session_service.dart');
      final content = await file.readAsString();

      expect(content.contains("select('id, tutor_id, learner_id, parent_id')"), isTrue);
      expect(content.contains("from('session_participants').upsert("), isTrue);
      expect(content.contains("onConflict: 'individual_session_id,user_id'"), isTrue);
    });

    test('backfill migration exists for legacy sessions', () async {
      final migration = File('supabase/migrations/077_backfill_session_participants.sql');
      final content = await migration.readAsString();

      expect(content.contains('INSERT INTO public.session_participants'), isTrue);
      expect(content.contains('FROM public.individual_sessions'), isTrue);
      expect(content.contains('FROM public.trial_sessions'), isTrue);
    });
  });
}

