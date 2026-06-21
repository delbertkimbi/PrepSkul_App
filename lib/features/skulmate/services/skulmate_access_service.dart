import 'package:prepskul/core/services/supabase_service.dart';
import 'skulmate_credits_service.dart';
import 'skulmate_service.dart';

enum SkulmateSourceType { text, image }

class SkulmateAccessResult {
  final bool canProceed;
  final bool needsPlan;
  final String message;

  const SkulmateAccessResult({
    required this.canProceed,
    required this.needsPlan,
    required this.message,
  });
}

class SkulmateAccessService {
  static const int _freeDocTextPerDay = 4;
  static const int _freeImagePerDay = 2;

  static Future<SkulmateAccessResult> checkGenerationAccess({
    required SkulmateSourceType sourceType,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      return const SkulmateAccessResult(
        canProceed: false,
        needsPlan: false,
        message: 'Please log in to continue.',
      );
    }

    int freeLimit = sourceType == SkulmateSourceType.image
        ? _freeImagePerDay
        : _freeDocTextPerDay;
    int freeUsed = 0;
    try {
      final data = await SkulMateService.fetchPricingUsage();
      final today = (data['today'] as Map?)?.cast<String, dynamic>() ?? const {};
      final freeDocLimit = (today['freeDocTextLimit'] as num?)?.toInt();
      final freeImageLimit = (today['freeImageLimit'] as num?)?.toInt();
      if (freeDocLimit != null && freeDocLimit >= 0) {
        freeLimit = freeDocLimit;
      }
      if (sourceType == SkulmateSourceType.image &&
          freeImageLimit != null &&
          freeImageLimit >= 0) {
        freeLimit = freeImageLimit;
      }
      freeUsed = sourceType == SkulmateSourceType.image
          ? (today['freeImageUsed'] as num?)?.toInt() ?? 0
          : (today['freeDocTextUsed'] as num?)?.toInt() ?? 0;
    } catch (_) {
      // Fallback to local counting so access checks still work.
      final nowUtc = DateTime.now().toUtc();
      final dayStartUtc = DateTime.utc(
        nowUtc.year,
        nowUtc.month,
        nowUtc.day,
      ).toIso8601String();
      try {
        var query = SupabaseService.client
            .from('skulmate_games')
            .select('id')
            .eq('user_id', userId)
            .eq('is_deleted', false)
            .gte('created_at', dayStartUtc);
        if (sourceType == SkulmateSourceType.image) {
          query = query.eq('source_type', 'image');
        } else {
          query = query.inFilter('source_type', ['text', 'pdf', 'docx']);
        }
        final rows = await query;
        freeUsed = (rows as List).length;
      } catch (_) {
        freeUsed = 0;
      }
    }

    if (freeUsed < freeLimit) {
      return SkulmateAccessResult(
        canProceed: true,
        needsPlan: false,
        message: 'Free usage available.',
      );
    }

    int creditsBalance = await SkulmateCreditsService.fetchBalance();

    final minimumCreditsRequired = sourceType == SkulmateSourceType.image
        ? 2
        : 2;

    if (creditsBalance >= minimumCreditsRequired) {
      return SkulmateAccessResult(
        canProceed: true,
        needsPlan: false,
        message: 'Paid credits available.',
      );
    }

    if (sourceType == SkulmateSourceType.image) {
      return const SkulmateAccessResult(
        canProceed: false,
        needsPlan: true,
        message:
            'You already used your free image generations today. Choose a plan to continue now.',
      );
    }

    return const SkulmateAccessResult(
      canProceed: false,
      needsPlan: true,
      message:
          'You already used your free document/text generations today. Choose a plan to continue now.',
    );
  }
}
