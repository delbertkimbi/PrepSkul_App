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
    setState(() => _isLoading = true);

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

      setState(() => _isLoading = false);

      // Only show error if ALL payment types failed
      if (_paymentRequests.isEmpty &&
          _trialPayments.isEmpty &&
          _sessionPayments.isEmpty) {
        if (mounted) {
          BrandedSnackBar.showError(
            context,
            'Unable to load payment history. Please try again later.',
          );
        }
      }
    } catch (e) {
      print('❌ Critical error loading payments: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        BrandedSnackBar.showError(
          context,
          'Failed to load payment history: $e',
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
            payment_confirmed_at,
            scheduled_date,
            scheduled_time,
            status,
            created_at
          ''')
          .eq('requester_id', userId)
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
      print('❌ Error loading trial payments: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      // Check if it's a table not found error
      if (e.toString().contains('does not exist') ||
          e.toString().contains('relation') ||
          e.toString().contains('PGRST')) {
        print('⚠️ Trial sessions table might not exist yet');
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadSessionPayments(String userId) async {
    try {
      // Try with inner join first (if individual_sessions exists)
      try {
        final response = await SupabaseService.client
            .from('session_payments')
            .select('''
              *,
              individual_sessions!inner(
                id,
                session_date,
                session_time,
                subject,
                tutor_id,
                student_id
              )
            ''')
            .eq('individual_sessions.student_id', userId)
            .order('created_at', ascending: false);

        try {
          return List<Map<String, dynamic>>.from(response);
        } catch (castError) {
          print('⚠️ Error casting session payments response: $castError');
          return (response as List).whereType<Map<String, dynamic>>().toList();
        }
      } catch (innerJoinError) {
        // If inner join fails (table doesn't exist), try without the join
        print('⚠️ Inner join failed, trying without join: $innerJoinError');

        // Load session_payments directly and filter by user
        final response = await SupabaseService.client
            .from('session_payments')
            .select('*')
            .order('created_at', ascending: false);

        // Filter manually if we can't use the join
        try {
          return List<Map<String, dynamic>>.from(response);
        } catch (castError) {
          print('⚠️ Error casting session payments (no join): $castError');
          return (response as List).whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (e) {
      print('❌ Error loading session payments: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      // Check if it's a table not found error
      if (e.toString().contains('does not exist') ||
          e.toString().contains('relation') ||
          e.toString().contains('PGRST')) {
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
      final status = _getPaymentStatus(payment);
      return status.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();
  }

  String _getPaymentStatus(Map<String, dynamic> payment) {
    if (payment.containsKey('status')) {
      return payment['status'] as String? ?? 'pending';
    } else if (payment.containsKey('payment_status')) {
      return payment['payment_status'] as String? ?? 'pending';
    }
    return 'pending';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment History',
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
          tabs: const [
            Tab(text: 'Bookings'),
            Tab(text: 'Trials'),
            Tab(text: 'Sessions'),
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
                _buildFilterChip('all', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('pending', 'Pending'),
                const SizedBox(width: 8),
                _buildFilterChip('paid', 'Paid'),
                const SizedBox(width: 8),
                _buildFilterChip('failed', 'Failed'),
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
                      'Payment Plan',
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
                    status == 'failed' ? 'Retry Payment' : 'Pay Now',
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

  Widget _buildTrialPaymentCard(Map<String, dynamic> payment) {
    final status = payment['payment_status'] as String? ?? 'unpaid';
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
                  status == 'paid'
                      ? 'paid'
                      : status == 'unpaid'
                      ? 'pending'
                      : status,
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
            if (status == 'unpaid' || status == 'pending') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _retryTrialPayment(trialId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Pay Now',
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

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'paid':
        color = Colors.green;
        label = 'Paid';
        icon = Icons.check_circle;
        break;
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        icon = Icons.pending;
        break;
      case 'failed':
        color = Colors.red;
        label = 'Failed';
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

    return Container(
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

  Widget _buildEmptyState(String message) {
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
