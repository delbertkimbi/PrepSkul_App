import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepskul/core/theme/app_theme.dart';
import 'package:prepskul/core/utils/error_handler.dart';
import 'package:prepskul/core/utils/safe_set_state.dart';
import 'package:prepskul/features/payment/screens/booking_payment_screen.dart';

import '../l10n/skulmate_copy.dart';
import '../models/skulmate_revision_plan.dart';
import '../screens/skulmate_plans_screen.dart';
import '../services/skulmate_credits_service.dart';
import '../services/skulmate_pricing_service.dart';
import '../services/skulmate_topup_service.dart';
import 'skulmate_plan_card.dart';
import 'skulmate_sheet_scaffold.dart';
import 'skulmate_usage_meter.dart';

/// Bottom sheet shown only when generation is blocked (free quota + no credits).
class SkulMatePaywallSheet extends StatefulWidget {
  final String? message;
  final SkulmateCreditsSnapshot? snapshot;

  const SkulMatePaywallSheet({super.key, this.message, this.snapshot});

  static Future<bool> show(BuildContext context, {String? message}) async {
    final snapshot = await SkulmateCreditsService.fetchSnapshot();
    if (snapshot.hasCredits || !snapshot.isPaywallState) {
      return true;
    }
    if (!context.mounted) return false;
    return SkulMateSheetScaffold.show<bool>(
      context,
      child: SkulMatePaywallSheet(message: message, snapshot: snapshot),
    ).then((value) => value ?? false);
  }

  @override
  State<SkulMatePaywallSheet> createState() => _SkulMatePaywallSheetState();
}

class _SkulMatePaywallSheetState extends State<SkulMatePaywallSheet> {
  bool _paying = false;
  String? _payingPlanTitle;
  List<SkulmateRevisionPlan> _plans = SkulmateRevisionPlan.catalog;
  bool _loadingPlans = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans = await SkulmatePricingService.fetchRevisionPlans();
    if (mounted) {
      safeSetState(() {
        _plans = plans;
        _loadingPlans = false;
      });
    }
  }

  Future<void> _purchase(SkulmateRevisionPlan plan) async {
    if (_paying) return;
    safeSetState(() {
      _paying = true;
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
          builder: (_) => BookingPaymentScreen(paymentRequestId: paymentRequestId),
        ),
      );
      if (!mounted) return;
      if (paid == true) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorHandler.getUserFriendlyMessage(e),
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        safeSetState(() {
          _paying = false;
          _payingPlanTitle = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = SkulMateCopy.of(context);

    return SkulMateSheetScaffold(
      title: copy.paywallTitle,
      showWandIcon: false,
      maxHeightFactor: 0.88,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.message != null && widget.message!.isNotEmpty) ...[
            Text(
              widget.message!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textMedium,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            copy.paywallSubtitle,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textMedium,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SkulMateUsageMeter(snapshot: widget.snapshot),
          const SizedBox(height: 14),
          if (_loadingPlans)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else
            ..._plans.map(
              (plan) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SkulMatePlanCard(
                  plan: plan,
                  isLoading: _paying && _payingPlanTitle == plan.title,
                  onSelect: () => _purchase(plan),
                ),
              ),
            ),
          TextButton(
            onPressed: () async {
              final paid = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const SkulmatePlansScreen(),
                ),
              );
              if (!mounted) return;
              if (paid == true) Navigator.pop(context, true);
            },
            child: Text(
              copy.paywallSeeAllPlans,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
