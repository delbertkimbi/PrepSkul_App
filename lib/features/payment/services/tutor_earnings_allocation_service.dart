import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/payment/services/payment_request_amounts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pre-allocates tutor pending earnings (85% session + 100% transport) when a
/// payment_request is marked paid. Idempotent per payment_request_id.
class TutorEarningsAllocationService {
  static SupabaseClient get _supabase => SupabaseService.client;

  static const _commissionRate = 0.15;
  static const _tutorRate = 0.85;

  static Future<int> allocateForPaymentRequest(String paymentRequestId) async {
    try {
      final existing = await _supabase
          .from('tutor_earnings')
          .select('id')
          .eq('payment_request_id', paymentRequestId)
          .limit(1);

      if ((existing as List).isNotEmpty) {
        LogService.info(
          'Tutor earnings already allocated for payment_request: $paymentRequestId',
        );
        return 0;
      }

      final pr = await _supabase
          .from('payment_requests')
          .select(
            'id, amount, tutor_id, recurring_session_id, status',
          )
          .eq('id', paymentRequestId)
          .maybeSingle();

      if (pr == null || pr['status'] != 'paid') return 0;

      final recurringSessionId = pr['recurring_session_id'] as String?;
      if (recurringSessionId == null) return 0;

      final rs = await _supabase
          .from('recurring_sessions')
          .select(
            'id, tutor_id, monthly_total, frequency, location, payment_plan, transportation_cost_per_session',
          )
          .eq('id', recurringSessionId)
          .maybeSingle();

      if (rs == null) return 0;

      final tutorId = (pr['tutor_id'] ?? rs['tutor_id']) as String;
      final frequency = (rs['frequency'] as num?)?.toInt() ?? 1;
      final paymentPlan = rs['payment_plan'] as String? ?? 'monthly';
      final weeks = PaymentRequestAmounts.weeksAheadForPaymentPlan(paymentPlan);
      final maxSessions = frequency * weeks;
      final monthlyTotal = (rs['monthly_total'] as num?)?.toDouble() ?? 0;
      final sessionsPerMonth = frequency * 4;
      final sessionFee = monthlyTotal / sessionsPerMonth;
      final platformFee = sessionFee * _commissionRate;
      final sessionTutorShare = sessionFee * _tutorRate;

      final location = (rs['location'] as String? ?? 'online').toLowerCase();
      final isOnsite = location == 'onsite' || location == 'hybrid';
      final transportDefault =
          (rs['transportation_cost_per_session'] as num?)?.toDouble() ?? 0;

      final sessions = await _supabase
          .from('individual_sessions')
          .select('id, transportation_cost')
          .eq('recurring_session_id', recurringSessionId)
          .eq('status', 'scheduled')
          .order('scheduled_date', ascending: true)
          .limit(maxSessions);

      final sessionList = (sessions as List).cast<Map<String, dynamic>>();
      if (sessionList.isEmpty) return 0;

      final now = DateTime.now().toIso8601String();
      final rows = <Map<String, dynamic>>[];

      for (final s in sessionList) {
        final transport = isOnsite
            ? ((s['transportation_cost'] as num?)?.toDouble() ??
                transportDefault)
            : 0.0;
        final totalTutor = sessionTutorShare + transport;
        final earningsType = transport > 0 ? 'combined' : 'session';

        rows.add({
          'tutor_id': tutorId,
          'session_id': s['id'],
          'recurring_session_id': recurringSessionId,
          'payment_request_id': paymentRequestId,
          'session_fee': sessionFee,
          'platform_fee': platformFee,
          'tutor_earnings': totalTutor,
          'transportation_earnings': isOnsite ? transport : 0,
          'earnings_type': earningsType,
          'earnings_status': 'pending',
          'added_to_pending_balance': true,
          'pending_balance_added_at': now,
          'created_at': now,
          'updated_at': now,
        });
      }

      await _supabase.from('tutor_earnings').insert(rows);
      LogService.success(
        'Allocated ${rows.length} pending tutor earnings for payment $paymentRequestId',
      );
      return rows.length;
    } catch (e) {
      LogService.error('Error allocating tutor earnings: $e');
      rethrow;
    }
  }
}
