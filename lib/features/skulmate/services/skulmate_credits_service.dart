import 'package:prepskul/core/services/supabase_service.dart';

import 'skulmate_pricing_service.dart';
import 'skulmate_service.dart';

/// Revision credits + daily free usage (user_credits is source of truth for balance).
class SkulmateCreditsSnapshot {
  final int creditsBalance;
  final int docUsed;
  final int docLimit;
  final int imageUsed;
  final int imageLimit;

  const SkulmateCreditsSnapshot({
    required this.creditsBalance,
    required this.docUsed,
    required this.docLimit,
    required this.imageUsed,
    required this.imageLimit,
  });

  bool get hasCredits => creditsBalance > 0;

  bool get docQuotaRemaining => docUsed < docLimit;

  bool get imageQuotaRemaining => imageUsed < imageLimit;

  bool get anyFreeQuotaRemaining => docQuotaRemaining || imageQuotaRemaining;

  /// True only when user has no credits and both free pools are exhausted.
  bool get isPaywallState =>
      !hasCredits && !docQuotaRemaining && !imageQuotaRemaining;
}

class SkulmateCreditsService {
  static Future<int> fetchBalance() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final row = await SupabaseService.client
          .from('user_credits')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();
      return (row?['balance'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<SkulmateCreditsSnapshot> fetchSnapshot() async {
    final balance = await fetchBalance();

    // Paid credits — skip slow pricing API; usage meter is hidden anyway.
    if (balance > 0) {
      return SkulmateCreditsSnapshot(
        creditsBalance: balance,
        docUsed: 0,
        docLimit: 4,
        imageUsed: 0,
        imageLimit: 2,
      );
    }

    var docUsed = 0;
    var docLimit = 4;
    var imageUsed = 0;
    var imageLimit = 2;

    try {
      final limits = await SkulmatePricingService.fetchFreeLimits();
      docLimit = limits['doc'] ?? docLimit;
      imageLimit = limits['image'] ?? imageLimit;
    } catch (_) {}

    try {
      final data = await SkulMateService.fetchPricingUsage().timeout(
        const Duration(seconds: 6),
      );
      final today = (data['today'] as Map?)?.cast<String, dynamic>() ?? {};
      docUsed = (today['freeDocTextUsed'] as num?)?.toInt() ?? docUsed;
      docLimit = (today['freeDocTextLimit'] as num?)?.toInt() ?? docLimit;
      imageUsed = (today['freeImageUsed'] as num?)?.toInt() ?? imageUsed;
      imageLimit = (today['freeImageLimit'] as num?)?.toInt() ?? imageLimit;
    } catch (_) {
      final local = await _countLocalUsageToday();
      docUsed = local.docUsed;
      imageUsed = local.imageUsed;
    }

    return SkulmateCreditsSnapshot(
      creditsBalance: balance,
      docUsed: docUsed,
      docLimit: docLimit,
      imageUsed: imageUsed,
      imageLimit: imageLimit,
    );
  }

  /// Last paid SkulMate package tier, or inferred from balance.
  static Future<String?> fetchActivePlanTier({int? knownBalance}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final rows = await SupabaseService.client
          .from('payment_requests')
          .select('metadata, status, created_at')
          .eq('student_id', userId)
          .eq('status', 'paid')
          .order('created_at', ascending: false)
          .limit(12);

      for (final row in rows as List) {
        final metadata = (row['metadata'] as Map?)?.cast<String, dynamic>();
        if (metadata?['is_skulmate_topup'] != true) continue;
        final planId = metadata?['plan_id'] as String?;
        if (planId != null && planId.isNotEmpty) {
          return _formatTier(planId);
        }
        final package = (metadata?['package_name'] as String?) ?? '';
        final fromName = _tierFromPackageName(package);
        if (fromName != null) return fromName;
      }
    } catch (_) {}

    final balance = knownBalance ?? await fetchBalance();
    if (balance <= 0) return null;
    if (balance >= 4000) return 'Elite';
    if (balance >= 1500) return 'Pro';
    if (balance >= 400) return 'Starter';
    return null;
  }

  static String _formatTier(String planId) {
    switch (planId.toLowerCase()) {
      case 'elite':
        return 'Elite';
      case 'pro':
        return 'Pro';
      case 'starter':
        return 'Starter';
      default:
        return planId[0].toUpperCase() + planId.substring(1);
    }
  }

  static String? _tierFromPackageName(String package) {
    final lower = package.toLowerCase();
    if (lower.contains('elite')) return 'Elite';
    if (lower.contains('pro')) return 'Pro';
    if (lower.contains('starter')) return 'Starter';
    return null;
  }

  static Future<({int docUsed, int imageUsed})> _countLocalUsageToday() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return (docUsed: 0, imageUsed: 0);

    final nowUtc = DateTime.now().toUtc();
    final dayStartUtc = DateTime.utc(
      nowUtc.year,
      nowUtc.month,
      nowUtc.day,
    ).toIso8601String();

    try {
      final docRows = await SupabaseService.client
          .from('skulmate_games')
          .select('id')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .gte('created_at', dayStartUtc)
          .inFilter('source_type', ['text', 'pdf', 'docx']);
      final imageRows = await SupabaseService.client
          .from('skulmate_games')
          .select('id')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .gte('created_at', dayStartUtc)
          .eq('source_type', 'image');
      return (
        docUsed: (docRows as List).length,
        imageUsed: (imageRows as List).length,
      );
    } catch (_) {
      return (docUsed: 0, imageUsed: 0);
    }
  }
}
