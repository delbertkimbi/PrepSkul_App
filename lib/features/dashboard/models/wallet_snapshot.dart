/// Cached wallet metrics for the home promo carousel.
class WalletSnapshot {
  final int sessionCredits;
  final int skulMateCredits;
  final int paidSessionsAhead;

  const WalletSnapshot({
    required this.sessionCredits,
    required this.skulMateCredits,
    required this.paidSessionsAhead,
  });

  static const empty = WalletSnapshot(
    sessionCredits: 0,
    skulMateCredits: 0,
    paidSessionsAhead: 0,
  );

  bool get hasData =>
      sessionCredits > 0 || skulMateCredits > 0 || paidSessionsAhead > 0;

  bool get needsSessionTopUp => sessionCredits == 0 && paidSessionsAhead == 0;

  bool get needsSkulMateTopUp => skulMateCredits == 0;

  /// Dynamic footer CTA for the payment-card wallet slide.
  String footerCta({required bool isParent}) {
    if (needsSkulMateTopUp && needsSessionTopUp) {
      return isParent
          ? 'Add SkulMate credits so your child can play'
          : 'Get SkulMate credits to play games';
    }
    if (needsSessionTopUp) {
      return isParent
          ? 'Top up session credits to book your child\'s next lesson'
          : 'Top up session credits to book a tutor';
    }
    if (needsSkulMateTopUp) {
      return isParent
          ? 'Add SkulMate credits so your child can play'
          : 'Get SkulMate credits to play games';
    }
    if (paidSessionsAhead > 0) {
      final word = paidSessionsAhead == 1 ? 'session' : 'sessions';
      return '$paidSessionsAhead paid $word ahead';
    }
    return 'View balances & payment history';
  }
}
