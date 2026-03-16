import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/push_notification_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Schedules on-device payment reminders for pending payment requests.
/// This is a reliable fallback when remote reminder scheduling is unavailable.
class PaymentLocalReminderService {
  static int _stableReminderId(String paymentRequestId, String suffix) {
    final seed = '$paymentRequestId-$suffix';
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return 900000 + (hash % 90000);
  }

  static Future<void> reschedulePendingForCurrentUser() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final rows = await SupabaseService.client
          .from('payment_requests')
          .select('id, due_date, amount, metadata')
          .eq('student_id', userId)
          .eq('status', 'pending')
          .gte('due_date', DateTime.now().toIso8601String())
          .order('due_date', ascending: true)
          .limit(25);

      for (final row in rows as List) {
        final id = row['id'] as String?;
        final dueDateRaw = row['due_date'] as String?;
        if (id == null || dueDateRaw == null) continue;

        final dueDate = DateTime.tryParse(dueDateRaw);
        if (dueDate == null) continue;
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        final metadata = (row['metadata'] as Map?)?.cast<String, dynamic>();
        final tutorName = metadata?['tutor_name'] as String? ?? 'your tutor';

        final reminders =
            <
              ({
                DateTime when,
                String suffix,
                String title,
                String body,
                bool urgent,
              })
            >[
              (
                when: dueDate.subtract(const Duration(days: 2)),
                suffix: '2d',
                title: 'Payment reminder',
                body:
                    'Your payment with $tutorName (${amount.toStringAsFixed(0)} XAF) is due in 2 days.',
                urgent: false,
              ),
              (
                when: dueDate.subtract(const Duration(days: 1)),
                suffix: '1d',
                title: 'Payment due tomorrow',
                body:
                    'Your payment with $tutorName (${amount.toStringAsFixed(0)} XAF) is due tomorrow.',
                urgent: false,
              ),
              (
                when: dueDate.subtract(const Duration(hours: 2)),
                suffix: '2h',
                title: 'Payment due soon',
                body:
                    'Your payment with $tutorName (${amount.toStringAsFixed(0)} XAF) is due in 2 hours.',
                urgent: true,
              ),
            ];

        for (final r in reminders) {
          if (!r.when.isAfter(DateTime.now())) continue;
          await PushNotificationService().scheduleLocalOneTimeReminder(
            id: _stableReminderId(id, r.suffix),
            title: r.title,
            body: r.body,
            when: r.when,
            urgent: r.urgent,
            payload: {
              'type': 'payment_reminder',
              'actionUrl': '/payments/$id',
              'payment_request_id': id,
              'reminder_type': r.suffix,
            },
          );
        }
      }
    } catch (e) {
      LogService.warning('Could not reschedule local payment reminders: $e');
    }
  }
}
