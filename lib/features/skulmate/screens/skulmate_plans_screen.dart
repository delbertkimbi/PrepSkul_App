import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/features/payment/screens/booking_payment_screen.dart';
import 'package:prepskul/features/skulmate/services/skulmate_topup_service.dart';

class _SkulmatePlan {
  final String title;
  final String subtitle;
  final int credits;
  final double amountXaf;
  final bool isPopular;
  final List<String> benefits;
  final String cta;

  const _SkulmatePlan({
    required this.title,
    required this.subtitle,
    required this.credits,
    required this.amountXaf,
    required this.benefits,
    required this.cta,
    this.isPopular = false,
  });
}

class SkulmatePlansScreen extends StatefulWidget {
  const SkulmatePlansScreen({Key? key}) : super(key: key);

  @override
  State<SkulmatePlansScreen> createState() => _SkulmatePlansScreenState();
}

class _SkulmatePlansScreenState extends State<SkulmatePlansScreen> {
  bool _isStartingPayment = false;
  int _creditsBalance = 0;

  static const _plans = <_SkulmatePlan>[
    _SkulmatePlan(
      title: 'Starter',
      subtitle: 'Good for consistent weekly revision',
      credits: 600,
      amountXaf: 2000,
      benefits: [
        'Create challenge games from your notes quickly',
        'Play saved SkulMate games offline anytime',
        'Invite friends/classmates and start game sessions',
      ],
      cta: 'Start Starter',
    ),
    _SkulmatePlan(
      title: 'Pro',
      subtitle: 'Best for exam periods and daily study',
      credits: 2500,
      amountXaf: 5000,
      benefits: [
        'Much higher daily generation capacity for exam periods',
        'Handles heavier image/document revision workflows',
        'Better value for serious daily learners',
      ],
      cta: 'Go Pro',
      isPopular: true,
    ),
    _SkulmatePlan(
      title: 'Elite',
      subtitle: 'For families and power users',
      credits: 5000,
      amountXaf: 9000,
      benefits: [
        'Highest headroom for families and class groups',
        'Best for intensive weekly challenges and competitions',
        'Maximum continuity for power users',
      ],
      cta: 'Choose Elite',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCreditsBalance();
  }

  Future<void> _loadCreditsBalance() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final row = await SupabaseService.client
          .from('user_credits')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();
      if (!mounted) return;
      safeSetState(
        () => _creditsBalance = (row?['balance'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {}
  }

  Future<void> _startPlanPayment(_SkulmatePlan plan) async {
    if (_isStartingPayment) return;
    safeSetState(() => _isStartingPayment = true);
    try {
      final paymentRequestId =
          await SkulmateTopupService.createTopupPaymentRequest(
            packageName: '${plan.title} • ${plan.credits} credits',
            credits: plan.credits,
            amountXaf: plan.amountXaf,
          );

      if (!mounted) return;
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              BookingPaymentScreen(paymentRequestId: paymentRequestId),
        ),
      );
      if (!mounted) return;
      await _loadCreditsBalance();
      if (paid == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment successful. Credits updated: $_creditsBalance',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) safeSetState(() => _isStartingPayment = false);
    }
  }

  void _showCreditsUsageSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Credits breakdown',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Document/Text generation = 2 credits',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Image generation = 2-4 credits (depends on complexity)',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You always get a message before generation when a paid plan is required.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'SkulMate Plans',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF123F87), Color(0xFF0A2D67)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Start Free, Upgrade When Ready',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _showCreditsUsageSheet,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.read_more_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Free includes up to 2 document/text generations and 4 image generations per day. Paid plans unlock much more generation power anytime.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.92),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.stars_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current balance: $_creditsBalance credits',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final plan in _plans) ...[
            _buildPlanCard(plan),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanCard(_SkulmatePlan plan) {
    final amountLabel = plan.amountXaf.toStringAsFixed(0);
    Color planColor;
    switch (plan.title) {
      case 'Starter':
        planColor = const Color(0xFF2F7A4A);
        break;
      case 'Pro':
        planColor = const Color(0xFF6D3FB1);
        break;
      case 'Elite':
        planColor = const Color(0xFFD97706);
        break;
      default:
        planColor = AppTheme.primaryColor;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: plan.isPopular
              ? planColor.withOpacity(0.6)
              : AppTheme.softBorder,
          width: plan.isPopular ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${plan.title} · ${plan.credits} credits',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              if (plan.isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: planColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Popular',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: planColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            plan.subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 8),
          ...plan.benefits.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: planColor,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$amountLabel XAF',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: planColor,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isStartingPayment
                    ? null
                    : () => _startPlanPayment(plan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: planColor,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                child: _isStartingPayment
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        plan.cta,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
