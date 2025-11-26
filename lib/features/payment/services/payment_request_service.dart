import 'package:prepskul/core/services/supabase_service.dart';
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
  /// Creates payment request record and calculates amount based on plan
  static Future<String> createPaymentRequestOnApproval(
    BookingRequest approvedRequest,
  ) async {
    try {
      print('💰 Creating payment request for approved booking: ${approvedRequest.id}');

      // Calculate payment amount based on plan
      // Monthly: monthlyTotal (with discount)
      // Bi-weekly: monthlyTotal / 2 (with discount)
      // Weekly: monthlyTotal / 4 (no discount)
      final paymentAmount = _calculatePaymentAmount(
        monthlyTotal: approvedRequest.monthlyTotal,
        paymentPlan: approvedRequest.paymentPlan,
      );

      // Get pricing details (discount, etc.) for the actual payment period
      final baseAmount = _getBaseAmountForPlan(
        monthlyTotal: approvedRequest.monthlyTotal,
        paymentPlan: approvedRequest.paymentPlan,
      );
      final pricingDetails = PricingService.calculateDiscount(
        monthlyTotal: baseAmount,
        paymentPlan: approvedRequest.paymentPlan,
      );

      // Create payment request data
      final paymentRequestData = {
        'booking_request_id': approvedRequest.id,
        'recurring_session_id': null, // Will be set when recurring session is created
        'student_id': approvedRequest.studentId,
        'tutor_id': approvedRequest.tutorId,
        'amount': paymentAmount,
        'original_amount': approvedRequest.monthlyTotal,
        'discount_percent': pricingDetails['discountPercent'] as double,
        'discount_amount': pricingDetails['discountAmount'] as double,
        'payment_plan': approvedRequest.paymentPlan,
        'status': 'pending', // pending, paid, failed, expired
        'due_date': _calculateDueDate(approvedRequest.paymentPlan),
        'description': _generatePaymentDescription(approvedRequest),
        'metadata': {
          'frequency': approvedRequest.frequency,
          'days': approvedRequest.days,
          'location': approvedRequest.location,
          'student_name': approvedRequest.studentName,
          'tutor_name': approvedRequest.tutorName,
        },
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert into payment_requests table
      final response = await SupabaseService.client
          .from('payment_requests')
          .insert(paymentRequestData)
          .select('id')
          .single();

      final paymentRequestId = response['id'] as String;
      print('✅ Payment request created: $paymentRequestId (Amount: ${PricingService.formatPrice(paymentAmount)})');

      return paymentRequestId;
    } catch (e) {
      print('❌ Error creating payment request: $e');
      // Check if table doesn't exist
      if (e.toString().contains('relation "payment_requests" does not exist')) {
        print('⚠️ payment_requests table does not exist - need to create migration');
        throw Exception('Payment requests table not found. Please run database migration.');
      }
      rethrow;
    }
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
      print('❌ Error fetching payment request: $e');
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
      print('❌ Error fetching pending payment requests: $e');
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
            print('⚠️ Skipping invalid payment request format: ${item.runtimeType}');
          }
        } catch (parseError) {
          print('⚠️ Error parsing payment request: $parseError');
          // Continue processing other items
        }
      }
      
      return paymentRequests;
    } catch (e) {
      print('❌ Error fetching all payment requests: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      // Check if it's a table not found error
      if (e.toString().contains('does not exist') || 
          e.toString().contains('relation') ||
          e.toString().contains('PGRST')) {
        print('⚠️ Payment requests table might not exist yet');
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

      print('✅ Payment request status updated: $paymentRequestId -> $status');
    } catch (e) {
      print('❌ Error updating payment request status: $e');
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

      print('✅ Payment request linked to recurring session: '
          '$paymentRequestId -> $recurringSessionId');
    } catch (e) {
      print('❌ Error linking payment request to recurring session: $e');
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
      print('❌ Error fetching payment request by booking request ID: $e');
      return null;
    }
  }
}
