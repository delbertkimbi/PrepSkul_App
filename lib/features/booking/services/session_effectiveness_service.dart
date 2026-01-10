import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepskul/core/services/supabase_service.dart';
import 'package:prepskul/core/services/log_service.dart';

/// Session Effectiveness Service
///
/// Provides analytics on session effectiveness by:
/// - Location (online vs onsite)
/// - Session type (trial vs recurrent)
/// - Overall effectiveness metrics
class SessionEffectivenessService {
  static SupabaseClient get _supabase => SupabaseService.client;

  /// Get effectiveness metrics by location
  ///
  /// Returns comparison of online vs onsite sessions:
  /// - Average rating by location
  /// - Completion rate by location
  /// - Engagement scores by location
  /// - Common issues by location
  static Future<Map<String, dynamic>> getLocationEffectiveness({
    required String tutorId,
    String? location, // 'online' or 'onsite' - optional filter
  }) async {
    try {
      // Build query for feedback with location filter
      var query = _supabase
          .from('session_feedback')
          .select('''
            location_type,
            student_rating,
            student_would_recommend,
            learning_objectives_met,
            student_progress_rating,
            would_continue_lessons,
            individual_sessions!inner(
              tutor_id,
              status,
              session_ended_at
            )
          ''')
          .eq('individual_sessions.tutor_id', tutorId)
          .not('location_type', 'is', null);

      if (location != null) {
        query = query.eq('location_type', location.toLowerCase());
      }

      final feedback = await query;

      if (feedback.isEmpty) {
        return {
          'online': _emptyMetrics(),
          'onsite': _emptyMetrics(),
          'comparison': {},
        };
      }

      // Separate by location
      final onlineFeedback = (feedback as List)
          .where((f) => f['location_type'] == 'online')
          .toList();
      final onsiteFeedback = (feedback as List)
          .where((f) => f['location_type'] == 'onsite')
          .toList();

      final onlineMetrics = _calculateMetrics(onlineFeedback);
      final onsiteMetrics = _calculateMetrics(onsiteFeedback);

      return {
        'online': onlineMetrics,
        'onsite': onsiteMetrics,
        'comparison': _compareMetrics(onlineMetrics, onsiteMetrics),
      };
    } catch (e) {
      LogService.error('Error getting location effectiveness: $e');
      return {
        'online': _emptyMetrics(),
        'onsite': _emptyMetrics(),
        'comparison': {},
      };
    }
  }

  /// Get effectiveness metrics by session type
  ///
  /// Returns comparison of trial vs recurrent sessions:
  /// - Average rating by type
  /// - Conversion rate (trial → recurrent)
  /// - Retention rate
  static Future<Map<String, dynamic>> getSessionTypeEffectiveness({
    required String tutorId,
    String? sessionType, // 'trial' or 'recurrent' - optional filter
  }) async {
    try {
      // Build query for feedback with session type filter
      var query = _supabase
          .from('session_feedback')
          .select('''
            session_type,
            student_rating,
            student_would_recommend,
            learning_objectives_met,
            student_progress_rating,
            would_continue_lessons,
            individual_sessions!inner(
              tutor_id,
              status,
              recurring_session_id
            )
          ''')
          .eq('individual_sessions.tutor_id', tutorId)
          .not('session_type', 'is', null);

      if (sessionType != null) {
        query = query.eq('session_type', sessionType.toLowerCase());
      }

      final feedback = await query;

      if (feedback.isEmpty) {
        return {
          'trial': _emptyMetrics(),
          'recurrent': _emptyMetrics(),
          'conversion_rate': 0.0,
          'retention_rate': 0.0,
        };
      }

      // Separate by session type
      final trialFeedback = (feedback as List)
          .where((f) => f['session_type'] == 'trial')
          .toList();
      final recurrentFeedback = (feedback as List)
          .where((f) => f['session_type'] == 'recurrent')
          .toList();

      final trialMetrics = _calculateMetrics(trialFeedback);
      final recurrentMetrics = _calculateMetrics(recurrentFeedback);

      // Calculate conversion rate (trial → recurrent)
      // This would require checking if students who did trials later booked recurrent
      final conversionRate = await _calculateConversionRate(tutorId);

      // Calculate retention rate
      final retentionRate = await _calculateRetentionRate(tutorId);

      return {
        'trial': trialMetrics,
        'recurrent': recurrentMetrics,
        'conversion_rate': conversionRate,
        'retention_rate': retentionRate,
        'comparison': _compareMetrics(trialMetrics, recurrentMetrics),
      };
    } catch (e) {
      LogService.error('Error getting session type effectiveness: $e');
      return {
        'trial': _emptyMetrics(),
        'recurrent': _emptyMetrics(),
        'conversion_rate': 0.0,
        'retention_rate': 0.0,
      };
    }
  }

  /// Get comprehensive effectiveness report
  ///
  /// Returns combined metrics:
  /// - Overall effectiveness
  /// - Location comparison
  /// - Session type comparison
  /// - Trends over time
  static Future<Map<String, dynamic>> getComprehensiveReport({
    required String tutorId,
  }) async {
    try {
      final locationEffectiveness = await getLocationEffectiveness(tutorId: tutorId);
      final sessionTypeEffectiveness = await getSessionTypeEffectiveness(tutorId: tutorId);

      // Get overall stats
      final allFeedback = await _supabase
          .from('session_feedback')
          .select('''
            student_rating,
            student_would_recommend,
            learning_objectives_met,
            student_progress_rating,
            would_continue_lessons,
            individual_sessions!inner(
              tutor_id,
              status
            )
          ''')
          .eq('individual_sessions.tutor_id', tutorId);

      final overallMetrics = _calculateMetrics(allFeedback as List);

      return {
        'overall': overallMetrics,
        'by_location': locationEffectiveness,
        'by_session_type': sessionTypeEffectiveness,
        'insights': _generateInsights(locationEffectiveness, sessionTypeEffectiveness),
      };
    } catch (e) {
      LogService.error('Error getting comprehensive report: $e');
      return {
        'overall': _emptyMetrics(),
        'by_location': {'online': _emptyMetrics(), 'onsite': _emptyMetrics()},
        'by_session_type': {'trial': _emptyMetrics(), 'recurrent': _emptyMetrics()},
        'insights': [],
      };
    }
  }

  /// Calculate metrics from feedback data
  static Map<String, dynamic> _calculateMetrics(List<dynamic> feedback) {
    if (feedback.isEmpty) {
      return _emptyMetrics();
    }

    double totalRating = 0;
    int ratingCount = 0;
    int recommendCount = 0;
    int objectivesMetCount = 0;
    double totalProgressRating = 0;
    int progressRatingCount = 0;
    int continueLessonsCount = 0;
    int totalFeedback = feedback.length;

    for (final f in feedback) {
      final rating = f['student_rating'] as int?;
      if (rating != null) {
        totalRating += rating;
        ratingCount++;
      }

      if (f['student_would_recommend'] == true) {
        recommendCount++;
      }

      if (f['learning_objectives_met'] == true) {
        objectivesMetCount++;
      }

      final progressRating = f['student_progress_rating'] as int?;
      if (progressRating != null) {
        totalProgressRating += progressRating;
        progressRatingCount++;
      }

      if (f['would_continue_lessons'] == true) {
        continueLessonsCount++;
      }
    }

    return {
      'average_rating': ratingCount > 0 ? totalRating / ratingCount : 0.0,
      'total_feedback': totalFeedback,
      'rating_count': ratingCount,
      'recommendation_rate': totalFeedback > 0 ? recommendCount / totalFeedback : 0.0,
      'objectives_met_rate': totalFeedback > 0 ? objectivesMetCount / totalFeedback : 0.0,
      'average_progress_rating': progressRatingCount > 0 ? totalProgressRating / progressRatingCount : 0.0,
      'continue_lessons_rate': totalFeedback > 0 ? continueLessonsCount / totalFeedback : 0.0,
    };
  }

  /// Compare two sets of metrics
  static Map<String, dynamic> _compareMetrics(
    Map<String, dynamic> metrics1,
    Map<String, dynamic> metrics2,
  ) {
    final rating1 = metrics1['average_rating'] as double;
    final rating2 = metrics2['average_rating'] as double;
    final recommend1 = metrics1['recommendation_rate'] as double;
    final recommend2 = metrics2['recommendation_rate'] as double;

    return {
      'rating_difference': rating1 - rating2,
      'recommendation_difference': recommend1 - recommend2,
      'better_performer': rating1 > rating2 ? 'first' : rating2 > rating1 ? 'second' : 'equal',
    };
  }

  /// Calculate conversion rate (trial → recurrent)
  static Future<double> _calculateConversionRate(String tutorId) async {
    try {
      // Get all trial sessions for this tutor
      final trialSessions = await _supabase
          .from('trial_sessions')
          .select('id, learner_id, status')
          .eq('tutor_id', tutorId)
          .eq('status', 'completed');

      if (trialSessions.isEmpty) {
        return 0.0;
      }

      // Check how many led to recurrent bookings
      int converted = 0;
      for (final trial in trialSessions as List) {
        final learnerId = trial['learner_id'] as String;
        // Check if this learner has any recurrent sessions with this tutor
        final recurrentSessions = await _supabase
            .from('recurring_sessions')
            .select('id')
            .eq('tutor_id', tutorId)
            .eq('learner_id', learnerId)
            .limit(1);

        if (recurrentSessions.isNotEmpty) {
          converted++;
        }
      }

      return trialSessions.length > 0 ? converted / trialSessions.length : 0.0;
    } catch (e) {
      LogService.error('Error calculating conversion rate: $e');
      return 0.0;
    }
  }

  /// Calculate retention rate
  static Future<double> _calculateRetentionRate(String tutorId) async {
    try {
      // Get all students who have had sessions with this tutor
      final sessions = await _supabase
          .from('individual_sessions')
          .select('learner_id')
          .eq('tutor_id', tutorId)
          .eq('status', 'completed');

      if (sessions.isEmpty) {
        return 0.0;
      }

      // Count unique learners
      final uniqueLearners = (sessions as List)
          .map((s) => s['learner_id'] as String)
          .toSet()
          .length;

      // Count learners with multiple sessions
      final learnerSessionCounts = <String, int>{};
      for (final session in sessions as List) {
        final learnerId = session['learner_id'] as String;
        learnerSessionCounts[learnerId] = (learnerSessionCounts[learnerId] ?? 0) + 1;
      }

      final retainedLearners = learnerSessionCounts.values.where((count) => count > 1).length;

      return uniqueLearners > 0 ? retainedLearners / uniqueLearners : 0.0;
    } catch (e) {
      LogService.error('Error calculating retention rate: $e');
      return 0.0;
    }
  }

  /// Generate insights from metrics
  static List<String> _generateInsights(
    Map<String, dynamic> locationData,
    Map<String, dynamic> sessionTypeData,
  ) {
    final insights = <String>[];

    final locationComparison = locationData['comparison'] as Map<String, dynamic>?;
    if (locationComparison != null) {
      final ratingDiff = locationComparison['rating_difference'] as double? ?? 0.0;
      if (ratingDiff.abs() > 0.2) {
        final better = ratingDiff > 0 ? 'online' : 'onsite';
        insights.add('Your $better sessions have ${(ratingDiff.abs() * 100).toStringAsFixed(0)}% higher ratings');
      }
    }

    final sessionComparison = sessionTypeData['comparison'] as Map<String, dynamic>?;
    if (sessionComparison != null) {
      final ratingDiff = sessionComparison['rating_difference'] as double? ?? 0.0;
      if (ratingDiff.abs() > 0.2) {
        final better = ratingDiff > 0 ? 'trial' : 'recurrent';
        insights.add('Your $better sessions have ${(ratingDiff.abs() * 100).toStringAsFixed(0)}% higher ratings');
      }
    }

    final conversionRate = sessionTypeData['conversion_rate'] as double? ?? 0.0;
    if (conversionRate > 0.3) {
      insights.add('${(conversionRate * 100).toStringAsFixed(0)}% of trial students convert to recurrent bookings');
    }

    return insights;
  }

  /// Empty metrics structure
  static Map<String, dynamic> _emptyMetrics() {
    return {
      'average_rating': 0.0,
      'total_feedback': 0,
      'rating_count': 0,
      'recommendation_rate': 0.0,
      'objectives_met_rate': 0.0,
      'average_progress_rating': 0.0,
      'continue_lessons_rate': 0.0,
    };
  }
}

