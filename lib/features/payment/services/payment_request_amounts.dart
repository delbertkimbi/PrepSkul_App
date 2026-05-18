import 'package:prepskul/core/services/pricing_service.dart';

/// Pure payment amount calculations for 1:1 booking approval (no I/O).
class PaymentRequestAmounts {
  PaymentRequestAmounts._();

  /// Normalizes plan strings from UI/DB (`bi-weekly`, `biweekly`, etc.).
  static String normalizePlan(String paymentPlan) {
    final p = paymentPlan.trim().toLowerCase();
    if (p == 'bi-weekly' || p == 'biweekly') return 'biweekly';
    if (p == 'trial session' || p == 'trial') return 'trial';
    return p;
  }

  /// Number of installment rows created on tutor approval (1:1 recurring only).
  static int installmentCountForPlan(String paymentPlan) {
    switch (normalizePlan(paymentPlan)) {
      case 'weekly':
        return 4;
      case 'biweekly':
        return 2;
      case 'monthly':
        return 1;
      case 'trial':
        return 1;
      default:
        return 1;
    }
  }

  /// Session fee for the month plus onsite/hybrid transportation for the month.
  static double totalMonthlyWithTransport({
    required double sessionFeeMonthly,
    required String location,
    required double transportationPerSession,
    required int sessionsPerWeek,
  }) {
    final loc = location.trim().toLowerCase();
    final isOnsite = loc == 'onsite' || loc == 'hybrid';
    final sessionsPerMonth = sessionsPerWeek * 4;
    final transportMonthly = (isOnsite && transportationPerSession > 0)
        ? transportationPerSession * sessionsPerMonth
        : 0.0;
    return sessionFeeMonthly + transportMonthly;
  }

  /// Period base before plan discount (monthly / 2 / 4).
  static double baseAmountForPlan({
    required double totalMonthlyAmount,
    required String paymentPlan,
  }) {
    switch (normalizePlan(paymentPlan)) {
      case 'monthly':
        return totalMonthlyAmount;
      case 'biweekly':
        return totalMonthlyAmount / 2;
      case 'weekly':
        return totalMonthlyAmount / 4;
      case 'trial':
        return totalMonthlyAmount;
      default:
        return totalMonthlyAmount;
    }
  }

  /// One installment charge (after plan discount). Trials use list price as-is.
  static PaymentInstallmentQuote quoteInstallment({
    required double sessionFeeMonthly,
    required String location,
    required double transportationPerSession,
    required int sessionsPerWeek,
    required String paymentPlan,
  }) {
    final plan = normalizePlan(paymentPlan);

    if (plan == 'trial') {
      final amount = sessionFeeMonthly;
      return PaymentInstallmentQuote(
        installmentAmount: amount,
        totalMonthlyAmount: amount,
        baseBeforeDiscount: amount,
        discountPercent: 0,
        discountAmount: 0,
        paymentPlan: 'trial',
      );
    }

    final totalMonthly = totalMonthlyWithTransport(
      sessionFeeMonthly: sessionFeeMonthly,
      location: location,
      transportationPerSession: transportationPerSession,
      sessionsPerWeek: sessionsPerWeek,
    );

    final base = baseAmountForPlan(
      totalMonthlyAmount: totalMonthly,
      paymentPlan: plan,
    );

    final pricing = PricingService.calculateDiscount(
      monthlyTotal: base,
      paymentPlan: plan,
    );

    return PaymentInstallmentQuote(
      installmentAmount: (pricing['finalAmount'] as num).toDouble(),
      totalMonthlyAmount: totalMonthly,
      baseBeforeDiscount: base,
      discountPercent: (pricing['discountPercent'] as num).toDouble(),
      discountAmount: (pricing['discountAmount'] as num).toDouble(),
      paymentPlan: plan,
    );
  }

  /// Days between installment due dates for bi-weekly / weekly plans.
  static int daysBetweenInstallments(String paymentPlan) {
    return normalizePlan(paymentPlan) == 'weekly' ? 7 : 14;
  }
}

class PaymentInstallmentQuote {
  final double installmentAmount;
  final double totalMonthlyAmount;
  final double baseBeforeDiscount;
  final double discountPercent;
  final double discountAmount;
  final String paymentPlan;

  const PaymentInstallmentQuote({
    required this.installmentAmount,
    required this.totalMonthlyAmount,
    required this.baseBeforeDiscount,
    required this.discountPercent,
    required this.discountAmount,
    required this.paymentPlan,
  });
}
