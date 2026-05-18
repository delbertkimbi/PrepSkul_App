import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/features/payment/services/payment_request_amounts.dart';

void main() {
  group('PaymentRequestAmounts', () {
    test('normalizePlan handles bi-weekly variants', () {
      expect(PaymentRequestAmounts.normalizePlan('bi-weekly'), 'biweekly');
      expect(PaymentRequestAmounts.normalizePlan('BIWEEKLY'), 'biweekly');
      expect(PaymentRequestAmounts.normalizePlan('Trial Session'), 'trial');
    });

    test('installmentCountForPlan', () {
      expect(PaymentRequestAmounts.installmentCountForPlan('monthly'), 1);
      expect(PaymentRequestAmounts.installmentCountForPlan('biweekly'), 2);
      expect(PaymentRequestAmounts.installmentCountForPlan('weekly'), 4);
      expect(PaymentRequestAmounts.installmentCountForPlan('trial'), 1);
    });

    test('totalMonthlyWithTransport adds onsite transport', () {
      final total = PaymentRequestAmounts.totalMonthlyWithTransport(
        sessionFeeMonthly: 28000,
        location: 'onsite',
        transportationPerSession: 500,
        sessionsPerWeek: 2,
      );
      // 2x/week => 8 sessions/month => 4000 transport + 28000 sessions
      expect(total, 32000);
    });

    test('totalMonthlyWithTransport ignores transport for online', () {
      final total = PaymentRequestAmounts.totalMonthlyWithTransport(
        sessionFeeMonthly: 28000,
        location: 'online',
        transportationPerSession: 500,
        sessionsPerWeek: 2,
      );
      expect(total, 28000);
    });

    test('monthly installment uses 10% discount on full month', () {
      final quote = PaymentRequestAmounts.quoteInstallment(
        sessionFeeMonthly: 40000,
        location: 'online',
        transportationPerSession: 0,
        sessionsPerWeek: 2,
        paymentPlan: 'monthly',
      );
      expect(quote.totalMonthlyAmount, 40000);
      expect(quote.baseBeforeDiscount, 40000);
      expect(quote.installmentAmount, 36000); // 10% off
      expect(quote.discountPercent, 10);
    });

    test('biweekly installment is half month with 5% discount', () {
      final quote = PaymentRequestAmounts.quoteInstallment(
        sessionFeeMonthly: 40000,
        location: 'online',
        transportationPerSession: 0,
        sessionsPerWeek: 2,
        paymentPlan: 'biweekly',
      );
      expect(quote.baseBeforeDiscount, 20000);
      expect(quote.installmentAmount, 19000); // 5% off 20000
      expect(quote.discountPercent, 5);
    });

    test('weekly installment is quarter month without discount', () {
      final quote = PaymentRequestAmounts.quoteInstallment(
        sessionFeeMonthly: 40000,
        location: 'online',
        transportationPerSession: 0,
        sessionsPerWeek: 2,
        paymentPlan: 'weekly',
      );
      expect(quote.baseBeforeDiscount, 10000);
      expect(quote.installmentAmount, 10000);
      expect(quote.discountPercent, 0);
    });

    test('biweekly onsite includes transport in installment base', () {
      final quote = PaymentRequestAmounts.quoteInstallment(
        sessionFeeMonthly: 28000,
        location: 'onsite',
        transportationPerSession: 500,
        sessionsPerWeek: 2,
        paymentPlan: 'biweekly',
      );
      // monthly total 32000, half = 16000, 5% off => 15200
      expect(quote.totalMonthlyAmount, 32000);
      expect(quote.installmentAmount, 15200);
    });

    test('trial uses list price without plan discount', () {
      final quote = PaymentRequestAmounts.quoteInstallment(
        sessionFeeMonthly: 3500,
        location: 'onsite',
        transportationPerSession: 0,
        sessionsPerWeek: 1,
        paymentPlan: 'Trial Session',
      );
      expect(quote.paymentPlan, 'trial');
      expect(quote.installmentAmount, 3500);
      expect(quote.discountPercent, 0);
    });

    test('daysBetweenInstallments', () {
      expect(PaymentRequestAmounts.daysBetweenInstallments('weekly'), 7);
      expect(PaymentRequestAmounts.daysBetweenInstallments('biweekly'), 14);
    });
  });
}
