import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import '../widgets/skulmate_surface_styles.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/features/payment/screens/booking_payment_screen.dart';
import 'package:prepskul/features/skulmate/services/skulmate_topup_service.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_revision_plan.dart';
import '../services/skulmate_credits_service.dart';
import '../services/skulmate_pricing_service.dart';
import '../widgets/skulmate_plan_card.dart';
import '../widgets/skulmate_usage_meter.dart';

class SkulmatePlansScreen extends StatefulWidget {
  const SkulmatePlansScreen({Key? key}) : super(key: key);

  @override
  State<SkulmatePlansScreen> createState() => _SkulmatePlansScreenState();
}

class _SkulmatePlansScreenState extends State<SkulmatePlansScreen> {
  bool _isStartingPayment = false;
  String? _payingPlanTitle;
  SkulmateCreditsSnapshot? _snapshot;
  String? _planTier;
  List<SkulmateRevisionPlan> _plans = SkulmateRevisionPlan.catalog;
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshotFuture = SkulmateCreditsService.fetchSnapshot();
      final plansFuture = SkulmatePricingService.fetchRevisionPlans();
      final snapshot = await snapshotFuture;
      final tierFuture = SkulmateCreditsService.fetchActivePlanTier(
        knownBalance: snapshot.creditsBalance,
      );
      final results = await Future.wait([plansFuture, tierFuture]);
      if (!mounted) return;
      safeSetState(() {
        _snapshot = snapshot;
        _planTier = results[1] as String?;
        _plans = results[0] as List<SkulmateRevisionPlan>;
        _loadingStatus = false;
      });
    } catch (_) {
      if (mounted) safeSetState(() => _loadingStatus = false);
    }
  }

  Future<void> _startPlanPayment(SkulmateRevisionPlan plan) async {
    if (_isStartingPayment) return;
    safeSetState(() {
      _isStartingPayment = true;
      _payingPlanTitle = plan.title;
    });
    try {
      final paymentRequestId =
          await SkulmateTopupService.createTopupPaymentRequest(
        packageName: '${plan.title} · ${plan.credits} credits',
        planId: plan.id,
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
      await _load();
      if (paid == true) {
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorHandler.getUserFriendlyMessage(e),
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        safeSetState(() {
          _isStartingPayment = false;
          _payingPlanTitle = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);
    final snapshot = _snapshot;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SkulMateSurfaceStyles.lightStatusBarOverlay,
      child: Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
          backgroundColor: AppTheme.softBackground,
          systemOverlayStyle: SkulMateSurfaceStyles.lightStatusBarOverlay,
          iconTheme: const IconThemeData(color: AppTheme.textDark),
        title: Text(
            copy.revisionPlansTitle,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
            if (_loadingStatus || snapshot == null)
              const _StatusCardSkeleton()
            else
              _StatusCard(
                snapshot: snapshot,
                planTier: _planTier,
                copy: copy,
              ),
            if (snapshot != null && !snapshot.hasCredits) ...[
              const SizedBox(height: 12),
              SkulMateUsageMeter(snapshot: snapshot),
            ],
            const SizedBox(height: 14),
            Text(
              snapshot != null && snapshot.hasCredits
                  ? copy.plansTopUpHeading
                  : copy.plansChooseHeading,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
            const SizedBox(height: 10),
            for (final plan in _plans) ...[
              SkulMatePlanCard(
                plan: plan,
                isLoading:
                    _isStartingPayment && _payingPlanTitle == plan.title,
                onSelect: () => _startPlanPayment(plan),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCardSkeleton extends StatelessWidget {
  const _StatusCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.all(14),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 16),
      alignment: Alignment.centerLeft,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final SkulmateCreditsSnapshot snapshot;
  final String? planTier;
  final SkulMateCopy copy;

  const _StatusCard({
    required this.snapshot,
    required this.planTier,
    required this.copy,
  });

  @override
  Widget build(BuildContext context) {
    final hasCredits = snapshot.hasCredits;
    final tier = planTier;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SkulMateSurfaceStyles.homeCard(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasCredits
                ? copy.plansHeroWithCredits(snapshot.creditsBalance)
                : (snapshot.isPaywallState
                    ? copy.paywallSubtitle
                    : copy.plansHeroFreeRemaining),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
              height: 1.4,
            ),
          ),
          if (tier != null && hasCredits) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _tierBadgeColor(tier).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                copy.activePlanBadge(tier),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _tierBadgeColor(tier),
                        ),
                      ),
              ),
            ],
        ],
      ),
    );
  }

  static Color _tierBadgeColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'pro':
      case 'elite':
        return const Color(0xFFC9A227);
      default:
        return AppTheme.primaryColor;
    }
  }
}
