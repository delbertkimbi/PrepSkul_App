import 'package:flutter_test/flutter_test.dart';
import 'package:prepskul/core/services/pricing_service.dart';
void main() {
  test('discovery session rate is not the recurring monthly total', () {
    final pricing = PricingService.calculateMonthlyPricing(
      baseTutorRate: 3000, rating: 4, qualification: 'Professional', sessionsPerWeek: 2,
      adminPriceOverride: 3500);
    expect(pricing['perSession'],3500);
    expect(pricing['perMonth'],28000);
    expect(PricingService.formatPrice(pricing['perSession'] as double),'3,500 XAF');
  });
  test('frequency changes booking totals without changing the session rate', () {
    Map<String,dynamic> price(int frequency) => PricingService.calculateMonthlyPricing(
      baseTutorRate: 3000, rating: 4.5, qualification: 'Professional', sessionsPerWeek: frequency);
    expect(price(2)['perSession'],price(4)['perSession']);
    expect(price(4)['perMonth'],(price(2)['perMonth'] as double)*2);
  });
}
