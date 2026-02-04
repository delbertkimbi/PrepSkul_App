import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';
import 'package:prepskul/features/booking/services/session_payment_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Tutor Payout Service
/// 
/// Handles tutor payout requests and Fapshi disbursement integration
/// Tutors can request payouts from their active balance
class TutorPayoutService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Request a payout
  /// 
  /// Creates a payout request for the tutor's active balance
  /// Minimum payout amount: 5,000 XAF
  /// 
  /// Parameters:
  /// - [amount]: Amount to withdraw (must be <= active balance)
  /// - [phoneNumber]: Phone number for Fapshi disbursement
  /// - [notes]: Optional notes for the payout request
  static Future<Map<String, dynamic>> requestPayout({
    required double amount,
    required String phoneNumber,
    String? notes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Validate minimum amount
      if (amount < 5000) {
        throw Exception('Minimum payout amount is 5,000 XAF');
      }

      // Get tutor's active balance
      final walletBalances = await SessionPaymentService.getTutorWalletBalances(userId);
      final activeBalance = walletBalances['active_balance'] as double;

      if (amount > activeBalance) {
        throw Exception('Insufficient balance. Available: ${activeBalance.toStringAsFixed(0)} XAF');
      }

      // Create payout request
      final payoutRequest = {
        'tutor_id': userId,
        'amount': amount,
        'phone_number': phoneNumber,
        'status': 'pending',
        'notes': notes,
        'requested_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('payout_requests')
          .insert(payoutRequest)
          .select()
          .maybeSingle();
      
      if (response == null) {
        throw Exception('Failed to create payout request');
      }

      // Mark earnings as "requested for payout"
      // This prevents double-withdrawal
      await _supabase
          .from('tutor_earnings')
          .update({
            'payout_request_id': response['id'],
            'earnings_status': 'paid_out',
            'paid_out_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('tutor_id', userId)
          .eq('earnings_status', 'active')
          .limit((amount / 1000).ceil()); // Approximate number of earnings records

      LogService.success('Payout request created: ${response['id']}');

      // Send notification to admin
      try {
        await _notifyAdminOfPayoutRequest(
          payoutRequestId: response['id'] as String,
          tutorId: userId,
          amount: amount,
        );
      } catch (e) {
        LogService.warning('Failed to notify admin of payout request: $e');
      }

      return response;
    } catch (e) {
      LogService.error('Error requesting payout: $e');
      rethrow;
    }
  }

  /// Get payout history for tutor
  static Future<List<Map<String, dynamic>>> getPayoutHistory(String tutorId) async {
    try {
      final payouts = await _supabase
          .from('payout_requests')
          .select('*')
          .eq('tutor_id', tutorId)
          .order('requested_at', ascending: false);

      return (payouts as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.error('Error fetching payout history: $e');
      return [];
    }
  }

  /// Get pending payout requests (for admin)
  static Future<List<Map<String, dynamic>>> getPendingPayouts() async {
    try {
      final payouts = await _supabase
          .from('payout_requests')
          .select('''
            *,
            profiles!payout_requests_tutor_id_fkey(
              full_name,
              email,
              phone_number
            )
          ''')
          .eq('status', 'pending')
          .order('requested_at', ascending: true);

      return (payouts as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.error('Error fetching pending payouts: $e');
      return [];
    }
  }

  /// Process payout via Fapshi disbursement (admin only)
  ///
  /// Calls PrepSkul_Web API to process payout via Fapshi disbursement.
  /// The server updates payout status and notifies the tutor.
  static Future<void> processPayout({
    required String payoutRequestId,
    required String adminId,
  }) async {
    try {
      final payoutRequest = await _supabase
          .from('payout_requests')
          .select('*')
          .eq('id', payoutRequestId)
          .maybeSingle();

      if (payoutRequest == null) {
        throw Exception('Payout request not found: $payoutRequestId');
      }

      if (payoutRequest['status'] != 'pending') {
        throw Exception('Payout request is not pending');
      }

      final accessToken = SupabaseService.client.auth.currentSession?.accessToken;
      if (accessToken == null) {
        throw Exception('Not authenticated');
      }

      final apiUrl = AppConfig.effectiveApiBaseUrl;
      final response = await http.post(
        Uri.parse('$apiUrl/payouts/process'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'payoutRequestId': payoutRequestId,
          'adminId': adminId,
        }),
      );

      if (response.statusCode == 200) {
        LogService.success('Payout processing initiated via Fapshi: $payoutRequestId');
        return;
      }

      final body = response.body;
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final err = json['error'] as String? ?? body;
        throw Exception(err);
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception(body);
      }
    } catch (e) {
      LogService.error('Error processing payout: $e');
      rethrow;
    }
  }

  /// Notify admin of payout request
  static Future<void> _notifyAdminOfPayoutRequest({
    required String payoutRequestId,
    required String tutorId,
    required double amount,
  }) async {
    try {
      // Get tutor profile
      final tutorProfile = await _supabase
          .from('profiles')
          .select('full_name, email')
          .eq('id', tutorId)
          .maybeSingle();

      final tutorName = tutorProfile?['full_name'] as String? ?? 'Tutor';

      // Create notification for admin (you may need to get admin IDs)
      // For now, log it
      LogService.info('Payout request created: $payoutRequestId for tutor $tutorName (${amount.toStringAsFixed(0)} XAF)');
    } catch (e) {
      LogService.warning('Error notifying admin: $e');
    }
  }

  /// Notify tutor of payout status
  static Future<void> _notifyTutorOfPayoutStatus({
    required String tutorId,
    required String payoutRequestId,
    required String status,
    required double amount,
  }) async {
    try {
      final statusMessages = {
        'processing': 'Your payout request is being processed',
        'completed': 'Your payout has been completed',
        'failed': 'Your payout request failed',
      };

      await _supabase.from('notifications').insert({
        'user_id': tutorId,
        'type': 'payout_status',
        'notification_type': 'payout_status',
        'title': status == 'processing' ? 'Payout Processing' : 
                 status == 'completed' ? 'Payout Completed' : 
                 'Payout Failed',
        'message': '${statusMessages[status] ?? 'Payout status updated'}: ${amount.toStringAsFixed(0)} XAF',
        'priority': status == 'failed' ? 'high' : 'normal',
        'is_read': false,
        'action_url': '/earnings/payouts',
        'action_text': 'View Payout',
        'icon': status == 'completed' ? '✅' : status == 'failed' ? '❌' : '💰',
        'metadata': {
          'payout_request_id': payoutRequestId,
          'status': status,
          'amount': amount,
        },
      });
    } catch (e) {
      LogService.warning('Error notifying tutor: $e');
    }
  }
}
