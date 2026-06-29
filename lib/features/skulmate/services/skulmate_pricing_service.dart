import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

import '../models/skulmate_revision_plan.dart';

import '../services/skulmate_credits_service.dart';

/// Loads SkulMate limits and revision packages from the admin-controlled row.
class SkulmatePricingService {
  static List<SkulmateRevisionPlan>? _cachedPlans;
  static DateTime? _cachedAt;
  static Map<String, int>? _cachedImageBundleLimits;
  static DateTime? _cachedImageBundleLimitsAt;
  static int? _cachedMaxImages;
  static DateTime? _cachedMaxImagesAt;

  static const _cacheTtl = Duration(minutes: 5);

  static Future<List<SkulmateRevisionPlan>> fetchRevisionPlans({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedPlans != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cachedPlans!;
    }

    try {
      final row = await SupabaseService.client
          .from('skulmate_pricing')
          .select('revision_packages')
          .eq('id', 1)
          .maybeSingle();

      final raw = row?['revision_packages'];
      if (raw is List && raw.isNotEmpty) {
        final plans = raw
            .whereType<Map>()
            .map((m) => SkulmateRevisionPlan.fromJson(m.cast<String, dynamic>()))
            .where((p) => p.amountXaf > 0 && p.credits > 0)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        if (plans.isNotEmpty) {
          _cachedPlans = plans;
          _cachedAt = DateTime.now();
          return plans;
        }
      }
    } catch (e) {
      LogService.debug('SkulmatePricingService: using catalog fallback ($e)');
    }

    return SkulmateRevisionPlan.catalog;
  }

  static void invalidateCache() {
    _cachedPlans = null;
    _cachedAt = null;
    _cachedImageBundleLimits = null;
    _cachedImageBundleLimitsAt = null;
    _cachedMaxImages = null;
    _cachedMaxImagesAt = null;
  }

  static Future<Map<String, int>> fetchFreeLimits() async {
    try {
      final row = await SupabaseService.client
          .from('skulmate_pricing')
          .select(
            'free_doc_text_games_per_day, free_image_games_per_day',
          )
          .eq('id', 1)
          .maybeSingle();

      return {
        'doc': (row?['free_doc_text_games_per_day'] as num?)?.toInt() ?? 4,
        'image': (row?['free_image_games_per_day'] as num?)?.toInt() ?? 2,
      };
    } catch (_) {
      return const {'doc': 4, 'image': 2};
    }
  }

  static Future<bool> saveRevisionPackages(
    List<Map<String, dynamic>> packages,
  ) async {
    await SupabaseService.client.from('skulmate_pricing').update({
      'revision_packages': packages,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', 1);
    invalidateCache();
    return true;
  }

  static Future<bool> saveFreeLimits({
    required int docPerDay,
    required int imagePerDay,
  }) async {
    await SupabaseService.client.from('skulmate_pricing').update({
      'free_doc_text_games_per_day': docPerDay,
      'free_image_games_per_day': imagePerDay,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', 1);
    return true;
  }

  static Future<Map<String, int>> fetchImageBundleLimits({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedImageBundleLimits != null &&
        _cachedImageBundleLimitsAt != null &&
        DateTime.now().difference(_cachedImageBundleLimitsAt!) < _cacheTtl) {
      return _cachedImageBundleLimits!;
    }

    try {
      final row = await SupabaseService.client
          .from('skulmate_pricing')
          .select(
            'max_images_per_prompt_free, max_images_per_prompt_paid',
          )
          .eq('id', 1)
          .maybeSingle();

      final limits = {
        'free': (row?['max_images_per_prompt_free'] as num?)?.toInt() ?? 3,
        'paid': (row?['max_images_per_prompt_paid'] as num?)?.toInt() ?? 5,
      };
      _cachedImageBundleLimits = limits;
      _cachedImageBundleLimitsAt = DateTime.now();
      return limits;
    } catch (_) {
      return const {'free': 3, 'paid': 5};
    }
  }

  /// Paid credit balance unlocks the higher per-prompt image cap.
  static Future<int> resolveMaxImagesPerPrompt({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedMaxImages != null &&
        _cachedMaxImagesAt != null &&
        DateTime.now().difference(_cachedMaxImagesAt!) < _cacheTtl) {
      return _cachedMaxImages!;
    }

    final limits = await fetchImageBundleLimits(forceRefresh: forceRefresh);
    int max;
    try {
      final credits = await SkulmateCreditsService.fetchBalance();
      max = credits >= 2 ? limits['paid'] ?? 5 : limits['free'] ?? 3;
    } catch (_) {
      max = limits['free'] ?? 3;
    }
    _cachedMaxImages = max;
    _cachedMaxImagesAt = DateTime.now();
    return max;
  }
}
