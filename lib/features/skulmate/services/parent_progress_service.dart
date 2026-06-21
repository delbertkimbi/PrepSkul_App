import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/services/supabase_service.dart';

import '../utils/learner_path_context.dart';

/// Phase C4 — parent-facing SkulMate progress (labels gated to learner level).
class ParentSkulMateProgressService {
  ParentSkulMateProgressService._();

  static Future<ParentProgressSnapshot> fetch({
    String? childId,
    bool french = false,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      return ParentProgressSnapshot.empty(french: french);
    }

    try {
      final profile = await _fetchLearnerProfile(userId, childId);
      final masteryRows = await _fetchMastery(userId, childId);
      final gameMeta = await _fetchGames(userId, childId);
      final sessions = await _fetchSessions(userId, gameMeta.keys.toList());
      final sessionHighlights = await _fetchSessionHighlights(userId);
      final upcomingSessions = await _fetchUpcomingSessions(userId);

      return _buildSnapshot(
        masteryRows: masteryRows,
        sessions: sessions,
        gameTitles: gameMeta,
        profile: profile,
        sessionHighlights: sessionHighlights,
        upcomingSessions: upcomingSessions,
        french: french,
      );
    } catch (e) {
      LogService.debug('ParentSkulMateProgressService: $e');
      return ParentProgressSnapshot.empty(french: french);
    }
  }

  static Future<LearnerPathProfile?> _fetchLearnerProfile(
    String userId,
    String? childId,
  ) async {
    if (childId == null || childId.isEmpty) return null;
    try {
      final row = await SupabaseService.client
          .from('parent_learners')
          .select(
            'class_level, education_level, exam_type, specific_exam, learning_path',
          )
          .eq('id', childId)
          .eq('parent_id', userId)
          .maybeSingle();
      return LearnerPathContext.fromParentLearner(
        row == null ? null : Map<String, dynamic>.from(row),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchMastery(
    String userId,
    String? childId,
  ) async {
    var query = SupabaseService.client
        .from('skulmate_concept_mastery')
        .select(
          'topic_id, framework_id, mastery_score, weak_streak, attempts, last_seen_at, last_game_id',
        )
        .eq('user_id', userId);

    if (childId != null && childId.isNotEmpty) {
      query = query.eq('child_id', childId);
    } else {
      query = query.filter('child_id', 'is', null);
    }

    final rows = await query
        .order('mastery_score', ascending: true)
        .limit(40);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, String>> _fetchGames(
    String userId,
    String? childId,
  ) async {
    var query = SupabaseService.client
        .from('skulmate_games')
        .select('id, title')
        .eq('user_id', userId);

    if (childId != null && childId.isNotEmpty) {
      query = query.eq('child_id', childId);
    } else {
      query = query.filter('child_id', 'is', null);
    }

    final rows = await query.limit(200);
    final map = <String, String>{};
    for (final row in rows) {
      final id = row['id']?.toString();
      if (id == null) continue;
      map[id] = row['title']?.toString() ?? 'Revision game';
    }
    return map;
  }

  static Future<List<_SessionRow>> _fetchSessions(
    String userId,
    List<String> gameIds,
  ) async {
    if (gameIds.isEmpty) return [];

    final rows = await SupabaseService.client
        .from('skulmate_game_sessions')
        .select(
          'game_id, correct_answers, total_questions, time_taken_seconds, completed_at',
        )
        .eq('user_id', userId)
        .inFilter('game_id', gameIds)
        .order('completed_at', ascending: false)
        .limit(120);

    return rows
        .map(
          (r) => _SessionRow(
            gameId: r['game_id']?.toString() ?? '',
            correctAnswers: (r['correct_answers'] as num?)?.toInt() ?? 0,
            totalQuestions: (r['total_questions'] as num?)?.toInt() ?? 0,
            timeTakenSeconds: (r['time_taken_seconds'] as num?)?.toInt(),
            completedAt: DateTime.tryParse(r['completed_at']?.toString() ?? '') ??
                DateTime.now(),
          ),
        )
        .toList();
  }

  static Future<List<ParentSessionHighlight>> _fetchSessionHighlights(
    String parentId,
  ) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 14));
      final rows = await SupabaseService.client
          .from('individual_sessions')
          .select(
            'id, session_summary, completed_at, scheduled_date, tutor_name, subject',
          )
          .not('session_summary', 'is', null)
          .gte('completed_at', cutoff.toIso8601String())
          .or('parent_id.eq.$parentId,learner_id.eq.$parentId')
          .order('completed_at', ascending: false)
          .limit(5);

      final highlights = <ParentSessionHighlight>[];
      for (final row in rows) {
        final raw = row['session_summary']?.toString().trim() ?? '';
        if (raw.length < 20) continue;
        final preview =
            raw.length > 180 ? '${raw.substring(0, 177).trim()}…' : raw;
        final completedAt = DateTime.tryParse(
              row['completed_at']?.toString() ??
                  row['scheduled_date']?.toString() ??
                  '',
            ) ??
            DateTime.now();
        highlights.add(
          ParentSessionHighlight(
            sessionId: row['id']?.toString() ?? '',
            tutorName: row['tutor_name']?.toString(),
            subjectHint: row['subject']?.toString(),
            summaryPreview: preview,
            completedAt: completedAt,
          ),
        );
      }
      return highlights;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ParentUpcomingSession>> _fetchUpcomingSessions(
    String parentId,
  ) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await SupabaseService.client
          .from('individual_sessions')
          .select(
            'id, scheduled_date, scheduled_time, tutor_name, session_mode, status',
          )
          .or('parent_id.eq.$parentId,learner_id.eq.$parentId')
          .gte('scheduled_date', today)
          .inFilter('status', ['scheduled', 'approved', 'pending'])
          .order('scheduled_date', ascending: true)
          .limit(5);

      return rows
          .map(
            (row) => ParentUpcomingSession(
              sessionId: row['id']?.toString() ?? '',
              tutorName: row['tutor_name']?.toString(),
              scheduledAt:
                  '${row['scheduled_date'] ?? ''} ${row['scheduled_time'] ?? ''}'
                      .trim(),
              mode: row['session_mode']?.toString(),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static ParentProgressSnapshot _buildSnapshot({
    required List<Map<String, dynamic>> masteryRows,
    required List<_SessionRow> sessions,
    required Map<String, String> gameTitles,
    required LearnerPathProfile? profile,
    required List<ParentSessionHighlight> sessionHighlights,
    required List<ParentUpcomingSession> upcomingSessions,
    required bool french,
  }) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7));
    final recent = sessions.where((s) => s.completedAt.isAfter(cutoff)).toList();

    var correct7 = 0;
    var total7 = 0;
    var seconds7 = 0;
    for (final s in recent) {
      correct7 += s.correctAnswers;
      total7 += s.totalQuestions;
      seconds7 += s.timeTakenSeconds ?? 0;
    }

    final weakTopics = <ParentWeakTopic>[];
    var masterySum = 0.0;
    var masteryCount = 0;
    var weakPenalty = 0;

    for (final row in masteryRows) {
      final attempts = (row['attempts'] as num?)?.toInt() ?? 0;
      if (attempts < 2) continue;

      final topicId = row['topic_id']?.toString() ?? '';
      if (topicId == 'open:general') continue;

      final score = (row['mastery_score'] as num?)?.toDouble() ?? 0;
      final weakStreak = (row['weak_streak'] as num?)?.toInt() ?? 0;
      final frameworkId = row['framework_id']?.toString();

      masterySum += score;
      masteryCount += 1;

      final needsAttention = weakStreak >= 2 ||
          (attempts >= 4 && score < 0.42) ||
          score < 0.5;

      if (needsAttention) {
        weakPenalty += 1;
        weakTopics.add(
          ParentWeakTopic(
            topicId: topicId,
            label: _topicLabel(topicId, french),
            frameworkLabel: LearnerPathContext.parentFrameworkLabel(
              frameworkId: frameworkId,
              profile: profile,
              french: french,
            ),
            masteryPercent: (score * 100).round(),
            attempts: attempts,
          ),
        );
      }
    }

    final readiness = masteryCount == 0
        ? 0
        : ((masterySum / masteryCount) * 100 - weakPenalty * 6)
            .round()
            .clamp(0, 100);

    final band = _readinessBand(readiness);
    final recentGames = sessions.take(6).map((s) {
      return ParentRecentGame(
        title: gameTitles[s.gameId] ?? 'Revision game',
        completedAt: s.completedAt,
        accuracy: s.totalQuestions > 0
            ? ((s.correctAnswers / s.totalQuestions) * 100).round()
            : 0,
      );
    }).toList();

    return ParentProgressSnapshot(
      streakDays: _computeStreak(sessions),
      sessionsLast7Days: recent.length,
      revisionMinutesLast7Days: (seconds7 / 60).round(),
      accuracyLast7Days: total7 > 0 ? ((correct7 / total7) * 100).round() : null,
      totalSessions: sessions.length,
      examReadiness: readiness,
      readinessBand: band,
      readinessLabel: _readinessLabel(band, french),
      readinessTitle: LearnerPathContext.readinessTitle(profile, french),
      readinessDisclaimer: LearnerPathContext.readinessDisclaimer(profile, french),
      learnerContextLine: LearnerPathContext.learnerContextLine(profile, french),
      isExamTrack: LearnerPathContext.isExamTrackLearner(profile),
      weakTopics: weakTopics.take(6).toList(),
      recentGames: recentGames,
      sessionHighlights: sessionHighlights,
      upcomingSessions: upcomingSessions,
    );
  }

  static int _computeStreak(List<_SessionRow> sessions) {
    if (sessions.isEmpty) return 0;

    final days = <String>{};
    for (final s in sessions) {
      final d = DateTime(s.completedAt.year, s.completedAt.month, s.completedAt.day);
      days.add('${d.year}-${d.month}-${d.day}');
    }

    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = '${yesterday.year}-${yesterday.month}-${yesterday.day}';

    if (!days.contains(todayKey) && !days.contains(yesterdayKey)) {
      return 0;
    }

    var streak = 0;
    var cursor = days.contains(todayKey) ? today : yesterday;

    while (true) {
      final key = '${cursor.year}-${cursor.month}-${cursor.day}';
      if (!days.contains(key)) break;
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static String _topicLabel(String topicId, bool french) {
    const known = {
      'gce_ol_chem_electrolysis': ('Electrolysis', 'Électrolyse'),
      'gce_ol_chem_bonding': ('Chemical bonding', 'Liaisons chimiques'),
      'gce_ol_bio_photosynthesis': ('Photosynthesis', 'Photosynthèse'),
      'gce_al_math_calculus': ('Calculus', 'Calcul différentiel'),
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

  static String _readinessBand(int score) {
    if (score < 40) return 'needs_support';
    if (score < 60) return 'building';
    if (score < 78) return 'on_track';
    return 'strong';
  }

  static String _readinessLabel(String band, bool french) {
    switch (band) {
      case 'needs_support':
        return french ? 'Besoin de soutien' : 'Needs support';
      case 'building':
        return french ? 'En construction' : 'Building foundation';
      case 'on_track':
        return french ? 'Sur la bonne voie' : 'On track';
      default:
        return french ? 'Solide' : 'Strong';
    }
  }
}

class _SessionRow {
  final String gameId;
  final int correctAnswers;
  final int totalQuestions;
  final int? timeTakenSeconds;
  final DateTime completedAt;

  const _SessionRow({
    required this.gameId,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.completedAt,
    this.timeTakenSeconds,
  });
}

class ParentWeakTopic {
  final String topicId;
  final String label;
  final String? frameworkLabel;
  final int masteryPercent;
  final int attempts;

  const ParentWeakTopic({
    required this.topicId,
    required this.label,
    this.frameworkLabel,
    required this.masteryPercent,
    required this.attempts,
  });
}

class ParentRecentGame {
  final String title;
  final DateTime completedAt;
  final int accuracy;

  const ParentRecentGame({
    required this.title,
    required this.completedAt,
    required this.accuracy,
  });
}

class ParentSessionHighlight {
  final String sessionId;
  final String? tutorName;
  final String? subjectHint;
  final String summaryPreview;
  final DateTime completedAt;

  const ParentSessionHighlight({
    required this.sessionId,
    this.tutorName,
    this.subjectHint,
    required this.summaryPreview,
    required this.completedAt,
  });
}

class ParentUpcomingSession {
  final String sessionId;
  final String? tutorName;
  final String scheduledAt;
  final String? mode;

  const ParentUpcomingSession({
    required this.sessionId,
    this.tutorName,
    required this.scheduledAt,
    this.mode,
  });
}

class ParentProgressSnapshot {
  final int streakDays;
  final int sessionsLast7Days;
  final int revisionMinutesLast7Days;
  final int? accuracyLast7Days;
  final int totalSessions;
  final int examReadiness;
  final String readinessBand;
  final String readinessLabel;
  final String readinessTitle;
  final String readinessDisclaimer;
  final String? learnerContextLine;
  final bool isExamTrack;
  final List<ParentWeakTopic> weakTopics;
  final List<ParentRecentGame> recentGames;
  final List<ParentSessionHighlight> sessionHighlights;
  final List<ParentUpcomingSession> upcomingSessions;

  const ParentProgressSnapshot({
    required this.streakDays,
    required this.sessionsLast7Days,
    required this.revisionMinutesLast7Days,
    required this.accuracyLast7Days,
    required this.totalSessions,
    required this.examReadiness,
    required this.readinessBand,
    required this.readinessLabel,
    required this.readinessTitle,
    required this.readinessDisclaimer,
    this.learnerContextLine,
    this.isExamTrack = false,
    required this.weakTopics,
    required this.recentGames,
    this.sessionHighlights = const [],
    this.upcomingSessions = const [],
  });

  bool get hasActivity =>
      totalSessions > 0 ||
      weakTopics.isNotEmpty ||
      sessionHighlights.isNotEmpty ||
      upcomingSessions.isNotEmpty;

  factory ParentProgressSnapshot.empty({bool french = false}) {
    return ParentProgressSnapshot(
      streakDays: 0,
      sessionsLast7Days: 0,
      revisionMinutesLast7Days: 0,
      accuracyLast7Days: null,
      totalSessions: 0,
      examReadiness: 0,
      readinessBand: 'building',
      readinessLabel: french ? 'En construction' : 'Building foundation',
      readinessTitle: LearnerPathContext.readinessTitle(null, french),
      readinessDisclaimer: LearnerPathContext.readinessDisclaimer(null, french),
      weakTopics: const [],
      recentGames: const [],
    );
  }
}
