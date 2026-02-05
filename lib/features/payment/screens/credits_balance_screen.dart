import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/auth_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/features/payment/services/user_credits_service.dart';
import 'package:prepskul/features/payment/widgets/credits_balance_widget.dart';
import 'package:intl/intl.dart';

/// Credits Balance Screen
///
/// Displays user's current credits balance, transaction history, and purchase options
class CreditsBalanceScreen extends StatefulWidget {
  const CreditsBalanceScreen({Key? key}) : super(key: key);

  @override
  State<CreditsBalanceScreen> createState() => _CreditsBalanceScreenState();
}

class _CreditsBalanceScreenState extends State<CreditsBalanceScreen> {
  bool _isLoading = true;
  int _currentBalance = 0;
  int _totalPurchased = 0;
  List<Map<String, dynamic>> _transactions = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCreditsData();
  }

  Future<void> _loadCreditsData() async {
    safeSetState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = await AuthService.getUserId();
      if (userId == null) {
        throw Exception('User not found');
      }

      final balance = await UserCreditsService.getUserBalance(userId);
      
      // Get credits record for total_purchased
      final creditsRecord = await SupabaseService.client
          .from('user_credits')
          .select('total_purchased')
          .eq('user_id', userId)
          .maybeSingle();
      
      final totalPurchased = (creditsRecord?['total_purchased'] as num?)?.toInt() ?? 0;
      
      // Get transaction history
      final transactionsResponse = await SupabaseService.client
          .from('credit_transactions')
          .select('''
            id,
            type,
            amount,
            amount_xaf,
            balance_before,
            balance_after,
            description,
            reference_id,
            reference_type,
            created_at
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      
      final transactions = (transactionsResponse as List).cast<Map<String, dynamic>>();

      safeSetState(() {
        _currentBalance = balance;
        _totalPurchased = totalPurchased;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      LogService.error('Error loading credits data: $e');
      safeSetState(() {
        _errorMessage = 'Failed to load credits data. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          'Credits Balance',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCreditsData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCreditsData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Balance Card
                        CreditsBalanceWidget(
                          currentCredits: _currentBalance,
                          isLoading: false,
                        ),
                        const SizedBox(height: 24),
                        
                        // Statistics
                        _buildStatisticsCard(),
                        const SizedBox(height: 24),
                        
                        // Transaction History
                        Text(
                          'Transaction History',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTransactionList(),
                      ],
                    ),
                  ),
                ),
    );
  }

  /// Calculate sessions available from points
  /// New system: 10 points per session
  int _calculateSessionsFromPoints(int points) {
    if (points <= 0) return 0;
    return (points / 10).floor();
  }

  Widget _buildStatisticsCard() {
    final sessionsAvailable = _calculateSessionsFromPoints(_currentBalance);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistics',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Total Purchased', '$_totalPurchased points'),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              _buildStatItem('Current Balance', '$_currentBalance points'),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              _buildStatItem('Sessions Available', '$sessionsAvailable sessions'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final transaction = _transactions[index];
        return _buildTransactionItem(transaction);
      },
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String? ?? 'unknown';
    final amount = (transaction['amount'] as num?)?.toInt() ?? 0;
    final description = transaction['description'] as String? ?? '';
    final createdAt = transaction['created_at'] as String?;
    
    final isPurchase = type == 'purchase';
    final isDeduction = type == 'deduction';
    final isRefund = type == 'refund';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isPurchase
                  ? Colors.green[50]
                  : isDeduction
                      ? Colors.orange[50]
                      : Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPurchase
                  ? Icons.add_circle_outline
                  : isDeduction
                      ? Icons.remove_circle_outline
                      : Icons.refresh,
              color: isPurchase
                  ? Colors.green[700]
                  : isDeduction
                      ? Colors.orange[700]
                      : Colors.blue[700],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description.isNotEmpty ? description : type.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(createdAt)),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${isPurchase ? '+' : isDeduction ? '-' : '+'}$amount',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isPurchase
                  ? Colors.green[700]
                  : isDeduction
                      ? Colors.orange[700]
                      : Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }
}