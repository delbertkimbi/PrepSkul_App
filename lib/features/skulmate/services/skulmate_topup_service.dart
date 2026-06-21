import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

class SkulmateTopupService {
  /// Creates a payment request row that can be paid via existing Fapshi flow.
  /// After payment, webhook/confirmation converts payment amount into credits.
  static Future<String> createTopupPaymentRequest({
    required String packageName,
    required String planId,
    required int credits,
    required double amountXaf,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final dueDate = DateTime.now()
        .add(const Duration(days: 2))
        .toIso8601String();

    final payload = {
      'booking_request_id': null,
      'recurring_session_id': null,
      'student_id': userId,
      // Reuse current user as tutor_id for top-up purchases to satisfy existing schema.
      'tutor_id': userId,
      'amount': amountXaf,
      'original_amount': amountXaf,
      'discount_percent': 0,
      'discount_amount': 0,
      // DB check constraint only allows weekly | biweekly | monthly | trial.
      'payment_plan': 'monthly',
      'status': 'pending',
      'due_date': dueDate,
      'description': 'SkulMate $packageName',
      'metadata': {
        'is_skulmate_topup': true,
        'package_name': packageName,
        'plan_id': planId,
        'credits': credits,
        'location': 'online',
        'tutor_name': 'SkulMate',
      },
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await SupabaseService.client
        .from('payment_requests')
        .insert(payload)
        .select('id')
        .maybeSingle();

    final paymentRequestId = response?['id'] as String?;
    if (paymentRequestId == null || paymentRequestId.isEmpty) {
      LogService.error('Failed to create SkulMate top-up payment request');
      throw Exception('Could not start payment right now. Please try again.');
    }

    return paymentRequestId;
  }
}
