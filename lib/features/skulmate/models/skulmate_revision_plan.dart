/// Revision credit top-up packages (paywall sheet + plans screen).
/// Defaults are overridden by admin `skulmate_pricing.revision_packages`.
class SkulmateRevisionPlan {
  final String id;
  final String title;
  final String subtitle;
  final int credits;
  final double amountXaf;
  final double originalAmountXaf;
  final bool isPopular;
  final List<String> benefits;
  final String cta;
  final int sortOrder;

  const SkulmateRevisionPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.credits,
    required this.amountXaf,
    required this.benefits,
    required this.cta,
    this.originalAmountXaf = 0,
    this.isPopular = false,
    this.sortOrder = 0,
  });

  bool get hasPromo => originalAmountXaf > amountXaf;

  factory SkulmateRevisionPlan.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount_xaf'] as num?)?.toDouble() ?? 0;
    final original = (json['original_amount_xaf'] as num?)?.toDouble() ?? 0;
    final benefitsRaw = json['benefits'];
    return SkulmateRevisionPlan(
      id: (json['id'] as String?)?.trim() ?? 'plan',
      title: (json['title'] as String?)?.trim() ?? 'Plan',
      subtitle: (json['subtitle'] as String?)?.trim() ?? '',
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      amountXaf: amount,
      originalAmountXaf: original > amount ? original : amount * 2,
      isPopular: json['is_popular'] == true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      cta: (json['cta'] as String?)?.trim() ?? 'Choose plan',
      benefits: benefitsRaw is List
          ? benefitsRaw.map((e) => e.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'credits': credits,
        'amount_xaf': amountXaf.round(),
        'original_amount_xaf': originalAmountXaf.round(),
        'is_popular': isPopular,
        'sort_order': sortOrder,
        'cta': cta,
        'benefits': benefits,
      };

  static const List<SkulmateRevisionPlan> catalog = [
    SkulmateRevisionPlan(
      id: 'starter',
      title: 'Starter',
      subtitle: 'Good for consistent weekly revision',
      credits: 600,
      amountXaf: 2000,
      originalAmountXaf: 4000,
      sortOrder: 1,
      benefits: [
        'Generate games from your notes quickly',
        'Play saved games offline anytime',
        'Challenge friends and classmates',
      ],
      cta: 'Start Starter',
    ),
    SkulmateRevisionPlan(
      id: 'pro',
      title: 'Pro',
      subtitle: 'Best for exam periods and daily study',
      credits: 2500,
      amountXaf: 5000,
      originalAmountXaf: 10000,
      sortOrder: 2,
      benefits: [
        'Higher daily generation capacity',
        'Handles heavier image and document uploads',
        'Best value for serious daily learners',
      ],
      cta: 'Go Pro',
      isPopular: true,
    ),
    SkulmateRevisionPlan(
      id: 'elite',
      title: 'Elite',
      subtitle: 'For families and power users',
      credits: 5000,
      amountXaf: 9000,
      originalAmountXaf: 18000,
      sortOrder: 3,
      benefits: [
        'Highest headroom for intensive revision',
        'Great for weekly challenges with friends',
        'Maximum continuity for power users',
      ],
      cta: 'Choose Elite',
    ),
  ];
}
