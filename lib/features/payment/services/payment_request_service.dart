import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';
import 'package:prepskul/features/payment/services/payment_request_amounts.dart';

/// Payment Request Service
/// 
/// Handles creation of payment requests when tutors approve bookings
/// Calculates payment amounts based on payment plan (monthly/bi-weekly/weekly)
/// Auto-launches payment screen for students

class PaymentRequestService {
  /// Create payment request when tutor approves booking
  /// 
  /// This is called automatically when a booking request is approved
  /// Creates payment request record(s) and calculates amount based on plan
  /// - Monthly: Creates 1 payment request
  /// - Bi-weekly: Creates 2 payment requests (first + second)
  /// - Weekly: Creates 4 payment requests (first + 3 more)
  static Future<String> createPaymentRequestOnApproval(
    BookingRequest approvedRequest,
  ) async {
    try {
      LogService.info('Creating payment request(s) for approved booking: ${approvedRequest.id}');

      // Idempotent: do not create duplicate rows on re-approval or double callbacks.
      final existingId = await _findExistingOpenPaymentRequestId(approvedRequest.id);
      if (existingId != null) {
        LogService.warning(
          'Payment request(s) already exist for ${approvedRequest.id}; '
          'reusing payable request $existingId',
        );
        return existingId;
      }

      // Trials: single charge at trial list price (booking_request_id = trial_sessions.id).
      if (approvedRequest.isTrial) {
        return await _createTrialPaymentRequest(approvedRequest);
      }

      // Handle multi-learner partial acceptance
      // If only some learners accepted, recalculate monthly total
      double? adjustedMonthlyTotal;
      if (approvedRequest.isMultiLearner && approvedRequest.acceptedLearnersCount > 0) {
        final totalLearners = approvedRequest.learnerLabels!.length;
        final acceptedCount = approvedRequest.acceptedLearnersCount;
        
        // If not all learners accepted, recalculate monthly total
        if (acceptedCount < totalLearners) {
          LogService.info('Partial acceptance: $acceptedCount of $totalLearners learners accepted. Recalculating payment...');
          
          // Estimate base per-learner monthly total
          // The original monthlyTotal includes multi-learner discounts
          // We approximate by dividing total by total learners (rough estimate)
          // Then recalculate with discount for accepted count only
          final estimatedBasePerLearner = approvedRequest.monthlyTotal / totalLearners;
          
          // Recalculate with multi-learner discount for accepted learners only
          adjustedMonthlyTotal = await PricingService.calculateMultiLearnerMonthlyTotal(
            baseMonthlyTotal: estimatedBasePerLearner,
            learnerCount: acceptedCount,
          );
          
          LogService.info('Recalculated monthly total: ${approvedRequest.monthlyTotal} -> $adjustedMonthlyTotal (for $acceptedCount learners)');
        }
      }

      final plan = PaymentRequestAmounts.normalizePlan(approvedRequest.paymentPlan);
      final count = PaymentRequestAmounts.installmentCountForPlan(plan);

      if (count == 1) {
        return await _createSinglePaymentRequest(
          approvedRequest,
          adjustedMonthlyTotal: adjustedMonthlyTotal,
        );
      }
      return await _createRecurringPaymentRequests(
        approvedRequest,
        count: count,
        adjustedMonthlyTotal: adjustedMonthlyTotal,
      );
    } catch (e) {
      LogService.error('Error creating payment request: $e');
      if (e.toString().contains('relation "payment_requests" does not exist')) {
        LogService.warning('payment_requests table does not exist - need to create migration');
        throw Exception('Payment requests table not found. Please run database migration.');
      }
      rethrow;
    }
  }

  /// Returns first pending installment id when payment rows already exist.
  static Future<String?> _findExistingOpenPaymentRequestId(
    String bookingRequestId,
  ) async {
    try {
      final response = await SupabaseService.client
          .from('payment_requests')
          .select('id, status, metadata, due_date, created_at')
          .eq('booking_request_id', bookingRequestId)
          .order('created_at', ascending: true);

      final rows = List<Map<String, dynamic>>.from(response as List);
      if (rows.isEmpty) return null;

      final pending = rows.where((r) => r['status'] == 'pending').toList();
      if (pending.isEmpty) {
        // Paid/failed history exists — do not create duplicates on approval retry.
        if (rows.isNotEmpty) {
          return rows.first['id'] as String?;
        }
        return null;
      }

      pending.sort((a, b) {
        final aMeta = a['metadata'];
        final bMeta = b['metadata'];
        final aNum = _paymentNumberFromMetadata(aMeta);
        final bNum = _paymentNumberFromMetadata(bMeta);
        if (aNum != null && bNum != null) return aNum.compareTo(bNum);
        final aDue = a['due_date'] as String? ?? '';
        final bDue = b['due_date'] as String? ?? '';
        return aDue.compareTo(bDue);
      });
      return pending.first['id'] as String?;
    } catch (e) {
      LogService.warning('Could not check existing payment requests: $e');
      return null;
    }
  }

  static int? _paymentNumberFromMetadata(dynamic metadata) {
    if (metadata is! Map) return null;
    final raw = metadata['payment_number'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }

  static PaymentInstallmentQuote _quoteForRequest(
    BookingRequest request, {
    double? adjustedSessionFeeMonthly,
  }) {
    return PaymentRequestAmounts.quoteInstallment(
      sessionFeeMonthly: adjustedSessionFeeMonthly ?? request.monthlyTotal,
      location: request.location,
      transportationPerSession: request.estimatedTransportationCost ?? 0.0,
      sessionsPerWeek: request.frequency,
      paymentPlan: request.paymentPlan,
    );
  }

  /// One-off trial payment (booking_request_id = trial_sessions.id).
  static Future<String> _createTrialPaymentRequest(
    BookingRequest approvedRequest,
  ) async {
    final quote = _quoteForRequest(approvedRequest);
    final dueDate = DateTime.now().add(const Duration(days: 3)).toIso8601String();

    final paymentRequestData = {
      'booking_request_id': approvedRequest.id,
      'recurring_session_id': null,
      'student_id': approvedRequest.studentId,
      'tutor_id': approvedRequest.tutorId,
      'amount': quote.installmentAmount,
      'original_amount': quote.installmentAmount,
      'discount_percent': 0.0,
      'discount_amount': 0.0,
      'payment_plan': 'trial',
      'status': 'pending',
      'due_date': dueDate,
      'description': 'Trial session with ${approvedRequest.tutorName}',
      'metadata': {
        'is_trial': true,
        'location': approvedRequest.location,
        'student_name': approvedRequest.studentName,
        'tutor_name': approvedRequest.tutorName,
        'payment_number': 1,
        'total_payments': 1,
        if (approvedRequest.subject != null) 'subject': approvedRequest.subject,
      },
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await SupabaseService.client
        .from('payment_requests')
        .insert(paymentRequestData)
        .select('id')
        .maybeSingle();

    if (response == null) {
      throw Exception('Failed to create trial payment request');
    }

    final id = response['id'] as String;
    LogService.success(
      'Trial payment request created: $id (${PricingService.formatPrice(quote.installmentAmount)})',
    );
    return id;
  }

  /// Create a single payment request (for monthly plan)
  static Future<String> _createSinglePaymentRequest(
    BookingRequest approvedRequest, {
    double? adjustedMonthlyTotal,
  }) async {
    final quote = _quoteForRequest(
      approvedRequest,
      adjustedSessionFeeMonthly: adjustedMonthlyTotal,
    );

    final paymentRequestData = {
      'booking_request_id': approvedRequest.id,
      'recurring_session_id': null,
      'student_id': approvedRequest.studentId,
      'tutor_id': approvedRequest.tutorId,
      'amount': quote.installmentAmount,
      'original_amount': quote.totalMonthlyAmount,
      'discount_percent': quote.discountPercent,
      'discount_amount': quote.discountAmount,
      'payment_plan': quote.paymentPlan,
      'status': 'pending',
      'due_date': _calculateDueDate(approvedRequest.paymentPlan),
      'description': _generatePaymentDescription(approvedRequest),
      'metadata': {
        'frequency': approvedRequest.frequency,
        'days': approvedRequest.days,
        'location': approvedRequest.location,
        'student_name': approvedRequest.studentName,
        'tutor_name': approvedRequest.tutorName,
        'payment_number': 1,
        'total_payments': 1,
      },
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await SupabaseService.client
        .from('payment_requests')
        .insert(paymentRequestData)
        .select('id')
        .maybeSingle();
    
    if (response == null) {
      throw Exception('Failed to create payment request');
    }

    final paymentRequestId = response['id'] as String;
    LogService.success(
      'Payment request created: $paymentRequestId '
      '(Amount: ${PricingService.formatPrice(quote.installmentAmount)})',
    );

    return paymentRequestId;
  }

  /// Create multiple payment requests for bi-weekly or weekly plans
  /// Returns the ID of the first payment request
  static Future<String> _createRecurringPaymentRequests(
    BookingRequest approvedRequest, {
    required int count,
    double? adjustedMonthlyTotal,
  }) async {
    final quote = _quoteForRequest(
      approvedRequest,
      adjustedSessionFeeMonthly: adjustedMonthlyTotal,
    );
    final estimatedTransportationCost =
        approvedRequest.estimatedTransportationCost ?? 0.0;
    final frequency = approvedRequest.frequency;
    final sessionsPerMonth = frequency * 4;
    final isOnsite = approvedRequest.location == 'onsite' ||
        approvedRequest.location == 'hybrid';
    final monthlyTransportationTotal = (isOnsite && estimatedTransportationCost > 0)
        ? estimatedTransportationCost * sessionsPerMonth
        : 0.0;

    final daysInterval =
        PaymentRequestAmounts.daysBetweenInstallments(approvedRequest.paymentPlan);
    
    // Calculate first due date
    final firstDueDate = _calculateDueDate(approvedRequest.paymentPlan);
    final firstDueDateTime = DateTime.parse(firstDueDate);

    final paymentRequests = <Map<String, dynamic>>[];

    // Create all payment requests
    for (int i = 0; i < count; i++) {
      final dueDate = firstDueDateTime.add(Duration(days: i * daysInterval));
      
      final paymentRequestData = {
        'booking_request_id': approvedRequest.id,
        'recurring_session_id': null,
        'student_id': approvedRequest.studentId,
        'tutor_id': approvedRequest.tutorId,
        'amount': quote.installmentAmount,
        'original_amount': quote.totalMonthlyAmount,
        'discount_percent': quote.discountPercent,
        'discount_amount': quote.discountAmount,
        'payment_plan': quote.paymentPlan,
        'status': 'pending',
        'due_date': dueDate.toIso8601String(),
        'description': _generateRecurringPaymentDescription(
          approvedRequest,
          paymentNumber: i + 1,
          totalPayments: count,
          dueDate: dueDate,
        ),
        'metadata': {
          'frequency': approvedRequest.frequency,
          'days': approvedRequest.days,
          'location': approvedRequest.location,
          'student_name': approvedRequest.studentName,
          'tutor_name': approvedRequest.tutorName,
          'payment_number': i + 1,
          'total_payments': count,
          'session_fee_monthly': approvedRequest.monthlyTotal,
          'transportation_cost_monthly': monthlyTransportationTotal,
          'transportation_cost_per_session': estimatedTransportationCost,
        },
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      paymentRequests.add(paymentRequestData);
    }

    // Batch insert all payment requests
    final response = await SupabaseService.client
        .from('payment_requests')
        .insert(paymentRequests)
        .select('id');

    if (response.isNotEmpty) {
      final firstPaymentRequestId = (response as List)[0]['id'] as String;
      LogService.success('Created $count payment request(s) for ${approvedRequest.paymentPlan} plan. First ID: $firstPaymentRequestId');
      return firstPaymentRequestId;
    } else {
      throw Exception('Failed to create payment requests');
    }
  }

  /// Generate description for recurring payment requests
  static String _generateRecurringPaymentDescription(
    BookingRequest request, {
    required int paymentNumber,
    required int totalPayments,
    required DateTime dueDate,
  }) {
    final plan = request.paymentPlan.toUpperCase();
    final frequency = request.frequency;
    final days = request.days.join(', ');
    final dueDateStr = '${dueDate.day}/${dueDate.month}/${dueDate.year}';
    
    return '$plan payment $paymentNumber of $totalPayments for $frequency session${frequency > 1 ? 's' : ''} per week ($days) with ${request.tutorName} - Due: $dueDateStr';
  }

  /// Calculate due date based on payment plan
  /// 
  /// - Monthly: 7 days from now
  /// - Bi-weekly: 3 days from now
  /// - Weekly: 1 day from now
  static String _calculateDueDate(String paymentPlan) {
    final now = DateTime.now();
    late DateTime dueDate;

    switch (PaymentRequestAmounts.normalizePlan(paymentPlan)) {
      case 'monthly':
        dueDate = now.add(const Duration(days: 7));
        break;
      case 'biweekly':
        dueDate = now.add(const Duration(days: 3));
        break;
      case 'weekly':
        dueDate = now.add(const Duration(days: 1));
        break;
      case 'trial':
        dueDate = now.add(const Duration(days: 3));
        break;
      default:
        dueDate = now.add(const Duration(days: 7));
    }

    return dueDate.toIso8601String();
  }

  /// Generate payment description
  static String _generatePaymentDescription(BookingRequest request) {
    final plan = request.paymentPlan.toUpperCase();
    final frequency = request.frequency;
    final days = request.days.join(', ');
    
    return '$plan payment for $frequency session${frequency > 1 ? 's' : ''} per week ($days) with ${request.tutorName}';
  }

  /// Get payment request by ID
  static Future<Map<String, dynamic>?> getPaymentRequest(String paymentRequestId) async {
    try {
      final response = await SupabaseService.client
          .from('payment_requests')
          .select()
          .eq('id', paymentRequestId)
          .maybeSingle();

      return response;
    } catch (e) {
      LogService.error('Error fetching payment request: $e');
      return null;
    }
  }

  /// Get pending payment requests for a student
  static Future<List<Map<String, dynamic>>> getPendingPaymentRequests(String studentId) async {
    try {
      final response = await SupabaseService.client
          .from('payment_requests')
          .select()
          .eq('student_id', studentId)
          .eq('status', 'pending')
          .order('due_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      LogService.error('Error fetching pending payment requests: $e');
      return [];
    }
  }

  /// Get all payment requests for a student (all statuses)
  static Future<List<Map<String, dynamic>>> getAllPaymentRequests(String studentId) async {
    try {
      // Use left join instead of inner join to handle cases where booking_request might be missing
      // This prevents failures when payment_requests exist but booking_requests don't
      final response = await SupabaseService.client
          .from('payment_requests')
          .select('''
            *,
            booking_requests(
              id,
              tutor_id,
              student_id,
              tutor_name,
              student_name
            )
          ''')
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      // Safely handle response
      final List<Map<String, dynamic>> paymentRequests = [];
      final responseList = response as List;
      
      for (var item in responseList) {
        try {
          // Ensure item is a Map
          if (item is Map<String, dynamic>) {
            paymentRequests.add(item);
          } else {
            LogService.warning('Skipping invalid payment request format: ${item.runtimeType}');
          }
        } catch (parseError) {
          LogService.warning('Error parsing payment request: $parseError');
          // Continue processing other items
        }
      }
      
      return paymentRequests;
    } catch (e) {
      LogService.error('Error fetching all payment requests: $e');
      LogService.error('Stack trace: ${StackTrace.current}');
      // Check if it's a table not found error
      if (e.toString().contains('does not exist') || 
          e.toString().contains('relation') ||
          e.toString().contains('PGRST')) {
        LogService.warning('Payment requests table might not exist yet');
      }
      return [];
    }
  }

  /// Update payment request status
  static Future<void> updatePaymentRequestStatus(
    String paymentRequestId,
    String status, {
    String? fapshiTransId,
    String? paymentId,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
        if (fapshiTransId != null) 'fapshi_trans_id': fapshiTransId,
        if (paymentId != null) 'payment_id': paymentId,
        if (status == 'paid') 'paid_at': DateTime.now().toIso8601String(),
        if (status == 'failed') 'failed_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService.client
          .from('payment_requests')
          .update(updateData)
          .eq('id', paymentRequestId);

      LogService.success('Payment request status updated: $paymentRequestId -> $status');
    } catch (e) {
      LogService.error('Error updating payment request status: $e');
      rethrow;
    }
  }
  /// Link payment request to recurring session
  /// 
  /// Called after recurring session is created to link the payment request
  static Future<void> linkPaymentRequestToRecurringSession(
    String paymentRequestId,
    String recurringSessionId,
  ) async {
    try {
      await SupabaseService.client
          .from('payment_requests')
          .update({
            'recurring_session_id': recurringSessionId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentRequestId);

      LogService.success('Payment request linked to recurring session: '
          '$paymentRequestId -> $recurringSessionId');
    } catch (e) {
      LogService.error('Error linking payment request to recurring session: $e');
      rethrow;
    }
  }

  /// Get payment request by booking request ID
  /// 
  /// Returns the payment request created for a specific booking request
  static Future<String?> getPaymentRequestIdByBookingRequestId(
    String bookingRequestId,
  ) async {
    try {
      final pendingId = await _findExistingOpenPaymentRequestId(bookingRequestId);
      if (pendingId != null) return pendingId;

      final response = await SupabaseService.client
          .from('payment_requests')
          .select('id')
          .eq('booking_request_id', bookingRequestId)
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      return response?['id'] as String?;
    } catch (e) {
      LogService.error('Error fetching payment request by booking request ID: $e');
      return null;
    }
  }

  /// Get payment request with full details by booking request ID
  /// 
  /// Returns the payment request with status and other details
  static Future<Map<String, dynamic>?> getPaymentRequestByBookingRequestId(
    String bookingRequestId,
  ) async {
    try {
      final response = await SupabaseService.client
          .from('payment_requests')
          .select('id, status, booking_request_id, recurring_session_id')
          .eq('booking_request_id', bookingRequestId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      LogService.error('Error fetching payment request by booking request ID: $e');
      return null;
    }
  }
}
