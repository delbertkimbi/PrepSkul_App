import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// GroupClassService
///
/// Handles listing/session linking and enrollment finalization for group classes.
class GroupClassService {
  GroupClassService._();

  static final _supabase = SupabaseService.client;

  /// Marks group enrollments as paid for a payment request, ensures a linked
  /// individual session exists for the listing, and upserts classroom
  /// participants for token authorization parity.
  static Future<int> finalizeEnrollmentForPaymentRequest(
    String paymentRequestId,
  ) async {
    if (paymentRequestId.isEmpty) return 0;

    try {
      final enrollments = await _supabase
          .from('group_class_enrollments')
          .select('id, listing_id, user_id, status')
          .eq('payment_request_id', paymentRequestId);

      if (enrollments.isEmpty) return 0;

      var processed = 0;
      for (final row in enrollments) {
        final enrollmentId = row['id'] as String?;
        final listingId = row['listing_id'] as String?;
        final learnerUserId = row['user_id'] as String?;
        if (enrollmentId == null ||
            listingId == null ||
            learnerUserId == null ||
            enrollmentId.isEmpty ||
            listingId.isEmpty ||
            learnerUserId.isEmpty) {
          continue;
        }

        if ((row['status'] as String?) != 'paid') {
          await _supabase
              .from('group_class_enrollments')
              .update({
                'status': 'paid',
                'paid_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', enrollmentId);
        }

        final sessionId = await _ensureListingSession(
          listingId: listingId,
          learnerUserId: learnerUserId,
        );
        if (sessionId == null) continue;

        await _upsertSessionParticipants(
          listingId: listingId,
          sessionId: sessionId,
          learnerUserId: learnerUserId,
        );
        await _updateListingStatusIfFull(listingId);
        processed += 1;
      }

      if (processed > 0) {
        LogService.success(
          '✅ Group class enrollment finalization complete for payment_request=$paymentRequestId (processed=$processed)',
        );
      }
      return processed;
    } catch (e) {
      LogService.warning(
        'Failed to finalize group class enrollment for payment request $paymentRequestId: $e',
      );
      return 0;
    }
  }

  static Future<String?> _ensureListingSession({
    required String listingId,
    required String learnerUserId,
  }) async {
    final listing = await _supabase
        .from('group_class_listings')
        .select(
          'id, tutor_id, title, starts_at, duration_minutes, individual_session_id',
        )
        .eq('id', listingId)
        .maybeSingle();
    if (listing == null) return null;

    final existingSessionId = listing['individual_session_id'] as String?;
    if (existingSessionId != null && existingSessionId.isNotEmpty) {
      return existingSessionId;
    }

    final tutorId = listing['tutor_id'] as String?;
    final startsAtRaw = listing['starts_at'] as String?;
    if (tutorId == null ||
        tutorId.isEmpty ||
        startsAtRaw == null ||
        startsAtRaw.isEmpty) {
      return null;
    }
    final startsAt = DateTime.tryParse(startsAtRaw);
    if (startsAt == null) return null;

    final inserted = await _supabase
        .from('individual_sessions')
        .insert({
          'recurring_session_id': null,
          'tutor_id': tutorId,
          'learner_id': learnerUserId,
          'parent_id': null,
          'status': 'scheduled',
          'scheduled_date': startsAt.toIso8601String().split('T')[0],
          'scheduled_time':
              '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}',
          'subject': (listing['title'] as String?) ?? 'Group Class',
          'duration_minutes': listing['duration_minutes'] as int? ?? 60,
          'location': 'online',
          'address': null,
          'location_description': null,
        })
        .select('id')
        .single();

    final sessionId = inserted['id'] as String?;
    if (sessionId == null || sessionId.isEmpty) return null;

    await _supabase
        .from('group_class_listings')
        .update({
          'individual_session_id': sessionId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', listingId);

    return sessionId;
  }

  static Future<void> _upsertSessionParticipants({
    required String listingId,
    required String sessionId,
    required String learnerUserId,
  }) async {
    final listing = await _supabase
        .from('group_class_listings')
        .select('tutor_id')
        .eq('id', listingId)
        .maybeSingle();
    final tutorId = listing?['tutor_id'] as String?;
    if (tutorId == null || tutorId.isEmpty) return;

    await _supabase.from('session_participants').upsert([
      {
        'individual_session_id': sessionId,
        'user_id': tutorId,
        'role': 'tutor',
      },
      {
        'individual_session_id': sessionId,
        'user_id': learnerUserId,
        'role': 'learner',
      },
    ], onConflict: 'individual_session_id,user_id');
  }

  static Future<void> _updateListingStatusIfFull(String listingId) async {
    final listing = await _supabase
        .from('group_class_listings')
        .select('capacity, status')
        .eq('id', listingId)
        .maybeSingle();
    if (listing == null) return;

    final capacity = listing['capacity'] as int?;
    final currentStatus = listing['status'] as String?;
    if (capacity == null || capacity <= 0 || currentStatus == 'full') return;

    final paidRows = await _supabase
        .from('group_class_enrollments')
        .select('id')
        .eq('listing_id', listingId)
        .eq('status', 'paid');

    if (paidRows.length >= capacity) {
      await _supabase
          .from('group_class_listings')
          .update({
            'status': 'full',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', listingId);
    }
  }
}

