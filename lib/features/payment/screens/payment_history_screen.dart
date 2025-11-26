import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/widgets/branded_snackbar.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/pricing_service.dart';
import 'package:prepskul/features/payment/services/payment_request_service.dart';
import 'package:prepskul/features/payment/screens/booking_payment_screen.dart';
import 'package:prepskul/features/booking/screens/trial_payment_screen.dart';
import 'package:prepskul/features/booking/models/trial_session_model.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';

/// Payment History Screen
///
/// Displays all payment history for the current user:
/// - Payment requests (regular bookings)
/// - Trial session payments
/// - Session payments (completed sessions)
///
/// Features:
/// - Filter by status (all, pending, paid, failed)
/// - Retry failed payments
/// - View payment details
/// - Payment status indicators

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, pending, paid, failed

  // Payment data
  List<Map<String, dynamic>> _paymentRequests = [];
  List<Map<String, dynamic>> _trialPayments = [];
  List<Map<String, dynamic>> _sessionPayments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Load all payment types independently - don't let one failure break others
      // Load payment requests
      try {
        _paymentRequests = await PaymentRequestService.getAllPaymentRequests(
          userId,
        );
        print('✅ Loaded ${_paymentRequests.length} payment requests');
      } catch (e) {
        print('⚠️ Error loading payment requests: $e');
        _paymentRequests = [];
        // Don't throw - continue loading other payment types
      }

      // Load trial session payments
      try {
        _trialPayments = await _loadTrialPayments(userId);
        print('✅ Loaded ${_trialPayments.length} trial payments');
      } catch (e) {
        print('⚠️ Error loading trial payments: $e');
        _trialPayments = [];
        // Don't throw - continue loading other payment types
      }

      // Load session payments
      try {
        _sessionPayments = await _loadSessionPayments(userId);
        print('✅ Loaded ${_sessionPayments.length} session payments');
      } catch (e) {
        print('⚠️ Error loading session payments: $e');
        _sessionPayments = [];
        // Don't throw - continue showing what we can load
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }

      // Don't show error if all lists are empty - empty states will handle it gracefully
      // This is expected for new users who haven't made any payments yet
      // Also don't show error for database schema issues (tables/columns not found)
      // These are handled gracefully by returning empty lists
    } catch (e) {
      print('❌ Critical error loading payments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }

      // Only show error if it's NOT a database schema issue (table/column not found)
      // Schema issues are expected during development and should be handled silently
      final errorString = e.toString().toLowerCase();
      final isSchemaError =
          errorString.contains('does not exist') ||
          errorString.contains('relation') ||
          errorString.contains('pgrst') ||
          errorString.contains('schema cache') ||
          errorString.contains('column') && errorString.contains('not found');

      // Don't show error for schema issues or when all lists are empty
      // Empty states will handle the display gracefully
      if (mounted &&
          !isSchemaError &&
          (_paymentRequests.isNotEmpty ||
              _trialPayments.isNotEmpty ||
              _sessionPayments.isNotEmpty)) {
        // Only show error if there's actual data that failed to load
        BrandedSnackBar.showError(
          context,
          'Unable to load payment history. Please try again later.',
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadTrialPayments(String userId) async {
    try {
      final response = await SupabaseService.client
          .from('trial_sessions')
          .select('''
            id,
            tutor_id,
            learner_id,
            subject,
            trial_fee,
            payment_status,
            fapshi_trans_id,
            payment_initiated_at,
            scheduled_date,
            scheduled_time,
            status,
            created_at
          ''')
          .or(
            'learner_id.eq.$userId,parent_id.eq.$userId,requester_id.eq.$userId',
          )
          .order('created_at', ascending: false);

      // Safely handle response
      try {
        return List<Map<String, dynamic>>.from(response);
      } catch (castError) {
        print('⚠️ Error casting trial payments response: $castError');
        // Try to parse manually if direct cast fails
        return response.whereType<Map<String, dynamic>>().toList();
      }
    } catch (e) {
      // Silently handle schema errors - don't log warnings
      final errorString = e.toString().toLowerCase();
      final isSchemaError =
          errorString.contains('does not exist') ||
          errorString.contains('relation') ||
          errorString.contains('pgrst') ||
          errorString.contains('schema cache') ||
          (errorString.contains('column') && errorString.contains('not found'));

      if (!isSchemaError) {
        print('❌ Error loading trial payments: $e');
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadSessionPayments(String userId) async {
    try {
      // Check if session_payments table exists by trying a simple query first
      try {
        // Try to load session payments with proper join to individual_sessions
        // Use the correct relationship name
        final response = await SupabaseService.client
            .from('session_payments')
            .select('''
              *,
              individual_sessions:session_id(
                id,
                scheduled_date,
                scheduled_time,
                subject,
                tutor_id,
                learner_id,
                parent_id
              )
            ''')
            .order('created_at', ascending: false);

        // Filter by user ID manually since we can't filter on joined table directly
        final allPayments = List<Map<String, dynamic>>.from(response);
        final userPayments = allPayments.where((payment) {
          final session =
              payment['individual_sessions'] as Map<String, dynamic>?;
          if (session == null) return false;
          final learnerId = session['learner_id'] as String?;
          final parentId = session['parent_id'] as String?;
          return learnerId == userId || parentId == userId;
        }).toList();

        return userPayments;
      } catch (joinError) {
        // Silently handle schema errors
        final errorString = joinError.toString().toLowerCase();
        final isSchemaError =
            errorString.contains('does not exist') ||
            errorString.contains('relation') ||
            errorString.contains('pgrst') ||
            errorString.contains('schema cache') ||
            (errorString.contains('table') &&
                errorString.contains('not found'));

        if (!isSchemaError) {
          print('⚠️ Join query failed, trying direct query: $joinError');
        }

        // If join fails, try loading from individual_sessions and get payment info
        try {
          final sessionsResponse = await SupabaseService.client
              .from('individual_sessions')
              .select('''
                id,
                scheduled_date,
                scheduled_time,
                subject,
                tutor_id,
                learner_id,
                parent_id
              ''')
              .or('learner_id.eq.$userId,parent_id.eq.$userId')
              .order('scheduled_date', ascending: false)
              .limit(50); // Limit to prevent too much data

          final sessions = List<Map<String, dynamic>>.from(sessionsResponse);

          // For each session, try to get payment info
          final paymentsWithSessions = <Map<String, dynamic>>[];
          for (final session in sessions) {
            try {
              final sessionId = session['id'] as String;
              final paymentResponse = await SupabaseService.client
                  .from('session_payments')
                  .select('*')
                  .eq('session_id', sessionId)
                  .maybeSingle();

              if (paymentResponse != null) {
                paymentsWithSessions.add({
                  ...Map<String, dynamic>.from(paymentResponse),
                  'individual_sessions': session,
                });
              }
            } catch (e) {
              // Skip if payment not found for this session
              continue;
            }
          }

          return paymentsWithSessions;
        } catch (directError) {
          print('⚠️ Direct query also failed: $directError');
          // If both fail, return empty list (table might not exist)
          return [];
        }
      }
    } catch (e) {
      print('❌ Error loading session payments: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      // Check if it's a table not found error
      if (e.toString().contains('does not exist') ||
          e.toString().contains('relation') ||
          e.toString().contains('PGRST') ||
          e.toString().contains('schema cache')) {
        print(
          '⚠️ Session payments or individual_sessions table might not exist yet',
        );
      }
      return [];
    }
  }

  List<Map<String, dynamic>> _getFilteredPayments(
    List<Map<String, dynamic>> payments,
  ) {
    if (_selectedFilter == 'all') return payments;

    return payments.where((payment) {
      final status = _getPaymentStatus(context, payment);
      return status.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();
  }

  // String _getPaymentStatus(context, BuildContext context, Map<String, dynamic> payment) {
  //     final t = AppLocalizations.of(context)!;
  //   // Prefer explicit payment_status when available (trial and session payments),
  //   // fall back to generic status (payment requests, trials without payment_status).
  //   if (payment.containsKey('payment_status')) {
  //     final raw = (payment['payment_status'] as String? ?? 'pending').toLowerCase();

  //     // Normalize various underlying states into the 3 UI filters:
  //     // - Treat "unpaid" and "processing" as "pending" so they appear under Pending.
  //     // - Keep "paid" and "failed" as-is.
  //     switch (raw) {
  //       case 'unpaid':
  //       case 'processing':
  //         return 'pending';
  //       case 'paid':
  //       case 'failed':
  //         return raw;
  //       default:
  //         return raw;
  //     }
  //   }

  //   if (payment.containsKey('status')) {
  //     return (payment['status'] as String? ?? 'pending').toLowerCase();
  //   }

  //   return 'pending';
  // }

  String _getPaymentStatus(BuildContext context, Map<String, dynamic> payment) {
  // Optional: t is here if you later want localized error messages.
  final t = AppLocalizations.of(context)!;

  // Prefer explicit payment_status when available (trial and session payments),
  // fall back to generic status (payment requests, trials without payment_status).
  if (payment.containsKey('payment_status')) {
    final raw = (payment['payment_status'] as String? ?? 'pending').toLowerCase();

    // Normalize to our three filters.
    switch (raw) {
      case 'unpaid':
      case 'processing':
        return 'pending';
      case 'paid':
      case 'failed':
        return raw;
      default:
        return 'pending';
    }
  }

  // Fallback for older records: use generic status field.
  final genericStatus = (payment['status'] as String? ?? 'pending').toLowerCase();
  switch (genericStatus) {
    case 'paid':
    case 'failed':
      return genericStatus;
    default:
      return 'pending';
  }
}

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t.paymentHistoryTitle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: t.paymentHistoryTabBookings),
            Tab(text: t.paymentHistoryTabTrials),
            Tab(text: t.paymentHistoryTabSessions),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterChip('all', t.paymentHistoryFilterAll),
                const SizedBox(width: 8),
                _buildFilterChip('pending', t.paymentHistoryFilterPending),
                const SizedBox(width: 8),
                _buildFilterChip('paid', t.paymentHistoryFilterPaid),
                const SizedBox(width: 8),
                _buildFilterChip('failed', t.paymentHistoryFilterFailed),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPaymentRequestsTab(),
                      _buildTrialPaymentsTab(),
                      _buildSessionPaymentsTab(),
                      
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
      ),
    );
  }

  Widget _buildPaymentRequestsTab() {
    final filtered = _getFilteredPayments(_paymentRequests);

    if (filtered.isEmpty) {
      return _buildEmptyState('No payment requests found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _buildPaymentRequestCard(filtered[index]);
      },
    );
  }

  Widget _buildTrialPaymentsTab() {
    final filtered = _getFilteredPayments(_trialPayments);

    if (filtered.isEmpty) {
      return _buildEmptyState('No trial payments found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _buildTrialPaymentCard(filtered[index]);
      },
    );
  }

  Widget _buildSessionPaymentsTab() {
    final filtered = _getFilteredPayments(_sessionPayments);

    if (filtered.isEmpty) {
      return _buildEmptyState('No session payments found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _buildSessionPaymentCard(filtered[index]);
      },
    );
  }

  Widget _buildPaymentRequestCard(Map<String, dynamic> payment) {
    final status = payment['status'] as String? ?? 'pending';
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final dueDate = payment['due_date'] as String?;
    final paymentPlan = payment['payment_plan'] as String? ?? 'monthly';
    final bookingRequest = payment['booking_requests'] as Map<String, dynamic>?;
    final tutorName = bookingRequest?['tutor_name'] as String? ?? 'Tutor';
  final t = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Payment',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'With $tutorName',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PricingService.formatPrice(amount),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      t.paymentHistoryPaymentPlan,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      paymentPlan.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (dueDate != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Due: ${_formatDate(dueDate)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'failed' || status == 'pending') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _retryPaymentRequest(payment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    status == 'failed' ? t.paymentHistoryRetryPayment : t.myRequestsPayNow,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

Widget _buildTrialPaymentCard(BuildContext context, Map<String, dynamic> payment) {
  final t = App
    final status = payment['payment_status'] as String? ?? 'unpaid';
    final trialStatus = payment['status'] as String? ?? 'pending';
    final paymentStatus = _getPaymentStatus(context, payment);
    final isApproved = trialStatus == 'approved' || trialStatus == 'scheduled';
    final canPay =
        isApproved && (paymentStatus == 'pending');
        isApproved && (status == 'unpaid' || status == 'pending');
    final amount = (payment['trial_fee'] as num?)?.toDouble() ?? 0.0;
    final subject = payment['subject'] as String? ?? 'Trial Session';
    final scheduledDate = payment['scheduled_date'] as String?;
    final trialId = payment['id'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trial Session',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subject,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(
                  paymentStatus == 'paid'
                      ? 'paid'
                      : paymentStatus,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PricingService.formatPrice(amount),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                if (scheduledDate != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Scheduled',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(scheduledDate),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (paymentStatus == 'pending') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canPay ? () => _retryTrialPayment(trialId) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canPay
                        ? AppTheme.primaryColor
                        : Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    canPay ? t.myRequestsPayNow : t.paymentHistoryAwaitingApproval,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: canPay ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ),
              if (!isApproved) ...[
                const SizedBox(height: 6),
                Text(
                  'Your tutor needs to approve this trial before you can pay.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionPaymentCard(Map<String, dynamic> payment) {
    final status = payment['payment_status'] as String? ?? 'pending';
    final amount = (payment['session_fee'] as num?)?.toDouble() ?? 0.0;
    final session = payment['individual_sessions'] as Map<String, dynamic>?;
    final sessionDate = session?['session_date'] as String?;
    final subject = session?['subject'] as String? ?? 'Session';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Payment',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subject,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PricingService.formatPrice(amount),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                if (sessionDate != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Session Date',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(sessionDate),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

Widget _buildStatusBadge(BuildContext context, String status) {
  final t = AppLocalizations.of(context)!;
    Color color;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'paid':
        color = Colors.green;
        label = t.paymentHistoryStatusPaid;
        icon = Icons.check_circle;
        break;
      case 'pending':
        color = Colors.orange;
        label = t.paymentHistoryStatusPending;
        icon = Icons.pending;
        break;
      case 'failed':
        color = Colors.red;
        label = t.paymentHistoryStatusFailed;
        icon = Icons.error;
        break;
      case 'unpaid':
        color = Colors.grey;
        label = 'Unpaid';
        icon = Icons.payment;
        break;
      default:
        color = Colors.grey;
        label = status.toUpperCase();
        icon = Icons.info;
    }

get    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _idEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _retryPaymentRequest(Map<String, dynamic> payment) async {
    final paymentRequestId = payment['id'] as String;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BookingPaymentScreen(paymentRequestId: paymentRequestId),
      ),
    ).then((_) => _loadPayments());
  }

  Future<void> _retryTrialPayment(String trialId) async {
    // Get trial session data
    try {
      final trialResponse = await SupabaseService.client
          .from('trial_sessions')
          .select()
          .eq('id', trialId)
          .single();

      final trial = TrialSession.fromJson(trialResponse);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TrialPaymentScreen(trialSession: trial),
        ),
      ).then((_) => _loadPayments());
    } catch (e) {
      if (mounted) {
        BrandedSnackBar.showError(context, 'Failed to load trial session: $e');
      }
    }
  }
}
