import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

/// Learner-facing topic row for Progress sheet (no exam/framework labels).
class LearnerTopicProgress {
  final String topicId;
  final String label;
  final int masteryPercent;
  final String band; // solid | building | needs_work

  const LearnerTopicProgress({
    required this.topicId,
    required this.label,
    required this.masteryPercent,
    required this.band,
  });
}

/// Loads concept mastery for learner "Where am I?" view (Maps M1).
class LearnerTopicProgressService {
  LearnerTopicProgressService._();

  static Future<List<LearnerTopicProgress>> fetchTopics({
    String? childId,
    int limit = 5,
    bool french = false,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      var query = SupabaseService.client
          .from('skulmate_concept_mastery')
          .select('topic_id, mastery_score, attempts, weak_streak')
          .eq('user_id', userId)
          .gte('attempts', 2);

      if (childId != null) {
        query = query.eq('child_id', childId);
      } else {
        query = query.filter('child_id', 'is', null);
      }

      final rows = await query
          .order('last_seen_at', ascending: false)
          .limit(limit * 2);

      final topics = <LearnerTopicProgress>[];
      for (final row in rows) {
        final topicId = row['topic_id']?.toString() ?? '';
        if (topicId.isEmpty || topicId == 'open:general') continue;

        final score = (row['mastery_score'] as num?)?.toDouble() ?? 0;
        final weakStreak = (row['weak_streak'] as num?)?.toInt() ?? 0;
        final percent = (score * 100).round().clamp(0, 100);
        final band = _bandFor(score, weakStreak);

        topics.add(
          LearnerTopicProgress(
            topicId: topicId,
            label: _topicLabel(topicId, french: french),
            masteryPercent: percent,
            band: band,
          ),
        );
        if (topics.length >= limit) break;
      }
      return topics;
    } catch (e) {
      LogService.debug('LearnerTopicProgressService.fetchTopics: $e');
      return [];
    }
  }

  static String _bandFor(double score, int weakStreak) {
    if (weakStreak >= 2 || score < 0.45) return 'needs_work';
    if (score < 0.72) return 'building';
    return 'solid';
  }

  static String _topicLabel(String topicId, {bool french = false}) {
    const known = {
      'gce_ol_chem_electrolysis': ('Electrolysis', 'Électrolyse'),
      'gce_ol_chem_bonding': ('Chemical bonding', 'Liaisons chimiques'),
      'gce_ol_bio_photosynthesis': ('Photosynthesis', 'Photosynthèse'),
      'gce_al_math_calculus': ('Calculus', 'Calcul'),
    };
    final hit = known[topicId];
    if (hit != null) return french ? hit.$2 : hit.$1;

    final raw = topicId.replaceFirst('open:', '').replaceAll('_', ' ').trim();
    if (raw.isEmpty) {
      return french ? 'Révision générale' : 'General revision';
    }
    return raw
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
