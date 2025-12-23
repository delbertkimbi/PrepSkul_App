import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_set_state.dart';
import '../../../core/services/log_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/branded_snackbar.dart';
import '../../../features/booking/services/session_payment_service.dart';
import '../../../features/payment/services/tutor_payout_service.dart';
import 'package:intl/intl.dart';

class TutorEarningsScreen extends StatefulWidget {
  const TutorEarningsScreen({Key? key}) : super(key: key);

  @override
  State<TutorEarningsScreen> createState() => _TutorEarningsScreenState();
}

class _TutorEarningsScreenState extends State<TutorEarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  double _activeBalance = 0.0;
  double _pendingBalance = 0.0;
  List<Map<String, dynamic>> _earningsHistory = [];
  List<Map<String, dynamic>> _payoutHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    safeSetState(() => _isLoading = true);
    try {
      final user = await AuthService.getCurrentUser();
      final userId = user['userId'] as String;

      // Load wallet balances
      final balances = await SessionPaymentService.getTutorWalletBalances(userId);
      _activeBalance = (balances['active_balance'] as num).toDouble();
      _pendingBalance = (balances['pending_balance'] as num).toDouble();

      // Load earnings history
      await _loadEarningsHistory(userId);

      // Load payout history
      _payoutHistory = await TutorPayoutService.getPayoutHistory(userId);
    } catch (e) {
      LogService.error('Error loading earnings data: $e');
      if (mounted) {
        BrandedSnackBar.showError(context, 'Failed to load earnings: $e');
      }
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _loadEarningsHistory(String tutorId) async {
    try {
      final earnings = await SupabaseService.client
          .from('tutor_earnings')
          .select('''
            *,
            individual_sessions!left(
              subject,
              scheduled_date,
              scheduled_time
            )
          ''')
          .eq('tutor_id', tutorId)
          .order('created_at', ascending: false)
          .limit(50);

      _earningsHistory = (earnings as List).cast<Map<String, dynamic>>();
    } catch (e) {
      LogService.warning('Error loading earnings history: $e');
      _earningsHistory = [];
    }
  }

  Future<void> _requestPayout() async {
    if (_activeBalance < 5000) {
      if (mounted) {
        BrandedSnackBar.show(
          context,
          message: 'Minimum payout amount is 5,000 XAF',
          backgroundColor: Colors.orange,
          icon: Icons.info_outline,
        );
      }
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _PayoutRequestDialog(
        maxAmount: _activeBalance,
      ),
    );

    if (result != null) {
      try {
        safeSetState(() => _isLoading = true);
        
        await TutorPayoutService.requestPayout(
          amount: result['amount'] as double,
          phoneNumber: result['phoneNumber'] as String,
          notes: result['notes'] as String?,
        );

        if (mounted) {
          BrandedSnackBar.showSuccess(
            context,
            'Payout request submitted successfully!',
          );
        }

        // Reload data
        await _loadData();
      } catch (e) {
        if (mounted) {
          BrandedSnackBar.showError(
            context,
            'Failed to request payout: ${e.toString().replaceFirst('Exception: ', '')}',
          );
        }
      } finally {
        safeSetState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Earnings & Payouts',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Balance Cards
            _buildWalletBalanceSection(),
            const SizedBox(height: 24),
            
            // Request Payout Button
            if (_activeBalance >= 5000)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _requestPayout,
                  icon: const Icon(Icons.account_balance_wallet, size: 20),
                  label: Text(
                    'Request Payout',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Minimum payout amount is 5,000 XAF. You currently have ${_activeBalance.toStringAsFixed(0)} XAF available.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Quick Stats
            _buildQuickStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletBalanceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PrepSkul Wallet',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Your earnings and balance',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildBalanceCard(
                  label: 'Active Balance',
                  amount: _activeBalance,
                  icon: Icons.check_circle,
                  color: Colors.green[300]!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBalanceCard(
                  label: 'Pending Balance',
                  amount: _pendingBalance,
                  icon: Icons.pending,
                  color: Colors.orange[300]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${amount.toStringAsFixed(0)} XAF',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final totalEarnings = _earningsHistory
        .where((e) => e['earnings_status'] != 'cancelled')
        .fold<double>(0.0, (sum, e) => sum + ((e['tutor_earnings'] as num?)?.toDouble() ?? 0.0));
    
    final totalPayouts = _payoutHistory
        .where((p) => p['status'] == 'completed')
        .fold<double>(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Stats',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: 'Total Earned',
                value: '${totalEarnings.toStringAsFixed(0)} XAF',
                icon: Icons.trending_up,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                label: 'Total Withdrawn',
                value: '${totalPayouts.toStringAsFixed(0)} XAF',
                icon: Icons.account_balance_wallet,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryColor,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: TabBar(
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey[600],
                labelStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                indicatorColor: AppTheme.primaryColor,
                tabs: const [
                  Tab(text: 'Earnings'),
                  Tab(text: 'Payouts'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildEarningsHistory(),
                  _buildPayoutHistory(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsHistory() {
    if (_earningsHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppTheme.textLight),
              const SizedBox(height: 16),
              Text(
                'No earnings yet',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your earnings will appear here after completing sessions',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _earningsHistory.length,
      itemBuilder: (context, index) {
        final earning = _earningsHistory[index];
        return _buildEarningCard(earning);
      },
    );
  }

  Widget _buildEarningCard(Map<String, dynamic> earning) {
    final amount = (earning['tutor_earnings'] as num?)?.toDouble() ?? 0.0;
    final status = earning['earnings_status'] as String? ?? 'pending';
    final createdAt = earning['created_at'] as String?;
    final session = earning['individual_sessions'] as Map<String, dynamic>?;
    final subject = session?['subject'] as String? ?? 'Session';
    final scheduledDate = session?['scheduled_date'] as String?;
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (status) {
      case 'active':
        statusColor = Colors.green;
        statusText = 'Available';
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pending';
        statusIcon = Icons.pending;
        break;
      case 'paid_out':
        statusColor = Colors.blue;
        statusText = 'Withdrawn';
        statusIcon = Icons.account_balance_wallet;
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
        statusIcon = Icons.info;
    }

    String dateText = 'Recently';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        final now = DateTime.now();
        final difference = now.difference(date);
        
        if (difference.inDays == 0) {
          dateText = 'Today';
        } else if (difference.inDays == 1) {
          dateText = 'Yesterday';
        } else if (difference.inDays < 7) {
          dateText = '${difference.inDays} days ago';
        } else {
          dateText = DateFormat('MMM d, y').format(date);
        }
      } catch (e) {
        LogService.warning('Error parsing date: $e');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.textLight.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateText,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  if (scheduledDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Session: ${DateFormat('MMM d, y').format(DateTime.parse(scheduledDate))}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${amount.toStringAsFixed(0)} XAF',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutHistory() {
    if (_payoutHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppTheme.textLight),
              const SizedBox(height: 16),
              Text(
                'No payout requests yet',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your payout requests will appear here',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payoutHistory.length,
      itemBuilder: (context, index) {
        final payout = _payoutHistory[index];
        return _buildPayoutCard(payout);
      },
    );
  }

  Widget _buildPayoutCard(Map<String, dynamic> payout) {
    final amount = (payout['amount'] as num?)?.toDouble() ?? 0.0;
    final status = payout['status'] as String? ?? 'pending';
    final requestedAt = payout['requested_at'] as String?;
    final phoneNumber = payout['phone_number'] as String?;
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = 'Completed';
        statusIcon = Icons.check_circle;
        break;
      case 'processing':
        statusColor = Colors.blue;
        statusText = 'Processing';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pending';
        statusIcon = Icons.pending;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusText = 'Failed';
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
        statusIcon = Icons.info;
    }

    String dateText = 'Recently';
    if (requestedAt != null) {
      try {
        final date = DateTime.parse(requestedAt);
        final now = DateTime.now();
        final difference = now.difference(date);
        
        if (difference.inDays == 0) {
          dateText = 'Today';
        } else if (difference.inDays == 1) {
          dateText = 'Yesterday';
        } else if (difference.inDays < 7) {
          dateText = '${difference.inDays} days ago';
        } else {
          dateText = DateFormat('MMM d, y').format(date);
        }
      } catch (e) {
        LogService.warning('Error parsing date: $e');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.textLight.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payout Request',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateText,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  if (phoneNumber != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'To: $phoneNumber',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${amount.toStringAsFixed(0)} XAF',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Payout Request Dialog
class _PayoutRequestDialog extends StatefulWidget {
  final double maxAmount;

  const _PayoutRequestDialog({required this.maxAmount});

  @override
  State<_PayoutRequestDialog> createState() => _PayoutRequestDialogState();
}

class _PayoutRequestDialogState extends State<_PayoutRequestDialog> {
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Request Payout',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Balance: ${widget.maxAmount.toStringAsFixed(0)} XAF',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (XAF)',
                  hintText: 'Minimum: 5,000 XAF',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null) {
                    return 'Please enter a valid number';
                  }
                  if (amount < 5000) {
                    return 'Minimum payout is 5,000 XAF';
                  }
                  if (amount > widget.maxAmount) {
                    return 'Amount exceeds available balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '67XXXXXXX or 69XXXXXXX',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  // Basic phone validation
                  final phone = value.trim().replaceAll(RegExp(r'[^\d]'), '');
                  if (phone.length < 9) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Any additional information...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(color: AppTheme.textMedium),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final amount = double.parse(_amountController.text.trim());
              final phone = _phoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
              final notes = _notesController.text.trim().isEmpty 
                  ? null 
                  : _notesController.text.trim();
              
              Navigator.pop(context, {
                'amount': amount,
                'phoneNumber': phone,
                'notes': notes,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Request Payout',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}



