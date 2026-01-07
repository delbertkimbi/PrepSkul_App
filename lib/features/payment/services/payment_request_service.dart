import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/features/booking/models/booking_request_model.dart';

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

      final paymentPlan = approvedRequest.paymentPlan.toLowerCase();
      
      if (paymentPlan == 'monthly') {
        return await _createSinglePaymentRequest(approvedRequest);
      } else if (paymentPlan == 'bi-weekly' || paymentPlan == 'biweekly') {
        return await _createRecurringPaymentRequests(approvedRequest, count: 2);
      } else if (paymentPlan == 'weekly') {
        return await _createRecurringPaymentRequests(approvedRequest, count: 4);
      } else {
        // Default to monthly
        return await _createSinglePaymentRequest(approvedRequest);
      }
    } catch (e) {
      LogService.error('Error creating payment request: $e');
      if (e.toString().contains('relation "payment_requests" does not exist')) {
        LogService.warning('payment_requests table does not exist - need to create migration');
        throw Exception('Payment requests table not found. Please run database migration.');
      }
      rethrow;
    }
  }

  /// Create a single payment request (for monthly plan)
  static Future<String> _createSinglePaymentRequest(
    BookingRequest approvedRequest,
  ) async {
    final paymentAmount = _calculatePaymentAmount(
      monthlyTotal: approvedRequest.monthlyTotal,
      paymentPlan: approvedRequest.paymentPlan,
    );

    final baseAmount = _getBaseAmountForPlan(
      monthlyTotal: approvedRequest.monthlyTotal,
      paymentPlan: approvedRequest.paymentPlan,
    );
    final pricingDetails = PricingService.calculateDiscount(
      monthlyTotal: baseAmount,
      paymentPlan: approvedRequest.paymentPlan,
    );

    final paymentRequestData = {
      'booking_request_id': approvedRequest.id,
      'recurring_session_id': null,
      'student_id': approvedRequest.studentId,
      'tutor_id': approvedRequest.tutorId,
      'amount': paymentAmount,
      'original_amount': approvedRequest.monthlyTotal,
      'discount_percent': pricingDetails['discountPercent'] as double,
      'discount_amount': pricingDetails['discountAmount'] as double,
      'payment_plan': approvedRequest.paymentPlan,
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
    LogService.success('Payment request created: $paymentRequestId (Amount: ${PricingService.formatPrice(paymentAmount)})');

    return paymentRequestId;
  }

  /// Create multiple payment requests for bi-weekly or weekly plans
  /// Returns the ID of the first payment request
  static Future<String> _createRecurringPaymentRequests(
    BookingRequest approvedRequest, {
    required int count,
  }) async {
    final baseAmount = _getBaseAmountForPlan(
      monthlyTotal: approvedRequest.monthlyTotal,
      paymentPlan: approvedRequest.paymentPlan,
    );
    final pricingDetails = PricingService.calculateDiscount(
      monthlyTotal: baseAmount,
      paymentPlan: approvedRequest.paymentPlan,
    );
    final paymentAmount = pricingDetails['finalAmount'] as double;

    final paymentPlan = approvedRequest.paymentPlan.toLowerCase();
    
    // Calculate interval between payments
    final daysInterval = paymentPlan == 'weekly' ? 7 : 14;
    
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
        'amount': paymentAmount,
        'original_amount': approvedRequest.monthlyTotal,
        'discount_percent': pricingDetails['discountPercent'] as double,
        'discount_amount': pricingDetails['discountAmount'] as double,
        'payment_plan': approvedRequest.paymentPlan,
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

  /// Get base amount for the payment plan period
  /// 
  /// - Monthly: monthlyTotal
  /// - Bi-weekly: monthlyTotal / 2
  /// - Weekly: monthlyTotal / 4
  static double _getBaseAmountForPlan({
    required double monthlyTotal,
    required String paymentPlan,
  }) {
    switch (paymentPlan.toLowerCase()) {
      case 'monthly':
        return monthlyTotal;
      case 'biweekly':
      case 'bi-weekly':
        return monthlyTotal / 2;
      case 'weekly':
        return monthlyTotal / 4;
      default:
        return monthlyTotal; // Default to monthly
    }
  }

  /// Calculate payment amount based on plan
  /// 
  /// - Monthly: monthlyTotal (with discount applied)
  /// - Bi-weekly: monthlyTotal / 2 (with discount applied)
  /// - Weekly: monthlyTotal / 4 (no discount)
  static double _calculatePaymentAmount({
    required double monthlyTotal,
    required String paymentPlan,
  }) {
    // Get base amount for the payment period
    final baseAmount = _getBaseAmountForPlan(
      monthlyTotal: monthlyTotal,
      paymentPlan: paymentPlan,
    );

    // Apply discount
    final pricingDetails = PricingService.calculateDiscount(
      monthlyTotal: baseAmount,
      paymentPlan: paymentPlan,
    );

    return pricingDetails['finalAmount'] as double;
  }

  /// Calculate due date based on payment plan
  /// 
  /// - Monthly: 7 days from now
  /// - Bi-weekly: 3 days from now
  /// - Weekly: 1 day from now
  static String _calculateDueDate(String paymentPlan) {
    final now = DateTime.now();
    late DateTime dueDate;

    switch (paymentPlan.toLowerCase()) {
      case 'monthly':
        dueDate = now.add(const Duration(days: 7));
        break;
      case 'biweekly':
      case 'bi-weekly':
        dueDate = now.add(const Duration(days: 3));
        break;
      case 'weekly':
        dueDate = now.add(const Duration(days: 1));
        break;
      default:
        dueDate = now.add(const Duration(days: 7)); // Default to 7 days
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
      final response = await SupabaseService.client
          .from('payment_requests')
          .select('id')
          .eq('booking_request_id', bookingRequestId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return response['id'] as String?;
      }
      return null;
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
