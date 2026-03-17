import 'package:prepskul/core/services/supabase_service.dart';

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
  static const int _freeDocTextPerDay = 2;
  static const int _freeImagePerDay = 4;

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

    final freeLimit = sourceType == SkulmateSourceType.image
        ? _freeImagePerDay
        : _freeDocTextPerDay;

    final nowUtc = DateTime.now().toUtc();
    final dayStartUtc = DateTime.utc(
      nowUtc.year,
      nowUtc.month,
      nowUtc.day,
    ).toIso8601String();

    int freeUsed = 0;
    try {
      var query = SupabaseService.client
          .from('skulmate_usage_events')
          .select('id')
          .eq('user_id', userId)
          .eq('event_type', 'generate_game')
          .eq('success', true)
          .gte('created_at', dayStartUtc)
          .contains('metadata', {'billing_mode': 'free'});
      if (sourceType == SkulmateSourceType.image) {
        query = query.eq('source_type', 'image');
      } else {
        query = query.inFilter('source_type', ['text', 'pdf', 'docx']);
      }
      final rows = await query;
      freeUsed = (rows as List).length;
    } catch (_) {
      // Do not block users if telemetry read fails.
      freeUsed = 0;
    }

    if (freeUsed < freeLimit) {
      return SkulmateAccessResult(
        canProceed: true,
        needsPlan: false,
        message: 'Free usage available.',
      );
    }

    int creditsBalance = 0;
    try {
      final creditRow = await SupabaseService.client
          .from('user_credits')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();
      creditsBalance = (creditRow?['balance'] as num?)?.toInt() ?? 0;
    } catch (_) {
      creditsBalance = 0;
    }

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
            'You already used your 4 free image generations today. Choose a plan to continue now.',
      );
    }

    return const SkulmateAccessResult(
      canProceed: false,
      needsPlan: true,
      message:
          'You already used your 2 free document/text generations today. Choose a plan to continue now.',
    );
  }
}
